package analytics

import (
	"errors"
	"slices"
	"testing"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/humatest"

	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
)

func loc(t *testing.T, name string) *time.Location {
	t.Helper()
	l, err := time.LoadLocation(name)
	if err != nil {
		t.Fatal(err)
	}
	return l
}

func TestChangeOfUsesTheMagnitudeOfTheBase(t *testing.T) {
	for _, c := range []struct {
		current, comparison int64
		change              string
		bp                  *int64
	}{
		{350000, 300000, "500.00", ptr(1667)},       // +16.67 %
		{290000, 300000, "-100.00", ptr(-333)},      // -3.33 %
		{3650000, -300000, "39500.00", ptr(131667)}, // from a negative net cash flow: still an increase
		{-50000, -100000, "500.00", ptr(5000)},      // less negative = up
		{-150000, -100000, "-500.00", ptr(-5000)},   // more negative = down
		{100, 0, "1.00", nil},                       // no base: no percentage
		{0, 0, "0.00", nil},
	} {
		got, err := changeOf(c.current, c.comparison, "INR")
		if err != nil || got.Change.Amount != c.change || got.Change.Currency != "INR" || !sameBP(got.ChangeBP, c.bp) {
			t.Errorf("changeOf(%d, %d) = %+v %v, want %s %v", c.current, c.comparison, got, err, c.change, show(c.bp))
		}
	}
	if _, err := changeOf(1<<62, -(1 << 62), "INR"); err == nil {
		t.Fatal("overflow not reported")
	}
}

func TestTotalsChangeComparesEveryMetricInOneCurrency(t *testing.T) {
	cur := totalsFrom("USD", 400000, 350000, 0, 3) // income 4000, net expense 3500
	cmp := totalsFrom("USD", 0, 320000, 20000, 2)  // no income, net expense 3000
	ch, err := totalsChange("USD", cur, cmp)
	if err != nil {
		t.Fatal(err)
	}
	if ch.Income.Change.Amount != "4000.00" || ch.Income.ChangeBP != nil {
		t.Errorf("income = %+v", ch.Income)
	}
	if ch.GrossExpense.Change.Amount != "300.00" || *ch.GrossExpense.ChangeBP != 938 {
		t.Errorf("gross expense = %+v %v", ch.GrossExpense, show(ch.GrossExpense.ChangeBP))
	}
	if ch.Refunds.Change.Amount != "-200.00" || *ch.Refunds.ChangeBP != -10000 {
		t.Errorf("refunds = %+v", ch.Refunds)
	}
	if ch.NetExpense.Change.Amount != "500.00" || *ch.NetExpense.ChangeBP != 1667 {
		t.Errorf("net expense = %+v", ch.NetExpense)
	}
	// Net cash flow: 500.00 now against -3000.00 before.
	if ch.NetCashFlow.Change.Amount != "3500.00" || *ch.NetCashFlow.ChangeBP != 11667 {
		t.Errorf("net cash flow = %+v %v", ch.NetCashFlow, show(ch.NetCashFlow.ChangeBP))
	}
	if ch.TransactionCount != 1 {
		t.Errorf("transaction count = %d", ch.TransactionCount)
	}
	for _, m := range []MetricChange{ch.Income, ch.GrossExpense, ch.Refunds, ch.NetExpense, ch.NetCashFlow} {
		if m.Change.Currency != "USD" {
			t.Errorf("currency mixed: %+v", m)
		}
	}
}

func TestResolveWindowInTheUsersCalendar(t *testing.T) {
	ist := finance.UserContext{Timezone: "Asia/Kolkata", Loc: loc(t, "Asia/Kolkata"), WeekStart: time.Monday, MonthStartDay: 1}
	utc := finance.UserContext{Timezone: "UTC", Loc: time.UTC, WeekStart: time.Monday, MonthStartDay: 1}
	tonga := finance.UserContext{Timezone: "Pacific/Tongatapu", Loc: loc(t, "Pacific/Tongatapu"), WeekStart: time.Monday, MonthStartDay: 1}
	// 20:00 UTC on 31 January is already 1 February in India.
	now := time.Date(2026, 1, 31, 20, 0, 0, 0, time.UTC)
	for _, c := range []struct {
		u        finance.UserContext
		f        Filter
		from, to string
		days     int
	}{
		{ist, Filter{Range: "this_month"}, "2026-02-01", "2026-02-28", 28},
		{ist, Filter{Range: "last_month"}, "2026-01-01", "2026-01-31", 31},
		{ist, Filter{}, "2026-02-01", "2026-02-28", 28}, // this_month by default
		{utc, Filter{Range: "this_month"}, "2026-01-01", "2026-01-31", 31},
		{tonga, Filter{Range: "today"}, "2026-02-01", "2026-02-01", 1},
		{ist, Filter{Range: "last_month", From: "2025-12-01", To: "2025-12-31"}, "2025-12-01", "2025-12-31", 31}, // custom wins
	} {
		w, err := ResolveWindow(c.f, now, c.u, "body.filters.")
		if err != nil || w.From != c.from || w.To != c.to || w.Days != c.days || w.Timezone != c.u.Timezone {
			t.Errorf("%s %+v = %+v %v, want %s..%s (%d days)", c.u.Timezone, c.f, w, err, c.from, c.to, c.days)
		}
	}
	for _, c := range []struct {
		f     Filter
		field string
	}{
		{Filter{From: "2026-01-01"}, "body.filters.from"},
		{Filter{To: "2026-01-01"}, "body.filters.from"},
		{Filter{From: "2026-01-01", To: "2026-02-30"}, "body.filters.to"},
		{Filter{From: "2026-03-01", To: "2026-02-01"}, "body.filters.to"},
		{Filter{Range: "fortnight"}, "body.filters.range"},
	} {
		_, err := ResolveWindow(c.f, now, ist, "body.filters.")
		var ae *apperr.Error
		if !errors.As(err, &ae) || ae.Code != apperr.CodeValidation || ae.Details[0].Field != c.field {
			t.Errorf("%+v: %v, want a validation error on %s", c.f, err, c.field)
		}
	}
}

