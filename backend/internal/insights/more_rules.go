package insights

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/finance"
)

// unusualFrequency flags a burst of purchases at one merchant: at least 4
// in the last 7 days and at least 3× the merchant's weekly average over the
// previous 12 weeks, with enough history to know the merchant. One insight
// per merchant per week.
func unusualFrequency(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	rows, err := tx.Query(ctx, `with recent as (
			select t.merchant_id, count(*) n, (array_agg(t.id order by t.local_date desc, t.created_at desc))[1:10] ids
			from transactions t where t.user_id = $1 and t.type = 'expense' and t.status in ('posted','pending') and t.deleted_at is null
			and t.merchant_id is not null and t.local_date between $2::date - 6 and $2::date
			group by t.merchant_id having count(*) >= 4),
		base as (
			select t.merchant_id, count(*) n from transactions t join recent r on r.merchant_id = t.merchant_id
			where t.user_id = $1 and t.type = 'expense' and t.status = 'posted' and t.deleted_at is null
			and t.local_date between $2::date - 90 and $2::date - 7
			group by t.merchant_id)
		select r.merchant_id, m.name, r.n::int, b.n::int, r.ids
		from recent r join merchants m on m.id = r.merchant_id join base b on b.merchant_id = r.merchant_id
		where b.n >= $3 and r.n::numeric >= 3 * (b.n::numeric / 12)`, uid, today, minFrequencyBase)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	year, week := today.ISOWeek()
	start := today.AddDate(0, 0, -6)
	var out []candidate
	for rows.Next() {
		var mid uuid.UUID
		var name string
		var recent, base int
		var ids []uuid.UUID
		if err := rows.Scan(&mid, &name, &recent, &base, &ids); err != nil {
			return nil, err
		}
		avg := float64(base) / 12
		conf := 0.6
		if base >= 12 {
			conf = 0.75
		}
		end := today
		out = append(out, candidate{kind: "anomaly", subtype: "unusual_frequency", severity: "notice", confidence: conf, scope: mid.String(),
			title: "More purchases than usual at " + name,
			body: fmt.Sprintf("You made %d purchases at %s in the last 7 days, compared with about %.1f a week over the previous 12 weeks. "+
				"This is unusual for you, not necessarily wrong; if it is expected, mark it so.", recent, name, avg),
			evidence: map[string]any{"merchant_id": mid, "recent_count": recent, "baseline_count": base, "baseline_weekly_average": fmt.Sprintf("%.1f", avg),
				"window_days": 7, "baseline_days": 84, "transaction_ids": ids, "rule": "≥ 4 purchases in 7 days and ≥ 3× the weekly average of the previous 12 weeks"},
			params: map[string]any{"merchant_id": mid, "merchant_name": name, "recent_count": recent, "baseline_weekly_average": fmt.Sprintf("%.1f", avg),
				"window_days": 7, "baseline_weeks": 12},
			fingerprint: fmt.Sprintf("unusual_frequency:%s:%d-%02d", mid, year, week), start: &start, end: &end})
	}
	return out, rows.Err()
}

// recurringAmountChange flags a recurring payment whose latest amount
// differs by at least 10% from the median of its previous payments (up to
// six). Variable-amount rules and subscriptions (which have their own
// price-change insight) are skipped.
func recurringAmountChange(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	rows, err := tx.Query(ctx, `with linked as (
			select t.recurring_rule_id rid, t.id, t.amount_minor, t.currency, t.local_date,
				row_number() over (partition by t.recurring_rule_id order by t.local_date desc, t.created_at desc) rn
			from transactions t join recurring_rules r on r.id = t.recurring_rule_id
			where t.user_id = $1 and r.user_id = $1 and r.group_id is null and r.status = 'active' and not r.amount_is_variable
			and r.kind in ('expense','income','bill') and t.deleted_at is null and t.status = 'posted' and t.type in ('expense','income')
			and t.local_date >= $2::date - 400)
		select l.rid, r.name, l.id, l.amount_minor, l.currency, l.local_date,
			(select percentile_cont(0.5) within group (order by p.amount_minor) from linked p where p.rid = l.rid and p.rn between 2 and 7
				and p.currency = l.currency)::bigint,
			(select count(*) from linked p where p.rid = l.rid and p.rn between 2 and 7 and p.currency = l.currency)::int
		from linked l join recurring_rules r on r.id = l.rid
		where l.rn = 1 and l.local_date >= $2::date - 35`, uid, today)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []candidate
	for rows.Next() {
		var rid, txID uuid.UUID
		var name, cur string
		var amt int64
		var med *int64
		var n int
		var d time.Time
		if err := rows.Scan(&rid, &name, &txID, &amt, &cur, &d, &med, &n); err != nil {
			return nil, err
		}
		if med == nil || *med <= 0 || n < minRecurringBase {
			continue
		}
		diff := amt - *med
		if diff < 0 {
			diff = -diff
		}
		if diff*10 < *med {
			continue
		}
		pct := float64(amt-*med) * 100 / float64(*med)
		direction := "higher"
		if amt < *med {
			direction = "lower"
		}
		conf := 0.7
		if n >= 4 {
			conf = 0.8
		}
		out = append(out, candidate{kind: "anomaly", subtype: "recurring_amount_change", severity: "notice", confidence: conf, scope: rid.String(),
			code:  "recurring_amount_change_" + direction,
			title: fmt.Sprintf("%s was %s than usual", name, direction),
			body: fmt.Sprintf("The latest %s payment (%s on %s) differs from the usual %s (median of the previous %d payments), a change of %+.0f%%. "+
				"If the amount changed for good, update the recurring rule so your plans stay accurate.", name, fmtMoney(amt, cur), finance.LocalDateString(d),
				fmtMoney(*med, cur), n, pct),
			evidence: map[string]any{"recurring_rule_id": rid, "transaction_id": txID, "amount": fmtMoney(amt, cur), "usual_amount": fmtMoney(*med, cur),
				"change_percent": fmt.Sprintf("%+.1f", pct), "history_count": n, "rule": "latest payment differs by ≥ 10% from the median of up to 6 earlier payments"},
			params: map[string]any{"recurring_rule_id": rid, "name": name, "transaction_id": txID, "amount": moneyOf(amt, cur), "usual_amount": moneyOf(*med, cur),
				"local_date": finance.LocalDateString(d), "change_percent": fmt.Sprintf("%+.1f", pct), "history_count": n},
			fingerprint: "recurring_amount_change:" + txID.String(), start: &d, end: &d})
	}
	return out, rows.Err()
}

