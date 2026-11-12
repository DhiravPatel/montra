package groups

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/ledger"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// SettlementInput records an off-app payment between two members (spec
// §4.15). Montra never initiates payments; every settlement is
// user-reported unless a real provider verifies it.
type SettlementInput struct {
	PayerUserID   uuid.UUID  `json:"payer_user_id"`
	PayeeUserID   uuid.UUID  `json:"payee_user_id"`
	Amount        string     `json:"amount" doc:"In the group currency; partial amounts are allowed"`
	Method        string     `json:"method,omitempty" enum:"cash,bank_transfer,upi,other" doc:"How it was (or will be) paid outside Montra"`
	State         string     `json:"state,omitempty" enum:"proposed,paid" doc:"proposed: a request or plan; paid (default): the money was paid"`
	SettledOn     string     `json:"settled_on,omitempty" doc:"YYYY-MM-DD, default today in the group time zone"`
	Note          string     `json:"note,omitempty" maxLength:"500"`
	ReceiptFileID *uuid.UUID `json:"receipt_file_id,omitempty" doc:"Proof uploaded to this group (purpose group_attachment)"`
	AccountID     *uuid.UUID `json:"account_id,omitempty" doc:"Also record it in one of your accounts (payer: money out, payee: money in); never income or spending"`
}

// SettlementDTO is a settlement record.
type SettlementDTO struct {
	ID                      uuid.UUID      `json:"id"`
	GroupID                 uuid.UUID      `json:"group_id"`
	PayerUserID             uuid.UUID      `json:"payer_user_id"`
	PayerName               string         `json:"payer_name"`
	PayeeUserID             uuid.UUID      `json:"payee_user_id"`
	PayeeName               string         `json:"payee_name"`
	Amount                  apitypes.Money `json:"amount"`
	Method                  string         `json:"method" enum:"cash,bank_transfer,upi,other"`
	Status                  string         `json:"status" enum:"proposed,user_reported_paid,confirmed,disputed,voided"`
	Verification            string         `json:"verification" enum:"user_reported,provider_verified" doc:"user_reported unless a provider verified the payment"`
	ProposedBy              *uuid.UUID     `json:"proposed_by,omitempty"`
	ConfirmedBy             *uuid.UUID     `json:"confirmed_by,omitempty"`
	ConfirmedAt             *time.Time     `json:"confirmed_at,omitempty"`
	DisputeReason           *string        `json:"dispute_reason,omitempty"`
	VoidedBy                *uuid.UUID     `json:"voided_by,omitempty"`
	VoidReason              *string        `json:"void_reason,omitempty"`
	VoidedAt                *time.Time     `json:"voided_at,omitempty"`
	CorrectsSettlementID    *uuid.UUID     `json:"corrects_settlement_id,omitempty"`
	CorrectedBySettlementID *uuid.UUID     `json:"corrected_by_settlement_id,omitempty"`
	Note                    *string        `json:"note,omitempty"`
	ReceiptFileID           *uuid.UUID     `json:"receipt_file_id,omitempty"`
	SettledOn               string         `json:"settled_on"`
	MyTransactionID         *uuid.UUID     `json:"my_transaction_id,omitempty" doc:"Your own linked account record, if any (other members' records are never shown)"`
	Counted                 bool           `json:"counted" doc:"Confirmed settlements count toward balances"`
	Version                 int32          `json:"version"`
	CreatedAt               time.Time      `json:"created_at"`
}

// SettlementActionInput changes a settlement's state.
type SettlementActionInput struct {
	Action    string     `json:"action" enum:"mark_paid,confirm,dispute,void,record_personal,unlink_personal"`
	Version   int32      `json:"version"`
	Reason    string     `json:"reason,omitempty" maxLength:"500" doc:"Required to dispute or void"`
	AccountID *uuid.UUID `json:"account_id,omitempty" doc:"mark_paid / confirm / record_personal: record it in one of your accounts"`
}

