package api_test

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"regexp"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/storage"
	"montra/backend/internal/testutil/apitest"
)

// Reports, analytics and exchange-rate fixes reported by the web client.

// rfxStore wraps the worker's file store: before runs with the object key
// ahead of every upload, and an error from it fails the upload.
type rfxStore struct {
	storage.Store
	before func(key string) error
}

func (f *rfxStore) Put(ctx context.Context, a storage.Area, key, src, contentType string) error {
	if err := f.before(key); err != nil {
		return err
	}
	return f.Store.Put(ctx, a, key, src, contentType)
}

type rfxDoc struct {
	Title string `json:"title"`
	Meta  []struct {
		Key   string `json:"key"`
		Value string `json:"value"`
	} `json:"meta"`
	Sections []rfxSection `json:"sections"`
}

type rfxSection struct {
	Title   string `json:"title"`
	Columns []struct {
		Title string `json:"title"`
		Kind  string `json:"kind"`
	} `json:"columns"`
	Rows  [][]string `json:"rows"`
	Notes []string   `json:"notes"`
}

func (d rfxDoc) meta(key string) string {
	for _, m := range d.Meta {
		if m.Key == key {
			return m.Value
		}
	}
	return ""
}

func (d rfxDoc) section(t *testing.T, title string) rfxSection {
	t.Helper()
	for _, s := range d.Sections {
		if s.Title == title {
			return s
		}
	}
	t.Fatalf("no section %q in %v", title, d.titles())
	return rfxSection{}
}

func (d rfxDoc) titles() []string {
	var out []string
	for _, s := range d.Sections {
		out = append(out, s.Title)
	}
	return out
}

func (d rfxDoc) columns() []string {
	var out []string
	for _, s := range d.Sections {
		for _, c := range s.Columns {
			out = append(out, s.Title+"/"+c.Title)
		}
	}
	return out
}

// rfxReport requests a JSON report, runs the jobs and returns the report
// with its parsed document and raw bytes.
func rfxReport(t *testing.T, s *apitest.Server, c *apitest.Client, body map[string]any) (map[string]any, rfxDoc, string) {
	t.Helper()
	rep := reportOf(t, s, c, body)
	if rep["status"] != "completed" {
		t.Fatalf("report = %v", rep)
	}
	raw := download(t, s, c, rep["id"].(string))
	var d rfxDoc
	if err := json.Unmarshal(raw, &d); err != nil {
		t.Fatalf("report json: %v", err)
	}
	return rep, d, string(raw)
}

func rfxRunJob(t *testing.T, s *apitest.Server, jobType string) {
	t.Helper()
	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: jobType, DedupeKey: jobType + ":" + uuid.NewString()})
		return err
	}); err != nil {
		t.Fatal(err)
	}
	s.RunJobs(t)
}

func rfxWindow(t *testing.T, r map[string]any) (string, string, float64) {
	t.Helper()
	w, ok := r["window"].(map[string]any)
	if !ok {
		t.Fatalf("no window: %v", r)
	}
	return w["from"].(string), w["to"].(string), w["days"].(float64)
}

