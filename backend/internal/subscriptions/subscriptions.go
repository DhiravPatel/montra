// Package subscriptions implements the subscription manager (spec §4.8,
// §20B.9): manual subscriptions that work without any bank connection,
// explainable detection candidates that the user confirms or dismisses,
// renewal and trial reminders, price history, normalized costs, duplicate
// warnings and a user-confirmed cancellation flow. Montra never cancels a
// subscription itself and detection never changes ledger records.
package subscriptions

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/domain/recurrence"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
)

// Service implements subscriptions.
type Service struct {
	DB      *database.DB
	Finance *finance.Service
	Now     func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func localToday(now time.Time, tz string) time.Time {
	loc, err := time.LoadLocation(tz)
	if err != nil {
		loc = time.UTC
	}
	return dateOnly(now.In(loc))
}

// CancellationChecklistItem is one step of a cancellation checklist.
type CancellationChecklistItem struct {
	Item string `json:"item" minLength:"1" maxLength:"200"`
	Done bool   `json:"done"`
}

// SubscriptionInput creates a subscription (updates use SubscriptionPatch).
type SubscriptionInput struct {
	Name                     string                      `json:"name" minLength:"1" maxLength:"120"`
	PlanName                 string                      `json:"plan_name,omitempty" maxLength:"120"`
	MerchantName             string                      `json:"merchant_name,omitempty" maxLength:"120"`
	CategoryID               *uuid.UUID                  `json:"category_id,omitempty"`
	Amount                   string                      `json:"amount" doc:"Price per billing cycle (decimal)"`
	Currency                 string                      `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Defaults to the payment account's currency, then your base currency"`
	BillingFrequency         string                      `json:"billing_frequency" enum:"weekly,monthly,quarterly,semiannual,yearly,custom"`
	IntervalCount            int16                       `json:"interval_count,omitempty" minimum:"1" maximum:"366" doc:"Custom frequency: every N units"`
	IntervalUnit             *string                     `json:"interval_unit,omitempty" enum:"day,week,month,year"`
	StartDate                string                      `json:"start_date" doc:"YYYY-MM-DD the subscription started"`
	NextRenewalDate          string                      `json:"next_renewal_date,omitempty" doc:"Defaults to the first renewal on or after today"`
	TrialEndsOn              string                      `json:"trial_ends_on,omitempty"`
	PaymentAccountID         *uuid.UUID                  `json:"payment_account_id,omitempty"`
	CancellationURL          string                      `json:"cancellation_url,omitempty" maxLength:"500" doc:"Official https:// page you verified"`
	CancellationInstructions string                      `json:"cancellation_instructions,omitempty" maxLength:"4000"`
	CancellationChecklist    []CancellationChecklistItem `json:"cancellation_checklist,omitempty" maxItems:"20"`
	InvoiceFileID            *uuid.UUID                  `json:"invoice_file_id,omitempty" doc:"An uploaded subscription_invoice file you own"`
	Notes                    string                      `json:"notes,omitempty" maxLength:"2000"`
	ReminderDaysBefore       []int16                     `json:"reminder_days_before,omitempty" maxItems:"5" doc:"Renewal reminder offsets (0-30 days); default [3]"`
	GroupID                  *uuid.UUID                  `json:"group_id,omitempty" doc:"Track as shared with a group you belong to"`
	Version                  int32                       `json:"version,omitempty" doc:"Not used when creating (accepted for compatibility)"`
}

// SubscriptionPayment is a recorded subscription payment.
type SubscriptionPayment struct {
	TransactionID *uuid.UUID      `json:"transaction_id,omitempty"`
	OccurredOn    string          `json:"occurred_on"`
	Amount        *apitypes.Money `json:"amount,omitempty"`
}

// DuplicateWarning flags a possible duplicate subscription.
type DuplicateWarning struct {
	SubscriptionID uuid.UUID         `json:"subscription_id"`
	Name           string            `json:"name"`
	Reason         string            `json:"reason" doc:"English; localize by reason_code"`
	ReasonCode     string            `json:"reason_code" enum:"same_merchant,same_name,same_price_and_cycle" doc:"Why it may be a duplicate"`
	ReasonParams   map[string]string `json:"reason_params" doc:"Values the code refers to: name (the other subscription); for same_price_and_cycle also amount, currency and billing_frequency"`
}

var duplicateReasons = map[string]string{
	"same_merchant": "Same merchant", "same_name": "Same name", "same_price_and_cycle": "Same price and billing cycle",
}

// SubscriptionDTO is a subscription.
type SubscriptionDTO struct {
	ID                       uuid.UUID                   `json:"id"`
	Name                     string                      `json:"name"`
	PlanName                 *string                     `json:"plan_name,omitempty"`
	Merchant                 *finance.MerchantRef        `json:"merchant,omitempty"`
	CategoryID               *uuid.UUID                  `json:"category_id,omitempty"`
	Amount                   apitypes.Money              `json:"amount"`
	BillingFrequency         string                      `json:"billing_frequency" enum:"weekly,monthly,quarterly,semiannual,yearly,custom"`
	IntervalCount            int16                       `json:"interval_count"`
	IntervalUnit             *string                     `json:"interval_unit,omitempty" enum:"day,week,month,year" doc:"Custom billing only"`
	StartDate                string                      `json:"start_date"`
	NextRenewalDate          *string                     `json:"next_renewal_date,omitempty"`
	TrialEndsOn              *string                     `json:"trial_ends_on,omitempty"`
	PaymentAccountID         *uuid.UUID                  `json:"payment_account_id,omitempty"`
	Status                   string                      `json:"status" enum:"trial,active,paused,cancellation_pending,cancelled"`
	Source                   string                      `json:"source" enum:"manual,detected"`
	DetectionCandidateID     *uuid.UUID                  `json:"detection_candidate_id,omitempty"`
	CancellationURL          *string                     `json:"cancellation_url,omitempty"`
	CancellationInstructions *string                     `json:"cancellation_instructions,omitempty"`
	CancellationChecklist    []CancellationChecklistItem `json:"cancellation_checklist"`
	InvoiceFileID            *uuid.UUID                  `json:"invoice_file_id,omitempty"`
	Notes                    *string                     `json:"notes,omitempty"`
	ReminderDaysBefore       []int16                     `json:"reminder_days_before"`
	LastVerifiedAt           *time.Time                  `json:"last_verified_at,omitempty"`
	CancelledOn              *string                     `json:"cancelled_on,omitempty" doc:"YYYY-MM-DD the cancellation took effect (canonical; a calendar date, no time zone)"`
	CancelledAt              *time.Time                  `json:"cancelled_at,omitempty" deprecated:"true" doc:"Deprecated: the same date as cancelled_on, as midnight UTC (converting it to a local time can shift the day); use cancelled_on"`
	GroupID                  *uuid.UUID                  `json:"group_id,omitempty"`
	MonthlyCost              apitypes.Money              `json:"monthly_cost" doc:"Normalized per month (exact, rounded half away from zero)"`
	AnnualCost               apitypes.Money              `json:"annual_cost" doc:"Yearly cost projection at the current price"`
	LastPayment              *SubscriptionPayment        `json:"last_payment,omitempty" doc:"The most recent linked payment"`
	DuplicateWarnings        []DuplicateWarning          `json:"duplicate_warnings"`
	Owned                    bool                        `json:"owned"`
	Version                  int32                       `json:"version"`
	CreatedAt                time.Time                   `json:"created_at"`
}

// SubscriptionEvent is a subscription history entry.
type SubscriptionEvent struct {
	ID            uuid.UUID       `json:"id"`
	Kind          string          `json:"kind" enum:"created,price_changed,renewed,payment_recorded,payment_unlinked,trial_started,trial_ending,paused,resumed,cancellation_started,cancelled,reactivated,verified,edited"`
	OldAmount     *apitypes.Money `json:"old_amount,omitempty" doc:"price_changed: the previous price"`
	NewAmount     *apitypes.Money `json:"new_amount,omitempty" doc:"price_changed: the new price; created: the price; payment_recorded and payment_unlinked: the payment amount"`
	TransactionID *uuid.UUID      `json:"transaction_id,omitempty" doc:"payment_recorded, payment_unlinked, and price_changed from a payment"`
	OccurredOn    string          `json:"occurred_on"`
	Note          *string         `json:"note,omitempty" doc:"Your note, or English text written by Montra (then note_code is set)"`
	NoteCode      *string         `json:"note_code,omitempty" enum:"matched_by_detection" doc:"Set when Montra wrote the note; localize by it. matched_by_detection: the payment was linked when you confirmed a detection"`
	CreatedAt     time.Time       `json:"created_at"`
}

// System note texts and their codes.
const (
	noteMatchedByDetection     = "Matched by detection"
	noteCodeMatchedByDetection = "matched_by_detection"
)

// SubscriptionDetail adds history (price changes, payments, lifecycle).
type SubscriptionDetail struct {
	SubscriptionDTO
	Events   []SubscriptionEvent `json:"events"`
	Payments []LinkedPayment     `json:"payments" doc:"Payments currently linked (newest first, up to 500); the history of links is in events"`
}

// LinkedPayment is a recorded transaction currently linked as a payment.
type LinkedPayment struct {
	TransactionID uuid.UUID      `json:"transaction_id"`
	LocalDate     string         `json:"local_date"`
	Amount        apitypes.Money `json:"amount"`
	AccountName   *string        `json:"account_name,omitempty"`
	LinkedAt      time.Time      `json:"linked_at"`
}

// PeriodsPerYear returns billing cycles per year as a fraction num/den.
func PeriodsPerYear(freq string, interval int16, unit *string) (num, den int64) {
	switch freq {
	case "weekly":
		return 52, 1
	case "monthly":
		return 12, 1
	case "quarterly":
		return 4, 1
	case "semiannual":
		return 2, 1
	case "yearly":
		return 1, 1
	}
	n := int64(max(interval, 1))
	if unit == nil {
		return 12, n
	}
	switch *unit {
	case "day":
		return 365, n
	case "week":
		return 52, n
	case "year":
		return 1, n
	}
	return 12, n
}

// RenewalSchedule builds the renewal recurrence anchored at the next
// renewal date. When that date was clamped to a short month's end, the
// original billing day (from the start date) is kept, so Jan 31 renews on
// Feb 28 and then Mar 31.
func RenewalSchedule(freq string, interval int16, unit *string, start, next time.Time) recurrence.Rule {
	r := recurrence.Rule{Frequency: freq, Start: dateOnly(next)}
	if freq == "custom" {
		r.Interval = int(max(interval, 1))
		if unit != nil {
			r.Unit = *unit
		}
	}
	monthly := freq == "monthly" || freq == "quarterly" || freq == "semiannual" || freq == "yearly" ||
		(freq == "custom" && unit != nil && (*unit == "month" || *unit == "year"))
	if monthly {
		lastDay := time.Date(next.Year(), next.Month()+1, 0, 0, 0, 0, 0, time.UTC).Day()
		if next.Day() == lastDay && start.Day() > next.Day() {
			r.ByMonthDay = start.Day()
		}
	}
	return r
}

const subCols = `s.id, s.name, s.plan_name, s.merchant_id, m.name, s.category_id, s.amount_minor, s.currency, s.billing_frequency,
	s.interval_count, s.interval_unit, s.start_date, s.next_renewal_date, s.trial_ends_on, s.payment_account_id, s.status, s.source,
	s.detection_candidate_id, s.cancellation_url, s.cancellation_instructions, s.cancellation_checklist, s.invoice_file_id, s.notes,
	s.reminder_days_before, s.last_verified_at, s.cancelled_at, s.group_id, s.version, s.created_at, s.user_id`

const subFrom = ` from subscriptions s left join merchants m on m.id = s.merchant_id`

type row struct {
	SubscriptionDTO
	owner  uuid.UUID
	amount int64
	cur    string
	start  time.Time
	next   *time.Time
	trial  *time.Time
}

func scan(r pgx.Row, me uuid.UUID) (*row, error) {
	var x row
	var merchID *uuid.UUID
	var merchName *string
	var checklist []byte
	if err := r.Scan(&x.ID, &x.Name, &x.PlanName, &merchID, &merchName, &x.CategoryID, &x.amount, &x.cur, &x.BillingFrequency,
		&x.IntervalCount, &x.IntervalUnit, &x.start, &x.next, &x.trial, &x.PaymentAccountID, &x.Status, &x.Source,
		&x.DetectionCandidateID, &x.CancellationURL, &x.CancellationInstructions, &checklist, &x.InvoiceFileID, &x.Notes,
		&x.ReminderDaysBefore, &x.LastVerifiedAt, &x.CancelledAt, &x.GroupID, &x.Version, &x.CreatedAt, &x.owner); err != nil {
		return nil, err
	}
	x.Owned = x.owner == me
	if merchID != nil && merchName != nil {
		x.Merchant = &finance.MerchantRef{ID: *merchID, Name: *merchName}
	}
	x.Amount = apitypes.M(x.amount, x.cur)
	x.StartDate = finance.LocalDateString(x.start)
	if x.next != nil {
		n := finance.LocalDateString(*x.next)
		x.NextRenewalDate = &n
	}
	if x.trial != nil {
		t := finance.LocalDateString(*x.trial)
		x.TrialEndsOn = &t
	}
	if x.CancelledAt != nil {
		// Stored as the cancellation date at midnight UTC.
		d := finance.LocalDateString(x.CancelledAt.UTC())
		x.CancelledOn = &d
	}
	x.CancellationChecklist = []CancellationChecklistItem{}
	if len(checklist) > 0 {
		if err := json.Unmarshal(checklist, &x.CancellationChecklist); err != nil {
			return nil, err
		}
	}
	if x.ReminderDaysBefore == nil {
		x.ReminderDaysBefore = []int16{}
	}
	num, den := PeriodsPerYear(x.BillingFrequency, x.IntervalCount, x.IntervalUnit)
	annual, err := money.MulRatio(x.amount, num, den)
	if err != nil {
		return nil, err
	}
	monthly, err := money.MulRatio(x.amount, num, den*12)
	if err != nil {
		return nil, err
	}
	x.AnnualCost, x.MonthlyCost = apitypes.M(annual, x.cur), apitypes.M(monthly, x.cur)
	x.DuplicateWarnings = []DuplicateWarning{}
	return &x, nil
}

// enrich adds the last payment and duplicate warnings.
func (s *Service) enrich(ctx context.Context, tx pgx.Tx, x *row) error {
	var txID uuid.UUID
	var d time.Time
	var amt int64
	var cur string
	err := tx.QueryRow(ctx, `select p.transaction_id, t.local_date, t.amount_minor, t.currency from subscription_payments p
		join transactions t on t.id = p.transaction_id where p.subscription_id = $1
		order by t.local_date desc, p.created_at desc limit 1`, x.ID).Scan(&txID, &d, &amt, &cur)
	switch {
	case err == nil:
		m := apitypes.M(amt, cur)
		x.LastPayment = &SubscriptionPayment{TransactionID: &txID, OccurredOn: finance.LocalDateString(d), Amount: &m}
	case !database.IsNoRows(err):
		return err
	}
	if x.Status == "cancelled" {
		return nil
	}
	rows, err := tx.Query(ctx, `select id, name, case
			when $3::uuid is not null and merchant_id = $3 then 'same_merchant'
			when lower(name) = lower($2) then 'same_name'
			else 'same_price_and_cycle' end
		from subscriptions where user_id = $1 and id <> $4 and status <> 'cancelled' and (
			($3::uuid is not null and merchant_id = $3) or lower(name) = lower($2)
			or (amount_minor = $5 and currency = $6 and billing_frequency = $7))
		order by name limit 5`, x.owner, x.Name, merchantID(x), x.ID, x.amount, x.cur, x.BillingFrequency)
	if err != nil {
		return err
	}
	x.DuplicateWarnings, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (DuplicateWarning, error) {
		var w DuplicateWarning
		err := r.Scan(&w.SubscriptionID, &w.Name, &w.ReasonCode)
		w.Reason, w.ReasonParams = duplicateReasons[w.ReasonCode], map[string]string{"name": w.Name}
		if w.ReasonCode == "same_price_and_cycle" {
			w.ReasonParams["amount"], w.ReasonParams["currency"], w.ReasonParams["billing_frequency"] = x.Amount.Amount, x.cur, x.BillingFrequency
		}
		return w, err
	})
	return err
}

