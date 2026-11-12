package finance

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/ledger"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// TransferInput moves money between two of the caller's accounts.
type TransferInput struct {
	FromAccountID uuid.UUID `json:"from_account_id"`
	ToAccountID   uuid.UUID `json:"to_account_id"`
	Amount        string    `json:"amount" doc:"Amount leaving the source account (source currency)"`
	ToAmount      string    `json:"to_amount,omitempty" doc:"Amount arriving (destination currency); required for cross-currency unless fx_rate is given"`
	FXRate        string    `json:"fx_rate,omitempty" doc:"Destination units per source unit (exact decimal)"`
	Fee           string    `json:"fee,omitempty" doc:"Fee charged to the source account (recorded as a separate expense)"`
	LocalDate     string    `json:"local_date,omitempty"`
	Description   string    `json:"description,omitempty" maxLength:"500"`
	Notes         string    `json:"notes,omitempty" maxLength:"4000"`
}

// TransferDTO describes a transfer and its legs.
type TransferDTO struct {
	ID                uuid.UUID       `json:"id"`
	FromAccountID     uuid.UUID       `json:"from_account_id"`
	ToAccountID       uuid.UUID       `json:"to_account_id"`
	FromTransactionID uuid.UUID       `json:"from_transaction_id"`
	ToTransactionID   uuid.UUID       `json:"to_transaction_id"`
	FeeTransactionID  *uuid.UUID      `json:"fee_transaction_id,omitempty"`
	FromAmount        apitypes.Money  `json:"from_amount"`
	ToAmount          apitypes.Money  `json:"to_amount"`
	FXRate            *string         `json:"fx_rate,omitempty"`
	FXRateSource      *string         `json:"fx_rate_source,omitempty"`
	Fee               *apitypes.Money `json:"fee,omitempty"`
	Status            string          `json:"status" enum:"posted,voided"`
	LocalDate         string          `json:"local_date" doc:"YYYY-MM-DD (from the outgoing leg)"`
	Description       *string         `json:"description,omitempty"`
	Notes             *string         `json:"notes,omitempty"`
	CreatedAt         time.Time       `json:"created_at"`
}

const transferSelect = `select tr.id, tr.from_account_id, tr.to_account_id, tr.from_transaction_id, tr.to_transaction_id, tr.fee_transaction_id,
	tr.from_amount_minor, tr.from_currency, tr.to_amount_minor, tr.to_currency, tr.fx_rate::text, tr.fx_rate_source, tr.fee_minor, tr.status,
	ft.local_date, ft.description, ft.notes, tr.created_at
	from transfers tr join transactions ft on ft.id = tr.from_transaction_id`

func scanTransfer(r pgx.Row) (*TransferDTO, error) {
	var t TransferDTO
	var fa, ta, fee int64
	var fc, tc string
	var d time.Time
	if err := r.Scan(&t.ID, &t.FromAccountID, &t.ToAccountID, &t.FromTransactionID, &t.ToTransactionID, &t.FeeTransactionID,
		&fa, &fc, &ta, &tc, &t.FXRate, &t.FXRateSource, &fee, &t.Status, &d, &t.Description, &t.Notes, &t.CreatedAt); err != nil {
		return nil, err
	}
	t.LocalDate = LocalDateString(d)
	t.FromAmount, t.ToAmount = m(fa, fc), m(ta, tc)
	if fee > 0 {
		f := m(fee, fc)
		t.Fee = &f
	}
	return &t, nil
}

