// Package recurring implements recurring rules, materialized occurrences,
// bills, reminders and the planning calendar (spec §4.7, §20B.8).
//
// Generation is a durable, idempotent scheduler job: occurrences are unique
// per (rule, date), posting locks the occurrence row and records the
// transaction ID on it, so restarts, retries and concurrent schedulers never
// create duplicates, and a missed run is recovered by the next one. A
// scheduled occurrence is an expectation, not money movement: a bill is never
// marked paid because its due date passed.
package recurring

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/recurrence"
	"montra/backend/internal/finance"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
)

// JobGenerate materializes occurrences, posts due auto-post rules, marks
// overdue items and sends reminders.
const JobGenerate = "recurring.generate"

const (
	// horizonDays is how far ahead occurrences are materialized.
	horizonDays = 35
	// autoPostRetryDays bounds automatic retries of a failing auto-post;
	// afterwards the occurrence becomes overdue for the user to handle.
	autoPostRetryDays = 7
	batchSize         = 500
)

// Open-record counts for the fair-use caps (internal/platform/caps).
const (
	openRulesQ = `select count(*) from recurring_rules where user_id = $1 and group_id is null and status <> 'ended'`
	openBillsQ = `select count(*) from bills where user_id = $1 and status <> 'archived'`
)

// Service implements recurring rules and bills.
type Service struct {
	DB      *database.DB
	Finance *finance.Service
	Now     func() time.Time // injectable clock (tests)
	// GroupPoster adds one due recurring group expense (owned by the groups
	// package, wired by the app). Nil disables automatic adding.
	GroupPoster func(ctx context.Context, occurrenceID uuid.UUID) error
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// localToday is the calendar date in loc, as a UTC-midnight date value.
func localToday(now time.Time, loc *time.Location) time.Time {
	l := now.In(loc)
	return time.Date(l.Year(), l.Month(), l.Day(), 0, 0, 0, 0, time.UTC)
}

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func maxDate(a, b time.Time) time.Time {
	if a.After(b) {
		return a
	}
	return b
}

// Schedule is the recurrence part of a rule or bill.
type Schedule struct {
	Frequency          string  `json:"frequency" enum:"daily,weekly,biweekly,monthly,bimonthly,quarterly,semiannual,yearly,custom"`
	IntervalCount      int16   `json:"interval_count,omitempty" minimum:"1" maximum:"366" doc:"Custom frequency: every N units"`
	IntervalUnit       *string `json:"interval_unit,omitempty" enum:"day,week,month,year"`
	ByMonthDay         *int16  `json:"by_month_day,omitempty" minimum:"-1" maximum:"31" doc:"Monthly family: day of month (-1 = last day). Days past a month's end fall on its last day."`
	ByWeekday          *int16  `json:"by_weekday,omitempty" minimum:"0" maximum:"6" doc:"0 = Sunday"`
	ByWeekOfMonth      *int16  `json:"by_week_of_month,omitempty" minimum:"-1" maximum:"5" doc:"With by_weekday: nth weekday of the month (-1 = last)"`
	StartDate          string  `json:"start_date" doc:"YYYY-MM-DD; first eligible date"`
	EndDate            string  `json:"end_date,omitempty"`
	MaxOccurrences     *int32  `json:"max_occurrences,omitempty" minimum:"1" maximum:"10000"`
	Timezone           string  `json:"timezone,omitempty" maxLength:"64" doc:"IANA zone; defaults to your profile time zone"`
	LocalTime          string  `json:"local_time,omitempty" pattern:"^([01][0-9]|2[0-3]):[0-5][0-9]$" doc:"Local due time (default 09:00); kept across DST changes"`
	ReminderDaysBefore []int16 `json:"reminder_days_before,omitempty" maxItems:"5" doc:"Reminder offsets in days (0-30); default [1]"`
}

// RecurringRuleDTO is a recurring rule.
type RecurringRuleDTO struct {
	ID                 uuid.UUID            `json:"id"`
	Kind               string               `json:"kind" enum:"expense,income,transfer,bill,group_expense" doc:"Subscriptions are managed through /subscriptions, not recurring rules"`
	Name               string               `json:"name"`
	Frequency          string               `json:"frequency" enum:"daily,weekly,biweekly,monthly,bimonthly,quarterly,semiannual,yearly,custom"`
	IntervalCount      int16                `json:"interval_count"`
	IntervalUnit       *string              `json:"interval_unit,omitempty" enum:"day,week,month,year"`
	ByMonthDay         *int16               `json:"by_month_day,omitempty"`
	ByWeekday          *int16               `json:"by_weekday,omitempty"`
	ByWeekOfMonth      *int16               `json:"by_week_of_month,omitempty"`
	StartDate          string               `json:"start_date"`
	EndDate            *string              `json:"end_date,omitempty"`
	MaxOccurrences     *int32               `json:"max_occurrences,omitempty"`
	Timezone           string               `json:"timezone"`
	LocalTime          string               `json:"local_time"`
	Amount             *apitypes.Money      `json:"amount,omitempty"`
	Currency           *string              `json:"currency,omitempty"`
	AmountIsVariable   bool                 `json:"amount_is_variable"`
	AccountID          *uuid.UUID           `json:"account_id,omitempty"`
	ToAccountID        *uuid.UUID           `json:"to_account_id,omitempty"`
	CategoryID         *uuid.UUID           `json:"category_id,omitempty"`
	MerchantID         *uuid.UUID           `json:"merchant_id,omitempty"`
	Merchant           *finance.MerchantRef `json:"merchant,omitempty" doc:"The merchant (or bill provider) by name"`
	Description        *string              `json:"description,omitempty"`
	Notes              *string              `json:"notes,omitempty"`
	AutoPost           bool                 `json:"auto_post"`
	ReminderDaysBefore []int16              `json:"reminder_days_before"`
	Status             string               `json:"status" enum:"active,paused,ended"`
	NextOccurrence     *string              `json:"next_occurrence,omitempty"`
	CompletedCount     int32                `json:"completed_count" doc:"Occurrences posted or paid"`
	BillID             *uuid.UUID           `json:"bill_id,omitempty" doc:"The bill this rule schedules (kind bill); manage it through /bills/{id}"`
	GroupID            *uuid.UUID           `json:"group_id,omitempty"`
	Owned              bool                 `json:"owned"`
	Version            int32                `json:"version"`
	CreatedAt          time.Time            `json:"created_at"`
}

const ruleCols = `id, kind, name, frequency, interval_count, interval_unit, by_month_day, by_weekday, by_week_of_month, start_date, end_date,
	max_occurrences, timezone, to_char(local_time, 'HH24:MI'), amount_minor, currency, amount_is_variable, account_id, to_account_id, category_id,
	merchant_id, description, notes, auto_post, reminder_days_before, status, next_occurrence_date, occurrences_count, group_id, version,
	created_at, user_id, generated_through, (select m.name from merchants m where m.id = recurring_rules.merchant_id) as merchant_name,
	(select b.id from bills b where b.recurring_rule_id = recurring_rules.id) as bill_id`

type ruleRow struct {
	RecurringRuleDTO
	userID     uuid.UUID
	start      time.Time
	end        *time.Time
	amount     *int64
	next       *time.Time
	generated  *time.Time
	groupSplit []byte // group_expense rules: the groups package's split template
}

func scanRule(r pgx.Row) (*ruleRow, error) {
	var x ruleRow
	var merchantName *string
	if err := r.Scan(&x.ID, &x.Kind, &x.Name, &x.Frequency, &x.IntervalCount, &x.IntervalUnit, &x.ByMonthDay, &x.ByWeekday, &x.ByWeekOfMonth,
		&x.start, &x.end, &x.MaxOccurrences, &x.Timezone, &x.LocalTime, &x.amount, &x.Currency, &x.AmountIsVariable, &x.AccountID, &x.ToAccountID,
		&x.CategoryID, &x.MerchantID, &x.Description, &x.Notes, &x.AutoPost, &x.ReminderDaysBefore, &x.Status, &x.next, &x.CompletedCount,
		&x.GroupID, &x.Version, &x.CreatedAt, &x.userID, &x.generated, &merchantName, &x.BillID); err != nil {
		return nil, err
	}
	if x.MerchantID != nil && merchantName != nil {
		x.Merchant = &finance.MerchantRef{ID: *x.MerchantID, Name: *merchantName}
	}
	x.StartDate = finance.LocalDateString(x.start)
	if x.end != nil {
		e := finance.LocalDateString(*x.end)
		x.EndDate = &e
	}
	if x.next != nil {
		n := finance.LocalDateString(*x.next)
		x.NextOccurrence = &n
	}
	if x.amount != nil && x.Currency != nil {
		x.Amount = apitypes.MP(x.amount, *x.Currency)
	}
	if x.ReminderDaysBefore == nil {
		x.ReminderDaysBefore = []int16{}
	}
	return &x, nil
}

func (x *ruleRow) dto(me uuid.UUID) RecurringRuleDTO {
	d := x.RecurringRuleDTO
	d.Owned = x.userID == me
	return d
}

// spec converts a stored rule into the domain rule.
func (x *ruleRow) spec() (recurrence.Rule, error) {
	loc, err := time.LoadLocation(x.Timezone)
	if err != nil {
		loc = time.UTC
	}
	r := recurrence.Rule{Frequency: x.Frequency, Interval: int(x.IntervalCount), Start: x.start, End: x.end, Location: loc}
	if x.IntervalUnit != nil {
		r.Unit = *x.IntervalUnit
	}
	if x.ByMonthDay != nil {
		r.ByMonthDay = int(*x.ByMonthDay)
	}
	if x.ByWeekday != nil {
		wd := time.Weekday(*x.ByWeekday)
		r.ByWeekday = &wd
	}
	if x.ByWeekOfMonth != nil {
		r.ByWeekOfMonth = int(*x.ByWeekOfMonth)
	}
	if x.MaxOccurrences != nil {
		r.Count = int(*x.MaxOccurrences)
	}
	if t, err := time.Parse("15:04", x.LocalTime); err == nil {
		r.Hour, r.Minute = t.Hour(), t.Minute()
	}
	return r, r.Validate()
}

// ruleSpec is a normalized create/update request.
type ruleSpec struct {
	Kind             string
	Name             string
	Schedule         Schedule
	Amount           string
	Currency         string
	AmountIsVariable bool
	AccountID        *uuid.UUID
	ToAccountID      *uuid.UUID
	CategoryID       *uuid.UUID
	MerchantName     string
	Description      string
	Notes            string
	AutoPost         bool
	// kept lists references already stored on the record being edited:
	// they stay valid even if archived since (an unrelated edit must not
	// fail), except for auto-posting, which needs an active account.
	kept map[uuid.UUID]bool
}

// RecurringRuleInput creates or replaces a recurring income/expense/transfer rule.
// Bills are managed through /bills and subscriptions through
// /subscriptions.
type RecurringRuleInput struct {
	Kind string `json:"kind" enum:"expense,income,transfer"`
	Name string `json:"name" minLength:"1" maxLength:"120"`
	Schedule
	Amount           string     `json:"amount,omitempty" doc:"Expected amount (decimal); required for auto-posting"`
	Currency         string     `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Defaults to the account currency"`
	AmountIsVariable bool       `json:"amount_is_variable,omitempty"`
	AccountID        *uuid.UUID `json:"account_id,omitempty"`
	ToAccountID      *uuid.UUID `json:"to_account_id,omitempty" doc:"Destination account for transfers"`
	CategoryID       *uuid.UUID `json:"category_id,omitempty"`
	MerchantName     string     `json:"merchant_name,omitempty" maxLength:"120"`
	Description      string     `json:"description,omitempty" maxLength:"500"`
	Notes            string     `json:"notes,omitempty" maxLength:"2000"`
	AutoPost         bool       `json:"auto_post,omitempty" doc:"Record the transaction automatically when due (fixed amount and account required)"`
	Version          int32      `json:"version,omitempty" doc:"Required for updates (optimistic concurrency)"`
}

func (in RecurringRuleInput) spec() ruleSpec {
	return ruleSpec{Kind: in.Kind, Name: in.Name, Schedule: in.Schedule, Amount: in.Amount, Currency: in.Currency,
		AmountIsVariable: in.AmountIsVariable, AccountID: in.AccountID, ToAccountID: in.ToAccountID, CategoryID: in.CategoryID,
		MerchantName: in.MerchantName, Description: in.Description, Notes: in.Notes, AutoPost: in.AutoPost}
}

// validate checks a rule request and returns the normalized row.
func (s *Service) validate(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in ruleSpec) (*ruleRow, error) {
	u, err := finance.LoadUser(ctx, tx, uid)
	if err != nil {
		return nil, err
	}
	x := &ruleRow{userID: uid}
	sch := in.Schedule
	x.Kind, x.Name, x.Frequency = in.Kind, strings.TrimSpace(in.Name), sch.Frequency
	if x.Name == "" {
		return nil, apperr.FieldError("body.name", "Enter a name.")
	}
	x.IntervalCount = 1
	if x.Frequency == recurrence.Custom {
		if sch.IntervalUnit == nil {
			return nil, apperr.FieldError("body.interval_unit", "Custom schedules need an interval unit.")
		}
		x.IntervalCount = max(sch.IntervalCount, 1)
		x.IntervalUnit = sch.IntervalUnit
	}
	x.ByMonthDay, x.ByWeekday, x.ByWeekOfMonth, x.MaxOccurrences = sch.ByMonthDay, sch.ByWeekday, sch.ByWeekOfMonth, sch.MaxOccurrences
	x.Timezone = sch.Timezone
	if x.Timezone == "" {
		x.Timezone = u.Timezone
	}
	loc, err := time.LoadLocation(x.Timezone)
	if err != nil || x.Timezone == "Local" {
		return nil, apperr.FieldError("body.timezone", "Unknown time zone.")
	}
	if x.start, err = finance.ParseDate("body.start_date", sch.StartDate, loc); err != nil {
		return nil, err
	}
	x.start = dateOnly(x.start)
	if sch.EndDate != "" {
		e, err := finance.ParseDate("body.end_date", sch.EndDate, loc)
		if err != nil {
			return nil, err
		}
		e = dateOnly(e)
		x.end = &e
	}
	x.LocalTime = sch.LocalTime
	if x.LocalTime == "" {
		x.LocalTime = "09:00"
	}
	if _, err := x.spec(); err != nil {
		return nil, apperr.Validation("The schedule is not valid: check the interval, weekday rule and end date.")
	}
	x.ReminderDaysBefore = sch.ReminderDaysBefore
	if x.ReminderDaysBefore == nil {
		x.ReminderDaysBefore = []int16{1}
	}
	for _, d := range x.ReminderDaysBefore {
		if d < 0 || d > 30 {
			return nil, apperr.FieldError("body.reminder_days_before", "Reminders can be 0-30 days before.")
		}
	}

	// Accounts must be the caller's active accounts.
	accountCur := map[uuid.UUID]string{}
	for field, acct := range map[string]*uuid.UUID{"body.account_id": in.AccountID, "body.to_account_id": in.ToAccountID} {
		if acct == nil {
			continue
		}
		var cur, status string
		if err := tx.QueryRow(ctx, `select currency, status from financial_accounts where id = $1 and user_id = $2`, *acct, uid).
			Scan(&cur, &status); err != nil {
			if database.IsNoRows(err) {
				return nil, apperr.FieldError(field, "Choose one of your active accounts.")
			}
			return nil, err
		}
		if status != "active" && (!in.kept[*acct] || in.AutoPost) {
			return nil, apperr.FieldError(field, "Choose one of your active accounts.")
		}
		accountCur[*acct] = cur
	}
	x.AccountID, x.ToAccountID = in.AccountID, in.ToAccountID
	if x.Kind == "transfer" {
		if in.AccountID == nil || in.ToAccountID == nil || *in.AccountID == *in.ToAccountID {
			return nil, apperr.Rule("transfer_needs_two_accounts", "Recurring transfers need two different accounts.", nil)
		}
		if in.AutoPost && accountCur[*in.AccountID] != accountCur[*in.ToAccountID] {
			return nil, apperr.Rule("cross_currency_transfer_not_auto_posted", "Cross-currency transfers need the received amount each time, so they cannot be auto-posted.", nil)
		}
	} else if in.ToAccountID != nil {
		return nil, apperr.FieldError("body.to_account_id", "Only transfers have a destination account.")
	}
	cur := in.Currency
	if cur == "" && in.AccountID != nil {
		cur = accountCur[*in.AccountID]
	}
	if cur == "" {
		cur = u.BaseCurrency
	}
	if !currency.Selectable(cur) {
		return nil, apperr.FieldError("body.currency", "Unsupported currency.")
	}
	if in.AccountID != nil && accountCur[*in.AccountID] != cur {
		return nil, apperr.FieldError("body.currency", "The amount must be in the account currency ("+accountCur[*in.AccountID]+").")
	}
	x.Currency = &cur
	if in.Amount != "" {
		v, err := finance.ParseAmount("body.amount", in.Amount, cur)
		if err != nil {
			return nil, err
		}
		x.amount = &v
	}
	x.AmountIsVariable, x.AutoPost = in.AmountIsVariable, in.AutoPost
	if x.AutoPost {
		if x.Kind == "bill" || x.Kind == "subscription" {
			return nil, apperr.Rule("bills_not_auto_posted", "Bills are confirmed by linking or recording the actual payment, not auto-posted.", nil)
		}
		if x.amount == nil || x.AmountIsVariable || in.AccountID == nil {
			return nil, apperr.Rule("auto_post_needs_amount_and_account", "Auto-posting needs a fixed amount and an account.", nil)
		}
	}
	if in.CategoryID != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from categories where id = $1 and user_id = $2
			and (status = 'active' or ($3 and status = 'archived')))`, *in.CategoryID, uid, in.kept[*in.CategoryID]).Scan(&ok); err != nil {
			return nil, err
		}
		if !ok {
			return nil, apperr.FieldError("body.category_id", "Category not found.")
		}
		x.CategoryID = in.CategoryID
	}
	if strings.TrimSpace(in.MerchantName) != "" {
		mid, err := s.Finance.ResolveMerchantName(ctx, tx, uid, in.MerchantName)
		if err != nil {
			return nil, err
		}
		x.MerchantID = mid
	}
	x.Description, x.Notes = trim(in.Description, 500), trim(in.Notes, 2000)
	return x, nil
}

// storedRefs returns the non-null IDs a query selects for one record (the
// references an edit may keep even if they were archived since).
func storedRefs(ctx context.Context, tx pgx.Tx, q string, id uuid.UUID) (map[uuid.UUID]bool, error) {
	var a, b, c *uuid.UUID
	if err := tx.QueryRow(ctx, q, id).Scan(&a, &b, &c); err != nil {
		return nil, err
	}
	out := map[uuid.UUID]bool{}
	for _, p := range []*uuid.UUID{a, b, c} {
		if p != nil {
			out[*p] = true
		}
	}
	return out, nil
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

// insertRule stores a validated rule; generation starts at the later of the
// start date and today (creating a rule never back-posts the past).
func (s *Service) insertRule(ctx context.Context, tx pgx.Tx, uid uuid.UUID, x *ruleRow) (uuid.UUID, error) {
	loc, err := time.LoadLocation(x.Timezone)
	if err != nil {
		return uuid.Nil, err
	}
	genThrough := maxDate(x.start, localToday(s.now(), loc)).AddDate(0, 0, -1)
	id := uuid.New()
	if _, err := tx.Exec(ctx, `insert into recurring_rules (id, user_id, kind, name, frequency, interval_count, interval_unit, by_month_day, by_weekday,
		by_week_of_month, start_date, end_date, max_occurrences, timezone, local_time, amount_minor, amount_is_variable, currency, account_id,
		to_account_id, category_id, merchant_id, description, notes, auto_post, reminder_days_before, generated_through, group_id, group_split)
		values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15::time,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29)`,
		id, uid, x.Kind, x.Name, x.Frequency, x.IntervalCount, x.IntervalUnit, x.ByMonthDay, x.ByWeekday, x.ByWeekOfMonth, x.start, x.end,
		x.MaxOccurrences, x.Timezone, x.LocalTime, x.amount, x.AmountIsVariable, x.Currency, x.AccountID, x.ToAccountID, x.CategoryID, x.MerchantID,
		x.Description, x.Notes, x.AutoPost, x.ReminderDaysBefore, genThrough, x.GroupID, x.groupSplit); err != nil {
		return uuid.Nil, err
	}
	if err := s.materialize(ctx, tx, id); err != nil {
		return uuid.Nil, err
	}
	return id, audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "recurring_rule", EntityID: &id, Action: "created",
		Changes: map[string]any{"kind": x.Kind}})
}

// replaceSchedule applies an "edit this and future" change: open future
// occurrences are removed and regenerated from today; past, posted and paid
// occurrences are untouched. When the dates are unchanged (a rename, a new
// amount or account), occurrences the user adjusted (postponed, or given
// their own amount) are kept as they are.
func (s *Service) replaceSchedule(ctx context.Context, tx pgx.Tx, id uuid.UUID, x *ruleRow) error {
	loc, err := time.LoadLocation(x.Timezone)
	if err != nil {
		return err
	}
	today := localToday(s.now(), loc)
	cur, err := scanRule(tx.QueryRow(ctx, `select `+ruleCols+` from recurring_rules where id = $1`, id))
	if err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `delete from recurring_occurrences where rule_id = $1 and status = 'scheduled' and transaction_id is null
		and occurrence_date >= $2 and (not $3 or overrides = '{}'::jsonb)`, id, today, sameDates(cur, x)); err != nil {
		return err
	}
	// Kept (postponed) occurrences follow the new expected amount unless the
	// user set their own.
	if _, err := tx.Exec(ctx, `update recurring_occurrences set amount_minor = $3 where rule_id = $1 and status = 'scheduled'
		and transaction_id is null and occurrence_date >= $2 and not (overrides ? 'amount')`, id, today, x.amount); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `update recurring_rules set name = $2, frequency = $3, interval_count = $4, interval_unit = $5,
		by_month_day = $6, by_weekday = $7, by_week_of_month = $8, start_date = $9, end_date = $10, max_occurrences = $11, timezone = $12,
		local_time = $13::time, amount_minor = $14, amount_is_variable = $15, currency = $16, account_id = $17, to_account_id = $18,
		category_id = $19, merchant_id = $20, description = $21, notes = $22, auto_post = $23, reminder_days_before = $24,
		generated_through = $25, status = case when status = 'ended' then 'active' else status end, version = version + 1 where id = $1`,
		id, x.Name, x.Frequency, x.IntervalCount, x.IntervalUnit, x.ByMonthDay, x.ByWeekday, x.ByWeekOfMonth, x.start, x.end,
		x.MaxOccurrences, x.Timezone, x.LocalTime, x.amount, x.AmountIsVariable, x.Currency, x.AccountID, x.ToAccountID, x.CategoryID,
		x.MerchantID, x.Description, x.Notes, x.AutoPost, x.ReminderDaysBefore, today.AddDate(0, 0, -1)); err != nil {
		return err
	}
	return s.materialize(ctx, tx, id)
}

// sameDates reports whether two versions of a rule produce the same
// occurrence dates and due times.
func sameDates(a, b *ruleRow) bool {
	sameEnd := (a.end == nil && b.end == nil) || (a.end != nil && b.end != nil && a.end.Equal(*b.end))
	return a.Frequency == b.Frequency && a.IntervalCount == b.IntervalCount && eqPtr(a.IntervalUnit, b.IntervalUnit) &&
		eqPtr(a.ByMonthDay, b.ByMonthDay) && eqPtr(a.ByWeekday, b.ByWeekday) && eqPtr(a.ByWeekOfMonth, b.ByWeekOfMonth) &&
		a.start.Equal(b.start) && sameEnd && eqPtr(a.MaxOccurrences, b.MaxOccurrences) && a.Timezone == b.Timezone &&
		a.LocalTime == b.LocalTime
}

func eqPtr[T comparable](a, b *T) bool {
	return (a == nil && b == nil) || (a != nil && b != nil && *a == *b)
}

// materialize inserts occurrences up to the horizon (idempotent) and
// refreshes the rule's next occurrence, status and counters.
func (s *Service) materialize(ctx context.Context, tx pgx.Tx, ruleID uuid.UUID) error {
	x, err := scanRule(tx.QueryRow(ctx, `select `+ruleCols+` from recurring_rules where id = $1 for update`, ruleID))
	if err != nil {
		return err
	}
	if x.Status == "active" {
		spec, err := x.spec()
		if err != nil {
			return err
		}
		today := localToday(s.now(), spec.Location)
		from := x.start
		if x.generated != nil && !x.generated.Before(from) {
			from = x.generated.AddDate(0, 0, 1)
		}
		to := today.AddDate(0, 0, horizonDays)
		if !from.After(to) {
			for _, d := range spec.Between(from, to, batchSize) {
				if _, err := tx.Exec(ctx, `insert into recurring_occurrences (rule_id, user_id, group_id, occurrence_date, due_at, amount_minor)
					values ($1,$2,$3,$4,$5,$6) on conflict (rule_id, occurrence_date) do nothing`,
					x.ID, x.userID, x.GroupID, d, spec.DueAt(d), x.amount); err != nil {
					return err
				}
			}
			if _, err := tx.Exec(ctx, `update recurring_rules set generated_through = $2 where id = $1`, x.ID, to); err != nil {
				return err
			}
			x.generated = &to
		}
	}
	return s.refresh(ctx, tx, x)
}

// ruleProgress is a rule's derived state: next occurrence, next run,
// completed count and whether it has ended.
type ruleProgress struct {
	next, nextRun *time.Time
	completed     int32
	status        string
}

// progressOf computes a rule's derived state from its occurrences and
// schedule.
func (s *Service) progressOf(ctx context.Context, tx pgx.Tx, x *ruleRow) (*ruleProgress, error) {
	spec, err := x.spec()
	if err != nil {
		return nil, err
	}
	today := localToday(s.now(), spec.Location)
	p := &ruleProgress{status: x.Status}
	var open int32
	if err := tx.QueryRow(ctx, `select min(coalesce(postponed_to, occurrence_date)) filter (where status = 'scheduled'
			and coalesce(postponed_to, occurrence_date) >= $2),
		min(due_at) filter (where status = 'scheduled'),
		count(*) filter (where status in ('scheduled','overdue')),
		count(*) filter (where status in ('posted','paid'))
		from recurring_occurrences where rule_id = $1`, x.ID, today).Scan(&p.next, &p.nextRun, &open, &p.completed); err != nil {
		return nil, err
	}
	if p.status == "active" && p.next == nil {
		after := today
		if x.generated != nil {
			after = maxDate(*x.generated, today.AddDate(0, 0, -1))
		}
		if n, ok := spec.Next(after.AddDate(0, 0, 1)); ok {
			p.next = &n
		} else if open == 0 {
			p.status = "ended"
		}
	}
	if p.status != "active" {
		p.next, p.nextRun = nil, nil
	}
	return p, nil
}

// refresh recomputes next occurrence, next run, completed count and the
// ended state.
func (s *Service) refresh(ctx context.Context, tx pgx.Tx, x *ruleRow) error {
	p, err := s.progressOf(ctx, tx, x)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `update recurring_rules set next_occurrence_date = $2, next_run_at = $3, occurrences_count = $4, status = $5
		where id = $1`, x.ID, p.next, p.nextRun, p.completed, p.status)
	return err
}

// OccurrenceDTO is a scheduled or past occurrence.
type OccurrenceDTO struct {
	ID             uuid.UUID       `json:"id"`
	RuleID         uuid.UUID       `json:"rule_id"`
	RuleName       string          `json:"rule_name"`
	Kind           string          `json:"kind" enum:"expense,income,transfer,bill,group_expense"`
	OccurrenceDate string          `json:"occurrence_date" doc:"Scheduled date"`
	EffectiveDate  string          `json:"effective_date" doc:"Postponed date when postponed, otherwise the scheduled date"`
	DueAt          time.Time       `json:"due_at"`
	Status         string          `json:"status" enum:"scheduled,posted,paid,skipped,overdue" doc:"A moved occurrence stays scheduled (or overdue) with postponed_to set"`
	Amount         *apitypes.Money `json:"amount,omitempty"`
	TransactionID  *uuid.UUID      `json:"transaction_id,omitempty"`
	PostponedTo    *string         `json:"postponed_to,omitempty"`
	BillID         *uuid.UUID      `json:"bill_id,omitempty"`
	GroupID        *uuid.UUID      `json:"group_id,omitempty" doc:"Recurring shared expense of this group"`
	GroupExpenseID *uuid.UUID      `json:"group_expense_id,omitempty" doc:"The group expense added for this occurrence"`
}

const occSelect = `select o.id, o.rule_id, r.name, r.kind, o.occurrence_date, o.due_at, o.status, coalesce(o.amount_minor, r.amount_minor),
	r.currency, o.transaction_id, o.postponed_to, b.id, o.group_id, o.group_expense_id
	from recurring_occurrences o join recurring_rules r on r.id = o.rule_id left join bills b on b.recurring_rule_id = r.id`

func scanOcc(r pgx.Row) (*OccurrenceDTO, error) {
	var o OccurrenceDTO
	var d time.Time
	var amt *int64
	var cur *string
	var post *time.Time
	if err := r.Scan(&o.ID, &o.RuleID, &o.RuleName, &o.Kind, &d, &o.DueAt, &o.Status, &amt, &cur, &o.TransactionID, &post, &o.BillID,
		&o.GroupID, &o.GroupExpenseID); err != nil {
		return nil, err
	}
	o.OccurrenceDate = finance.LocalDateString(d)
	o.EffectiveDate = o.OccurrenceDate
	if amt != nil && cur != nil {
		o.Amount = apitypes.MP(amt, *cur)
	}
	if post != nil {
		p := finance.LocalDateString(*post)
		o.PostponedTo, o.EffectiveDate = &p, p
	}
	return &o, nil
}

func queryOccs(ctx context.Context, tx pgx.Tx, where string, args ...any) ([]OccurrenceDTO, error) {
	rows, err := tx.Query(ctx, occSelect+` where `+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []OccurrenceDTO{}
	for rows.Next() {
		o, err := scanOcc(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *o)
	}
	return out, rows.Err()
}

// CreateRule creates a rule and materializes its first occurrences.
// A retry with the same Idempotency-Key returns the rule created first.
func (s *Service) CreateRule(ctx context.Context, key string, in RecurringRuleInput) (*RecurringRuleDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out RecurringRuleDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "recurring_rule.create", in, func() (RecurringRuleDTO, error) {
			if err := caps.Check(ctx, tx, uid, "recurring_rules", openRulesQ, caps.OpenRecurringRules); err != nil {
				return RecurringRuleDTO{}, err
			}
			x, err := s.validate(ctx, tx, uid, in.spec())
			if err != nil {
				return RecurringRuleDTO{}, err
			}
			id, err := s.insertRule(ctx, tx, uid, x)
			if err != nil {
				return RecurringRuleDTO{}, err
			}
			r, err := s.getRule(ctx, tx, uid, id)
			if err != nil {
				return RecurringRuleDTO{}, err
			}
			return *r, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

func (s *Service) getRule(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (*RecurringRuleDTO, error) {
	// Group rules are managed (and read) through /groups/{id}/recurring-expenses.
	x, err := scanRule(tx.QueryRow(ctx, `select `+ruleCols+` from recurring_rules where id = $1 and group_id is null`, id))
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("recurring rule")
	}
	if err != nil {
		return nil, err
	}
	d := x.dto(me)
	return &d, nil
}

// ListRules returns the caller's recurring rules (bills included, with
// kind = bill).
func (s *Service) ListRules(ctx context.Context, kind, status string) ([]RecurringRuleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []RecurringRuleDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+ruleCols+` from recurring_rules where group_id is null and ($1 = '' or kind = $1) and ($2 = '' or status = $2)
			order by case status when 'active' then 0 when 'paused' then 1 else 2 end, next_occurrence_date nulls last, name`, kind, status)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			x, err := scanRule(rows)
			if err != nil {
				return err
			}
			out = append(out, x.dto(uid))
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// RecurringRuleDetail adds occurrence history and the upcoming schedule.
type RecurringRuleDetail struct {
	RecurringRuleDTO
	Occurrences []OccurrenceDTO `json:"occurrences" doc:"Upcoming and past occurrences (newest first) with generated transaction links"`
}

// GetRule returns a rule with occurrences.
func (s *Service) GetRule(ctx context.Context, id uuid.UUID) (*RecurringRuleDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out RecurringRuleDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		r, err := s.getRule(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		out.RecurringRuleDTO = *r
		out.Occurrences, err = queryOccs(ctx, tx, `o.rule_id = $1 order by o.occurrence_date desc limit 120`, id)
		return err
	})
	return &out, database.MapError(err)
}

// lockOwnRule locks a rule the caller owns and returns its kind/version.
func lockOwnRule(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (kind string, version int32, err error) {
	var owner uuid.UUID
	if err := tx.QueryRow(ctx, `select kind, version, user_id from recurring_rules where id = $1 and group_id is null`, id).Scan(&kind, &version, &owner); err != nil {
		if database.IsNoRows(err) {
			return "", 0, apperr.NotFound("recurring rule")
		}
		return "", 0, err
	}
	if owner != uid {
		return "", 0, apperr.Forbidden()
	}
	if _, err := tx.Exec(ctx, `select 1 from recurring_rules where id = $1 for update`, id); err != nil {
		return "", 0, err
	}
	return kind, version, nil
}

// UpdateRule edits this and future occurrences.
func (s *Service) UpdateRule(ctx context.Context, id uuid.UUID, in RecurringRuleInput) (*RecurringRuleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *RecurringRuleDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		kind, version, err := lockOwnRule(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if kind == "bill" || kind == "subscription" {
			return apperr.Rule("use_bill_screen", "Edit bills from the bill screen.", nil)
		}
		if version != in.Version {
			return apperr.VersionConflict()
		}
		if in.Kind != kind {
			return apperr.FieldError("body.kind", "The kind of a recurring rule cannot change; create a new rule instead.")
		}
		spec := in.spec()
		if spec.kept, err = storedRefs(ctx, tx, `select account_id, to_account_id, category_id from recurring_rules where id = $1`, id); err != nil {
			return err
		}
		x, err := s.validate(ctx, tx, uid, spec)
		if err != nil {
			return err
		}
		if err := s.replaceSchedule(ctx, tx, id, x); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "recurring_rule", EntityID: &id, Action: "updated"}); err != nil {
			return err
		}
		out, err = s.getRule(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// setStatus pauses, resumes or stops a rule (shared by bills).
func (s *Service) setStatus(ctx context.Context, tx pgx.Tx, id uuid.UUID, action string) error {
	status := map[string]string{"pause": "paused", "resume": "active", "stop": "ended"}[action]
	if status == "" {
		return apperr.BadRequest("Unknown action.")
	}
	var cur, tz string
	if err := tx.QueryRow(ctx, `select status, timezone from recurring_rules where id = $1`, id).Scan(&cur, &tz); err != nil {
		return err
	}
	if action == "resume" && cur == "ended" {
		return apperr.ConflictCode("schedule_ended", "This schedule has ended; edit it to set new dates.", nil)
	}
	if action == "resume" {
		return s.resumeRule(ctx, tx, id)
	}
	loc, err := time.LoadLocation(tz)
	if err != nil {
		loc = time.UTC
	}
	today := localToday(s.now(), loc)
	// Pause/stop: remove open future occurrences (regenerated on resume).
	if _, err := tx.Exec(ctx, `delete from recurring_occurrences where rule_id = $1 and status = 'scheduled' and transaction_id is null
		and coalesce(postponed_to, occurrence_date) >= $2`, id, today); err != nil {
		return err
	}
	// Removed occurrences are regenerated from the resume date onwards.
	if _, err := tx.Exec(ctx, `update recurring_rules set status = $2, version = version + 1,
		generated_through = least(coalesce(generated_through, $3::date - 1), $3::date - 1) where id = $1`, id, status, today); err != nil {
		return err
	}
	x, err := scanRule(tx.QueryRow(ctx, `select `+ruleCols+` from recurring_rules where id = $1`, id))
	if err != nil {
		return err
	}
	return s.refresh(ctx, tx, x)
}

// resumeRule reactivates a paused or stopped rule. The gap is not
// back-filled: generation restarts today, and a rule whose dates are over
// ends again.
func (s *Service) resumeRule(ctx context.Context, tx pgx.Tx, id uuid.UUID) error {
	var tz string
	if err := tx.QueryRow(ctx, `select timezone from recurring_rules where id = $1`, id).Scan(&tz); err != nil {
		return err
	}
	loc, err := time.LoadLocation(tz)
	if err != nil {
		loc = time.UTC
	}
	if _, err := tx.Exec(ctx, `update recurring_rules set status = 'active', version = version + 1,
		generated_through = greatest(coalesce(generated_through, start_date - 1), $2::date - 1) where id = $1`, id, localToday(s.now(), loc)); err != nil {
		return err
	}
	return s.materialize(ctx, tx, id)
}

// ruleActions maps the rule lifecycle actions to the status they set.
var ruleActions = map[string]string{"pause": "paused", "resume": "active", "stop": "ended"}

// SetRuleStatus pauses, resumes or stops a recurring rule; version, when
// not 0, must match the rule's current version.
func (s *Service) SetRuleStatus(ctx context.Context, id uuid.UUID, action string, version int32) (*RecurringRuleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *RecurringRuleDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		kind, current, err := lockOwnRule(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if kind == "bill" {
			return apperr.Rule("use_bill_screen", "Pause or archive bills from the bill screen.", nil)
		}
		if version != 0 && version != current {
			return apperr.VersionConflict()
		}
		// Only real moves are allowed (pausing a paused rule would bump its
		// version for nothing); resuming an ended rule keeps its own code.
		var status string
		if err := tx.QueryRow(ctx, `select status from recurring_rules where id = $1`, id).Scan(&status); err != nil {
			return err
		}
		if to, ok := ruleActions[action]; ok && (status == to || (action == "stop" && status == "ended") || (action == "pause" && status == "ended")) {
			return apperr.Rule("invalid_status_transition", "A recurring rule cannot move from "+status+" to "+to+".",
				map[string]string{"from": status, "to": to})
		}
		if err := s.setStatus(ctx, tx, id, action); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "recurring_rule", EntityID: &id, Action: action}); err != nil {
			return err
		}
		out, err = s.getRule(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// RecurringDeleteResult reports what DELETE did.
type RecurringDeleteResult struct {
	Outcome string `json:"outcome" enum:"deleted,ended" doc:"deleted = never used and removed; ended = history kept, no future occurrences"`
}

// DeleteRule removes a never-used rule, or ends one that has history.
func (s *Service) DeleteRule(ctx context.Context, id uuid.UUID) (*RecurringDeleteResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &RecurringDeleteResult{}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		kind, _, err := lockOwnRule(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if kind == "bill" {
			return apperr.Rule("use_bill_screen", "Archive bills from the bill screen.", nil)
		}
		var used bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from recurring_occurrences where rule_id = $1
			and (status <> 'scheduled' or transaction_id is not null))
			or exists (select 1 from transactions where recurring_rule_id = $1)`, id).Scan(&used); err != nil {
			return err
		}
		if used {
			if err := s.setStatus(ctx, tx, id, "stop"); err != nil {
				return err
			}
			out.Outcome = "ended"
		} else {
			if _, err := tx.Exec(ctx, `delete from recurring_occurrences where rule_id = $1`, id); err != nil {
				return err
			}
			tag, err := tx.Exec(ctx, `delete from recurring_rules where id = $1`, id)
			if err != nil {
				return err
			}
			if tag.RowsAffected() != 1 {
				return apperr.ConflictCode("rule_in_use", "This rule could not be deleted; stop it instead.", nil)
			}
			out.Outcome = "deleted"
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "recurring_rule", EntityID: &id, Action: out.Outcome})
	})
	return out, database.MapError(err)
}

