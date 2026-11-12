package api_test

import (
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/testutil/apitest"
)

// Subscriptions and goals fixes reported by the web and mobile clients:
// partial updates, coded texts, response enums, payment links, owner
// identity, recording planned contributions, CSV export and status rules.

func sgDetail(t *testing.T, r *apitest.Response) map[string]any {
	t.Helper()
	e, _ := r.Body["error"].(map[string]any)
	d, _ := e["details"].([]any)
	if len(d) == 0 {
		t.Fatalf("no error details: %d %s", r.Status, r.Raw)
	}
	return d[0].(map[string]any)
}

func sgEvents(x map[string]any, kind string) []map[string]any {
	var out []map[string]any
	for _, e := range x["events"].([]any) {
		if m := e.(map[string]any); m["kind"] == kind {
			out = append(out, m)
		}
	}
	return out
}

func sgCreateSub(t *testing.T, c *apitest.Client, body map[string]any) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodPost, "/subscriptions", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
}

func sgCreateGoal(t *testing.T, c *apitest.Client, body map[string]any) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodPost, "/goals", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
}

func sgVersion(x map[string]any) string { return strconv.Itoa(int(x["version"].(float64))) }

func TestSubscriptionPatchKeepsOmittedFields(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "subpatch"))
	acct := createAccount(t, c, map[string]any{"name": "Card", "account_type": "bank", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	today := todayIn(t, "Asia/Kolkata")
	manual := today.AddDate(0, 0, 9).Format(day)
	body := map[string]any{"name": "Melodia", "plan_name": "Family", "merchant_name": "Melodia Music", "amount": "199", "billing_frequency": "monthly",
		"start_date": today.AddDate(0, -2, 0).Format(day), "next_renewal_date": manual, "payment_account_id": acct,
		"cancellation_url": "https://melodia.example/cancel", "notes": "shared with family", "reminder_days_before": []int{1, 7},
		"cancellation_checklist": []map[string]any{{"item": "Open settings", "done": false}, {"item": "Cancel the plan", "done": false}}}

	// Creating needs an Idempotency-Key; a retry replays the original.
	if r := c.Do(t, http.MethodPost, "/subscriptions", body); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("create without Idempotency-Key: %d %s", r.Status, r.Raw)
	}
	k := key()
	sub := c.Do(t, http.MethodPost, "/subscriptions", body, "Idempotency-Key", k).Expect(t, http.StatusCreated).Data()
	sid := sub["id"].(string)
	again := c.Do(t, http.MethodPost, "/subscriptions", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	if again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["id"] != sid {
		t.Fatalf("create replay: %s", again.Raw)
	}
	if n := len(c.Do(t, http.MethodGet, "/subscriptions", nil).Expect(t, http.StatusOK).List()); n != 1 {
		t.Fatalf("replayed create added a subscription: %d", n)
	}

	// Only the notes change; merchant, account, checklist, URL, reminders and
	// the manual renewal date are kept.
	got := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"notes": "just me now"}).Expect(t, http.StatusOK).Data()
	if got["notes"] != "just me now" || got["plan_name"] != "Family" || got["merchant"] == nil || got["payment_account_id"] != acct ||
		got["cancellation_url"] != "https://melodia.example/cancel" || len(got["cancellation_checklist"].([]any)) != 2 ||
		fmt.Sprint(got["reminder_days_before"]) != "[1 7]" || got["next_renewal_date"] != manual || got["version"] != sub["version"].(float64)+1 {
		t.Fatalf("partial patch changed other fields: %v", got)
	}
	if ev := got["events"].([]any)[0].(map[string]any); ev["kind"] != "edited" {
		t.Fatalf("latest event = %v", ev)
	}
	// version is optional; a stale one is rejected.
	if r := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"notes": "x", "version": sub["version"]}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale patch: %s", r.Raw)
	}
	// A field cannot be both sent and cleared.
	if r := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"payment_account_id": acct, "clear": []string{"payment_account_id"}}); r.ErrorCode() != "VALIDATION_ERROR" ||
		!strings.Contains(string(r.Raw), "body.clear") {
		t.Fatalf("send and clear: %s", r.Raw)
	}
	// Empty strings clear text; clear removes links.
	cl := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"plan_name": "", "merchant_name": "", "cancellation_url": "",
		"cancellation_checklist": []any{}, "clear": []string{"payment_account_id"}, "version": got["version"]}).Expect(t, http.StatusOK).Data()
	if cl["plan_name"] != nil || cl["merchant"] != nil || cl["cancellation_url"] != nil || len(cl["cancellation_checklist"].([]any)) != 0 ||
		cl["payment_account_id"] != nil || cl["notes"] != "just me now" || cl["next_renewal_date"] != manual {
		t.Fatalf("clearing: %v", cl)
	}
	// A schedule change recomputes the renewal date unless one is sent; an
	// empty string recomputes it on request.
	yr := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"billing_frequency": "yearly"}).Expect(t, http.StatusOK).Data()
	if yr["billing_frequency"] != "yearly" || yr["next_renewal_date"] == manual || yr["next_renewal_date"] == nil || money(yr, "annual_cost") != "199.00" {
		t.Fatalf("schedule change: %v / %v", yr["billing_frequency"], yr["next_renewal_date"])
	}
	if x := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"next_renewal_date": manual}).Expect(t, http.StatusOK).Data(); x["next_renewal_date"] != manual {
		t.Fatalf("explicit renewal date: %v", x["next_renewal_date"])
	}
	if x := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"next_renewal_date": ""}).Expect(t, http.StatusOK).Data(); x["next_renewal_date"] == manual ||
		x["next_renewal_date"] == nil {
		t.Fatalf("recomputed renewal date: %v", x["next_renewal_date"])
	}
	// A different currency needs the price in that currency, and is not a
	// price change in the history.
	if r := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"currency": "USD"}); r.ErrorCode() != "VALIDATION_ERROR" ||
		!strings.Contains(string(r.Raw), "body.amount") {
		t.Fatalf("currency without amount: %s", r.Raw)
	}
	usd := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"currency": "USD", "amount": "4.99"}).Expect(t, http.StatusOK).Data()
	if usd["amount"].(map[string]any)["currency"] != "USD" || money(usd, "amount") != "4.99" || usd["events"].([]any)[0].(map[string]any)["kind"] != "edited" {
		t.Fatalf("currency change: %v", usd["amount"])
	}
	// A client that sends the full record keeps working; a price change is
	// kept in the history.
	full := map[string]any{"version": usd["version"], "currency": "USD", "amount": "5.99"}
	for k, v := range body {
		if k != "amount" {
			full[k] = v
		}
	}
	f := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, full).Expect(t, http.StatusOK).Data()
	ev := f["events"].([]any)[0].(map[string]any)
	if ev["kind"] != "price_changed" || money(ev, "old_amount") != "4.99" || money(ev, "new_amount") != "5.99" || f["plan_name"] != "Family" ||
		f["payment_account_id"] != acct || f["merchant"].(map[string]any)["name"] != "Melodia Music" || f["next_renewal_date"] != manual ||
		f["billing_frequency"] != "monthly" {
		t.Fatalf("full-record update: %v", f)
	}
	// cancelled_on is for cancelled subscriptions only.
	r := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"cancelled_on": today.Format(day)})
	if r.ErrorCode() != "DOMAIN_RULE_VIOLATION" || sgDetail(t, r)["code"] != "subscription_not_cancelled" {
		t.Fatalf("cancelled_on on an active subscription: %s", r.Raw)
	}
	// Other users cannot patch it.
	other, _ := s.Login(t, s.Register(t, "subpatchsnoop"))
	other.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"notes": "mine"}).Expect(t, http.StatusNotFound)
}

