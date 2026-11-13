package analytics

import (
	"context"
	"net/http"
	"sort"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/budgets"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/finance"
	"montra/backend/internal/goals"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/subscriptions"
)

// Planning holds the planning services analytics summarizes.
type Planning struct {
	Budgets *budgets.Service
	Subs    *subscriptions.Service
	Goals   *goals.Service
}

// BudgetPerformance summarizes active budgets for the current period.
type BudgetPerformance struct {
	Budgets   []budgets.BudgetDTO `json:"budgets"`
	ByPace    map[string]int      `json:"by_pace" doc:"Counts per pace: under_pace, on_track, ahead_of_pace, over_budget"`
	OverCount int                 `json:"over_count"`
}

// RecurringCommitment is the normalized monthly cost of active rules.
type RecurringCommitment struct {
	Kind              string         `json:"kind" enum:"expense,income,transfer,bill,subscription,group_expense"`
	Currency          string         `json:"currency"`
	MonthlyEquivalent apitypes.Money `json:"monthly_equivalent" doc:"Fixed amounts normalized to a month (exact, rounded half away from zero)"`
	RuleCount         int            `json:"rule_count"`
	VariableCount     int            `json:"variable_count" doc:"Rules without a fixed amount (not included)"`
	Next30Days        apitypes.Money `json:"next_30_days" doc:"Open occurrences due in the next 30 days"`
}

// RecurringReport lists commitments per kind and currency.
type RecurringReport struct {
	Commitments []RecurringCommitment `json:"commitments"`
	Note        string                `json:"note" doc:"English; localize by note_code"`
	NoteCode    string                `json:"note_code" enum:"fixed_amounts_expectations" doc:"Stable code for note"`
}

// GoalTotal sums goals per currency.
type GoalTotal struct {
	Currency string         `json:"currency"`
	Target   apitypes.Money `json:"target"`
	Saved    apitypes.Money `json:"saved"`
	Count    int            `json:"count"`
	Achieved int            `json:"achieved"`
}

// GoalReport summarizes goal progress.
type GoalReport struct {
	Totals []GoalTotal     `json:"totals"`
	Goals  []goals.GoalDTO `json:"goals"`
}

// cyclesPerYear returns billing cycles per year as num/den for a rule.
func cyclesPerYear(freq string, interval int16, unit *string) (int64, int64) {
	switch freq {
	case "daily":
		return 365, 1
	case "weekly":
		return 52, 1
	case "biweekly":
		return 26, 1
	case "bimonthly":
		return 6, 1
	}
	return subscriptions.PeriodsPerYear(freq, interval, unit)
}

// Recurring returns normalized recurring commitments.
func (s *Service) Recurring(ctx context.Context) (*RecurringReport, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &RecurringReport{Commitments: []RecurringCommitment{},
		Note:     "Monthly equivalents use fixed rule amounts only; bills and income are expectations, not recorded money.",
		NoteCode: "fixed_amounts_expectations"}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		type key struct{ kind, cur string }
		agg := map[key]*RecurringCommitment{}
		get := func(k key) *RecurringCommitment {
			if c := agg[k]; c != nil {
				return c
			}
			c := &RecurringCommitment{Kind: k.kind, Currency: k.cur}
			agg[k] = c
			return c
		}
		monthly := map[key]int64{}
		rows, err := tx.Query(ctx, `select kind, coalesce(currency, ''), frequency, interval_count, interval_unit, amount_minor, amount_is_variable
			from recurring_rules where user_id = $1 and status = 'active' and group_id is null`, uid)
		if err != nil {
			return err
		}
		for rows.Next() {
			var kind, cur, freq string
			var interval int16
			var unit *string
			var amount *int64
			var variable bool
			if err := rows.Scan(&kind, &cur, &freq, &interval, &unit, &amount, &variable); err != nil {
				rows.Close()
				return err
			}
			if cur == "" {
				continue
			}
			k := key{kind, cur}
			c := get(k)
			c.RuleCount++
			if amount == nil || variable {
				c.VariableCount++
				continue
			}
			num, den := cyclesPerYear(freq, interval, unit)
			v, err := money.MulRatio(*amount, num, den*12)
			if err != nil {
				rows.Close()
				return err
			}
			if monthly[k], err = money.Add(monthly[k], v); err != nil {
				rows.Close()
				return err
			}
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		// Active subscriptions are commitments too (kind subscription); trials
		// start counting once they convert.
		srows, err := tx.Query(ctx, `select amount_minor, currency, billing_frequency, interval_count, interval_unit, start_date, next_renewal_date
			from subscriptions where user_id = $1 and status = 'active'`, uid)
		if err != nil {
			return err
		}
		type subRow struct {
			amount   int64
			cur      string
			freq     string
			interval int16
			unit     *string
			start    time.Time
			next     *time.Time
		}
		subs, err := pgx.CollectRows(srows, func(r pgx.CollectableRow) (subRow, error) {
			var x subRow
			err := r.Scan(&x.amount, &x.cur, &x.freq, &x.interval, &x.unit, &x.start, &x.next)
			return x, err
		})
		if err != nil {
			return err
		}
		subNext := map[key]int64{}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		// The next 30 days in the user's own calendar.
		now := time.Now().In(u.Loc)
		from := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
		to := from.AddDate(0, 0, 30)
		for _, x := range subs {
			k := key{"subscription", x.cur}
			c := get(k)
			c.RuleCount++
			num, den := subscriptions.PeriodsPerYear(x.freq, x.interval, x.unit)
			v, err := money.MulRatio(x.amount, num, den*12)
			if err != nil {
				return err
			}
			if monthly[k], err = money.Add(monthly[k], v); err != nil {
				return err
			}
			if x.next != nil {
				due := subscriptions.RenewalSchedule(x.freq, x.interval, x.unit, x.start, *x.next).Between(from, to, 100)
				for range due {
					if subNext[k], err = money.Add(subNext[k], x.amount); err != nil {
						return err
					}
				}
			}
		}
		next := map[key]int64{}
		for k, v := range subNext {
			next[k] = v
		}
		orows, err := tx.Query(ctx, `select r.kind, r.currency, coalesce(sum(coalesce(o.amount_minor, r.amount_minor)), 0)::bigint
			from recurring_occurrences o join recurring_rules r on r.id = o.rule_id
			where o.user_id = $1 and o.group_id is null and o.status in ('scheduled','overdue') and r.currency is not null
			and coalesce(o.postponed_to, o.occurrence_date) between $2::date and $3::date group by 1, 2`, uid, from, to)
		if err != nil {
			return err
		}
		for orows.Next() {
			var kind, cur string
			var sum int64
			if err := orows.Scan(&kind, &cur, &sum); err != nil {
				orows.Close()
				return err
			}
			get(key{kind, cur})
			if next[key{kind, cur}], err = money.Add(next[key{kind, cur}], sum); err != nil {
				orows.Close()
				return err
			}
		}
		orows.Close()
		if err := orows.Err(); err != nil {
			return err
		}
		for k, c := range agg {
			c.MonthlyEquivalent, c.Next30Days = apitypes.M(monthly[k], k.cur), apitypes.M(next[k], k.cur)
			out.Commitments = append(out.Commitments, *c)
		}
		sort.Slice(out.Commitments, func(i, j int) bool {
			if out.Commitments[i].Kind != out.Commitments[j].Kind {
				return out.Commitments[i].Kind < out.Commitments[j].Kind
			}
			return out.Commitments[i].Currency < out.Commitments[j].Currency
		})
		return orows.Err()
	})
	return out, database.MapError(err)
}

