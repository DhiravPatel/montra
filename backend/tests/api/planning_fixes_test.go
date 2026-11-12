package api_test

import (
	"fmt"
	"net/http"
	"slices"
	"strings"
	"testing"

	"github.com/google/uuid"

	"montra/backend/internal/testutil/apitest"
)

// detail returns details[0] of an error response.
func detail(t *testing.T, r *apitest.Response) map[string]any {
	t.Helper()
	e, _ := r.Body["error"].(map[string]any)
	d, _ := e["details"].([]any)
	if len(d) == 0 {
		t.Fatalf("no error details: %d %s", r.Status, r.Raw)
	}
	return d[0].(map[string]any)
}

func strList(v any) []string {
	var out []string
	for _, x := range v.([]any) {
		out = append(out, x.(string))
	}
	return out
}

// Bills: idempotent create, partial updates that keep what was not sent
// (including a postponed payment), explicit lifecycle actions that work even
// when a referenced account was archived, and owner-only access.
func TestBillPartialUpdateLifecycleAndIdempotentCreate(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "billpatch"))
	other, _ := s.Login(t, s.Register(t, "billsnoop"))
	card := createAccount(t, c, map[string]any{"name": "Old card", "account_type": "bank", "currency": "INR"})["id"].(string)
	today := utcToday()
	due := today.AddDate(0, 0, 5)
	body := map[string]any{"name": "Broadband", "provider_name": "FiberNet", "expected_amount": "799", "frequency": "monthly",
		"by_month_day": due.Day(), "start_date": due.Format(day), "timezone": "UTC", "payment_account_id": card}

	// A retried create returns the first bill; the key cannot be reused for
	// a different request, and it is required.
	k := key()
	first := c.Do(t, http.MethodPost, "/bills", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	again := c.Do(t, http.MethodPost, "/bills", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	if again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["id"] != first.Data()["id"] {
		t.Fatalf("bill create replay: %s", again.Raw)
	}
	if n := len(c.Do(t, http.MethodGet, "/bills", nil).Expect(t, http.StatusOK).List()); n != 1 {
		t.Fatalf("a retried create made %d bills", n)
	}
	changed := map[string]any{}
	for k, v := range body {
		changed[k] = v
	}
	changed["name"] = "Something else"
	if r := c.Do(t, http.MethodPost, "/bills", changed, "Idempotency-Key", k); r.ErrorCode() != "IDEMPOTENCY_CONFLICT" {
		t.Fatalf("key reused for another bill: %d %s", r.Status, r.Raw)
	}
	c.Do(t, http.MethodPost, "/bills", body).Expect(t, http.StatusUnprocessableEntity)

	bill := first.Data()
	bid := bill["id"].(string)
	occ := bill["next_due"].(map[string]any)["id"].(string)
	later := due.AddDate(0, 0, 3).Format(day)
	c.Do(t, http.MethodPost, "/recurring-occurrences/"+occ+"/actions", map[string]any{"action": "postpone", "postpone_to": later},
		"Idempotency-Key", key()).Expect(t, http.StatusOK)

	// A rename changes only the name and keeps the postponed payment.
	b := c.Do(t, http.MethodGet, "/bills/"+bid, nil).Expect(t, http.StatusOK).Data()
	b = c.Do(t, http.MethodPatch, "/bills/"+bid, map[string]any{"name": "Home broadband", "version": b["version"]}).Expect(t, http.StatusOK).Data()
	next := b["next_due"].(map[string]any)
	if b["name"] != "Home broadband" || b["provider_name"] != "FiberNet" || money(b, "expected_amount") != "799.00" ||
		b["payment_account_id"] != card || next["id"] != occ || next["postponed_to"] != later {
		t.Fatalf("partial bill update: %v", b)
	}
	// A new expected amount reaches the kept occurrence too.
	b = c.Do(t, http.MethodPatch, "/bills/"+bid, map[string]any{"expected_amount": "849.50", "version": b["version"]}).Expect(t, http.StatusOK).Data()
	if next := b["next_due"].(map[string]any); money(next, "amount") != "849.50" || next["postponed_to"] != later || b["amount_is_variable"] != false {
		t.Fatalf("expected amount update: %v", b)
	}
	// Stale versions are rejected.
	if r := c.Do(t, http.MethodPatch, "/bills/"+bid, map[string]any{"name": "x", "version": 1}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale bill patch: %s", r.Raw)
	}

	// Lifecycle actions only change the status, so an archived payment
	// account does not block them.
	s.Env.ExecWorker(t, `update financial_accounts set status = 'archived' where id = $1`, uuid.MustParse(card))
	b = c.Do(t, http.MethodPost, "/bills/"+bid+"/archive", nil).Expect(t, http.StatusOK).Data()
	if b["status"] != "archived" || b["state"] != "archived" || b["next_due"] != nil {
		t.Fatalf("archive: %v", b)
	}
	r := c.Do(t, http.MethodPost, "/bills/"+bid+"/pause", nil).Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["code"] != "invalid_status_transition" || d["params"].(map[string]any)["from"] != "archived" ||
		d["params"].(map[string]any)["to"] != "paused" {
		t.Fatalf("pause archived bill: %v", d)
	}
	b = c.Do(t, http.MethodPost, "/bills/"+bid+"/restore", nil).Expect(t, http.StatusOK).Data()
	if b["status"] != "active" || b["schedule"].(map[string]any)["status"] != "active" || b["next_due"] == nil {
		t.Fatalf("restore: %v", b)
	}
	b = c.Do(t, http.MethodPost, "/bills/"+bid+"/pause", nil).Expect(t, http.StatusOK).Data()
	if b["state"] != "paused" || b["schedule"].(map[string]any)["status"] != "paused" || b["next_due"] != nil {
		t.Fatalf("pause: %v", b)
	}
	c.Do(t, http.MethodPost, "/bills/"+bid+"/pause", nil).Expect(t, http.StatusUnprocessableEntity)
	b = c.Do(t, http.MethodPost, "/bills/"+bid+"/resume", nil).Expect(t, http.StatusOK).Data()
	if b["status"] != "active" || b["next_due"] == nil {
		t.Fatalf("resume: %v", b)
	}

	// Optional references are removed through clear; a field cannot be both
	// sent and cleared.
	if r := c.Do(t, http.MethodPatch, "/bills/"+bid, map[string]any{"payment_account_id": card, "clear": []string{"payment_account_id"},
		"version": b["version"]}); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("send and clear accepted: %d %s", r.Status, r.Raw)
	}
	c.Do(t, http.MethodPatch, "/bills/"+bid, map[string]any{"clear": []string{"name"}, "version": b["version"]}).Expect(t, http.StatusUnprocessableEntity)
	b = c.Do(t, http.MethodPatch, "/bills/"+bid, map[string]any{"clear": []string{"payment_account_id"}, "version": b["version"]}).
		Expect(t, http.StatusOK).Data()
	if b["payment_account_id"] != nil || b["name"] != "Home broadband" {
		t.Fatalf("clear payment account: %v", b)
	}
	// A new frequency starts from the anchors sent with it.
	b = c.Do(t, http.MethodPatch, "/bills/"+bid, map[string]any{"frequency": "weekly", "by_weekday": int(due.Weekday()), "version": b["version"]}).
		Expect(t, http.StatusOK).Data()
	sch := b["schedule"].(map[string]any)
	if sch["frequency"] != "weekly" || sch["by_month_day"] != nil || sch["by_weekday"].(float64) != float64(due.Weekday()) ||
		b["next_due"].(map[string]any)["postponed_to"] != nil {
		t.Fatalf("frequency change: %v", sch)
	}

	// Bills are private to their owner.
	other.Do(t, http.MethodPatch, "/bills/"+bid, map[string]any{"name": "Mine", "version": b["version"]}).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodPost, "/bills/"+bid+"/archive", nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodGet, "/bills/"+bid+"/payment-candidates", nil).Expect(t, http.StatusNotFound)
}

