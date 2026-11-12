package api_test

import (
	"net/http"
	"testing"

	"github.com/google/uuid"

	"montra/backend/internal/testutil/apitest"
)

func key() string { return uuid.NewString() }

func money(r map[string]any, field string) string {
	return r[field].(map[string]any)["amount"].(string)
}

func createAccount(t *testing.T, c *apitest.Client, body map[string]any) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodPost, "/accounts", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
}

func createTx(t *testing.T, c *apitest.Client, body map[string]any) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodPost, "/transactions", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()["transaction"].(map[string]any)
}

func balance(t *testing.T, c *apitest.Client, acct string) string {
	t.Helper()
	return money(c.Do(t, http.MethodGet, "/accounts/"+acct, nil).Expect(t, http.StatusOK).Data(), "balance")
}

func TestAccountLifecycleAndIdempotency(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "accounts"))
	k := key()
	body := map[string]any{"name": "HDFC Savings", "account_type": "savings", "currency": "INR", "opening_balance": "25000.50"}
	a := c.Do(t, http.MethodPost, "/accounts", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	acct := a.Data()
	if money(acct, "balance") != "25000.50" {
		t.Fatalf("opening balance = %v", acct["balance"])
	}
	again := c.Do(t, http.MethodPost, "/accounts", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	if again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["id"] != acct["id"] {
		t.Fatal("retry with the same key must replay the original result")
	}
	body["name"] = "Different"
	if r := c.Do(t, http.MethodPost, "/accounts", body, "Idempotency-Key", k); r.ErrorCode() != "IDEMPOTENCY_CONFLICT" {
		t.Fatalf("reused key with different payload: %s", r.Raw)
	}
	if n := len(c.Do(t, http.MethodGet, "/accounts", nil).List()); n != 1 {
		t.Fatalf("expected exactly 1 account after retries, got %d", n)
	}
	id := acct["id"].(string)
	// Credit card: amount owed is a negative balance; available credit derived.
	cc := createAccount(t, c, map[string]any{"name": "Card", "account_type": "credit_card", "currency": "INR", "opening_balance": "-12000", "credit_limit": "50000"})
	if !cc["is_liability"].(bool) || money(cc, "available_credit") != "38000.00" {
		t.Fatalf("credit card = %v", cc)
	}
	// Currency is locked once transactions exist.
	if r := c.Do(t, http.MethodPatch, "/accounts/"+id, map[string]any{"version": acct["version"], "currency": "USD"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("currency change allowed: %s", r.Raw)
	}
	// Adjustment requires a reason and is auditable.
	adj := c.Do(t, http.MethodPost, "/accounts/"+id+"/adjustments", map[string]any{"target_balance": "25100.50", "reason": "Interest credited"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if money(adj, "balance") != "25100.50" || adj["balance_source"] != "manual" {
		t.Fatalf("adjustment = %v", adj)
	}
	// Archive blocks new transactions; close requires a zero balance.
	c.Do(t, http.MethodPost, "/accounts/"+id+"/archive", nil).Expect(t, http.StatusOK)
	r := c.Do(t, http.MethodPost, "/transactions", map[string]any{"type": "expense", "account_id": id, "amount": "10"}, "Idempotency-Key", key())
	if r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("transaction on archived account: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/accounts/"+id+"/restore", nil).Expect(t, http.StatusOK)
	if r := c.Do(t, http.MethodPost, "/accounts/"+id+"/close", nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("closing with balance allowed: %s", r.Raw)
	}
	// Zero- and three-decimal currencies.
	jpy := createAccount(t, c, map[string]any{"name": "Yen", "account_type": "cash", "currency": "JPY", "opening_balance": "1500"})
	kwd := createAccount(t, c, map[string]any{"name": "Dinar", "account_type": "cash", "currency": "KWD", "opening_balance": "1.234"})
	if money(jpy, "balance") != "1500" || money(kwd, "balance") != "1.234" {
		t.Fatalf("exponent handling: %v %v", jpy["balance"], kwd["balance"])
	}
	if r := c.Do(t, http.MethodPost, "/accounts", map[string]any{"name": "Bad", "account_type": "cash", "currency": "JPY", "opening_balance": "10.5"},
		"Idempotency-Key", key()); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("JPY with decimals accepted: %s", r.Raw)
	}
	// Cross-user isolation.
	other, _ := s.Login(t, s.Register(t, "nosy"))
	other.Do(t, http.MethodGet, "/accounts/"+id, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodPost, "/accounts/"+id+"/archive", nil).Expect(t, http.StatusNotFound)
	if r := other.Do(t, http.MethodPost, "/transactions", map[string]any{"type": "expense", "account_id": id, "amount": "1"}, "Idempotency-Key", key()); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("other user wrote into my account: %s", r.Raw)
	}
}

func TestTransactionEditVoidRestoreAndAudit(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "ledger"))
	acct := createAccount(t, c, map[string]any{"name": "Wallet", "account_type": "cash", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	tx := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "250.75", "merchant_name": "Sample Grocer",
		"description": "Weekly groceries", "tag_names": []string{"Home", "food"}})
	if balance(t, c, acct) != "749.25" {
		t.Fatalf("balance after expense = %s", balance(t, c, acct))
	}
	if tx["merchant"].(map[string]any)["name"] != "Sample Grocer" || len(tx["tags"].([]any)) != 2 {
		t.Fatalf("merchant/tags not resolved: %v", tx)
	}
	id := tx["id"].(string)
	upd := c.Do(t, http.MethodPatch, "/transactions/"+id, map[string]any{"version": tx["version"], "amount": "300"}).Expect(t, http.StatusOK).Data()
	if balance(t, c, acct) != "700.00" || upd["version"].(float64) != 2 {
		t.Fatalf("edit did not re-post the ledger: %s", balance(t, c, acct))
	}
	// Stale version is rejected (no silent overwrite).
	if r := c.Do(t, http.MethodPatch, "/transactions/"+id, map[string]any{"version": tx["version"], "amount": "1"}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale edit accepted: %s", r.Raw)
	}
	c.Do(t, http.MethodDelete, "/transactions/"+id, nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodDelete, "/transactions/"+id, nil).Expect(t, http.StatusOK) // idempotent
	if balance(t, c, acct) != "1000.00" {
		t.Fatalf("void did not reverse the ledger: %s", balance(t, c, acct))
	}
	if n := len(c.Do(t, http.MethodGet, "/transactions?type=expense", nil).List()); n != 0 {
		t.Fatalf("voided transaction still listed by default (%d)", n)
	}
	c.Do(t, http.MethodPost, "/transactions/"+id+"/restore", nil).Expect(t, http.StatusOK)
	if balance(t, c, acct) != "700.00" {
		t.Fatalf("restore did not re-post: %s", balance(t, c, acct))
	}
	audit := c.Do(t, http.MethodGet, "/transactions/"+id+"/audit", nil).Expect(t, http.StatusOK).List()
	actions := []string{}
	for _, e := range audit {
		actions = append(actions, e.(map[string]any)["action"].(string))
	}
	want := []string{"created", "updated", "voided", "restored"}
	if len(actions) != len(want) {
		t.Fatalf("audit = %v", actions)
	}
	for i := range want {
		if actions[i] != want[i] {
			t.Fatalf("audit = %v", actions)
		}
	}
	// Other users cannot see, edit, void or audit it.
	other, _ := s.Login(t, s.Register(t, "intruder2"))
	other.Do(t, http.MethodGet, "/transactions/"+id, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodPatch, "/transactions/"+id, map[string]any{"version": 4, "amount": "1"}).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodDelete, "/transactions/"+id, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodGet, "/transactions/"+id+"/audit", nil).Expect(t, http.StatusNotFound)
	// Card numbers / OTPs are rejected in free text (Luhn-valid test number).
	r := c.Do(t, http.MethodPost, "/transactions", map[string]any{"type": "expense", "account_id": acct, "amount": "5",
		"notes": "card 4111 1111 1111 1111"}, "Idempotency-Key", key())
	if r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("card number stored: %s", r.Raw)
	}
}