func TestSubscriptionCodesCancellationDateAndChecklist(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "subcodes"))
	today := todayIn(t, "Asia/Kolkata")
	sub := sgCreateSub(t, c, map[string]any{"name": "NewsDaily", "amount": "149", "billing_frequency": "monthly", "start_date": today.AddDate(0, -1, 0).Format(day),
		"cancellation_checklist": []map[string]any{{"item": "Find the cancel page", "done": false}, {"item": "Confirm by email", "done": false}}})
	sid := sub["id"].(string)

	// Checklist items are ticked one at a time.
	ck := c.Do(t, http.MethodPatch, "/subscriptions/"+sid+"/cancellation-checklist/1", map[string]any{"done": true}).Expect(t, http.StatusOK).Data()
	items := ck["cancellation_checklist"].([]any)
	if items[1].(map[string]any)["done"] != true || items[0].(map[string]any)["done"] != false || ck["version"] != sub["version"].(float64)+1 {
		t.Fatalf("checklist item: %v", items)
	}
	c.Do(t, http.MethodPatch, "/subscriptions/"+sid+"/cancellation-checklist/5", map[string]any{"done": true}).Expect(t, http.StatusNotFound)
	if r := c.Do(t, http.MethodPatch, "/subscriptions/"+sid+"/cancellation-checklist/0", map[string]any{"done": true, "version": sub["version"]}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale checklist update: %s", r.Raw)
	}

	// Lifecycle actions take an optional ?version=.
	if r := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/pause?version="+sgVersion(sub), nil); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale pause: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/pause?version="+sgVersion(ck), nil).Expect(t, http.StatusOK)
	if r := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/resume", map[string]any{"cancelled_on": today.Format(day)}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("cancelled_on on resume: %s", r.Raw)
	}

	// Cancellation needs the user's confirmation (coded field error).
	r := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancelled", map[string]any{})
	if d := sgDetail(t, r); r.ErrorCode() != "VALIDATION_ERROR" || d["code"] != "cancellation_confirmation_required" || d["field"] != "body.confirm" {
		t.Fatalf("unconfirmed cancellation: %s", r.Raw)
	}
	on := today.AddDate(0, 0, -3).Format(day)
	cx := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancelled", map[string]any{"confirm": true, "cancelled_on": on}).Expect(t, http.StatusOK).Data()
	at, err := time.Parse(time.RFC3339, cx["cancelled_at"].(string))
	if err != nil || cx["cancelled_on"] != on || at.UTC().Format(day) != on || cx["status"] != "cancelled" || cx["next_renewal_date"] != nil {
		t.Fatalf("cancelled: on=%v at=%v status=%v", cx["cancelled_on"], cx["cancelled_at"], cx["status"])
	}
	// The cancellation date can be corrected later.
	fixed := today.AddDate(0, 0, -4).Format(day)
	if x := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, map[string]any{"cancelled_on": fixed}).Expect(t, http.StatusOK).Data(); x["cancelled_on"] != fixed ||
		x["status"] != "cancelled" || x["next_renewal_date"] != nil {
		t.Fatalf("corrected cancellation date: %v %v %v", x["cancelled_on"], x["status"], x["next_renewal_date"])
	}
	// A transition that is not allowed is the shared coded rule.
	r = c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/pause", nil)
	d := sgDetail(t, r)
	if r.Status != http.StatusUnprocessableEntity || d["code"] != "invalid_status_transition" ||
		fmt.Sprint(d["params"]) != "map[from:cancelled to:paused]" {
		t.Fatalf("invalid transition: %d %s", r.Status, r.Raw)
	}

	// Duplicate warnings carry a stable reason code.
	sgCreateSub(t, c, map[string]any{"name": "VideoMax", "merchant_name": "VideoMax Ltd", "amount": "500", "billing_frequency": "monthly",
		"start_date": today.Format(day)})
	reasons := func(x map[string]any) string {
		var out []string
		for _, w := range x["duplicate_warnings"].([]any) {
			m := w.(map[string]any)
			out = append(out, m["name"].(string)+"="+m["reason_code"].(string)+"/"+m["reason"].(string))
		}
		return strings.Join(out, ",")
	}
	b := sgCreateSub(t, c, map[string]any{"name": "Streams", "merchant_name": "VideoMax Ltd", "amount": "300", "billing_frequency": "monthly",
		"start_date": today.Format(day)})
	cc := sgCreateSub(t, c, map[string]any{"name": "videomax", "amount": "200", "billing_frequency": "weekly", "start_date": today.Format(day)})
	dd := sgCreateSub(t, c, map[string]any{"name": "Cloud drive", "amount": "500", "billing_frequency": "monthly", "start_date": today.Format(day)})
	if reasons(b) != "VideoMax=same_merchant/Same merchant" || reasons(cc) != "VideoMax=same_name/Same name" ||
		reasons(dd) != "VideoMax=same_price_and_cycle/Same price and billing cycle" {
		t.Fatalf("duplicate reasons: %q %q %q", reasons(b), reasons(cc), reasons(dd))
	}
}

