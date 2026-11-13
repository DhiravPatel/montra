// Package analytics is the canonical calculation layer shared by the
// dashboard, analytics, reports and AI context (spec §20B.12). Every metric
// is computed server-side from ledger-backed transactions, per currency
// (unlike currencies are never summed), using the classification rules in
// domain/ledger (documented in docs/METRICS.md).
package analytics

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/domain/period"
	"montra/backend/internal/finance"
	"montra/backend/internal/fx"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
)

// SQL classification expressions — the single SQL definition of
// ledger.Classify (verified against it by tests/api/analytics_test.go).
const (
	sqlIncome  = `case when t.type = 'income' then t.amount_minor else 0 end`
	sqlExpense = `case when t.type = 'expense' then t.amount_minor when t.type = 'group_expense' then coalesce(t.personal_share_minor, t.amount_minor) else 0 end`
	sqlRefund  = `case when t.type in ('refund','reimbursement') then t.amount_minor else 0 end`
	sqlCounted = `t.type not in ('transfer','adjustment','opening_balance','settlement')`
)

// spendingTypes are the transaction types spending figures are made of, so
// a drill-down lists exactly what was counted (never opening balances,
// transfers or adjustments).
const spendingTypes = "expense,group_expense,refund,reimbursement"

// SQLExpressions exposes the classification SQL for verification tests.
func SQLExpressions() (income, expense, refund string) { return sqlIncome, sqlExpense, sqlRefund }

// IncomeTypes are the transaction types of the income views
// (/analytics/income, categories kind=income, income reports).
func IncomeTypes() []string { return []string{"income"} }

// ExpenseTypes are the transaction types of the spending views
// (/analytics/expenses, categories kind=expense, merchants, expense
// reports): refunds and reimbursements reduce spending.
func ExpenseTypes() []string { return []string{"expense", "group_expense", "refund", "reimbursement"} }

// Breakdown kinds of /analytics/categories.
const (
	KindExpense = "expense"
	KindIncome  = "income"
)

