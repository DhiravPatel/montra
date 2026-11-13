package api_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/testutil/apitest"
)

func pmSlices(t *testing.T, c *apitest.Client, query string) []map[string]any {
	t.Helper()
	d := c.Do(t, http.MethodGet, "/analytics/payment-methods"+query, nil).Expect(t, http.StatusOK).Data()
	var out []map[string]any
	for _, x := range d["payment_methods"].([]any) {
		out = append(out, x.(map[string]any))
	}
	return out
}

func pmSlice(list []map[string]any, cur, key string) map[string]any {
	for _, x := range list {
		if x["currency"] == cur && x["key"] == key {
			return x
		}
	}
	return nil
}

// GET /analytics/payment-methods (ANL-002): net spending per payment
// method in exact minor units, per currency, with an unspecified bucket,
// the analytics window and filters, and nobody else's data.
func TestAnalyticsPaymentMethodDistribution(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "payer", nil)
	b := newPerson(t, s, "otherpayer", nil)
	a.c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"timezone": "UTC"}).Expect(t, http.StatusOK)
	today := utcToday().Format(day)

	inr := createAccount(t, a.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "100000"})["id"].(string)
	usd := createAccount(t, a.c, map[string]any{"name": "Travel", "account_type": "bank", "currency": "USD", "opening_balance": "1000"})["id"].(string)
	card := a.c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "credit_card", "label": "Rewards card", "network": "visa",
		"masked_hint": "4242"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	upi := a.c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "upi", "label": "UPI"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	old := a.c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "debit_card", "label": "Old debit"}).Expect(t, http.StatusCreated).Data()["id"].(string)

	tx := func(c *apitest.Client, body map[string]any) string {
		body["local_date"] = today
		return createTx(t, c, body)["id"].(string)
	}
	// Card: 1234.56 + 100.01 − 34.57 refund (inherits the card) = 1300.00.
	cardBuy := tx(a.c, map[string]any{"type": "expense", "account_id": inr, "amount": "1234.56", "payment_method_id": card})
	tx(a.c, map[string]any{"type": "expense", "account_id": inr, "amount": "100.01", "payment_method_id": card})
	a.c.Do(t, http.MethodPost, "/transactions/"+cardBuy+"/refunds", map[string]any{"amount": "34.57", "local_date": today},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	// UPI: 500.00 INR and 12.34 USD (kept apart).
	tx(a.c, map[string]any{"type": "expense", "account_id": inr, "amount": "500", "payment_method_id": upi})
	tx(a.c, map[string]any{"type": "expense", "account_id": usd, "amount": "12.34", "payment_method_id": upi})
	// No payment method: 200.00 → unspecified.
	tx(a.c, map[string]any{"type": "expense", "account_id": inr, "amount": "200"})
	// Archived payment method keeps its spending.
	tx(a.c, map[string]any{"type": "expense", "account_id": inr, "amount": "0.01", "payment_method_id": old})
	if r := a.c.Do(t, http.MethodDelete, "/payment-methods/"+old, nil).Expect(t, http.StatusOK).Data(); r["archived"] != true {
		t.Fatalf("delete of a used payment method should archive it: %v", r)
	}
	// Not spending: income, transfers, pending (unless asked) and voided.
	tx(a.c, map[string]any{"type": "income", "account_id": inr, "amount": "9999", "payment_method_id": card})
	a.c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": inr, "to_account_id": usd, "amount": "830",
		"to_amount": "10", "local_date": today}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	tx(a.c, map[string]any{"type": "expense", "account_id": inr, "amount": "77", "payment_method_id": upi, "status": "pending"})
	voided := tx(a.c, map[string]any{"type": "expense", "account_id": inr, "amount": "999", "payment_method_id": card})
	a.c.Do(t, http.MethodDelete, "/transactions/"+voided, nil).Expect(t, http.StatusOK)

	// Someone else's spending, payment methods and labels never appear.
	bInr := createAccount(t, b.c, map[string]any{"name": "B bank", "account_type": "bank", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	bCard := b.c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "credit_card", "label": "Secret card"}).
		Expect(t, http.StatusCreated).Data()["id"].(string)
	tx(b.c, map[string]any{"type": "expense", "account_id": bInr, "amount": "4321", "payment_method_id": bCard})
	tx(b.c, map[string]any{"type": "expense", "account_id": bInr, "amount": "11"})
	// A cannot tag a transaction with B's payment method.
	if r := a.c.Do(t, http.MethodPost, "/transactions", map[string]any{"type": "expense", "account_id": inr, "amount": "1", "payment_method_id": bCard},
		"Idempotency-Key", key()); r.Status < 400 {
		t.Fatalf("another person's payment method was accepted: %s", r.Raw)
	}

	r := a.c.Do(t, http.MethodGet, "/analytics/payment-methods", nil).Expect(t, http.StatusOK)
	if raw := string(r.Raw); strings.Contains(raw, "Secret card") || strings.Contains(raw, bCard) || strings.Contains(raw, "4321") {
		t.Fatalf("another person's data leaked: %s", raw)
	}
	w := r.Data()["window"].(map[string]any)
	if w["timezone"] != "UTC" || w["to"].(string) < today || w["from"].(string) > today {
		t.Fatalf("default window should be this month: %v", w)
	}
	list := pmSlices(t, a.c, "")
	if len(list) != 5 {
		t.Fatalf("slices = %v", list)
	}
	// INR first (alphabetical), largest first; USD separately.
	order := []string{card, upi, "unspecified", old}
	for i, k := range order {
		if list[i]["currency"] != "INR" || list[i]["key"] != k {
			t.Fatalf("INR order at %d = %v (want %s)", i, list[i]["key"], k)
		}
	}
	c := pmSlice(list, "INR", card)
	if money(c, "net_expense") != "1300.00" || c["net_expense"].(map[string]any)["amount_minor"].(float64) != 130000 || c["count"].(float64) != 3 ||
		c["label"] != "Rewards card" || c["kind"] != "credit_card" || c["network"] != "visa" || c["masked_hint"] != "4242" || c["archived"] != false ||
		c["payment_method_id"] != card {
		t.Fatalf("card slice = %v", c)
	}
	un := pmSlice(list, "INR", "unspecified")
	if money(un, "net_expense") != "200.00" || un["kind"] != "unspecified" || un["label"] != "Unspecified" || un["payment_method_id"] != nil ||
		!strings.Contains(un["drill_down_path"].(string), "payment_method_id=none") {
		t.Fatalf("unspecified slice = %v", un)
	}
	// The drill-down lists exactly what was counted: spending without a
	// payment method, never opening balances, transfers or adjustments.
	for _, tx := range a.c.Do(t, http.MethodGet, un["drill_down_path"].(string), nil).Expect(t, http.StatusOK).List() {
		switch ty := tx.(map[string]any)["type"]; ty {
		case "expense", "group_expense", "refund", "reimbursement":
		default:
			t.Fatalf("drill-down lists a %v transaction: %v", ty, tx)
		}
	}
	if o := pmSlice(list, "INR", old); money(o, "net_expense") != "0.01" || o["archived"] != true {
		t.Fatalf("archived slice = %v", o)
	}
	if u := pmSlice(list, "USD", upi); money(u, "net_expense") != "12.34" || u["share_bp"].(float64) != 10000 {
		t.Fatalf("USD slice = %v", u)
	}
	// INR total 2000.01: shares in basis points of that total.
	var shares float64
	for _, x := range list {
		if x["currency"] == "INR" {
			shares += x["share_bp"].(float64)
		}
	}
	if c["share_bp"].(float64) != 6500 || shares < 9999 || shares > 10001 {
		t.Fatalf("shares: card %v, INR total %v", c["share_bp"], shares)
	}

	// The drill-down paths select the counted transactions.
	if l := a.c.Do(t, http.MethodGet, "/transactions?from="+today+"&to="+today+"&currency=INR&payment_method_id=none&type=expense", nil).
		Expect(t, http.StatusOK).List(); len(l) != 1 {
		t.Fatalf("payment_method_id=none listed %d", len(l))
	}

	// Filters: currency, account, pending, and a window without data.
	if l := pmSlices(t, a.c, "?currency=USD"); len(l) != 1 || l[0]["key"] != upi {
		t.Fatalf("currency filter = %v", l)
	}
	if l := pmSlices(t, a.c, "?account_id="+usd); len(l) != 1 || l[0]["currency"] != "USD" {
		t.Fatalf("account filter = %v", l)
	}
	if u := pmSlice(pmSlices(t, a.c, "?include_pending=true"), "INR", upi); money(u, "net_expense") != "577.00" {
		t.Fatalf("include_pending = %v", u)
	}
	if l := pmSlices(t, a.c, "?from=2020-01-01&to=2020-01-31"); len(l) != 0 {
		t.Fatalf("empty window = %v", l)
	}
	if r := a.c.Do(t, http.MethodGet, "/analytics/payment-methods?from=2026-01-01", nil); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("half a custom range: %s", r.Raw)
	}
	// B sees only B's own figures.
	bl := pmSlices(t, b.c, "")
	if len(bl) != 2 || money(pmSlice(bl, "INR", bCard), "net_expense") != "4321.00" || money(pmSlice(bl, "INR", "unspecified"), "net_expense") != "11.00" {
		t.Fatalf("B's slices = %v", bl)
	}
}