func TestSubscriptionPaymentCandidatesLinkAndUnlink(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "sublinks"))
	today := todayIn(t, "Asia/Kolkata")
	acct := createAccount(t, c, map[string]any{"name": "Card", "account_type": "bank", "currency": "INR", "opening_balance": "50000",
		"opening_date": today.AddDate(0, -3, 0).Format(day)})["id"].(string)
	sub := sgCreateSub(t, c, map[string]any{"name": "StreamBox", "merchant_name": "StreamBox", "amount": "499", "billing_frequency": "monthly",
		"start_date": today.AddDate(0, -2, 0).Format(day), "payment_account_id": acct})
	sid := sub["id"].(string)
	tx := func(merchant, amount string, daysAgo int) string {
		return createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": amount, "merchant_name": merchant,
			"local_date": today.AddDate(0, 0, -daysAgo).Format(day)})["id"].(string)
	}
	exact, other, cafe := tx("StreamBox", "499", 1), tx("StreamBox", "520", 2), tx("Corner Cafe", "480", 1)
	tx("Grocer", "120", 1) // unrelated: different merchant and price

	candidates := func() []map[string]any {
		var out []map[string]any
		for _, x := range c.Do(t, http.MethodGet, "/subscriptions/"+sid+"/payment-candidates", nil).Expect(t, http.StatusOK).List() {
			out = append(out, x.(map[string]any))
		}
		return out
	}
	ids := func(list []map[string]any) []string {
		var out []string
		for _, x := range list {
			out = append(out, x["transaction_id"].(string))
		}
		return out
	}
	cands := candidates()
	if fmt.Sprint(ids(cands)) != fmt.Sprint([]string{exact, other, cafe}) {
		t.Fatalf("candidates (same merchant first, then closest amount) = %v", cands)
	}
	if fmt.Sprint(cands[0]["reason_codes"]) != "[same_merchant same_amount near_renewal_date]" && fmt.Sprint(cands[0]["reason_codes"]) != "[same_merchant same_amount on_renewal_date]" {
		t.Fatalf("reasons of the exact charge: %v", cands[0]["reason_codes"])
	}
	if fmt.Sprint(cands[1]["reason_codes"].([]any)[:2]) != "[same_merchant amount_close]" || fmt.Sprint(cands[2]["reason_codes"].([]any)[0]) != "amount_close" ||
		len(cands[0]["reasons"].([]any)) != len(cands[0]["reason_codes"].([]any)) || cands[0]["expected_date"] == nil || cands[0]["days_from_renewal"] == nil {
		t.Fatalf("candidate details: %v", cands)
	}

	link := func(id string, txID string, body map[string]any) *apitest.Response {
		if body == nil {
			body = map[string]any{}
		}
		body["transaction_id"] = txID
		return c.Do(t, http.MethodPost, "/subscriptions/"+id+"/payments", body, "Idempotency-Key", key())
	}
	d := link(sid, exact, nil).Expect(t, http.StatusCreated).Data()
	if d["last_payment"].(map[string]any)["transaction_id"] != exact {
		t.Fatalf("last payment: %v", d["last_payment"])
	}
	// Regression: update_price with a different amount used to fail (500)
	// and save nothing.
	d = link(sid, other, map[string]any{"update_price": true}).Expect(t, http.StatusCreated).Data()
	pc := sgEvents(d, "price_changed")
	if money(d, "amount") != "520.00" || len(pc) != 1 || pc[0]["transaction_id"] != other || money(pc[0], "old_amount") != "499.00" ||
		len(sgEvents(d, "payment_recorded")) != 2 {
		t.Fatalf("payment with price update: %v", d)
	}
	if fmt.Sprint(ids(candidates())) != fmt.Sprint([]string{cafe}) {
		t.Fatalf("linked transactions are still suggested: %v", ids(candidates()))
	}

	// Unlinking keeps the history and frees the transaction.
	u := c.Do(t, http.MethodDelete, "/subscriptions/"+sid+"/payments/"+exact, nil).Expect(t, http.StatusOK).Data()
	ul := sgEvents(u, "payment_unlinked")
	if len(ul) != 1 || ul[0]["transaction_id"] != exact || money(ul[0], "new_amount") != "499.00" || len(sgEvents(u, "payment_recorded")) != 2 ||
		u["last_payment"].(map[string]any)["transaction_id"] != other {
		t.Fatalf("unlink: %v", u)
	}
	c.Do(t, http.MethodDelete, "/subscriptions/"+sid+"/payments/"+exact, nil).Expect(t, http.StatusNotFound)
	if got := ids(candidates()); len(got) == 0 || got[0] != exact {
		t.Fatalf("unlinked transaction is not suggested again: %v", got)
	}
	link(sid, exact, nil).Expect(t, http.StatusCreated) // linking again works

	// A transaction backs one subscription payment; the reason is coded.
	sub2 := sgCreateSub(t, c, map[string]any{"name": "Kids corner", "amount": "499", "billing_frequency": "monthly", "start_date": today.Format(day)})
	r := link(sub2["id"].(string), exact, nil)
	if r.ErrorCode() != "DUPLICATE" || sgDetail(t, r)["code"] != "payment_linked_elsewhere" {
		t.Fatalf("payment of another subscription: %s", r.Raw)
	}
	if r := link(sid, exact, nil); r.ErrorCode() != "DUPLICATE" || sgDetail(t, r)["code"] != "payment_already_linked" {
		t.Fatalf("payment linked twice: %s", r.Raw)
	}
	c.Do(t, http.MethodDelete, "/subscriptions/"+sid+"/payments/"+exact, nil).Expect(t, http.StatusOK)
	link(sub2["id"].(string), exact, nil).Expect(t, http.StatusCreated)

	// Owner only; cancelled subscriptions get no suggestions.
	snoop, _ := s.Login(t, s.Register(t, "sublinksnoop"))
	snoop.Do(t, http.MethodGet, "/subscriptions/"+sid+"/payment-candidates", nil).Expect(t, http.StatusNotFound)
	snoop.Do(t, http.MethodDelete, "/subscriptions/"+sid+"/payments/"+other, nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancelled", map[string]any{"confirm": true}).Expect(t, http.StatusOK)
	if n := len(candidates()); n != 0 {
		t.Fatalf("cancelled subscription candidates = %d", n)
	}
}

