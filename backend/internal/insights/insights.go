// Package insights detects unusual activity and savings opportunities with
// explainable, deterministic rules over the user's own history (spec
// §4.13, §20B.14). Every insight shows its evidence and baseline, is
// labelled "unusual" (never fraud), needs a minimum amount of history, can
// be dismissed, snoozed, marked expected or muted, and is never acted on
// automatically.
package insights

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/budgets"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
)

// Service implements insights.
type Service struct {
	DB *database.DB
	// Budgets provides closed-period outcomes for the repeated-overspend
	// suggestion (optional).
	Budgets *budgets.Service
	Now     func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Minimum history before a rule may fire (false-positive control).
const (
	minCategoryHistory = 8  // prior transactions in the category (180 days)
	minOverallHistory  = 10 // prior expenses overall for "new merchant"
	minMonthsHistory   = 3  // months with spending for category spikes
	minFrequencyBase   = 6  // prior purchases at the merchant in the 12-week baseline
	minRecurringBase   = 2  // earlier payments of a recurring rule
)

// candidate is an insight a rule wants to record.
type candidate struct {
	kind, subtype, title, body, severity string
	confidence                           float64
	evidence                             map[string]any
	scope                                string // mute scope key
	fingerprint                          string
	start, end                           *time.Time
	// code and params localize title and body (message_code,
	// message_params); amounts in params are Money objects.
	code   string
	params map[string]any
}

// ruleCodes are the stable codes of each subtype's evidence.rule text.
var ruleCodes = map[string]string{
	"unusual_amount":              "amount_3x_median_above_p95",
	"category_spike":              "month_to_date_above_3_month_average",
	"new_merchant_large":          "first_at_merchant_2x_median_expense",
	"possible_duplicate":          "same_account_amount_within_2_days",
	"subscription_price_increase": "recorded_price_change",
	"missing_recurring_payment":   "overdue_recurring_occurrence",
	"cash_flow_change":            "spending_up_25_or_income_down_20_vs_3_months",
	"subscription_costs":          "active_subscriptions_normalized_monthly",
	"unusual_frequency":           "4_in_7_days_and_3x_weekly_average",
	"recurring_amount_change":     "latest_differs_10_from_median_of_6",
	"repeated_budget_overspend":   "over_limit_2_of_last_3_periods",
}

// RuleCodes lists every subtype with its rule code (docs and tests).
func RuleCodes() map[string]string {
	out := make(map[string]string, len(ruleCodes))
	for k, v := range ruleCodes {
		out[k] = v
	}
	return out
}

func fmtMoney(minor int64, cur string) string { return money.Format(minor, cur) + " " + cur }

func moneyOf(minor int64, cur string) apitypes.Money { return apitypes.M(minor, cur) }

func clip(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n-1]) + "…"
	}
	return s
}

