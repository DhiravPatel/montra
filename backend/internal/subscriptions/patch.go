package subscriptions

import (
	"context"
	"encoding/json"
	"reflect"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/currency"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
)

// SubscriptionPatch changes only the fields sent; omitted fields keep their
// values (including reminders and the renewal date). Optional text and
// dates are cleared with an empty string, links to other records through
// clear (the pattern of BillPatch). Every field of SubscriptionInput is
// accepted, so a client that sends the full record keeps working.
type SubscriptionPatch struct {
	Name                     *string                      `json:"name,omitempty" minLength:"1" maxLength:"120"`
	PlanName                 *string                      `json:"plan_name,omitempty" maxLength:"120" doc:"Empty string clears it"`
	MerchantName             *string                      `json:"merchant_name,omitempty" maxLength:"120" doc:"Matched to one of your merchants (or created); empty string clears it"`
	CategoryID               *uuid.UUID                   `json:"category_id,omitempty"`
	Amount                   *string                      `json:"amount,omitempty" doc:"Price per billing cycle (decimal); a change is kept in the price history"`
	Currency                 *string                      `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"A different currency also needs amount (the price in the new currency)"`
	BillingFrequency         *string                      `json:"billing_frequency,omitempty" enum:"weekly,monthly,quarterly,semiannual,yearly,custom"`
	IntervalCount            *int16                       `json:"interval_count,omitempty" minimum:"1" maximum:"366" doc:"Custom frequency: every N units"`
	IntervalUnit             *string                      `json:"interval_unit,omitempty" enum:"day,week,month,year" doc:"Custom frequency unit"`
	StartDate                *string                      `json:"start_date,omitempty" doc:"YYYY-MM-DD the subscription started"`
	NextRenewalDate          *string                      `json:"next_renewal_date,omitempty" doc:"YYYY-MM-DD. Empty string recomputes it from the schedule; when omitted it is kept, unless the schedule (frequency, interval, start or trial end) changes, which recomputes it. Cancelled subscriptions are never given a computed date"`
	TrialEndsOn              *string                      `json:"trial_ends_on,omitempty" doc:"YYYY-MM-DD; empty string clears it"`
	PaymentAccountID         *uuid.UUID                   `json:"payment_account_id,omitempty" doc:"One of your active accounts"`
	CancellationURL          *string                      `json:"cancellation_url,omitempty" maxLength:"500" doc:"Official https:// page you verified; empty string clears it"`
	CancellationInstructions *string                      `json:"cancellation_instructions,omitempty" maxLength:"4000" doc:"Empty string clears it"`
	CancellationChecklist    *[]CancellationChecklistItem `json:"cancellation_checklist,omitempty" maxItems:"20" doc:"Replaces the whole checklist; [] clears it"`
	InvoiceFileID            *uuid.UUID                   `json:"invoice_file_id,omitempty" doc:"An uploaded subscription_invoice file you own"`
	Notes                    *string                      `json:"notes,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	ReminderDaysBefore       *[]int16                     `json:"reminder_days_before,omitempty" maxItems:"5" doc:"Replaces the renewal reminder offsets (0-30 days); [] turns renewal reminders off"`
	GroupID                  *uuid.UUID                   `json:"group_id,omitempty" doc:"Track as shared with a group you belong to"`
	CancelledOn              *string                      `json:"cancelled_on,omitempty" doc:"Cancelled subscriptions only: correct the YYYY-MM-DD the cancellation took effect (DOMAIN_RULE_VIOLATION subscription_not_cancelled otherwise)"`
	Clear                    []string                     `json:"clear,omitempty" maxItems:"4" enum:"category_id,payment_account_id,invoice_file_id,group_id" doc:"Optional links to remove (stop sharing with the group: group_id). Sending a field and clearing it answers 422"`
	Version                  int32                        `json:"version,omitempty" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

// patch turns a create request into a patch over the defaults of a new
// subscription (empty optional values mean "not set").
func (in SubscriptionInput) patch() SubscriptionPatch {
	opt := func(s string) *string {
		if s == "" {
			return nil
		}
		return &s
	}
	p := SubscriptionPatch{Name: &in.Name, PlanName: opt(in.PlanName), MerchantName: opt(in.MerchantName), CategoryID: in.CategoryID,
		Amount: &in.Amount, Currency: opt(in.Currency), BillingFrequency: &in.BillingFrequency, IntervalUnit: in.IntervalUnit,
		StartDate: &in.StartDate, NextRenewalDate: opt(in.NextRenewalDate), TrialEndsOn: opt(in.TrialEndsOn), PaymentAccountID: in.PaymentAccountID,
		CancellationURL: opt(in.CancellationURL), CancellationInstructions: opt(in.CancellationInstructions), InvoiceFileID: in.InvoiceFileID,
		Notes: opt(in.Notes), GroupID: in.GroupID}
	if in.IntervalCount != 0 {
		p.IntervalCount = &in.IntervalCount
	}
	if in.CancellationChecklist != nil {
		p.CancellationChecklist = &in.CancellationChecklist
	}
	if in.ReminderDaysBefore != nil {
		p.ReminderDaysBefore = &in.ReminderDaysBefore
	}
	return p
}

// sentFields lists the JSON names of the fields a patch sets (for audit).
func sentFields(p any) []string {
	v := reflect.ValueOf(p)
	t := v.Type()
	out := []string{}
	for i := 0; i < t.NumField(); i++ {
		name, _, _ := strings.Cut(t.Field(i).Tag.Get("json"), ",")
		f := v.Field(i)
		switch {
		case name == "version" || name == "":
		case f.Kind() == reflect.Pointer && !f.IsNil(), f.Kind() == reflect.Slice && f.Len() > 0:
			out = append(out, name)
		}
	}
	return out
}

// normalized is a validated subscription definition.
type normalized struct {
	name, freq                string
	plan, instructions, notes *string
	url                       *string
	merchant, category        *uuid.UUID
	amount                    int64
	cur                       string
	interval                  int16
	unit                      *string
	start                     time.Time
	next, trial               *time.Time
	account, invoice, group   *uuid.UUID
	checklist                 []byte
	reminders                 []int16
	status                    string // trial | active, from the trial end (applied to trial/active subscriptions)
}

// newDefinition is what a new subscription starts from.
func newDefinition() *normalized {
	return &normalized{interval: 1, reminders: []int16{3}, checklist: []byte("[]")}
}

// loadDefinition reads a subscription's stored definition.
func loadDefinition(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*normalized, error) {
	n := &normalized{}
	err := tx.QueryRow(ctx, `select name, plan_name, merchant_id, category_id, amount_minor, currency, billing_frequency, interval_count,
		interval_unit, start_date, next_renewal_date, trial_ends_on, payment_account_id, cancellation_url, cancellation_instructions,
		cancellation_checklist, invoice_file_id, notes, reminder_days_before, group_id from subscriptions where id = $1`, id).
		Scan(&n.name, &n.plan, &n.merchant, &n.category, &n.amount, &n.cur, &n.freq, &n.interval, &n.unit, &n.start, &n.next, &n.trial,
			&n.account, &n.url, &n.instructions, &n.checklist, &n.invoice, &n.notes, &n.reminders, &n.group)
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("subscription")
	}
	if err != nil {
		return nil, err
	}
	if n.reminders == nil {
		n.reminders = []int16{}
	}
	if len(n.checklist) == 0 {
		n.checklist = []byte("[]")
	}
	return n, nil
}

