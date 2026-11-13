package api_test

import (
	"net/http"
	"testing"
	"time"

	"montra/backend/internal/testutil/apitest"
)

// BUD-011 boundary tests: budget periods across a change of the user's
// time zone, and edits that move spend between budgets and periods.

// cvClock pins the API's finance and budget clocks to an instant.
func cvClock(t *testing.T, s *apitest.Server, at time.Time) {
	t.Helper()
	now := func() time.Time { return at }
	s.Svcs.Finance.Now, s.Svcs.Budgets.Now = now, now
	t.Cleanup(func() { s.Svcs.Finance.Now, s.Svcs.Budgets.Now = nil, nil })
}

func cvProgress(t *testing.T, c *apitest.Client, bid string) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()["progress"].(map[string]any)
}

// cvPeriod returns the progress of the period containing date.
func cvPeriod(t *testing.T, c *apitest.Client, bid, date string) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodGet, "/budgets/"+bid+"/progress?date="+date, nil).Expect(t, http.StatusOK).List()[0].(map[string]any)
}

func cvAllocSpent(t *testing.T, c *apitest.Client, bid, cat string) string {
	t.Helper()
	for _, x := range c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()["allocations"].([]any) {
		if a := x.(map[string]any); a["category_id"] == cat {
			return money(a, "spent")
		}
	}
	t.Fatalf("no allocation for %s", cat)
	return ""
}

// The instant 2026-10-31 20:00 UTC is already 1 November in India
// (UTC+5:30) but still 31 October in New York (UTC-4).
func TestCoverageBudgetPeriodsAcrossUserTimeZoneChange(t *testing.T) {
	s := apitest.New(t, nil)
	cvClock(t, s, time.Date(2026, 10, 31, 20, 0, 0, 0, time.UTC))
	c, _ := s.Login(t, s.Register(t, "cvbudtz"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000",
		"opening_date": "2026-09-01"})["id"].(string)
	b := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Monthly", "budget_type": "total", "period": "monthly", "currency": "INR",
		"limit": "3100", "starts_on": "2026-09-01", "alert_forecast": false, "alert_thresholds": []int{}}).Expect(t, http.StatusCreated).Data()
	bid := b["id"].(string)
	if b["timezone"] != "Asia/Kolkata" {
		t.Fatalf("budget time zone defaults to the user's: %v", b["timezone"])
	}
	// Created in India: no date means today there (1 November).
	nov := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "100", "description": "Nov 1 in India"})
	if nov["local_date"] != "2026-11-01" {
		t.Fatalf("local date in India = %v", nov["local_date"])
	}
	oct := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "40", "local_date": "2026-10-31", "description": "Oct 31"})
	p := cvProgress(t, c, bid)
	if p["period_start"] != "2026-11-01" || p["period_end"] != "2026-11-30" || money(p, "spent") != "100.00" ||
		p["elapsed_days"] != float64(1) || p["total_days"] != float64(30) {
		t.Fatalf("November in India = %v", p)
	}

	// The user moves to New York. Recorded transactions keep their dates
	// and the budget keeps the zone it was created in, so its periods do
	// not shift under existing spend.
	prefs := c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"timezone": "America/New_York"}).Expect(t, http.StatusOK).Data()
	if prefs["timezone"] != "America/New_York" {
		t.Fatalf("preferences = %v", prefs)
	}
	if g := c.Do(t, http.MethodGet, "/transactions/"+nov["id"].(string), nil).Expect(t, http.StatusOK).Data(); g["local_date"] != "2026-11-01" {
		t.Fatalf("a time zone change rewrote a transaction date: %v", g["local_date"])
	}
	got := c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()
	if got["timezone"] != "Asia/Kolkata" || got["progress"].(map[string]any)["period_start"] != "2026-11-01" {
		t.Fatalf("budget after the user's move = %v %v", got["timezone"], got["progress"])
	}
	// New transactions now default to the new local date (31 October).
	ny := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "7", "description": "Oct 31 in New York"})
	if ny["local_date"] != "2026-10-31" || ny["timezone"] != "America/New_York" {
		t.Fatalf("new transaction after the move = %v %v", ny["local_date"], ny["timezone"])
	}
	if p := cvPeriod(t, c, bid, "2026-10-31"); p["period_start"] != "2026-10-01" || money(p, "spent") != "47.00" {
		t.Fatalf("October after the move = %v", p)
	}

	// Moving the budget to the new zone recomputes which period is current
	// and how much of it has elapsed; spend per period is unchanged.
	upd := c.Do(t, http.MethodPatch, "/budgets/"+bid, map[string]any{"timezone": "America/New_York", "version": got["version"]}).Expect(t, http.StatusOK).Data()
	p = upd["progress"].(map[string]any)
	if upd["timezone"] != "America/New_York" || p["period_start"] != "2026-10-01" || p["period_end"] != "2026-10-31" ||
		money(p, "spent") != "47.00" || p["elapsed_days"] != float64(31) || p["total_days"] != float64(31) {
		t.Fatalf("budget in New York = %v %v", upd["timezone"], p)
	}
	hist := c.Do(t, http.MethodGet, "/budgets/"+bid+"/progress", nil).Expect(t, http.StatusOK).List()
	if prev := hist[1].(map[string]any); prev["period_start"] != "2026-09-01" || money(prev, "spent") != "0.00" {
		t.Fatalf("previous period = %v", prev)
	}
	if p := cvPeriod(t, c, bid, "2026-11-01"); money(p, "spent") != "100.00" {
		t.Fatalf("November after the budget moved = %v", p)
	}
	listed := c.Do(t, http.MethodGet, "/budgets/"+bid+"/transactions", nil).Expect(t, http.StatusOK).List()
	if !slicesEqualSet(ids(listed, "id"), []string{ny["id"].(string), oct["id"].(string)}) {
		t.Fatalf("current period transactions = %v", listed)
	}
	// A budget created after the move starts in the new zone.
	b2 := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Weekly", "budget_type": "total", "period": "weekly", "currency": "INR",
		"limit": "700", "alert_forecast": false, "alert_thresholds": []int{}}).Expect(t, http.StatusCreated).Data()
	if b2["timezone"] != "America/New_York" || b2["starts_on"] != "2026-10-31" {
		t.Fatalf("budget created after the move = %v %v", b2["timezone"], b2["starts_on"])
	}
	gfField(t, c.Do(t, http.MethodPatch, "/budgets/"+bid, map[string]any{"timezone": "Mars/Olympus", "version": upd["version"]}), "body.timezone")
}

