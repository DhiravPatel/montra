package finance

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/ledger"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// lockedTx is the mutable state of a transaction row, locked FOR UPDATE.
type lockedTx struct {
	ID, AccountID          uuid.UUID
	Type, Direction        string
	Status                 string
	Amount                 int64
	Currency               string
	LocalDate              time.Time
	OccurredAt             time.Time
	Timezone               string
	CategoryID, MerchantID *uuid.UUID
	PaymentMethodID        *uuid.UUID
	Description, Notes     *string
	Location               *string
	OriginalTxID           *uuid.UUID
	TransferID             *uuid.UUID
	OriginalAmount         *int64
	OriginalCurrency       *string
	IsCorrection           bool
	Version                int32
}

func lockTx(ctx context.Context, tx pgx.Tx, id, uid uuid.UUID) (*lockedTx, error) {
	var t lockedTx
	err := tx.QueryRow(ctx, `select id, account_id, type, direction, status, amount_minor, currency, local_date, occurred_at, timezone,
		category_id, merchant_id, payment_method_id, description, notes, location_text, original_transaction_id, transfer_id,
		original_amount_minor, original_currency, is_correction, version
		from transactions where id = $1 and user_id = $2 for update`, id, uid).Scan(&t.ID, &t.AccountID, &t.Type, &t.Direction, &t.Status,
		&t.Amount, &t.Currency, &t.LocalDate, &t.OccurredAt, &t.Timezone, &t.CategoryID, &t.MerchantID, &t.PaymentMethodID,
		&t.Description, &t.Notes, &t.Location, &t.OriginalTxID, &t.TransferID, &t.OriginalAmount, &t.OriginalCurrency, &t.IsCorrection, &t.Version)
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("transaction")
	}
	return &t, err
}

// TransactionPatch edits a transaction; absent fields are unchanged.
type TransactionPatch struct {
	Version            int32        `json:"version" doc:"Current version (optimistic concurrency)"`
	AccountID          *uuid.UUID   `json:"account_id,omitempty" doc:"Move to another account with the same currency"`
	Amount             *string      `json:"amount,omitempty"`
	OriginalAmount     *string      `json:"original_amount,omitempty"`
	OriginalCurrency   *string      `json:"original_currency,omitempty" pattern:"^[A-Z]{3}$"`
	ClearOriginal      bool         `json:"clear_original,omitempty"`
	OccurredAt         *time.Time   `json:"occurred_at,omitempty"`
	LocalDate          *string      `json:"local_date,omitempty"`
	Timezone           *string      `json:"timezone,omitempty" maxLength:"64"`
	Status             *string      `json:"status,omitempty" enum:"posted,pending,draft"`
	CategoryID         *uuid.UUID   `json:"category_id,omitempty"`
	ClearCategory      bool         `json:"clear_category,omitempty"`
	MerchantID         *uuid.UUID   `json:"merchant_id,omitempty"`
	MerchantName       *string      `json:"merchant_name,omitempty" maxLength:"120"`
	ClearMerchant      bool         `json:"clear_merchant,omitempty"`
	PaymentMethodID    *uuid.UUID   `json:"payment_method_id,omitempty"`
	ClearPaymentMethod bool         `json:"clear_payment_method,omitempty"`
	Description        *string      `json:"description,omitempty" maxLength:"500"`
	Notes              *string      `json:"notes,omitempty" maxLength:"4000"`
	LocationText       *string      `json:"location_text,omitempty" maxLength:"200"`
	TagIDs             *[]uuid.UUID `json:"tag_ids,omitempty" maxItems:"20" doc:"Replaces all tags"`
	TagNames           []string     `json:"tag_names,omitempty" maxItems:"20"`
	IsCorrection       *bool        `json:"is_correction,omitempty"`
}

// metadataOnlyTypes may change only descriptive fields here (amounts are
// owned by their dedicated workflows).
var metadataOnlyTypes = map[string]bool{ledger.TypeTransfer: true, ledger.TypeOpeningBalance: true, ledger.TypeAdjustment: true,
	ledger.TypeGroupExpense: true, ledger.TypeSettlement: true}