// Recurring rules: idempotent create, merchant and bill references, partial
// updates with clear, and coded conflicts.
func TestRecurringRulePatchReferencesAndCodedConflicts(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "rulepatch"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	cat := categoryID(t, c, "Healthcare")
	today := utcToday()
	body := map[string]any{"kind": "expense", "name": "Gym", "frequency": "monthly", "start_date": today.AddDate(0, 0, 3).Format(day),
		"timezone": "UTC", "amount": "1200", "account_id": acct, "category_id": cat, "merchant_name": "FitHub"}
	k := key()
	rule := c.Do(t, http.MethodPost, "/recurring-rules", body, "Idempotency-Key", k).Expect(t, http.StatusCreated).Data()
	rid := rule["id"].(string)
	m, _ := rule["merchant"].(map[string]any)
	if m == nil || m["name"] != "FitHub" || m["id"] != rule["merchant_id"] || rule["bill_id"] != nil || rule["frequency"] != "monthly" {
		t.Fatalf("rule references: %v", rule)
	}
	if r := c.Do(t, http.MethodPost, "/recurring-rules", body, "Idempotency-Key", k); r.Headers.Get("Idempotent-Replayed") != "true" ||
		r.Data()["id"] != rid {
		t.Fatalf("rule create replay: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/recurring-rules", body).Expect(t, http.StatusUnprocessableEntity)

	// Only the amount changes.
	r := c.Do(t, http.MethodPatch, "/recurring-rules/"+rid, map[string]any{"amount": "1350.50", "version": rule["version"]}).Expect(t, http.StatusOK).Data()
	if money(r, "amount") != "1350.50" || r["name"] != "Gym" || r["account_id"] != acct || r["category_id"] != cat ||
		r["merchant"].(map[string]any)["name"] != "FitHub" || r["start_date"] != body["start_date"] {
		t.Fatalf("partial rule update: %v", r)
	}
	// The kind is accepted for compatibility but cannot change.
	if res := c.Do(t, http.MethodPatch, "/recurring-rules/"+rid, map[string]any{"kind": "income", "version": r["version"]}); res.Status != http.StatusUnprocessableEntity {
		t.Fatalf("kind change accepted: %s", res.Raw)
	}
	r = c.Do(t, http.MethodPatch, "/recurring-rules/"+rid, map[string]any{"kind": "expense", "clear": []string{"category_id"}, "merchant_name": "",
		"version": r["version"]}).Expect(t, http.StatusOK).Data()
	if r["category_id"] != nil || r["merchant"] != nil || r["merchant_id"] != nil || money(r, "amount") != "1350.50" {
		t.Fatalf("clear category and merchant: %v", r)
	}
	if res := c.Do(t, http.MethodPatch, "/recurring-rules/"+rid, map[string]any{"name": "Gym", "version": 1}); res.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale rule patch: %s", res.Raw)
	}

	// A bill's schedule links back to the bill.
	bill := c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Water", "provider_name": "City Water", "expected_amount": "400",
		"frequency": "monthly", "start_date": today.AddDate(0, 0, 9).Format(day), "timezone": "UTC"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	var found bool
	for _, x := range c.Do(t, http.MethodGet, "/recurring-rules?kind=bill", nil).Expect(t, http.StatusOK).List() {
		x := x.(map[string]any)
		found = found || (x["bill_id"] == bill["id"] && x["merchant"].(map[string]any)["name"] == "City Water")
	}
	if !found {
		t.Fatal("bill rule without bill_id/merchant")
	}

	// Only real moves are allowed; conflicts carry stable codes.
	if d := detail(t, c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/resume", nil).Expect(t, http.StatusUnprocessableEntity)); d["code"] != "invalid_status_transition" ||
		d["params"].(map[string]any)["from"] != "active" {
		t.Fatalf("resume an active rule: %v", d)
	}
	c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/pause", nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/pause", nil).Expect(t, http.StatusUnprocessableEntity)
	c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/resume", nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/stop", nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/stop", nil).Expect(t, http.StatusUnprocessableEntity)
	res := c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/resume", nil).Expect(t, http.StatusConflict)
	if d := detail(t, res); d["code"] != "schedule_ended" {
		t.Fatalf("resume ended rule: %v", d)
	}
	res = c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/skip-next", nil).Expect(t, http.StatusConflict)
	if d := detail(t, res); d["code"] != "no_open_occurrence" {
		t.Fatalf("skip-next without occurrences: %v", d)
	}

	// The recurring report's note is coded.
	if rep := c.Do(t, http.MethodGet, "/analytics/recurring", nil).Expect(t, http.StatusOK).Data(); rep["note_code"] != "fixed_amounts_expectations" {
		t.Fatalf("recurring report note: %v", rep)
	}
}