const settlementCols = `s.id, s.group_id, s.payer_user_id, s.payee_user_id, s.amount_minor, s.currency, s.method, s.status, s.verification,
	s.proposed_by, s.confirmed_by, s.confirmed_at, s.dispute_reason, s.voided_by, s.void_reason, s.voided_at, s.corrects_settlement_id,
	(select c.id from settlements c where c.corrects_settlement_id = s.id order by c.created_at desc limit 1),
	s.note, s.receipt_file_id, s.settled_on,
	(select t.id from transactions t where t.settlement_id = s.id and t.user_id = montra.current_user_id() and t.status <> 'voided' limit 1),
	s.version, s.created_at`

func scanSettlement(r pgx.Row) (*SettlementDTO, error) {
	var x SettlementDTO
	var amt int64
	var cur string
	var on time.Time
	if err := r.Scan(&x.ID, &x.GroupID, &x.PayerUserID, &x.PayeeUserID, &amt, &cur, &x.Method, &x.Status, &x.Verification, &x.ProposedBy,
		&x.ConfirmedBy, &x.ConfirmedAt, &x.DisputeReason, &x.VoidedBy, &x.VoidReason, &x.VoidedAt, &x.CorrectsSettlementID,
		&x.CorrectedBySettlementID, &x.Note, &x.ReceiptFileID, &on, &x.MyTransactionID, &x.Version, &x.CreatedAt); err != nil {
		return nil, err
	}
	x.Amount, x.SettledOn, x.Counted = apitypes.M(amt, cur), finance.LocalDateString(on), x.Status == "confirmed"
	return &x, nil
}

func (s *Service) loadSettlements(ctx context.Context, tx pgx.Tx, groupID uuid.UUID, where string, args ...any) ([]SettlementDTO, error) {
	ms, err := members(ctx, tx, groupID)
	if err != nil {
		return nil, err
	}
	names := map[uuid.UUID]string{}
	for _, m := range ms {
		names[m.UserID] = m.DisplayName
	}
	q := `select ` + settlementCols + ` from settlements s where s.group_id = $1`
	if where != "" {
		q += ` and ` + where
	}
	rows, err := tx.Query(ctx, q, append([]any{groupID}, args...)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []SettlementDTO{}
	for rows.Next() {
		x, err := scanSettlement(rows)
		if err != nil {
			return nil, err
		}
		x.PayerName, x.PayeeName = nameOr(names, x.PayerUserID), nameOr(names, x.PayeeUserID)
		out = append(out, *x)
	}
	return out, rows.Err()
}

func nameOr(names map[uuid.UUID]string, id uuid.UUID) string {
	if n, ok := names[id]; ok {
		return n
	}
	return "Former member"
}

func (s *Service) settlement(ctx context.Context, tx pgx.Tx, groupID, id uuid.UUID) (*SettlementDTO, error) {
	list, err := s.loadSettlements(ctx, tx, groupID, `s.id = $2`, id)
	if err != nil {
		return nil, err
	}
	if len(list) == 0 {
		return nil, apperr.NotFound("settlement")
	}
	return &list[0], nil
}

// ListSettlements lists a group's settlements (newest first).
func (s *Service) ListSettlements(ctx context.Context, groupID uuid.UUID, includeVoided bool) ([]SettlementDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []SettlementDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		where := `s.status <> 'voided' order by s.settled_on desc, s.created_at desc limit 500`
		if includeVoided {
			where = `true order by s.settled_on desc, s.created_at desc limit 500`
		}
		out, err = s.loadSettlements(ctx, tx, groupID, where)
		return err
	})
	return out, database.MapError(err)
}

// GetSettlement returns one settlement.
func (s *Service) GetSettlement(ctx context.Context, groupID, id uuid.UUID) (*SettlementDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *SettlementDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		out, err = s.settlement(ctx, tx, groupID, id)
		return err
	})
	return out, database.MapError(err)
}

