package finance

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/ledger"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/outbox"
)

// GroupLink describes a personal ledger record created for group activity
// (ADR-023): a payer's group expense (full amount paid, personal share
// counted as spending) or a settlement (money moved; never income or
// expense).
type GroupLink struct {
	AccountID      uuid.UUID
	Type           string // group_expense | settlement
	Direction      string // outflow | inflow
	AmountMinor    int64
	PersonalShare  *int64 // group_expense only
	LocalDate      time.Time
	Description    string
	GroupID        uuid.UUID
	GroupExpenseID *uuid.UUID
	SettlementID   *uuid.UUID
}

// CreateGroupLinkedInTx records the personal transaction in the caller's
// own account (currency must match the group record).
func (s *Service) CreateGroupLinkedInTx(ctx context.Context, tx pgx.Tx, uid uuid.UUID, l GroupLink, currencyCode string) (uuid.UUID, error) {
	if l.Type != ledger.TypeGroupExpense && l.Type != ledger.TypeSettlement {
		return uuid.Nil, apperr.Internal(nil)
	}
	var acctCur, status string
	if err := tx.QueryRow(ctx, `select currency, status from financial_accounts where id = $1 and user_id = $2`, l.AccountID, uid).Scan(&acctCur, &status); err != nil {
		if database.IsNoRows(err) {
			return uuid.Nil, apperr.FieldError("body.account_id", "Choose one of your accounts.")
		}
		return uuid.Nil, err
	}
	if status != "active" {
		return uuid.Nil, apperr.Rule("account_inactive", "The account is not active.", nil)
	}
	if acctCur != currencyCode {
		return uuid.Nil, apperr.FieldError("body.account_id", "Choose an account in "+currencyCode+" (the group currency).")
	}
	u, err := LoadUser(ctx, tx, uid)
	if err != nil {
		return uuid.Nil, err
	}
	id := uuid.New()
	desc := trimPtr(&l.Description, 500)
	occurred := time.Date(l.LocalDate.Year(), l.LocalDate.Month(), l.LocalDate.Day(), 12, 0, 0, 0, u.Loc)
	if _, err := tx.Exec(ctx, `insert into transactions (id, user_id, account_id, group_id, type, direction, status, amount_minor, currency,
		occurred_at, local_date, timezone, posted_at, description, personal_share_minor, group_expense_id, settlement_id, source)
		values ($1,$2,$3,$4,$5,$6,'posted',$7,$8,$9,$10,$11,now(),$12,$13,$14,$15,'group')`,
		id, uid, l.AccountID, l.GroupID, l.Type, l.Direction, l.AmountMinor, acctCur, occurred, l.LocalDate, u.Timezone, desc, l.PersonalShare,
		l.GroupExpenseID, l.SettlementID); err != nil {
		return uuid.Nil, err
	}
	if err := postLedger(ctx, tx, uid, id, l.AccountID, 1, l.Direction, l.AmountMinor, acctCur, l.LocalDate); err != nil {
		return uuid.Nil, err
	}
	if err := txAudit(ctx, tx, uid, id, "user", "created", 1, map[string]any{"type": l.Type, "group_id": l.GroupID}); err != nil {
		return uuid.Nil, err
	}
	return id, outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.created", AggregateType: "transaction", AggregateID: id, UserID: &uid,
		GroupID: &l.GroupID, Payload: map[string]any{"local_date": LocalDateString(l.LocalDate)}})
}

// VoidGroupLinkedInTx voids a personal record created for group activity
// (when the group expense or settlement is edited, deleted or voided).
func (s *Service) VoidGroupLinkedInTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) error {
	t, err := lockTx(ctx, tx, id, uid)
	if err != nil {
		return err
	}
	if t.Type != ledger.TypeGroupExpense && t.Type != ledger.TypeSettlement {
		return apperr.Rule("not_group_record", "Not a group-linked transaction.", nil)
	}
	return voidRow(ctx, tx, uid, t) // records audit and the transaction.voided event
}