func TestSubscriptionDetectionScoreAndReasonCodes(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "subdetect"))
	today := todayIn(t, "Asia/Kolkata")
	acct := createAccount(t, c, map[string]any{"name": "Card", "account_type": "bank", "currency": "INR", "opening_balance": "90000",
		"opening_date": today.AddDate(0, -6, 0).Format(day)})["id"].(string)
	var charges []string
	for i := 3; i >= 0; i-- {
		charges = append(charges, createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "119", "merchant_name": "Tunely",
			"local_date": today.AddDate(0, 0, -30*i).Format(day)})["id"].(string))
	}
	// One charge is already a payment of another subscription.
	manual := sgCreateSub(t, c, map[string]any{"name": "Old plan", "amount": "119", "billing_frequency": "monthly", "start_date": today.AddDate(0, -4, 0).Format(day)})
	c.Do(t, http.MethodPost, "/subscriptions/"+manual["id"].(string)+"/payments", map[string]any{"transaction_id": charges[0]}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)

	c.Do(t, http.MethodPost, "/subscriptions/detections/refresh", nil).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	var cand map[string]any
	for _, x := range c.Do(t, http.MethodGet, "/subscriptions/detections", nil).Expect(t, http.StatusOK).List() {
		if m := x.(map[string]any); m["merchant_label"] == "Tunely" {
			cand = m
		}
	}
	if cand == nil {
		t.Fatal("no detection for the monthly charges")
	}
	conf, err := strconv.ParseFloat(cand["confidence"].(string), 64)
	bp := cand["confidence_bp"].(float64)
	if err != nil || bp < 6000 || bp > 10000 || bp != math.Round(conf*10000) {
		t.Fatalf("confidence %v vs confidence_bp %v", cand["confidence"], cand["confidence_bp"])
	}
	ev := cand["evidence"].(map[string]any)
	if fmt.Sprint(ev["reason_codes"]) != "[charge_cadence intervals_fit_cadence amounts_within_tolerance]" || len(ev["reasons"].([]any)) != 3 ||
		ev["intervals_in_cycle"] != float64(3) || ev["amounts_within_tolerance"] != float64(4) || ev["amount_tolerance_bp"] != float64(500) ||
		ev["charge_count"] != float64(4) {
		t.Fatalf("evidence: %v", ev)
	}
	conf2 := c.Do(t, http.MethodPost, "/subscriptions/detections/"+cand["id"].(string)+"/confirm", map[string]any{}).Expect(t, http.StatusCreated).Data()
	payments := sgEvents(conf2, "payment_recorded")
	if len(payments) != 3 {
		t.Fatalf("confirmed payments = %d, want 3 (one charge belongs to another subscription)", len(payments))
	}
	for _, p := range payments {
		if p["note_code"] != "matched_by_detection" || p["note"] != "Matched by detection" || p["transaction_id"] == charges[0] {
			t.Fatalf("detection payment: %v", p)
		}
	}
	r := c.Do(t, http.MethodPost, "/subscriptions/detections/"+cand["id"].(string)+"/confirm", map[string]any{})
	if r.Status != http.StatusConflict || sgDetail(t, r)["code"] != "detection_already_decided" {
		t.Fatalf("second confirm: %s", r.Raw)
	}
}