// DELETE /reports/{id}: owner only, any status, audited; the stored file is
// removed through the files deletion job and a running generation drops
// its file.
func TestReportDeleteRemovesTheFile(t *testing.T) {
	s := apitest.New(t, nil)
	email := s.Register(t, "reportdelete")
	c, _ := s.Login(t, email)
	uid := userID(t, s, email)
	other, _ := s.Login(t, s.Register(t, "reportdeleteother"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "250"})
	ctx := context.Background()

	rep := reportOf(t, s, c, map[string]any{"report_type": "transactions", "format": "csv"})
	id := rep["id"].(string)
	if rep["status"] != "completed" {
		t.Fatalf("report = %v", rep)
	}
	fileID := workerString(t, s, `select file_id::text from reports where id = $1`, id)
	objectKey := workerString(t, s, `select object_key from files where id = $1`, fileID)
	link := c.Do(t, http.MethodGet, "/reports/"+id+"/download", nil).Expect(t, http.StatusOK).Data()["url"].(string)

	other.Do(t, http.MethodDelete, "/reports/"+id, nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodGet, "/reports/"+id, nil).Expect(t, http.StatusOK)

	c.Do(t, http.MethodDelete, "/reports/"+id, nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodGet, "/reports/"+id, nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodGet, "/reports/"+id+"/download", nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodDelete, "/reports/"+id, nil).Expect(t, http.StatusNotFound)
	if l := c.Do(t, http.MethodGet, "/reports", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("deleted report still listed: %v", l)
	}
	if st := workerString(t, s, `select status from files where id = $1`, fileID); st != "deleting" {
		t.Fatalf("file status after delete = %s", st)
	}
	s.RunJobs(t)
	if st := workerString(t, s, `select status from files where id = $1`, fileID); st != "deleted" {
		t.Fatalf("file status after the deletion job = %s", st)
	}
	if _, err := s.WorkerSvcs.Reports.Store.Open(ctx, storage.AreaExports, objectKey); !errors.Is(err, storage.ErrNotFound) {
		t.Fatalf("stored object still there: %v", err)
	}
	resp, err := http.Get(strings.Replace(link, s.Cfg.HTTP.PublicBaseURL, s.URL, 1))
	if err != nil {
		t.Fatal(err)
	}
	_, _ = io.Copy(io.Discard, resp.Body)
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("a link issued before the delete answers %d", resp.StatusCode)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'report' and entity_id = $1 and action = 'deleted'
		and actor_user_id = $2 and changes->>'status' = 'completed'`, id, uid); n != 1 {
		t.Fatalf("report deletion audit events = %d", n)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'file' and entity_id = $1 and action = 'deleted'`, fileID); n != 1 {
		t.Fatalf("file deletion audit events = %d", n)
	}

	// A queued report: its generation is cancelled and never produces a file.
	q := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "cash_flow", "format": "pdf"}).Expect(t, http.StatusAccepted).Data()
	jobID := workerString(t, s, `select job_id::text from reports where id = $1`, q["id"])
	c.Do(t, http.MethodDelete, "/reports/"+q["id"].(string), nil).Expect(t, http.StatusOK)
	if st := workerString(t, s, `select status from jobs where id = $1`, jobID); st != "cancelled" {
		t.Fatalf("queued generation = %s", st)
	}
	s.RunJobs(t)
	if n := workerCount(t, s, `select count(*) from files where owner_user_id = $1 and purpose = 'report_export'`, uid); n != 1 {
		t.Fatalf("export files = %d", n)
	}

	// Deleted while it was being generated: the finished file is dropped.
	orig := s.WorkerSvcs.Reports.Store
	defer func() { s.WorkerSvcs.Reports.Store = orig }()
	var rid, putKey string
	s.WorkerSvcs.Reports.Store = &rfxStore{Store: orig, before: func(key string) error {
		putKey = key
		c.Do(t, http.MethodDelete, "/reports/"+rid, nil).Expect(t, http.StatusOK)
		return nil
	}}
	rid = c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "transactions", "format": "csv"}).Expect(t, http.StatusAccepted).
		Data()["id"].(string)
	jobID = workerString(t, s, `select job_id::text from reports where id = $1`, rid)
	s.RunJobs(t)
	if putKey == "" {
		t.Fatal("the report was not generated")
	}
	if _, err := orig.Open(ctx, storage.AreaExports, putKey); !errors.Is(err, storage.ErrNotFound) {
		t.Fatalf("the file of a deleted report was kept: %v", err)
	}
	if n := workerCount(t, s, `select count(*) from files where object_key = $1`, putKey); n != 0 {
		t.Fatalf("file rows for a deleted report = %d", n)
	}
	if n := workerCount(t, s, `select count(*) from notifications where entity_id = $1`, rid); n != 0 {
		t.Fatalf("notifications for a deleted report = %d", n)
	}
	if st := workerString(t, s, `select status from jobs where id = $1`, jobID); st != "succeeded" {
		t.Fatalf("generation job = %s", st)
	}
	// The ready notification opens the reports page (a web route).
	if link := workerString(t, s, `select deep_link from notifications where user_id = $1 and event_type = 'report_ready' limit 1`, uid); link != "/reports" {
		t.Fatalf("deep link = %q", link)
	}
}