// Generate runs every rule for one user and records new insights. It works
// in the caller's transaction (the API as the user, or the worker), and
// returns how many were new.
func (s *Service) Generate(ctx context.Context, tx pgx.Tx, uid uuid.UUID) (int, error) {
	u, err := finance.LoadUser(ctx, tx, uid)
	if err != nil {
		return 0, err
	}
	n := s.now().In(u.Loc)
	today := time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, time.UTC)
	var all []candidate
	for _, rule := range []func(context.Context, pgx.Tx, uuid.UUID, time.Time) ([]candidate, error){
		unusualAmounts, categorySpikes, newMerchants, duplicates, priceIncreases, missingRecurring, cashFlowChange, subscriptionCosts,
		unusualFrequency, recurringAmountChange, s.repeatedOverspend,
	} {
		c, err := rule(ctx, tx, uid, today)
		if err != nil {
			return 0, err
		}
		all = append(all, c...)
	}
	created := 0
	for _, c := range all {
		var muted bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from insight_mutes where user_id = $1 and subtype = $2 and scope_key in ('*', $3))`,
			uid, c.subtype, c.scope).Scan(&muted); err != nil {
			return created, err
		}
		if muted {
			continue
		}
		c.evidence["scope"] = c.scope
		ev, err := json.Marshal(c.evidence)
		if err != nil {
			return created, err
		}
		code := c.code
		if code == "" {
			code = c.subtype
		}
		if c.params == nil {
			c.params = map[string]any{}
		}
		params, err := json.Marshal(c.params)
		if err != nil {
			return created, err
		}
		tag, err := tx.Exec(ctx, `insert into insights (user_id, kind, subtype, title, body, severity, confidence, evidence, period_start, period_end, source,
			fingerprint, message_code, message_params, rule_code)
			values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'rules',$11,$12,$13,$14) on conflict (user_id, fingerprint) do nothing`,
			uid, c.kind, c.subtype, clip(c.title, 160), clip(c.body, 2000), c.severity, c.confidence, ev, c.start, c.end, c.fingerprint,
			code, params, ruleCodes[c.subtype])
		if err != nil {
			return created, err
		}
		created += int(tag.RowsAffected())
	}
	return created, nil
}

const expenseExpr = `case when t.type = 'expense' then t.amount_minor when t.type = 'group_expense' then coalesce(t.personal_share_minor, t.amount_minor)
	when t.type in ('refund','reimbursement') then -t.amount_minor else 0 end`

// unusualAmounts flags recent expenses far above the category's usual size.
func unusualAmounts(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	rows, err := tx.Query(ctx, `with recent as (
			select t.id, t.amount_minor, t.currency, t.category_id, t.local_date, coalesce(m.name, nullif(t.description, ''), 'A transaction') label, c.name cat
			from transactions t left join merchants m on m.id = t.merchant_id join categories c on c.id = t.category_id
			where t.user_id = $1 and t.type = 'expense' and t.status = 'posted' and t.deleted_at is null and t.local_date between $2::date - 6 and $2::date),
		base as (
			select r.id, percentile_cont(0.5) within group (order by h.amount_minor) med, percentile_cont(0.95) within group (order by h.amount_minor) p95, count(*) n
			from recent r join transactions h on h.user_id = $1 and h.category_id = r.category_id and h.currency = r.currency and h.type = 'expense'
				and h.status = 'posted' and h.deleted_at is null and h.local_date between r.local_date - 187 and r.local_date - 1 and h.id <> r.id
			group by r.id)
		select r.id, r.amount_minor, r.currency, r.category_id, r.local_date, r.label, r.cat, b.med::bigint, b.p95::bigint, b.n::int
		from recent r join base b on b.id = r.id
		where b.n >= $3 and r.amount_minor >= 3 * b.med and r.amount_minor > b.p95`, uid, today, minCategoryHistory)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []candidate
	for rows.Next() {
		var id, cat uuid.UUID
		var amt, med, p95 int64
		var cur, label, catName string
		var d time.Time
		var n int
		if err := rows.Scan(&id, &amt, &cur, &cat, &d, &label, &catName, &med, &p95, &n); err != nil {
			return nil, err
		}
		ratio := float64(amt) / float64(max(med, 1))
		conf := 0.6
		if n >= 20 {
			conf = 0.8
		}
		out = append(out, candidate{kind: "anomaly", subtype: "unusual_amount", severity: "notice", confidence: conf, scope: cat.String(),
			title: "Unusually large " + catName + " expense",
			body: fmt.Sprintf("%s for %s on %s is about %.1f× your usual %s transaction (median %s over %d transactions in the previous 6 months). "+
				"If it is expected, mark it so.", fmtMoney(amt, cur), label, finance.LocalDateString(d), ratio, catName, fmtMoney(med, cur), n),
			evidence: map[string]any{"transaction_id": id, "amount": fmtMoney(amt, cur), "baseline_median": fmtMoney(med, cur),
				"baseline_p95": fmtMoney(p95, cur), "history_count": n, "window_days": 180, "rule": "amount ≥ 3× median and above the 95th percentile"},
			params: map[string]any{"transaction_id": id, "label": label, "category_id": cat, "category_name": catName, "local_date": finance.LocalDateString(d),
				"amount": moneyOf(amt, cur), "baseline_median": moneyOf(med, cur), "ratio": fmt.Sprintf("%.1f", ratio), "history_count": n, "window_months": 6},
			fingerprint: "unusual_amount:" + id.String(), start: &d, end: &d})
	}
	return out, rows.Err()
}

// categorySpikes flags categories whose spending this month already
// exceeds a typical whole month (average of the previous 3 months).
func categorySpikes(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	start := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
	rows, err := tx.Query(ctx, `with monthly as (
			select t.category_id, t.currency, date_trunc('month', t.local_date)::date m, sum(`+expenseExpr+`) s
			from transactions t where t.user_id = $1 and t.status = 'posted' and t.deleted_at is null and t.category_id is not null
			and t.local_date between ($2::date - interval '3 months')::date and $3::date group by 1, 2, 3),
		hist as (select category_id, currency, sum(s) / 3 avg_m, count(*) filter (where s > 0) months from monthly where m < $2::date group by 1, 2),
		cur as (select category_id, currency, s from monthly where m = $2::date)
		select c.category_id, c.currency, c.s::bigint, h.avg_m::bigint, cat.name from cur c join hist h using (category_id, currency)
		join categories cat on cat.id = c.category_id
		where h.months >= $4 and h.avg_m > 0 and c.s > h.avg_m and c.s - h.avg_m >= 100`, uid, start, today, minMonthsHistory)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []candidate
	month := start.Format("2006-01")
	for rows.Next() {
		var cat uuid.UUID
		var cur, name string
		var sofar, avg int64
		if err := rows.Scan(&cat, &cur, &sofar, &avg, &name); err != nil {
			return nil, err
		}
		end := today
		out = append(out, candidate{kind: "anomaly", subtype: "category_spike", severity: "notice", confidence: 0.7, scope: cat.String(),
			title: name + " spending is above your usual month",
			body: fmt.Sprintf("You have spent %s on %s so far this month, more than your usual %s a month (average of the previous 3 months).",
				fmtMoney(sofar, cur), name, fmtMoney(avg, cur)),
			evidence: map[string]any{"so_far": fmtMoney(sofar, cur), "monthly_average": fmtMoney(avg, cur), "months_compared": 3,
				"rule": "this month so far > average of the previous 3 months"},
			params: map[string]any{"category_id": cat, "category_name": name, "month": month, "so_far": moneyOf(sofar, cur),
				"monthly_average": moneyOf(avg, cur), "months_compared": 3},
			fingerprint: "category_spike:" + cat.String() + ":" + month, start: &start, end: &end})
	}
	return out, rows.Err()
}

// newMerchants flags a first purchase at a merchant that is much larger
// than the user's typical expense.
func newMerchants(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	rows, err := tx.Query(ctx, `with base as (
			select currency, percentile_cont(0.5) within group (order by amount_minor) med, count(*) n from transactions
			where user_id = $1 and type = 'expense' and status = 'posted' and deleted_at is null and local_date between $2::date - 187 and $2::date - 7
			group by currency)
		select t.id, t.amount_minor, t.currency, t.local_date, m.name, b.med::bigint, b.n::int from transactions t join merchants m on m.id = t.merchant_id
		join base b on b.currency = t.currency
		where t.user_id = $1 and t.type = 'expense' and t.status = 'posted' and t.deleted_at is null and t.local_date between $2::date - 6 and $2::date
		and b.n >= $3 and t.amount_minor >= 2 * b.med
		and not exists (select 1 from transactions o where o.user_id = $1 and o.merchant_id = t.merchant_id and o.deleted_at is null and o.id <> t.id
			and (o.local_date < t.local_date or (o.local_date = t.local_date and o.created_at < t.created_at)))`, uid, today, minOverallHistory)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []candidate
	for rows.Next() {
		var id uuid.UUID
		var amt, med int64
		var cur, name string
		var d time.Time
		var n int
		if err := rows.Scan(&id, &amt, &cur, &d, &name, &med, &n); err != nil {
			return nil, err
		}
		out = append(out, candidate{kind: "anomaly", subtype: "new_merchant_large", severity: "notice", confidence: 0.6, scope: "*",
			title: "First purchase at " + name,
			body: fmt.Sprintf("%s at %s on %s is your first transaction there and larger than your typical expense (median %s). "+
				"If you recognise it, mark it expected.", fmtMoney(amt, cur), name, finance.LocalDateString(d), fmtMoney(med, cur)),
			evidence: map[string]any{"transaction_id": id, "amount": fmtMoney(amt, cur), "typical_expense": fmtMoney(med, cur), "history_count": n,
				"rule": "first transaction at the merchant and ≥ 2× your median expense"},
			params: map[string]any{"transaction_id": id, "merchant_name": name, "local_date": finance.LocalDateString(d), "amount": moneyOf(amt, cur),
				"typical_expense": moneyOf(med, cur), "history_count": n},
			fingerprint: "new_merchant:" + id.String(), start: &d, end: &d})
	}
	return out, rows.Err()
}

// duplicates flags recent pairs that look like the same purchase recorded
// twice (same account and amount within 2 days, same merchant or text).
func duplicates(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	rows, err := tx.Query(ctx, `select a.id, b.id, a.amount_minor, a.currency, a.local_date, b.local_date, a.account_id,
			coalesce(m.name, nullif(a.description, ''), 'a transaction')
		from transactions a join transactions b on b.user_id = a.user_id and b.account_id = a.account_id and b.amount_minor = a.amount_minor
			and b.type = a.type and b.id > a.id and abs(b.local_date - a.local_date) <= 2 and b.deleted_at is null
			and (b.merchant_id = a.merchant_id or lower(coalesce(b.description, '')) = lower(coalesce(a.description, '')))
		left join merchants m on m.id = a.merchant_id
		where a.user_id = $1 and a.type = 'expense' and a.deleted_at is null and a.local_date between $2::date - 13 and $2::date
		and a.transfer_id is null and b.transfer_id is null limit 20`, uid, today)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []candidate
	for rows.Next() {
		var a, b, acct uuid.UUID
		var amt int64
		var cur, label string
		var da, db time.Time
		if err := rows.Scan(&a, &b, &amt, &cur, &da, &db, &acct, &label); err != nil {
			return nil, err
		}
		out = append(out, candidate{kind: "anomaly", subtype: "possible_duplicate", severity: "notice", confidence: 0.7, scope: acct.String(),
			title: "Possible duplicate: " + label,
			body: fmt.Sprintf("Two transactions of %s for %s on %s and %s in the same account look alike. If one was recorded twice, void it; "+
				"Montra never deletes it for you.", fmtMoney(amt, cur), label, finance.LocalDateString(da), finance.LocalDateString(db)),
			evidence: map[string]any{"transaction_ids": []uuid.UUID{a, b}, "amount": fmtMoney(amt, cur), "rule": "same account and amount within 2 days, same merchant or description"},
			params: map[string]any{"label": label, "amount": moneyOf(amt, cur), "first_date": finance.LocalDateString(da), "second_date": finance.LocalDateString(db),
				"transaction_ids": []uuid.UUID{a, b}, "account_id": acct},
			fingerprint: "duplicate:" + a.String() + ":" + b.String(), start: &da, end: &db})
	}
	return out, rows.Err()
}

// priceIncreases reports subscription price rises (recorded price changes).
func priceIncreases(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	rows, err := tx.Query(ctx, `select e.id, s.id, s.name, s.currency, e.old_amount_minor, e.new_amount_minor, e.occurred_on, s.billing_frequency
		from subscription_events e join subscriptions s on s.id = e.subscription_id
		where e.user_id = $1 and e.kind = 'price_changed' and e.new_amount_minor > e.old_amount_minor and e.old_amount_minor > 0
		and e.occurred_on > $2::date - 60`, uid, today)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []candidate
	for rows.Next() {
		var ev, sub uuid.UUID
		var name, cur, freq string
		var old, nw int64
		var d time.Time
		if err := rows.Scan(&ev, &sub, &name, &cur, &old, &nw, &d, &freq); err != nil {
			return nil, err
		}
		pct := money.PercentBasisPoints(nw-old, old)
		out = append(out, candidate{kind: "subscription", subtype: "subscription_price_increase", severity: "notice", confidence: 1, scope: sub.String(),
			title: name + " costs more",
			body: fmt.Sprintf("%s went from %s to %s per %s billing (%s%% more) on %s.", name, fmtMoney(old, cur), fmtMoney(nw, cur), freq,
				money.FormatExp(pct, 2), finance.LocalDateString(d)),
			evidence: map[string]any{"subscription_id": sub, "old": fmtMoney(old, cur), "new": fmtMoney(nw, cur), "rule": "recorded price change"},
			params: map[string]any{"subscription_id": sub, "name": name, "old": moneyOf(old, cur), "new": moneyOf(nw, cur), "billing_frequency": freq,
				"percent": money.FormatExp(pct, 2), "percent_bp": pct, "local_date": finance.LocalDateString(d)},
			fingerprint: "sub_price:" + ev.String(), start: &d, end: &d})
	}
	return out, rows.Err()
}

// missingRecurring reports expected payments that were not recorded.
func missingRecurring(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	rows, err := tx.Query(ctx, `select o.id, r.id, r.name, coalesce(o.postponed_to, o.occurrence_date), coalesce(o.amount_minor, r.amount_minor), r.currency
		from recurring_occurrences o join recurring_rules r on r.id = o.rule_id
		where o.user_id = $1 and o.group_id is null and o.status = 'overdue' and r.kind in ('expense','bill','subscription')
		and coalesce(o.postponed_to, o.occurrence_date) > $2::date - 30`, uid, today)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []candidate
	for rows.Next() {
		var occ, rule uuid.UUID
		var name string
		var d time.Time
		var amt *int64
		var cur *string
		if err := rows.Scan(&occ, &rule, &name, &d, &amt, &cur); err != nil {
			return nil, err
		}
		amount := ""
		params := map[string]any{"name": name, "due": finance.LocalDateString(d), "occurrence_id": occ, "recurring_rule_id": rule}
		if amt != nil && cur != nil {
			amount = " (" + fmtMoney(*amt, *cur) + ")"
			params["amount"] = moneyOf(*amt, *cur)
		}
		out = append(out, candidate{kind: "recurring", subtype: "missing_recurring_payment", severity: "notice", confidence: 0.8, scope: rule.String(),
			title: name + " was not recorded",
			body: fmt.Sprintf("%s%s was due on %s, but no payment is linked yet. Record or link it, or skip this occurrence.", name, amount,
				finance.LocalDateString(d)),
			evidence:    map[string]any{"occurrence_id": occ, "recurring_rule_id": rule, "due": finance.LocalDateString(d), "rule": "overdue recurring occurrence"},
			params:      params,
			fingerprint: "missing:" + occ.String(), start: &d, end: &d})
	}
	return out, rows.Err()
}

// cashFlowChange compares last month with the 3 months before it, early in
// the month, when spending rose by a quarter or income fell by a fifth.
func cashFlowChange(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	if today.Day() > 10 {
		return nil, nil
	}
	last := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC).AddDate(0, -1, 0)
	rows, err := tx.Query(ctx, `with m as (
			select t.currency, date_trunc('month', t.local_date)::date m, sum(`+expenseExpr+`) spend,
				sum(case when t.type = 'income' then t.amount_minor else 0 end) income
			from transactions t where t.user_id = $1 and t.status = 'posted' and t.deleted_at is null
			and t.local_date >= ($2::date - interval '3 months')::date and t.local_date < ($2::date + interval '1 month')::date group by 1, 2)
		select l.currency, l.spend::bigint, l.income::bigint, (avg(h.spend))::bigint, (avg(h.income))::bigint, count(h.*)
		from m l join m h on h.currency = l.currency and h.m < l.m where l.m = $2::date group by l.currency, l.spend, l.income`, uid, last)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []candidate
	for rows.Next() {
		var cur string
		var spend, income, avgSpend, avgIncome int64
		var months int
		if err := rows.Scan(&cur, &spend, &income, &avgSpend, &avgIncome, &months); err != nil {
			return nil, err
		}
		if months < minMonthsHistory {
			continue
		}
		end := last.AddDate(0, 1, -1)
		var parts []string
		code := "cash_flow_change"
		if avgSpend > 0 && spend*4 >= avgSpend*5 {
			parts = append(parts, fmt.Sprintf("spending was %s against your usual %s", fmtMoney(spend, cur), fmtMoney(avgSpend, cur)))
			code += "_spending"
		}
		if avgIncome > 0 && income*5 <= avgIncome*4 {
			parts = append(parts, fmt.Sprintf("income was %s against your usual %s", fmtMoney(income, cur), fmtMoney(avgIncome, cur)))
			code += "_income"
		}
		if len(parts) == 0 {
			continue
		}
		if len(parts) == 2 {
			code = "cash_flow_change_both"
		}
		out = append(out, candidate{kind: "summary", subtype: "cash_flow_change", severity: "info", confidence: 0.8, scope: "*", code: code,
			title: "Last month's cash flow changed",
			body:  "In " + last.Format("January 2006") + ", " + strings.Join(parts, "; ") + " (average of the 3 months before).",
			evidence: map[string]any{"spending": fmtMoney(spend, cur), "usual_spending": fmtMoney(avgSpend, cur), "income": fmtMoney(income, cur),
				"usual_income": fmtMoney(avgIncome, cur), "rule": "spending +25% or income -20% vs the previous 3-month average"},
			params: map[string]any{"month": last.Format("2006-01"), "spending": moneyOf(spend, cur), "usual_spending": moneyOf(avgSpend, cur),
				"income": moneyOf(income, cur), "usual_income": moneyOf(avgIncome, cur), "months_compared": 3},
			fingerprint: "cashflow:" + cur + ":" + last.Format("2006-01"), start: &last, end: &end})
	}
	return out, rows.Err()
}

// subscriptionCosts makes recurring subscription costs visible (savings).
func subscriptionCosts(ctx context.Context, tx pgx.Tx, uid uuid.UUID, today time.Time) ([]candidate, error) {
	rows, err := tx.Query(ctx, `select currency, amount_minor, billing_frequency, interval_count, coalesce(interval_unit, ''), name from subscriptions
		where user_id = $1 and status in ('active','trial','cancellation_pending') order by currency`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	type agg struct {
		monthly int64
		names   []string
	}
	per := map[string]*agg{}
	for rows.Next() {
		var cur, freq, unit, name string
		var amt int64
		var n int16
		if err := rows.Scan(&cur, &amt, &freq, &n, &unit, &name); err != nil {
			return nil, err
		}
		num, den := monthlyFactor(freq, int64(max(n, 1)), unit)
		m, err := money.MulRatio(amt, num, den)
		if err != nil {
			continue
		}
		if per[cur] == nil {
			per[cur] = &agg{}
		}
		per[cur].monthly += m
		per[cur].names = append(per[cur].names, name)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	var out []candidate
	month := today.Format("2006-01")
	for cur, a := range per {
		if len(a.names) < 3 {
			continue
		}
		out = append(out, candidate{kind: "savings", subtype: "subscription_costs", severity: "info", confidence: 1, scope: "*",
			title: fmt.Sprintf("%d subscriptions cost about %s a month", len(a.names), fmtMoney(a.monthly, cur)),
			body: fmt.Sprintf("That is about %s a year. Cancelling one you no longer use stops its future renewals only; "+
				"Montra does not cancel anything for you.", fmtMoney(a.monthly*12, cur)),
			evidence: map[string]any{"monthly": fmtMoney(a.monthly, cur), "yearly": fmtMoney(a.monthly*12, cur), "count": len(a.names),
				"assumptions": "Each price normalized to a month from its billing frequency; trials counted at their post-trial price."},
			params:      map[string]any{"count": len(a.names), "monthly": moneyOf(a.monthly, cur), "yearly": moneyOf(a.monthly*12, cur)},
			fingerprint: "savings_subscriptions:" + cur + ":" + month})
	}
	return out, nil
}

func monthlyFactor(freq string, n int64, unit string) (int64, int64) {
	switch freq {
	case "weekly":
		return 52, 12
	case "monthly":
		return 1, 1
	case "quarterly":
		return 1, 3
	case "semiannual":
		return 1, 6
	case "yearly":
		return 1, 12
	}
	switch unit {
	case "day":
		return 365, 12 * n
	case "week":
		return 52, 12 * n
	case "month":
		return 1, n
	case "year":
		return 1, 12 * n
	}
	return 1, 1
}

// FeedbackDTO is the caller's own feedback on an insight (one per insight;
// repeating it updates the earlier answer).
type FeedbackDTO struct {
	Feedback  string    `json:"feedback" enum:"helpful,not_helpful,incorrect,expected"`
	Note      *string   `json:"note,omitempty"`
	UpdatedAt time.Time `json:"updated_at"`
}

// InsightDTO is an insight with its evidence.
type InsightDTO struct {
	ID            uuid.UUID      `json:"id"`
	Kind          string         `json:"kind" enum:"anomaly,savings,summary,forecast,budget,subscription,recurring"`
	Subtype       string         `json:"subtype"`
	Title         string         `json:"title" doc:"English; localize with message_code and message_params"`
	Body          string         `json:"body" doc:"English; localize with message_code and message_params"`
	MessageCode   *string        `json:"message_code,omitempty" doc:"Stable code for title and body (the subtype, or a variant such as cash_flow_change_income); absent for insights recorded before codes existed, whose text is English only"`
	MessageParams map[string]any `json:"message_params,omitempty" doc:"Values message_code refers to: amounts as Money objects ({amount_minor, amount, currency}), counts and percent_bp as numbers, names, dates (YYYY-MM-DD), months (YYYY-MM) and IDs as strings"`
	RuleCode      string         `json:"rule_code" doc:"Stable code for the rule that fired (evidence.rule); see docs/API.md"`
	Severity      string         `json:"severity" enum:"info,notice,warning"`
	Confidence    *float64       `json:"confidence,omitempty"`
	Evidence      map[string]any `json:"evidence" doc:"Baseline and references. evidence.amounts holds every amount as a Money object under its evidence key (and each entry of a list such as periods carries its own amounts); the top-level \"1100.00 INR\" strings are deprecated and kept for compatibility. evidence.rule is English (see rule_code)"`
	PeriodStart   *string        `json:"period_start,omitempty"`
	PeriodEnd     *string        `json:"period_end,omitempty"`
	Source        string         `json:"source" enum:"rules,ai"`
	Status        string         `json:"status" enum:"active,dismissed,snoozed,expected,resolved,muted"`
	SnoozedUntil  *time.Time     `json:"snoozed_until,omitempty"`
	MyFeedback    *FeedbackDTO   `json:"my_feedback,omitempty" doc:"Your feedback on this insight, if any"`
	CreatedAt     time.Time      `json:"created_at"`
}

// insightCols reads an insight (alias i) with the caller's feedback (alias
// f, from insightFrom).
const insightCols = `i.id, i.kind, i.subtype, i.title, i.body, i.severity, i.confidence::float8, i.evidence, i.period_start, i.period_end, i.source,
	case when i.status = 'snoozed' and i.snoozed_until <= now() then 'active' else i.status end, i.snoozed_until, i.created_at,
	i.message_code, i.message_params, i.rule_code, f.feedback, f.note, coalesce(f.updated_at, f.created_at)`

// insightFrom joins insights with the caller's own feedback (RLS limits
// insight_feedback to the caller's rows).
const insightFrom = `insights i left join insight_feedback f on f.insight_id = i.id and f.user_id = i.user_id`

func scanInsight(r pgx.CollectableRow) (InsightDTO, error) {
	var x InsightDTO
	var ev, params []byte
	var ps, pe *time.Time
	var ruleCode, feedback, note *string
	var feedbackAt *time.Time
	if err := r.Scan(&x.ID, &x.Kind, &x.Subtype, &x.Title, &x.Body, &x.Severity, &x.Confidence, &ev, &ps, &pe, &x.Source, &x.Status, &x.SnoozedUntil,
		&x.CreatedAt, &x.MessageCode, &params, &ruleCode, &feedback, &note, &feedbackAt); err != nil {
		return x, err
	}
	_ = json.Unmarshal(ev, &x.Evidence)
	if x.Evidence == nil {
		x.Evidence = map[string]any{}
	}
	enrichEvidence(x.Evidence)
	if x.MessageCode != nil {
		_ = json.Unmarshal(params, &x.MessageParams)
		if x.MessageParams == nil {
			x.MessageParams = map[string]any{}
		}
	}
	if ruleCode != nil {
		x.RuleCode = *ruleCode
	} else {
		x.RuleCode = ruleCodes[x.Subtype] // recorded before the column existed
	}
	if ps != nil {
		v := finance.LocalDateString(*ps)
		x.PeriodStart = &v
	}
	if pe != nil {
		v := finance.LocalDateString(*pe)
		x.PeriodEnd = &v
	}
	if feedback != nil && feedbackAt != nil {
		x.MyFeedback = &FeedbackDTO{Feedback: *feedback, Note: note, UpdatedAt: *feedbackAt}
	}
	return x, nil
}

// moneyText matches the evidence amount strings fmtMoney writes ("1100.00 INR").
var moneyText = regexp.MustCompile(`^(-?\d+(?:\.\d+)?) ([A-Z]{3})$`)

// enrichEvidence adds evidence.amounts: every "<decimal> <CUR>" string
// value as a Money object under the same key, and the same inside each
// object of a list value (e.g. the periods of a budget insight). The
// strings are kept for older clients. Reading them back is exact because
// fmtMoney writes money.Format output.
func enrichEvidence(ev map[string]any) {
	amounts := map[string]any{}
	for k, v := range ev {
		switch x := v.(type) {
		case string:
			if m := moneyText.FindStringSubmatch(x); m != nil {
				if minor, err := money.Parse(m[1], m[2], money.ParseOptions{AllowNegative: true, AllowZero: true}); err == nil {
					amounts[k] = apitypes.M(minor, m[2])
				}
			}
		case []any:
			for _, item := range x {
				if obj, ok := item.(map[string]any); ok {
					enrichEvidence(obj)
				}
			}
		}
	}
	if len(amounts) > 0 {
		ev["amounts"] = amounts
	}
}

// severityRank orders warnings before notices before info.
const severityRank = `case i.severity when 'warning' then 0 when 'notice' then 1 else 2 end`

type listCursor struct {
	Rank int       `json:"r"`
	T    time.Time `json:"t"`
	ID   uuid.UUID `json:"i"`
}

func rankOf(severity string) int {
	switch severity {
	case "warning":
		return 0
	case "notice":
		return 1
	}
	return 2
}

// List returns a page of the caller's insights (active by default):
// warnings first, then newest first.
func (s *Service) List(ctx context.Context, all bool, kind, cursor string, limit int) ([]InsightDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	var cur listCursor
	if err := httpx.DecodeCursor(cursor, &cur); err != nil {
		return nil, "", err
	}
	out := []InsightDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+insightCols+` from `+insightFrom+` where i.user_id = $1
			and ($2 or i.status = 'active' or (i.status = 'snoozed' and i.snoozed_until <= now())) and ($3 = '' or i.kind = $3)
			and ($4::timestamptz is null or `+severityRank+` > $5 or (`+severityRank+` = $5 and (i.created_at, i.id) < ($4, $6)))
			order by `+severityRank+`, i.created_at desc, i.id desc limit $7`, uid, all, kind, nullTime(cur.T), cur.Rank, cur.ID, limit+1)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, scanInsight)
		if err != nil {
			return err
		}
		if len(out) > limit {
			last := out[limit-1]
			next, _ = httpx.EncodeCursor(listCursor{Rank: rankOf(last.Severity), T: last.CreatedAt, ID: last.ID})
			out = out[:limit]
		}
		return nil
	})
	return out, next, database.MapError(err)
}

func nullTime(t time.Time) *time.Time {
	if t.IsZero() {
		return nil
	}
	return &t
}

// GenerateNow runs the rules for the caller and returns active insights.
func (s *Service) GenerateNow(ctx context.Context) (int, []InsightDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return 0, nil, err
	}
	var n int
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		n, err = s.Generate(ctx, tx, uid)
		return err
	})
	if err != nil {
		return 0, nil, database.MapError(err)
	}
	l, _, err := s.List(ctx, false, "", "", 200)
	return n, l, err
}

// ActionInput changes an insight's state.
type ActionInput struct {
	Action     string `json:"action" enum:"dismiss,snooze,expected,resolved,mute,reopen" doc:"mute stops this kind of insight for the same scope (e.g. category); reopen on a muted insight also removes the mute rule"`
	SnoozeDays int    `json:"snooze_days,omitempty" minimum:"1" maximum:"90" doc:"Default 7"`
}

// Act dismisses, snoozes, marks expected/resolved, mutes or reopens.
func (s *Service) Act(ctx context.Context, id uuid.UUID, in ActionInput) (*InsightDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out InsightDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var subtype, current string
		var ev []byte
		if err := tx.QueryRow(ctx, `select subtype, status, evidence from insights where id = $1 and user_id = $2 for update`, id, uid).
			Scan(&subtype, &current, &ev); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("insight")
			}
			return err
		}
		status := map[string]string{"dismiss": "dismissed", "snooze": "snoozed", "expected": "expected", "resolved": "resolved", "mute": "muted",
			"reopen": "active"}[in.Action]
		var until *time.Time
		if in.Action == "snooze" {
			days := in.SnoozeDays
			if days == 0 {
				days = 7
			}
			u := s.now().Add(time.Duration(days) * 24 * time.Hour)
			until = &u
		}
		if _, err := tx.Exec(ctx, `update insights set status = $3, snoozed_until = $4 where id = $1 and user_id = $2`, id, uid, status, until); err != nil {
			return err
		}
		var e map[string]any
		_ = json.Unmarshal(ev, &e)
		scope, _ := e["scope"].(string)
		if scope == "" {
			scope = "*"
		}
		switch in.Action {
		case "mute":
			if _, err := tx.Exec(ctx, `insert into insight_mutes (user_id, subtype, scope_key) values ($1,$2,$3) on conflict do nothing`, uid, subtype, scope); err != nil {
				return err
			}
		case "reopen":
			// A muted insight was hidden by its mute rule: reopening it
			// removes the rules that match it, so this kind is detected
			// again, and the other insights only those rules were hiding
			// come back too (the same as DELETE /insights/mutes).
			if current == "muted" {
				if _, err := tx.Exec(ctx, `delete from insight_mutes where user_id = $1 and subtype = $2 and scope_key in ('*', $3)`, uid, subtype, scope); err != nil {
					return err
				}
				if _, err := reopenUncovered(ctx, tx, uid, subtype); err != nil {
					return err
				}
			}
		case "expected":
			if err := upsertFeedback(ctx, tx, id, uid, "expected", nil); err != nil {
				return err
			}
		}
		rows, err := tx.Query(ctx, `select `+insightCols+` from `+insightFrom+` where i.id = $1`, id)
		if err != nil {
			return err
		}
		out, err = pgx.CollectExactlyOneRow(rows, scanInsight)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// FeedbackInput rates an insight.
type FeedbackInput struct {
	Feedback string `json:"feedback" enum:"helpful,not_helpful,incorrect,expected"`
	Note     string `json:"note,omitempty" maxLength:"500" doc:"Replaces the earlier note; empty clears it"`
}

func upsertFeedback(ctx context.Context, tx pgx.Tx, id, uid uuid.UUID, feedback string, note *string) error {
	_, err := tx.Exec(ctx, `insert into insight_feedback (insight_id, user_id, feedback, note, updated_at) values ($1,$2,$3,$4,now())
		on conflict (insight_id, user_id) do update set feedback = excluded.feedback, note = excluded.note, updated_at = now()`, id, uid, feedback, note)
	return err
}

// Feedback records feedback (used only to tune these rules; never shared).
// One answer per insight: repeating it updates the earlier one.
func (s *Service) Feedback(ctx context.Context, id uuid.UUID, in FeedbackInput) (*InsightDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out InsightDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from insights where id = $1 and user_id = $2)`, id, uid).Scan(&ok); err != nil {
			return err
		}
		if !ok {
			return apperr.NotFound("insight")
		}
		var note *string
		if n := strings.TrimSpace(in.Note); n != "" {
			note = &n
		}
		if err := upsertFeedback(ctx, tx, id, uid, in.Feedback, note); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select `+insightCols+` from `+insightFrom+` where i.id = $1`, id)
		if err != nil {
			return err
		}
		out, err = pgx.CollectExactlyOneRow(rows, scanInsight)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// InsightMuteDTO is a mute rule: insights of the subtype are not recorded for the
// scope (a category, account, merchant, subscription, recurring rule or
// budget ID, or * for all).
type InsightMuteDTO struct {
	Subtype   string    `json:"subtype"`
	Scope     string    `json:"scope" doc:"Record ID the rule applies to, or * for all"`
	CreatedAt time.Time `json:"created_at"`
}

// Mutes lists the caller's mute rules, newest first.
func (s *Service) Mutes(ctx context.Context) ([]InsightMuteDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []InsightMuteDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select subtype, scope_key, created_at from insight_mutes where user_id = $1 order by created_at desc, subtype, scope_key`, uid)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (InsightMuteDTO, error) {
			var m InsightMuteDTO
			err := r.Scan(&m.Subtype, &m.Scope, &m.CreatedAt)
			return m, err
		})
		return err
	})
	return out, database.MapError(err)
}