// Payment candidates explain themselves with stable reason codes.
func TestBillPaymentCandidateReasonCodes(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "billreasons"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "20000"})["id"].(string)
	today := utcToday()
	bill := c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Power", "provider_name": "PowerCo", "expected_amount": "1500",
		"frequency": "monthly", "start_date": today.AddDate(0, 0, 2).Format(day), "timezone": "UTC"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	paid := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1500", "merchant_name": "PowerCo",
		"local_date": today.Format(day)})
	cands := c.Do(t, http.MethodGet, "/bills/"+bill["id"].(string)+"/payment-candidates", nil).Expect(t, http.StatusOK).List()
	if len(cands) != 1 {
		t.Fatalf("candidates: %v", cands)
	}
	got := cands[0].(map[string]any)
	if got["transaction_id"] != paid["id"] || !slices.Equal(strList(got["reason_codes"]), []string{"same_provider", "same_amount", "near_due_date"}) ||
		got["days_from_due"].(float64) != -2 || len(got["reasons"].([]any)) != 3 {
		t.Fatalf("candidate reasons: %v", got)
	}
}

// Budgets: partial updates by an editor keep the owner's references,
// [] turns threshold alerts off, allocations report overspend, explanations
// are coded, status changes follow valid transitions and viewers cannot
// change status.
func TestBudgetPatchEditorRefsStatusAndExplanations(t *testing.T) {
	s := apitest.New(t, nil)
	ownerAddr, mateAddr := s.Register(t, "budowner"), s.Register(t, "budmate")
	c, _ := s.Login(t, ownerAddr)
	mate, _ := s.Login(t, mateAddr)
	owner, mateID := userID(t, s, ownerAddr), userID(t, s, mateAddr)
	g := uuid.New()
	s.Env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Flat','household','INR','Asia/Kolkata')`, g, owner)
	s.Env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, g, owner, mateID)
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	groceries := categoryID(t, c, "Groceries")
	mateGroceries := categoryID(t, mate, "Groceries")

	b := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Food", "budget_type": "category", "period": "monthly", "currency": "INR",
		"limit": "10000", "alert_thresholds": []int{}, "visibility": "members",
		"allocations": []any{map[string]any{"category_id": groceries, "limit": "6000"}},
		"members":     []any{map[string]any{"user_id": mateID, "role": "editor"}}}).Expect(t, http.StatusCreated).Data()
	bid := b["id"].(string)
	if th := b["alert_thresholds"].([]any); len(th) != 0 {
		t.Fatalf("[] should turn threshold alerts off: %v", th)
	}
	def := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "All", "budget_type": "total", "period": "monthly", "currency": "INR",
		"limit": "30000"}).Expect(t, http.StatusCreated).Data()
	if len(def["alert_thresholds"].([]any)) == 0 {
		t.Fatalf("omitted thresholds should use the defaults: %v", def["alert_thresholds"])
	}

	// The editor changes the limit; the owner's allocation stays valid.
	v := mate.Do(t, http.MethodPatch, "/budgets/"+bid, map[string]any{"limit": "12000", "version": b["version"]}).Expect(t, http.StatusOK).Data()
	allocs := v["allocations"].([]any)
	if money(v, "limit") != "12000.00" || v["name"] != "Food" || len(allocs) != 1 || allocs[0].(map[string]any)["category_id"] != groceries {
		t.Fatalf("editor partial update: %v", v)
	}
	// The editor's own categories are not the budget's.
	if r := mate.Do(t, http.MethodPatch, "/budgets/"+bid, map[string]any{"allocations": []any{map[string]any{"category_id": mateGroceries,
		"limit": "5000"}}, "version": v["version"]}); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("editor referenced a category outside the budget owner's: %d %s", r.Status, r.Raw)
	}

	// Overspent allocations and coded explanations.
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "7000", "category_id": groceries})
	s.RunJobs(t)
	got := c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()
	alloc := got["allocations"].([]any)[0].(map[string]any)
	items := got["progress"].(map[string]any)["explanation_items"].([]any)
	first := items[0].(map[string]any)
	if money(alloc, "overspent") != "1000.00" || first["code"] != "spent_of_limit" || first["params"].(map[string]any)["spent"] != "7000.00" {
		t.Fatalf("overspend/explanations: %v / %v", alloc, items)
	}

	// Viewers cannot change status; transitions are validated.
	c.Do(t, http.MethodPatch, "/budgets/"+bid+"/members/"+mateID.String(), map[string]any{"role": "viewer"}).Expect(t, http.StatusOK)
	mate.Do(t, http.MethodPost, "/budgets/"+bid+"/pause", nil).Expect(t, http.StatusForbidden)
	mate.Do(t, http.MethodPatch, "/budgets/"+bid, map[string]any{"name": "Mine", "version": got["version"]}).Expect(t, http.StatusForbidden)
	r := c.Do(t, http.MethodPost, "/budgets/"+bid+"/restore", nil).Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["code"] != "invalid_status_transition" || d["params"].(map[string]any)["from"] != "active" {
		t.Fatalf("restore active budget: %v", d)
	}
	if a := c.Do(t, http.MethodDelete, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data(); a["status"] != "archived" {
		t.Fatalf("archive: %v", a["status"])
	}
	c.Do(t, http.MethodDelete, "/budgets/"+bid, nil).Expect(t, http.StatusOK) // archiving twice is a no-op
	c.Do(t, http.MethodPost, "/budgets/"+bid+"/pause", nil).Expect(t, http.StatusUnprocessableEntity)
	if a := c.Do(t, http.MethodPost, "/budgets/"+bid+"/restore", nil).Expect(t, http.StatusOK).Data(); a["status"] != "active" {
		t.Fatalf("restore: %v", a["status"])
	}
	c.Do(t, http.MethodPost, "/budgets/"+bid+"/pause", nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/budgets/"+bid+"/resume", nil).Expect(t, http.StatusOK)
}

// The budget drill-down lists exactly what the total counts, a page at a
// time; alerts page too.
func TestBudgetDrillDownMatchesTotalAndPages(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "drilldown"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	travel, groceries := categoryID(t, c, "Travel"), categoryID(t, c, "Groceries")
	b := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Everyday", "budget_type": "total", "period": "monthly", "currency": "INR",
		"limit": "20000", "excluded_category_ids": []string{travel}}).Expect(t, http.StatusCreated).Data()
	bid := b["id"].(string)
	if b["owner_display_name"] == nil {
		t.Fatalf("owner_display_name missing: %v", b)
	}
	for _, amt := range []string{"100", "200", "300"} {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": amt, "category_id": groceries})
	}
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "5000", "category_id": travel}) // excluded
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "700", "status": "pending"})    // pending not counted
	s.RunJobs(t)
	p := c.Do(t, http.MethodGet, "/budgets/"+bid, nil).Expect(t, http.StatusOK).Data()["progress"].(map[string]any)
	if money(p, "spent") != "600.00" || p["transaction_count"].(float64) != 3 {
		t.Fatalf("total: %v", p)
	}
	first := c.Do(t, http.MethodGet, "/budgets/"+bid+"/transactions?limit=2", nil).Expect(t, http.StatusOK)
	meta := first.Body["meta"].(map[string]any)
	if len(first.List()) != 2 || meta["has_more"] != true || meta["next_cursor"] == "" {
		t.Fatalf("first page: %s", first.Raw)
	}
	second := c.Do(t, http.MethodGet, "/budgets/"+bid+"/transactions?limit=2&cursor="+meta["next_cursor"].(string), nil).Expect(t, http.StatusOK)
	all := append(first.List(), second.List()...)
	if len(all) != 3 || second.Body["meta"].(map[string]any)["has_more"] != false {
		t.Fatalf("pages: %d / %s", len(all), second.Raw)
	}
	for _, x := range all {
		if cat, _ := x.(map[string]any)["category"].(map[string]any); cat == nil || cat["id"] != groceries {
			t.Fatalf("drill-down listed an uncounted transaction: %v", x)
		}
	}
	al := c.Do(t, http.MethodGet, "/budget-alerts?limit=1", nil).Expect(t, http.StatusOK)
	if _, ok := al.Body["meta"].(map[string]any)["has_more"]; !ok {
		t.Fatalf("alerts are not paged: %s", al.Raw)
	}
}

