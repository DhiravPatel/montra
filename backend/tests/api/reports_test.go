package api_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"

	"montra/backend/internal/app"
	"montra/backend/internal/domain/statement"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/testutil/apitest"
)

func setRate(t *testing.T, c *apitest.Client, base, quote, rate string, asOf time.Time) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodPost, "/fx/rates", map[string]any{"base": base, "quote": quote, "rate": rate, "as_of": asOf.UTC().Format(time.RFC3339)}).
		Expect(t, http.StatusCreated).Data()
}

func convert(t *testing.T, c *apitest.Client, q string) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodGet, "/fx/convert?"+q, nil).Expect(t, http.StatusOK).Data()
}

func TestFXRatesConversionHistoryAndDisplayCurrency(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "fxuser"))
	now := time.Now()
	setRate(t, c, "USD", "INR", "82.00", now.AddDate(0, 0, -10))
	setRate(t, c, "USD", "INR", "83.25", now.AddDate(0, 0, -1))
	cur := convert(t, c, "amount=10&from=USD&to=INR")
	if money(cur, "to") != "832.50" || cur["rate"].(map[string]any)["source"] != "manual" || cur["policy"] != "current" {
		t.Fatalf("current conversion = %v", cur)
	}
	hist := convert(t, c, "amount=10&from=USD&to=INR&policy=historical&date="+now.AddDate(0, 0, -5).Format(day))
	if money(hist, "to") != "820.00" {
		t.Fatalf("historical conversion used %v", hist["rate"])
	}
	// Inverse pair, zero- and three-decimal currencies, exact rounding.
	inv := convert(t, c, "amount=832.50&from=INR&to=USD")
	if money(inv, "to") != "10.00" || inv["rate"].(map[string]any)["inverted"] != true {
		t.Fatalf("inverse = %v", inv)
	}
	setRate(t, c, "JPY", "INR", "0.55", now.AddDate(0, 0, -1))
	if j := convert(t, c, "amount=1000&from=JPY&to=INR"); money(j, "to") != "550.00" {
		t.Fatalf("JPY = %v", j)
	}
	if j := convert(t, c, "amount=999.99&from=INR&to=JPY"); money(j, "to") != "1818" {
		t.Fatalf("INR→JPY (0 decimals) = %v", j)
	}
	setRate(t, c, "BHD", "INR", "220.5", now.AddDate(0, 0, -1))
	if b := convert(t, c, "amount=1.234&from=BHD&to=INR"); money(b, "to") != "272.10" || b["rounding_delta"] != "-0.3" {
		t.Fatalf("BHD = %v", b)
	}
	if r := c.Do(t, http.MethodGet, "/fx/convert?amount=1&from=GBP&to=INR", nil); r.ErrorCode() != "NOT_FOUND" {
		t.Fatalf("missing rate: %s", r.Raw)
	}
	// Provider rates (test double for the ECB feed) are append-only.
	ecb := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = io.WriteString(w, `<?xml version="1.0"?><gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01"><Cube><Cube time="`+
			now.AddDate(0, 0, -1).Format(day)+`"><Cube currency="USD" rate="1.0800"/><Cube currency="INR" rate="90.10"/><Cube currency="XXX" rate="1"/></Cube></Cube></gesmes:Envelope>`)
	}))
	defer ecb.Close()
	s.WorkerSvcs.FX.Cfg = config.FXConfig{Provider: "ecb", ECBURL: ecb.URL}
	n, err := s.WorkerSvcs.FX.RefreshECB(context.Background())
	if err != nil || n != 2 {
		t.Fatalf("ECB refresh = %d %v", n, err)
	}
	if n2, _ := s.WorkerSvcs.FX.RefreshECB(context.Background()); n2 != 0 {
		t.Fatalf("ECB refresh must not duplicate: %d", n2)
	}
	if e := convert(t, c, "amount=100&from=EUR&to=INR"); money(e, "to") != "9010.00" || e["rate"].(map[string]any)["source"] != "ecb" {
		t.Fatalf("EUR via provider = %v", e)
	}
	// Display currency: unlike currencies combined only with disclosed rates.
	inr := createAccount(t, c, map[string]any{"name": "INR bank", "account_type": "bank", "currency": "INR", "opening_balance": "10000"})["id"].(string)
	usd := createAccount(t, c, map[string]any{"name": "USD card", "account_type": "bank", "currency": "USD", "opening_balance": "500"})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": inr, "amount": "1000"})
	createTx(t, c, map[string]any{"type": "expense", "account_id": usd, "amount": "20"})
	cf := c.Do(t, http.MethodGet, "/analytics/cash-flow?display_currency=INR", nil).Expect(t, http.StatusOK).Data()
	conv := cf["converted"].(map[string]any)
	if money(conv, "net_expense") != "2665.00" || len(conv["rates"].([]any)) != 1 || len(conv["unconverted"].([]any)) != 0 || len(cf["totals"].([]any)) != 2 {
		t.Fatalf("converted = %v", conv)
	}
	gbp := c.Do(t, http.MethodGet, "/analytics/cash-flow?display_currency=GBP", nil).Expect(t, http.StatusOK).Data()["converted"].(map[string]any)
	if len(gbp["unconverted"].([]any)) != 2 || money(gbp, "net_expense") != "0.00" {
		t.Fatalf("GBP display without rates = %v", gbp)
	}
	// Manual rates are private to their owner.
	other, _ := s.Login(t, s.Register(t, "fxother"))
	if r := other.Do(t, http.MethodGet, "/fx/convert?amount=1&from=JPY&to=INR", nil); r.ErrorCode() != "NOT_FOUND" {
		t.Fatalf("another user's manual rate leaked: %s", r.Raw)
	}
	rates := c.Do(t, http.MethodGet, "/fx/rates?base=JPY", nil).Expect(t, http.StatusOK).List()
	other.Do(t, http.MethodDelete, "/fx/rates/"+rates[0].(map[string]any)["id"].(string), nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodDelete, "/fx/rates/"+rates[0].(map[string]any)["id"].(string), nil).Expect(t, http.StatusOK)
}