// Income and expense reports apply the /analytics/income and
// /analytics/expenses type sets: an income report contains no expenses.
func TestIncomeAndExpenseReportsKeepToTheirTypes(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "incomereport"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "20000"})["id"].(string)
	savings := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR"})["id"].(string)
	salary, freelance, groceries := categoryID(t, c, "Salary"), categoryID(t, c, "Freelance income"), categoryID(t, c, "Groceries")
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "5000.00", "category_id": salary})
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "1200.00", "category_id": freelance})
	shop := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1250.50", "category_id": groceries, "description": "Weekly shop"})
	c.Do(t, http.MethodPost, "/transactions/"+shop["id"].(string)+"/refunds", map[string]any{"amount": "50.25"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": acct, "to_account_id": savings, "amount": "300"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)

	inc, doc, raw := rfxReport(t, s, c, map[string]any{"report_type": "income", "format": "json"})
	if !slices.Equal(doc.titles(), []string{"Totals", "Previous period", "Series", "Income by category"}) {
		t.Fatalf("income report sections = %v", doc.titles())
	}
	for _, col := range doc.columns() {
		if l := strings.ToLower(col); strings.Contains(l, "expense") || strings.Contains(l, "refund") || strings.Contains(l, "cash flow") || strings.Contains(l, "savings") {
			t.Errorf("income report column %q", col)
		}
	}
	for _, v := range []string{"1250.50", "50.25", "1200.25", "300.00", "Weekly shop", "Groceries"} {
		if strings.Contains(raw, v) {
			t.Errorf("income report contains %q:\n%s", v, raw)
		}
	}
	if rows := doc.section(t, "Totals").Rows; !slices.EqualFunc(rows, [][]string{{"INR", "6200.00", "2"}}, slices.Equal) {
		t.Fatalf("income totals = %v", rows)
	}
	if rows := doc.section(t, "Income by category").Rows; !slices.EqualFunc(rows, [][]string{
		{"Salary", "INR", "5000.00", "80.65", "1"}, {"Freelance income", "INR", "1200.00", "19.35", "1"}}, slices.Equal) {
		t.Fatalf("income by category = %v", rows)
	}
	if f := inc["filters"].(map[string]any); f["range"] != "this_month" || doc.meta("Filters") != "range=this_month" {
		t.Fatalf("filters = %v / %q", f, doc.meta("Filters"))
	}

	_, doc, raw = rfxReport(t, s, c, map[string]any{"report_type": "expense", "format": "json"})
	if !slices.Equal(doc.titles(), []string{"Totals", "Previous period", "Series", "Spending by category"}) {
		t.Fatalf("expense report sections = %v", doc.titles())
	}
	for _, col := range doc.columns() {
		if strings.Contains(col, "Income") || strings.Contains(col, "cash flow") || strings.Contains(col, "Savings") {
			t.Errorf("expense report column %q", col)
		}
	}
	for _, v := range []string{"5000.00", "6200.00", "Salary", "Freelance"} {
		if strings.Contains(raw, v) {
			t.Errorf("expense report contains %q", v)
		}
	}
	if rows := doc.section(t, "Totals").Rows; !slices.EqualFunc(rows, [][]string{{"INR", "1250.50", "50.25", "1200.25", "2"}}, slices.Equal) {
		t.Fatalf("expense totals = %v", rows)
	}

	// Cash flow keeps both sides.
	_, doc, _ = rfxReport(t, s, c, map[string]any{"report_type": "cash_flow", "format": "json"})
	if rows := doc.section(t, "Totals").Rows; !slices.EqualFunc(rows, [][]string{{"INR", "6200.00", "1250.50", "50.25", "1200.25", "4999.75", "80.64", "4"}}, slices.Equal) {
		t.Fatalf("cash flow totals = %v", rows)
	}

	// Types narrow inside a report's own set and never cross it.
	r := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "income", "format": "csv", "filters": map[string]any{"types": []string{"expense"}}})
	if r.Status != http.StatusUnprocessableEntity || r.ErrorCode() != "VALIDATION_ERROR" || detail(t, r)["field"] != "body.filters.types" {
		t.Fatalf("income report with expense types: %d %s", r.Status, r.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "expense", "format": "csv",
		"filters": map[string]any{"types": []string{"refund", "income"}}}); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("expense report with income types: %d %s", r.Status, r.Raw)
	}
	_, doc, _ = rfxReport(t, s, c, map[string]any{"report_type": "expense", "format": "json", "filters": map[string]any{"types": []string{"refund"}}})
	if rows := doc.section(t, "Totals").Rows; !slices.EqualFunc(rows, [][]string{{"INR", "0.00", "50.25", "-50.25", "1"}}, slices.Equal) {
		t.Fatalf("refund-only expense totals = %v", rows)
	}
	if r := c.Do(t, http.MethodPost, "/reports/schedules", map[string]any{"report_type": "income", "format": "csv", "cadence": "monthly",
		"filters": map[string]any{"types": []string{"expense"}}}); r.Status != http.StatusUnprocessableEntity || detail(t, r)["field"] != "body.filters.types" {
		t.Fatalf("income schedule with expense types: %d %s", r.Status, r.Raw)
	}
}