// Budgets refuse settings they would silently ignore.
func TestBudgetShapeValidation(t *testing.T) {
	s := apitest.New(t, nil)
	ownerAddr, mateAddr, outsiderAddr := s.Register(t, "shapeowner"), s.Register(t, "shapemate"), s.Register(t, "shapeout")
	c, _ := s.Login(t, ownerAddr)
	owner, mateID, outsider := userID(t, s, ownerAddr), userID(t, s, mateAddr), userID(t, s, outsiderAddr)
	g := uuid.New()
	s.Env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Trip','trip','INR','Asia/Kolkata')`, g, owner)
	s.Env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, g, owner, mateID)
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR"})["id"].(string)
	groceries := categoryID(t, c, "Groceries")
	base := func(extra map[string]any) map[string]any {
		body := map[string]any{"name": "Shape", "period": "monthly", "currency": "INR", "limit": "1000"}
		for k, v := range extra {
			body[k] = v
		}
		return body
	}
	code := func(body map[string]any) string {
		r := c.Do(t, http.MethodPost, "/budgets", body)
		if r.Status != http.StatusUnprocessableEntity {
			t.Fatalf("accepted %v: %d %s", body, r.Status, r.Raw)
		}
		d := detail(t, r)
		if c, ok := d["code"].(string); ok && c != "" {
			return c
		}
		return d["field"].(string)
	}
	cases := []struct {
		body map[string]any
		want string
	}{
		{base(map[string]any{"group_id": g, "budget_type": "category", "allocations": []any{map[string]any{"category_id": groceries, "limit": "500"}}}), "group_budget_type_unsupported"},
		{base(map[string]any{"group_id": g, "budget_type": "total", "included_account_ids": []string{acct}}), "group_budget_filter_unsupported"},
		{base(map[string]any{"group_id": g, "budget_type": "envelope", "allocations": []any{map[string]any{"category_id": groceries, "limit": "500"}}}), "group_budget_allocation_unsupported"},
		{base(map[string]any{"group_id": g, "budget_type": "envelope", "allocations": []any{map[string]any{"member_user_id": outsider, "limit": "500"}}}), "body.allocations[0].member_user_id"},
		{base(map[string]any{"budget_type": "envelope", "allocations": []any{map[string]any{"member_user_id": mateID, "limit": "500"}}}), "body.allocations[0].member_user_id"},
		{base(map[string]any{"budget_type": "merchant"}), "body.merchant_ids"},
		{base(map[string]any{"budget_type": "account"}), "body.included_account_ids"},
	}
	for _, tc := range cases {
		if got := code(tc.body); got != tc.want {
			t.Fatalf("%v: got %s, want %s", tc.body, got, tc.want)
		}
	}
	// A valid group budget split between members.
	c.Do(t, http.MethodPost, "/budgets", base(map[string]any{"group_id": g, "budget_type": "envelope",
		"allocations": []any{map[string]any{"member_user_id": mateID, "limit": "400"}, map[string]any{"member_user_id": owner, "limit": "600"}}})).
		Expect(t, http.StatusCreated)
	// Member errors point at the member endpoint's own fields.
	b := c.Do(t, http.MethodPost, "/budgets", base(map[string]any{"budget_type": "total"})).Expect(t, http.StatusCreated).Data()
	r := c.Do(t, http.MethodPost, "/budgets/"+b["id"].(string)+"/members", map[string]any{"user_id": outsider, "role": "viewer"}).
		Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["field"] != "body.user_id" {
		t.Fatalf("member error field: %v", d)
	}
}