func reportOf(t *testing.T, s *apitest.Server, c *apitest.Client, body map[string]any) map[string]any {
	t.Helper()
	r := c.Do(t, http.MethodPost, "/reports", body).Expect(t, http.StatusAccepted).Data()
	if r["status"] != "queued" {
		t.Fatalf("new report = %v", r)
	}
	s.RunJobs(t)
	return c.Do(t, http.MethodGet, "/reports/"+r["id"].(string), nil).Expect(t, http.StatusOK).Data()
}

func download(t *testing.T, s *apitest.Server, c *apitest.Client, id string) []byte {
	t.Helper()
	acc := c.Do(t, http.MethodGet, "/reports/"+id+"/download", nil).Expect(t, http.StatusOK).Data()
	resp, err := http.Get(strings.Replace(acc["url"].(string), s.Cfg.HTTP.PublicBaseURL, s.URL, 1))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()
	b, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("download %d: %s", resp.StatusCode, b)
	}
	return b
}

func TestReportsFormatsIsolationExpiryAndSchedules(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "reporter"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "20000"})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1250.50", "description": "=SUM(A1:A9) shop"})
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "5000", "description": "Salary"})
	other, _ := s.Login(t, s.Register(t, "reportother"))
	oacct := createAccount(t, other, map[string]any{"name": "Other", "account_type": "bank", "currency": "INR"})["id"].(string)
	createTx(t, other, map[string]any{"type": "expense", "account_id": oacct, "amount": "999", "description": "SECRET-OTHER"})

	csvRep := reportOf(t, s, c, map[string]any{"report_type": "transactions", "format": "csv"})
	if csvRep["status"] != "completed" || csvRep["row_count"] != float64(3) { // opening balance + 2 transactions
		t.Fatalf("csv report = %v", csvRep)
	}
	body := download(t, s, c, csvRep["id"].(string))
	text := string(body)
	if !bytes.HasPrefix(body, []byte{0xEF, 0xBB, 0xBF}) || !strings.Contains(text, "'=SUM(A1:A9) shop") || !strings.Contains(text, "-1250.50") ||
		!strings.Contains(text, "Timezone") || !strings.Contains(text, "opening_balance") || strings.Contains(text, "SECRET-OTHER") {
		t.Fatalf("csv = %q", text)
	}
	xl := reportOf(t, s, c, map[string]any{"report_type": "monthly_summary", "format": "xlsx"})
	tb, err := statement.Parse(download(t, s, c, xl["id"].(string)), "xlsx", statement.DefaultLimits)
	if xl["status"] != "completed" || err != nil || tb.Rows[0][0] != "Monthly summary" {
		t.Fatalf("xlsx = %v %v", xl["status"], err)
	}
	pdf := reportOf(t, s, c, map[string]any{"report_type": "cash_flow", "format": "pdf", "title": "Cash flow (PDF)"})
	if pb := download(t, s, c, pdf["id"].(string)); !bytes.HasPrefix(pb, []byte("%PDF-1.4")) || !bytes.Contains(pb, []byte("Cash flow \\(PDF\\)")) {
		t.Fatalf("pdf = %q", pb[:min(len(pb), 80)])
	}
	js := reportOf(t, s, c, map[string]any{"report_type": "category", "format": "json"})
	var doc struct {
		Title    string `json:"title"`
		Sections []struct {
			Rows [][]string `json:"rows"`
		} `json:"sections"`
	}
	if err := json.Unmarshal(download(t, s, c, js["id"].(string)), &doc); err != nil || doc.Title != "Spending by category" || len(doc.Sections) != 1 {
		t.Fatalf("json = %v %+v", err, doc)
	}
	if n := notificationsOf(t, c, "export", "report_ready"); n != 4 {
		t.Fatalf("report notices = %d", n)
	}
	// Isolation.
	other.Do(t, http.MethodGet, "/reports/"+csvRep["id"].(string), nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodGet, "/reports/"+csvRep["id"].(string)+"/download", nil).Expect(t, http.StatusNotFound)
	if n := len(other.Do(t, http.MethodGet, "/reports", nil).List()); n != 0 {
		t.Fatalf("other user sees %d reports", n)
	}
	// Expiry: downloads stop, the retention job marks the report expired.
	s.Env.ExecWorker(t, `update reports set expires_at = now() - interval '1 minute' where id = $1`, csvRep["id"])
	if r := c.Do(t, http.MethodGet, "/reports/"+csvRep["id"].(string)+"/download", nil); r.ErrorCode() != "GONE" {
		t.Fatalf("expired download: %s", r.Raw)
	}
	enqueue := func(jobType string) {
		ctx := context.Background()
		if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
			_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: jobType, DedupeKey: jobType + ":" + fmt.Sprint(time.Now().UnixNano())})
			return err
		}); err != nil {
			t.Fatal(err)
		}
		s.RunJobs(t)
	}
	enqueue(app.JobRetentionCleanup)
	if st := c.Do(t, http.MethodGet, "/reports/"+csvRep["id"].(string), nil).Data()["status"]; st != "expired" {
		t.Fatalf("status after retention = %v", st)
	}
	// Schedules create a report for the previous full period.
	sch := c.Do(t, http.MethodPost, "/reports/schedules", map[string]any{"report_type": "monthly_summary", "format": "csv", "cadence": "monthly"}).
		Expect(t, http.StatusCreated).Data()
	if next, _ := time.Parse(time.RFC3339, sch["next_run_at"].(string)); !next.After(time.Now()) {
		t.Fatalf("next run = %v", sch["next_run_at"])
	}
	s.Env.ExecWorker(t, `update scheduled_reports set next_run_at = now() - interval '1 minute'`)
	enqueue("reports.schedules")
	list := c.Do(t, http.MethodGet, "/reports", nil).List()
	newest := list[0].(map[string]any)
	if newest["filters"].(map[string]any)["range"] != "last_month" || newest["status"] != "completed" {
		t.Fatalf("scheduled report = %v", newest)
	}
	if sl := c.Do(t, http.MethodGet, "/reports/schedules", nil).List(); len(sl) != 1 {
		t.Fatalf("schedules = %v", sl)
	} else if next, _ := time.Parse(time.RFC3339, sl[0].(map[string]any)["next_run_at"].(string)); !next.After(time.Now()) {
		t.Fatalf("schedule not advanced: %v", sl[0])
	}
	c.Do(t, http.MethodDelete, "/reports/schedules/"+sch["id"].(string), nil).Expect(t, http.StatusOK)
	if r := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "transactions", "format": "csv",
		"filters": map[string]any{"from": "2026-01-01"}}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("half custom range accepted: %s", r.Raw)
	}
}