func TestGoalPatchKeepsOmittedFields(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "goalpatch"))
	acct := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	today := todayIn(t, "Asia/Kolkata")
	target := today.AddDate(0, 8, 0).Format(day)
	body := map[string]any{"name": "Bike", "goal_type": "vehicle", "target_amount": "10000", "starting_amount": "500", "target_date": target,
		"description": "commuter bike", "notes": "ask about the discount", "contribution_schedule": "monthly", "planned_contribution": "100",
		"reminders_enabled": true, "linked_account_id": acct, "milestones": []map[string]any{{"percent": 10, "label": "first tenth"}, {"percent": 60}}}
	k := key()
	g := c.Do(t, http.MethodPost, "/goals", body, "Idempotency-Key", k).Expect(t, http.StatusCreated).Data()
	gid := g["id"].(string)
	if r := c.Do(t, http.MethodPost, "/goals", body, "Idempotency-Key", k).Expect(t, http.StatusCreated); r.Headers.Get("Idempotent-Replayed") != "true" ||
		r.Data()["id"] != gid {
		t.Fatalf("goal create replay: %s", r.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/goals", body); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("goal create without Idempotency-Key: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/goals/"+gid+"/contributions", map[string]any{"amount": "600"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	g = c.Do(t, http.MethodGet, "/goals/"+gid, nil).Expect(t, http.StatusOK).Data()
	reached := g["milestones"].([]any)[0].(map[string]any)["reached_at"]
	if reached == nil {
		t.Fatalf("10%% milestone not reached: %v", g["milestones"])
	}

	// Only the name changes: milestones (with their reached dates), the
	// starting amount, schedule, reminders and links are kept.
	got := c.Do(t, http.MethodPatch, "/goals/"+gid, map[string]any{"name": "Road bike"}).Expect(t, http.StatusOK).Data()
	ms := got["milestones"].([]any)
	if got["name"] != "Road bike" || len(ms) != 2 || ms[0].(map[string]any)["reached_at"] != reached || ms[0].(map[string]any)["label"] != "first tenth" ||
		money(got, "starting") != "500.00" || got["contribution_schedule"] != "monthly" || money(got, "planned_contribution") != "100.00" ||
		got["reminders_enabled"] != true || got["linked_account_id"] != acct || got["description"] != "commuter bike" || got["target_date"] != target {
		t.Fatalf("partial goal patch changed other fields: %v", got)
	}
	if r := c.Do(t, http.MethodPatch, "/goals/"+gid, map[string]any{"name": "x", "version": g["version"]}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale goal patch: %s", r.Raw)
	}
	if r := c.Do(t, http.MethodPatch, "/goals/"+gid, map[string]any{"linked_account_id": acct, "clear": []string{"linked_account_id"}}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("send and clear: %s", r.Raw)
	}
	cl := c.Do(t, http.MethodPatch, "/goals/"+gid, map[string]any{"description": "", "target_date": "", "clear": []string{"linked_account_id"},
		"version": got["version"]}).Expect(t, http.StatusOK).Data()
	if cl["description"] != nil || cl["target_date"] != nil || cl["linked_account_id"] != nil || cl["notes"] != "ask about the discount" {
		t.Fatalf("goal clearing: %v", cl)
	}
	if r := c.Do(t, http.MethodPatch, "/goals/"+gid, map[string]any{"planned_contribution": ""}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("clearing the plan of a scheduled goal: %s", r.Raw)
	}
	if x := c.Do(t, http.MethodPatch, "/goals/"+gid, map[string]any{"contribution_schedule": "none", "planned_contribution": ""}).Expect(t, http.StatusOK).Data(); x["planned_contribution"] != nil ||
		x["contribution_schedule"] != "none" {
		t.Fatalf("clearing the plan: %v", x)
	}
	if r := c.Do(t, http.MethodPatch, "/goals/"+gid, map[string]any{"currency": "USD"}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("goal currency change: %s", r.Raw)
	}
	// The full record (the create shape plus version) still works.
	full := map[string]any{}
	for k, v := range body {
		full[k] = v
	}
	full["currency"], full["target_amount"], full["version"] = "INR", "12000", c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data()["version"]
	f := c.Do(t, http.MethodPatch, "/goals/"+gid, full).Expect(t, http.StatusOK).Data()
	if money(f, "target") != "12000.00" || f["name"] != "Bike" || f["linked_account_id"] != acct || len(f["milestones"].([]any)) != 2 {
		t.Fatalf("full-record goal update: %v", f)
	}
	if x := c.Do(t, http.MethodPatch, "/goals/"+gid, map[string]any{"milestones": []any{}}).Expect(t, http.StatusOK).Data(); len(x["milestones"].([]any)) != 0 {
		t.Fatalf("removing milestones: %v", x["milestones"])
	}
}

func TestGoalOwnerVisibilityRecordedPlansExportAndStatus(t *testing.T) {
	s := apitest.New(t, nil)
	ownerAddr, mateAddr := s.Register(t, "goalowner"), s.Register(t, "goalmate")
	c, _ := s.Login(t, ownerAddr)
	mate, _ := s.Login(t, mateAddr)
	owner, mateID := userID(t, s, ownerAddr), userID(t, s, mateAddr)
	grp := uuid.New()
	s.Env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Savers','friends','INR','Asia/Kolkata')`, grp, owner)
	s.Env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, grp, owner, mateID)
	today := todayIn(t, "Asia/Kolkata")
	acct := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR", "opening_balance": "20000"})["id"].(string)
	g := sgCreateGoal(t, c, map[string]any{"name": "Cabin trip", "goal_type": "travel", "target_amount": "10000"})
	gid := g["id"].(string)
	add := c.Do(t, http.MethodPost, "/goals/"+gid+"/members?version="+sgVersion(g), map[string]any{"user_id": mateID, "role": "contributor"}).Expect(t, http.StatusOK).Data()

	// Owner identity: owner_user_id, a minimal owner ref, and the owner as
	// the first member.
	for _, view := range []map[string]any{add, mate.Do(t, http.MethodGet, "/goals/"+gid, nil).Expect(t, http.StatusOK).Data()} {
		m0 := view["members"].([]any)[0].(map[string]any)
		if view["owner_user_id"] != owner.String() || view["owner"].(map[string]any)["user_id"] != owner.String() ||
			view["owner"].(map[string]any)["display_name"] != "Test goalowner" || m0["role"] != "owner" || m0["user_id"] != owner.String() ||
			m0["contribution_visibility"] != "amounts" || len(view["members"].([]any)) != 2 {
			t.Fatalf("owner identity: %v / %v", view["owner"], view["members"])
		}
	}
	contribute := func(cl *apitest.Client, body map[string]any) *apitest.Response {
		return cl.Do(t, http.MethodPost, "/goals/"+gid+"/contributions", body, "Idempotency-Key", key())
	}
	mine := contribute(c, map[string]any{"amount": "1000", "note": "=HYPERLINK(\"x\")"}).Expect(t, http.StatusCreated).Data()
	seen := func(cl *apitest.Client, id string) map[string]any {
		for _, x := range cl.Do(t, http.MethodGet, "/goals/"+gid+"/contributions", nil).Expect(t, http.StatusOK).List() {
			if m := x.(map[string]any); m["id"] == id {
				return m
			}
		}
		return nil
	}
	if m := seen(mate, mine["id"].(string)); m == nil || money(m, "amount") != "1000.00" {
		t.Fatalf("mate view of the owner's contribution: %v", m)
	}
	// The owner sets their own visibility through the member endpoint.
	if r := c.Do(t, http.MethodPatch, "/goals/"+gid+"/members/"+owner.String()+"?version=99", map[string]any{"contribution_visibility": "percent_only"}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale member update: %s", r.Raw)
	}
	pv := c.Do(t, http.MethodPatch, "/goals/"+gid+"/members/"+owner.String(), map[string]any{"contribution_visibility": "percent_only"}).Expect(t, http.StatusOK).Data()
	if pv["members"].([]any)[0].(map[string]any)["contribution_visibility"] != "percent_only" {
		t.Fatalf("owner visibility: %v", pv["members"])
	}
	if m := seen(mate, mine["id"].(string)); m == nil || m["amount"] != nil || m["percent_bp"] != float64(1000) || m["note"] != nil {
		t.Fatalf("percent-only owner contribution as seen by the mate: %v", m)
	}
	if m := seen(c, mine["id"].(string)); m == nil || money(m, "amount") != "1000.00" {
		t.Fatalf("owner's own view: %v", m)
	}
	c.Do(t, http.MethodPatch, "/goals/"+gid+"/members/"+owner.String(), map[string]any{"contribution_visibility": "hidden"}).Expect(t, http.StatusOK)
	if m := seen(mate, mine["id"].(string)); m != nil {
		t.Fatalf("hidden owner contribution is visible to the mate: %v", m)
	}
	if p := mate.Do(t, http.MethodGet, "/goals/"+gid, nil).Data()["progress"].(map[string]any); money(p, "saved") != "1000.00" {
		t.Fatalf("hidden contributions still count: %v", p)
	}
	for _, x := range []struct {
		cl   *apitest.Client
		do   func(*apitest.Client) *apitest.Response
		code string
	}{
		{mate, func(cl *apitest.Client) *apitest.Response {
			return cl.Do(t, http.MethodPatch, "/goals/"+gid+"/members/"+owner.String(), map[string]any{"contribution_visibility": "amounts"})
		}, "member_controls_visibility"},
		{c, func(cl *apitest.Client) *apitest.Response {
			return cl.Do(t, http.MethodPatch, "/goals/"+gid+"/members/"+owner.String(), map[string]any{"role": "viewer"})
		}, "owner_role_fixed"},
		{c, func(cl *apitest.Client) *apitest.Response {
			return cl.Do(t, http.MethodDelete, "/goals/"+gid+"/members/"+owner.String(), nil)
		}, "owner_cannot_leave"},
	} {
		if r := x.do(x.cl); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" || sgDetail(t, r)["code"] != x.code {
			t.Fatalf("want %s: %s", x.code, r.Raw)
		}
	}

	// A planned contribution is recorded in place: counted once, no new row.
	planned := contribute(c, map[string]any{"amount": "300", "status": "planned", "contributed_on": today.AddDate(0, 0, 10).Format(day)}).
		Expect(t, http.StatusCreated).Data()
	before := c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data()
	if p := before["progress"].(map[string]any); money(p, "planned") != "300.00" || money(p, "saved") != "1000.00" {
		t.Fatalf("before recording: %v", p)
	}
	rows := len(c.Do(t, http.MethodGet, "/goals/"+gid+"/contributions", nil).List())
	if r := mate.Do(t, http.MethodPost, "/goals/"+gid+"/contributions/"+planned["id"].(string)+"/record", nil, "Idempotency-Key", key()); r.Status != http.StatusNotFound {
		t.Fatalf("recording someone else's plan: %s", r.Raw)
	}
	rk := key()
	rec := c.Do(t, http.MethodPost, "/goals/"+gid+"/contributions/"+planned["id"].(string)+"/record", nil, "Idempotency-Key", rk).Expect(t, http.StatusOK)
	if rec.Data()["status"] != "recorded" || rec.Data()["id"] != planned["id"] || rec.Data()["contributed_on"] != today.Format(day) {
		t.Fatalf("recorded plan: %s", rec.Raw)
	}
	replay := c.Do(t, http.MethodPost, "/goals/"+gid+"/contributions/"+planned["id"].(string)+"/record", nil, "Idempotency-Key", rk).Expect(t, http.StatusOK)
	if replay.Headers.Get("Idempotent-Replayed") != "true" {
		t.Fatalf("record replay: %s", replay.Raw)
	}
	after := c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data()["progress"].(map[string]any)
	if money(after, "planned") != "0.00" || money(after, "saved") != "1300.00" || len(c.Do(t, http.MethodGet, "/goals/"+gid+"/contributions", nil).List()) != rows {
		t.Fatalf("after recording: %v", after)
	}
	r := c.Do(t, http.MethodPost, "/goals/"+gid+"/contributions/"+planned["id"].(string)+"/record", nil, "Idempotency-Key", key())
	if r.Status != http.StatusConflict || sgDetail(t, r)["code"] != "contribution_not_planned" {
		t.Fatalf("recording twice: %s", r.Raw)
	}
	// With a transaction the plan becomes verified; a transaction counts once.
	deposit := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "200", "description": "To the cabin fund",
		"local_date": today.AddDate(0, 0, -1).Format(day)})
	p2 := contribute(c, map[string]any{"amount": "200", "status": "planned"}).Expect(t, http.StatusCreated).Data()
	v := c.Do(t, http.MethodPost, "/goals/"+gid+"/contributions/"+p2["id"].(string)+"/record", map[string]any{"transaction_id": deposit["id"]},
		"Idempotency-Key", key()).Expect(t, http.StatusOK).Data()
	if v["status"] != "verified" || v["transaction_id"] != deposit["id"] || v["contributed_on"] != today.AddDate(0, 0, -1).Format(day) {
		t.Fatalf("verified plan: %v", v)
	}
	p3 := contribute(c, map[string]any{"amount": "150", "status": "planned"}).Expect(t, http.StatusCreated).Data()
	r = c.Do(t, http.MethodPost, "/goals/"+gid+"/contributions/"+p3["id"].(string)+"/record", map[string]any{"transaction_id": deposit["id"]}, "Idempotency-Key", key())
	if r.ErrorCode() != "DUPLICATE" || sgDetail(t, r)["code"] != "transaction_already_counted" {
		t.Fatalf("transaction counted twice: %s", r.Raw)
	}

	// Forecast assumptions carry codes and values.
	f := c.Do(t, http.MethodGet, "/goals/"+gid+"/forecast", nil).Expect(t, http.StatusOK).Data()
	if fmt.Sprint(f["assumption_codes"]) != "[exact_amounts_no_growth recent_pace_window planned_not_counted]" || len(f["assumptions"].([]any)) != 3 ||
		fmt.Sprint(f["assumption_params"]) != "map[currency:INR months:3 window_days:90]" {
		t.Fatalf("forecast codes: %v %v", f["assumption_codes"], f["assumption_params"])
	}

	// CSV export: text/csv, a neutral file name, formula-safe cells.
	csv := c.Do(t, http.MethodGet, "/goals/"+gid+"/export", nil).Expect(t, http.StatusOK)
	if !strings.HasPrefix(csv.Headers.Get("Content-Type"), "text/csv") ||
		csv.Headers.Get("Content-Disposition") != `attachment; filename="goal-contributions-`+today.Format(day)+`.csv"` ||
		!strings.Contains(string(csv.Raw), `'=HYPERLINK`) || !strings.HasPrefix(string(csv.Raw), "date,contributor,kind") {
		t.Fatalf("export: %s / %s\n%s", csv.Headers.Get("Content-Type"), csv.Headers.Get("Content-Disposition"), csv.Raw)
	}

	// Status changes: coded rule for a transition that is not allowed,
	// optional ?version=, resume reopens cancelled and archived goals.
	cur := c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data()
	if r := c.Do(t, http.MethodPost, "/goals/"+gid+"/pause?version=99", nil); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale pause: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/goals/"+gid+"/pause?version="+sgVersion(cur), nil).Expect(t, http.StatusOK)
	r = c.Do(t, http.MethodPost, "/goals/"+gid+"/pause", nil)
	if d := sgDetail(t, r); r.Status != http.StatusUnprocessableEntity || d["code"] != "invalid_status_transition" ||
		fmt.Sprint(d["params"]) != "map[from:paused to:paused]" {
		t.Fatalf("pausing twice: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/goals/"+gid+"/cancel", nil).Expect(t, http.StatusOK)
	if x := c.Do(t, http.MethodPost, "/goals/"+gid+"/resume", nil).Expect(t, http.StatusOK).Data(); x["status"] != "active" {
		t.Fatalf("resume from cancelled: %v", x["status"])
	}
	if r := c.Do(t, http.MethodDelete, "/goals/"+gid+"?version=1", nil); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale archive: %s", r.Raw)
	}
	if x := c.Do(t, http.MethodDelete, "/goals/"+gid, nil).Expect(t, http.StatusOK).Data(); x["status"] != "archived" {
		t.Fatalf("archive: %v", x["status"])
	}
	if x := c.Do(t, http.MethodPost, "/goals/"+gid+"/resume", nil).Expect(t, http.StatusOK).Data(); x["status"] != "active" {
		t.Fatalf("resume from archived: %v", x["status"])
	}
	// A member leaves; the history stays.
	mate.Do(t, http.MethodDelete, "/goals/"+gid+"/members/"+mateID.String(), nil).Expect(t, http.StatusOK)
	if n := len(c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data()["members"].([]any)); n != 1 {
		t.Fatalf("members after leaving = %d (owner only)", n)
	}
}