// UnmuteResult reports a removed mute rule and the insights it was hiding.
type UnmuteResult struct {
	Subtype  string       `json:"subtype"`
	Scope    string       `json:"scope"`
	Reopened int          `json:"reopened" doc:"Muted insights of the subtype that no remaining rule covers; they are active again"`
	Insights []InsightDTO `json:"insights" doc:"The reopened insights"`
}

// Unmute removes a mute rule and reopens the muted insights of that
// subtype that no remaining rule still covers.
func (s *Service) Unmute(ctx context.Context, subtype, scope string) (*UnmuteResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &UnmuteResult{Subtype: subtype, Scope: scope, Insights: []InsightDTO{}}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from insight_mutes where user_id = $1 and subtype = $2 and scope_key = $3`, uid, subtype, scope)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("mute")
		}
		ids, err := reopenUncovered(ctx, tx, uid, subtype)
		if err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select `+insightCols+` from `+insightFrom+` where i.id = any($1) order by i.created_at desc, i.id desc`, ids)
		if err != nil {
			return err
		}
		out.Insights, err = pgx.CollectRows(rows, scanInsight)
		out.Reopened = len(out.Insights)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return out, nil
}

// reopenUncovered makes the muted insights of a subtype active again when
// no remaining mute rule covers their scope, returning their IDs.
func reopenUncovered(ctx context.Context, tx pgx.Tx, uid uuid.UUID, subtype string) ([]uuid.UUID, error) {
	rows, err := tx.Query(ctx, `update insights i set status = 'active', snoozed_until = null where i.user_id = $1 and i.subtype = $2 and i.status = 'muted'
		and not exists (select 1 from insight_mutes m where m.user_id = $1 and m.subtype = $2 and m.scope_key in ('*', coalesce(i.evidence->>'scope', '*')))
		returning i.id`, uid, subtype)
	if err != nil {
		return nil, err
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return nil, err
	}
	if ids == nil {
		ids = []uuid.UUID{}
	}
	return ids, nil
}