// Service computes analytics.
type Service struct {
	DB  *database.DB
	Now func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Filter scopes analytics queries.
type Filter struct {
	Range          string      `query:"range" enum:"today,yesterday,this_week,last_week,this_month,last_month,this_year,last_year,last_7_days,last_30_days,last_90_days," default:"this_month"`
	From           string      `query:"from" doc:"YYYY-MM-DD (custom range; overrides range)"`
	To             string      `query:"to"`
	AccountIDs     []uuid.UUID `query:"account_id" doc:"Comma-separated"`
	CategoryIDs    []uuid.UUID `query:"category_id" doc:"Comma-separated"`
	Currency       string      `query:"currency" pattern:"^([A-Z]{3})?$"`
	Types          []string    `query:"type" doc:"Comma-separated"`
	IncludePending bool        `query:"include_pending" doc:"Include pending transactions (posted only by default)"`
	OverviewOnly   bool        `query:"overview_only" doc:"Only accounts marked include_in_overview"`
	MerchantIDs    []uuid.UUID `query:"merchant_id" doc:"Comma-separated"`
	Tags           []string    `query:"tag" doc:"Comma-separated tag names (any)"`
	// DisplayCurrency adds a converted view with disclosed rates.
	DisplayCurrency string `query:"display_currency" pattern:"^([A-Z]{3})?$"`
}

// Window is a resolved reporting window.
type Window struct {
	From     string `json:"from"`
	To       string `json:"to"`
	Days     int    `json:"days"`
	Timezone string `json:"timezone"`
}

type scope struct {
	uid    uuid.UUID
	u      finance.UserContext
	r      period.Range
	where  []string
	args   []any
	window Window
}

func (sc *scope) arg(v any) string {
	sc.args = append(sc.args, v)
	return fmt.Sprintf("$%d", len(sc.args))
}

// resolveRange resolves a filter's dates in the user's calendar: a custom
// from/to, or a named range relative to now (this_month by default).
// Problems name the field under prefix ("query." or "body.filters.").
func resolveRange(f Filter, now time.Time, u finance.UserContext, prefix string) (period.Range, error) {
	if f.From != "" || f.To != "" {
		if f.From == "" || f.To == "" {
			return period.Range{}, apperr.FieldError(prefix+"from", "Provide both from and to for a custom range.")
		}
		from, err := finance.ParseDate(prefix+"from", f.From, u.Loc)
		if err != nil {
			return period.Range{}, err
		}
		to, err := finance.ParseDate(prefix+"to", f.To, u.Loc)
		if err != nil {
			return period.Range{}, err
		}
		r, err := period.Custom(from, to, u.Loc)
		if err != nil {
			return period.Range{}, apperr.FieldError(prefix+"to", err.Error())
		}
		return r, nil
	}
	name := f.Range
	if name == "" {
		name = "this_month"
	}
	r, err := period.Named(name, now, u.Period())
	if err != nil {
		return period.Range{}, apperr.FieldError(prefix+"range", "Unknown range.")
	}
	return r, nil
}

func windowOf(r period.Range, tz string) Window {
	return Window{From: finance.LocalDateString(r.Start), To: finance.LocalDateString(r.End), Days: r.Days(), Timezone: tz}
}

// ResolveWindow resolves a filter's dates exactly as the analytics
// endpoints do, relative to now in the user's calendar (time zone, week
// start, month start day). Reports store the result when they are
// requested, so a named range such as last_month stays fixed for that
// report. Problems name the field under prefix (e.g. "body.filters.").
func ResolveWindow(f Filter, now time.Time, u finance.UserContext, prefix string) (Window, error) {
	r, err := resolveRange(f, now, u, prefix)
	if err != nil {
		return Window{}, err
	}
	return windowOf(r, u.Timezone), nil
}

func (s *Service) newScope(ctx context.Context, tx pgx.Tx, uid uuid.UUID, f Filter) (*scope, error) {
	u, err := finance.LoadUser(ctx, tx, uid)
	if err != nil {
		return nil, err
	}
	r, err := resolveRange(f, s.now(), u, "query.")
	if err != nil {
		return nil, err
	}
	sc := &scope{uid: uid, u: u, r: r, window: windowOf(r, u.Timezone)}
	sc.where = append(sc.where, "t.user_id = "+sc.arg(uid), "t.deleted_at is null",
		"t.local_date between "+sc.arg(sc.window.From)+"::date and "+sc.arg(sc.window.To)+"::date")
	if f.IncludePending {
		sc.where = append(sc.where, "t.status in ('posted','pending')")
	} else {
		sc.where = append(sc.where, "t.status = 'posted'")
	}
	if len(f.AccountIDs) > 0 {
		sc.where = append(sc.where, "t.account_id = any("+sc.arg(f.AccountIDs)+")")
	}
	if len(f.CategoryIDs) > 0 {
		p := sc.arg(f.CategoryIDs)
		sc.where = append(sc.where, "(t.category_id = any("+p+") or t.category_id in (select id from categories where parent_id = any("+p+")))")
	}
	if f.Currency != "" {
		sc.where = append(sc.where, "t.currency = "+sc.arg(f.Currency))
	}
	if len(f.Types) > 0 {
		sc.where = append(sc.where, "t.type = any("+sc.arg(f.Types)+")")
	}
	if f.OverviewOnly {
		sc.where = append(sc.where, "a.include_in_overview")
	}
	if len(f.MerchantIDs) > 0 {
		sc.where = append(sc.where, "t.merchant_id = any("+sc.arg(f.MerchantIDs)+")")
	}
	if len(f.Tags) > 0 {
		sc.where = append(sc.where, "exists (select 1 from transaction_tags tt join tags tg on tg.id = tt.tag_id where tt.transaction_id = t.id and lower(tg.name) = any("+
			sc.arg(lowerAll(f.Tags))+"))")
	}
	return sc, nil
}

func (sc *scope) clause() string { return strings.Join(sc.where, " and ") }

// argsWith returns the scope's arguments followed by extra ones and the
// placeholders of the extras. A scope is shared by several queries, so its
// own argument list is never extended for one of them.
func (sc *scope) argsWith(extra ...any) ([]any, []string) {
	args := append(append(make([]any, 0, len(sc.args)+len(extra)), sc.args...), extra...)
	ph := make([]string, len(extra))
	for i := range extra {
		ph[i] = fmt.Sprintf("$%d", len(sc.args)+i+1)
	}
	return args, ph
}

func lowerAll(v []string) []string {
	out := make([]string, 0, len(v))
	for _, x := range v {
		if x = strings.ToLower(strings.TrimSpace(x)); x != "" {
			out = append(out, x)
		}
	}
	return out
}

// CashFlowTotals are per-currency cash-flow figures.
type CashFlowTotals struct {
	Currency         string         `json:"currency"`
	Income           apitypes.Money `json:"income"`
	GrossExpense     apitypes.Money `json:"gross_expense"`
	Refunds          apitypes.Money `json:"refunds" doc:"Refunds and reimbursements (reduce spending)"`
	NetExpense       apitypes.Money `json:"net_expense"`
	NetCashFlow      apitypes.Money `json:"net_cash_flow" doc:"Income minus net expense (transfers excluded)"`
	SavingsRateBP    *int64         `json:"savings_rate_bp,omitempty" doc:"Net cash flow / income in basis points; omitted when income is zero"`
	TransactionCount int64          `json:"transaction_count"`
}

func totalsFrom(cur string, inc, exp, ref, n int64) CashFlowTotals {
	net := exp - ref
	flow := inc - net
	t := CashFlowTotals{Currency: cur, Income: apitypes.M(inc, cur), GrossExpense: apitypes.M(exp, cur), Refunds: apitypes.M(ref, cur),
		NetExpense: apitypes.M(net, cur), NetCashFlow: apitypes.M(flow, cur), TransactionCount: n}
	if inc > 0 {
		bp := money.PercentBasisPoints(flow, inc)
		t.SavingsRateBP = &bp
	}
	return t
}

func (s *Service) cashFlow(ctx context.Context, tx pgx.Tx, sc *scope) ([]CashFlowTotals, error) {
	rows, err := tx.Query(ctx, `select t.currency, coalesce(sum(`+sqlIncome+`),0)::bigint, coalesce(sum(`+sqlExpense+`),0)::bigint,
		coalesce(sum(`+sqlRefund+`),0)::bigint, count(*) filter (where `+sqlCounted+`)
		from transactions t join financial_accounts a on a.id = t.account_id where `+sc.clause()+` group by t.currency order by t.currency`, sc.args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CashFlowTotals{}
	for rows.Next() {
		var cur string
		var inc, exp, ref, n int64
		if err := rows.Scan(&cur, &inc, &exp, &ref, &n); err != nil {
			return nil, err
		}
		out = append(out, totalsFrom(cur, inc, exp, ref, n))
	}
	return out, rows.Err()
}

// SeriesPoint is one bucket of a cash-flow series.
type SeriesPoint struct {
	Bucket     string         `json:"bucket" doc:"Bucket start date (YYYY-MM-DD)"`
	Currency   string         `json:"currency"`
	Income     apitypes.Money `json:"income"`
	NetExpense apitypes.Money `json:"net_expense"`
	Net        apitypes.Money `json:"net"`
}

// seriesGranularity picks the bucket size for a window when none is asked.
func seriesGranularity(sc *scope, granularity string) string {
	switch granularity {
	case "day", "week", "month", "year":
		return granularity
	}
	g := "day"
	if sc.r.Days() > 62 {
		g = "week"
	}
	if sc.r.Days() > 400 {
		g = "month"
	}
	return g
}

// bucketExpr truncates a date expression to its bucket. Weeks start on
// the user's week start (PostgreSQL weeks start on Monday, so the date is
// shifted before truncating and shifted back after).
func bucketExpr(granularity, date string, weekStart time.Weekday) string {
	if granularity == "week" {
		if shift := (8 - int(weekStart)) % 7; shift != 0 {
			return fmt.Sprintf("(date_trunc('week', (%s)::date + %d)::date - %d)", date, shift, shift)
		}
	}
	return "date_trunc('" + granularity + "', (" + date + ")::date)::date"
}

// series returns one point per bucket of the window (zero-filled) for each
// currency with activity, oldest first. Weeks start on the user's week
// start (preferences week_start; Monday by default).
func (s *Service) series(ctx context.Context, tx pgx.Tx, sc *scope, granularity string) ([]SeriesPoint, error) {
	granularity = seriesGranularity(sc, granularity)
	args := append(append([]any{}, sc.args...), sc.window.From, sc.window.To)
	from, to := fmt.Sprintf("$%d", len(args)-1), fmt.Sprintf("$%d", len(args))
	ws := sc.u.WeekStart
	rows, err := tx.Query(ctx, `with v as (
			select `+bucketExpr(granularity, "t.local_date", ws)+` as bucket, t.currency,
				coalesce(sum(`+sqlIncome+`),0)::bigint as inc, coalesce(sum(`+sqlExpense+`) - sum(`+sqlRefund+`),0)::bigint as exp
			from transactions t join financial_accounts a on a.id = t.account_id where `+sc.clause()+` group by 1, 2),
		b as (select generate_series(`+bucketExpr(granularity, from, ws)+`, `+bucketExpr(granularity, to, ws)+`,
			interval '1 `+granularity+`')::date as bucket),
		c as (select distinct currency from v)
		select to_char(b.bucket, 'YYYY-MM-DD'), c.currency, coalesce(v.inc, 0), coalesce(v.exp, 0)
		from b cross join c left join v on v.bucket = b.bucket and v.currency = c.currency
		order by 1, 2`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []SeriesPoint{}
	for rows.Next() {
		var b, cur string
		var inc, exp int64
		if err := rows.Scan(&b, &cur, &inc, &exp); err != nil {
			return nil, err
		}
		out = append(out, SeriesPoint{Bucket: b, Currency: cur, Income: apitypes.M(inc, cur), NetExpense: apitypes.M(exp, cur), Net: apitypes.M(inc-exp, cur)})
	}
	return out, rows.Err()
}

// CategorySlice is spending (kind=expense) or income (kind=income) in one
// category.
type CategorySlice struct {
	CategoryID   *uuid.UUID     `json:"category_id,omitempty" doc:"Absent for uncategorized"`
	Name         string         `json:"name"`
	SystemKey    *string        `json:"system_key,omitempty" doc:"Starter category key, or uncategorized"`
	Color        *string        `json:"color,omitempty"`
	Currency     string         `json:"currency"`
	Amount       apitypes.Money `json:"amount" doc:"What the breakdown measures: net expense (kind=expense) or income (kind=income)"`
	NetExpense   apitypes.Money `json:"net_expense" doc:"Net spending (kind=expense; equals amount). Zero for kind=income: read amount"`
	Count        int64          `json:"count" doc:"Transactions counted"`
	ShareBP      int64          `json:"share_bp" doc:"Share of this currency's total amount (net expense or income), in basis points; 0 when that total is not positive"`
	Subcategory  bool           `json:"subcategory"`
	ParentID     *uuid.UUID     `json:"parent_id,omitempty"`
	DrillDownURL string         `json:"drill_down_path" doc:"App path to the underlying transactions"`
}

// categoryMeasure is the SQL figure a breakdown kind sums and the
// transaction types it counts (the same sets as /analytics/expenses and
// /analytics/income).
func categoryMeasure(kind string) (string, []string) {
	if kind == KindIncome {
		return sqlIncome, IncomeTypes()
	}
	return sqlExpense + ` - ` + sqlRefund, ExpenseTypes()
}

// categories ranks categories by the kind's amount separately in each
// currency: limit applies per currency (one currency never crowds out
// another) and share_bp is relative to the currency's full total.
func (s *Service) categories(ctx context.Context, tx pgx.Tx, sc *scope, rollup bool, limit int, kind string) ([]CategorySlice, error) {
	key := "t.category_id"
	if rollup {
		key = "coalesce(c.parent_id, t.category_id)"
	}
	measure, types := categoryMeasure(kind)
	args, ph := sc.argsWith(types, limit)
	rows, err := tx.Query(ctx, `with base as (
		select `+key+` as cid, t.currency, sum(`+measure+`)::bigint as amt, count(*) as n
		from transactions t join financial_accounts a on a.id = t.account_id left join categories c on c.id = t.category_id
		where `+sc.clause()+` and t.type = any(`+ph[0]+`::text[]) group by 1, 2),
		ranked as (
		select b.cid, coalesce(c.name, 'Uncategorized') as name, case when b.cid is null then 'uncategorized' else c.system_key end as system_key,
		       c.color, b.currency, b.amt, b.n, c.parent_id, sum(b.amt) over (partition by b.currency)::bigint as total,
		       row_number() over (partition by b.currency order by b.amt desc, coalesce(c.name, 'Uncategorized'), b.cid) as rn
		from base b left join categories c on c.id = b.cid where b.amt <> 0)
		select cid, name, system_key, color, currency, amt, n, parent_id, total from ranked
		where rn <= `+ph[1]+` order by currency, rn`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CategorySlice{}
	for rows.Next() {
		var c CategorySlice
		var amt, total int64
		if err := rows.Scan(&c.CategoryID, &c.Name, &c.SystemKey, &c.Color, &c.Currency, &amt, &c.Count, &c.ParentID, &total); err != nil {
			return nil, err
		}
		c.Amount = apitypes.M(amt, c.Currency)
		c.NetExpense = apitypes.M(0, c.Currency)
		if kind != KindIncome {
			c.NetExpense = c.Amount
		}
		if total > 0 {
			c.ShareBP = money.PercentBasisPoints(amt, total)
		}
		c.Subcategory = c.ParentID != nil
		path := "/transactions?from=" + sc.window.From + "&to=" + sc.window.To
		if c.CategoryID != nil {
			path += "&category_id=" + c.CategoryID.String()
		} else {
			path += "&uncategorized=true"
		}
		if kind == KindIncome {
			path += "&type=income"
		} else {
			path += "&type=" + spendingTypes
		}
		c.DrillDownURL = path
		out = append(out, c)
	}
	return out, rows.Err()
}

// MerchantSlice is spending at one merchant.
type MerchantSlice struct {
	MerchantID *uuid.UUID     `json:"merchant_id,omitempty"`
	Name       string         `json:"name"`
	Currency   string         `json:"currency"`
	NetExpense apitypes.Money `json:"net_expense"`
	Count      int64          `json:"count"`
}

// merchants ranks merchants with positive net spending separately in each
// currency: limit applies per currency, so one currency never crowds out
// another (amounts in different currencies are not comparable).
func (s *Service) merchants(ctx context.Context, tx pgx.Tx, sc *scope, limit int) ([]MerchantSlice, error) {
	args, ph := sc.argsWith(ExpenseTypes(), limit)
	rows, err := tx.Query(ctx, `with m as (
		select t.merchant_id, coalesce(mc.name, 'Unknown merchant') as name, t.currency, sum(`+sqlExpense+` - `+sqlRefund+`)::bigint as net, count(*) as n
		from transactions t join financial_accounts a on a.id = t.account_id left join merchants mc on mc.id = t.merchant_id
		where `+sc.clause()+` and t.type = any(`+ph[0]+`::text[]) and t.merchant_id is not null
		group by 1, 2, 3),
		ranked as (select m.*, row_number() over (partition by m.currency order by m.net desc, m.name, m.merchant_id) as rn from m where m.net > 0)
		select merchant_id, name, currency, net, n from ranked where rn <= `+ph[1]+` order by currency, rn`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []MerchantSlice{}
	for rows.Next() {
		var m MerchantSlice
		var net int64
		if err := rows.Scan(&m.MerchantID, &m.Name, &m.Currency, &net, &m.Count); err != nil {
			return nil, err
		}
		m.NetExpense = apitypes.M(net, m.Currency)
		out = append(out, m)
	}
	return out, rows.Err()
}

// BalanceTotals summarizes tracked balances per currency.
type BalanceTotals struct {
	Currency     string         `json:"currency"`
	Assets       apitypes.Money `json:"assets" doc:"Sum of non-liability account balances"`
	Liabilities  apitypes.Money `json:"liabilities" doc:"Amount owed on credit cards and loans (positive)"`
	NetWorth     apitypes.Money `json:"net_worth" doc:"Assets minus liabilities (tracked, not bank-verified)"`
	AccountCount int64          `json:"account_count"`
}

func (s *Service) balances(ctx context.Context, tx pgx.Tx, uid uuid.UUID, overviewOnly bool) ([]BalanceTotals, error) {
	rows, err := tx.Query(ctx, `with b as (select a.currency, a.is_liability,
		coalesce((select sum(l.amount_minor) from account_ledger_entries l where l.account_id = a.id), 0)::bigint as bal
		from financial_accounts a where a.user_id = $1 and a.status <> 'closed' and ($2 = false or a.include_in_overview))
		select currency, coalesce(sum(bal) filter (where not is_liability), 0)::bigint, coalesce(-sum(bal) filter (where is_liability), 0)::bigint, count(*)
		from b group by currency order by currency`, uid, overviewOnly)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []BalanceTotals{}
	for rows.Next() {
		var cur string
		var assets, liab, n int64
		if err := rows.Scan(&cur, &assets, &liab, &n); err != nil {
			return nil, err
		}
		out = append(out, BalanceTotals{Currency: cur, Assets: apitypes.M(assets, cur), Liabilities: apitypes.M(liab, cur),
			NetWorth: apitypes.M(assets-liab, cur), AccountCount: n})
	}
	return out, rows.Err()
}

// Coverage discloses data freshness and completeness (spec §4.2, §4.11).
// Counts follow the window and filters, except pending_count.
type Coverage struct {
	TransactionCount     int64      `json:"transaction_count" doc:"Transactions in the window that match the filters"`
	EarliestTransaction  *string    `json:"earliest_transaction,omitempty"`
	LatestTransaction    *string    `json:"latest_transaction,omitempty"`
	UncategorizedCount   int64      `json:"uncategorized_count" doc:"Uncategorized income and expenses in the window that match the filters"`
	PendingCount         int64      `json:"pending_count" doc:"All your pending transactions, of any date and account (not limited to the window or filters); figures leave pending transactions out unless include_pending=true"`
	LastImportAt         *time.Time `json:"last_import_at,omitempty"`
	ProviderSyncedSource bool       `json:"provider_synced" doc:"False: balances are tracked from your entries/imports, not verified by a bank"`
}

func (s *Service) coverage(ctx context.Context, tx pgx.Tx, sc *scope) (*Coverage, error) {
	var c Coverage
	err := tx.QueryRow(ctx, `select count(*), min(t.local_date)::text, max(t.local_date)::text,
		count(*) filter (where t.category_id is null and t.type in ('expense','income')),
		(select count(*) from transactions p where p.user_id = $1 and p.status = 'pending' and p.deleted_at is null),
		(select max(last_import_at) from financial_accounts where user_id = $1),
		exists (select 1 from financial_accounts where user_id = $1 and balance_source = 'provider')
		from transactions t join financial_accounts a on a.id = t.account_id where `+sc.clause(), sc.args...).
		Scan(&c.TransactionCount, &c.EarliestTransaction, &c.LatestTransaction, &c.UncategorizedCount, &c.PendingCount, &c.LastImportAt, &c.ProviderSyncedSource)
	return &c, err
}

// CashFlowReport is the /analytics/cash-flow payload.
type CashFlowReport struct {
	Window         Window           `json:"window"`
	Totals         []CashFlowTotals `json:"totals" doc:"One entry per currency"`
	Previous       []CashFlowTotals `json:"previous_period" doc:"Same-length preceding period for comparison; its dates are previous_window"`
	PreviousWindow Window           `json:"previous_window" doc:"The dates previous_period covers: as many days as window, ending the day before it starts"`
	Series         []SeriesPoint    `json:"series"`
	SeriesBy       string           `json:"series_granularity" enum:"day,week,month,year" doc:"Bucket size of series (zero-filled buckets; weeks start on your week_start preference)"`
	Coverage       Coverage         `json:"coverage"`
	Converted      *ConvertedTotals `json:"converted,omitempty" doc:"Present when display_currency is requested"`
}

// CashFlow returns totals, a comparison period and a series.
func (s *Service) CashFlow(ctx context.Context, f Filter, granularity string) (*CashFlowReport, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out CashFlowReport
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		sc, err := s.newScope(ctx, tx, uid, f)
		if err != nil {
			return err
		}
		out.Window = sc.window
		if out.Totals, err = s.cashFlow(ctx, tx, sc); err != nil {
			return err
		}
		if out.Series, err = s.series(ctx, tx, sc, granularity); err != nil {
			return err
		}
		out.SeriesBy = seriesGranularity(sc, granularity)
		cov, err := s.coverage(ctx, tx, sc)
		if err != nil {
			return err
		}
		out.Coverage = *cov
		prev := f
		p := sc.r.Previous()
		prev.Range, prev.From, prev.To = "", finance.LocalDateString(p.Start), finance.LocalDateString(p.End)
		psc, err := s.newScope(ctx, tx, uid, prev)
		if err != nil {
			return err
		}
		out.PreviousWindow = psc.window
		if out.Previous, err = s.cashFlow(ctx, tx, psc); err != nil {
			return err
		}
		if f.DisplayCurrency != "" {
			out.Converted, err = convertTotals(ctx, tx, sc, out.Totals, f.DisplayCurrency)
		}
		return err
	})
	return &out, database.MapError(err)
}

// CategoryReport is the /analytics/categories payload.
type CategoryReport struct {
	Window     Window          `json:"window"`
	Kind       string          `json:"kind" enum:"expense,income" doc:"expense: net spending per category (refunds and reimbursements reduce it); income: income transactions per category"`
	Categories []CategorySlice `json:"categories" doc:"Grouped by currency (alphabetical), largest amount first; at most 100 per currency"`
}

// CategoryOptions select a category breakdown.
type CategoryOptions struct {
	Rollup bool   // roll subcategories up to their parents
	Kind   string // KindExpense (default) or KindIncome
}

// Categories returns spending by category (rolled up to parents by default).
func (s *Service) Categories(ctx context.Context, f Filter, rollup bool) (*CategoryReport, error) {
	return s.CategoryBreakdown(ctx, f, CategoryOptions{Rollup: rollup, Kind: KindExpense})
}

// CategoryBreakdown returns spending (kind expense: the /analytics/expenses
// types, net of refunds) or income (kind income: the /analytics/income
// types) per category and currency.
func (s *Service) CategoryBreakdown(ctx context.Context, f Filter, o CategoryOptions) (*CategoryReport, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if o.Kind == "" {
		o.Kind = KindExpense
	}
	if o.Kind != KindExpense && o.Kind != KindIncome {
		return nil, apperr.FieldError("query.kind", "Choose expense or income.")
	}
	out := CategoryReport{Kind: o.Kind}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		sc, err := s.newScope(ctx, tx, uid, f)
		if err != nil {
			return err
		}
		out.Window = sc.window
		out.Categories, err = s.categories(ctx, tx, sc, o.Rollup, 100, o.Kind)
		return err
	})
	return &out, database.MapError(err)
}

// MerchantReport is the /analytics/merchants payload.
type MerchantReport struct {
	Window    Window          `json:"window"`
	Merchants []MerchantSlice `json:"merchants" doc:"Grouped by currency (alphabetical), largest net spending first; each currency is ranked and limited separately"`
}

// Merchants returns the top merchants by net spending in each currency
// (limit applies per currency).
func (s *Service) Merchants(ctx context.Context, f Filter, limit int) (*MerchantReport, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if limit <= 0 || limit > 100 {
		limit = 10
	}
	var out MerchantReport
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		sc, err := s.newScope(ctx, tx, uid, f)
		if err != nil {
			return err
		}
		out.Window = sc.window
		out.Merchants, err = s.merchants(ctx, tx, sc, limit)
		return err
	})
	return &out, database.MapError(err)
}