// Lifecycle actions honour ?version=, candidates are empty when nothing is
// unpaid, and creates stop at the fair-use cap shown in /limits.
func TestPlanningVersionsEmptyCandidatesAndCaps(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "plancaps"))
	me := c.Do(t, http.MethodGet, "/me", nil).Expect(t, http.StatusOK).Data()["account"].(map[string]any)["id"].(string)
	today := utcToday()
	bill := c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Rent", "expected_amount": "15000", "frequency": "monthly",
		"start_date": today.AddDate(0, 0, 4).Format(day), "timezone": "UTC"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	bid := bill["id"].(string)
	c.Do(t, http.MethodPost, "/bills/"+bid+"/pause?version=999", nil).Expect(t, http.StatusConflict)
	paused := c.Do(t, http.MethodPost, "/bills/"+bid+"/pause?version="+fmt.Sprint(bill["version"]), nil).Expect(t, http.StatusOK).Data()
	if cands := c.Do(t, http.MethodGet, "/bills/"+bid+"/payment-candidates", nil).Expect(t, http.StatusOK).List(); len(cands) != 0 {
		t.Fatalf("paused bill candidates: %v", cands)
	}
	c.Do(t, http.MethodPost, "/bills/"+bid+"/resume?version="+fmt.Sprint(paused["version"]), nil).Expect(t, http.StatusOK)

	lim := c.Do(t, http.MethodGet, "/limits", nil).Expect(t, http.StatusOK).Data()
	maxRules, maxBills := int(lim["max_open_recurring_rules"].(float64)), int(lim["max_open_bills"].(float64))
	if maxRules < 100 || maxBills < 100 {
		t.Fatalf("caps too low to be fair use: %v", lim)
	}
	s.Env.ExecWorker(t, `insert into recurring_rules (user_id, kind, name, frequency, start_date, timezone)
		select $1, 'expense', 'Rule '||g, 'monthly', current_date, 'UTC' from generate_series(1, $2) g`, uuid.MustParse(me), maxRules)
	r := c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "One more", "frequency": "monthly",
		"start_date": today.Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["code"] != "record_limit_reached" || d["params"].(map[string]any)["resource"] != "recurring_rules" {
		t.Fatalf("cap: %v", d)
	}
}

