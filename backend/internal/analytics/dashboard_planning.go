package analytics

import (
	"context"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/budgets"
	"montra/backend/internal/finance"
	"montra/backend/internal/goals"
	"montra/backend/internal/groups"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/recurring"
)

// Dashboard planning card limits: the cards show the most pressing items
// and link to the full lists, which hold the counts.
const (
	planningBudgets  = 5
	planningUpcoming = 8
	planningGoals    = 4
	planningGroups   = 5
	planningAlerts   = 5
	planningRenewals = 6
	// UpcomingDays is how far ahead the upcoming card looks.
	UpcomingDays = 14
	// RenewalDays is how far ahead the renewals card looks.
	RenewalDays = 30
	// alertScan bounds how many active alerts are counted.
	alertScan = 200
	// overdueLookback is how far back overdue items are collected.
	overdueLookback = 60
)

// GroupBalance is your open balance in one group.
type GroupBalance struct {
	GroupID   uuid.UUID      `json:"group_id"`
	Name      string         `json:"name"`
	GroupType string         `json:"group_type" enum:"household,roommates,trip,event,friends,custom"`
	MyNet     apitypes.Money `json:"my_net" doc:"Positive: you are owed; negative: you owe (group currency)"`
}

// DashboardPlanning is the planning side of the dashboard: the budgets,
// bills and renewals, goals and group balances that need attention. Each
// list is short and ordered by urgency; the counts say how many exist.
type DashboardPlanning struct {
	Today           string `json:"today" doc:"Your local date (YYYY-MM-DD)"`
	UpcomingThrough string `json:"upcoming_through" doc:"Last date the upcoming list covers (today + 14 days)"`

	Budgets         []budgets.BudgetDTO `json:"budgets" doc:"Active budgets, fullest first (percent of limit spent), up to 5"`
	BudgetCount     int                 `json:"budget_count" doc:"Active budgets"`
	OverBudgetCount int                 `json:"over_budget_count"`

	Upcoming      []recurring.CalendarItem `json:"upcoming" doc:"Overdue items first (oldest first), then items due from today through upcoming_through, up to 8. Bills, recurring transactions, shared recurring expenses, subscription renewals, trial ends and goal target dates"`
	UpcomingCount int                      `json:"upcoming_count" doc:"All items the list was taken from"`
	OverdueCount  int                      `json:"overdue_count"`

	Goals     []goals.GoalDTO `json:"goals" doc:"Active goals, nearest target date first (goals without one last, then by priority), up to 4"`
	GoalCount int             `json:"goal_count" doc:"Active goals"`

	GroupBalances []GroupBalance `json:"group_balances" doc:"Active groups where you are owed or owe, largest amounts first within each currency, up to 5"`
	GroupCount    int            `json:"group_count" doc:"Active groups with an open balance"`

	Alerts     []budgets.AlertDTO `json:"alerts" doc:"Active budget alerts, newest first, up to 5 (dismiss or snooze them with the budget alert endpoints)"`
	AlertCount int                `json:"alert_count" doc:"Active budget alerts (counted up to 200)"`

	RenewalsThrough string                   `json:"renewals_through" doc:"Last date the renewals list covers (today + 30 days)"`
	Renewals        []recurring.CalendarItem `json:"renewals" doc:"Subscription renewals and trial ends from today through renewals_through, soonest first, up to 6"`
	RenewalCount    int                      `json:"renewal_count"`

	Recurring         []RecurringCommitment `json:"recurring" doc:"Active recurring commitments per kind and currency, normalized to a month (as GET /analytics/recurring)"`
	RecurringNoteCode string                `json:"recurring_note_code" enum:"fixed_amounts_expectations" doc:"How the monthly figures are calculated (localize by code)"`
}

// PlanningCards gathers the planning cards from the feature services.
type PlanningCards struct {
	Budgets   *budgets.Service
	Goals     *goals.Service
	Recurring *recurring.Service
	Groups    *groups.Service
	Now       func() time.Time
}

func (p *PlanningCards) now() time.Time {
	if p.Now != nil {
		return p.Now()
	}
	return time.Now()
}