func sameDay(a, b *time.Time) bool {
	if a == nil || b == nil {
		return a == b
	}
	return a.Equal(*b)
}

func sameText(a, b *string) bool {
	if a == nil || b == nil {
		return a == b
	}
	return *a == *b
}

// clearSet validates a clear list: a field cannot be both sent and
// cleared.
func clearSet(clear []string, sent map[string]bool) (map[string]bool, error) {
	out := map[string]bool{}
	for _, f := range clear {
		if sent[f] {
			return nil, apperr.FieldError("body.clear", "Send a new value for "+f+" or clear it, not both.")
		}
		out[f] = true
	}
	return out, nil
}

// apply validates the fields a patch sets and applies them to n. status is
// the subscription's current status ("" when creating).
func (s *Service) apply(ctx context.Context, tx pgx.Tx, u finance.UserContext, n *normalized, p *SubscriptionPatch, status string, creating bool) error {
	clear, err := clearSet(p.Clear, map[string]bool{"category_id": p.CategoryID != nil, "payment_account_id": p.PaymentAccountID != nil,
		"invoice_file_id": p.InvoiceFileID != nil, "group_id": p.GroupID != nil})
	if err != nil {
		return err
	}
	uid := u.ID
	today := localToday(s.now(), u.Timezone)
	prevFreq, prevInterval, prevUnit, prevStart, prevTrial := n.freq, n.interval, n.unit, n.start, n.trial
	if p.Name != nil {
		if n.name = strings.TrimSpace(*p.Name); n.name == "" {
			return apperr.FieldError("body.name", "Enter a name.")
		}
	}
	if p.BillingFrequency != nil {
		n.freq = *p.BillingFrequency
	}
	if p.IntervalCount != nil {
		n.interval = *p.IntervalCount
	}
	if p.IntervalUnit != nil {
		unit := *p.IntervalUnit
		n.unit = &unit
	}
	if n.freq == "custom" {
		if n.unit == nil {
			return apperr.FieldError("body.interval_unit", "Custom billing needs an interval unit.")
		}
		n.interval = max(n.interval, 1)
	} else {
		n.interval, n.unit = 1, nil
	}
	accountCurrency := ""
	if clear["payment_account_id"] {
		n.account = nil
	}
	if p.PaymentAccountID != nil {
		if err := tx.QueryRow(ctx, `select currency from financial_accounts where id = $1 and user_id = $2 and status = 'active'`,
			*p.PaymentAccountID, uid).Scan(&accountCurrency); err != nil {
			if database.IsNoRows(err) {
				return apperr.FieldError("body.payment_account_id", "Choose one of your active accounts.")
			}
			return err
		}
		n.account = p.PaymentAccountID
	}
	switch {
	case creating:
		if p.Currency != nil {
			n.cur = *p.Currency
		}
		if n.cur == "" {
			n.cur = accountCurrency
		}
		if n.cur == "" {
			n.cur = u.BaseCurrency
		}
		if !currency.Selectable(n.cur) {
			return apperr.FieldError("body.currency", "Unsupported currency.")
		}
	case p.Currency != nil && *p.Currency != n.cur:
		if !currency.Selectable(*p.Currency) {
			return apperr.FieldError("body.currency", "Unsupported currency.")
		}
		if p.Amount == nil {
			return apperr.FieldError("body.amount", "Enter the price in the new currency.")
		}
		n.cur = *p.Currency
	}
	if p.Amount != nil {
		v, err := finance.ParseAmount("body.amount", *p.Amount, n.cur)
		if err != nil {
			return err
		}
		n.amount = v
	}
	if p.StartDate != nil {
		d, err := finance.ParseDate("body.start_date", *p.StartDate, u.Loc)
		if err != nil {
			return err
		}
		n.start = dateOnly(d)
	}
	if p.TrialEndsOn != nil {
		n.trial = nil
		if *p.TrialEndsOn != "" {
			d, err := finance.ParseDate("body.trial_ends_on", *p.TrialEndsOn, u.Loc)
			if err != nil {
				return err
			}
			d = dateOnly(d)
			n.trial = &d
		}
	}
	if n.trial != nil && n.trial.Before(n.start) {
		return apperr.FieldError("body.trial_ends_on", "The trial cannot end before the start date.")
	}
	scheduleChanged := creating || n.freq != prevFreq || n.interval != prevInterval || !sameText(n.unit, prevUnit) ||
		!n.start.Equal(prevStart) || !sameDay(n.trial, prevTrial)
	switch {
	case p.NextRenewalDate != nil && *p.NextRenewalDate != "":
		d, err := finance.ParseDate("body.next_renewal_date", *p.NextRenewalDate, u.Loc)
		if err != nil {
			return err
		}
		d = dateOnly(d)
		n.next = &d
	case status == "cancelled":
		// A cancelled subscription has no upcoming renewal.
	case p.NextRenewalDate != nil || scheduleChanged:
		anchor := n.start
		if n.trial != nil {
			anchor = *n.trial // the first paid renewal follows the trial
		}
		n.next = nil
		if next, ok := RenewalSchedule(n.freq, n.interval, n.unit, n.start, anchor).Next(today); ok {
			n.next = &next
		}
	}
	n.status = "active"
	if n.trial != nil && !n.trial.Before(today) {
		n.status = "trial"
	}
	if p.MerchantName != nil {
		n.merchant = nil
		if strings.TrimSpace(*p.MerchantName) != "" {
			m, err := s.Finance.ResolveMerchantName(ctx, tx, uid, *p.MerchantName)
			if err != nil {
				return err
			}
			n.merchant = m
		}
	}
	if clear["category_id"] {
		n.category = nil
	}
	if p.CategoryID != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from categories where id = $1 and user_id = $2 and status = 'active')`,
			*p.CategoryID, uid).Scan(&ok); err != nil {
			return err
		}
		if !ok {
			return apperr.FieldError("body.category_id", "Category not found.")
		}
		n.category = p.CategoryID
	}
	if p.CancellationURL != nil {
		n.url = nil
		if v := strings.TrimSpace(*p.CancellationURL); v != "" {
			if !strings.HasPrefix(strings.ToLower(v), "https://") || strings.ContainsAny(v, " \t\r\n<>\"") {
				return apperr.FieldError("body.cancellation_url", "Use the provider's official https:// page.")
			}
			n.url = &v
		}
	}
	if p.PlanName != nil {
		n.plan = trim(*p.PlanName, 120)
	}
	if p.CancellationInstructions != nil {
		n.instructions = trim(*p.CancellationInstructions, 4000)
	}
	if p.Notes != nil {
		n.notes = trim(*p.Notes, 2000)
	}
	if p.CancellationChecklist != nil {
		checklist := append([]CancellationChecklistItem{}, *p.CancellationChecklist...)
		for i := range checklist {
			if checklist[i].Item = strings.TrimSpace(checklist[i].Item); checklist[i].Item == "" {
				return apperr.FieldError("body.cancellation_checklist", "Checklist items need text.")
			}
		}
		b, err := json.Marshal(checklist)
		if err != nil {
			return err
		}
		n.checklist = b
	}
	if p.ReminderDaysBefore != nil {
		reminders := append([]int16{}, *p.ReminderDaysBefore...)
		for _, d := range reminders {
			if d < 0 || d > 30 {
				return apperr.FieldError("body.reminder_days_before", "Reminders can be 0-30 days before.")
			}
		}
		n.reminders = reminders
	}
	if clear["invoice_file_id"] {
		n.invoice = nil
	}
	if p.InvoiceFileID != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from files where id = $1 and owner_user_id = $2 and purpose = 'subscription_invoice'
			and status = 'ready')`, *p.InvoiceFileID, uid).Scan(&ok); err != nil {
			return err
		}
		if !ok {
			return apperr.FieldError("body.invoice_file_id", "Upload the invoice first (purpose subscription_invoice).")
		}
		n.invoice = p.InvoiceFileID
	}
	if clear["group_id"] {
		n.group = nil
	}
	if p.GroupID != nil {
		var member bool
		if err := tx.QueryRow(ctx, `select montra.is_group_member($1)`, *p.GroupID).Scan(&member); err != nil {
			return err
		}
		if !member {
			return apperr.FieldError("body.group_id", "Share only with a group you belong to.")
		}
		n.group = p.GroupID
	}
	return nil
}
