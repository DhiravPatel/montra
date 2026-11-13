package api_test

import (
	"context"
	"net/http"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/testutil/apitest"
)

func userID(t *testing.T, s *apitest.Server, email string) uuid.UUID {
	var id uuid.UUID
	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select id from users where email_normalized = $1`, strings.ToLower(email)).Scan(&id)
	}); err != nil {
		t.Fatal(err)
	}
	return id
}

func alertCount(t *testing.T, c *apitest.Client) int {
	return len(c.Do(t, http.MethodGet, "/budget-alerts", nil).Expect(t, http.StatusOK).List())
}

func TestBudgetProgressAlertsDedupeAndRefunds(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "budgeter"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "100000"})["id"].(string)
	savings := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR"})["id"].(string)
	// Threshold alerts only: the forecast alert depends on the day of the
	// month and has its own clock-controlled test.
	b := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Monthly", "budget_type": "total", "period": "monthly",
		"currency": "INR", "limit": "10000", "alert_forecast": false}).Expect(t, http.StatusCreated).Data()
	bid := b["id"].(string)
	exp := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "7600"})
	// Transfers and income never count toward budgets.
	c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": acct, "to_account_id": savings, "amount": "5000"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "50000"})
	s.RunJobs(t)
	got := c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()
	p := got["progress"].(map[string]any)
	if money(p, "spent") != "7600.00" || p["percent_bp"].(float64) != 7600 {
		t.Fatalf("progress = %v", p)
	}
	if n := alertCount(t, c); n != 2 { // 50% and 75%
		t.Fatalf("expected 2 threshold alerts, got %d", n)
	}
	s.RunJobs(t)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "10"}) // re-evaluation, no new threshold
	s.RunJobs(t)
	if n := alertCount(t, c); n != 2 {
		t.Fatalf("alerts must not repeat, got %d", n)
	}
	notes := c.Do(t, http.MethodGet, "/notifications?category=budget", nil).Expect(t, http.StatusOK).List()
	if len(notes) != 2 {
		t.Fatalf("expected 2 budget notifications, got %d", len(notes))
	}
	for _, n := range notes {
		if strings.Contains(n.(map[string]any)["body"].(string), "7600") {
			t.Fatal("notification preview must not include amounts")
		}
	}
	// Refunds restore budget.
	c.Do(t, http.MethodPost, "/transactions/"+exp["id"].(string)+"/refunds", map[string]any{"amount": "2000"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	p = c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Data()["progress"].(map[string]any)
	if money(p, "spent") != "5610.00" {
		t.Fatalf("spent after refund = %v", p["spent"])
	}
	// Snooze/dismiss and optimistic concurrency on edits.
	alerts := c.Do(t, http.MethodGet, "/budget-alerts", nil).List()
	aid := alerts[0].(map[string]any)["id"].(string)
	c.Do(t, http.MethodPatch, "/budget-alerts/"+aid, map[string]any{"status": "dismissed"}).Expect(t, http.StatusOK)
	upd := map[string]any{"name": "Monthly", "budget_type": "total", "period": "monthly", "currency": "INR", "limit": "12000", "version": 99}
	if r := c.Do(t, http.MethodPatch, "/budgets/"+bid, upd); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale budget edit accepted: %s", r.Raw)
	}
	upd["version"] = got["version"]
	c.Do(t, http.MethodPatch, "/budgets/"+bid, upd).Expect(t, http.StatusOK)
	other, _ := s.Login(t, s.Register(t, "budgetsnoop"))
	other.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusNotFound)
}

func TestCategoryBudgetAllocationsAndRollover(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "envelopes"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "100000",
		"opening_date": time.Now().AddDate(0, -3, 0).Format("2006-01-02")})["id"].(string)
	cats := map[string]string{}
	for _, x := range c.Do(t, http.MethodGet, "/categories", nil).List() {
		m := x.(map[string]any)
		if k, ok := m["system_key"].(string); ok {
			cats[k] = m["id"].(string)
		}
	}
	lastMonth := time.Now().AddDate(0, -1, 0)
	start := time.Date(lastMonth.Year(), lastMonth.Month(), 1, 0, 0, 0, 0, time.UTC).Format("2006-01-02")
	b := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Food", "budget_type": "category", "period": "monthly", "currency": "INR",
		"limit": "10000", "rollover_policy": "carry_unused", "starts_on": start,
		"allocations": []any{map[string]any{"category_id": cats["groceries"], "limit": "6000"}, map[string]any{"category_id": cats["food_dining"], "limit": "4000"}}}).
		Expect(t, http.StatusCreated).Data()
	bid := b["id"].(string)
	// Last month: 3000 on groceries → 7000 unused carries over.
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "3000", "category_id": cats["groceries"],
		"local_date": time.Date(lastMonth.Year(), lastMonth.Month(), 10, 0, 0, 0, 0, time.UTC).Format("2006-01-02")})
	// This month: groceries 1000, dining 500, transport (not budgeted) 9999.
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1000", "category_id": cats["groceries"]})
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "500", "category_id": cats["food_dining"]})
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "9999", "category_id": cats["transport"]})
	got := c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()
	p := got["progress"].(map[string]any)
	if money(p, "spent") != "1500.00" || money(p, "rollover_in") != "7000.00" || money(p, "limit") != "17000.00" {
		t.Fatalf("category budget/rollover = %v", p)
	}
	allocs := got["allocations"].([]any)
	if money(allocs[0].(map[string]any), "spent") != "1000.00" || money(allocs[1].(map[string]any), "spent") != "500.00" {
		t.Fatalf("allocation spend = %v", allocs)
	}
	hist := c.Do(t, http.MethodGet, "/budgets/"+bid+"/progress", nil).Expect(t, http.StatusOK).List()
	if len(hist) != 2 || money(hist[1].(map[string]any), "spent") != "3000.00" {
		t.Fatalf("history = %v", hist)
	}
	txs := c.Do(t, http.MethodGet, "/budgets/"+bid+"/transactions", nil).Expect(t, http.StatusOK).List()
	if len(txs) != 2 {
		t.Fatalf("drill-down should list the 2 counted transactions, got %d", len(txs))
	}
}

func TestSharedBudgetMembersSeeTotalsNotTransactions(t *testing.T) {
	s := apitest.New(t, nil)
	ownerAddr := s.Register(t, "sharer")
	mateAddr := s.Register(t, "mate")
	c, _ := s.Login(t, ownerAddr)
	mate, _ := s.Login(t, mateAddr)
	owner, mateID := userID(t, s, ownerAddr), userID(t, s, mateAddr)
	g := uuid.New()
	s.Env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Home','household','INR','Asia/Kolkata')`, g, owner)
	s.Env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, g, owner, mateID)
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	b := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Shared", "budget_type": "total", "period": "monthly", "currency": "INR", "limit": "8000",
		"alert_forecast": false, "visibility": "members", "members": []any{map[string]any{"user_id": mateID, "role": "viewer"}}}).Expect(t, http.StatusCreated).Data()
	bid := b["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "2000", "description": "Private pharmacy purchase"})
	s.RunJobs(t)
	view := mate.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()
	if view["access"] != "viewer" || money(view["progress"].(map[string]any), "spent") != "2000.00" {
		t.Fatalf("member view = %v", view)
	}
	mate.Do(t, http.MethodGet, "/budgets/"+bid+"/transactions", nil).Expect(t, http.StatusForbidden)
	if n := len(mate.Do(t, http.MethodGet, "/transactions?q=pharmacy", nil).List()); n != 0 {
		t.Fatal("budget membership exposed the owner's private transactions")
	}
	// The member received the alert too (deduplicated per recipient).
	if n := alertCount(t, mate); n != 0 {
		t.Fatalf("25%% spend should raise no alert, got %d", n)
	}
	// Members cannot edit (viewer) but can leave.
	upd := map[string]any{"name": "Hijack", "budget_type": "total", "period": "monthly", "currency": "INR", "limit": "1", "version": view["version"]}
	mate.Do(t, http.MethodPatch, "/budgets/"+bid, upd).Expect(t, http.StatusForbidden)
	mate.Do(t, http.MethodDelete, "/budgets/"+bid+"/members/"+mateID.String(), nil).Expect(t, http.StatusOK)
	mate.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusNotFound)
}