// CreateTransfer records a transfer atomically (spec §18 "Transfer").
func (s *Service) CreateTransfer(ctx context.Context, key string, in TransferInput) (*TransferDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	if in.FromAccountID == in.ToAccountID {
		return nil, false, apperr.FieldError("body.to_account_id", "Choose two different accounts.")
	}
	var out TransferDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "transfer.create", in, func() (TransferDTO, error) {
			return s.createTransfer(ctx, tx, uid, in, "manual", nil)
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// CreateTransferInTx records a transfer inside an existing transaction
// (recurring generation). The caller provides idempotency (occurrence key).
func (s *Service) CreateTransferInTx(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in TransferInput, source string, prov *Provenance) (TransferDTO, error) {
	return s.createTransfer(ctx, tx, uid, in, source, prov)
}

func (s *Service) createTransfer(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in TransferInput, source string, prov *Provenance) (TransferDTO, error) {
	if in.FromAccountID == in.ToAccountID {
		return TransferDTO{}, apperr.FieldError("body.to_account_id", "Choose two different accounts.")
	}
	u, err := LoadUser(ctx, tx, uid)
	if err != nil {
		return TransferDTO{}, err
	}
	accounts := map[uuid.UUID]string{}
	rows, err := tx.Query(ctx, `select id, currency, status from financial_accounts where id = any($1) and user_id = $2 for update`,
		[]uuid.UUID{in.FromAccountID, in.ToAccountID}, uid)
	if err != nil {
		return TransferDTO{}, err
	}
	for rows.Next() {
		var id uuid.UUID
		var cur, status string
		if err := rows.Scan(&id, &cur, &status); err != nil {
			rows.Close()
			return TransferDTO{}, err
		}
		if status != "active" {
			rows.Close()
			return TransferDTO{}, apperr.Rule("accounts_inactive", "Both accounts must be active.", nil)
		}
		accounts[id] = cur
	}
	rows.Close()
	fromCur, ok1 := accounts[in.FromAccountID]
	toCur, ok2 := accounts[in.ToAccountID]
	if !ok1 || !ok2 {
		return TransferDTO{}, apperr.FieldError("body.from_account_id", "Both accounts must be yours.")
	}
	amount, err := ParseAmount("body.amount", in.Amount, fromCur)
	if err != nil {
		return TransferDTO{}, err
	}
	toAmount := amount
	var rate, rateSrc *string
	changes := map[string]any{}
	if fromCur != toCur {
		src := "manual"
		switch {
		case in.ToAmount != "":
			if toAmount, err = ParseAmount("body.to_amount", in.ToAmount, toCur); err != nil {
				return TransferDTO{}, err
			}
			r := ratePerUnit(toAmount, toCur, amount, fromCur)
			rate, rateSrc = &r, &src
		case in.FXRate != "":
			rr, err := money.ParseRate(in.FXRate)
			if err != nil {
				return TransferDTO{}, apperr.FieldError("body.fx_rate", "Enter a positive exact rate such as 83.1234.")
			}
			conv, err := money.Convert(amount, fromCur, toCur, rr)
			if err != nil {
				return TransferDTO{}, apperr.FieldError("body.fx_rate", "The converted amount is out of range.")
			}
			if conv.ToMinor <= 0 {
				return TransferDTO{}, apperr.FieldError("body.fx_rate", "The converted amount rounds to zero.")
			}
			toAmount = conv.ToMinor
			r := money.FormatRate(rr)
			rate, rateSrc = &r, &src
			changes["rounding_delta_minor_units"] = conv.RoundingDelta
		default:
			return TransferDTO{}, apperr.FieldError("body.to_amount", "Cross-currency transfers need the received amount or an exchange rate.")
		}
	} else if in.ToAmount != "" {
		if v, err := ParseAmount("body.to_amount", in.ToAmount, toCur); err != nil || v != amount {
			return TransferDTO{}, apperr.FieldError("body.to_amount", "Same-currency transfers move the same amount; record fees with the fee field.")
		}
	}
	var fee int64
	if in.Fee != "" {
		if fee, err = ParseSignedAmount("body.fee", in.Fee, fromCur); err != nil || fee < 0 {
			return TransferDTO{}, apperr.FieldError("body.fee", "Fee must be zero or positive.")
		}
	}
	date := todayIn(s.now(), u.Loc)
	if in.LocalDate != "" {
		if date, err = ParseDate("body.local_date", in.LocalDate, u.Loc); err != nil {
			return TransferDTO{}, err
		}
	}
	occurred := time.Date(date.Year(), date.Month(), date.Day(), 12, 0, 0, 0, u.Loc)
	if in.LocalDate == "" {
		occurred = s.now()
	}
	if source == "manual" {
		if err := rejectSensitiveText(in.Description, in.Notes); err != nil {
			return TransferDTO{}, err
		}
	}
	actor := "user"
	var recRule, occ *uuid.UUID
	if prov != nil {
		recRule, occ = prov.RecurringRule, prov.Occurrence
		if prov.ActorKind != "" {
			actor = prov.ActorKind
		}
	}
	desc := trimPtr(&in.Description, 500)
	notes := trimPtr(&in.Notes, 4000)
	transferID, fromTx, toTx := uuid.New(), uuid.New(), uuid.New()
	insertLeg := func(id, acct uuid.UUID, typ, dir string, amt int64, cur string, category *uuid.UUID, d *string) error {
		if _, err := tx.Exec(ctx, `insert into transactions (id, user_id, account_id, type, direction, status, amount_minor, currency,
			occurred_at, local_date, timezone, posted_at, description, notes, transfer_id, category_id, source, recurring_rule_id, recurring_occurrence_id)
			values ($1,$2,$3,$4,$5,'posted',$6,$7,$8,$9,$10,now(),$11,$12,$13,$14,$15,$16,$17)`,
			id, uid, acct, typ, dir, amt, cur, occurred, date, u.Timezone, d, notes, transferID, category, source, recRule, occ); err != nil {
			return err
		}
		if err := postLedger(ctx, tx, uid, id, acct, 1, dir, amt, cur, date); err != nil {
			return err
		}
		return txAudit(ctx, tx, uid, id, actor, "created", 1, map[string]any{"type": typ, "transfer_id": transferID, "source": source})
	}
	if err := insertLeg(fromTx, in.FromAccountID, ledger.TypeTransfer, ledger.Outflow, amount, fromCur, nil, desc); err != nil {
		return TransferDTO{}, err
	}
	if err := insertLeg(toTx, in.ToAccountID, ledger.TypeTransfer, ledger.Inflow, toAmount, toCur, nil, desc); err != nil {
		return TransferDTO{}, err
	}
	var feeTx *uuid.UUID
	if fee > 0 {
		var feeCat *uuid.UUID
		_ = tx.QueryRow(ctx, `select id from categories where user_id = $1 and system_key = 'taxes_fees' and status = 'active'`, uid).Scan(&feeCat)
		fid := uuid.New()
		feeDesc := "Transfer fee"
		if err := insertLeg(fid, in.FromAccountID, ledger.TypeExpense, ledger.Outflow, fee, fromCur, feeCat, &feeDesc); err != nil {
			return TransferDTO{}, err
		}
		feeTx = &fid
	}
	var fxAt *time.Time
	if rate != nil {
		n := s.now()
		fxAt = &n
	}
	if _, err := tx.Exec(ctx, `insert into transfers (id, user_id, from_account_id, to_account_id, from_transaction_id, to_transaction_id,
		fee_transaction_id, from_amount_minor, from_currency, to_amount_minor, to_currency, fx_rate, fx_rate_source, fx_rate_at, fee_minor)
		values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::numeric,$13,$14,$15)`, transferID, uid, in.FromAccountID, in.ToAccountID, fromTx, toTx,
		feeTx, amount, fromCur, toAmount, toCur, rate, rateSrc, fxAt, fee); err != nil {
		return TransferDTO{}, err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "transfer", EntityID: &transferID, Action: "created", Changes: changes}); err != nil {
		return TransferDTO{}, err
	}
	if err := outbox.Emit(ctx, tx, outbox.Event{Type: "transfer.created", AggregateType: "transfer", AggregateID: transferID, UserID: &uid,
		Payload: map[string]any{"local_date": LocalDateString(date)}}); err != nil {
		return TransferDTO{}, err
	}
	t, err := scanTransfer(tx.QueryRow(ctx, transferSelect+` where tr.id = $1`, transferID))
	if err != nil {
		return TransferDTO{}, err
	}
	return *t, nil
}

// GetTransfer returns a transfer.
func (s *Service) GetTransfer(ctx context.Context, id uuid.UUID) (*TransferDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *TransferDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out, err = scanTransfer(tx.QueryRow(ctx, transferSelect+` where tr.id = $1 and tr.user_id = $2`, id, uid))
		if database.IsNoRows(err) {
			return apperr.NotFound("transfer")
		}
		return err
	})
	return out, database.MapError(err)
}