// Planning builds the dashboard planning summary for the caller.
func (s *Service) Planning(ctx context.Context, p *PlanningCards) (*DashboardPlanning, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var loc *time.Location
	if err := s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		loc = u.Loc
		return nil
	}); err != nil {
		return nil, database.MapError(err)
	}
	now := p.now().In(loc)
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	through := today.AddDate(0, 0, UpcomingDays)
	out := &DashboardPlanning{Today: finance.LocalDateString(today), UpcomingThrough: finance.LocalDateString(through),
		RenewalsThrough: finance.LocalDateString(today.AddDate(0, 0, RenewalDays)),
		Budgets:         []budgets.BudgetDTO{}, Upcoming: []recurring.CalendarItem{}, Goals: []goals.GoalDTO{}, GroupBalances: []GroupBalance{},
		Alerts: []budgets.AlertDTO{}, Renewals: []recurring.CalendarItem{}, Recurring: []RecurringCommitment{}}

	// Budgets: fullest first.
	bl, err := p.Budgets.List(ctx, false)
	if err != nil {
		return nil, err
	}
	active := make([]budgets.BudgetDTO, 0, len(bl))
	for _, b := range bl {
		if b.Status != "active" {
			continue
		}
		active = append(active, b)
		if b.Progress != nil && b.Progress.Pace == "over_budget" {
			out.OverBudgetCount++
		}
	}
	pct := func(b budgets.BudgetDTO) int64 {
		if b.Progress == nil {
			return -1
		}
		return b.Progress.PercentBP
	}
	sort.SliceStable(active, func(i, j int) bool { return pct(active[i]) > pct(active[j]) })
	out.BudgetCount = len(active)
	out.Budgets = append(out.Budgets, active[:min(len(active), planningBudgets)]...)

	// Upcoming: overdue (oldest first), then due through the window.
	cal, err := p.Recurring.Calendar(ctx, finance.LocalDateString(today.AddDate(0, 0, -overdueLookback)), out.RenewalsThrough)
	if err != nil {
		return nil, err
	}
	byDate := func(l []recurring.CalendarItem) {
		sort.SliceStable(l, func(i, j int) bool { return l[i].Date < l[j].Date })
	}
	var overdue, due, renewals []recurring.CalendarItem
	for _, it := range cal {
		open := it.Status == "scheduled" || it.Status == "expected" || it.Status == "projected" || it.Status == "target"
		switch {
		case it.Status == "overdue":
			overdue = append(overdue, it)
		case it.Date >= out.Today && it.Date <= out.UpcomingThrough && open:
			due = append(due, it)
		}
		if it.Date >= out.Today && (it.Kind == "subscription_renewal" || it.Kind == "trial_end") && open {
			renewals = append(renewals, it)
		}
	}
	byDate(renewals)
	out.RenewalCount = len(renewals)
	out.Renewals = append(out.Renewals, renewals[:min(len(renewals), planningRenewals)]...)
	byDate(overdue)
	byDate(due)
	out.OverdueCount = len(overdue)
	out.UpcomingCount = len(overdue) + len(due)
	merged := append(overdue, due...)
	out.Upcoming = append(out.Upcoming, merged[:min(len(merged), planningUpcoming)]...)

	// Goals: nearest target date first.
	gl, err := p.Goals.List(ctx, "active")
	if err != nil {
		return nil, err
	}
	sort.SliceStable(gl, func(i, j int) bool {
		a, b := gl[i].TargetDate, gl[j].TargetDate
		switch {
		case a != nil && b != nil && *a != *b:
			return *a < *b
		case (a == nil) != (b == nil):
			return a != nil
		}
		return gl[i].Priority < gl[j].Priority
	})
	out.GoalCount = len(gl)
	out.Goals = append(out.Goals, gl[:min(len(gl), planningGoals)]...)

	// Group balances: open ones, largest first per currency.
	grs, err := p.Groups.List(ctx, false)
	if err != nil {
		return nil, err
	}
	open := []GroupBalance{}
	size := map[uuid.UUID]int64{}
	for _, g := range grs {
		if g.Status != "active" {
			continue
		}
		if size[g.ID] = minorOf(g.MyNet); size[g.ID] == 0 {
			continue
		}
		open = append(open, GroupBalance{GroupID: g.ID, Name: g.Name, GroupType: g.GroupType, MyNet: g.MyNet})
	}
	sort.SliceStable(open, func(i, j int) bool {
		if open[i].MyNet.Currency != open[j].MyNet.Currency {
			return open[i].MyNet.Currency < open[j].MyNet.Currency
		}
		return size[open[i].GroupID] > size[open[j].GroupID]
	})
	out.GroupCount = len(open)
	out.GroupBalances = append(out.GroupBalances, open[:min(len(open), planningGroups)]...)

	// Budget alerts: active ones, newest first.
	al, _, err := p.Budgets.ListAlerts(ctx, "active", nil, "", alertScan)
	if err != nil {
		return nil, err
	}
	out.AlertCount = len(al)
	out.Alerts = append(out.Alerts, al[:min(len(al), planningAlerts)]...)

	// Recurring commitments per month.
	rr, err := s.Recurring(ctx)
	if err != nil {
		return nil, err
	}
	out.Recurring = append(out.Recurring, rr.Commitments...)
	out.RecurringNoteCode = rr.NoteCode
	return out, nil
}

// minorOf parses a server-produced amount to minor units (exact).
func minorOf(m apitypes.Money) int64 {
	v, err := finance.ParseAmount("my_net", strings.TrimPrefix(m.Amount, "-"), m.Currency)
	if err != nil {
		return 0
	}
	return v
}

// PlanningCardRoutes registers GET /dashboard/planning.
func (s *Service) PlanningCardRoutes(api huma.API, p *PlanningCards) {
	httpx.Protected(api, httpx.Op("dashboard-planning", http.MethodGet, "/dashboard/planning",
		"Budgets, upcoming bills and renewals, goals and group balances for the dashboard", "Dashboard"),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[DashboardPlanning], error) {
			r, err := s.Planning(ctx, p)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}