// SkipNext skips the next open occurrence.
func (s *Service) SkipNext(ctx context.Context, id uuid.UUID, version int32) (*RecurringRuleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *RecurringRuleDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, current, err := lockOwnRule(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if version != 0 && version != current {
			return apperr.VersionConflict()
		}
		if err := s.skipOpen(ctx, tx, id, nil); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "recurring_rule", EntityID: &id, Action: "skip_next"}); err != nil {
			return err
		}
		out, err = s.getRule(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// skipOpen skips a specific open occurrence, or the oldest open one.
func (s *Service) skipOpen(ctx context.Context, tx pgx.Tx, ruleID uuid.UUID, occID *uuid.UUID) error {
	tag, err := tx.Exec(ctx, `update recurring_occurrences set status = 'skipped' where id = (select id from recurring_occurrences
		where rule_id = $1 and status in ('scheduled','overdue') and transaction_id is null and ($2::uuid is null or id = $2)
		order by coalesce(postponed_to, occurrence_date) limit 1)`, ruleID, occID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return apperr.ConflictCode("no_open_occurrence", "There is no open occurrence to skip.", nil)
	}
	x, err := scanRule(tx.QueryRow(ctx, `select `+ruleCols+` from recurring_rules where id = $1`, ruleID))
	if err != nil {
		return err
	}
	return s.refresh(ctx, tx, x)
}

// OccurrenceAction changes one occurrence ("edit this occurrence").
type OccurrenceAction struct {
	Action        string     `json:"action" enum:"skip,reopen,postpone,set_amount,confirm,link_transaction"`
	PostponeTo    string     `json:"postpone_to,omitempty" doc:"YYYY-MM-DD (postpone)"`
	Amount        string     `json:"amount,omitempty" doc:"set_amount, or confirm with the actual amount"`
	TransactionID *uuid.UUID `json:"transaction_id,omitempty" doc:"link_transaction: the payment you already recorded (no duplicate is created)"`
	AccountID     *uuid.UUID `json:"account_id,omitempty" doc:"confirm: account used when the rule has none"`
	Date          string     `json:"date,omitempty" doc:"confirm: transaction date (default: the due date, or today when paying early)"`
}

// ActOnOccurrence applies an occurrence action. It is idempotent per
// Idempotency-Key, and posting is additionally idempotent per occurrence.
func (s *Service) ActOnOccurrence(ctx context.Context, key string, occID uuid.UUID, a OccurrenceAction) (*OccurrenceDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out OccurrenceDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		req := struct {
			ID     uuid.UUID
			Action OccurrenceAction
		}{occID, a}
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "recurring.occurrence", req, func() (OccurrenceDTO, error) {
			if err := s.actOnOccurrence(ctx, tx, uid, occID, a); err != nil {
				return OccurrenceDTO{}, err
			}
			o, err := scanOcc(tx.QueryRow(ctx, occSelect+` where o.id = $1`, occID))
			if err != nil {
				return OccurrenceDTO{}, err
			}
			return *o, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

func (s *Service) actOnOccurrence(ctx context.Context, tx pgx.Tx, uid, occID uuid.UUID, a OccurrenceAction) error {
	var ruleID uuid.UUID
	var status string
	var date time.Time
	var postponed *time.Time
	if err := tx.QueryRow(ctx, `select rule_id, status, occurrence_date, postponed_to from recurring_occurrences where id = $1 and user_id = $2
		and group_id is null for update`,
		occID, uid).Scan(&ruleID, &status, &date, &postponed); err != nil {
		if database.IsNoRows(err) {
			return apperr.NotFound("occurrence")
		}
		return err
	}
	x, err := scanRule(tx.QueryRow(ctx, `select `+ruleCols+` from recurring_rules where id = $1`, ruleID))
	if err != nil {
		return err
	}
	spec, err := x.spec()
	if err != nil {
		return err
	}
	effective := date
	if postponed != nil {
		effective = *postponed
	}
	open := status == "scheduled" || status == "overdue"
	switch a.Action {
	case "skip":
		if !open {
			return apperr.ConflictCode("occurrence_not_open", "Only upcoming or overdue occurrences can be skipped.", nil)
		}
		_, err = tx.Exec(ctx, `update recurring_occurrences set status = 'skipped' where id = $1`, occID)
	case "reopen":
		if status != "skipped" {
			return apperr.ConflictCode("occurrence_not_skipped", "Only skipped occurrences can be reopened.", nil)
		}
		_, err = tx.Exec(ctx, `update recurring_occurrences set status = 'scheduled', reminder_sent_at = null, overdue_notified_at = null where id = $1`, occID)
	case "postpone":
		d, perr := finance.ParseDate("body.postpone_to", a.PostponeTo, spec.Location)
		if perr != nil {
			return perr
		}
		d = dateOnly(d)
		if !open || !d.After(effective) {
			return apperr.Rule("postpone_needs_later_open_occurrence", "Postpone an open occurrence to a later date.", nil)
		}
		_, err = tx.Exec(ctx, `update recurring_occurrences set status = 'scheduled', postponed_to = $2, due_at = $3, reminder_sent_at = null,
			overdue_notified_at = null, overrides = overrides || '{"postponed":true}' where id = $1`, occID, d, spec.DueAt(d))
	case "set_amount":
		if !open {
			return apperr.ConflictCode("occurrence_already_handled", "This occurrence is already handled.", nil)
		}
		v, perr := finance.ParseAmount("body.amount", a.Amount, *x.Currency)
		if perr != nil {
			return perr
		}
		_, err = tx.Exec(ctx, `update recurring_occurrences set amount_minor = $2, overrides = overrides || '{"amount":true}' where id = $1`, occID, v)
	case "link_transaction":
		if a.TransactionID == nil {
			return apperr.FieldError("body.transaction_id", "Choose the transaction that paid this occurrence.")
		}
		err = s.linkTransaction(ctx, tx, uid, x, occID, status, *a.TransactionID)
	case "confirm":
		if !open {
			return apperr.ConflictCode("occurrence_already_handled", "This occurrence is already handled.", nil)
		}
		on := effective
		if today := localToday(s.now(), spec.Location); on.After(today) {
			on = today // paying early: record it today
		}
		if a.Date != "" {
			d, perr := finance.ParseDate("body.date", a.Date, spec.Location)
			if perr != nil {
				return perr
			}
			on = dateOnly(d)
		}
		_, err = s.postOccurrence(ctx, tx, x, occID, on, a.Amount, a.AccountID, "user")
	default:
		return apperr.BadRequest("Unknown action.")
	}
	if err != nil {
		return err
	}
	if err := s.refresh(ctx, tx, x); err != nil {
		return err
	}
	return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "recurring_occurrence", EntityID: &occID, Action: a.Action})
}

// linkTransaction marks an occurrence handled by an existing transaction.
func (s *Service) linkTransaction(ctx context.Context, tx pgx.Tx, uid uuid.UUID, x *ruleRow, occID uuid.UUID, status string, txID uuid.UUID) error {
	if status != "scheduled" && status != "overdue" {
		return apperr.ConflictCode("occurrence_already_handled", "This occurrence is already handled.", nil)
	}
	var typ, cur, txStatus string
	var amount int64
	var linkedOcc *uuid.UUID
	err := tx.QueryRow(ctx, `select type, currency, amount_minor, status, recurring_occurrence_id from transactions
		where id = $1 and user_id = $2 and deleted_at is null for update`, txID, uid).Scan(&typ, &cur, &amount, &txStatus, &linkedOcc)
	if database.IsNoRows(err) {
		return apperr.FieldError("body.transaction_id", "Transaction not found.")
	}
	if err != nil {
		return err
	}
	if txStatus == "voided" {
		return apperr.Rule("transaction_voided", "A voided transaction cannot pay an occurrence.", nil)
	}
	var otherOcc bool
	if err := tx.QueryRow(ctx, `select exists (select 1 from recurring_occurrences where transaction_id = $1 and id <> $2)`, txID, occID).
		Scan(&otherOcc); err != nil {
		return err
	}
	if otherOcc || (linkedOcc != nil && *linkedOcc != occID) {
		return apperr.New(apperr.CodeDuplicate, 409, "This transaction is already linked to another occurrence.")
	}
	want := map[string]string{"income": "income", "transfer": "transfer"}[x.Kind]
	if want == "" {
		want = "expense"
	}
	if typ != want && (want != "expense" || typ != "group_expense") {
		return apperr.FieldError("body.transaction_id", "Link a transaction of type "+want+".")
	}
	if x.Currency != nil && cur != *x.Currency {
		return apperr.FieldError("body.transaction_id", "The transaction currency must match ("+*x.Currency+").")
	}
	newStatus := "posted"
	if x.Kind == "bill" || x.Kind == "subscription" {
		newStatus = "paid"
	}
	if _, err := tx.Exec(ctx, `update transactions set recurring_rule_id = $2, recurring_occurrence_id = $3 where id = $1`, txID, x.ID, occID); err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `update recurring_occurrences set status = $2, transaction_id = $3, amount_minor = $4 where id = $1`, occID, newStatus, txID, amount)
	return err
}