// setTransferVoided voids or restores every leg of a transfer together.
func (s *Service) setTransferVoided(ctx context.Context, tx pgx.Tx, uid, transferID uuid.UUID, void bool) error {
	var fromTx, toTx uuid.UUID
	var feeTx *uuid.UUID
	if err := tx.QueryRow(ctx, `select from_transaction_id, to_transaction_id, fee_transaction_id from transfers where id = $1 and user_id = $2 for update`,
		transferID, uid).Scan(&fromTx, &toTx, &feeTx); err != nil {
		if database.IsNoRows(err) {
			return apperr.NotFound("transfer")
		}
		return err
	}
	legs := []uuid.UUID{fromTx, toTx}
	if feeTx != nil {
		legs = append(legs, *feeTx)
	}
	for _, id := range legs {
		t, err := lockTx(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		if void {
			err = voidRow(ctx, tx, uid, t)
		} else if t.Status == ledger.StatusVoided {
			err = restoreRow(ctx, tx, uid, t)
		}
		if err != nil {
			return err
		}
	}
	status := "posted"
	if void {
		status = "voided"
	}
	if _, err := tx.Exec(ctx, `update transfers set status = $2 where id = $1`, transferID, status); err != nil {
		return err
	}
	return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "transfer", EntityID: &transferID, Action: map[bool]string{true: "voided", false: "restored"}[void]})
}

// VoidTransfer deletes a transfer: every leg (and the fee) is voided as a
// unit with reversing ledger entries. It is idempotent and restorable.
func (s *Service) VoidTransfer(ctx context.Context, id uuid.UUID) (*TransferDTO, error) {
	return s.setTransferState(ctx, id, true)
}

// RestoreTransfer restores a voided transfer as a unit.
func (s *Service) RestoreTransfer(ctx context.Context, id uuid.UUID) (*TransferDTO, error) {
	return s.setTransferState(ctx, id, false)
}

func (s *Service) setTransferState(ctx context.Context, id uuid.UUID, void bool) (*TransferDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *TransferDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx, `select status from transfers where id = $1 and user_id = $2`, id, uid).Scan(&status); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("transfer")
			}
			return err
		}
		if (void && status != "voided") || (!void && status == "voided") {
			if err := s.setTransferVoided(ctx, tx, uid, id, void); err != nil {
				return err
			}
		}
		var err error
		out, err = scanTransfer(tx.QueryRow(ctx, transferSelect+` where tr.id = $1 and tr.user_id = $2`, id, uid))
		return err
	})
	return out, database.MapError(err)
}