// A report's window is resolved in the owner's time zone when it is
// requested and stays fixed however late it is generated; asking again
// resolves the range from the new request date.
func TestReportWindowIsResolvedAtRequest(t *testing.T) {
	s := apitest.New(t, nil)
	email := s.Register(t, "reportwindow")
	c, _ := s.Login(t, email)
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR"})["id"].(string)
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "900", "local_date": "2026-01-15"})
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "700", "local_date": "2026-02-10"})
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "400"}) // today

	// 20:00 UTC on 31 January is 01:30 on 1 February in India.
	s.Svcs.Reports.Now = func() time.Time { return time.Date(2026, 1, 31, 20, 0, 0, 0, time.UTC) }
	feb := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "cash_flow", "format": "json", "filters": map[string]any{"range": "this_month"}}).
		Expect(t, http.StatusAccepted).Data()
	if from, to, days := rfxWindow(t, feb); from != "2026-02-01" || to != "2026-02-28" || days != 28 || feb["window"].(map[string]any)["timezone"] != "Asia/Kolkata" {
		t.Fatalf("this_month window = %v", feb["window"])
	}
	if feb["filters"].(map[string]any)["range"] != "this_month" {
		t.Fatalf("filters = %v", feb["filters"])
	}
	jan := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "income", "format": "json", "filters": map[string]any{"range": "last_month"}}).
		Expect(t, http.StatusAccepted).Data()
	if from, to, _ := rfxWindow(t, jan); from != "2026-01-01" || to != "2026-01-31" {
		t.Fatalf("last_month window = %v", jan["window"])
	}
	if acc := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "account", "format": "csv"}).Expect(t, http.StatusAccepted).Data(); acc["window"] != nil {
		t.Fatalf("an account report has no window: %v", acc["window"])
	}
	// The same instant is still January for a UTC user.
	s.Env.ExecWorker(t, `update user_preferences set timezone = 'UTC' where user_id = $1`, userID(t, s, email))
	utc := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "cash_flow", "format": "csv"}).Expect(t, http.StatusAccepted).Data()
	if from, to, _ := rfxWindow(t, utc); from != "2026-01-01" || to != "2026-01-31" || utc["timezone"] != "UTC" {
		t.Fatalf("UTC window = %v", utc["window"])
	}
	s.Env.ExecWorker(t, `update user_preferences set timezone = 'Asia/Kolkata' where user_id = $1`, userID(t, s, email))

	// Generated now (months later), each report keeps its own dates.
	s.RunJobs(t)
	var doc rfxDoc
	if err := json.Unmarshal(download(t, s, c, feb["id"].(string)), &doc); err != nil {
		t.Fatal(err)
	}
	if doc.meta("Period") != "2026-02-01 to 2026-02-28" || !slices.Equal(doc.section(t, "Totals").Rows[0], []string{"INR", "700.00", "0.00", "0.00", "0.00", "700.00", "100.00", "1"}) {
		t.Fatalf("February report: %q %v", doc.meta("Period"), doc.section(t, "Totals").Rows)
	}
	if err := json.Unmarshal(download(t, s, c, jan["id"].(string)), &doc); err != nil {
		t.Fatal(err)
	}
	if doc.meta("Period") != "2026-01-01 to 2026-01-31" || !slices.Equal(doc.section(t, "Totals").Rows[0], []string{"INR", "900.00", "1"}) {
		t.Fatalf("January report: %q %v", doc.meta("Period"), doc.section(t, "Totals").Rows)
	}
	got := c.Do(t, http.MethodGet, "/reports/"+feb["id"].(string), nil).Expect(t, http.StatusOK).Data()
	if from, to, _ := rfxWindow(t, got); from != "2026-02-01" || to != "2026-02-28" || got["status"] != "completed" {
		t.Fatalf("stored report = %v", got)
	}

	// Asking again resolves the range from the new request date.
	s.Svcs.Reports.Now = func() time.Time { return time.Date(2026, 3, 15, 6, 0, 0, 0, time.UTC) }
	again := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "cash_flow", "format": "json", "filters": feb["filters"]}).
		Expect(t, http.StatusAccepted).Data()
	if from, to, _ := rfxWindow(t, again); from != "2026-03-01" || to != "2026-03-31" {
		t.Fatalf("regenerated window = %v", again["window"])
	}
	s.Svcs.Reports.Now = nil
	today := todayIn(t, "Asia/Kolkata")
	now := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "cash_flow", "format": "json"}).Expect(t, http.StatusAccepted).Data()
	if from, _, _ := rfxWindow(t, now); from != time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC).Format(day) {
		t.Fatalf("current window = %v", now["window"])
	}
	// Bad custom ranges are rejected when requested, not when generated.
	if r := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "transactions", "format": "csv",
		"filters": map[string]any{"from": "2026-03-01", "to": "2026-02-01"}}); r.Status != http.StatusUnprocessableEntity || detail(t, r)["field"] != "body.filters.to" {
		t.Fatalf("reversed range: %d %s", r.Status, r.Raw)
	}
}

// A generation that runs out of retries fails the report with a reason
// code; a job that ended without a result is swept; a completed report past
// expires_at reads as expired everywhere before the hourly cleanup.
func TestReportFailureAndExpiryAreNeverStuck(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "reportstuck"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR"})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "99"})
	s.RunJobs(t)

	orig := s.WorkerSvcs.Reports.Store
	s.WorkerSvcs.Reports.Store = &rfxStore{Store: orig, before: func(string) error { return errors.New("bucket unavailable") }}
	id := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "transactions", "format": "csv"}).Expect(t, http.StatusAccepted).
		Data()["id"].(string)
	jobID := workerString(t, s, `select job_id::text from reports where id = $1`, id)
	// The first failure is retried: the report keeps running.
	if _, err := s.Worker.Drain(context.Background(), 1); err != nil {
		t.Fatal(err)
	}
	if r := c.Do(t, http.MethodGet, "/reports/"+id, nil).Expect(t, http.StatusOK).Data(); r["status"] != "running" || r["error_code"] != nil {
		t.Fatalf("after one failed attempt = %v", r)
	}
	if st := workerString(t, s, `select status from jobs where id = $1`, jobID); st != "queued" {
		t.Fatalf("job after one attempt = %s", st)
	}
	// The last attempt fails the report with the reason.
	s.RunJobs(t)
	if r := c.Do(t, http.MethodGet, "/reports/"+id, nil).Expect(t, http.StatusOK).Data(); r["status"] != "failed" || r["error_code"] != "storage_unavailable" {
		t.Fatalf("after the last attempt = %v", r)
	}
	if st := workerString(t, s, `select status from jobs where id = $1`, jobID); st != "dead" {
		t.Fatalf("job after the last attempt = %s", st)
	}
	if n := workerCount(t, s, `select count(*) from job_attempts where job_id = $1`, jobID); n != 3 {
		t.Fatalf("attempts = %d", n)
	}
	s.WorkerSvcs.Reports.Store = orig

	// A job that died without its handler finishing (a crashed worker) is swept.
	lost := c.Do(t, http.MethodPost, "/reports", map[string]any{"report_type": "cash_flow", "format": "csv"}).Expect(t, http.StatusAccepted).
		Data()["id"].(string)
	s.Env.ExecWorker(t, `update jobs set status = 'dead', finished_at = now(), last_error_code = 'lease_expired'
		where id = (select job_id from reports where id = $1)`, lost)
	s.Env.ExecWorker(t, `update reports set status = 'running' where id = $1`, lost)
	rfxRunJob(t, s, "reports.schedules")
	if r := c.Do(t, http.MethodGet, "/reports/"+lost, nil).Expect(t, http.StatusOK).Data(); r["status"] != "failed" || r["error_code"] != "generation_failed" {
		t.Fatalf("abandoned report = %v", r)
	}

	// Expiry is derived on read, consistently with the download.
	ok := reportOf(t, s, c, map[string]any{"report_type": "transactions", "format": "csv"})
	okID := ok["id"].(string)
	s.Env.ExecWorker(t, `update reports set expires_at = now() - interval '1 minute' where id = $1`, okID)
	if st := workerString(t, s, `select status from reports where id = $1`, okID); st != "completed" {
		t.Fatalf("stored status = %s", st)
	}
	if r := c.Do(t, http.MethodGet, "/reports/"+okID, nil).Expect(t, http.StatusOK).Data(); r["status"] != "expired" {
		t.Fatalf("get = %v", r["status"])
	}
	for _, x := range c.Do(t, http.MethodGet, "/reports", nil).Expect(t, http.StatusOK).List() {
		if r := x.(map[string]any); r["id"] == okID && r["status"] != "expired" {
			t.Fatalf("list = %v", r["status"])
		}
	}
	if r := c.Do(t, http.MethodGet, "/reports/"+okID+"/download", nil); r.Status != http.StatusGone || r.ErrorCode() != "GONE" {
		t.Fatalf("download = %d %s", r.Status, r.Raw)
	}
}