func TestRefundCapsAndAnalyticsReconcile(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "refunds"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "10000"})["id"].(string)
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "5000"})
	exp := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1000"})
	id := exp["id"].(string)
	c.Do(t, http.MethodPost, "/transactions/"+id+"/refunds", map[string]any{"amount": "600"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/transactions/"+id+"/refunds", map[string]any{"amount": "300", "type": "reimbursement"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	if r := c.Do(t, http.MethodPost, "/transactions/"+id+"/refunds", map[string]any{"amount": "100.01"}, "Idempotency-Key", key()); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("over-refund accepted: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/transactions/"+id+"/refunds", map[string]any{"amount": "100.01", "is_correction": true}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	// The original cannot be voided while refunds exist.
	if r := c.Do(t, http.MethodDelete, "/transactions/"+id, nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("void with refunds allowed: %s", r.Raw)
	}
	// Transfer to a second account is excluded from income/expense.
	acct2 := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR"})["id"].(string)
	c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": acct, "to_account_id": acct2, "amount": "2000", "fee": "10"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	if balance(t, c, acct2) != "2000.00" {
		t.Fatalf("transfer destination = %s", balance(t, c, acct2))
	}
	// Ledger: 10000 + 5000 - 1000 + 600 + 300 + 100.01 - 2000 - 10 = 12990.01
	if balance(t, c, acct) != "12990.01" {
		t.Fatalf("source balance = %s", balance(t, c, acct))
	}
	cf := c.Do(t, http.MethodGet, "/analytics/cash-flow?range=this_month", nil).Expect(t, http.StatusOK).Data()
	tot := cf["totals"].([]any)[0].(map[string]any)
	// income 5000; gross expense 1000 + fee 10; refunds 1000.01 → net expense 9.99
	if money(tot, "income") != "5000.00" || money(tot, "gross_expense") != "1010.00" || money(tot, "refunds") != "1000.01" ||
		money(tot, "net_expense") != "9.99" || money(tot, "net_cash_flow") != "4990.01" {
		t.Fatalf("cash flow does not reconcile: %v", tot)
	}
	dash := c.Do(t, http.MethodGet, "/dashboard/summary", nil).Expect(t, http.StatusOK).Data()
	if len(dash["recent_transactions"].([]any)) == 0 || len(dash["notes"].([]any)) == 0 {
		t.Fatalf("dashboard incomplete: %v", dash)
	}
	bal := c.Do(t, http.MethodGet, "/analytics/accounts", nil).Expect(t, http.StatusOK).Data()["totals"].([]any)[0].(map[string]any)
	if money(bal, "net_worth") != "14990.01" {
		t.Fatalf("net worth = %v", bal["net_worth"])
	}
}

