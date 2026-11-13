package api_test

import (
	"encoding/base64"
	"encoding/json"
	"net/http"
	"strings"
	"testing"

	"montra/backend/internal/testutil/apitest"
)

// Contract fixes reported by the web and mobile clients (P11 round 1):
// repeated parameters, opaque cursors, refund merchants, reason codes,
// onboarding resume, payment methods, transfers, dashboard buckets,
// category keys, uncategorized drill-down, clearing account days,
// versioned status changes and duplicate reason codes.
func TestClientContractFixes(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "contract"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	wallet := createAccount(t, c, map[string]any{"name": "Wallet", "account_type": "cash", "currency": "INR"})["id"].(string)

	// Repeated query parameters are rejected instead of silently dropped.
	r := c.Do(t, http.MethodGet, "/transactions?type=expense&type=income", nil)
	if r.Status != http.StatusUnprocessableEntity || !strings.Contains(string(r.Raw), "repeated_parameter") {
		t.Fatalf("repeated parameter: %d %s", r.Status, r.Raw)
	}
	c.Do(t, http.MethodGet, "/transactions?type=expense,income", nil).Expect(t, http.StatusOK)

	// Refunds net out of the original merchant and carry reason codes.
	groceries := categoryID(t, c, "Groceries")
	orig := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "100.00", "merchant_name": "Corner Store",
		"category_id": groceries, "description": "weekly shop"})
	refund := c.Do(t, http.MethodPost, "/transactions/"+orig["id"].(string)+"/refunds", map[string]any{"amount": "40.00"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()["transaction"].(map[string]any)
	if refund["merchant"].(map[string]any)["name"] != "Corner Store" {
		t.Fatalf("refund merchant: %v", refund["merchant"])
	}
	if ck := orig["category"].(map[string]any)["system_key"]; ck != "groceries" {
		t.Fatalf("category system key: %v", ck)
	}
	over := c.Do(t, http.MethodPost, "/transactions/"+orig["id"].(string)+"/refunds", map[string]any{"amount": "70.00"}, "Idempotency-Key", key())
	if over.Status != http.StatusUnprocessableEntity {
		t.Fatalf("refund cap: %d", over.Status)
	}
	det := over.Body["error"].(map[string]any)["details"].([]any)[0].(map[string]any)
	if det["code"] != "refund_exceeds_remaining" || det["params"].(map[string]any)["remaining"] != "60.00" {
		t.Fatalf("reason detail: %v", det)
	}

	// Cursors are opaque and tamper-evident.
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "12.00"})
	page := c.Do(t, http.MethodGet, "/transactions?limit=1", nil).Expect(t, http.StatusOK)
	cursor, _ := page.Body["meta"].(map[string]any)["next_cursor"].(string)
	raw, err := base64.RawURLEncoding.DecodeString(cursor)
	if cursor == "" || err != nil || json.Valid(raw) || strings.Contains(string(raw), "local_date") {
		t.Fatalf("cursor is not opaque: %q", raw)
	}
	c.Do(t, http.MethodGet, "/transactions?limit=1&cursor="+cursor, nil).Expect(t, http.StatusOK)
	bad := []byte(cursor)
	bad[len(bad)/2] ^= 1
	c.Do(t, http.MethodGet, "/transactions?limit=1&cursor="+string(bad), nil).Expect(t, http.StatusUnprocessableEntity)

	// Duplicate hints carry codes.
	dupBody := map[string]any{"type": "expense", "account_id": acct, "amount": "55.00", "description": "parking"}
	createTx(t, c, dupBody)
	res := c.Do(t, http.MethodPost, "/transactions", dupBody, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	hints := res["possible_duplicates"].([]any)
	if len(hints) != 1 {
		t.Fatalf("duplicate hints: %v", hints)
	}
	codes := hints[0].(map[string]any)["reason_codes"].([]any)
	if codes[0] != "same_account_amount" || codes[1] != "same_date" || codes[2] != "same_description" {
		t.Fatalf("duplicate reason codes: %v", codes)
	}

	// Uncategorized drill-down and dashboard buckets.
	today := todayIn(t, "Asia/Kolkata")
	from := today.AddDate(0, 0, -6).Format(day)
	dash := c.Do(t, http.MethodGet, "/dashboard/summary?from="+from+"&to="+today.Format(day), nil).Expect(t, http.StatusOK).Data()
	if dash["trend_granularity"] != "day" || len(dash["trend"].([]any)) != 7 || len(dash["note_codes"].([]any)) != 4 {
		t.Fatalf("dashboard trend: granularity=%v points=%d notes=%v", dash["trend_granularity"], len(dash["trend"].([]any)), dash["note_codes"])
	}
	var uncategorized map[string]any
	for _, x := range dash["top_categories"].([]any) {
		if x.(map[string]any)["system_key"] == "uncategorized" {
			uncategorized = x.(map[string]any)
		}
	}
	// The drill-down lists only counted spending (never opening balances,
	// transfers or adjustments).
	if uncategorized == nil || !strings.Contains(uncategorized["drill_down_path"].(string), "uncategorized=true") ||
		!strings.Contains(uncategorized["drill_down_path"].(string), "type=expense,group_expense,refund,reimbursement") {
		t.Fatalf("uncategorized slice: %v", dash["top_categories"])
	}
	for _, x := range c.Do(t, http.MethodGet, "/transactions?uncategorized=true&limit=100", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["category"] != nil {
			t.Fatalf("uncategorized filter returned a categorized row: %v", x)
		}
	}
	c.Do(t, http.MethodGet, "/transactions?uncategorized=true&category_id="+groceries, nil).Expect(t, http.StatusUnprocessableEntity)

	// Onboarding progress merges and can be read back.
	c.Do(t, http.MethodPost, "/me/onboarding", map[string]any{"completed_steps": []any{"welcome"}, "skipped_steps": []any{"privacy"}, "complete": false}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/me/onboarding", map[string]any{"completed_steps": []any{"privacy"}, "skipped_steps": []any{}, "complete": false}).Expect(t, http.StatusOK)
	ob := c.Do(t, http.MethodGet, "/me/onboarding", nil).Expect(t, http.StatusOK).Data()
	if done := ob["completed_steps"].([]any); len(done) != 2 || done[0] != "welcome" || done[1] != "privacy" || len(ob["skipped_steps"].([]any)) != 0 {
		t.Fatalf("onboarding: %v", ob)
	}

	// Payment methods: partial PATCH with version, get, delete result, restore.
	pm := c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "credit_card", "label": "Travel card", "masked_hint": "4821",
		"network": "visa"}).Expect(t, http.StatusCreated).Data()
	pmID := pm["id"].(string)
	up := c.Do(t, http.MethodPatch, "/payment-methods/"+pmID, map[string]any{"label": "Travel Visa", "version": pm["version"]}).Expect(t, http.StatusOK).Data()
	if up["label"] != "Travel Visa" || up["network"] != "visa" || up["masked_hint"] != "4821" || up["kind"] != "credit_card" {
		t.Fatalf("partial patch cleared fields: %v", up)
	}
	stale := c.Do(t, http.MethodPatch, "/payment-methods/"+pmID, map[string]any{"label": "Old", "version": pm["version"]})
	if stale.Status != http.StatusConflict || stale.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale patch: %d %s", stale.Status, stale.Raw)
	}
	c.Do(t, http.MethodPatch, "/payment-methods/"+pmID, map[string]any{"masked_hint": "", "network": ""}).Expect(t, http.StatusOK)
	if got := c.Do(t, http.MethodGet, "/payment-methods/"+pmID, nil).Expect(t, http.StatusOK).Data(); got["masked_hint"] != nil || got["network"] != nil {
		t.Fatalf("clearing fields: %v", got)
	}
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "9.00", "payment_method_id": pmID})
	if d := c.Do(t, http.MethodDelete, "/payment-methods/"+pmID, nil).Expect(t, http.StatusOK).Data(); d["archived"] != true || d["deleted"] != false {
		t.Fatalf("delete used method: %v", d)
	}
	if rs := c.Do(t, http.MethodPost, "/payment-methods/"+pmID+"/restore", nil).Expect(t, http.StatusOK).Data(); rs["archived_at"] != nil {
		t.Fatalf("restore: %v", rs)
	}
	unused := c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "cash", "label": "Pocket"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	if d := c.Do(t, http.MethodDelete, "/payment-methods/"+unused, nil).Expect(t, http.StatusOK).Data(); d["deleted"] != true {
		t.Fatalf("delete unused method: %v", d)
	}

	// Transfers: date/description in the DTO, delete and restore as a unit.
	tr := c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": acct, "to_account_id": wallet, "amount": "300.00",
		"fee": "5.00", "description": "ATM", "local_date": today.Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	trID := tr["id"].(string)
	if tr["local_date"] != today.Format(day) || tr["description"] != "ATM" {
		t.Fatalf("transfer fields: %v", tr)
	}
	before := balance(t, c, acct)
	if v := c.Do(t, http.MethodDelete, "/transactions/transfers/"+trID, nil).Expect(t, http.StatusOK).Data(); v["status"] != "voided" {
		t.Fatalf("transfer delete: %v", v)
	}
	if balance(t, c, wallet) != "0.00" {
		t.Fatalf("wallet after transfer delete: %s", balance(t, c, wallet))
	}
	if v := c.Do(t, http.MethodPost, "/transactions/transfers/"+trID+"/restore", nil).Expect(t, http.StatusOK).Data(); v["status"] != "posted" {
		t.Fatalf("transfer restore: %v", v)
	}
	if balance(t, c, acct) != before || balance(t, c, wallet) != "300.00" {
		t.Fatalf("balances after restore: %s %s", balance(t, c, acct), balance(t, c, wallet))
	}

	// Accounts: 0 clears statement/due days; status changes honour version.
	card := createAccount(t, c, map[string]any{"name": "Card", "account_type": "credit_card", "currency": "INR", "statement_day": 5, "payment_due_day": 20})
	cleared := c.Do(t, http.MethodPatch, "/accounts/"+card["id"].(string), map[string]any{"statement_day": 0, "payment_due_day": 0, "version": card["version"]}).
		Expect(t, http.StatusOK).Data()
	if cleared["statement_day"] != nil || cleared["payment_due_day"] != nil {
		t.Fatalf("clearing account days: %v", cleared)
	}
	c.Do(t, http.MethodPost, "/accounts/"+card["id"].(string)+"/archive?version=1", nil).Expect(t, http.StatusConflict)
	c.Do(t, http.MethodPost, "/accounts/"+card["id"].(string)+"/archive?version=2", nil).Expect(t, http.StatusOK)
}
