package reports

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/danielgtaylor/huma/v2/humatest"

	"montra/backend/internal/analytics"
	"montra/backend/internal/apitypes"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/reports/render"
)

func TestIsExpired(t *testing.T) {
	now := time.Date(2026, 11, 5, 10, 0, 0, 0, time.UTC)
	past, future := now.Add(-time.Minute), now.Add(time.Minute)
	for _, c := range []struct {
		status  string
		expires *time.Time
		want    bool
	}{
		{"completed", &past, true}, // the hourly cleanup has not run yet
		{"completed", &future, false},
		{"completed", &now, false},
		{"completed", nil, false},
		{"expired", nil, true},
		{"failed", &past, false},
		{"running", nil, false},
	} {
		if got := isExpired(c.status, c.expires, now); got != c.want {
			t.Errorf("isExpired(%s, %v) = %v", c.status, c.expires, got)
		}
	}
	s := &Service{Now: func() time.Time { return now }}
	r := s.present(&ReportDTO{Status: "completed", ExpiresAt: &past})
	if r.Status != "expired" {
		t.Fatalf("derived status = %s", r.Status)
	}
}

func TestStoredWindow(t *testing.T) {
	from, to := "2026-02-01", "2026-02-28"
	w := storedWindow(&from, &to, "Asia/Kolkata")
	if w == nil || w.From != from || w.To != to || w.Days != 28 || w.Timezone != "Asia/Kolkata" {
		t.Fatalf("window = %+v", w)
	}
	// Days count calendar days, also across a DST change in the user's zone.
	from, to = "2026-03-01", "2026-03-31"
	if w := storedWindow(&from, &to, "America/New_York"); w.Days != 31 {
		t.Fatalf("March = %d days", w.Days)
	}
	if storedWindow(nil, nil, "UTC") != nil || storedWindow(&from, nil, "UTC") != nil {
		t.Fatal("a report without dates has no window")
	}
}

func TestCheckTypesKeepsIncomeAndExpenseReportsApart(t *testing.T) {
	ok := []struct {
		reportType string
		types      []string
	}{
		{"income", nil}, {"income", []string{"income"}}, {"expense", []string{"refund"}},
		{"expense", []string{"expense", "group_expense", "refund", "reimbursement"}}, {"cash_flow", []string{"transfer"}},
		{"transactions", []string{"income", "expense"}},
	}
	for _, c := range ok {
		if err := checkTypes(c.reportType, c.types, "body.filters.types"); err != nil {
			t.Errorf("%s %v rejected: %v", c.reportType, c.types, err)
		}
	}
	for _, c := range []struct {
		reportType string
		types      []string
	}{{"income", []string{"expense"}}, {"income", []string{"income", "refund"}}, {"expense", []string{"income"}}, {"expense", []string{"transfer"}}} {
		err := checkTypes(c.reportType, c.types, "body.filters.types")
		var ae *apperr.Error
		if !errors.As(err, &ae) || ae.Details[0].Field != "body.filters.types" {
			t.Errorf("%s %v accepted: %v", c.reportType, c.types, err)
		}
	}
}

func TestReportFilterUsesTheStoredWindowAndTypeSet(t *testing.T) {
	win := &analytics.Window{From: "2026-10-01", To: "2026-10-31", Days: 31, Timezone: "Asia/Kolkata"}
	for _, c := range []struct {
		r     ReportDTO
		types []string
	}{
		{ReportDTO{ReportType: "income", Filters: Filters{Range: "this_month"}, Window: win}, []string{"income"}},
		{ReportDTO{ReportType: "expense", Filters: Filters{Range: "last_month"}, Window: win},
			[]string{"expense", "group_expense", "refund", "reimbursement"}},
		{ReportDTO{ReportType: "expense", Filters: Filters{Types: []string{"refund"}}, Window: win}, []string{"refund"}},
		// A request stored before the type check: still never mixes sides.
		{ReportDTO{ReportType: "income", Filters: Filters{Types: []string{"expense"}}, Window: win}, []string{"income"}},
		{ReportDTO{ReportType: "cash_flow", Filters: Filters{Types: []string{"expense"}}, Window: win}, []string{"expense"}},
		{ReportDTO{ReportType: "cash_flow", Window: win}, nil},
	} {
		f := c.r.filter()
		if f.Range != "" || f.From != win.From || f.To != win.To || !slices.Equal(f.Types, c.types) {
			t.Errorf("%s %+v → %+v, want types %v", c.r.ReportType, c.r.Filters, f, c.types)
		}
	}
	// Reports stored without a window resolve their filters as before.
	f := (&ReportDTO{ReportType: "cash_flow", Filters: Filters{Range: "last_month"}}).filter()
	if f.Range != "last_month" || f.From != "" {
		t.Fatalf("legacy filter = %+v", f)
	}
}