func TestCoverageBudgetTransactionEditsMoveSpendExactly(t *testing.T) {
	s := apitest.New(t, nil)
	cvClock(t, s, time.Date(2026, 10, 20, 6, 0, 0, 0, time.UTC))
	c, _ := s.Login(t, s.Register(t, "cvbudedit"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000",
		"opening_date": "2026-08-01"})["id"].(string)
	groceries, dining, transport := categoryKey(t, c, "groceries"), categoryKey(t, c, "food_dining"), categoryKey(t, c, "transport")
	quiet := map[string]any{"alert_forecast": false, "alert_thresholds": []int{}}
	mk := func(body map[string]any) string {
		for k, v := range quiet {
			body[k] = v
		}
		body["period"], body["currency"], body["starts_on"] = "monthly", "INR", "2026-08-01"
		return c.Do(t, http.MethodPost, "/budgets", body).Expect(t, http.StatusCreated).Data()["id"].(string)
	}
	food := mk(map[string]any{"name": "Food", "budget_type": "category", "limit": "10000",
		"allocations": []any{map[string]any{"category_id": groceries, "limit": "6000"}, map[string]any{"category_id": dining, "limit": "4000"}}})
	travel := mk(map[string]any{"name": "Travel", "budget_type": "category", "limit": "5000",
		"allocations": []any{map[string]any{"category_id": transport, "limit": "5000"}}})
	total := mk(map[string]any{"name": "Everything", "budget_type": "total", "limit": "20000"})
	other := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "250", "category_id": groceries, "local_date": "2026-10-02"})
	tx := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1000", "category_id": groceries, "local_date": "2026-10-05"})
	id := tx["id"].(string)
	version := tx["version"]
	edit := func(body map[string]any) {
		t.Helper()
		body["version"] = version
		version = c.Do(t, http.MethodPatch, "/transactions/"+id, body).Expect(t, http.StatusOK).Data()["version"]
	}
	type want struct{ budget, date, spent string }
	check := func(step string, ws ...want) {
		t.Helper()
		for _, w := range ws {
			if p := cvPeriod(t, c, w.budget, w.date); money(p, "spent") != w.spent {
				t.Fatalf("%s: spent in the period of %s = %s, want %s (%v)", step, w.date, money(p, "spent"), w.spent, p)
			}
		}
	}
	check("start", want{food, "2026-10-20", "1250.00"}, want{total, "2026-10-20", "1250.00"}, want{travel, "2026-10-20", "0.00"})
	if g := cvAllocSpent(t, c, food, groceries); g != "1250.00" {
		t.Fatalf("groceries allocation = %s", g)
	}

	// Amount: the difference moves, nothing else.
	edit(map[string]any{"amount": "1500.75"})
	check("amount", want{food, "2026-10-20", "1750.75"}, want{total, "2026-10-20", "1750.75"}, want{travel, "2026-10-20", "0.00"})
	if g, d := cvAllocSpent(t, c, food, groceries), cvAllocSpent(t, c, food, dining); g != "1750.75" || d != "0.00" {
		t.Fatalf("allocations after the amount edit = %s / %s", g, d)
	}
	// Category inside the same budget: between allocations, total unchanged.
	edit(map[string]any{"category_id": dining})
	check("category within budget", want{food, "2026-10-20", "1750.75"}, want{total, "2026-10-20", "1750.75"})
	if g, d := cvAllocSpent(t, c, food, groceries), cvAllocSpent(t, c, food, dining); g != "250.00" || d != "1500.75" {
		t.Fatalf("allocations after the category edit = %s / %s", g, d)
	}
	// Category into another budget: leaves Food, enters Travel.
	edit(map[string]any{"category_id": transport})
	check("category across budgets", want{food, "2026-10-20", "250.00"}, want{travel, "2026-10-20", "1500.75"}, want{total, "2026-10-20", "1750.75"})
	// Date into the previous month: leaves October, enters September, in
	// every budget that counts it.
	edit(map[string]any{"local_date": "2026-09-30"})
	check("date", want{travel, "2026-10-20", "0.00"}, want{travel, "2026-09-30", "1500.75"}, want{total, "2026-10-20", "250.00"},
		want{total, "2026-09-01", "1500.75"}, want{food, "2026-09-15", "0.00"})
	hist := c.Do(t, http.MethodGet, "/budgets/"+total+"/progress", nil).Expect(t, http.StatusOK).List()
	if cur, prev := hist[0].(map[string]any), hist[1].(map[string]any); prev["period_start"] != "2026-09-01" || money(prev, "spent") != "1500.75" ||
		money(cur, "spent") != "250.00" {
		t.Fatalf("progress history after the date edit = %v", hist)
	}
	// Drill-downs list exactly what each period counts.
	if l := c.Do(t, http.MethodGet, "/budgets/"+travel+"/transactions?date=2026-09-10", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != id {
		t.Fatalf("travel September transactions = %v", l)
	}
	if l := c.Do(t, http.MethodGet, "/budgets/"+total+"/transactions", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != other["id"] {
		t.Fatalf("total October transactions = %v", l)
	}
	// All three at once back to the start: everything returns exactly.
	edit(map[string]any{"amount": "1000", "category_id": groceries, "local_date": "2026-10-05"})
	check("revert", want{food, "2026-10-20", "1250.00"}, want{total, "2026-10-20", "1250.00"}, want{travel, "2026-10-20", "0.00"},
		want{travel, "2026-09-30", "0.00"}, want{total, "2026-09-30", "0.00"})
	// A stale version changes nothing.
	r := c.Do(t, http.MethodPatch, "/transactions/"+id, map[string]any{"amount": "9999", "version": tx["version"]})
	if r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale edit: %s", r.Raw)
	}
	check("stale edit", want{food, "2026-10-20", "1250.00"})
	// Deleting and restoring moves the spend out and back.
	c.Do(t, http.MethodDelete, "/transactions/"+id, nil).Expect(t, http.StatusOK)
	check("deleted", want{food, "2026-10-20", "250.00"}, want{total, "2026-10-20", "250.00"})
	c.Do(t, http.MethodPost, "/transactions/"+id+"/restore", nil).Expect(t, http.StatusOK)
	check("restored", want{food, "2026-10-20", "1250.00"}, want{total, "2026-10-20", "1250.00"})
}

func categoryKey(t *testing.T, c *apitest.Client, systemKey string) string {
	t.Helper()
	for _, x := range c.Do(t, http.MethodGet, "/categories", nil).Expect(t, http.StatusOK).List() {
		if m := x.(map[string]any); m["system_key"] == systemKey {
			return m["id"].(string)
		}
	}
	t.Fatalf("no starter category %s", systemKey)
	return ""
}

func slicesEqualSet(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for _, x := range a {
		if !contains(b, x) {
			return false
		}
	}
	return true
}