// SyncGroupExpenseInTx keeps a payer's linked group_expense record in step
// with the group expense after another member edits or deletes it (worker,
// audited as "system"). paid <= 0 (no longer a payer, or the expense was
// deleted) voids the record. The transaction keeps its ID so attachments
// and reconciliation links survive. It returns "updated", "voided" or
// "unchanged".
func (s *Service) SyncGroupExpenseInTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID, paid, share int64, date time.Time) (string, error) {
	t, err := lockTx(ctx, tx, id, uid)
	if err != nil {
		return "", err
	}
	if t.Type != ledger.TypeGroupExpense {
		return "", apperr.Rule("not_group_record", "Not a group expense record.", nil)
	}
	if t.Status == ledger.StatusVoided {
		return "unchanged", nil
	}
	if paid <= 0 {
		return "voided", systemVoid(ctx, tx, uid, t, "group_expense_changed")
	}
	share = min(max(share, 0), paid)
	var cur *int64
	if err := tx.QueryRow(ctx, `select personal_share_minor from transactions where id = $1`, id).Scan(&cur); err != nil {
		return "", err
	}
	if t.Amount == paid && cur != nil && *cur == share && t.LocalDate.Equal(date) {
		return "unchanged", nil
	}
	nv := t.Version + 1
	if ledger.AffectsBalance(t.Status) {
		if err := reverseLedger(ctx, tx, uid, t.ID, t.AccountID, t.Version, t.Direction, t.Amount, t.Currency, t.LocalDate); err != nil {
			return "", err
		}
		if err := postLedger(ctx, tx, uid, t.ID, t.AccountID, nv, t.Direction, paid, t.Currency, date); err != nil {
			return "", err
		}
	}
	loc, err := time.LoadLocation(t.Timezone)
	if err != nil {
		loc = time.UTC
	}
	occurred := time.Date(date.Year(), date.Month(), date.Day(), 12, 0, 0, 0, loc)
	if _, err := tx.Exec(ctx, `update transactions set amount_minor = $2, personal_share_minor = $3, local_date = $4, occurred_at = $5, version = $6
		where id = $1`, id, paid, share, date, occurred, nv); err != nil {
		return "", err
	}
	d := diff{}
	d.add("amount_minor", t.Amount, paid)
	d.add("personal_share_minor", deref(cur), share)
	d.add("local_date", LocalDateString(t.LocalDate), LocalDateString(date))
	changes := map[string]any{"reason": "group_expense_changed"}
	for k, v := range d {
		changes[k] = v
	}
	if err := txAudit(ctx, tx, uid, id, "system", "updated", nv, changes); err != nil {
		return "", err
	}
	return "updated", outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.updated", AggregateType: "transaction", AggregateID: id, UserID: &uid,
		Payload: map[string]any{"account_id": t.AccountID, "local_date": LocalDateString(date), "previous_local_date": LocalDateString(t.LocalDate)}})
}

// SystemVoidGroupLinkedInTx voids a member's linked record after the group
// record it mirrors was voided by someone else (worker, audited as
// "system"). It reports whether anything changed.
func (s *Service) SystemVoidGroupLinkedInTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID, reason string) (bool, error) {
	t, err := lockTx(ctx, tx, id, uid)
	if err != nil {
		return false, err
	}
	if t.Type != ledger.TypeGroupExpense && t.Type != ledger.TypeSettlement {
		return false, apperr.Rule("not_group_record", "Not a group-linked transaction.", nil)
	}
	if t.Status == ledger.StatusVoided {
		return false, nil
	}
	return true, systemVoid(ctx, tx, uid, t, reason)
}

func systemVoid(ctx context.Context, tx pgx.Tx, uid uuid.UUID, t *lockedTx, reason string) error {
	if ledger.AffectsBalance(t.Status) {
		if err := reverseLedger(ctx, tx, uid, t.ID, t.AccountID, t.Version, t.Direction, t.Amount, t.Currency, t.LocalDate); err != nil {
			return err
		}
	}
	nv := t.Version + 1
	if _, err := tx.Exec(ctx, `update transactions set status = 'voided', deleted_at = now(), version = $2 where id = $1`, t.ID, nv); err != nil {
		return err
	}
	if err := txAudit(ctx, tx, uid, t.ID, "system", "voided", nv, map[string]any{"reason": reason, "previous_status": t.Status}); err != nil {
		return err
	}
	return outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.voided", AggregateType: "transaction", AggregateID: t.ID, UserID: &uid,
		Payload: map[string]any{"account_id": t.AccountID, "local_date": LocalDateString(t.LocalDate)}})
}
