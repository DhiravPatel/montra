package goals

import (
	"context"
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

// GoalPatch changes only the fields sent; omitted fields keep their values
// (milestones and the starting amount included). Optional text, dates and
// amounts are cleared with an empty string, optional links through clear
// (the pattern of BillPatch). Every field of GoalInput is accepted, so a
// client that sends the full record keeps working.
type GoalPatch struct {
	Name                 *string               `json:"name,omitempty" minLength:"1" maxLength:"120"`
	Description          *string               `json:"description,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	GoalType             *string               `json:"goal_type,omitempty" enum:"emergency_fund,travel,education,device,vehicle,home,event,debt_payoff,large_purchase,custom"`
	TargetAmount         *string               `json:"target_amount,omitempty" doc:"Decimal; changing the target never rewrites contributions"`
	Currency             *string               `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Cannot change after creation; accepted when equal to the goal currency"`
	StartingAmount       *string               `json:"starting_amount,omitempty" doc:"Saved before you started tracking; empty string sets it to zero"`
	StartDate            *string               `json:"start_date,omitempty" doc:"YYYY-MM-DD"`
	TargetDate           *string               `json:"target_date,omitempty" doc:"YYYY-MM-DD; empty string clears it"`
	Priority             *int16                `json:"priority,omitempty" minimum:"1" maximum:"5" doc:"1 = highest"`
	LinkedAccountID      *uuid.UUID            `json:"linked_account_id,omitempty" doc:"Informational; the balance is not counted automatically"`
	ContributionSchedule *string               `json:"contribution_schedule,omitempty" enum:"none,weekly,biweekly,monthly"`
	PlannedContribution  *string               `json:"planned_contribution,omitempty" doc:"Planned amount per schedule period; empty string clears it (schedule none only)"`
	Visibility           *string               `json:"visibility,omitempty" enum:"private,members"`
	RemindersEnabled     *bool                 `json:"reminders_enabled,omitempty"`
	Notes                *string               `json:"notes,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	GroupID              *uuid.UUID            `json:"group_id,omitempty" doc:"Share with a group you belong to"`
	Milestones           *[]GoalMilestoneInput `json:"milestones,omitempty" maxItems:"10" doc:"Replaces the milestones (reached dates are kept for percentages that remain); [] removes them all"`
	Clear                []string              `json:"clear,omitempty" maxItems:"2" enum:"linked_account_id,group_id" doc:"Optional links to remove. Sending a field and clearing it answers 422"`
	Version              int32                 `json:"version,omitempty" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

// patch turns a create request into a patch over the defaults of a new
// goal (empty optional values mean "not set").
func (in GoalInput) patch() GoalPatch {
	opt := func(s string) *string {
		if s == "" {
			return nil
		}
		return &s
	}
	p := GoalPatch{Name: &in.Name, Description: opt(in.Description), GoalType: &in.GoalType, TargetAmount: &in.TargetAmount,
		Currency: opt(in.Currency), StartingAmount: opt(in.StartingAmount), StartDate: opt(in.StartDate), TargetDate: opt(in.TargetDate),
		LinkedAccountID: in.LinkedAccountID, ContributionSchedule: opt(in.ContributionSchedule), PlannedContribution: opt(in.PlannedContribution),
		Visibility: opt(in.Visibility), RemindersEnabled: &in.RemindersEnabled, Notes: opt(in.Notes), GroupID: in.GroupID}
	if in.Priority != 0 {
		p.Priority = &in.Priority
	}
	if in.Milestones != nil {
		p.Milestones = &in.Milestones
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

// normalized is a validated goal definition.
type normalized struct {
	name, goalType, schedule, visibility string
	description, notes                   *string
	target, starting                     int64
	cur                                  string
	start                                time.Time
	targetDate                           *time.Time
	priority                             int16
	account, group                       *uuid.UUID
	planned                              *int64
	reminders                            bool
	milestones                           []GoalMilestoneInput // nil: keep the stored milestones
}

// newDefinition is what a new goal starts from.
func newDefinition(today time.Time) *normalized {
	return &normalized{schedule: "none", visibility: "private", priority: 3, start: today,
		milestones: []GoalMilestoneInput{{Percent: 25}, {Percent: 50}, {Percent: 75}, {Percent: 100}}}
}

// loadDefinition reads a goal's stored definition (milestones excluded).
func loadDefinition(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*normalized, error) {
	n := &normalized{}
	err := tx.QueryRow(ctx, `select name, description, goal_type, target_amount_minor, currency, starting_amount_minor, start_date, target_date,
		priority, linked_account_id, contribution_schedule, planned_contribution_minor, visibility, reminders_enabled, notes, group_id
		from goals where id = $1`, id).Scan(&n.name, &n.description, &n.goalType, &n.target, &n.cur, &n.starting, &n.start, &n.targetDate,
		&n.priority, &n.account, &n.schedule, &n.planned, &n.visibility, &n.reminders, &n.notes, &n.group)
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("goal")
	}
	return n, err
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

// apply validates the fields a patch sets and applies them to n.
func (s *Service) apply(ctx context.Context, tx pgx.Tx, u finance.UserContext, n *normalized, p *GoalPatch, creating bool) error {
	clear, err := clearSet(p.Clear, map[string]bool{"linked_account_id": p.LinkedAccountID != nil, "group_id": p.GroupID != nil})
	if err != nil {
		return err
	}
	if p.Name != nil {
		if n.name = strings.TrimSpace(*p.Name); n.name == "" {
			return apperr.FieldError("body.name", "Enter a name.")
		}
	}
	if p.Description != nil {
		n.description = trim(*p.Description, 2000)
	}
	if p.GoalType != nil {
		n.goalType = *p.GoalType
	}
	switch {
	case creating:
		if p.Currency != nil {
			n.cur = *p.Currency
		}
		if n.cur == "" {
			n.cur = u.BaseCurrency
		}
		if !currency.Selectable(n.cur) {
			return apperr.FieldError("body.currency", "Unsupported currency.")
		}
	case p.Currency != nil && *p.Currency != n.cur:
		return apperr.FieldError("body.currency", "A goal's currency cannot change after creation.")
	}
	if p.TargetAmount != nil {
		v, err := finance.ParseAmount("body.target_amount", *p.TargetAmount, n.cur)
		if err != nil {
			return err
		}
		n.target = v
	}
	if p.StartingAmount != nil {
		n.starting = 0
		if *p.StartingAmount != "" {
			v, err := finance.ParseSignedAmount("body.starting_amount", *p.StartingAmount, n.cur)
			if err != nil || v < 0 {
				return apperr.FieldError("body.starting_amount", "Enter zero or a positive amount.")
			}
			n.starting = v
		}
	}
	if p.StartDate != nil {
		d, err := finance.ParseDate("body.start_date", *p.StartDate, u.Loc)
		if err != nil {
			return err
		}
		n.start = dateOnly(d)
	}
	if p.TargetDate != nil {
		n.targetDate = nil
		if *p.TargetDate != "" {
			d, err := finance.ParseDate("body.target_date", *p.TargetDate, u.Loc)
			if err != nil {
				return err
			}
			d = dateOnly(d)
			n.targetDate = &d
		}
	}
	if n.targetDate != nil && n.targetDate.Before(n.start) {
		return apperr.FieldError("body.target_date", "The target date must be on or after the start date.")
	}
	if p.Priority != nil {
		n.priority = *p.Priority
	}
	if clear["linked_account_id"] {
		n.account = nil
	}
	if p.LinkedAccountID != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from financial_accounts where id = $1 and user_id = $2)`, *p.LinkedAccountID, u.ID).Scan(&ok); err != nil {
			return err
		}
		if !ok {
			return apperr.FieldError("body.linked_account_id", "Choose one of your accounts.")
		}
		n.account = p.LinkedAccountID
	}
	if p.ContributionSchedule != nil {
		n.schedule = *p.ContributionSchedule
	}
	if p.PlannedContribution != nil {
		n.planned = nil
		if *p.PlannedContribution != "" {
			v, err := finance.ParseAmount("body.planned_contribution", *p.PlannedContribution, n.cur)
			if err != nil {
				return err
			}
			n.planned = &v
		}
	}
	if n.schedule != "none" && n.planned == nil {
		return apperr.FieldError("body.planned_contribution", "Enter the planned amount for the contribution schedule.")
	}
	if p.Visibility != nil {
		n.visibility = *p.Visibility
	}
	if p.RemindersEnabled != nil {
		n.reminders = *p.RemindersEnabled
	}
	if p.Notes != nil {
		n.notes = trim(*p.Notes, 2000)
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
	if p.Milestones != nil {
		ms := append([]GoalMilestoneInput{}, *p.Milestones...)
		seen := map[int16]bool{}
		for _, m := range ms {
			if m.Percent < 1 || m.Percent > 100 || seen[m.Percent] {
				return apperr.FieldError("body.milestones", "Milestones are distinct percentages from 1 to 100.")
			}
			seen[m.Percent] = true
		}
		n.milestones = ms
	}
	return nil
}