// postOccurrence creates the transaction for an occurrence exactly once (the
// occurrence row is locked and records the transaction ID).
func (s *Service) postOccurrence(ctx context.Context, tx pgx.Tx, x *ruleRow, occID uuid.UUID, on time.Time, amountOverride string,
	accountOverride *uuid.UUID, actor string) (uuid.UUID, error) {
	var existing *uuid.UUID
	var occAmount *int64
	var status string
	if err := tx.QueryRow(ctx, `select transaction_id, amount_minor, status from recurring_occurrences where id = $1 for update`, occID).
		Scan(&existing, &occAmount, &status); err != nil {
		return uuid.Nil, err
	}
	if existing != nil {
		return *existing, nil // already posted: idempotent
	}
	if status != "scheduled" && status != "overdue" {
		return uuid.Nil, apperr.ConflictCode("occurrence_already_handled", "This occurrence is already handled.", nil)
	}
	acct := x.AccountID
	if accountOverride != nil {
		acct = accountOverride
	}
	if acct == nil {
		return uuid.Nil, apperr.FieldError("body.account_id", "Choose the account used for this payment.")
	}
	cur := *x.Currency
	var amount string
	switch {
	case amountOverride != "":
		amount = amountOverride
	case occAmount != nil:
		amount = apitypes.M(*occAmount, cur).Amount
	case x.amount != nil:
		amount = apitypes.M(*x.amount, cur).Amount
	default:
		return uuid.Nil, apperr.FieldError("body.amount", "Enter the amount for this occurrence.")
	}
	prov := &finance.Provenance{RecurringRule: &x.ID, Occurrence: &occID, ActorKind: actor}
	desc := x.Name
	if x.Description != nil {
		desc = *x.Description
	}
	notes := ""
	if x.Notes != nil {
		notes = *x.Notes
	}
	var txID uuid.UUID
	if x.Kind == "transfer" {
		if x.ToAccountID == nil {
			return uuid.Nil, apperr.Rule("transfer_missing_destination", "This transfer has no destination account.", nil)
		}
		t, err := s.Finance.CreateTransferInTx(ctx, tx, x.userID, finance.TransferInput{FromAccountID: *acct, ToAccountID: *x.ToAccountID,
			Amount: amount, LocalDate: finance.LocalDateString(on), Description: desc, Notes: notes}, "recurring", prov)
		if err != nil {
			return uuid.Nil, err
		}
		txID = t.FromTransactionID
	} else {
		typ := "expense"
		if x.Kind == "income" {
			typ = "income"
		}
		var err error
		txID, err = s.Finance.CreateInTx(ctx, tx, x.userID, finance.TransactionInput{Type: typ, AccountID: *acct, Amount: amount,
			LocalDate: finance.LocalDateString(on), Timezone: x.Timezone, CategoryID: x.CategoryID, MerchantID: x.MerchantID,
			Description: desc, Notes: notes}, "recurring", prov)
		if err != nil {
			return uuid.Nil, err
		}
	}
	newStatus := "posted"
	if x.Kind == "bill" || x.Kind == "subscription" {
		newStatus = "paid"
	}
	if _, err := tx.Exec(ctx, `update recurring_occurrences set status = $2, transaction_id = $3,
		amount_minor = (select amount_minor from transactions where id = $3) where id = $1`, occID, newStatus, txID); err != nil {
		return uuid.Nil, err
	}
	return txID, nil
}