// Merges carry budget filters along, and filters on a merged category or
// merchant still find the moved transactions (saved filters, bookmarks).
func TestMergesRepointBudgetFiltersAndResolveMergedIDs(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "mergebudgets"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "120", "merchant_name": "Corner Cafe"})
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "80", "merchant_name": "Corner Café Ltd"})
	merchantID := func(name string) string {
		for _, x := range c.Do(t, http.MethodGet, "/merchants?status=all", nil).Expect(t, http.StatusOK).List() {
			if x.(map[string]any)["name"] == name {
				return x.(map[string]any)["id"].(string)
			}
		}
		t.Fatalf("no merchant %s", name)
		return ""
	}
	src, dst := merchantID("Corner Café Ltd"), merchantID("Corner Cafe")
	mb := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Cafe", "budget_type": "merchant", "period": "monthly", "currency": "INR",
		"limit": "1000", "merchant_ids": []string{src}}).Expect(t, http.StatusCreated).Data()
	prev := c.Do(t, http.MethodPost, "/merchants/merge/preview", map[string]any{"source_ids": []string{src}, "target_id": dst}).
		Expect(t, http.StatusOK).Data()
	if prev["affected"].(map[string]any)["budget_filters"].(float64) != 1 {
		t.Fatalf("merchant merge preview: %v", prev)
	}
	c.Do(t, http.MethodPost, "/merchants/merge", map[string]any{"source_ids": []string{src}, "target_id": dst}).Expect(t, http.StatusOK)
	got := c.Do(t, http.MethodGet, "/budgets/"+mb["id"].(string), nil).Expect(t, http.StatusOK).Data()
	if ids := strList(got["merchant_ids"]); len(ids) != 1 || ids[0] != dst {
		t.Fatalf("merchant budget after merge: %v", got["merchant_ids"])
	}
	if n := len(c.Do(t, http.MethodGet, "/transactions?merchant_id="+src, nil).Expect(t, http.StatusOK).List()); n != 2 {
		t.Fatalf("filter on a merged merchant found %d transactions, want 2", n)
	}

	// Categories: an excluded category moves with the merge.
	coffee := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Coffee", "kind": "expense"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	food := categoryID(t, c, "Food & dining")
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "60", "category_id": coffee})
	tb := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "All but coffee", "budget_type": "total", "period": "monthly",
		"currency": "INR", "limit": "5000", "excluded_category_ids": []string{coffee}}).Expect(t, http.StatusCreated).Data()
	c.Do(t, http.MethodPost, "/categories/merge", map[string]any{"source_ids": []string{coffee}, "target_id": food}).Expect(t, http.StatusOK)
	got = c.Do(t, http.MethodGet, "/budgets/"+tb["id"].(string), nil).Expect(t, http.StatusOK).Data()
	if ids := strList(got["excluded_category_ids"]); len(ids) != 1 || ids[0] != food {
		t.Fatalf("excluded categories after merge: %v", got["excluded_category_ids"])
	}
	if n := len(c.Do(t, http.MethodGet, "/transactions?category_id="+coffee, nil).Expect(t, http.StatusOK).List()); n != 1 {
		t.Fatalf("filter on a merged category found %d transactions, want 1", n)
	}
}

// A rule's amount bounds apply only in their own currency.
func TestCategoryRuleAmountBoundsAreCurrencyAware(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "rulecurrency"))
	inr := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "9000"})["id"].(string)
	usd := createAccount(t, c, map[string]any{"name": "Travel card", "account_type": "bank", "currency": "USD", "opening_balance": "900"})["id"].(string)
	food := categoryID(t, c, "Food & dining")
	c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Coffee", "match_field": "description", "match_type": "contains",
		"pattern": "coffee", "amount_min": "100", "amount_max": "500", "currency": "INR", "set_category_id": food}).Expect(t, http.StatusCreated)
	inINR := createTx(t, c, map[string]any{"type": "expense", "account_id": inr, "amount": "300", "description": "Coffee beans"})
	inUSD := createTx(t, c, map[string]any{"type": "expense", "account_id": usd, "amount": "300", "description": "Coffee beans"})
	if cat, _ := inINR["category"].(map[string]any); cat == nil || cat["id"] != food {
		t.Fatalf("INR transaction not categorized: %v", inINR["category"])
	}
	if inUSD["category"] != nil {
		t.Fatalf("an INR-bounded rule categorized a USD transaction: %v", inUSD["category"])
	}
	prev := c.Do(t, http.MethodPost, "/category-rules/preview", map[string]any{"rule": map[string]any{"name": "Coffee", "match_field": "description",
		"match_type": "contains", "pattern": "coffee", "amount_min": "100", "amount_max": "500", "currency": "INR", "set_category_id": food},
		"only_uncategorized": false}).Expect(t, http.StatusOK).Data()
	if prev["match_count"].(float64) != 1 {
		t.Fatalf("preview matched across currencies: %v", prev)
	}
}