func cashFlowSample() *analytics.CashFlowReport {
	tot := func(cur string, inc, exp, ref, n int64) analytics.CashFlowTotals {
		net := exp - ref
		bp := int64(7500)
		return analytics.CashFlowTotals{Currency: cur, Income: apitypes.M(inc, cur), GrossExpense: apitypes.M(exp, cur), Refunds: apitypes.M(ref, cur),
			NetExpense: apitypes.M(net, cur), NetCashFlow: apitypes.M(inc-net, cur), SavingsRateBP: &bp, TransactionCount: n}
	}
	return &analytics.CashFlowReport{
		Window:         analytics.Window{From: "2026-10-01", To: "2026-10-31", Days: 31},
		Totals:         []analytics.CashFlowTotals{tot("INR", 500000, 125050, 0, 3)},
		Previous:       []analytics.CashFlowTotals{tot("INR", 0, 0, 0, 0)},
		PreviousWindow: analytics.Window{From: "2026-08-31", To: "2026-09-30", Days: 31},
		Series: []analytics.SeriesPoint{{Bucket: "2026-10-01", Currency: "INR", Income: apitypes.M(500000, "INR"),
			NetExpense: apitypes.M(125050, "INR"), Net: apitypes.M(374950, "INR")}},
		Converted: &analytics.ConvertedTotals{Currency: "USD", Income: apitypes.M(6000, "USD"), GrossExpense: apitypes.M(1500, "USD"),
			Refunds: apitypes.M(0, "USD"), NetExpense: apitypes.M(1500, "USD"), NetCashFlow: apitypes.M(4500, "USD"), RatePolicy: "Latest rate"},
	}
}

func titlesOf(secs []render.Section) (sections, columns []string, cells string) {
	var b strings.Builder
	for _, s := range secs {
		sections = append(sections, s.Title)
		for _, c := range s.Columns {
			columns = append(columns, s.Title+"/"+c.Title)
		}
		for _, r := range s.Rows {
			b.WriteString(strings.Join(r, "|") + "\n")
		}
	}
	return sections, columns, b.String()
}

func TestCashFlowSectionsShowOnlyTheirSide(t *testing.T) {
	cf := cashFlowSample()
	secs := cashFlowSections(cf, "income")
	names, cols, cells := titlesOf(secs)
	if !slices.Equal(names, []string{"Totals", "Previous period", "Converted to USD", "Series"}) {
		t.Fatalf("income sections = %v", names)
	}
	for _, c := range cols {
		if strings.Contains(strings.ToLower(c), "expense") || strings.Contains(c, "Refunds") || strings.Contains(c, "Net") {
			t.Errorf("income report column %q", c)
		}
	}
	if strings.Contains(cells, "1250.50") || strings.Contains(cells, "15.00") || strings.Contains(cells, "Gross") {
		t.Errorf("income report shows expense figures:\n%s", cells)
	}
	if !slices.Equal(secs[0].Rows[0], []string{"INR", "5000.00", "3"}) || !slices.Equal(secs[2].Rows[0], []string{"Income", "60.00", "USD"}) {
		t.Errorf("income rows = %v / %v", secs[0].Rows, secs[2].Rows)
	}
	if !strings.Contains(secs[1].Notes[0], "2026-08-31 to 2026-09-30") {
		t.Errorf("previous period note = %v", secs[1].Notes)
	}

	secs = cashFlowSections(cf, "expense")
	_, cols, cells = titlesOf(secs)
	for _, c := range cols {
		if strings.Contains(c, "Income") || strings.Contains(c, "Net cash flow") || strings.Contains(c, "Savings") {
			t.Errorf("expense report column %q", c)
		}
	}
	if strings.Contains(cells, "5000.00") || strings.Contains(cells, "60.00") {
		t.Errorf("expense report shows income:\n%s", cells)
	}
	if !slices.Equal(secs[0].Rows[0], []string{"INR", "1250.50", "0.00", "1250.50", "3"}) || !slices.Equal(secs[3].Columns[2:], []render.Column{{Title: "Net expense", Kind: render.Money}}) {
		t.Errorf("expense rows = %v / series %v", secs[0].Rows, secs[3].Columns)
	}

	secs = cashFlowSections(cf, "cash_flow")
	if len(secs[0].Columns) != 8 || secs[0].Columns[6].Title != "Savings rate %" || len(secs[2].Rows) != 5 || len(secs[3].Columns) != 5 {
		t.Errorf("cash flow sections = %+v", secs)
	}
}