// UpdateTransaction applies a versioned edit, appending reversing and new
// ledger entries when the financial effect changes (no silent mutation).
func (s *Service) UpdateTransaction(ctx context.Context, id uuid.UUID, p TransactionPatch) (*TransactionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *TransactionDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		old, err := lockTx(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		if old.Version != p.Version {
			return apperr.VersionConflict()
		}
		if old.Status == ledger.StatusVoided {
			return apperr.Rule("transaction_voided", "Restore this transaction before editing it.", nil)
		}
		financial := p.AccountID != nil || p.Amount != nil || p.OriginalAmount != nil || p.ClearOriginal || p.OccurredAt != nil ||
			p.LocalDate != nil || p.Timezone != nil || p.Status != nil
		if metadataOnlyTypes[old.Type] && (financial || p.CategoryID != nil || p.ClearCategory) {
			return apperr.Rule("limited_edit", "Only the description, notes, merchant and tags of this transaction can be edited here.", nil)
		}
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		nt := *old
		d := diff{}
		if p.AccountID != nil && *p.AccountID != old.AccountID {
			var cur, status string
			err := tx.QueryRow(ctx, `select currency, status from financial_accounts where id = $1 and user_id = $2`, *p.AccountID, uid).Scan(&cur, &status)
			if database.IsNoRows(err) {
				return apperr.FieldError("body.account_id", "Choose one of your accounts.")
			}
			if err != nil {
				return err
			}
			if status != "active" {
				return apperr.Rule("account_inactive", "The destination account is archived or closed.", nil)
			}
			if cur != old.Currency {
				return apperr.Rule("currency_mismatch", "Transactions can only move between accounts with the same currency.", nil)
			}
			nt.AccountID = *p.AccountID
		}
		if p.Amount != nil {
			if nt.Amount, err = ParseAmount("body.amount", *p.Amount, old.Currency); err != nil {
				return err
			}
		}
		if p.IsCorrection != nil {
			nt.IsCorrection = *p.IsCorrection
		}
		if p.ClearOriginal {
			nt.OriginalAmount, nt.OriginalCurrency = nil, nil
		} else if p.OriginalAmount != nil || p.OriginalCurrency != nil {
			oc := strOr(p.OriginalCurrency)
			if oc == "" && old.OriginalCurrency != nil {
				oc = *old.OriginalCurrency
			}
			if !currency.Valid(oc) || oc == old.Currency {
				return apperr.FieldError("body.original_currency", "Provide a different, supported original currency.")
			}
			oa, err := ParseAmount("body.original_amount", strOr(p.OriginalAmount), oc)
			if err != nil {
				return err
			}
			nt.OriginalAmount, nt.OriginalCurrency = &oa, &oc
		}
		loc := u.Loc
		if p.Timezone != nil {
			l, err := time.LoadLocation(*p.Timezone)
			if err != nil || *p.Timezone == "Local" {
				return apperr.FieldError("body.timezone", "Unknown time zone.")
			}
			nt.Timezone, loc = *p.Timezone, l
		} else if l, err := time.LoadLocation(old.Timezone); err == nil {
			loc = l
		}
		switch {
		case p.OccurredAt != nil:
			nt.OccurredAt = *p.OccurredAt
			l := nt.OccurredAt.In(loc)
			nt.LocalDate = time.Date(l.Year(), l.Month(), l.Day(), 0, 0, 0, 0, time.UTC)
		case p.LocalDate != nil:
			ld, err := ParseDate("body.local_date", *p.LocalDate, loc)
			if err != nil {
				return err
			}
			nt.LocalDate = ld
			nt.OccurredAt = time.Date(ld.Year(), ld.Month(), ld.Day(), 12, 0, 0, 0, loc)
		}
		if p.Status != nil && *p.Status != old.Status {
			if !ledger.CanTransition(old.Status, *p.Status) {
				return apperr.Rule("invalid_status_transition", "A transaction cannot move from "+old.Status+" to "+*p.Status+".",
					map[string]string{"from": old.Status, "to": *p.Status})
			}
			nt.Status = *p.Status
		}
		// Refund cap (as a refund) and refunded-total floor (as an original).
		if old.OriginalTxID != nil && (nt.Amount != old.Amount || nt.IsCorrection != old.IsCorrection) {
			var oAmt, already int64
			if err := tx.QueryRow(ctx, `select o.amount_minor, coalesce((select sum(r.amount_minor) from transactions r
				where r.original_transaction_id = o.id and r.deleted_at is null and r.type in ('refund','reimbursement') and r.id <> $2), 0)::bigint
				from transactions o where o.id = $1 for update`, *old.OriginalTxID, id).Scan(&oAmt, &already); err != nil {
				return err
			}
			if err := ledger.CheckRefundCap(oAmt, already, nt.Amount, nt.IsCorrection); err != nil {
				return apperr.Rule("refund_exceeds_remaining", "Refunds and reimbursements cannot exceed the original amount ("+money.Format(oAmt-already, old.Currency)+" remaining).",
					map[string]string{"remaining": money.Format(oAmt-already, old.Currency), "currency": old.Currency})
			}
		}
		if nt.Amount < old.Amount && ledger.RefundableTypes(old.Type) {
			var refunded int64
			if err := tx.QueryRow(ctx, `select coalesce(sum(amount_minor), 0)::bigint from transactions where original_transaction_id = $1
				and deleted_at is null and type in ('refund','reimbursement')`, id).Scan(&refunded); err != nil {
				return err
			}
			if nt.Amount < refunded {
				return apperr.Rule("amount_below_refunds", "The amount cannot be lower than the refunds already recorded ("+money.Format(refunded, old.Currency)+").",
					map[string]string{"refunded": money.Format(refunded, old.Currency), "currency": old.Currency})
			}
		}
		if p.ClearCategory {
			nt.CategoryID = nil
		} else if p.CategoryID != nil {
			if err := validateCategoryFor(ctx, tx, uid, *p.CategoryID, old.Type); err != nil {
				return err
			}
			nt.CategoryID = p.CategoryID
		}
		if p.ClearMerchant {
			nt.MerchantID = nil
		} else if p.MerchantID != nil || p.MerchantName != nil {
			mid, err := s.resolveMerchant(ctx, tx, uid, p.MerchantID, strOr(p.MerchantName))
			if err != nil {
				return err
			}
			nt.MerchantID = mid
		}
		if p.ClearPaymentMethod {
			nt.PaymentMethodID = nil
		} else if p.PaymentMethodID != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from payment_methods where id = $1 and user_id = $2 and archived_at is null)`,
				*p.PaymentMethodID, uid).Scan(&ok); err != nil {
				return err
			}
			if !ok {
				return apperr.FieldError("body.payment_method_id", "Payment method not found.")
			}
			nt.PaymentMethodID = p.PaymentMethodID
		}
		if p.Description != nil {
			nt.Description = trimPtr(p.Description, 500)
		}
		if p.Notes != nil {
			nt.Notes = trimPtr(p.Notes, 4000)
		}
		if err := rejectSensitiveText(strOr(nt.Description), strOr(nt.Notes)); err != nil {
			return err
		}
		if p.LocationText != nil {
			if strings.TrimSpace(*p.LocationText) != "" {
				var consent bool
				if err := tx.QueryRow(ctx, `select exists (select 1 from user_consents where user_id = $1 and consent_type = 'location' and revoked_at is null)`,
					uid).Scan(&consent); err != nil {
					return err
				}
				if !consent {
					return apperr.New(apperr.CodeConsentRequired, 403, "Enable location consent in Privacy settings to save a location.")
				}
			}
			nt.Location = trimPtr(p.LocationText, 200)
		}
		d.add("account_id", old.AccountID, nt.AccountID)
		d.add("amount_minor", old.Amount, nt.Amount)
		d.add("local_date", LocalDateString(old.LocalDate), LocalDateString(nt.LocalDate))
		d.add("status", old.Status, nt.Status)
		d.add("category_id", deref(old.CategoryID), deref(nt.CategoryID))
		d.add("merchant_id", deref(old.MerchantID), deref(nt.MerchantID))
		d.add("payment_method_id", deref(old.PaymentMethodID), deref(nt.PaymentMethodID))
		d.add("description", deref(old.Description), deref(nt.Description))
		d.add("notes_changed", false, strOr(old.Notes) != strOr(nt.Notes))
		d.add("original_amount_minor", deref(old.OriginalAmount), deref(nt.OriginalAmount))
		ledgerChanged := nt.AccountID != old.AccountID || nt.Amount != old.Amount || LocalDateString(nt.LocalDate) != LocalDateString(old.LocalDate) ||
			ledger.AffectsBalance(nt.Status) != ledger.AffectsBalance(old.Status)
		newVersion := old.Version + 1
		if ledgerChanged {
			if ledger.AffectsBalance(old.Status) {
				if err := reverseLedger(ctx, tx, uid, id, old.AccountID, old.Version, old.Direction, old.Amount, old.Currency, old.LocalDate); err != nil {
					return err
				}
			}
			if ledger.AffectsBalance(nt.Status) {
				if err := postLedger(ctx, tx, uid, id, nt.AccountID, newVersion, nt.Direction, nt.Amount, nt.Currency, nt.LocalDate); err != nil {
					return err
				}
			}
		}
		var rate *string
		if nt.OriginalAmount != nil && nt.OriginalCurrency != nil {
			r := ratePerUnit(nt.Amount, nt.Currency, *nt.OriginalAmount, *nt.OriginalCurrency)
			rate = &r
		}
		if _, err := tx.Exec(ctx, `update transactions set account_id = $2, amount_minor = $3, original_amount_minor = $4, original_currency = $5,
			fx_rate = $6::numeric, fx_rate_source = case when $4::bigint is null then null else coalesce(fx_rate_source, 'manual') end,
			occurred_at = $7, local_date = $8, timezone = $9, status = $10,
			posted_at = case when $10 = 'posted' then coalesce(posted_at, now()) else posted_at end,
			category_id = $11, merchant_id = $12, payment_method_id = $13, description = $14, notes = $15, location_text = $16,
			is_correction = $17, version = $18 where id = $1`, id, nt.AccountID, nt.Amount, nt.OriginalAmount, nt.OriginalCurrency, rate,
			nt.OccurredAt, nt.LocalDate, nt.Timezone, nt.Status, nt.CategoryID, nt.MerchantID, nt.PaymentMethodID, nt.Description, nt.Notes,
			nt.Location, nt.IsCorrection, newVersion); err != nil {
			return err
		}
		if p.TagIDs != nil || len(p.TagNames) > 0 {
			var ids []uuid.UUID
			if p.TagIDs != nil {
				ids = *p.TagIDs
			}
			if err := s.setTags(ctx, tx, uid, id, ids, p.TagNames, p.TagIDs != nil); err != nil {
				return err
			}
			d["tags"] = map[string]any{"changed": true}
		}
		if err := txAudit(ctx, tx, uid, id, "user", "updated", newVersion, d); err != nil {
			return err
		}
		if err := outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.updated", AggregateType: "transaction", AggregateID: id, UserID: &uid,
			Payload: map[string]any{"account_id": nt.AccountID, "local_date": LocalDateString(nt.LocalDate), "previous_local_date": LocalDateString(old.LocalDate)}}); err != nil {
			return err
		}
		out, err = getTx(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(err)
}

// VoidTransaction soft-deletes a transaction with reversing ledger entries.
// Transfers are voided as a unit. It is idempotent.
func (s *Service) VoidTransaction(ctx context.Context, id uuid.UUID) (*TransactionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *TransactionDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if err := s.voidInTx(ctx, tx, uid, id); err != nil {
			return err
		}
		out, err = getTx(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(err)
}

// VoidInTx voids a transaction inside an existing transaction (imports
// rollback, reconciliation), with the same rules and audit as the API.
func (s *Service) VoidInTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) error {
	return s.voidInTx(ctx, tx, uid, id)
}

// RestoreInTx restores a voided transaction inside an existing transaction
// (reconciliation unmatch).
func (s *Service) RestoreInTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) error {
	t, err := lockTx(ctx, tx, id, uid)
	if err != nil {
		return err
	}
	if t.Status != ledger.StatusVoided {
		return nil
	}
	if t.TransferID != nil {
		return s.setTransferVoided(ctx, tx, uid, *t.TransferID, false)
	}
	return restoreRow(ctx, tx, uid, t)
}

func (s *Service) voidInTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) error {
	t, err := lockTx(ctx, tx, id, uid)
	if err != nil {
		return err
	}
	if t.Status == ledger.StatusVoided {
		return nil
	}
	if t.TransferID != nil { // transfer legs and transfer fees void as a unit
		return s.setTransferVoided(ctx, tx, uid, *t.TransferID, true)
	}
	if t.Type == ledger.TypeGroupExpense || t.Type == ledger.TypeSettlement {
		return apperr.Rule("group_linked", "This transaction is linked to a group record; update it from the group.", nil)
	}
	var active int
	if err := tx.QueryRow(ctx, `select count(*) from transactions where original_transaction_id = $1 and deleted_at is null`, id).Scan(&active); err != nil {
		return err
	}
	if active > 0 {
		return apperr.Rule("has_linked_refunds", "Delete the linked refunds or reimbursements first.", nil)
	}
	return voidRow(ctx, tx, uid, t)
}

func voidRow(ctx context.Context, tx pgx.Tx, uid uuid.UUID, t *lockedTx) error {
	return voidRowAs(ctx, tx, uid, t, "user", nil)
}

// voidRowAs voids one row, recording who did it (user, system, integration).
func voidRowAs(ctx context.Context, tx pgx.Tx, uid uuid.UUID, t *lockedTx, actorKind string, extra map[string]any) error {
	if t.Status == ledger.StatusVoided {
		return nil
	}
	if ledger.AffectsBalance(t.Status) {
		if err := reverseLedger(ctx, tx, uid, t.ID, t.AccountID, t.Version, t.Direction, t.Amount, t.Currency, t.LocalDate); err != nil {
			return err
		}
	}
	nv := t.Version + 1
	if _, err := tx.Exec(ctx, `update transactions set status = 'voided', deleted_at = now(), version = $2 where id = $1`, t.ID, nv); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `update recurring_occurrences set status = 'scheduled', transaction_id = null where transaction_id = $1`, t.ID); err != nil {
		return err
	}
	changes := map[string]any{"previous_status": t.Status}
	for k, v := range extra {
		changes[k] = v
	}
	if err := txAudit(ctx, tx, uid, t.ID, actorKind, "voided", nv, changes); err != nil {
		return err
	}
	return outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.voided", AggregateType: "transaction", AggregateID: t.ID, UserID: &uid,
		Payload: map[string]any{"account_id": t.AccountID, "local_date": LocalDateString(t.LocalDate)}})
}

// RestoreTransaction restores a voided transaction (re-posting the ledger).
func (s *Service) RestoreTransaction(ctx context.Context, id uuid.UUID) (*TransactionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *TransactionDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		t, err := lockTx(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		if t.Status != ledger.StatusVoided {
			return apperr.Conflict("Only deleted transactions can be restored.")
		}
		if t.TransferID != nil {
			if err := s.setTransferVoided(ctx, tx, uid, *t.TransferID, false); err != nil {
				return err
			}
		} else {
			if err := restoreRow(ctx, tx, uid, t); err != nil {
				return err
			}
		}
		out, err = getTx(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(err)
}

func restoreRow(ctx context.Context, tx pgx.Tx, uid uuid.UUID, t *lockedTx) error {
	var status string
	if err := tx.QueryRow(ctx, `select status from financial_accounts where id = $1`, t.AccountID).Scan(&status); err != nil {
		return err
	}
	if status != "active" {
		return apperr.Rule("account_inactive", "Restore the account before restoring its transactions.", nil)
	}
	if t.OriginalTxID != nil {
		var oAmt, already int64
		var oStatus string
		if err := tx.QueryRow(ctx, `select o.amount_minor, o.status, coalesce((select sum(r.amount_minor) from transactions r
			where r.original_transaction_id = o.id and r.deleted_at is null and r.type in ('refund','reimbursement')), 0)::bigint
			from transactions o where o.id = $1 for update`, *t.OriginalTxID).Scan(&oAmt, &oStatus, &already); err != nil {
			return err
		}
		if oStatus == ledger.StatusVoided {
			return apperr.Rule("original_voided", "Restore the original transaction first.", nil)
		}
		if err := ledger.CheckRefundCap(oAmt, already, t.Amount, t.IsCorrection); err != nil {
			return apperr.Rule("restore_exceeds_original", "Restoring would exceed the original amount.", nil)
		}
	}
	nv := t.Version + 1
	if err := postLedger(ctx, tx, uid, t.ID, t.AccountID, nv, t.Direction, t.Amount, t.Currency, t.LocalDate); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `update transactions set status = 'posted', deleted_at = null, posted_at = coalesce(posted_at, now()), version = $2 where id = $1`,
		t.ID, nv); err != nil {
		return err
	}
	if err := txAudit(ctx, tx, uid, t.ID, "user", "restored", nv, nil); err != nil {
		return err
	}
	return outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.restored", AggregateType: "transaction", AggregateID: t.ID, UserID: &uid,
		Payload: map[string]any{"account_id": t.AccountID, "local_date": LocalDateString(t.LocalDate)}})
}

// DuplicateTransaction copies an expense/income as a new transaction.
func (s *Service) DuplicateTransaction(ctx context.Context, id uuid.UUID, key, localDate string) (*CreateResult, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var src *TransactionDTO
	if err := s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		src, err = getTx(ctx, tx, id, uid)
		return err
	}); err != nil {
		return nil, false, database.MapError(err)
	}
	if !src.Owned || (src.Type != ledger.TypeExpense && src.Type != ledger.TypeIncome) {
		return nil, false, apperr.Rule("cannot_duplicate", "Only your own expenses and income can be duplicated.", nil)
	}
	in := TransactionInput{Type: src.Type, AccountID: src.AccountID, Amount: src.Amount.Amount, LocalDate: localDate,
		Description: strOr(src.Description), Notes: strOr(src.Notes), PaymentMethodID: src.PaymentMethodID}
	if src.Category != nil {
		in.CategoryID = &src.Category.ID
	}
	if src.Merchant != nil {
		in.MerchantID = &src.Merchant.ID
	}
	for _, t := range src.Tags {
		in.TagIDs = append(in.TagIDs, t.ID)
	}
	if src.OriginalAmount != nil {
		in.OriginalAmount, in.OriginalCurrency = src.OriginalAmount.Amount, src.OriginalAmount.Currency
	}
	res, replayed, err := s.CreateTransaction(ctx, key, in)
	if err == nil && !replayed {
		_ = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
			return txAudit(ctx, tx, uid, res.Transaction.ID, "user", "duplicated", 1, map[string]any{"source_transaction_id": id})
		})
	}
	return res, replayed, err
}

// RefundInput records a refund or reimbursement against an original.
type RefundInput struct {
	Type         string     `json:"type,omitempty" enum:"refund,reimbursement" default:"refund"`
	Amount       string     `json:"amount"`
	AccountID    *uuid.UUID `json:"account_id,omitempty" doc:"Defaults to the original's account"`
	LocalDate    string     `json:"local_date,omitempty"`
	Description  string     `json:"description,omitempty" maxLength:"500"`
	Notes        string     `json:"notes,omitempty" maxLength:"4000"`
	IsCorrection bool       `json:"is_correction,omitempty"`
}

// CreateRefund links a (partial) refund or reimbursement to an original.
func (s *Service) CreateRefund(ctx context.Context, originalID uuid.UUID, key string, in RefundInput) (*CreateResult, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	typ := in.Type
	if typ == "" {
		typ = ledger.TypeRefund
	}
	acct := uuid.Nil
	if in.AccountID != nil {
		acct = *in.AccountID
	} else {
		if err := s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
			return tx.QueryRow(ctx, `select account_id from transactions where id = $1 and user_id = $2`, originalID, uid).Scan(&acct)
		}); err != nil {
			if database.IsNoRows(err) {
				return nil, false, apperr.NotFound("transaction")
			}
			return nil, false, database.MapError(err)
		}
	}
	return s.CreateTransaction(ctx, key, TransactionInput{Type: typ, AccountID: acct, Amount: in.Amount, LocalDate: in.LocalDate,
		Description: in.Description, Notes: in.Notes, OriginalTransactionID: &originalID, IsCorrection: in.IsCorrection})
}

// BulkUpdateInput changes many transactions atomically.
type BulkUpdateInput struct {
	TransactionIDs []uuid.UUID `json:"transaction_ids" minItems:"1" maxItems:"500"`
	CategoryID     *uuid.UUID  `json:"category_id,omitempty"`
	ClearCategory  bool        `json:"clear_category,omitempty"`
	AddTagIDs      []uuid.UUID `json:"add_tag_ids,omitempty" maxItems:"20"`
	RemoveTagIDs   []uuid.UUID `json:"remove_tag_ids,omitempty" maxItems:"20"`
	AccountID      *uuid.UUID  `json:"account_id,omitempty" doc:"Move to an account with the same currency"`
}

// BulkResult reports how many records changed.
type BulkResult struct {
	Updated int `json:"updated"`
}

// BulkUpdate applies the same change to many transactions (all or nothing).
func (s *Service) BulkUpdate(ctx context.Context, in BulkUpdateInput) (*BulkResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &BulkResult{}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var destCur string
		if in.AccountID != nil {
			var status string
			err := tx.QueryRow(ctx, `select currency, status from financial_accounts where id = $1 and user_id = $2`, *in.AccountID, uid).Scan(&destCur, &status)
			if database.IsNoRows(err) || status != "active" {
				return apperr.FieldError("body.account_id", "Choose one of your active accounts.")
			}
			if err != nil {
				return err
			}
		}
		for _, id := range dedupeIDs(in.TransactionIDs) {
			t, err := lockTx(ctx, tx, id, uid)
			if err != nil {
				return err
			}
			if t.Status == ledger.StatusVoided {
				continue
			}
			d := diff{}
			newCat := t.CategoryID
			if in.ClearCategory {
				newCat = nil
			} else if in.CategoryID != nil && !metadataOnlyTypes[t.Type] {
				if err := validateCategoryFor(ctx, tx, uid, *in.CategoryID, t.Type); err != nil {
					return err
				}
				newCat = in.CategoryID
			}
			d.add("category_id", deref(t.CategoryID), deref(newCat))
			newAcct := t.AccountID
			if in.AccountID != nil && *in.AccountID != t.AccountID {
				if metadataOnlyTypes[t.Type] {
					return apperr.Rule("cannot_move_transaction", "Transfers and system transactions cannot be moved between accounts.", nil)
				}
				if destCur != t.Currency {
					return apperr.Rule("currency_mismatch", "Transactions can only move between accounts with the same currency.", nil)
				}
				newAcct = *in.AccountID
				d.add("account_id", t.AccountID, newAcct)
			}
			nv := t.Version + 1
			if newAcct != t.AccountID && ledger.AffectsBalance(t.Status) {
				if err := reverseLedger(ctx, tx, uid, id, t.AccountID, t.Version, t.Direction, t.Amount, t.Currency, t.LocalDate); err != nil {
					return err
				}
				if err := postLedger(ctx, tx, uid, id, newAcct, nv, t.Direction, t.Amount, t.Currency, t.LocalDate); err != nil {
					return err
				}
			}
			if _, err := tx.Exec(ctx, `update transactions set category_id = $2, account_id = $3, version = $4 where id = $1`, id, newCat, newAcct, nv); err != nil {
				return err
			}
			if err := s.setTags(ctx, tx, uid, id, in.AddTagIDs, nil, false); err != nil {
				return err
			}
			if len(in.RemoveTagIDs) > 0 {
				if _, err := tx.Exec(ctx, `delete from transaction_tags where transaction_id = $1 and tag_id = any($2)`, id, in.RemoveTagIDs); err != nil {
					return err
				}
				d.add("tags_removed", 0, len(in.RemoveTagIDs))
			}
			if len(in.AddTagIDs) > 0 {
				d.add("tags_added", 0, len(in.AddTagIDs))
			}
			if err := txAudit(ctx, tx, uid, id, "user", "bulk_updated", nv, d); err != nil {
				return err
			}
			out.Updated++
		}
		return outbox.Emit(ctx, tx, outbox.Event{Type: "transactions.bulk_updated", AggregateType: "user", AggregateID: uid, UserID: &uid,
			Payload: map[string]any{"count": out.Updated}})
	})
	return out, database.MapError(err)
}

// BulkDelete voids many transactions atomically (requires confirmation).
func (s *Service) BulkDelete(ctx context.Context, ids []uuid.UUID, confirm bool) (*BulkResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if !confirm {
		return nil, apperr.FieldError("body.confirm", "Confirm the deletion.")
	}
	out := &BulkResult{}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		for _, id := range dedupeIDs(ids) {
			if err := s.voidInTx(ctx, tx, uid, id); err != nil {
				return err
			}
			out.Updated++
		}
		return nil
	})
	return out, database.MapError(err)
}

func dedupeIDs(ids []uuid.UUID) []uuid.UUID {
	seen := map[uuid.UUID]bool{}
	out := make([]uuid.UUID, 0, len(ids))
	for _, id := range ids {
		if !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
	}
	return out
}

// AttachFile links an uploaded file (receipt/document) to a transaction.
func (s *Service) AttachFile(ctx context.Context, txID, fileID uuid.UUID) (*TransactionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *TransactionDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		t, err := lockTx(ctx, tx, txID, uid)
		if err != nil {
			return err
		}
		var purpose, status string
		err = tx.QueryRow(ctx, `select purpose, status from files where id = $1 and owner_user_id = $2`, fileID, uid).Scan(&purpose, &status)
		if database.IsNoRows(err) {
			return apperr.FieldError("body.file_id", "File not found.")
		}
		if err != nil {
			return err
		}
		if status != "ready" && status != "uploaded" {
			return apperr.Rule("file_not_ready", "Finish uploading the file before attaching it.", nil)
		}
		switch purpose {
		case "receipt", "transaction_attachment", "bill_document", "subscription_invoice":
		default:
			return apperr.Rule("file_not_attachable", "This file cannot be attached to a transaction.", nil)
		}
		if _, err := tx.Exec(ctx, `insert into transaction_attachments (user_id, transaction_id, file_id) values ($1,$2,$3) on conflict do nothing`,
			uid, txID, fileID); err != nil {
			return err
		}
		if err := txAudit(ctx, tx, uid, txID, "user", "attachment_added", t.Version, map[string]any{"file_id": fileID}); err != nil {
			return err
		}
		out, err = getTx(ctx, tx, txID, uid)
		return err
	})
	return out, database.MapError(err)
}

// DetachFile unlinks a file from a transaction (the file itself remains).
func (s *Service) DetachFile(ctx context.Context, txID, fileID uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		t, err := lockTx(ctx, tx, txID, uid)
		if err != nil {
			return err
		}
		tag, err := tx.Exec(ctx, `delete from transaction_attachments where transaction_id = $1 and file_id = $2`, txID, fileID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("attachment")
		}
		return txAudit(ctx, tx, uid, txID, "user", "attachment_removed", t.Version, map[string]any{"file_id": fileID})
	}))
}

// AttachmentDTO is a file attached to a transaction.
type AttachmentDTO struct {
	FileID      uuid.UUID `json:"file_id"`
	Purpose     string    `json:"purpose"`
	Filename    *string   `json:"filename,omitempty"`
	ContentType *string   `json:"content_type,omitempty"`
	SizeBytes   *int64    `json:"size_bytes,omitempty"`
	AttachedAt  time.Time `json:"attached_at"`
}

// ListAttachments returns a transaction's attachments.
func (s *Service) ListAttachments(ctx context.Context, txID uuid.UUID) ([]AttachmentDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []AttachmentDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := getTx(ctx, tx, txID, uid); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select f.id, f.purpose, f.original_filename, f.detected_mime, f.size_bytes, ta.created_at
			from transaction_attachments ta join files f on f.id = ta.file_id
			where ta.transaction_id = $1 and f.status <> 'deleted' order by ta.created_at`, txID)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var a AttachmentDTO
			if err := rows.Scan(&a.FileID, &a.Purpose, &a.Filename, &a.ContentType, &a.SizeBytes, &a.AttachedAt); err != nil {
				return err
			}
			out = append(out, a)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// AuditEventDTO is one entry of a transaction's history.