// RegisterJobs registers the generator.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobGenerate, func(ctx context.Context, _ jobs.Job) error { return s.Generate(ctx) },
		jobs.WithTimeout(10*time.Minute), jobs.WithConcurrency(1))
}

// Generate is the scheduler entry point (system scope). Each step works in
// small transactions so one failing rule never blocks the others.
func (s *Service) Generate(ctx context.Context) error {
	var firstErr error
	note := func(step string, id uuid.UUID, err error) {
		slog.ErrorContext(ctx, "recurring step failed", slog.String("step", step), slog.String("id", id.String()), slog.Any("error", err))
		if firstErr == nil {
			firstErr = err
		}
	}
	now := s.now()
	// 1. Materialize horizons (any zone's local date is at most UTC+1 day).
	ids, err := s.ids(ctx, `select id from recurring_rules where status = 'active'
		and (generated_through is null or generated_through < $1::date) order by id limit 1000`, dateOnly(now.UTC()).AddDate(0, 0, horizonDays+1))
	if err != nil {
		return err
	}
	for _, id := range ids {
		if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return s.materialize(ctx, tx, id) }); err != nil {
			note("materialize", id, err)
		}
	}
	// 2. Auto-post due occurrences. Missed runs are always recovered;
	// failing posts are retried within a bounded window.
	due, err := s.ids(ctx, `select o.id from recurring_occurrences o join recurring_rules r on r.id = o.rule_id
		where o.status = 'scheduled' and o.transaction_id is null and o.due_at <= $1 and r.status = 'active' and r.auto_post
		and not r.amount_is_variable and r.kind in ('expense','income','transfer')
		and (o.first_failed_at is null or o.first_failed_at > $1::timestamptz - make_interval(days => $2))
		order by o.due_at limit $3`, now, autoPostRetryDays, batchSize)
	if err != nil {
		return err
	}
	for _, id := range due {
		if err := s.autoPost(ctx, id); err != nil {
			note("auto_post", id, err)
		}
	}
	// 2b. Recurring shared (group) expenses set to be added automatically.
	if s.GroupPoster != nil {
		gdue, err := s.ids(ctx, `select o.id from recurring_occurrences o join recurring_rules r on r.id = o.rule_id
			where o.status = 'scheduled' and o.group_expense_id is null and o.due_at <= $1 and r.status = 'active' and r.auto_post
			and r.kind = 'group_expense' and o.first_failed_at is null order by o.due_at limit $2`, now, batchSize)
		if err != nil {
			return err
		}
		for _, id := range gdue {
			if err := s.GroupPoster(ctx, id); err != nil {
				note("group_auto_add", id, err)
			}
		}
	}
	// 3. Overdue, 4. reminders.
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return s.markOverdue(ctx, tx, now) }); err != nil {
		return err
	}
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return s.sendReminders(ctx, tx, now) }); err != nil {
		return err
	}
	return firstErr
}

