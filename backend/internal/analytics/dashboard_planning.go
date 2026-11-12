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
	// UpcomingDays is how far ahead the upcoming card looks.
	UpcomingDays = 14
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
		Budgets: []budgets.BudgetDTO{}, Upcoming: []recurring.CalendarItem{}, Goals: []goals.GoalDTO{}, GroupBalances: []GroupBalance{}}

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
	cal, err := p.Recurring.Calendar(ctx, finance.LocalDateString(today.AddDate(0, 0, -overdueLookback)), out.UpcomingThrough)
	if err != nil {
		return nil, err
	}
	var overdue, due []recurring.CalendarItem
	for _, it := range cal {
		switch {
		case it.Status == "overdue":
			overdue = append(overdue, it)
		case it.Date >= out.Today && (it.Status == "scheduled" || it.Status == "expected" || it.Status == "projected" || it.Status == "target"):
			due = append(due, it)
		}
	}
	byDate := func(l []recurring.CalendarItem) {
		sort.SliceStable(l, func(i, j int) bool { return l[i].Date < l[j].Date })
	}
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