func merchantID(x *row) *uuid.UUID {
	if x.Merchant == nil {
		return nil
	}
	return &x.Merchant.ID
}

func (s *Service) load(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (*row, error) {
	x, err := scan(tx.QueryRow(ctx, `select `+subCols+subFrom+` where s.id = $1`, id), me)
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("subscription")
	}
	if err != nil {
		return nil, err
	}
	return x, s.enrich(ctx, tx, x)
}

func (s *Service) detail(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (*SubscriptionDetail, error) {
	x, err := s.load(ctx, tx, me, id)
	if err != nil {
		return nil, err
	}
	out := &SubscriptionDetail{SubscriptionDTO: x.SubscriptionDTO, Events: []SubscriptionEvent{}}
	rows, err := tx.Query(ctx, `select id, kind, old_amount_minor, new_amount_minor, transaction_id, occurred_on, note, note_code, created_at
		from subscription_events where subscription_id = $1 order by occurred_on desc, created_at desc limit 200`, id)
	if err != nil {
		return nil, err
	}
	out.Events, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (SubscriptionEvent, error) {
		var e SubscriptionEvent
		var oldA, newA *int64
		var d time.Time
		if err := r.Scan(&e.ID, &e.Kind, &oldA, &newA, &e.TransactionID, &d, &e.Note, &e.NoteCode, &e.CreatedAt); err != nil {
			return e, err
		}
		e.OldAmount, e.NewAmount, e.OccurredOn = apitypes.MP(oldA, x.cur), apitypes.MP(newA, x.cur), finance.LocalDateString(d)
		return e, nil
	})
	if err != nil {
		return nil, err
	}
	prow, err := tx.Query(ctx, `select p.transaction_id, t.local_date, t.amount_minor, t.currency, a.name, p.created_at
		from subscription_payments p join transactions t on t.id = p.transaction_id left join financial_accounts a on a.id = t.account_id
		where p.subscription_id = $1 and t.deleted_at is null order by t.local_date desc, p.created_at desc limit 500`, id)
	if err != nil {
		return nil, err
	}
	out.Payments, err = pgx.CollectRows(prow, func(r pgx.CollectableRow) (LinkedPayment, error) {
		var p LinkedPayment
		var d time.Time
		var amt int64
		var cur string
		if err := r.Scan(&p.TransactionID, &d, &amt, &cur, &p.AccountName, &p.LinkedAt); err != nil {
			return p, err
		}
		p.LocalDate, p.Amount = finance.LocalDateString(d), apitypes.M(amt, cur)
		return p, nil
	})
	return out, err
}