// Operator job visibility (JOB-007) and the FX circuit breaker (OPS-003):
// a failing provider opens the breaker, later attempts fail fast with
// provider_circuit_open and the job dies; admins can list it with filters
// and cursor paging, see its attempts (codes only) and retry it once,
// idempotently and audited.
func TestOperatorJobsAndProviderCircuitBreaker(t *testing.T) {
	s := apitest.New(t, nil)
	user := newPerson(t, s, "jobuser", nil)
	support := newPerson(t, s, "jobsupport", nil)
	admin := newPerson(t, s, "jobadmin", nil)
	s.Env.ExecWorker(t, `update users set platform_role = 'support' where id = $1`, support.id)
	s.Env.ExecWorker(t, `update users set platform_role = 'admin' where id = $1`, admin.id)

	var hits atomic.Int32
	ecb := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		hits.Add(1)
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer ecb.Close()
	s.WorkerSvcs.FX.Cfg = config.FXConfig{Provider: "ecb", ECBURL: ecb.URL}

	ctx := context.Background()
	var fxJob uuid.UUID
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var err error
		fxJob, _, err = jobs.Enqueue(ctx, tx, jobs.Spec{Type: "fx.refresh", Payload: map[string]string{"secret": "do-not-show"}})
		return err
	}); err != nil {
		t.Fatal(err)
	}
	s.RunJobs(t) // retries run immediately in tests: 8 attempts, then dead
	// The breaker (5 consecutive failures) stopped the calls to the provider.
	if n := hits.Load(); n != 5 {
		t.Fatalf("provider requests = %d, want 5 (then fail fast)", n)
	}

	// Staff only: users and support staff are refused.
	user.c.Do(t, http.MethodGet, "/admin/jobs", nil).Expect(t, http.StatusForbidden)
	support.c.Do(t, http.MethodGet, "/admin/jobs", nil).Expect(t, http.StatusForbidden)
	support.c.Do(t, http.MethodGet, "/admin/jobs/"+fxJob.String(), nil).Expect(t, http.StatusForbidden)
	support.c.Do(t, http.MethodPost, "/admin/jobs/"+fxJob.String()+"/retry", nil, "Idempotency-Key", key()).Expect(t, http.StatusForbidden)

	dead := admin.c.Do(t, http.MethodGet, "/admin/jobs?status=dead&type=fx.refresh", nil).Expect(t, http.StatusOK)
	if raw := string(dead.Raw); strings.Contains(raw, "do-not-show") || strings.Contains(raw, "payload") || strings.Contains(raw, "ecb status") ||
		strings.Contains(raw, user.id) || strings.Contains(raw, admin.id) {
		t.Fatalf("job list exposes payloads, messages or people: %s", raw)
	}
	l := dead.List()
	if len(l) != 1 {
		t.Fatalf("dead fx jobs = %v", l)
	}
	j := l[0].(map[string]any)
	if j["id"] != fxJob.String() || j["status"] != "dead" || j["attempts"].(float64) != 8 || j["last_error_code"] != "provider_circuit_open" ||
		j["retryable"] != true || j["user_scoped"] != false {
		t.Fatalf("dead job = %v", j)
	}
	detail := admin.c.Do(t, http.MethodGet, "/admin/jobs/"+fxJob.String(), nil).Expect(t, http.StatusOK)
	if strings.Contains(string(detail.Raw), "ecb status") || strings.Contains(string(detail.Raw), "do-not-show") {
		t.Fatalf("job detail exposes messages: %s", detail.Raw)
	}
	atts := detail.Data()["attempts"].([]any)
	if len(atts) != 8 {
		t.Fatalf("attempts = %v", atts)
	}
	for i, x := range atts {
		a := x.(map[string]any)
		wantCode, wantOutcome := "provider_unavailable", "retry"
		if i >= 5 {
			wantCode = "provider_circuit_open"
		}
		if i == 7 {
			wantOutcome = "dead"
		}
		if a["attempt"].(float64) != float64(i+1) || a["error_code"] != wantCode || a["outcome"] != wantOutcome || a["worker_id"] == "" {
			t.Fatalf("attempt %d = %v", i+1, a)
		}
	}
	admin.c.Do(t, http.MethodGet, "/admin/jobs/"+uuid.NewString(), nil).Expect(t, http.StatusNotFound)

	// Filters and cursor paging, over five jobs of a type only this test
	// uses (other tests' jobs share the database).
	const probe = "test.round8_probe"
	for i := 0; i < 5; i++ {
		s.Env.ExecWorker(t, `insert into jobs (type, status, payload, finished_at) values ($1, 'cancelled', '{"secret":"x"}', now())`, probe)
	}
	seen := map[string]bool{}
	cursor, pages := "", 0
	for {
		r := admin.c.Do(t, http.MethodGet, "/admin/jobs?type="+probe+"&limit=2"+cursor, nil).Expect(t, http.StatusOK)
		for _, x := range r.List() {
			m := x.(map[string]any)
			if seen[m["id"].(string)] || m["type"] != probe || m["status"] != "cancelled" || m["retryable"] != false {
				t.Fatalf("page item %v (repeated: %v)", m, seen[m["id"].(string)])
			}
			seen[m["id"].(string)] = true
		}
		pages++
		next, _ := r.Body["meta"].(map[string]any)["next_cursor"].(string)
		if next == "" {
			break
		}
		cursor = "&cursor=" + next
	}
	if len(seen) != 5 || pages != 3 {
		t.Fatalf("paged %d probe jobs in %d pages", len(seen), pages)
	}
	today := utcToday().Format(day)
	if n := len(admin.c.Do(t, http.MethodGet, "/admin/jobs?type="+probe+"&from="+today+"&to="+today, nil).Expect(t, http.StatusOK).List()); n != 5 {
		t.Fatalf("today's probe jobs = %d", n)
	}
	if n := len(admin.c.Do(t, http.MethodGet, "/admin/jobs?type="+probe+"&status=dead", nil).Expect(t, http.StatusOK).List()); n != 0 {
		t.Fatalf("dead probe jobs = %d", n)
	}
	if n := len(admin.c.Do(t, http.MethodGet, "/admin/jobs?from=2020-01-01&to=2020-01-02", nil).Expect(t, http.StatusOK).List()); n != 0 {
		t.Fatalf("jobs in 2020 = %d", n)
	}
	for _, q := range []string{"from=2026-02-30", "from=2026-11-13&to=2026-11-12", "status=lost", "type=Bad%20Type", "cursor=forged"} {
		if r := admin.c.Do(t, http.MethodGet, "/admin/jobs?"+q, nil); r.ErrorCode() != "VALIDATION_ERROR" {
			t.Fatalf("%s: %s", q, r.Raw)
		}
	}

	// Retry: refused for jobs that are not failed or dead (succeeded,
	// cancelled), with the current status.
	ok := admin.c.Do(t, http.MethodGet, "/admin/jobs?status=succeeded&limit=1", nil).Expect(t, http.StatusOK).List()
	if len(ok) != 1 {
		t.Fatal("no succeeded job to test with")
	}
	done := uuid.MustParse(ok[0].(map[string]any)["id"].(string))
	for id := range seen {
		if r := admin.c.Do(t, http.MethodPost, "/admin/jobs/"+id+"/retry", nil, "Idempotency-Key", key()); detailCode(r) != "job_not_retryable" ||
			detailParam(r, "status") != "cancelled" {
			t.Fatalf("retry of a cancelled job: %s", r.Raw)
		}
		break
	}
	r := admin.c.Do(t, http.MethodPost, "/admin/jobs/"+done.String()+"/retry", nil, "Idempotency-Key", key())
	if r.Status != http.StatusUnprocessableEntity || r.ErrorCode() != "DOMAIN_RULE_VIOLATION" || detailCode(r) != "job_not_retryable" ||
		detailParam(r, "status") != "succeeded" {
		t.Fatalf("retry of a succeeded job: %s", r.Raw)
	}
	admin.c.Do(t, http.MethodPost, "/admin/jobs/"+uuid.NewString()+"/retry", nil, "Idempotency-Key", key()).Expect(t, http.StatusNotFound)
	admin.c.Do(t, http.MethodPost, "/admin/jobs/"+fxJob.String()+"/retry", nil).Expect(t, http.StatusUnprocessableEntity) // key required

	k := key()
	first := admin.c.Do(t, http.MethodPost, "/admin/jobs/"+fxJob.String()+"/retry", nil, "Idempotency-Key", k).Expect(t, http.StatusOK)
	q := first.Data()
	if q["status"] != "queued" || q["retryable"] != false || q["max_attempts"].(float64) < 9 || first.Headers.Get("Idempotent-Replayed") != "" {
		t.Fatalf("retried job = %v", q)
	}
	again := admin.c.Do(t, http.MethodPost, "/admin/jobs/"+fxJob.String()+"/retry", nil, "Idempotency-Key", k).Expect(t, http.StatusOK)
	if again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["status"] != "queued" {
		t.Fatalf("replay: %s", again.Raw)
	}
	// A new key while it is queued is refused (no double retry).
	if r := admin.c.Do(t, http.MethodPost, "/admin/jobs/"+fxJob.String()+"/retry", nil, "Idempotency-Key", key()); detailCode(r) != "job_not_retryable" ||
		detailParam(r, "status") != "queued" {
		t.Fatalf("second retry: %s", r.Raw)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'job' and entity_id = $1 and action = 'retried'
		and actor_user_id = $2 and actor_kind = 'admin' and changes->>'from' = 'dead' and changes->>'type' = 'fx.refresh'`, fxJob, admin.id); n != 1 {
		t.Fatalf("retry audit events = %d", n)
	}
	// The provider is still down and the breaker still open: the retried
	// attempt fails fast without a request.
	s.RunJobs(t)
	if hits.Load() != 5 {
		t.Fatalf("retried job reached the provider while the breaker was open: %d", hits.Load())
	}
	if n := workerCount(t, s, `select count(*) from jobs where id = $1 and status = 'dead' and attempts = 9 and last_error_code = 'provider_circuit_open'`, fxJob); n != 1 {
		t.Fatal("retried job did not run once more")
	}
}

func detailCode(r *apitest.Response) string {
	if e, ok := r.Body["error"].(map[string]any); ok {
		if d, ok := e["details"].([]any); ok && len(d) > 0 {
			c, _ := d[0].(map[string]any)["code"].(string)
			return c
		}
	}
	return ""
}

func detailParam(r *apitest.Response, name string) string {
	if e, ok := r.Body["error"].(map[string]any); ok {
		if d, ok := e["details"].([]any); ok && len(d) > 0 {
			if p, ok := d[0].(map[string]any)["params"].(map[string]any); ok {
				v, _ := p[name].(string)
				return v
			}
		}
	}
	return ""
}