func TestSubscriptionsAndGoalsContractShapes(t *testing.T) {
	s := apitest.New(t, map[string]string{"HTTP_ENABLE_DOCS": "true"})
	c, _ := s.Login(t, s.Register(t, "subsgoalsdoc"))
	doc := c.Do(t, http.MethodGet, "/openapi.json", nil).Expect(t, http.StatusOK).Body
	schemas := doc["components"].(map[string]any)["schemas"].(map[string]any)
	prop := func(schema, field string) map[string]any {
		t.Helper()
		sc, ok := schemas[schema].(map[string]any)
		if !ok {
			t.Fatalf("schema %s missing", schema)
		}
		p, ok := sc["properties"].(map[string]any)[field].(map[string]any)
		if !ok {
			t.Fatalf("%s.%s missing", schema, field)
		}
		return p
	}
	enum := func(schema, field string) string {
		p := prop(schema, field)
		if items, ok := p["items"].(map[string]any); ok {
			p = items
		}
		return fmt.Sprint(p["enum"])
	}
	for _, x := range []struct{ schema, field, want string }{
		{"SubscriptionDTO", "billing_frequency", "[weekly monthly quarterly semiannual yearly custom]"},
		{"SubscriptionDTO", "interval_unit", "[day week month year]"},
		{"SubscriptionEvent", "kind", "[created price_changed renewed payment_recorded payment_unlinked trial_started trial_ending paused resumed " +
			"cancellation_started cancelled reactivated verified edited]"},
		{"SubscriptionEvent", "note_code", "[matched_by_detection]"},
		{"DuplicateWarning", "reason_code", "[same_merchant same_name same_price_and_cycle]"},
		{"DetectionEvidence", "reason_codes", "[charge_cadence intervals_fit_cadence amounts_within_tolerance]"},
		{"SubscriptionPaymentCandidate", "reason_codes", "[same_merchant matches_name same_amount amount_close on_renewal_date near_renewal_date]"},
		{"SubscriptionPatch", "clear", "[category_id payment_account_id invoice_file_id group_id]"},
		{"GoalDTO", "goal_type", "[emergency_fund travel education device vehicle home event debt_payoff large_purchase custom]"},
		{"GoalMember", "role", "[owner contributor viewer]"},
		{"GoalForecast", "assumption_codes", "[exact_amounts_no_growth recent_pace_window planned_not_counted]"},
		{"GoalPatch", "clear", "[linked_account_id group_id]"},
	} {
		if got := enum(x.schema, x.field); got != x.want {
			t.Errorf("%s.%s enum = %s, want %s", x.schema, x.field, got, x.want)
		}
	}
	if p := prop("DetectionCandidateDTO", "confidence_bp"); p["type"] != "integer" || p["maximum"] != float64(10000) {
		t.Errorf("confidence_bp = %v", p)
	}
	if prop("DetectionCandidateDTO", "confidence")["deprecated"] != true || prop("SubscriptionDTO", "cancelled_at")["deprecated"] != true {
		t.Error("legacy fields are not marked deprecated")
	}
	for _, f := range [][2]string{{"SubscriptionDTO", "cancelled_on"}, {"GoalDTO", "owner_user_id"}, {"GoalDTO", "owner"}, {"GoalForecast", "assumption_params"}} {
		prop(f[0], f[1])
	}
	paths := doc["paths"].(map[string]any)
	op := func(path, method string) map[string]any {
		t.Helper()
		o, ok := paths[path].(map[string]any)[method].(map[string]any)
		if !ok {
			t.Fatalf("%s %s missing", method, path)
		}
		return o
	}
	content := op("/goals/{id}/export", "get")["responses"].(map[string]any)["200"].(map[string]any)["content"].(map[string]any)
	if _, ok := content["text/csv"]; !ok || len(content) != 1 {
		t.Errorf("export content = %v", content)
	}
	ref := func(path, method string) string {
		return fmt.Sprint(op(path, method)["requestBody"].(map[string]any)["content"].(map[string]any)["application/json"].(map[string]any)["schema"])
	}
	if !strings.Contains(ref("/subscriptions/{id}", "patch"), "SubscriptionPatch") || !strings.Contains(ref("/goals/{id}", "patch"), "GoalPatch") {
		t.Errorf("patch bodies: %s / %s", ref("/subscriptions/{id}", "patch"), ref("/goals/{id}", "patch"))
	}
	for _, x := range [][2]string{{"/subscriptions", "post"}, {"/goals", "post"}, {"/goals/{id}/contributions/{contributionId}/record", "post"}} {
		found := false
		for _, p := range op(x[0], x[1])["parameters"].([]any) {
			if m := p.(map[string]any); m["name"] == "Idempotency-Key" && m["required"] == true {
				found = true
			}
		}
		if !found {
			t.Errorf("%s %s does not require Idempotency-Key", x[1], x[0])
		}
	}
	for _, x := range [][2]string{{"/subscriptions/{id}/payment-candidates", "get"}, {"/subscriptions/{id}/payments/{transactionId}", "delete"},
		{"/subscriptions/{id}/cancellation-checklist/{index}", "patch"}} {
		op(x[0], x[1])
	}
	if d := op("/goals/{id}/resume", "post")["description"].(string); !strings.Contains(d, "cancelled or archived") {
		t.Errorf("resume transitions are not documented: %q", d)
	}
}