func TestCategorySectionKinds(t *testing.T) {
	cr := &analytics.CategoryReport{Kind: analytics.KindIncome, Categories: []analytics.CategorySlice{{Name: "Salary", Currency: "INR",
		Amount: apitypes.M(500000, "INR"), NetExpense: apitypes.M(0, "INR"), ShareBP: 10000, Count: 1}}}
	sec := categorySection(cr)
	if sec.Title != "Income by category" || sec.Columns[2].Title != "Income" || !slices.Equal(sec.Rows[0], []string{"Salary", "INR", "5000.00", "100.00", "1"}) {
		t.Fatalf("income categories = %+v", sec)
	}
	cr.Kind = analytics.KindExpense
	if sec := categorySection(cr); sec.Title != "Spending by category" || sec.Columns[2].Title != "Net expense" {
		t.Fatalf("spending categories = %+v", sec)
	}
}

func TestFailureCode(t *testing.T) {
	for err, want := range map[error]string{
		jobs.WithCode(ErrCodeStorage, &failure{code: ErrCodeStorage, err: errors.New("disk full")}): ErrCodeStorage,
		fmt.Errorf("wrapped: %w", &failure{code: ErrCodeStorage, err: errors.New("x")}):             ErrCodeStorage,
		errors.New("connection reset"): ErrCodeGenerationFailed,
		context.DeadlineExceeded:       ErrCodeGenerationFailed,
	} {
		if got := failureCode(err); got != want {
			t.Errorf("failureCode(%v) = %s, want %s", err, got, want)
		}
	}
}

// The published contract carries the new operations, fields and enums (the
// OpenAPI file itself is regenerated separately).
func TestContract(t *testing.T) {
	_, api := humatest.New(t)
	(&Service{}).Routes(api)
	doc := api.OpenAPI()
	if p := doc.Paths["/reports/{id}"]; p == nil || p.Delete == nil || p.Delete.OperationID != "reports-delete" {
		t.Fatal("DELETE /reports/{id} missing")
	}
	if p := doc.Paths["/reports/schedules/{id}"]; p == nil || p.Patch == nil || p.Patch.OperationID != "reports-schedules-update" {
		t.Fatal("PATCH /reports/schedules/{id} missing")
	}
	schemas := doc.Components.Schemas.Map()
	enum := func(schema, field string) []string {
		t.Helper()
		sc := schemas[schema]
		if sc == nil || sc.Properties[field] == nil {
			t.Fatalf("%s.%s missing", schema, field)
		}
		var out []string
		for _, v := range sc.Properties[field].Enum {
			out = append(out, v.(string))
		}
		return out
	}
	formats := []string{"csv", "xlsx", "pdf", "json"}
	types := strings.Split("monthly_summary,yearly_summary,income,expense,cash_flow,category,merchant,account,budget,subscription,recurring,goal,transactions", ",")
	for _, c := range []struct {
		schema, field string
		want          []string
	}{
		{"ScheduleDTO", "format", formats},
		{"ScheduleDTO", "report_type", types},
		{"ReportDTO", "report_type", types},
		{"ReportDTO", "error_code", []string{ErrCodeUnavailable, ErrCodeInvalid, ErrCodeTooManyRows, ErrCodePDFTooLarge, ErrCodeStorage, ErrCodeGenerationFailed}},
		{"SchedulePatch", "format", formats},
		{"SchedulePatch", "cadence", []string{"weekly", "monthly"}},
	} {
		if got := enum(c.schema, c.field); !slices.Equal(got, c.want) {
			t.Errorf("%s.%s enum = %v, want %v", c.schema, c.field, got, c.want)
		}
	}
	for _, f := range []string{"window", "filters"} {
		if schemas["ReportDTO"].Properties[f] == nil {
			t.Errorf("ReportDTO.%s missing", f)
		}
	}
	for _, f := range []string{"filters", "version", "enabled"} {
		if schemas["ScheduleDTO"].Properties[f] == nil {
			t.Errorf("ScheduleDTO.%s missing", f)
		}
	}
	if del := doc.Paths["/reports/{id}"].Delete; !slices.Contains(del.Errors, http.StatusNotFound) {
		t.Errorf("DELETE /reports/{id} errors = %v", del.Errors)
	}
}