func (s *Service) ids(ctx context.Context, q string, args ...any) ([]uuid.UUID, error) {
	var out []uuid.UUID
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, q, args...)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		return err
	})
	return out, err
}

// autoPost posts one due occurrence in its own transaction. A domain failure
// (archived account, invalid amount) notifies the owner once and is retried
// on later runs for a bounded period.
func (s *Service) autoPost(ctx context.Context, occID uuid.UUID) error {
	var x *ruleRow
	var postErr error
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var ruleID uuid.UUID
		var date time.Time
		var postponed *time.Time
		err := tx.QueryRow(ctx, `select rule_id, occurrence_date, postponed_to from recurring_occurrences
			where id = $1 and status = 'scheduled' and transaction_id is null for update skip locked`, occID).Scan(&ruleID, &date, &postponed)
		if database.IsNoRows(err) {
			return nil // handled concurrently or by the user
		}
		if err != nil {
			return err
		}
		if x, err = scanRule(tx.QueryRow(ctx, `select `+ruleCols+` from recurring_rules where id = $1`, ruleID)); err != nil {
			return err
		}
		on := date
		if postponed != nil {
			on = *postponed
		}
		if _, err := s.postOccurrence(ctx, tx, x, occID, on, "", nil, "recurring"); err != nil {
			postErr = err
			return err
		}
		return s.refresh(ctx, tx, x)
	})
	if err == nil {
		return nil
	}
	var ae *apperr.Error
	if postErr == nil || !errors.As(postErr, &ae) || ae.Status >= 500 || x == nil {
		return err // infrastructure error: the job retries
	}
	now := s.now()
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `update recurring_occurrences set auto_post_attempts = least(auto_post_attempts + 1, 32000),
			first_failed_at = coalesce(first_failed_at, $2), last_failure_code = $3 where id = $1`, occID, now, string(ae.Code)); err != nil {
			return err
		}
		_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: x.userID, Category: "recurring",
			EventType: "recurring_post_failed", Title: x.Name + " could not be recorded automatically",
			Body: "Open the schedule to record or skip this occurrence.", DeepLink: "/planning/recurring/" + x.ID.String(),
			EntityType: "recurring_rule", EntityID: &x.ID, Priority: "high", DedupeKey: "recurring_fail:" + occID.String()})
		return err
	})
}