// Goal contributions page with a cursor (no silent cut-off), the CSV export
// is complete, and goals/subscriptions stop at their fair-use caps.
func TestGoalContributionPagesCompleteExportAndCaps(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "goalpages"))
	me := uuid.MustParse(c.Do(t, http.MethodGet, "/me", nil).Expect(t, http.StatusOK).Data()["account"].(map[string]any)["id"].(string))
	g := c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Long haul", "goal_type": "custom", "target_amount": "100000"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	gid := g["id"].(string)
	s.Env.ExecWorker(t, `insert into goal_contributions (goal_id, user_id, amount_minor, currency, contributed_on)
		select $1, $2, 100, 'INR', current_date - (n % 900) from generate_series(1, 505) n`, uuid.MustParse(gid), me)

	seen := map[string]bool{}
	path := "/goals/" + gid + "/contributions"
	pages := 0
	for path != "" {
		r := c.Do(t, http.MethodGet, path, nil).Expect(t, http.StatusOK)
		for _, x := range r.List() {
			id := x.(map[string]any)["id"].(string)
			if seen[id] {
				t.Fatalf("contribution %s repeated across pages", id)
			}
			seen[id] = true
		}
		pages++
		meta := r.Body["meta"].(map[string]any)
		path = ""
		if meta["has_more"] == true {
			path = "/goals/" + gid + "/contributions?cursor=" + meta["next_cursor"].(string)
		}
	}
	if len(seen) != 505 || pages != 2 {
		t.Fatalf("paged %d contributions in %d pages, want 505 in 2", len(seen), pages)
	}
	csv := c.Do(t, http.MethodGet, "/goals/"+gid+"/export", nil).Expect(t, http.StatusOK)
	if lines := len(strings.Split(strings.TrimSpace(string(csv.Raw)), "\n")); lines != 506 {
		t.Fatalf("export has %d lines, want header + 505", lines)
	}

	// Caps: goals (not archived) and subscriptions (not cancelled).
	lim := c.Do(t, http.MethodGet, "/limits", nil).Expect(t, http.StatusOK).Data()
	maxGoals, maxSubs := int(lim["max_open_goals"].(float64)), int(lim["max_open_subscriptions"].(float64))
	s.Env.ExecWorker(t, `insert into goals (owner_user_id, name, goal_type, target_amount_minor, currency, start_date)
		select $1, 'Goal '||n, 'custom', 1000, 'INR', current_date from generate_series(1, $2) n`, me, maxGoals)
	r := c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "One more", "goal_type": "custom", "target_amount": "100"},
		"Idempotency-Key", key()).Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["code"] != "record_limit_reached" || d["params"].(map[string]any)["resource"] != "goals" {
		t.Fatalf("goal cap: %v", d)
	}
	s.Env.ExecWorker(t, `insert into subscriptions (user_id, name, amount_minor, currency, billing_frequency, start_date)
		select $1, 'Sub '||n, 100, 'INR', 'monthly', current_date from generate_series(1, $2) n`, me, maxSubs)
	r = c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "One more", "amount": "99", "billing_frequency": "monthly",
		"start_date": utcToday().Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["code"] != "record_limit_reached" || d["params"].(map[string]any)["resource"] != "subscriptions" {
		t.Fatalf("subscription cap: %v", d)
	}
}

