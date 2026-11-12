package subscriptions

import (
	"context"
	"encoding/json"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
)

// SubscriptionPaymentInput links a recorded transaction as a subscription payment.
type SubscriptionPaymentInput struct {
	TransactionID uuid.UUID `json:"transaction_id"`
	UpdatePrice   bool      `json:"update_price,omitempty" doc:"If the charge differs from the current price, record a price change"`
}

// duplicate is a DUPLICATE error with a stable reason (details[0].code).
func duplicate(code, msg string) *apperr.Error {
	return apperr.New(apperr.CodeDuplicate, http.StatusConflict, msg).WithDetails(apperr.Detail{Code: code, Message: msg})
}

// linkPayment links a transaction as a payment of the subscription unless
// it already backs a subscription payment (then it returns false).
func linkPayment(ctx context.Context, tx pgx.Tx, subID, txID, uid uuid.UUID) (bool, error) {
	tag, err := tx.Exec(ctx, `insert into subscription_payments (subscription_id, transaction_id, user_id) values ($1,$2,$3)
		on conflict do nothing`, subID, txID, uid)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

// RecordPayment links an existing transaction (payment history; the ledger
// is not changed). A transaction backs at most one subscription payment.
func (s *Service) RecordPayment(ctx context.Context, key string, id uuid.UUID, in SubscriptionPaymentInput) (*SubscriptionDetail, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out SubscriptionDetail
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "subscription.payment", struct {
			ID uuid.UUID
			In SubscriptionPaymentInput
		}{id, in}, func() (SubscriptionDetail, error) {
			status, _, price, err := lockOwn(ctx, tx, uid, id)
			if err != nil {
				return SubscriptionDetail{}, err
			}
			if status == "cancelled" {
				return SubscriptionDetail{}, apperr.Rule("subscription_inactive", "Reactivate the subscription before recording new payments.", nil)
			}
			var amt int64
			var cur, subCur string
			var date time.Time
			if err := tx.QueryRow(ctx, `select amount_minor, currency, local_date from transactions where id = $1 and user_id = $2
				and deleted_at is null and status <> 'voided' and type in ('expense','group_expense')`, in.TransactionID, uid).Scan(&amt, &cur, &date); err != nil {
				if database.IsNoRows(err) {
					return SubscriptionDetail{}, apperr.FieldError("body.transaction_id", "Choose one of your expenses.")
				}
				return SubscriptionDetail{}, err
			}
			if err := tx.QueryRow(ctx, `select currency from subscriptions where id = $1`, id).Scan(&subCur); err != nil {
				return SubscriptionDetail{}, err
			}
			if cur != subCur {
				return SubscriptionDetail{}, apperr.FieldError("body.transaction_id", "The payment must be in the subscription currency ("+subCur+").")
			}
			var linkedTo uuid.UUID
			switch err := tx.QueryRow(ctx, `select subscription_id from subscription_payments where transaction_id = $1`, in.TransactionID).Scan(&linkedTo); {
			case err == nil && linkedTo == id:
				return SubscriptionDetail{}, duplicate("payment_already_linked", "This payment is already recorded for the subscription.")
			case err == nil:
				return SubscriptionDetail{}, duplicate("payment_linked_elsewhere", "This payment is already recorded for another subscription.")
			case !database.IsNoRows(err):
				return SubscriptionDetail{}, err
			}
			linked, err := linkPayment(ctx, tx, id, in.TransactionID, uid)
			if err != nil {
				return SubscriptionDetail{}, err
			}
			if !linked {
				return SubscriptionDetail{}, duplicate("payment_linked_elsewhere", "This payment is already recorded for another subscription.")
			}
			if err := event(ctx, tx, id, uid, "payment_recorded", nil, &amt, &in.TransactionID, date, "", ""); err != nil {
				return SubscriptionDetail{}, err
			}
			if in.UpdatePrice && amt != price {
				if _, err := tx.Exec(ctx, `update subscriptions set amount_minor = $2, version = version + 1 where id = $1`, id, amt); err != nil {
					return SubscriptionDetail{}, err
				}
				if err := event(ctx, tx, id, uid, "price_changed", &price, &amt, &in.TransactionID, date, "", ""); err != nil {
					return SubscriptionDetail{}, err
				}
			}
			u, err := finance.LoadUser(ctx, tx, uid)
			if err != nil {
				return SubscriptionDetail{}, err
			}
			if err := s.advanceRenewal(ctx, tx, id, u.Timezone); err != nil {
				return SubscriptionDetail{}, err
			}
			if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "subscription", EntityID: &id,
				Action: "payment_recorded", Changes: map[string]any{"transaction_id": in.TransactionID, "price_updated": in.UpdatePrice && amt != price}}); err != nil {
				return SubscriptionDetail{}, err
			}
			d, err := s.detail(ctx, tx, uid, id)
			if err != nil {
				return SubscriptionDetail{}, err
			}
			return *d, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// UnlinkPayment removes a payment link; the transaction itself is not
// changed. The history keeps the payment_recorded entry and gains a
// payment_unlinked one. A price change recorded from that payment stays
// (edit the price to undo it). The transaction can be linked again.
func (s *Service) UnlinkPayment(ctx context.Context, id, txID uuid.UUID) (*SubscriptionDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *SubscriptionDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, _, err := lockOwn(ctx, tx, uid, id); err != nil {
			return err
		}
		tag, err := tx.Exec(ctx, `delete from subscription_payments where subscription_id = $1 and transaction_id = $2`, id, txID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("payment")
		}
		var amt *int64
		if err := tx.QueryRow(ctx, `select amount_minor from transactions where id = $1`, txID).Scan(&amt); err != nil && !database.IsNoRows(err) {
			return err
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		if err := event(ctx, tx, id, uid, "payment_unlinked", nil, amt, &txID, localToday(s.now(), u.Timezone), "", ""); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "subscription", EntityID: &id,
			Action: "payment_unlinked", Changes: map[string]any{"transaction_id": txID}}); err != nil {
			return err
		}
		out, err = s.detail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// SubscriptionPaymentCandidate is an unlinked expense that may be a payment
// of the subscription.
type SubscriptionPaymentCandidate struct {
	TransactionID   uuid.UUID      `json:"transaction_id"`
	LocalDate       string         `json:"local_date"`
	Amount          apitypes.Money `json:"amount"`
	AccountName     string         `json:"account_name"`
	Merchant        *string        `json:"merchant,omitempty" doc:"Merchant name"`
	Description     *string        `json:"description,omitempty"`
	Reasons         []string       `json:"reasons" doc:"Why it was suggested (English; localize by reason_codes)"`
	ReasonCodes     []string       `json:"reason_codes" enum:"same_merchant,matches_name,same_amount,amount_close,on_renewal_date,near_renewal_date" doc:"Stable reasons in the order of reasons: same_merchant, or matches_name (the merchant or description equals the subscription name); same_amount, or amount_close (within 25% of the price); on_renewal_date, or near_renewal_date (within 10 days of expected_date)"`
	ExpectedDate    *string        `json:"expected_date,omitempty" doc:"The expected charge (renewal) date nearest to the transaction: the next renewal or the one before it"`
	DaysFromRenewal *int           `json:"days_from_renewal,omitempty" doc:"Transaction date minus expected_date, in days (negative = before)"`
}

// addMonths moves a date by whole months, clamping to the month's end (Mar
// 31 minus one month is Feb 28).
func addMonths(d time.Time, months int) time.Time {
	first := time.Date(d.Year(), d.Month()+time.Month(months), 1, 0, 0, 0, 0, time.UTC)
	last := first.AddDate(0, 1, -1).Day()
	return time.Date(first.Year(), first.Month(), min(d.Day(), last), 0, 0, 0, 0, time.UTC)
}

// previousRenewal steps one billing period back from a renewal date.
func previousRenewal(freq string, interval int16, unit *string, next time.Time) time.Time {
	n := int(max(interval, 1))
	switch freq {
	case "weekly":
		return next.AddDate(0, 0, -7)
	case "monthly":
		return addMonths(next, -1)
	case "quarterly":
		return addMonths(next, -3)
	case "semiannual":
		return addMonths(next, -6)
	case "yearly":
		return addMonths(next, -12)
	}
	if unit != nil {
		switch *unit {
		case "day":
			return next.AddDate(0, 0, -n)
		case "week":
			return next.AddDate(0, 0, -7*n)
		case "year":
			return addMonths(next, -12*n)
		}
	}
	return addMonths(next, -n)
}

func absInt(v int) int {
	if v < 0 {
		return -v
	}
	return v
}

// PaymentCandidates suggests recent unlinked expenses that may be payments
// of the subscription: same merchant (or name) first, then the closest
// amount and date. A transaction already linked to any subscription is
// never suggested.
func (s *Service) PaymentCandidates(ctx context.Context, id uuid.UUID) ([]SubscriptionPaymentCandidate, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []SubscriptionPaymentCandidate{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var owner uuid.UUID
		var name, cur, freq, status string
		var price int64
		var interval int16
		var unit *string
		var next *time.Time
		var merchant *uuid.UUID
		if err := tx.QueryRow(ctx, `select user_id, name, merchant_id, amount_minor, currency, billing_frequency, interval_count, interval_unit,
			next_renewal_date, status from subscriptions where id = $1`, id).Scan(&owner, &name, &merchant, &price, &cur, &freq, &interval, &unit,
			&next, &status); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("subscription")
			}
			return err
		}
		if owner != uid {
			return apperr.Forbidden()
		}
		if status == "cancelled" {
			return nil // reactivate before recording payments
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		today := localToday(s.now(), u.Timezone)
		from := today.AddDate(0, 0, -45)
		var expected []time.Time
		if next != nil {
			prev := previousRenewal(freq, interval, unit, *next)
			expected = []time.Time{prev, *next}
			if d := prev.AddDate(0, 0, -15); d.Before(from) {
				from = d
			}
		}
		if limit := today.AddDate(0, 0, -400); from.Before(limit) {
			from = limit
		}
		rows, err := tx.Query(ctx, `select t.id, t.local_date, t.amount_minor, a.name, m.name, t.description,
			coalesce(t.merchant_id = $4, false) from transactions t join financial_accounts a on a.id = t.account_id
			left join merchants m on m.id = t.merchant_id
			where t.user_id = $1 and t.deleted_at is null and t.status <> 'voided' and t.type in ('expense','group_expense')
			and t.currency = $2 and t.local_date >= $3
			and not exists (select 1 from subscription_payments p where p.transaction_id = t.id)
			and (coalesce(t.merchant_id = $4, false) or lower(btrim(m.name)) = lower(btrim($5)) or lower(btrim(t.description)) = lower(btrim($5))
			     or t.amount_minor between $6::bigint * 3 / 4 and $6::bigint * 5 / 4)
			order by t.local_date desc, t.created_at desc limit 200`, uid, cur, from, merchant, name, price)
		if err != nil {
			return err
		}
		type cand struct {
			SubscriptionPaymentCandidate
			date             time.Time
			sameMerchant     bool
			sameName         bool
			amountGap, dayGp int64
		}
		var list []cand
		norm := finance.NormalizeName(name)
		for rows.Next() {
			var c cand
			var amt int64
			if err := rows.Scan(&c.TransactionID, &c.date, &amt, &c.AccountName, &c.Merchant, &c.Description, &c.sameMerchant); err != nil {
				rows.Close()
				return err
			}
			c.LocalDate, c.Amount = finance.LocalDateString(c.date), apitypes.M(amt, cur)
			c.sameName = !c.sameMerchant && ((c.Merchant != nil && finance.NormalizeName(*c.Merchant) == norm) ||
				(c.Description != nil && finance.NormalizeName(*c.Description) == norm))
			c.amountGap = amt - price
			if c.amountGap < 0 {
				c.amountGap = -c.amountGap
			}
			c.Reasons, c.ReasonCodes = []string{}, []string{}
			reason := func(code, text string) {
				c.ReasonCodes, c.Reasons = append(c.ReasonCodes, code), append(c.Reasons, text)
			}
			switch {
			case c.sameMerchant:
				reason("same_merchant", "Same merchant")
			case c.sameName:
				reason("matches_name", "Merchant or description matches the subscription name")
			}
			switch {
			case amt == price:
				reason("same_amount", "Same amount as the price")
			case c.amountGap*4 <= price:
				reason("amount_close", "Amount within 25% of the price")
			}
			c.dayGp = 1 << 30
			for _, e := range expected {
				days := int(dateOnly(c.date).Sub(e).Hours() / 24)
				if int64(absInt(days)) < c.dayGp {
					c.dayGp = int64(absInt(days))
					ed := finance.LocalDateString(e)
					c.ExpectedDate, c.DaysFromRenewal = &ed, &days
				}
			}
			switch {
			case c.DaysFromRenewal != nil && *c.DaysFromRenewal == 0:
				reason("on_renewal_date", "On the expected renewal date")
			case c.DaysFromRenewal != nil && absInt(*c.DaysFromRenewal) <= 10:
				reason("near_renewal_date", "Within 10 days of the expected renewal date")
			}
			list = append(list, c)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		sort.SliceStable(list, func(i, j int) bool {
			a, b := list[i], list[j]
			switch {
			case a.sameMerchant != b.sameMerchant:
				return a.sameMerchant
			case a.sameName != b.sameName:
				return a.sameName
			case a.amountGap != b.amountGap:
				return a.amountGap < b.amountGap
			case a.dayGp != b.dayGp:
				return a.dayGp < b.dayGp
			}
			return a.date.After(b.date)
		})
		for i := 0; i < len(list) && i < 20; i++ {
			out = append(out, list[i].SubscriptionPaymentCandidate)
		}
		return nil
	})
	return out, database.MapError(err)
}