func trim(s string, n int) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	if r := []rune(s); len(r) > n {
		s = string(r[:n])
	}
	return &s
}

// event appends a history entry; noteCode marks a note Montra wrote.
func event(ctx context.Context, tx pgx.Tx, subID, uid uuid.UUID, kind string, oldA, newA *int64, txID *uuid.UUID, on time.Time, note, noteCode string) error {
	var code *string
	if noteCode != "" {
		code = &noteCode
	}
	_, err := tx.Exec(ctx, `insert into subscription_events (subscription_id, user_id, kind, old_amount_minor, new_amount_minor, transaction_id,
		occurred_on, note, note_code) values ($1,$2,$3,$4,$5,$6,$7,$8,$9)`, subID, uid, kind, oldA, newA, txID, on, trim(note, 500), code)
	return err
}

// Create creates a manual subscription (idempotent per key: a retry with
// the same key returns the original result).
func (s *Service) Create(ctx context.Context, key string, in SubscriptionInput) (*SubscriptionDetail, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out SubscriptionDetail
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "subscription.create", in, func() (SubscriptionDetail, error) {
			id, err := s.create(ctx, tx, uid, in, "manual", nil)
			if err != nil {
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

// openSubscriptionsQ counts a user's subscriptions for the fair-use cap.
const openSubscriptionsQ = `select count(*) from subscriptions where user_id = $1 and status <> 'cancelled'`

func (s *Service) create(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in SubscriptionInput, source string, candidate *uuid.UUID) (uuid.UUID, error) {
	if err := caps.Check(ctx, tx, uid, "subscriptions", openSubscriptionsQ, caps.OpenSubscriptions); err != nil {
		return uuid.Nil, err
	}
	u, err := finance.LoadUser(ctx, tx, uid)
	if err != nil {
		return uuid.Nil, err
	}
	n, p := newDefinition(), in.patch()
	if err := s.apply(ctx, tx, u, n, &p, "", true); err != nil {
		return uuid.Nil, err
	}
	id := uuid.New()
	if _, err := tx.Exec(ctx, `insert into subscriptions (id, user_id, group_id, name, plan_name, merchant_id, category_id, amount_minor, currency,
		billing_frequency, interval_count, interval_unit, start_date, next_renewal_date, trial_ends_on, payment_account_id, status, source,
		detection_candidate_id, cancellation_url, cancellation_instructions, cancellation_checklist, invoice_file_id, notes, reminder_days_before)
		values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25)`,
		id, uid, n.group, n.name, n.plan, n.merchant, n.category, n.amount, n.cur, n.freq, n.interval, n.unit, n.start, n.next, n.trial,
		n.account, n.status, source, candidate, n.url, n.instructions, n.checklist, n.invoice, n.notes, n.reminders); err != nil {
		return uuid.Nil, err
	}
	today := localToday(s.now(), u.Timezone)
	if err := event(ctx, tx, id, uid, "created", nil, &n.amount, nil, today, "", ""); err != nil {
		return uuid.Nil, err
	}
	if n.status == "trial" {
		if err := event(ctx, tx, id, uid, "trial_started", nil, nil, nil, n.start, "", ""); err != nil {
			return uuid.Nil, err
		}
	}
	return id, audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "subscription", EntityID: &id, Action: "created",
		Changes: map[string]any{"source": source}})
}

// List returns subscriptions (all non-cancelled by default).
func (s *Service) List(ctx context.Context, status string) ([]SubscriptionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []SubscriptionDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+subCols+subFrom+` where ($1 = 'all' or ($1 = '' and s.status <> 'cancelled') or s.status = $1)
			order by s.next_renewal_date nulls last, s.name limit 500`, status)
		if err != nil {
			return err
		}
		var list []*row
		for rows.Next() {
			x, err := scan(rows, uid)
			if err != nil {
				rows.Close()
				return err
			}
			list = append(list, x)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		for _, x := range list {
			if err := s.enrich(ctx, tx, x); err != nil {
				return err
			}
			out = append(out, x.SubscriptionDTO)
		}
		return nil
	})
	return out, database.MapError(err)
}