// markOverdue moves open occurrences whose (effective) day has ended to
// overdue and notifies once per occurrence. Auto-post occurrences become
// overdue only after their bounded retry window.
func (s *Service) markOverdue(ctx context.Context, tx pgx.Tx, now time.Time) error {
	if _, err := tx.Exec(ctx, `update recurring_occurrences o set status = 'overdue' from recurring_rules r
		where r.id = o.rule_id and o.status = 'scheduled' and o.transaction_id is null and r.status = 'active'
		and coalesce(o.postponed_to, o.occurrence_date) < ($1::timestamptz at time zone r.timezone)::date
		and (not r.auto_post or r.amount_is_variable or r.kind not in ('expense','income','transfer')
		     or o.first_failed_at <= $1::timestamptz - make_interval(days => $2))`, now, autoPostRetryDays); err != nil {
		return err
	}
	type od struct {
		id, user, rule uuid.UUID
		name, kind     string
		bill, group    *uuid.UUID
	}
	rows, err := tx.Query(ctx, `select o.id, o.user_id, r.id, r.name, r.kind, b.id, r.group_id from recurring_occurrences o
		join recurring_rules r on r.id = o.rule_id left join bills b on b.recurring_rule_id = r.id
		where o.status = 'overdue' and o.overdue_notified_at is null order by o.due_at limit $1`, batchSize)
	if err != nil {
		return err
	}
	list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (od, error) {
		var x od
		err := r.Scan(&x.id, &x.user, &x.rule, &x.name, &x.kind, &x.bill, &x.group)
		return x, err
	})
	if err != nil {
		return err
	}
	for _, o := range list {
		n := notifications.Notification{UserID: o.user, Category: "recurring", EventType: "recurring_overdue",
			Title: o.name + " is waiting to be recorded", Body: "Confirm it, link the transaction, or skip it.",
			DeepLink: "/planning/recurring/" + o.rule.String(), EntityType: "recurring_rule", EntityID: &o.rule, DedupeKey: "overdue:" + o.id.String()}
		if o.group != nil {
			n.Body, n.GroupID = "Add it to the group or skip it.", o.group
			n.DeepLink, n.EntityType = "/groups/"+o.group.String()+"/recurring", "group_recurring_expense"
		}
		if o.bill != nil {
			n.Category, n.EventType, n.Priority = "bill", "bill_overdue", "high"
			n.Title, n.Body = o.name+" is overdue", "Mark it paid by linking the payment, or skip this one."
			n.DeepLink, n.EntityType, n.EntityID = "/planning/bills/"+o.bill.String(), "bill", o.bill
		}
		if _, _, err := notifications.Create(ctx, tx, n); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update recurring_occurrences set overdue_notified_at = $2 where id = $1`, o.id, now); err != nil {
			return err
		}
	}
	return nil
}

// sendReminders notifies once per occurrence when its reminder window opens.
func (s *Service) sendReminders(ctx context.Context, tx pgx.Tx, now time.Time) error {
	type rem struct {
		id, user, rule uuid.UUID
		name, kind     string
		date           time.Time
		bill           *uuid.UUID
		today          time.Time
		group          *uuid.UUID
	}
	rows, err := tx.Query(ctx, `select o.id, o.user_id, r.id, r.name, r.kind, coalesce(o.postponed_to, o.occurrence_date), b.id,
		($1::timestamptz at time zone r.timezone)::date, r.group_id
		from recurring_occurrences o join recurring_rules r on r.id = o.rule_id left join bills b on b.recurring_rule_id = r.id
		where o.status = 'scheduled' and o.transaction_id is null and o.reminder_sent_at is null and r.status = 'active' and not r.auto_post
		and coalesce(o.postponed_to, o.occurrence_date) >= ($1::timestamptz at time zone r.timezone)::date
		and exists (select 1 from unnest(r.reminder_days_before) d
		            where coalesce(o.postponed_to, o.occurrence_date) - d <= ($1::timestamptz at time zone r.timezone)::date)
		order by o.due_at limit $2`, now, batchSize)
	if err != nil {
		return err
	}
	list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (rem, error) {
		var x rem
		err := r.Scan(&x.id, &x.user, &x.rule, &x.name, &x.kind, &x.date, &x.bill, &x.today, &x.group)
		return x, err
	})
	if err != nil {
		return err
	}
	for _, r := range list {
		n := notifications.Notification{UserID: r.user, Category: "recurring", EventType: "recurring_due_soon",
			Title: r.name + " is due " + humanDue(r.date, r.today), Body: "Open Montra to review or record it.",
			DeepLink: "/planning/recurring/" + r.rule.String(), EntityType: "recurring_rule", EntityID: &r.rule, DedupeKey: "reminder:" + r.id.String()}
		if r.bill != nil {
			n.Category, n.EventType = "bill", "bill_due_soon"
			n.DeepLink, n.EntityType, n.EntityID = "/planning/bills/"+r.bill.String(), "bill", r.bill
		}
		if r.group != nil {
			n.Body, n.GroupID = "Add it to the group when it is paid.", r.group
			n.DeepLink, n.EntityType = "/groups/"+r.group.String()+"/recurring", "group_recurring_expense"
		}
		if _, _, err := notifications.Create(ctx, tx, n); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update recurring_occurrences set reminder_sent_at = $2 where id = $1`, r.id, now); err != nil {
			return err
		}
	}
	return nil
}

func humanDue(d, today time.Time) string {
	switch days := int(dateOnly(d).Sub(dateOnly(today)).Hours() / 24); days {
	case 0:
		return "today"
	case 1:
		return "tomorrow"
	default:
		return "on " + d.Format("2 Jan")
	}
}