// PATCH /reports/schedules/{id}: partial edits with a version, pause and
// resume (no back-fill), owner only, audited.
func TestScheduleEditPauseResume(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "schedules"))
	other, _ := s.Login(t, s.Register(t, "schedulesother"))
	ist, _ := time.LoadLocation("Asia/Kolkata")

	sch := c.Do(t, http.MethodPost, "/reports/schedules", map[string]any{"report_type": "monthly_summary", "format": "csv", "cadence": "monthly",
		"filters": map[string]any{"currency": "INR", "range": "last_year"}}).Expect(t, http.StatusCreated).Data()
	id := sch["id"].(string)
	if sch["version"] != float64(1) || sch["enabled"] != true || sch["title"] != "Monthly summary (monthly)" ||
		sch["filters"].(map[string]any)["currency"] != "INR" || sch["filters"].(map[string]any)["range"] != nil {
		t.Fatalf("schedule = %v", sch)
	}
	patch := func(cl *apitest.Client, body map[string]any) *apitest.Response {
		return cl.Do(t, http.MethodPatch, "/reports/schedules/"+id, body)
	}
	p := patch(c, map[string]any{"enabled": false, "version": 1}).Expect(t, http.StatusOK).Data()
	if p["enabled"] != false || p["version"] != float64(2) {
		t.Fatalf("paused = %v", p)
	}
	if r := patch(c, map[string]any{"format": "pdf", "version": 1}); r.Status != http.StatusConflict || r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale version: %d %s", r.Status, r.Raw)
	}
	patch(other, map[string]any{"enabled": true}).Expect(t, http.StatusNotFound)

	// A paused schedule requests nothing when it is due.
	s.Env.ExecWorker(t, `update scheduled_reports set next_run_at = now() - interval '1 minute' where id = $1`, id)
	rfxRunJob(t, s, "reports.schedules")
	if l := c.Do(t, http.MethodGet, "/reports", nil).List(); len(l) != 0 {
		t.Fatalf("a paused schedule ran: %v", l)
	}
	// Resuming starts from the next month (no back-fill).
	p = patch(c, map[string]any{"enabled": true}).Expect(t, http.StatusOK).Data()
	next, _ := time.Parse(time.RFC3339, p["next_run_at"].(string))
	if p["enabled"] != true || p["version"] != float64(3) || !next.After(time.Now()) || next.In(ist).Day() != 1 || next.In(ist).Hour() != 6 {
		t.Fatalf("resumed = %v", p)
	}
	// Partial edit: cadence, format and filters; the default title follows the cadence.
	p = patch(c, map[string]any{"cadence": "weekly", "format": "pdf", "version": 3,
		"filters": map[string]any{"currency": "USD", "include_pending": true, "range": "last_month"}}).Expect(t, http.StatusOK).Data()
	next, _ = time.Parse(time.RFC3339, p["next_run_at"].(string))
	f := p["filters"].(map[string]any)
	if p["cadence"] != "weekly" || p["format"] != "pdf" || p["title"] != "Monthly summary (weekly)" || p["version"] != float64(4) ||
		f["currency"] != "USD" || f["include_pending"] != true || f["range"] != nil ||
		next.In(ist).Weekday() != time.Monday || next.In(ist).Hour() != 6 || !next.After(time.Now()) {
		t.Fatalf("edited = %v", p)
	}
	// A chosen title stays when the cadence changes; an empty one restores the default.
	if p = patch(c, map[string]any{"title": "Board pack"}).Expect(t, http.StatusOK).Data(); p["title"] != "Board pack" {
		t.Fatalf("title = %v", p["title"])
	}
	if p = patch(c, map[string]any{"cadence": "monthly"}).Expect(t, http.StatusOK).Data(); p["title"] != "Board pack" {
		t.Fatalf("title after cadence = %v", p["title"])
	}
	if p = patch(c, map[string]any{"title": " "}).Expect(t, http.StatusOK).Data(); p["title"] != "Monthly summary (monthly)" || p["version"] != float64(7) {
		t.Fatalf("default title = %v", p)
	}
	// Sending the current values changes nothing.
	if p = patch(c, map[string]any{"format": "pdf", "enabled": true}).Expect(t, http.StatusOK).Data(); p["version"] != float64(7) {
		t.Fatalf("no-op patch = %v", p)
	}

	// Income schedules keep to income types.
	inc := c.Do(t, http.MethodPost, "/reports/schedules", map[string]any{"report_type": "income", "format": "csv", "cadence": "weekly"}).
		Expect(t, http.StatusCreated).Data()
	if r := c.Do(t, http.MethodPatch, "/reports/schedules/"+inc["id"].(string), map[string]any{"filters": map[string]any{"types": []string{"refund"}}}); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("income schedule with refund type: %d %s", r.Status, r.Raw)
	}
	c.Do(t, http.MethodPatch, "/reports/schedules/"+inc["id"].(string), map[string]any{"filters": map[string]any{"types": []string{"income"}}}).
		Expect(t, http.StatusOK)
	if l := c.Do(t, http.MethodGet, "/reports/schedules", nil).Expect(t, http.StatusOK).List(); len(l) != 2 {
		t.Fatalf("schedules = %v", l)
	}

	// The next run uses the edited settings.
	s.Env.ExecWorker(t, `update scheduled_reports set next_run_at = now() - interval '1 minute' where id = $1`, id)
	rfxRunJob(t, s, "reports.schedules")
	l := c.Do(t, http.MethodGet, "/reports", nil).List()
	if len(l) != 1 {
		t.Fatalf("reports = %v", l)
	}
	rep := l[0].(map[string]any)
	rf := rep["filters"].(map[string]any)
	if rep["format"] != "pdf" || rep["title"] != "Monthly summary (monthly)" || rf["range"] != "last_month" || rf["currency"] != "USD" ||
		rf["include_pending"] != true || rep["status"] != "completed" || rep["window"] == nil {
		t.Fatalf("scheduled report = %v", rep)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'scheduled_report' and entity_id = $1
		and action in ('paused','resumed','updated')`, id); n != 6 {
		t.Fatalf("schedule audit events = %d", n)
	}
}

// A bare as_of date is the start of that day in the user's time zone:
// today is never "in the future", and in UTC+13 the rate stays on its day.
func TestManualRateDateUsesTheUsersZone(t *testing.T) {
	s := apitest.New(t, nil)
	india, _ := s.Login(t, s.Register(t, "fxindia"))
	tongaEmail := s.Register(t, "fxtonga")
	tonga, _ := s.Login(t, tongaEmail)
	s.Env.ExecWorker(t, `update user_preferences set timezone = 'Pacific/Tongatapu' where user_id = $1`, userID(t, s, tongaEmail))
	set := func(c *apitest.Client, base, quote, rate, asOf string) *apitest.Response {
		return c.Do(t, http.MethodPost, "/fx/rates", map[string]any{"base": base, "quote": quote, "rate": rate, "as_of": asOf})
	}

	// 02:00 UTC on 5 November: 07:30 in India, 15:00 in Tonga.
	s.Svcs.FX.Now = func() time.Time { return time.Date(2026, 11, 5, 2, 0, 0, 0, time.UTC) }
	r := set(india, "CHF", "SEK", "11.123400", "2026-11-05").Expect(t, http.StatusCreated).Data()
	if r["rate"] != "11.1234" || !sameInstant(t, "2026-11-04T18:30:00Z", r["as_of"]) || r["source"] != "manual" || r["mine"] != true {
		t.Fatalf("India today = %v", r)
	}
	if r := set(india, "CHF", "SEK", "11.2", "2026-11-06"); r.Status != http.StatusUnprocessableEntity || detail(t, r)["field"] != "body.as_of" {
		t.Fatalf("India tomorrow: %d %s", r.Status, r.Raw)
	}
	if r := set(india, "CHF", "SEK", "12.000", "2026-11-01T10:00:00+05:30").Expect(t, http.StatusCreated).Data(); r["rate"] != "12" ||
		!sameInstant(t, "2026-11-01T04:30:00Z", r["as_of"]) {
		t.Fatalf("RFC 3339 = %v", r)
	}
	if r := set(india, "CHF", "SEK", "abc", "2026-11-01"); r.Status != http.StatusUnprocessableEntity || detail(t, r)["field"] != "body.rate" {
		t.Fatalf("bad rate: %d %s", r.Status, r.Raw)
	}
	if r := set(india, "CHF", "SEK", "11", "05/11/2026"); r.Status != http.StatusUnprocessableEntity || detail(t, r)["field"] != "body.as_of" {
		t.Fatalf("bad date: %d %s", r.Status, r.Raw)
	}
	plain := regexp.MustCompile(`^(0|[1-9]\d*)(\.\d*[1-9])?$`)
	rates := india.Do(t, http.MethodGet, "/fx/rates?base=CHF", nil).Expect(t, http.StatusOK).List()
	if len(rates) == 0 {
		t.Fatal("no rates listed")
	}
	for _, x := range rates {
		if v := x.(map[string]any)["rate"].(string); !plain.MatchString(v) {
			t.Errorf("listed rate %q keeps padding", v)
		}
	}

	// UTC+13: the date is not pushed onto the next local day.
	r = set(tonga, "NZD", "SEK", "6.500000000000", "2026-11-05").Expect(t, http.StatusCreated).Data()
	if r["rate"] != "6.5" || !sameInstant(t, "2026-11-04T11:00:00Z", r["as_of"]) {
		t.Fatalf("Tonga today = %v", r)
	}
	conv := tonga.Do(t, http.MethodGet, "/fx/convert?amount=10&from=NZD&to=SEK&policy=historical&date=2026-11-05", nil).Expect(t, http.StatusOK).Data()
	if money(conv, "to") != "65.00" || conv["rate"].(map[string]any)["rate"] != "6.5" {
		t.Fatalf("conversion dated that day = %v", conv)
	}
	if r := tonga.Do(t, http.MethodGet, "/fx/convert?amount=10&from=NZD&to=SEK&policy=historical&date=2026-11-04", nil); r.ErrorCode() != "NOT_FOUND" {
		t.Fatalf("the rate applied to the previous day: %s", r.Raw)
	}
	// Late in the UTC day it is already tomorrow in Tonga, not in India.
	s.Svcs.FX.Now = func() time.Time { return time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC) }
	if r := set(tonga, "NZD", "SEK", "6.6", "2026-11-06").Expect(t, http.StatusCreated).Data(); !sameInstant(t, "2026-11-05T11:00:00Z", r["as_of"]) {
		t.Fatalf("Tonga's today = %v", r)
	}
	if r := set(india, "NZD", "SEK", "6.6", "2026-11-06"); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("India's tomorrow: %d %s", r.Status, r.Raw)
	}
}

// Compare: per-metric changes per currency and note codes. Cash flow: the
// previous window and the rate policy as data. Merchants: ranked and limited
// per currency. Categories: income by category.
func TestAnalyticsComparisonsBreakdownsAndDisclosures(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "analyticsfixes"))
	inr := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "100000"})["id"].(string)
	usd := createAccount(t, c, map[string]any{"name": "Card", "account_type": "bank", "currency": "USD", "opening_balance": "1000"})["id"].(string)
	dining, groceries := categoryID(t, c, "Food & dining"), categoryID(t, c, "Groceries")
	salary, freelance := categoryID(t, c, "Salary"), categoryID(t, c, "Freelance income")
	tx := func(typ, acct, amount, date string, extra map[string]any) {
		body := map[string]any{"type": typ, "account_id": acct, "amount": amount, "local_date": date}
		for k, v := range extra {
			body[k] = v
		}
		createTx(t, c, body)
	}
	tx("expense", inr, "1000.00", "2026-09-05", map[string]any{"category_id": dining})
	tx("expense", inr, "2000.00", "2026-09-10", map[string]any{"category_id": groceries})
	tx("expense", usd, "10.00", "2026-09-12", map[string]any{"category_id": groceries})
	tx("expense", inr, "1600.00", "2026-10-05", map[string]any{"category_id": dining})
	tx("expense", inr, "1900.00", "2026-10-10", map[string]any{"category_id": groceries})
	tx("expense", usd, "25.00", "2026-10-12", map[string]any{"category_id": groceries})
	tx("income", inr, "40000.00", "2026-10-01", map[string]any{"category_id": salary})
	tx("income", inr, "2500.00", "2026-10-20", map[string]any{"category_id": freelance})
	tx("expense", inr, "75.00", "2026-07-20", map[string]any{"status": "pending"})

	cmp := c.Do(t, http.MethodGet, "/analytics/compare?from=2026-10-01&to=2026-10-31&compare_from=2026-09-01&compare_to=2026-09-30", nil).
		Expect(t, http.StatusOK).Data()
	if !slices.Equal(strList(cmp["note_codes"]), []string{"same_filters_and_rules", "compared_as_totals", "currencies_separate"}) || len(cmp["notes"].([]any)) != 3 {
		t.Fatalf("notes = %v / %v", cmp["notes"], cmp["note_codes"])
	}
	curs := cmp["currencies"].([]any)
	if len(curs) != 2 {
		t.Fatalf("currencies = %v", curs)
	}
	metric := func(cur map[string]any, name string) (string, any) {
		m := cur["change"].(map[string]any)[name].(map[string]any)
		return m["change"].(map[string]any)["amount"].(string) + " " + m["change"].(map[string]any)["currency"].(string), m["change_bp"]
	}
	in, us := curs[0].(map[string]any), curs[1].(map[string]any)
	for _, tc := range []struct {
		cur    map[string]any
		metric string
		change string
		bp     any
	}{
		{in, "income", "42500.00 INR", nil},
		{in, "gross_expense", "500.00 INR", float64(1667)},
		{in, "refunds", "0.00 INR", nil},
		{in, "net_expense", "500.00 INR", float64(1667)},
		{in, "net_cash_flow", "42000.00 INR", float64(140000)}, // 39000.00 against -3000.00
		{us, "net_expense", "15.00 USD", float64(15000)},
		{us, "net_cash_flow", "-15.00 USD", float64(-15000)}, // -25.00 against -10.00: a decrease
	} {
		if ch, bp := metric(tc.cur, tc.metric); ch != tc.change || bp != tc.bp {
			t.Errorf("%s %s = %s %v, want %s %v", tc.cur["currency"], tc.metric, ch, bp, tc.change, tc.bp)
		}
	}
	if in["change"].(map[string]any)["transaction_count"] != float64(2) || us["change"].(map[string]any)["transaction_count"] != float64(0) {
		t.Fatalf("transaction count changes = %v / %v", in["change"], us["change"])
	}

	// Cash flow: the previous window, pending coverage and the rate policy as data.
	setRate(t, c, "USD", "INR", "83.00", time.Date(2026, 10, 15, 0, 0, 0, 0, time.UTC))
	cf := c.Do(t, http.MethodGet, "/analytics/cash-flow?from=2026-10-01&to=2026-10-31&display_currency=INR", nil).Expect(t, http.StatusOK).Data()
	pw := cf["previous_window"].(map[string]any)
	if pw["from"] != "2026-08-31" || pw["to"] != "2026-09-30" || pw["days"] != float64(31) || pw["timezone"] != "Asia/Kolkata" {
		t.Fatalf("previous window = %v", pw)
	}
	conv := cf["converted"].(map[string]any)
	if conv["rate_policy_code"] != "latest_on_or_before" || conv["rate_policy_params"].(map[string]any)["date"] != "2026-10-31" ||
		!strings.Contains(conv["rate_policy"].(string), "2026-10-31") || money(conv, "net_expense") != "5575.00" {
		t.Fatalf("converted = %v", conv)
	}
	if cov := cf["coverage"].(map[string]any); cov["pending_count"] != float64(1) || cov["transaction_count"] != float64(5) {
		t.Fatalf("coverage = %v", cov)
	}

	// Merchants are ranked and limited per currency.
	tx("expense", inr, "5000.00", "2026-08-10", map[string]any{"merchant_name": "Big Bazaar"})
	tx("expense", inr, "4000.00", "2026-08-11", map[string]any{"merchant_name": "Croma"})
	tx("expense", inr, "3000.00", "2026-08-12", map[string]any{"merchant_name": "DMart"})
	tx("expense", usd, "30.00", "2026-08-13", map[string]any{"merchant_name": "Amazon US"})
	tx("expense", usd, "20.00", "2026-08-14", map[string]any{"merchant_name": "Target"})
	ms := c.Do(t, http.MethodGet, "/analytics/merchants?from=2026-08-01&to=2026-08-31&limit=2", nil).Expect(t, http.StatusOK).Data()["merchants"].([]any)
	var got []string
	for _, x := range ms {
		m := x.(map[string]any)
		got = append(got, m["name"].(string)+" "+money(m, "net_expense")+" "+m["currency"].(string))
	}
	if !slices.Equal(got, []string{"Big Bazaar 5000.00 INR", "Croma 4000.00 INR", "Amazon US 30.00 USD", "Target 20.00 USD"}) {
		t.Fatalf("merchants = %v", got)
	}

	// Income by category, consistent with /analytics/income.
	ic := c.Do(t, http.MethodGet, "/analytics/categories?from=2026-10-01&to=2026-10-31&kind=income", nil).Expect(t, http.StatusOK).Data()
	got = nil
	for _, x := range ic["categories"].([]any) {
		m := x.(map[string]any)
		got = append(got, m["name"].(string)+" "+money(m, "amount")+" "+money(m, "net_expense")+" "+jsonNum(m["share_bp"]))
		if !strings.Contains(m["drill_down_path"].(string), "&type=income") {
			t.Errorf("drill down = %v", m["drill_down_path"])
		}
	}
	if ic["kind"] != "income" || !slices.Equal(got, []string{"Salary 40000.00 0.00 9412", "Freelance income 2500.00 0.00 588"}) {
		t.Fatalf("income by category = %v %v", ic["kind"], got)
	}
	totalIncome := c.Do(t, http.MethodGet, "/analytics/income?from=2026-10-01&to=2026-10-31", nil).Expect(t, http.StatusOK).Data()["totals"].([]any)
	if money(totalIncome[0].(map[string]any), "income") != "42500.00" {
		t.Fatalf("income total = %v", totalIncome)
	}
	ec := c.Do(t, http.MethodGet, "/analytics/categories?from=2026-10-01&to=2026-10-31", nil).Expect(t, http.StatusOK).Data()
	got = nil
	for _, x := range ec["categories"].([]any) {
		m := x.(map[string]any)
		got = append(got, m["currency"].(string)+" "+m["name"].(string)+" "+money(m, "amount")+" "+money(m, "net_expense"))
	}
	if ec["kind"] != "expense" || !slices.Equal(got, []string{"INR Groceries 1900.00 1900.00", "INR Food & dining 1600.00 1600.00", "USD Groceries 25.00 25.00"}) {
		t.Fatalf("spending by category = %v %v", ec["kind"], got)
	}
	if r := c.Do(t, http.MethodGet, "/analytics/categories?kind=transfers", nil); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("unknown kind: %d %s", r.Status, r.Raw)
	}
}

func jsonNum(v any) string {
	b, _ := json.Marshal(v)
	return string(b)
}