func TestTypeSetsAndMeasures(t *testing.T) {
	inc := IncomeTypes()
	inc[0] = "changed"
	if IncomeTypes()[0] != "income" {
		t.Fatal("IncomeTypes shares its slice")
	}
	if !slices.Equal(ExpenseTypes(), []string{"expense", "group_expense", "refund", "reimbursement"}) {
		t.Fatalf("expense types = %v", ExpenseTypes())
	}
	m, types := categoryMeasure(KindIncome)
	if m != sqlIncome || !slices.Equal(types, []string{"income"}) {
		t.Fatalf("income measure = %s %v", m, types)
	}
	if m, types = categoryMeasure(KindExpense); m != sqlExpense+` - `+sqlRefund || len(types) != 4 {
		t.Fatalf("expense measure = %s %v", m, types)
	}
}

func TestArgsWithLeavesTheScopeUntouched(t *testing.T) {
	sc := &scope{}
	sc.arg("a")
	sc.arg("b")
	args, ph := sc.argsWith([]string{"income"}, 5)
	if len(sc.args) != 2 || len(args) != 4 || !slices.Equal(ph, []string{"$3", "$4"}) || args[3] != 5 {
		t.Fatalf("args = %v, placeholders = %v, scope = %v", args, ph, sc.args)
	}
}

// The published contract carries the new fields and enums (the OpenAPI file
// itself is regenerated separately).
func TestContractFields(t *testing.T) {
	_, api := humatest.New(t)
	s := &Service{}
	s.Routes(api, nil)
	s.CompareRoutes(api)
	schemas := api.OpenAPI().Components.Schemas.Map()
	prop := func(schema, field string) *huma.Schema {
		t.Helper()
		sc := schemas[schema]
		if sc == nil || sc.Properties[field] == nil {
			t.Fatalf("%s.%s missing", schema, field)
		}
		return sc.Properties[field]
	}
	enum := func(s *huma.Schema) []string {
		if s.Items != nil {
			s = s.Items
		}
		var out []string
		for _, v := range s.Enum {
			out = append(out, v.(string))
		}
		return out
	}
	if e := enum(prop("Comparison", "note_codes")); !slices.Equal(e, []string{"same_filters_and_rules", "compared_as_totals", "currencies_separate"}) {
		t.Errorf("note_codes enum = %v", e)
	}
	prop("CurrencyComparison", "change")
	for _, f := range []string{"income", "gross_expense", "refunds", "net_expense", "net_cash_flow", "transaction_count"} {
		prop("TotalsChange", f)
	}
	prop("MetricChange", "change_bp")
	prop("CashFlowReport", "previous_window")
	if e := enum(prop("ConvertedTotals", "rate_policy_code")); !slices.Equal(e, []string{"latest_on_or_before"}) {
		t.Errorf("rate_policy_code enum = %v", e)
	}
	prop("ConvertedTotals", "rate_policy_params")
	if e := enum(prop("CategoryReport", "kind")); !slices.Equal(e, []string{"expense", "income"}) {
		t.Errorf("kind enum = %v", e)
	}
	prop("CategorySlice", "amount")
	var kindParam *huma.Param
	for _, p := range api.OpenAPI().Paths["/analytics/categories"].Get.Parameters {
		if p.Name == "kind" {
			kindParam = p
		}
	}
	if kindParam == nil || kindParam.Schema.Default != "expense" || !slices.Equal(enum(kindParam.Schema), []string{"expense", "income"}) {
		t.Errorf("kind parameter = %+v", kindParam)
	}
}

func ptr(v int64) *int64 { return &v }

func sameBP(a, b *int64) bool { return (a == nil && b == nil) || (a != nil && b != nil && *a == *b) }

func show(p *int64) any {
	if p == nil {
		return "nil"
	}
	return *p
}