// repeatedOverspend suggests acting on a budget exceeded in at least two of
// its last three closed periods, showing the numbers, assumptions and
// trade-offs. It never promises savings.
func (s *Service) repeatedOverspend(ctx context.Context, tx pgx.Tx, uid uuid.UUID, _ time.Time) ([]candidate, error) {
	if s.Budgets == nil {
		return nil, nil
	}
	outcomes, err := s.Budgets.RecentOutcomes(ctx, tx, uid, 3)
	if err != nil {
		return nil, err
	}
	type agg struct {
		name, cur        string
		periods, over    int
		spent, overTotal int64
		limit            int64
		latest           time.Time
		history          []map[string]any
		first            time.Time
	}
	byBudget := map[uuid.UUID]*agg{}
	var order []uuid.UUID
	for _, o := range outcomes {
		a := byBudget[o.BudgetID]
		if a == nil {
			a = &agg{name: o.Name, cur: o.Currency, limit: o.Limit, latest: o.End}
			byBudget[o.BudgetID] = a
			order = append(order, o.BudgetID)
		}
		a.periods++
		a.spent += o.Spent
		a.first = o.Start
		if o.Limit > 0 && o.Spent > o.Limit {
			a.over++
			a.overTotal += o.Spent - o.Limit
		}
		a.history = append(a.history, map[string]any{"period_start": finance.LocalDateString(o.Start), "period_end": finance.LocalDateString(o.End),
			"limit": fmtMoney(o.Limit, o.Currency), "spent": fmtMoney(o.Spent, o.Currency)})
	}
	var out []candidate
	for _, id := range order {
		a := byBudget[id]
		if a.over < 2 || a.periods < 2 {
			continue
		}
		avgSpent := a.spent / int64(a.periods)
		avgOver := a.overTotal / int64(a.over)
		conf := 0.7
		if a.over == a.periods && a.periods >= 3 {
			conf = 0.85
		}
		start, end := a.first, a.latest
		out = append(out, candidate{kind: "savings", subtype: "repeated_budget_overspend", severity: "info", confidence: conf, scope: id.String(),
			title: fmt.Sprintf("%s budget exceeded in %d of the last %d periods", a.name, a.over, a.periods),
			body: fmt.Sprintf("Across the last %d periods you spent %s on average against a limit of %s, going over by %s on average when it was exceeded. "+
				"Two options: raise the limit to about %s so the budget matches how you actually spend (fewer alerts, but no push to cut back), "+
				"or keep the limit and review what drives the spending (needs changes, and results are not guaranteed). Based on past periods only.",
				a.periods, fmtMoney(avgSpent, a.cur), fmtMoney(a.limit, a.cur), fmtMoney(avgOver, a.cur), fmtMoney(avgSpent, a.cur)),
			evidence: map[string]any{"budget_id": id, "periods": a.history, "over_count": a.over, "average_spent": fmtMoney(avgSpent, a.cur),
				"average_overspend": fmtMoney(avgOver, a.cur), "assumption": "Past periods only; future spending may differ.",
				"rule": "spent above the limit in at least 2 of the last 3 closed periods"},
			params: map[string]any{"budget_id": id, "budget_name": a.name, "periods": a.periods, "over_count": a.over, "average_spent": moneyOf(avgSpent, a.cur),
				"limit": moneyOf(a.limit, a.cur), "average_overspend": moneyOf(avgOver, a.cur)},
			fingerprint: fmt.Sprintf("repeated_budget_overspend:%s:%s", id, finance.LocalDateString(a.latest)), start: &start, end: &end})
	}
	return out, nil
}