// Round-3 client findings: budget alert filter, bill field names, edits that
// keep archived references, subscription payment list, rule defaults, merchant
// versions, single tag/rule reads and moved calendar items.
func TestClientFindingsRound3(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "findings3"))
	other, _ := s.Login(t, s.Register(t, "findings3b"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	old := createAccount(t, c, map[string]any{"name": "Old card", "account_type": "bank", "currency": "INR"})["id"].(string)
	today := utcToday()

	// Alerts can be listed for one budget.
	a := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "A", "budget_type": "total", "period": "monthly", "currency": "INR",
		"limit": "100"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "B", "budget_type": "total", "period": "monthly", "currency": "INR",
		"limit": "100"}).Expect(t, http.StatusCreated)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "80"})
	s.RunJobs(t)
	all := c.Do(t, http.MethodGet, "/budget-alerts", nil).Expect(t, http.StatusOK).List()
	only := c.Do(t, http.MethodGet, "/budget-alerts?budget_id="+a, nil).Expect(t, http.StatusOK).List()
	if len(only) == 0 || len(only) >= len(all) {
		t.Fatalf("alert filter: %d of %d", len(only), len(all))
	}
	for _, x := range only {
		if x.(map[string]any)["budget_id"] != a {
			t.Fatalf("alert for another budget: %v", x)
		}
	}
	c.Do(t, http.MethodGet, "/budget-alerts?budget_id=nope", nil).Expect(t, http.StatusUnprocessableEntity)

	// Bill errors use the bill's field names.
	r := c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Gas", "expected_amount": "12.345", "frequency": "monthly",
		"start_date": today.Format(day), "timezone": "UTC"}, "Idempotency-Key", key()).Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["field"] != "body.expected_amount" {
		t.Fatalf("bill amount error field: %v", d)
	}

	// An unrelated edit keeps an account that was archived since; auto-posting rules still need an active one.
	bill := c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Phone", "expected_amount": "499", "frequency": "monthly",
		"start_date": today.AddDate(0, 0, 6).Format(day), "timezone": "UTC", "payment_account_id": old}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	rule := c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "Gym", "frequency": "monthly",
		"start_date": today.AddDate(0, 0, 6).Format(day), "timezone": "UTC", "amount": "999", "account_id": old, "auto_post": true},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	s.Env.ExecWorker(t, `update financial_accounts set status = 'archived' where id = $1`, uuid.MustParse(old))
	c.Do(t, http.MethodPatch, "/bills/"+bill["id"].(string), map[string]any{"name": "Mobile phone", "version": bill["version"]}).
		Expect(t, http.StatusOK)
	r = c.Do(t, http.MethodPatch, "/recurring-rules/"+rule["id"].(string), map[string]any{"name": "Gym club", "version": rule["version"]}).
		Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["field"] != "body.account_id" {
		t.Fatalf("auto-post rule with archived account: %v", d)
	}

	// The calendar shows moved occurrences.
	occ := c.Do(t, http.MethodGet, "/bills/"+bill["id"].(string), nil).Expect(t, http.StatusOK).Data()["next_due"].(map[string]any)
	moved := today.AddDate(0, 0, 9).Format(day)
	c.Do(t, http.MethodPost, "/recurring-occurrences/"+occ["id"].(string)+"/actions", map[string]any{"action": "postpone", "postpone_to": moved},
		"Idempotency-Key", key()).Expect(t, http.StatusOK)
	var found bool
	for _, x := range c.Do(t, http.MethodGet, "/calendar?from="+today.Format(day)+"&to="+today.AddDate(0, 0, 20).Format(day), nil).
		Expect(t, http.StatusOK).List() {
		x := x.(map[string]any)
		if x["occurrence_id"] == occ["id"] {
			found = x["date"] == moved && x["postponed_to"] == moved && x["scheduled_on"] == occ["occurrence_date"]
		}
	}
	if !found {
		t.Fatal("calendar did not show the moved occurrence")
	}

	// Subscriptions list the payments currently linked.
	sub := c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "Music", "amount": "199", "billing_frequency": "monthly",
		"start_date": today.Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	pay := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "199", "description": "Music"})
	c.Do(t, http.MethodPost, "/subscriptions/"+sub["id"].(string)+"/payments", map[string]any{"transaction_id": pay["id"]},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	payments := c.Do(t, http.MethodGet, "/subscriptions/"+sub["id"].(string), nil).Expect(t, http.StatusOK).Data()["payments"].([]any)
	if len(payments) != 1 || payments[0].(map[string]any)["transaction_id"] != pay["id"] || money(payments[0].(map[string]any), "amount") != "199.00" {
		t.Fatalf("linked payments: %v", payments)
	}

	// Rule priority defaults to 100, an explicit 0 is kept; single reads exist and are private.
	food := categoryID(t, c, "Food & dining")
	r1 := c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Cafe", "match_field": "description", "match_type": "contains",
		"pattern": "cafe", "set_category_id": food}).Expect(t, http.StatusCreated).Data()
	r0 := c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Tea", "priority": 0, "match_field": "description",
		"match_type": "contains", "pattern": "tea", "set_category_id": food}).Expect(t, http.StatusCreated).Data()
	if r1["priority"].(float64) != 100 || r0["priority"].(float64) != 0 || r1["apply_to"] != "all" {
		t.Fatalf("rule defaults: %v / %v", r1, r0)
	}
	if got := c.Do(t, http.MethodGet, "/category-rules/"+r1["id"].(string), nil).Expect(t, http.StatusOK).Data(); got["name"] != "Cafe" {
		t.Fatalf("get rule: %v", got)
	}
	other.Do(t, http.MethodGet, "/category-rules/"+r1["id"].(string), nil).Expect(t, http.StatusNotFound)
	tag := c.Do(t, http.MethodPost, "/tags", map[string]any{"name": "work"}).Expect(t, http.StatusCreated).Data()
	if got := c.Do(t, http.MethodGet, "/tags/"+tag["id"].(string), nil).Expect(t, http.StatusOK).Data(); got["name"] != "work" {
		t.Fatalf("get tag: %v", got)
	}
	other.Do(t, http.MethodGet, "/tags/"+tag["id"].(string), nil).Expect(t, http.StatusNotFound)

	// Alias changes bump the merchant's version.
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "40", "merchant_name": "Bean There"})
	var m map[string]any
	for _, x := range c.Do(t, http.MethodGet, "/merchants", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["name"] == "Bean There" {
			m = x.(map[string]any)
		}
	}
	after := c.Do(t, http.MethodPost, "/merchants/aliases", map[string]any{"merchant_id": m["id"], "alias": "BEAN THERE CAFE"}).
		Expect(t, http.StatusOK).Data()
	if after["version"].(float64) != m["version"].(float64)+1 {
		t.Fatalf("alias add version: %v -> %v", m["version"], after["version"])
	}
}
