package api_test

import (
	"net/http"
	"testing"
	"time"

	"montra/backend/internal/testutil/apitest"
)

func categoryID(t *testing.T, c *apitest.Client, name string) string {
	t.Helper()
	for _, x := range c.Do(t, http.MethodGet, "/categories", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["name"] == name {
			return x.(map[string]any)["id"].(string)
		}
	}
	t.Fatalf("no category %s", name)
	return ""
}

// Unusual frequency, recurring amount drift and repeated budget overspend
// (spec §4.13): thresholds, false-positive controls and deduplication.
func TestInsightFrequencyRecurringDriftAndRepeatedOverspend(t *testing.T) {
	s := apitest.New(t, nil)
	today := todayIn(t, "Asia/Kolkata")
	at := func(daysAgo int) string { return today.AddDate(0, 0, -daysAgo).Format(day) }

	// Frequency: 4 purchases this week at a merchant visited about every
	// two weeks is unusual; the same at a twice-a-week merchant is not, and
	// a merchant with little history is never judged.
	f, _ := s.Login(t, s.Register(t, "frequent"))
	acct := createAccount(t, f, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	buy := func(merchant string, daysAgo int) string {
		return createTx(t, f, map[string]any{"type": "expense", "account_id": acct, "amount": "120.00", "merchant_name": merchant,
			"local_date": at(daysAgo)})["id"].(string)
	}
	// Older history is cloned in SQL from one API-created purchase per
	// merchant (the per-user write rate limit would otherwise trip); rules
	// read transactions only.
	history := func(merchant string, first, every, count int) {
		tmpl := buy(merchant, first)
		for i := 1; i < count; i++ {
			s.Env.ExecWorker(t, `insert into transactions (id, user_id, account_id, type, direction, status, amount_minor, currency, occurred_at,
				local_date, timezone, posted_at, merchant_id, description, source)
				select gen_random_uuid(), user_id, account_id, type, direction, status, amount_minor, currency, occurred_at - make_interval(days => $2),
				local_date - $2::int, timezone, posted_at, merchant_id, description, source from transactions where id = $1`, tmpl, i*every)
		}
	}
	history("Chai Point", 10, 12, 6) // ~0.5 a week
	history("Daily Bread", 8, 3, 24) // ~2 a week
	history("Rare Shop", 20, 15, 3)  // too little history
	for i := 0; i < 4; i++ {
		buy("Chai Point", i)
		buy("Daily Bread", i)
	}
	for i := 0; i < 5; i++ {
		buy("Rare Shop", i)
	}
	st := subtypes(t, f)
	if st["unusual_frequency"] != 1 {
		t.Fatalf("frequency insights: %v", st)
	}
	var ev map[string]any
	for _, x := range f.Do(t, http.MethodGet, "/insights?kind=anomaly", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["subtype"] == "unusual_frequency" {
			ev = x.(map[string]any)["evidence"].(map[string]any)
		}
	}
	if ev == nil || ev["recent_count"].(float64) != 4 || ev["baseline_count"].(float64) != 6 || ev["baseline_weekly_average"] != "0.5" {
		t.Fatalf("frequency evidence: %v", ev)
	}
	if st := subtypes(t, f); st["unusual_frequency"] != 1 { // the list holds active insights; a rerun adds no duplicate
		t.Fatalf("frequency insight repeated in the same week: %v", st)
	}

	// Recurring drift: a 30% higher latest payment is flagged; a 5% change
	// and variable-amount rules are not.
	r, _ := s.Login(t, s.Register(t, "recurring"))
	racct := createAccount(t, r, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	rule := func(name string, variable bool) string {
		body := map[string]any{"kind": "expense", "name": name, "frequency": "monthly", "start_date": at(120), "timezone": "Asia/Kolkata",
			"local_time": "09:00", "amount": "499.00", "account_id": racct, "auto_post": false, "amount_is_variable": variable}
		return r.Do(t, http.MethodPost, "/recurring-rules", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()["id"].(string)
	}
	link := func(ruleID, amount string, daysAgo int) {
		id := createTx(t, r, map[string]any{"type": "expense", "account_id": racct, "amount": amount, "description": "payment", "local_date": at(daysAgo)})["id"].(string)
		s.Env.ExecWorker(t, `update transactions set recurring_rule_id = $1 where id = $2`, ruleID, id)
	}
	tv, broadband, power := rule("Streaming TV", false), rule("Broadband", false), rule("Electricity", true)
	for _, ago := range []int{95, 65, 35} {
		link(tv, "499.00", ago)
		link(broadband, "499.00", ago)
		link(power, "499.00", ago)
	}
	link(tv, "649.00", 3)
	link(broadband, "524.00", 3)
	link(power, "900.00", 3)
	st = subtypes(t, r)
	if st["recurring_amount_change"] != 1 {
		t.Fatalf("recurring drift insights: %v", st)
	}
	for _, x := range r.Do(t, http.MethodGet, "/insights?kind=anomaly", nil).Expect(t, http.StatusOK).List() {
		m := x.(map[string]any)
		if m["subtype"] == "recurring_amount_change" {
			e := m["evidence"].(map[string]any)
			if e["recurring_rule_id"] != tv || e["change_percent"] != "+30.1" || e["history_count"].(float64) != 3 {
				t.Fatalf("drift evidence: %v", e)
			}
		}
	}

	// Repeated overspend: over the limit in 2 of the last 3 closed months
	// produces one savings suggestion with its numbers; once is not enough.
	o, _ := s.Login(t, s.Register(t, "overspend"))
	oacct := createAccount(t, o, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	dining, groceries := categoryID(t, o, "Food & dining"), categoryID(t, o, "Groceries")
	monthStart := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
	budget := func(name, cat string) {
		o.Do(t, http.MethodPost, "/budgets", map[string]any{"name": name, "budget_type": "category", "period": "monthly", "currency": "INR",
			"limit": "1000", "starts_on": monthStart.AddDate(0, -4, 0).Format(day),
			"allocations": []any{map[string]any{"category_id": cat, "limit": "1000"}}}).Expect(t, http.StatusCreated)
	}
	budget("Dining out", dining)
	budget("Groceries", groceries)
	spend := func(cat, amount string, monthsAgo int) {
		createTx(t, o, map[string]any{"type": "expense", "account_id": oacct, "amount": amount, "category_id": cat,
			"local_date": monthStart.AddDate(0, -monthsAgo, 9).Format(day)})
	}
	spend(dining, "1500.00", 1)
	spend(dining, "1300.00", 2)
	spend(dining, "500.00", 3)
	spend(groceries, "1200.00", 1)
	spend(groceries, "700.00", 2)
	st = subtypes(t, o)
	if st["repeated_budget_overspend"] != 1 {
		t.Fatalf("overspend suggestions: %v", st)
	}
	for _, x := range o.Do(t, http.MethodGet, "/insights?kind=savings", nil).Expect(t, http.StatusOK).List() {
		m := x.(map[string]any)
		if m["subtype"] != "repeated_budget_overspend" {
			continue
		}
		e := m["evidence"].(map[string]any)
		if e["over_count"].(float64) != 2 || len(e["periods"].([]any)) != 3 || e["average_spent"] != "1100.00 INR" || e["average_overspend"] != "400.00 INR" {
			t.Fatalf("overspend evidence: %v", e)
		}
	}
}

// Comparing two user-selected periods uses the same rules as the dashboard
// and orders categories by the size of the change (spec §4.13).
func TestComparePeriods(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "compare"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	dining, groceries := categoryID(t, c, "Food & dining"), categoryID(t, c, "Groceries")
	spend := func(cat, amount, date string) {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": amount, "category_id": cat, "local_date": date})
	}
	spend(dining, "1000.00", "2026-09-05")
	spend(groceries, "2000.00", "2026-09-10")
	spend(dining, "1600.00", "2026-10-05")
	spend(groceries, "1900.00", "2026-10-10")
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "40000.00", "local_date": "2026-10-01"})

	r := c.Do(t, http.MethodGet, "/analytics/compare?from=2026-10-01&to=2026-10-31&compare_from=2026-09-01&compare_to=2026-09-30", nil).
		Expect(t, http.StatusOK).Data()
	cur := r["currencies"].([]any)[0].(map[string]any)
	if cur["current"].(map[string]any)["net_expense"].(map[string]any)["amount"] != "3500.00" ||
		cur["comparison"].(map[string]any)["net_expense"].(map[string]any)["amount"] != "3000.00" {
		t.Fatalf("totals: %v", cur)
	}
	cats := cur["categories"].([]any)
	first := cats[0].(map[string]any)
	if first["system_key"] != "food_dining" || first["change"].(map[string]any)["amount"] != "600.00" || first["change_bp"].(float64) != 6000 {
		t.Fatalf("largest change first: %v", first)
	}
	second := cats[1].(map[string]any)
	if second["change"].(map[string]any)["amount"] != "-100.00" || second["change_bp"].(float64) != -500 {
		t.Fatalf("decrease: %v", second)
	}
	c.Do(t, http.MethodGet, "/analytics/compare?from=2026-10-01&to=2026-10-31", nil).Expect(t, http.StatusUnprocessableEntity)
}