// Budgets summarizes budget performance.
func (s *Service) Budgets(ctx context.Context, p *Planning) (*BudgetPerformance, error) {
	list, err := p.Budgets.List(ctx, false)
	if err != nil {
		return nil, err
	}
	out := &BudgetPerformance{Budgets: list, ByPace: map[string]int{}}
	for _, b := range list {
		if b.Progress == nil {
			continue
		}
		out.ByPace[b.Progress.Pace]++
		if b.Progress.Pace == "over_budget" {
			out.OverCount++
		}
	}
	return out, nil
}

// GoalsSummary summarizes goal progress per currency.
func (s *Service) GoalsSummary(ctx context.Context, p *Planning) (*GoalReport, error) {
	list, err := p.Goals.List(ctx, "")
	if err != nil {
		return nil, err
	}
	out := &GoalReport{Totals: []GoalTotal{}, Goals: list}
	idx := map[string]int{}
	for _, g := range list {
		if g.Status == "cancelled" {
			continue
		}
		cur := g.Target.Currency
		i, ok := idx[cur]
		if !ok {
			i = len(out.Totals)
			idx[cur] = i
			out.Totals = append(out.Totals, GoalTotal{Currency: cur, Target: apitypes.M(0, cur), Saved: apitypes.M(0, cur)})
		}
		t := &out.Totals[i]
		tg, err := money.Add(t.Target.AmountMinor, g.Target.AmountMinor)
		if err != nil {
			return nil, err
		}
		sv, err := money.Add(t.Saved.AmountMinor, max(g.Progress.Saved.AmountMinor, 0))
		if err != nil {
			return nil, err
		}
		t.Target, t.Saved, t.Count = apitypes.M(tg, cur), apitypes.M(sv, cur), t.Count+1
		if g.Status == "achieved" {
			t.Achieved++
		}
	}
	return out, nil
}

// PlanningRoutes mounts the planning analytics views.
func (s *Service) PlanningRoutes(api huma.API, p *Planning) {
	const an = "Analytics"
	httpx.Protected(api, httpx.Op("analytics-budgets", http.MethodGet, "/analytics/budgets", "Budget performance for the current periods", an),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[BudgetPerformance], error) {
			r, err := s.Budgets(ctx, p)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("analytics-recurring", http.MethodGet, "/analytics/recurring", "Recurring commitments normalized per month", an),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[RecurringReport], error) {
			r, err := s.Recurring(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("analytics-subscriptions", http.MethodGet, "/analytics/subscriptions", "Subscription costs per currency", an),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[subscriptions.SubscriptionSummary], error) {
			r, err := p.Subs.Summary(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("analytics-goals", http.MethodGet, "/analytics/goals", "Goal progress per currency", an),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[GoalReport], error) {
			r, err := s.GoalsSummary(ctx, p)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}