func TestTransfersFXVoidAsUnit(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "fx"))
	usd := createAccount(t, c, map[string]any{"name": "USD", "account_type": "bank", "currency": "USD", "opening_balance": "1000"})["id"].(string)
	inr := createAccount(t, c, map[string]any{"name": "INR", "account_type": "bank", "currency": "INR"})["id"].(string)
	if r := c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": usd, "to_account_id": inr, "amount": "100"}, "Idempotency-Key", key()); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("cross-currency transfer without rate accepted: %s", r.Raw)
	}
	tr := c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": usd, "to_account_id": inr, "amount": "100", "fx_rate": "83.255"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if money(tr, "to_amount") != "8325.50" || tr["fx_rate"] == nil {
		t.Fatalf("fx transfer = %v", tr)
	}
	if balance(t, c, usd) != "900.00" || balance(t, c, inr) != "8325.50" {
		t.Fatal("fx transfer balances wrong")
	}
	// Voiding one leg voids the whole transfer.
	c.Do(t, http.MethodDelete, "/transactions/"+tr["to_transaction_id"].(string), nil).Expect(t, http.StatusOK)
	if balance(t, c, usd) != "1000.00" || balance(t, c, inr) != "0.00" {
		t.Fatal("transfer was not voided as a unit")
	}
	c.Do(t, http.MethodPost, "/transactions/"+tr["from_transaction_id"].(string)+"/restore", nil).Expect(t, http.StatusOK)
	if balance(t, c, inr) != "8325.50" {
		t.Fatal("transfer was not restored as a unit")
	}
}