type AuditEventDTO struct {
	ID        int64     `json:"id"`
	Action    string    `json:"action" enum:"created,updated,voided,restored,refund_added,reimbursement_added,reconciled,unreconciled,attachment_added,attachment_removed,bulk_updated,duplicated,imported,rule_categorized,receipt_linked,tags_changed"`
	ActorKind string    `json:"actor_kind" enum:"user,system,import,recurring,integration"`
	Version   int32     `json:"version"`
	Changes   AuditDiff `json:"changes" doc:"For updates: changed fields as {field: {from, to}} (amount_minor in minor units, ids as strings); other actions carry action-specific keys such as previous_status, reason, type"`
	CreatedAt time.Time `json:"created_at"`
}

// AuditDiff is an audit event's change set: mostly {field: {from, to}}.
type AuditDiff = json.RawMessage

// TransactionAudit returns the full audit history of an owned transaction.
func (s *Service) TransactionAudit(ctx context.Context, txID uuid.UUID) ([]AuditEventDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []AuditEventDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id, action, actor_kind, version, changes, created_at from transaction_audit_events
			where transaction_id = $1 and user_id = $2 order by id`, txID, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var e AuditEventDTO
			if err := rows.Scan(&e.ID, &e.Action, &e.ActorKind, &e.Version, &e.Changes, &e.CreatedAt); err != nil {
				return err
			}
			out = append(out, e)
		}
		if err := rows.Err(); err != nil {
			return err
		}
		if len(out) == 0 {
			return apperr.NotFound("transaction")
		}
		return nil
	})
	return out, database.MapError(err)
}