// AccountsReport is the /analytics/accounts payload.
type AccountsReport struct {
	Totals []BalanceTotals `json:"totals"`
}

// Accounts returns balance totals per currency.
func (s *Service) Accounts(ctx context.Context, overviewOnly bool) (*AccountsReport, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out AccountsReport
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out.Totals, err = s.balances(ctx, tx, uid, overviewOnly)
		return err
	})
	return &out, database.MapError(err)
}

// TxRow is one transaction in an export (same filters as analytics).
type TxRow struct {
	Date, Account, Type, Direction, Amount, SignedAmount, Currency string
	Category, Merchant, Description, Tags, Status, Source          string
	OriginalAmount, OriginalCurrency, FXRate                       string
}

// ErrTooManyRows is returned when an export exceeds its row limit.
var ErrTooManyRows = apperr.Rule("report_too_large", "The report has too many transactions; narrow the date range or filters.", nil)

// TransactionRows streams filtered transactions (oldest first) for exports;
// it returns the resolved window and the row count. More than limit rows is
// an error (exports are never silently truncated).
func (s *Service) TransactionRows(ctx context.Context, f Filter, limit int, fn func(TxRow) error) (Window, int, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return Window{}, 0, err
	}
	var win Window
	n := 0
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		sc, err := s.newScope(ctx, tx, uid, f)
		if err != nil {
			return err
		}
		win = sc.window
		rows, err := tx.Query(ctx, `select t.local_date::text, a.name, t.type, t.direction, t.amount_minor, t.currency, coalesce(c.name, ''),
			coalesce(m.name, ''), coalesce(t.description, ''),
			coalesce((select string_agg(tg.name, ', ' order by tg.name) from transaction_tags tt join tags tg on tg.id = tt.tag_id
				where tt.transaction_id = t.id), ''), t.status, t.source, t.original_amount_minor, coalesce(t.original_currency, ''), coalesce(t.fx_rate::text, '')
			from transactions t join financial_accounts a on a.id = t.account_id left join categories c on c.id = t.category_id
			left join merchants m on m.id = t.merchant_id where `+sc.clause()+` order by t.local_date, t.created_at limit `+fmt.Sprint(limit+1), sc.args...)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var r TxRow
			var amt int64
			var orig *int64
			if err := rows.Scan(&r.Date, &r.Account, &r.Type, &r.Direction, &amt, &r.Currency, &r.Category, &r.Merchant, &r.Description,
				&r.Tags, &r.Status, &r.Source, &orig, &r.OriginalCurrency, &r.FXRate); err != nil {
				return err
			}
			n++
			if n > limit {
				return ErrTooManyRows
			}
			r.Amount = apitypes.M(amt, r.Currency).Amount
			r.FXRate = fx.NormalizeDecimal(r.FXRate)
			signed := amt
			if r.Direction == "outflow" {
				signed = -amt
			}
			r.SignedAmount = apitypes.M(signed, r.Currency).Amount
			if orig != nil && r.OriginalCurrency != "" {
				r.OriginalAmount = apitypes.M(*orig, r.OriginalCurrency).Amount
			}
			if err := fn(r); err != nil {
				return err
			}
		}
		return rows.Err()
	})
	return win, n, database.MapError(err)
}