func TestSearchCategoriesRulesAndBulk(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "search"))
	acct := createAccount(t, c, map[string]any{"name": "Card", "account_type": "debit_card", "currency": "INR"})["id"].(string)
	cats := c.Do(t, http.MethodGet, "/categories", nil).Expect(t, http.StatusOK).List()
	var food string
	for _, x := range cats {
		if m := x.(map[string]any); m["system_key"] == "food_dining" {
			food = m["id"].(string)
		}
	}
	if len(cats) < 20 || food == "" {
		t.Fatalf("starter categories missing (%d)", len(cats))
	}
	sub := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Coffee", "kind": "expense", "parent_id": food}).Expect(t, http.StatusCreated).Data()
	if r := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Espresso", "kind": "expense", "parent_id": sub["id"]}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("third level accepted: %s", r.Raw)
	}
	// A rule auto-categorizes new transactions.
	c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Coffee shops", "match_field": "any", "match_type": "contains",
		"pattern": "brew", "set_category_id": sub["id"], "priority": 10}).Expect(t, http.StatusCreated)
	t1 := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "180", "description": "Morning brew bar"})
	if t1["category"].(map[string]any)["id"] != sub["id"] {
		t.Fatalf("rule not applied: %v", t1["category"])
	}
	for i, amt := range []string{"50", "75", "120", "999"} {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": amt, "description": "Item " + string(rune('A'+i))})
	}
	// Filter by subcategory via parent, amount range, text; paginate.
	if n := len(c.Do(t, http.MethodGet, "/transactions?category_id="+food, nil).List()); n != 1 {
		t.Fatalf("parent category filter should include subcategories, got %d", n)
	}
	if n := len(c.Do(t, http.MethodGet, "/transactions?min_amount=60&max_amount=200", nil).List()); n != 3 {
		t.Fatalf("amount filter = %d", n)
	}
	if n := len(c.Do(t, http.MethodGet, "/transactions?q=brew", nil).List()); n != 1 {
		t.Fatalf("text search = %d", n)
	}
	page := c.Do(t, http.MethodGet, "/transactions?limit=2&sort=amount_desc", nil).Expect(t, http.StatusOK)
	next := page.Body["meta"].(map[string]any)["next_cursor"].(string)
	page2 := c.Do(t, http.MethodGet, "/transactions?limit=2&sort=amount_desc&cursor="+next, nil).Expect(t, http.StatusOK).List()
	if len(page.List()) != 2 || len(page2) != 2 || money(page.List()[0].(map[string]any), "amount") != "999.00" ||
		money(page2[0].(map[string]any), "amount") != "120.00" {
		t.Fatal("cursor pagination by amount is wrong")
	}
	// Bulk recategorize everything uncategorized into food; merge coffee into food.
	ids := []string{}
	for _, x := range c.Do(t, http.MethodGet, "/transactions", nil).List() {
		ids = append(ids, x.(map[string]any)["id"].(string))
	}
	c.Do(t, http.MethodPost, "/transactions/bulk-update", map[string]any{"transaction_ids": ids, "category_id": food, "add_tag_ids": []string{}}).Expect(t, http.StatusOK)
	prev := c.Do(t, http.MethodPost, "/categories/merge", map[string]any{"source_ids": []any{sub["id"]}, "target_id": food, "preview": true}).Expect(t, http.StatusOK).Data()
	if prev["preview"] != true {
		t.Fatal("preview flag missing")
	}
	c.Do(t, http.MethodPost, "/categories/merge", map[string]any{"source_ids": []any{sub["id"]}, "target_id": food}).Expect(t, http.StatusOK)
	if r := c.Do(t, http.MethodDelete, "/categories/"+food, nil); r.Status != http.StatusConflict {
		t.Fatalf("deleting an in-use category allowed: %s", r.Raw)
	}
	unused := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Temp", "kind": "both"}).Expect(t, http.StatusCreated).Data()
	c.Do(t, http.MethodDelete, "/categories/"+unused["id"].(string), nil).Expect(t, http.StatusOK)
	cf := c.Do(t, http.MethodGet, "/analytics/categories", nil).Expect(t, http.StatusOK).Data()["categories"].([]any)
	if len(cf) != 1 || money(cf[0].(map[string]any), "net_expense") != "1424.00" {
		t.Fatalf("category analytics after merge = %v", cf)
	}
}