// ChecklistItemPatch changes one cancellation checklist item.
type ChecklistItemPatch struct {
	Item    *string `json:"item,omitempty" minLength:"1" maxLength:"200"`
	Done    *bool   `json:"done,omitempty"`
	Version int32   `json:"version,omitempty" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

// UpdateChecklistItem ticks, unticks or renames one item of the
// cancellation checklist (index is the item's position, from 0).
func (s *Service) UpdateChecklistItem(ctx context.Context, id uuid.UUID, index int, p ChecklistItemPatch) (*SubscriptionDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *SubscriptionDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, version, _, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if p.Version != 0 && p.Version != version {
			return apperr.VersionConflict()
		}
		var raw []byte
		if err := tx.QueryRow(ctx, `select cancellation_checklist from subscriptions where id = $1`, id).Scan(&raw); err != nil {
			return err
		}
		var items []CancellationChecklistItem
		if len(raw) > 0 {
			if err := json.Unmarshal(raw, &items); err != nil {
				return err
			}
		}
		if index < 0 || index >= len(items) {
			return apperr.NotFound("checklist item")
		}
		if p.Item != nil {
			if items[index].Item = strings.TrimSpace(*p.Item); items[index].Item == "" {
				return apperr.FieldError("body.item", "Checklist items need text.")
			}
		}
		if p.Done != nil {
			items[index].Done = *p.Done
		}
		b, err := json.Marshal(items)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update subscriptions set cancellation_checklist = $2, version = version + 1 where id = $1`, id, b); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "subscription", EntityID: &id,
			Action: "checklist_updated", Changes: map[string]any{"index": index, "fields": sentFields(p)}}); err != nil {
			return err
		}
		out, err = s.detail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}