// Get returns a subscription with its history.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*SubscriptionDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *SubscriptionDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		out, err = s.detail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// lockOwn locks a subscription the caller owns.
func lockOwn(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (status string, version int32, amount int64, err error) {
	var owner uuid.UUID
	if err := tx.QueryRow(ctx, `select user_id, status, version, amount_minor from subscriptions where id = $1`, id).
		Scan(&owner, &status, &version, &amount); err != nil {
		if database.IsNoRows(err) {
			return "", 0, 0, apperr.NotFound("subscription")
		}
		return "", 0, 0, err
	}
	if owner != uid {
		return "", 0, 0, apperr.Forbidden()
	}
	if _, err := tx.Exec(ctx, `select 1 from subscriptions where id = $1 for update`, id); err != nil {
		return "", 0, 0, err
	}
	return status, version, amount, nil
}

// Update applies a partial update (SubscriptionPatch): fields that are not
// sent keep their values. A price change is recorded in the price history;
// any other change as an edit.
func (s *Service) Update(ctx context.Context, id uuid.UUID, p SubscriptionPatch) (*SubscriptionDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *SubscriptionDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		status, version, _, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if p.Version != 0 && p.Version != version {
			return apperr.VersionConflict()
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		cur, err := loadDefinition(ctx, tx, id)
		if err != nil {
			return err
		}
		n := *cur
		if err := s.apply(ctx, tx, u, &n, &p, status, false); err != nil {
			return err
		}
		var cancelledAt *time.Time
		if p.CancelledOn != nil {
			if status != "cancelled" {
				return apperr.Rule("subscription_not_cancelled", "Only a cancelled subscription has a cancellation date.",
					map[string]string{"status": status})
			}
			d, err := finance.ParseDate("body.cancelled_on", *p.CancelledOn, u.Loc)
			if err != nil {
				return err
			}
			d = dateOnly(d)
			cancelledAt = &d
		}
		if status == "trial" || status == "active" {
			status = n.status
		}
		if _, err := tx.Exec(ctx, `update subscriptions set name = $2, plan_name = $3, merchant_id = $4, category_id = $5, amount_minor = $6,
			currency = $7, billing_frequency = $8, interval_count = $9, interval_unit = $10, start_date = $11, next_renewal_date = $12,
			trial_ends_on = $13, payment_account_id = $14, cancellation_url = $15, cancellation_instructions = $16, cancellation_checklist = $17,
			invoice_file_id = $18, notes = $19, reminder_days_before = $20, group_id = $21, status = $22,
			cancelled_at = coalesce($23, cancelled_at), version = version + 1 where id = $1`,
			id, n.name, n.plan, n.merchant, n.category, n.amount, n.cur, n.freq, n.interval, n.unit, n.start, n.next, n.trial, n.account,
			n.url, n.instructions, n.checklist, n.invoice, n.notes, n.reminders, n.group, status, cancelledAt); err != nil {
			return err
		}
		kind := "edited"
		var oldA, newA *int64
		if n.cur == cur.cur && n.amount != cur.amount {
			kind, oldA, newA = "price_changed", &cur.amount, &n.amount
		}
		if err := event(ctx, tx, id, uid, kind, oldA, newA, nil, localToday(s.now(), u.Timezone), "", ""); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "subscription", EntityID: &id, Action: kind,
			Changes: map[string]any{"fields": sentFields(p)}}); err != nil {
			return err
		}
		out, err = s.detail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// transitions lists allowed lifecycle actions: from-states → (to-state, event).
var transitions = map[string]struct {
	from  []string
	to    string
	event string
}{
	"pause":                {[]string{"trial", "active"}, "paused", "paused"},
	"resume":               {[]string{"paused"}, "active", "resumed"},
	"cancellation_started": {[]string{"trial", "active", "paused"}, "cancellation_pending", "cancellation_started"},
	"cancelled":            {[]string{"trial", "active", "paused", "cancellation_pending"}, "cancelled", "cancelled"},
	"reactivate":           {[]string{"cancelled", "cancellation_pending"}, "active", "reactivated"},
	"verify":               {[]string{"trial", "active", "paused", "cancellation_pending", "cancelled"}, "", "verified"},
}

// SubscriptionActionInput carries lifecycle details.
type SubscriptionActionInput struct {
	Confirm     bool   `json:"confirm,omitempty" doc:"Required for cancelled: you confirm the provider cancelled it"`
	EffectiveOn string `json:"effective_on,omitempty" doc:"YYYY-MM-DD the change took effect (its history date); default today"`
	CancelledOn string `json:"cancelled_on,omitempty" doc:"cancelled only: YYYY-MM-DD the cancellation took effect (returned as cancelled_on); default effective_on, then today"`
	Note        string `json:"note,omitempty" maxLength:"500"`
}

// Act applies a lifecycle action. Cancellation is recorded only after the
// user confirms it happened with the provider; Montra never cancels.
// version, when not 0, must be the current version (else VERSION_CONFLICT).
func (s *Service) Act(ctx context.Context, id uuid.UUID, action string, version int32, in SubscriptionActionInput) (*SubscriptionDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	t, ok := transitions[action]
	if !ok {
		return nil, apperr.BadRequest("Unknown action.")
	}
	if action == "cancelled" && !in.Confirm {
		msg := "Confirm that the provider has cancelled this subscription. Montra does not cancel subscriptions for you."
		return nil, apperr.Validation(msg, apperr.Detail{Field: "body.confirm", Code: "cancellation_confirmation_required", Message: msg})
	}
	if in.CancelledOn != "" && action != "cancelled" {
		return nil, apperr.FieldError("body.cancelled_on", "cancelled_on is only used when marking a subscription cancelled.")
	}
	var out *SubscriptionDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		status, current, _, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if version != 0 && version != current {
			return apperr.VersionConflict()
		}
		allowed := false
		for _, f := range t.from {
			allowed = allowed || f == status
		}
		if !allowed {
			return apperr.Rule("invalid_status_transition", "A subscription cannot move from "+status+" to "+t.to+".",
				map[string]string{"from": status, "to": t.to})
		}
		if status == "cancelled" && t.to != "cancelled" {
			if err := caps.Check(ctx, tx, uid, "subscriptions", openSubscriptionsQ, caps.OpenSubscriptions); err != nil {
				return err
			}
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		on := localToday(s.now(), u.Timezone)
		if in.EffectiveOn != "" {
			d, err := finance.ParseDate("body.effective_on", in.EffectiveOn, u.Loc)
			if err != nil {
				return err
			}
			on = dateOnly(d)
		}
		if in.CancelledOn != "" {
			d, err := finance.ParseDate("body.cancelled_on", in.CancelledOn, u.Loc)
			if err != nil {
				return err
			}
			if d = dateOnly(d); in.EffectiveOn != "" && !d.Equal(on) {
				return apperr.FieldError("body.cancelled_on", "cancelled_on and effective_on differ; send one of them.")
			}
			on = d
		}
		switch action {
		case "verify":
			_, err = tx.Exec(ctx, `update subscriptions set last_verified_at = now(), version = version + 1 where id = $1`, id)
		case "cancelled":
			_, err = tx.Exec(ctx, `update subscriptions set status = 'cancelled', cancelled_at = $2, cancellation_confirmed_by = $3,
				next_renewal_date = null, version = version + 1 where id = $1`, id, on, uid)
		case "reactivate", "resume":
			_, err = tx.Exec(ctx, `update subscriptions set status = $2, cancelled_at = null, cancellation_confirmed_by = null,
				version = version + 1 where id = $1`, id, t.to)
			if err == nil {
				err = s.advanceRenewal(ctx, tx, id, u.Timezone)
			}
		default:
			_, err = tx.Exec(ctx, `update subscriptions set status = $2, version = version + 1 where id = $1`, id, t.to)
		}
		if err != nil {
			return err
		}
		if err := event(ctx, tx, id, uid, t.event, nil, nil, nil, on, in.Note, ""); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "subscription", EntityID: &id, Action: action}); err != nil {
			return err
		}
		out, err = s.detail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// advanceRenewal moves next_renewal_date to the first renewal on/after
// today (renewals that passed are expected charges, not recorded payments).
func (s *Service) advanceRenewal(ctx context.Context, tx pgx.Tx, id uuid.UUID, tz string) error {
	var freq string
	var interval int16
	var unit *string
	var start time.Time
	var next *time.Time
	if err := tx.QueryRow(ctx, `select billing_frequency, interval_count, interval_unit, start_date, next_renewal_date from subscriptions where id = $1`, id).
		Scan(&freq, &interval, &unit, &start, &next); err != nil {
		return err
	}
	today := localToday(s.now(), tz)
	if next != nil && !next.Before(today) {
		return nil
	}
	anchor := start
	if next != nil {
		anchor = *next
	}
	n, ok := RenewalSchedule(freq, interval, unit, start, anchor).Next(today)
	if !ok {
		return nil
	}
	_, err := tx.Exec(ctx, `update subscriptions set next_renewal_date = $2 where id = $1`, id, n)
	return err
}

// SubscriptionCostTotal is a per-currency total of active subscriptions.
type SubscriptionCostTotal struct {
	Currency string         `json:"currency"`
	Monthly  apitypes.Money `json:"monthly"`
	Annual   apitypes.Money `json:"annual"`
	Count    int            `json:"count"`
}

// SubscriptionSummary summarizes subscription costs and upcoming renewals.
type SubscriptionSummary struct {
	Totals            []SubscriptionCostTotal `json:"totals" doc:"Per currency (no conversion); trial, active and pending-cancellation subscriptions"`
	UpcomingRenewals  []SubscriptionDTO       `json:"upcoming_renewals" doc:"Renewing within 30 days"`
	TrialsEndingSoon  []SubscriptionDTO       `json:"trials_ending_soon" doc:"Trials ending within 14 days"`
	PendingDetections int                     `json:"pending_detections"`
}

// Summary returns totals and upcoming renewals.
func (s *Service) Summary(ctx context.Context) (*SubscriptionSummary, error) {
	list, err := s.List(ctx, "")
	if err != nil {
		return nil, err
	}
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &SubscriptionSummary{Totals: []SubscriptionCostTotal{}, UpcomingRenewals: []SubscriptionDTO{}, TrialsEndingSoon: []SubscriptionDTO{}}
	var tz string
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `select timezone from user_preferences where user_id = $1`, uid).Scan(&tz); err != nil {
			return err
		}
		return tx.QueryRow(ctx, `select count(*) from subscription_detection_candidates where status = 'pending'`).Scan(&out.PendingDetections)
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	today := localToday(s.now(), tz)
	idx := map[string]int{}
	for _, d := range list {
		if d.Status == "paused" || !d.Owned {
			continue
		}
		i, ok := idx[d.Amount.Currency]
		if !ok {
			i = len(out.Totals)
			idx[d.Amount.Currency] = i
			out.Totals = append(out.Totals, SubscriptionCostTotal{Currency: d.Amount.Currency, Monthly: apitypes.M(0, d.Amount.Currency), Annual: apitypes.M(0, d.Amount.Currency)})
		}
		t := &out.Totals[i]
		mo, err := money.Add(t.Monthly.AmountMinor, d.MonthlyCost.AmountMinor)
		if err != nil {
			return nil, err
		}
		an, err := money.Add(t.Annual.AmountMinor, d.AnnualCost.AmountMinor)
		if err != nil {
			return nil, err
		}
		t.Monthly, t.Annual, t.Count = apitypes.M(mo, t.Currency), apitypes.M(an, t.Currency), t.Count+1
		if d.NextRenewalDate != nil {
			if n, err := time.Parse("2006-01-02", *d.NextRenewalDate); err == nil && !n.After(today.AddDate(0, 0, 30)) && d.Status != "cancellation_pending" {
				out.UpcomingRenewals = append(out.UpcomingRenewals, d)
			}
		}
		if d.Status == "trial" && d.TrialEndsOn != nil {
			if n, err := time.Parse("2006-01-02", *d.TrialEndsOn); err == nil && !n.After(today.AddDate(0, 0, 14)) {
				out.TrialsEndingSoon = append(out.TrialsEndingSoon, d)
			}
		}
	}
	return out, nil
}
