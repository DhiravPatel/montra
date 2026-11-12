package api_test

import (
	"net/http"
	"testing"

	"montra/backend/internal/insights"
	"montra/backend/internal/testutil/apitest"
)

// Mute rules can be listed; removing one (or reopening a muted insight)
// brings back what it hid; feedback is one answer per person and shows on
// the insight; the list is paged; and every insight carries localization
// codes with Money objects beside the English text.
func TestInsightMutesFeedbackPagesAndCodes(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "insightfix"))
	today := todayIn(t, "Asia/Kolkata")
	at := func(daysAgo int) string { return today.AddDate(0, 0, -daysAgo).Format(day) }
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	groceries := categoryID(t, c, "Groceries")
	for i := 1; i <= 9; i++ {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "120.00", "merchant_name": "Corner Store", "category_id": groceries,
			"local_date": at(i * 15)})
	}
	// Two identical large purchases today: two unusual amounts and a duplicate.
	for i := 0; i < 2; i++ {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "5200.00", "merchant_name": "FreshMart", "category_id": groceries})
	}
	gen := c.Do(t, http.MethodPost, "/ai/insights/generate", nil).Expect(t, http.StatusOK).Data()["insights"].([]any)
	var ua map[string]any
	unusual := 0
	for _, x := range gen {
		if m := x.(map[string]any); m["subtype"] == "unusual_amount" {
			unusual++
			if ua == nil {
				ua = m
			}
		}
	}
	if unusual != 2 || ua == nil {
		t.Fatalf("unusual amount insights: %d in %v", unusual, gen)
	}
	id := ua["id"].(string)

	// Localization: a message code with Money params, a rule code, and
	// evidence amounts as Money objects beside the deprecated strings.
	params := ua["message_params"].(map[string]any)
	amount, _ := params["amount"].(map[string]any)
	if ua["message_code"] != "unusual_amount" || ua["rule_code"] != insights.RuleCodes()["unusual_amount"] || params["category_name"] != "Groceries" ||
		amount["amount"] != "5200.00" || amount["currency"] != "INR" || amount["amount_minor"] != float64(520000) || params["history_count"] != float64(9) {
		t.Fatalf("message code/params: %v %v", ua["message_code"], params)
	}
	ev := ua["evidence"].(map[string]any)
	amounts, _ := ev["amounts"].(map[string]any)
	if ev["amount"] != "5200.00 INR" || amounts["amount"].(map[string]any)["amount_minor"] != float64(520000) ||
		amounts["baseline_median"].(map[string]any)["amount"] != "120.00" || amounts["baseline_median"].(map[string]any)["currency"] != "INR" {
		t.Fatalf("evidence amounts: %v", ev)
	}
	for _, x := range gen {
		if m := x.(map[string]any); m["rule_code"] == "" || m["message_code"] == nil {
			t.Fatalf("insight without codes: %v", m)
		}
	}

	// Feedback: one answer per person, repeating updates it, and the
	// insight shows it.
	fb := c.Do(t, http.MethodPost, "/insights/"+id+"/feedback", map[string]any{"feedback": "helpful"}).Expect(t, http.StatusOK).Data()
	if mf := fb["my_feedback"].(map[string]any); fb["id"] != id || mf["feedback"] != "helpful" || mf["note"] != nil {
		t.Fatalf("feedback: %v", fb)
	}
	fb = c.Do(t, http.MethodPost, "/insights/"+id+"/feedback", map[string]any{"feedback": "not_helpful", "note": "Expected purchase"}).Expect(t, http.StatusOK).Data()
	if mf := fb["my_feedback"].(map[string]any); mf["feedback"] != "not_helpful" || mf["note"] != "Expected purchase" || mf["updated_at"] == nil {
		t.Fatalf("updated feedback: %v", fb)
	}
	if n := workerCount(t, s, `select count(*) from insight_feedback where insight_id = $1`, id); n != 1 {
		t.Fatalf("feedback rows: %d", n)
	}
	c.Do(t, http.MethodPost, "/insights/"+id+"/actions", map[string]any{"action": "expected"}).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from insight_feedback where insight_id = $1 and feedback = 'expected'`, id); n != 1 {
		t.Fatalf("expected feedback rows: %d", n)
	}
	for _, x := range c.Do(t, http.MethodGet, "/insights?all=true", nil).Expect(t, http.StatusOK).List() {
		if m := x.(map[string]any); m["id"] == id && m["my_feedback"].(map[string]any)["feedback"] != "expected" {
			t.Fatalf("listed feedback: %v", m["my_feedback"])
		}
	}

	// Mutes: muting records a rule the list shows; removing the rule
	// reopens the insights it hid; subtype is required.
	if st := c.Do(t, http.MethodPost, "/insights/"+id+"/actions", map[string]any{"action": "mute"}).Expect(t, http.StatusOK).Data()["status"]; st != "muted" {
		t.Fatalf("mute: %v", st)
	}
	mutes := c.Do(t, http.MethodGet, "/insights/mutes", nil).Expect(t, http.StatusOK).List()
	if len(mutes) != 1 || mutes[0].(map[string]any)["subtype"] != "unusual_amount" || mutes[0].(map[string]any)["scope"] != groceries ||
		mutes[0].(map[string]any)["created_at"] == nil {
		t.Fatalf("mutes: %v", mutes)
	}
	if r := c.Do(t, http.MethodDelete, "/insights/mutes", nil); r.Status != http.StatusUnprocessableEntity || detail(t, r)["field"] != "query.subtype" {
		t.Fatalf("missing subtype: %d %s", r.Status, r.Raw)
	}
	un := c.Do(t, http.MethodDelete, "/insights/mutes?subtype=unusual_amount&scope="+groceries, nil).Expect(t, http.StatusOK).Data()
	if un["reopened"] != float64(1) || len(un["insights"].([]any)) != 1 || un["insights"].([]any)[0].(map[string]any)["id"] != id ||
		un["insights"].([]any)[0].(map[string]any)["status"] != "active" {
		t.Fatalf("unmute: %v", un)
	}
	if l := c.Do(t, http.MethodGet, "/insights/mutes", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("mutes after unmute: %v", l)
	}
	c.Do(t, http.MethodDelete, "/insights/mutes?subtype=unusual_amount&scope="+groceries, nil).Expect(t, http.StatusNotFound)

	// Reopening a muted insight removes its rule as well.
	c.Do(t, http.MethodPost, "/insights/"+id+"/actions", map[string]any{"action": "mute"}).Expect(t, http.StatusOK)
	if l := c.Do(t, http.MethodGet, "/insights/mutes", nil).Expect(t, http.StatusOK).List(); len(l) != 1 {
		t.Fatalf("mutes before reopen: %v", l)
	}
	if st := c.Do(t, http.MethodPost, "/insights/"+id+"/actions", map[string]any{"action": "reopen"}).Expect(t, http.StatusOK).Data()["status"]; st != "active" {
		t.Fatalf("reopen: %v", st)
	}
	if l := c.Do(t, http.MethodGet, "/insights/mutes", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("mutes after reopen: %v", l)
	}

	// Pages: warnings first then newest first, no repeats, every insight once.
	ids, pages := walkPages(t, c, "/insights?limit=2", "id")
	if len(ids) != len(gen) || pages != (len(gen)+1)/2 {
		t.Fatalf("paged %d insights over %d pages (want %d)", len(ids), pages, len(gen))
	}
}