func TestPlanningAnalyticsViews(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "planner"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	today := time.Now().Format(day)
	c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "Rent", "frequency": "monthly", "start_date": today,
		"amount": "12000", "account_id": acct}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "Gym", "frequency": "weekly", "start_date": today,
		"amount": "300", "account_id": acct}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "income", "name": "Freelance", "frequency": "monthly", "start_date": today,
		"amount_is_variable": true}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	rec := c.Do(t, http.MethodGet, "/analytics/recurring", nil).Expect(t, http.StatusOK).Data()
	var exp, inc map[string]any
	for _, x := range rec["commitments"].([]any) {
		m := x.(map[string]any)
		switch m["kind"] {
		case "expense":
			exp = m
		case "income":
			inc = m
		}
	}
	// 12000 + 300 × 52 / 12 = 13300.00 per month.
	if exp == nil || money(exp, "monthly_equivalent") != "13300.00" || exp["rule_count"] != float64(2) || inc == nil || inc["variable_count"] != float64(1) {
		t.Fatalf("commitments = %v", rec)
	}
	c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "All", "budget_type": "total", "period": "monthly", "currency": "INR", "limit": "1000"}).
		Expect(t, http.StatusCreated)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1500"})
	bp := c.Do(t, http.MethodGet, "/analytics/budgets", nil).Expect(t, http.StatusOK).Data()
	if bp["over_count"] != float64(1) || len(bp["budgets"].([]any)) != 1 {
		t.Fatalf("budget performance = %v", bp)
	}
	c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Car", "goal_type": "vehicle", "target_amount": "100000", "starting_amount": "25000"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)
	g := c.Do(t, http.MethodGet, "/analytics/goals", nil).Expect(t, http.StatusOK).Data()
	if tot := g["totals"].([]any); len(tot) != 1 || money(tot[0].(map[string]any), "saved") != "25000.00" {
		t.Fatalf("goal totals = %v", g)
	}
	c.Do(t, http.MethodGet, "/analytics/subscriptions", nil).Expect(t, http.StatusOK)
}