// The forecast alert is raised once enough of the period has passed for a
// projection (a fifth of it, at least 3 days) and the pace points over the
// limit; it is never repeated within the period.
func TestBudgetForecastAlertFollowsTheClock(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "forecaster"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "100000"})["id"].(string)
	bid := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Monthly", "budget_type": "total", "period": "monthly", "currency": "INR",
		"limit": "10000", "alert_thresholds": []int{}}).Expect(t, http.StatusCreated).Data()["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "7600"})
	now := time.Now().UTC()
	clock := func(day int) {
		at := func() time.Time { return time.Date(now.Year(), now.Month(), day, 12, 0, 0, 0, time.UTC) }
		s.Svcs.Budgets.Now, s.WorkerSvcs.Budgets.Now = at, at
	}
	progress := func() map[string]any {
		return c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()["progress"].(map[string]any)
	}
	kinds := func() []string {
		var out []string
		for _, a := range c.Do(t, http.MethodGet, "/budget-alerts", nil).Expect(t, http.StatusOK).List() {
			out = append(out, a.(map[string]any)["kind"].(string))
		}
		return out
	}
	// Day 2 of the period: too early to project.
	clock(2)
	s.RunJobs(t)
	if k := kinds(); len(k) != 0 {
		t.Fatalf("forecast raised too early: %v", k)
	}
	// Day 20: 7600 spent of 10000 projects to about 11400 by the month's end.
	clock(20)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1"}) // triggers a re-evaluation
	s.RunJobs(t)
	if k := kinds(); len(k) != 1 || k[0] != "forecast_overspend" {
		t.Fatalf("forecast alert: %v (progress %v)", k, progress())
	}
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1"})
	s.RunJobs(t)
	if k := kinds(); len(k) != 1 {
		t.Fatalf("forecast alert repeated: %v", k)
	}
}

// Budget alerts page with a cursor through a separate SQL text (query plan
// review R-F); paging returns every alert once, in the unpaged order, with
// and without the budget filter.
func TestBudgetAlertCursorPagingMatchesUnpagedList(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "alertpager"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "100000"})["id"].(string)
	var budgets []string
	for _, name := range []string{"First", "Second"} {
		budgets = append(budgets, c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": name, "budget_type": "total", "period": "monthly",
			"currency": "INR", "limit": "10000", "alert_forecast": false}).Expect(t, http.StatusCreated).Data()["id"].(string))
	}
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "7600"}) // 50% and 75% on both budgets
	s.RunJobs(t)
	for _, path := range []string{"/budget-alerts?status=", "/budget-alerts?budget_id=" + budgets[1]} {
		all := ids(c.Do(t, http.MethodGet, path+"&limit=100", nil).Expect(t, http.StatusOK).List(), "id")
		want := 4
		if strings.Contains(path, "budget_id") {
			want = 2
		}
		if len(all) != want {
			t.Fatalf("%s listed %d alerts, want %d", path, len(all), want)
		}
		for _, size := range []int{1, 3} {
			if got := pageAll(t, c, path, size); !slices.Equal(got, all) {
				t.Fatalf("%s paged by %d = %v, want %v", path, size, got, all)
			}
		}
	}
}