// CreateSettlement records a proposed or paid settlement (idempotent).
func (s *Service) CreateSettlement(ctx context.Context, key string, groupID uuid.UUID, in SettlementInput) (*SettlementDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out SettlementDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = runIdem(ctx, tx, uid, key, "settlement.create", groupID, in, func() (SettlementDTO, error) {
			_, g, err := requireMember(ctx, tx, groupID)
			if err != nil {
				return SettlementDTO{}, err
			}
			if err := requireActive(g); err != nil {
				return SettlementDTO{}, err
			}
			id, err := s.insertSettlement(ctx, tx, uid, g, in, nil)
			if err != nil {
				return SettlementDTO{}, err
			}
			x, err := s.settlement(ctx, tx, groupID, id)
			if err != nil {
				return SettlementDTO{}, err
			}
			return *x, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

func (s *Service) insertSettlement(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, in SettlementInput, corrects *uuid.UUID) (uuid.UUID, error) {
	if in.PayerUserID == in.PayeeUserID {
		return uuid.Nil, apperr.FieldError("body.payee_user_id", "The payer and payee must be different people.")
	}
	// Parties must be (or have been) members; former members can still be
	// settled with.
	var known int
	if err := tx.QueryRow(ctx, `select count(*) from group_members where group_id = $1 and user_id in ($2, $3)`, g.ID, in.PayerUserID,
		in.PayeeUserID).Scan(&known); err != nil {
		return uuid.Nil, err
	}
	if known != 2 {
		return uuid.Nil, apperr.FieldError("body.payer_user_id", "Both people must be members (or former members) of this group.")
	}
	amt, err := finance.ParseAmount("body.amount", in.Amount, g.BaseCurrency)
	if err != nil {
		return uuid.Nil, err
	}
	method := in.Method
	if method == "" {
		method = "other"
	}
	state := in.State
	if state == "" {
		state = "paid"
	}
	loc, err := time.LoadLocation(g.Timezone)
	if err != nil {
		loc = time.UTC
	}
	now := s.now().In(loc)
	on := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	if in.SettledOn != "" {
		d, err := finance.ParseDate("body.settled_on", in.SettledOn, loc)
		if err != nil {
			return uuid.Nil, err
		}
		on = time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, time.UTC)
	}
	if in.ReceiptFileID != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from files where id = $1 and group_id = $2 and purpose = 'group_attachment' and status = 'ready')`,
			*in.ReceiptFileID, g.ID).Scan(&ok); err != nil {
			return uuid.Nil, err
		}
		if !ok {
			return uuid.Nil, apperr.FieldError("body.receipt_file_id", "Upload the proof to this group first (purpose group_attachment).")
		}
	}
	status := "proposed"
	var confirmedBy *uuid.UUID
	if state == "paid" {
		status = "user_reported_paid"
		if uid == in.PayeeUserID { // the payee recording receipt is the confirmation
			status, confirmedBy = "confirmed", &uid
		}
	}
	if in.AccountID != nil {
		switch {
		case uid != in.PayerUserID && uid != in.PayeeUserID:
			return uuid.Nil, apperr.FieldError("body.account_id", "Only the payer or payee can record it in their own account.")
		case state != "paid":
			return uuid.Nil, apperr.FieldError("body.account_id", "Record it in your account once it is paid.")
		}
	}
	id := uuid.New()
	if _, err := tx.Exec(ctx, `insert into settlements (id, group_id, payer_user_id, payee_user_id, amount_minor, currency, method, status,
		proposed_by, confirmed_by, confirmed_at, corrects_settlement_id, note, receipt_file_id, settled_on)
		values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,case when $10::uuid is null then null else now() end,$11,$12,$13,$14)`,
		id, g.ID, in.PayerUserID, in.PayeeUserID, amt, g.BaseCurrency, method, status, uid, confirmedBy, corrects, trim(in.Note, 500),
		in.ReceiptFileID, on); err != nil {
		return uuid.Nil, err
	}
	if in.AccountID != nil {
		if err := s.recordPersonal(ctx, tx, uid, g, id, *in.AccountID); err != nil {
			return uuid.Nil, err
		}
	}
	kind := "settlement_" + map[string]string{"proposed": "proposed", "user_reported_paid": "reported", "confirmed": "confirmed"}[status]
	if corrects != nil {
		kind = "settlement_corrected"
	}
	if err := s.settlementChanged(ctx, tx, uid, g.ID, id, kind, "created"); err != nil {
		return uuid.Nil, err
	}
	return id, nil
}

func (s *Service) settlementChanged(ctx context.Context, tx pgx.Tx, uid, groupID, id uuid.UUID, kind, action string) error {
	if err := activity(ctx, tx, groupID, &uid, kind, "settlement", &id, nil); err != nil {
		return err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, GroupID: &groupID, EntityType: "settlement", EntityID: &id,
		Action: action}); err != nil {
		return err
	}
	return outbox.Emit(ctx, tx, outbox.Event{Type: EventSettlement, AggregateType: "settlement", AggregateID: id, UserID: &uid, GroupID: &groupID,
		Payload: map[string]any{"kind": kind}})
}

// recordPersonal creates the caller's own settlement record in one of their
// accounts: money out for the payer, money in for the payee.
func (s *Service) recordPersonal(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, settlementID, account uuid.UUID) error {
	var payer, payee uuid.UUID
	var amt int64
	var status, note string
	var on time.Time
	if err := tx.QueryRow(ctx, `select payer_user_id, payee_user_id, amount_minor, status, coalesce(note, ''), settled_on from settlements
		where id = $1 and group_id = $2`, settlementID, g.ID).Scan(&payer, &payee, &amt, &status, &note, &on); err != nil {
		return err
	}
	var dir string
	switch {
	case status == "voided" && (uid == payer || uid == payee):
		return settlementVoided()
	case uid == payer && (status == "user_reported_paid" || status == "confirmed" || status == "disputed"):
		dir = ledger.Outflow
	case uid == payee && status == "confirmed":
		dir = ledger.Inflow
	case uid == payee:
		return apperr.Rule("settlement_not_confirmed", "Confirm the payment before recording it in your account.", nil)
	case uid == payer:
		return apperr.Rule("settlement_not_paid", "Mark it paid before recording it in your account.", nil)
	default:
		return apperr.Forbidden()
	}
	var exists bool
	if err := tx.QueryRow(ctx, `select exists (select 1 from transactions where settlement_id = $1 and user_id = $2 and status <> 'voided')`,
		settlementID, uid).Scan(&exists); err != nil {
		return err
	}
	if exists {
		return apperr.ConflictCode("settlement_already_recorded", "This settlement is already recorded in your account.", nil)
	}
	desc := "Group settlement"
	if note != "" {
		desc += ": " + note
	}
	sid := settlementID
	_, err := s.Finance.CreateGroupLinkedInTx(ctx, tx, uid, finance.GroupLink{AccountID: account, Type: ledger.TypeSettlement, Direction: dir,
		AmountMinor: amt, LocalDate: on, Description: desc, GroupID: g.ID, SettlementID: &sid}, g.BaseCurrency)
	return err
}

// unlinkPersonal voids the caller's own linked record for a settlement.
func (s *Service) unlinkPersonal(ctx context.Context, tx pgx.Tx, uid, settlementID uuid.UUID) (bool, error) {
	rows, err := tx.Query(ctx, `select id from transactions where settlement_id = $1 and user_id = $2 and status <> 'voided'`, settlementID, uid)
	if err != nil {
		return false, err
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return false, err
	}
	for _, id := range ids {
		if err := s.Finance.VoidGroupLinkedInTx(ctx, tx, uid, id); err != nil {
			return false, err
		}
	}
	return len(ids) > 0, nil
}

func settlementVoided() error {
	return apperr.ConflictCode("settlement_voided", "This settlement was voided.", nil)
}

// statusParam carries the settlement's current status on a 409 that
// depends on it.
func statusParam(status string) map[string]string { return map[string]string{"status": status} }

// ActOnSettlement applies a lifecycle action:
//
//	proposed            → mark_paid (payer) → user_reported_paid
//	proposed/reported   → confirm (payee)   → confirmed
//	reported/confirmed  → dispute (either)  → disputed
//	disputed            → confirm (payee)   → confirmed (dispute resolved)
//	any but voided      → void (either party or an admin, with a reason)
//
// A payee who is no longer a member (removed or left) cannot confirm, so a
// payment to them is confirmed by an admin on their behalf (recorded as
// confirmed_by the admin, still user_reported).
func (s *Service) ActOnSettlement(ctx context.Context, groupID, id uuid.UUID, in SettlementActionInput) (*SettlementDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *SettlementDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		var payer, payee uuid.UUID
		var status string
		var version int32
		var proposedBy *uuid.UUID
		if err := tx.QueryRow(ctx, `select payer_user_id, payee_user_id, status, version, proposed_by from settlements
			where id = $1 and group_id = $2 for update`, id, groupID).Scan(&payer, &payee, &status, &version, &proposedBy); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("settlement")
			}
			return err
		}
		if in.Version != version {
			return apperr.VersionConflict()
		}
		party := uid == payer || uid == payee
		reason := strings.TrimSpace(in.Reason)
		kind := ""
		if status == "voided" && in.Action != "unlink_personal" {
			return settlementVoided()
		}
		switch in.Action {
		case "mark_paid":
			if uid != payer {
				return apperr.Forbidden()
			}
			if status != "proposed" {
				return apperr.ConflictCode("settlement_not_proposed", "Only a proposed settlement can be marked paid.", statusParam(status))
			}
			if err := requireActive(g); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `update settlements set status = 'user_reported_paid', version = version + 1 where id = $1`, id); err != nil {
				return err
			}
			kind = "settlement_reported"
		case "confirm":
			if uid != payee {
				var payeeActive bool
				if err := tx.QueryRow(ctx, `select exists (select 1 from group_members where group_id = $1 and user_id = $2 and status = 'active')`,
					groupID, payee).Scan(&payeeActive); err != nil {
					return err
				}
				if payeeActive || role == "member" {
					return apperr.Forbidden() // the payee confirms; admins only for a payee who is no longer a member
				}
				if in.AccountID != nil {
					return apperr.FieldError("body.account_id", "Only the payee records a payment they received in their account.")
				}
			}
			if status != "proposed" && status != "user_reported_paid" && status != "disputed" {
				return apperr.ConflictCode("settlement_not_confirmable", "Only a proposed, reported or disputed settlement can be confirmed.",
					statusParam(status))
			}
			if _, err := tx.Exec(ctx, `update settlements set status = 'confirmed', confirmed_by = $2, confirmed_at = now(), version = version + 1
				where id = $1`, id, uid); err != nil {
				return err
			}
			if status == "disputed" {
				if _, err := tx.Exec(ctx, `update group_disputes set status = 'resolved', resolution = 'Confirmed by the payee', resolved_by = $2,
					resolved_at = now() where settlement_id = $1 and status = 'open'`, id, uid); err != nil {
					return err
				}
			}
			kind = "settlement_confirmed"
		case "dispute":
			if !party {
				return apperr.Forbidden()
			}
			if status != "user_reported_paid" && status != "confirmed" {
				return apperr.ConflictCode("settlement_not_disputable", "Only a reported or confirmed settlement can be disputed.", statusParam(status))
			}
			if reason == "" {
				return apperr.FieldError("body.reason", "Explain what is wrong.")
			}
			if _, err := tx.Exec(ctx, `update settlements set status = 'disputed', dispute_reason = $2, version = version + 1 where id = $1`, id, reason); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `insert into group_disputes (group_id, settlement_id, raised_by, reason) values ($1,$2,$3,$4)`,
				groupID, id, uid, reason); err != nil {
				return err
			}
			kind = "settlement_disputed"
		case "void":
			if !party && role == "member" && (proposedBy == nil || *proposedBy != uid) {
				return apperr.Forbidden()
			}
			if reason == "" {
				return apperr.FieldError("body.reason", "Give a reason for voiding it.")
			}
			if err := s.voidSettlement(ctx, tx, uid, groupID, id, reason); err != nil {
				return err
			}
			kind = "settlement_voided"
		case "record_personal":
			if in.AccountID == nil {
				return apperr.FieldError("body.account_id", "Choose one of your accounts.")
			}
			if err := s.recordPersonal(ctx, tx, uid, g, id, *in.AccountID); err != nil {
				return err
			}
		case "unlink_personal":
			found, err := s.unlinkPersonal(ctx, tx, uid, id)
			if err != nil {
				return err
			}
			if !found {
				return apperr.NotFound("linked account record")
			}
		default:
			return apperr.FieldError("body.action", "Unknown action.")
		}
		if in.AccountID != nil && (in.Action == "mark_paid" || in.Action == "confirm") {
			if err := s.recordPersonal(ctx, tx, uid, g, id, *in.AccountID); err != nil {
				return err
			}
		}
		if kind != "" {
			if err := s.settlementChanged(ctx, tx, uid, groupID, id, kind, strings.TrimPrefix(kind, "settlement_")); err != nil {
				return err
			}
		}
		out, err = s.settlement(ctx, tx, groupID, id)
		return err
	})
	return out, database.MapError(err)
}

// voidSettlement voids a settlement, resolves open disputes on it and
// voids the caller's own linked record (the worker voids other members'
// records, which the caller cannot access).
func (s *Service) voidSettlement(ctx context.Context, tx pgx.Tx, uid, groupID, id uuid.UUID, reason string) error {
	if _, err := tx.Exec(ctx, `update settlements set status = 'voided', voided_by = $2, void_reason = $3, voided_at = now(), version = version + 1
		where id = $1`, id, uid, reason); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `update group_disputes set status = 'resolved', resolution = 'Settlement voided', resolved_by = $2, resolved_at = now()
		where settlement_id = $1 and status = 'open'`, id, uid); err != nil {
		return err
	}
	_, err := s.unlinkPersonal(ctx, tx, uid, id)
	return err
}

// CorrectSettlement replaces a settlement with a corrected one: the
// original is voided (kept for history) and linked from the new record.
func (s *Service) CorrectSettlement(ctx context.Context, key string, groupID, id uuid.UUID, in SettlementInput) (*SettlementDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out SettlementDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = runIdem(ctx, tx, uid, key, "settlement.correct", groupID, struct {
			ID uuid.UUID
			In SettlementInput
		}{id, in}, func() (SettlementDTO, error) {
			role, g, err := requireMember(ctx, tx, groupID)
			if err != nil {
				return SettlementDTO{}, err
			}
			if err := requireActive(g); err != nil {
				return SettlementDTO{}, err
			}
			var payer, payee uuid.UUID
			var status string
			if err := tx.QueryRow(ctx, `select payer_user_id, payee_user_id, status from settlements where id = $1 and group_id = $2 for update`,
				id, groupID).Scan(&payer, &payee, &status); err != nil {
				if database.IsNoRows(err) {
					return SettlementDTO{}, apperr.NotFound("settlement")
				}
				return SettlementDTO{}, err
			}
			if uid != payer && uid != payee && role == "member" {
				return SettlementDTO{}, apperr.Forbidden()
			}
			if status == "voided" {
				return SettlementDTO{}, settlementVoided()
			}
			if err := s.voidSettlement(ctx, tx, uid, groupID, id, "Corrected"); err != nil {
				return SettlementDTO{}, err
			}
			if err := s.settlementChanged(ctx, tx, uid, groupID, id, "settlement_voided", "voided"); err != nil {
				return SettlementDTO{}, err
			}
			orig := id
			nid, err := s.insertSettlement(ctx, tx, uid, g, in, &orig)
			if err != nil {
				return SettlementDTO{}, err
			}
			x, err := s.settlement(ctx, tx, groupID, nid)
			if err != nil {
				return SettlementDTO{}, err
			}
			return *x, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}
