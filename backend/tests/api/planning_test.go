package api_test

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/recurring"
	"montra/backend/internal/testutil/apitest"
)

const day = "2006-01-02"

func utcToday() time.Time {
	n := time.Now().UTC()
	return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, time.UTC)
}

func lastDayOf(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month()+1, 0, 0, 0, 0, 0, time.UTC)
}

func workerCount(t *testing.T, s *apitest.Server, q string, args ...any) int {
	t.Helper()
	var n int
	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error { return tx.QueryRow(ctx, q, args...).Scan(&n) }); err != nil {
		t.Fatal(err)
	}
	return n
}

func generate(t *testing.T, s *apitest.Server, runs int) {
	t.Helper()
	for i := 0; i < runs; i++ {
		if err := s.WorkerSvcs.Recurring.Generate(context.Background()); err != nil {
			t.Fatalf("generate: %v", err)
		}
	}
}

func notificationsOf(t *testing.T, c *apitest.Client, category, event string) int {
	t.Helper()
	n := 0
	for _, x := range c.Do(t, http.MethodGet, "/notifications?category="+category, nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["event_type"] == event {
			n++
		}
	}
	return n
}

func TestRecurringAutoPostMonthEndMissedRunsAndRetries(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "recurrer"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "100000"})["id"].(string)
	today := utcToday()
	rule := c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "Rent", "frequency": "monthly", "by_month_day": -1,
		"start_date": today.Format(day), "timezone": "UTC", "local_time": "00:00", "amount": "15000", "account_id": acct, "auto_post": true}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	rid := rule["id"].(string)
	if rule["next_occurrence"] != lastDayOf(today).Format(day) {
		t.Fatalf("next occurrence = %v, want %s", rule["next_occurrence"], lastDayOf(today).Format(day))
	}

	// The scheduler was down for four months; one run catches up, and a
	// repeated run (or a duplicate scheduler delivery) creates nothing new.
	sim := time.Now().UTC().AddDate(0, 4, 0)
	s.WorkerSvcs.Recurring.Now = func() time.Time { return sim }
	var want []string
	for m := lastDayOf(today); !m.After(sim); m = lastDayOf(m.AddDate(0, 0, 1)) {
		want = append(want, m.Format(day))
	}
	generate(t, s, 2)
	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: recurring.JobGenerate, DedupeKey: "test-generate"})
		return err
	}); err != nil {
		t.Fatal(err)
	}
	s.RunJobs(t)
	posted := map[string]string{}
	for _, o := range c.Do(t, http.MethodGet, "/recurring-rules/"+rid, nil).Expect(t, http.StatusOK).Data()["occurrences"].([]any) {
		m := o.(map[string]any)
		if m["status"] == "posted" {
			posted[m["occurrence_date"].(string)] = m["transaction_id"].(string)
		}
	}
	if len(posted) != len(want) {
		t.Fatalf("posted %v, want month ends %v", posted, want)
	}
	for _, d := range want { // month-end dates never drift (28/29/30/31)
		if posted[d] == "" {
			t.Fatalf("missing month-end occurrence %s in %v", d, posted)
		}
	}
	if n := workerCount(t, s, `select count(*) from transactions where recurring_rule_id = $1`, uuid.MustParse(rid)); n != len(want) {
		t.Fatalf("transactions = %d, want %d (no duplicates)", n, len(want))
	}
	if b := balance(t, c, acct); b != fmt.Sprintf("%d.00", 100000-15000*len(want)) {
		t.Fatalf("balance = %s", b)
	}
	tx := c.Do(t, http.MethodGet, "/transactions/"+posted[want[0]], nil).Expect(t, http.StatusOK).Data()
	if tx["source"] != "recurring" || tx["recurring_rule_id"] != rid {
		t.Fatalf("generated transaction provenance = %v", tx)
	}

	// Retry: an archived account makes auto-post fail; the owner is told
	// once, and the next run after the fix posts exactly once.
	acct2 := createAccount(t, c, map[string]any{"name": "Wallet", "account_type": "cash", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "Gym", "frequency": "daily",
		"start_date": today.Format(day), "end_date": today.Format(day), "timezone": "UTC", "local_time": "00:00", "amount": "300",
		"account_id": acct2, "auto_post": true}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	s.Env.ExecWorker(t, `update financial_accounts set status = 'archived' where id = $1`, uuid.MustParse(acct2))
	s.WorkerSvcs.Recurring.Now = nil
	generate(t, s, 2)
	if n := notificationsOf(t, c, "recurring", "recurring_post_failed"); n != 1 {
		t.Fatalf("failure notifications = %d, want 1", n)
	}
	s.Env.ExecWorker(t, `update financial_accounts set status = 'active' where id = $1`, uuid.MustParse(acct2))
	generate(t, s, 2)
	if b := balance(t, c, acct2); b != "4700.00" {
		t.Fatalf("retried auto-post balance = %s", b)
	}
}

func TestRecurringPauseResumeSkipEditFutureAndConfirm(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "scheduler"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "20000"})["id"].(string)
	today := utcToday()
	body := map[string]any{"kind": "expense", "name": "Yoga class", "frequency": "weekly", "start_date": today.Format(day), "timezone": "UTC",
		"local_time": "23:59", "amount": "500", "account_id": acct}
	rule := c.Do(t, http.MethodPost, "/recurring-rules", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	rid := rule["id"].(string)
	occs := func() []map[string]any {
		var out []map[string]any
		for _, o := range c.Do(t, http.MethodGet, "/recurring-rules/"+rid, nil).Expect(t, http.StatusOK).Data()["occurrences"].([]any) {
			out = append(out, o.(map[string]any))
		}
		return out
	}
	byDate := func() map[string]map[string]any {
		m := map[string]map[string]any{}
		for _, o := range occs() {
			m[o["occurrence_date"].(string)] = o
		}
		return m
	}
	if n := len(occs()); n != 6 { // today … today+35, weekly
		t.Fatalf("materialized %d occurrences, want 6", n)
	}
	r := c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/skip-next", nil).Expect(t, http.StatusOK).Data()
	if r["next_occurrence"] != today.AddDate(0, 0, 7).Format(day) || byDate()[today.Format(day)]["status"] != "skipped" {
		t.Fatalf("skip-next: %v", r)
	}
	r = c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/pause", nil).Expect(t, http.StatusOK).Data()
	if r["status"] != "paused" || r["next_occurrence"] != nil || len(occs()) != 1 {
		t.Fatalf("pause kept future occurrences: %v / %d", r, len(occs()))
	}
	r = c.Do(t, http.MethodPost, "/recurring-rules/"+rid+"/resume", nil).Expect(t, http.StatusOK).Data()
	if r["status"] != "active" || len(occs()) != 6 || byDate()[today.Format(day)]["status"] != "skipped" {
		t.Fatalf("resume: %v", r)
	}
	// Edit this and future: stale versions are rejected; future amounts change.
	body["amount"], body["version"] = "650", 1
	if res := c.Do(t, http.MethodPatch, "/recurring-rules/"+rid, body); res.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale edit accepted: %s", res.Raw)
	}
	body["version"] = r["version"]
	c.Do(t, http.MethodPatch, "/recurring-rules/"+rid, body).Expect(t, http.StatusOK)
	next := byDate()[today.AddDate(0, 0, 7).Format(day)]
	if money(next, "amount") != "650.00" {
		t.Fatalf("future occurrence amount = %v", next["amount"])
	}
	// Confirm one occurrence: idempotent per key and per occurrence.
	k := key()
	first := c.Do(t, http.MethodPost, "/recurring-occurrences/"+next["id"].(string)+"/actions", map[string]any{"action": "confirm"}, "Idempotency-Key", k).
		Expect(t, http.StatusOK)
	again := c.Do(t, http.MethodPost, "/recurring-occurrences/"+next["id"].(string)+"/actions", map[string]any{"action": "confirm"}, "Idempotency-Key", k).
		Expect(t, http.StatusOK)
	if again.Headers.Get("Idempotent-Replayed") != "true" || first.Data()["transaction_id"] != again.Data()["transaction_id"] {
		t.Fatalf("replay differs: %s vs %s", first.Raw, again.Raw)
	}
	if res := c.Do(t, http.MethodPost, "/recurring-occurrences/"+next["id"].(string)+"/actions", map[string]any{"action": "confirm"}, "Idempotency-Key", key()); res.ErrorCode() != "CONFLICT" {
		t.Fatalf("second confirm: %s", res.Raw)
	}
	if b := balance(t, c, acct); b != "19350.00" {
		t.Fatalf("balance after confirm = %s", b)
	}
	// Postpone another occurrence.
	later := byDate()[today.AddDate(0, 0, 14).Format(day)]
	p := c.Do(t, http.MethodPost, "/recurring-occurrences/"+later["id"].(string)+"/actions",
		map[string]any{"action": "postpone", "postpone_to": today.AddDate(0, 0, 16).Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusOK).Data()
	if p["effective_date"] != today.AddDate(0, 0, 16).Format(day) || p["status"] != "scheduled" {
		t.Fatalf("postpone: %v", p)
	}
	// Other users cannot see or change the rule.
	other, _ := s.Login(t, s.Register(t, "schedsnoop"))
	other.Do(t, http.MethodGet, "/recurring-rules/"+rid, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodPost, "/recurring-occurrences/"+later["id"].(string)+"/actions", map[string]any{"action": "skip"}, "Idempotency-Key", key()).
		Expect(t, http.StatusNotFound)
	// Delete: a rule with history ends; an unused rule is removed.
	if d := c.Do(t, http.MethodDelete, "/recurring-rules/"+rid, nil).Expect(t, http.StatusOK).Data(); d["outcome"] != "ended" {
		t.Fatalf("delete used rule: %v", d)
	}
	if n := workerCount(t, s, `select count(*) from recurring_occurrences where rule_id = $1 and status = 'scheduled'`, uuid.MustParse(rid)); n != 0 {
		t.Fatalf("ended rule kept %d scheduled occurrences", n)
	}
	unused := c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "income", "name": "Side gig", "frequency": "monthly",
		"start_date": today.AddDate(0, 1, 0).Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if d := c.Do(t, http.MethodDelete, "/recurring-rules/"+unused["id"].(string), nil).Expect(t, http.StatusOK).Data(); d["outcome"] != "deleted" {
		t.Fatalf("delete unused rule: %v", d)
	}
	c.Do(t, http.MethodGet, "/recurring-rules/"+unused["id"].(string), nil).Expect(t, http.StatusNotFound)
}

func TestBillsLinkPaymentOverdueRemindersAndSkip(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "biller"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	today := utcToday()
	newBill := func(name string, due time.Time) map[string]any {
		return c.Do(t, http.MethodPost, "/bills", map[string]any{"name": name, "provider_name": name + " Co", "expected_amount": "2500",
			"frequency": "monthly", "start_date": due.Format(day), "timezone": "UTC", "reminder_days_before": []int{3},
			"payment_account_id": acct}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	}
	bill := newBill("Electricity", today.AddDate(0, 0, 2))
	bid := bill["id"].(string)
	if bill["state"] != "due_soon" || bill["next_due"].(map[string]any)["effective_date"] != today.AddDate(0, 0, 2).Format(day) {
		t.Fatalf("new bill state = %v next = %v", bill["state"], bill["next_due"])
	}
	generate(t, s, 2)
	if n := notificationsOf(t, c, "bill", "bill_due_soon"); n != 1 {
		t.Fatalf("due-soon reminders = %d, want exactly 1", n)
	}
	// The payment was already recorded: link it instead of duplicating.
	paid := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "2500", "merchant_name": "Electricity Co"})
	cands := c.Do(t, http.MethodGet, "/bills/"+bid+"/payment-candidates", nil).Expect(t, http.StatusOK).List()
	if len(cands) == 0 || cands[0].(map[string]any)["transaction_id"] != paid["id"] ||
		!strings.Contains(fmt.Sprint(cands[0].(map[string]any)["reasons"]), "Same provider") {
		t.Fatalf("payment candidates = %v", cands)
	}
	k := key()
	res := c.Do(t, http.MethodPost, "/bills/"+bid+"/mark-paid", map[string]any{"transaction_id": paid["id"]}, "Idempotency-Key", k).Expect(t, http.StatusOK)
	if res.Data()["state"] != "paid" || res.Data()["last_paid"].(map[string]any)["transaction_id"] != paid["id"] {
		t.Fatalf("mark paid: %s", res.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/bills/"+bid+"/mark-paid", map[string]any{"transaction_id": paid["id"]}, "Idempotency-Key", k); r.Headers.Get("Idempotent-Replayed") != "true" {
		t.Fatalf("mark-paid replay: %s", r.Raw)
	}
	if b := balance(t, c, acct); b != "47500.00" {
		t.Fatalf("linking must not create a second payment; balance = %s", b)
	}
	// One transaction can satisfy only one bill occurrence.
	water := newBill("Water", today.AddDate(0, 0, 2))
	if r := c.Do(t, http.MethodPost, "/bills/"+water["id"].(string)+"/mark-paid", map[string]any{"transaction_id": paid["id"]}, "Idempotency-Key", key()); r.ErrorCode() != "DUPLICATE" {
		t.Fatalf("double-linked payment accepted: %s", r.Raw)
	}
	w := c.Do(t, http.MethodPost, "/bills/"+water["id"].(string)+"/mark-paid", map[string]any{"create_transaction": true, "amount": "2410.50"},
		"Idempotency-Key", key()).Expect(t, http.StatusOK).Data()
	if w["state"] != "paid" || money(w["last_paid"].(map[string]any), "amount") != "2410.50" {
		t.Fatalf("record payment: %v", w)
	}
	if b := balance(t, c, acct); b != "45089.50" {
		t.Fatalf("balance after recorded payment = %s", b)
	}
	// A due date passing never marks a bill paid: it becomes overdue.
	gas := newBill("Gas", today.AddDate(0, 0, 1))
	sim := time.Now().UTC().AddDate(0, 0, 3)
	s.WorkerSvcs.Recurring.Now = func() time.Time { return sim }
	generate(t, s, 2)
	g := c.Do(t, http.MethodGet, "/bills/"+gas["id"].(string), nil).Expect(t, http.StatusOK).Data()
	if g["state"] != "overdue" || g["last_paid"] != nil {
		t.Fatalf("gas bill = %v", g["state"])
	}
	if n := notificationsOf(t, c, "bill", "bill_overdue"); n != 1 {
		t.Fatalf("overdue notifications = %d, want 1", n)
	}
	g = c.Do(t, http.MethodPost, "/bills/"+gas["id"].(string)+"/skip", map[string]any{}).Expect(t, http.StatusOK).Data()
	if g["state"] != "upcoming" {
		t.Fatalf("after skip: %v", g["state"])
	}
	// Optimistic concurrency and pausing.
	upd := map[string]any{"name": "Gas", "expected_amount": "2600", "frequency": "monthly", "start_date": today.AddDate(0, 0, 1).Format(day),
		"timezone": "UTC", "version": 99}
	if r := c.Do(t, http.MethodPatch, "/bills/"+gas["id"].(string), upd); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale bill edit: %s", r.Raw)
	}
	upd["version"], upd["status"] = g["version"], "paused"
	g = c.Do(t, http.MethodPatch, "/bills/"+gas["id"].(string), upd).Expect(t, http.StatusOK).Data()
	if g["state"] != "paused" || g["schedule"].(map[string]any)["status"] != "paused" || money(g, "expected_amount") != "2600.00" {
		t.Fatalf("paused bill = %v", g)
	}
	other, _ := s.Login(t, s.Register(t, "billsnoop"))
	other.Do(t, http.MethodGet, "/bills/"+bid, nil).Expect(t, http.StatusNotFound)
	if len(other.Do(t, http.MethodGet, "/bills", nil).Expect(t, http.StatusOK).List()) != 0 {
		t.Fatal("bills leaked across users")
	}
}

func TestSubscriptionsManualDetectionAndConfirmedCancellation(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "subscriber")
	c, _ := s.Login(t, addr)
	acct := createAccount(t, c, map[string]any{"name": "Card", "account_type": "bank", "currency": "INR", "opening_balance": "90000",
		"opening_date": time.Now().AddDate(0, -6, 0).Format(day)})["id"].(string)
	sub := c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "StreamFlix", "amount": "649", "billing_frequency": "monthly",
		"start_date": "2026-01-15", "payment_account_id": acct, "cancellation_url": "https://streamflix.example/account/cancel"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	sid := sub["id"].(string)
	if sub["status"] != "active" || money(sub, "monthly_cost") != "649.00" || money(sub, "annual_cost") != "7788.00" || sub["next_renewal_date"] == nil {
		t.Fatalf("manual subscription = %v", sub)
	}
	if r := c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "Spotlight", "amount": "1", "billing_frequency": "monthly",
		"start_date": "2026-01-01", "cancellation_url": "http://insecure.example"}, "Idempotency-Key", key()); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("non-https cancellation URL accepted: %s", r.Raw)
	}
	dup := c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "streamflix", "amount": "199", "billing_frequency": "yearly",
		"start_date": "2026-03-01"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if len(dup["duplicate_warnings"].([]any)) == 0 || money(dup, "monthly_cost") != "16.58" {
		t.Fatalf("duplicate warning/normalized cost = %v / %v", dup["duplicate_warnings"], dup["monthly_cost"])
	}
	upd := map[string]any{"name": "StreamFlix", "amount": "699", "billing_frequency": "monthly", "start_date": "2026-01-15",
		"payment_account_id": acct, "version": sub["version"]}
	got := c.Do(t, http.MethodPatch, "/subscriptions/"+sid, upd).Expect(t, http.StatusOK).Data()
	if ev := got["events"].([]any)[0].(map[string]any); ev["kind"] != "price_changed" || money(ev, "old_amount") != "649.00" || money(ev, "new_amount") != "699.00" {
		t.Fatalf("price history = %v", got["events"])
	}

	// Detection: four monthly charges from one merchant (plus noise).
	today := time.Now()
	var evidence []string
	for i := 3; i >= 0; i-- {
		tx := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "119", "merchant_name": "Melody Music",
			"local_date": today.AddDate(0, 0, -30*i).Format(day)})
		evidence = append(evidence, tx["id"].(string))
	}
	for i, amt := range []string{"450", "1290", "88"} {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": amt, "merchant_name": "Corner Grocer",
			"local_date": today.AddDate(0, 0, -11*i-3).Format(day)})
	}
	for i := 2; i >= 0; i-- {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "299", "merchant_name": "CloudBox",
			"local_date": today.AddDate(0, 0, -31*i).Format(day)})
	}
	c.Do(t, http.MethodPost, "/subscriptions/detections/refresh", nil).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	cands := c.Do(t, http.MethodGet, "/subscriptions/detections", nil).Expect(t, http.StatusOK).List()
	if len(cands) != 2 {
		t.Fatalf("detections = %v", cands)
	}
	var melody, cloud map[string]any
	for _, x := range cands {
		m := x.(map[string]any)
		switch m["merchant_label"] {
		case "Melody Music":
			melody = m
		case "CloudBox":
			cloud = m
		}
	}
	if melody == nil || cloud == nil || melody["cadence"] != "monthly" || len(melody["evidence_transaction_ids"].([]any)) != 4 ||
		len(melody["evidence"].(map[string]any)["reasons"].([]any)) != 3 || melody["confidence"].(string) < "0.600" {
		t.Fatalf("melody detection = %v", melody)
	}
	// Detection never changes ledger records.
	for _, id := range evidence {
		if v := c.Do(t, http.MethodGet, "/transactions/"+id, nil).Data()["version"]; v != float64(1) {
			t.Fatalf("detection modified transaction %s (version %v)", id, v)
		}
	}
	conf := c.Do(t, http.MethodPost, "/subscriptions/detections/"+melody["id"].(string)+"/confirm", map[string]any{"name": "Melody Premium"}).
		Expect(t, http.StatusCreated).Data()
	payments := 0
	for _, e := range conf["events"].([]any) {
		if e.(map[string]any)["kind"] == "payment_recorded" {
			payments++
		}
	}
	if conf["source"] != "detected" || conf["merchant"].(map[string]any)["name"] != "Melody Music" || payments != 4 || conf["last_payment"] == nil {
		t.Fatalf("confirmed subscription = %v (payments %d)", conf, payments)
	}
	c.Do(t, http.MethodPost, "/subscriptions/detections/"+cloud["id"].(string)+"/dismiss", nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/subscriptions/detections/"+cloud["id"].(string)+"/confirm", map[string]any{}).Expect(t, http.StatusConflict)
	if _, err := s.WorkerSvcs.Subs.DetectForUser(context.Background(), userID(t, s, addr)); err != nil {
		t.Fatal(err)
	}
	if n := len(c.Do(t, http.MethodGet, "/subscriptions/detections", nil).List()); n != 0 {
		t.Fatalf("confirmed/dismissed detections were suggested again: %d", n)
	}
	// Payment history links a transaction once, to one subscription.
	charge := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "699", "merchant_name": "StreamFlix"})
	c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/payments", map[string]any{"transaction_id": charge["id"]}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	if r := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/payments", map[string]any{"transaction_id": charge["id"]}, "Idempotency-Key", key()); r.ErrorCode() != "DUPLICATE" {
		t.Fatalf("duplicate payment link: %s", r.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/payments", map[string]any{"transaction_id": evidence[0]}, "Idempotency-Key", key()); r.ErrorCode() != "DUPLICATE" {
		t.Fatalf("payment of another subscription accepted: %s", r.Raw)
	}
	// Cancellation is recorded only with explicit confirmation.
	if r := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancelled", map[string]any{}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("unconfirmed cancellation: %s", r.Raw)
	}
	cx := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancelled", map[string]any{"confirm": true}).Expect(t, http.StatusOK).Data()
	if cx["status"] != "cancelled" || cx["next_renewal_date"] != nil || cx["cancelled_at"] == nil {
		t.Fatalf("cancelled = %v", cx)
	}
	sum := c.Do(t, http.MethodGet, "/subscriptions/summary", nil).Expect(t, http.StatusOK).Data()
	if tot := sum["totals"].([]any); len(tot) != 1 || tot[0].(map[string]any)["count"] != float64(2) {
		t.Fatalf("summary totals = %v", sum["totals"])
	}
	other, _ := s.Login(t, s.Register(t, "subsnoop"))
	other.Do(t, http.MethodGet, "/subscriptions/"+sid, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodPost, "/subscriptions/detections/"+cloud["id"].(string)+"/dismiss", nil).Expect(t, http.StatusNotFound)
}

func TestGoalsContributionsForecastSharingAndCalendar(t *testing.T) {
	s := apitest.New(t, nil)
	ownerAddr, mateAddr := s.Register(t, "saver"), s.Register(t, "cosaver")
	c, _ := s.Login(t, ownerAddr)
	mate, _ := s.Login(t, mateAddr)
	owner, mateID := userID(t, s, ownerAddr), userID(t, s, mateAddr)
	g := uuid.New()
	s.Env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Trip crew','trip','INR','Asia/Kolkata')`, g, owner)
	s.Env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, g, owner, mateID)
	acct := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR", "opening_balance": "30000"})["id"].(string)
	target := time.Now().AddDate(0, 6, 0).Format(day)
	goal := c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Goa trip", "goal_type": "travel", "target_amount": "10000", "starting_amount": "1000",
		"target_date": target, "contribution_schedule": "monthly", "planned_contribution": "1500", "reminders_enabled": true}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	gid := goal["id"].(string)
	prog := func(x map[string]any) map[string]any { return x["progress"].(map[string]any) }
	if money(prog(goal), "saved") != "1000.00" || len(goal["milestones"].([]any)) != 4 || goal["access"] != "owner" {
		t.Fatalf("goal = %v", goal)
	}
	contribute := func(cl *apitest.Client, body map[string]any) *apitest.Response {
		return cl.Do(t, http.MethodPost, "/goals/"+gid+"/contributions", body, "Idempotency-Key", key())
	}
	contribute(c, map[string]any{"amount": "2000"}).Expect(t, http.StatusCreated)
	s.RunJobs(t)
	if n := notificationsOf(t, c, "goal", "goal_milestone"); n != 1 { // 25% reached
		t.Fatalf("milestone notifications = %d", n)
	}
	deposit := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1500", "description": "Moved to trip fund"})
	v := contribute(c, map[string]any{"amount": "1500", "transaction_id": deposit["id"]}).Expect(t, http.StatusCreated).Data()
	if v["status"] != "verified" {
		t.Fatalf("linked contribution status = %v", v["status"])
	}
	if r := contribute(c, map[string]any{"amount": "100", "transaction_id": deposit["id"]}); r.ErrorCode() != "DUPLICATE" {
		t.Fatalf("transaction counted twice: %s", r.Raw)
	}
	if r := contribute(c, map[string]any{"kind": "withdrawal", "amount": "99999"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("over-withdrawal: %s", r.Raw)
	}
	f := c.Do(t, http.MethodGet, "/goals/"+gid+"/forecast", nil).Expect(t, http.StatusOK).Data()
	if money(f, "saved") != "4500.00" || money(f, "recent_monthly_pace") != "1166.67" || f["required_per_month"] == nil ||
		len(f["assumptions"].([]any)) != 3 || f["planned_completion"] == nil {
		t.Fatalf("forecast = %v", f)
	}
	// Changing the target never rewrites contributions.
	got := c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data()
	upd := map[string]any{"name": "Goa trip", "goal_type": "travel", "target_amount": "20000", "starting_amount": "1000", "target_date": target,
		"version": got["version"]}
	got = c.Do(t, http.MethodPatch, "/goals/"+gid, upd).Expect(t, http.StatusOK).Data()
	if prog(got)["percent_bp"] != float64(2250) || len(c.Do(t, http.MethodGet, "/goals/"+gid+"/contributions", nil).List()) != 2 {
		t.Fatalf("after target change: %v", prog(got))
	}
	// Shared goal: explicit membership, contributor visibility, exit.
	mate.Do(t, http.MethodGet, "/goals/"+gid, nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodPost, "/goals/"+gid+"/members", map[string]any{"user_id": mateID, "role": "contributor"}).Expect(t, http.StatusOK)
	if mg := mate.Do(t, http.MethodGet, "/goals/"+gid, nil).Expect(t, http.StatusOK).Data(); mg["access"] != "contributor" {
		t.Fatalf("mate access = %v", mg["access"])
	}
	s.RunJobs(t)
	if n := notificationsOf(t, mate, "goal", "goal_shared"); n != 1 {
		t.Fatalf("share notifications = %d", n)
	}
	mc := contribute(mate, map[string]any{"amount": "500", "note": "my share"}).Expect(t, http.StatusCreated).Data()
	mate.Do(t, http.MethodPatch, "/goals/"+gid+"/members/"+mateID.String(), map[string]any{"contribution_visibility": "percent_only"}).Expect(t, http.StatusOK)
	for _, x := range c.Do(t, http.MethodGet, "/goals/"+gid+"/contributions", nil).List() {
		m := x.(map[string]any)
		if m["id"] == mc["id"] && (m["amount"] != nil || m["percent_bp"] != float64(250) || m["note"] != nil) {
			t.Fatalf("percent-only contribution exposed: %v", m)
		}
	}
	for _, x := range mate.Do(t, http.MethodGet, "/goals/"+gid+"/contributions", nil).List() {
		if m := x.(map[string]any); m["user_id"] == owner.String() && m["transaction_id"] != nil {
			t.Fatal("owner's ledger reference exposed to a member")
		}
	}
	mate.Do(t, http.MethodPost, "/goals/"+gid+"/contributions/"+mc["id"].(string)+"/void", nil).Expect(t, http.StatusOK)
	if r := c.Do(t, http.MethodPost, "/goals/"+gid+"/contributions/"+v["id"].(string)+"/void", nil); r.Status != http.StatusOK {
		t.Fatalf("owner voids own contribution: %s", r.Raw)
	}
	mate.Do(t, http.MethodDelete, "/goals/"+gid+"/members/"+mateID.String(), nil).Expect(t, http.StatusOK)
	mate.Do(t, http.MethodGet, "/goals/"+gid, nil).Expect(t, http.StatusNotFound)
	// Export (CSV, formula-safe).
	csv := c.Do(t, http.MethodGet, "/goals/"+gid+"/export", nil).Expect(t, http.StatusOK)
	if !strings.HasPrefix(csv.Headers.Get("Content-Type"), "text/csv") || !strings.HasPrefix(string(csv.Raw), "date,contributor,kind") {
		t.Fatalf("export = %s %q", csv.Headers.Get("Content-Type"), csv.Raw)
	}
	// Reaching the target achieves the goal; a withdrawal re-opens it.
	got = c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data()
	rem := prog(got)["remaining"].(map[string]any)["amount"].(string)
	contribute(c, map[string]any{"amount": rem}).Expect(t, http.StatusCreated)
	if got = c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data(); got["status"] != "achieved" || got["achieved_at"] == nil {
		t.Fatalf("goal not achieved: %v", got["status"])
	}
	contribute(c, map[string]any{"kind": "withdrawal", "amount": "10"}).Expect(t, http.StatusCreated)
	if got = c.Do(t, http.MethodGet, "/goals/"+gid, nil).Data(); got["status"] != "active" {
		t.Fatalf("goal after withdrawal: %v", got["status"])
	}

	// Planning calendar: bills, subscription renewals/trials and goal dates.
	today := utcToday()
	c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Internet", "expected_amount": "999", "frequency": "monthly",
		"start_date": today.AddDate(0, 0, 5).Format(day), "timezone": "UTC"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "PhotoVault", "amount": "130", "billing_frequency": "monthly",
		"start_date": today.Format(day), "trial_ends_on": today.AddDate(0, 0, 10).Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	near := c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Gift", "goal_type": "event", "target_amount": "3000",
		"target_date": today.AddDate(0, 0, 20).Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	kinds := map[string]int{}
	for _, x := range c.Do(t, http.MethodGet, "/calendar?from="+today.Format(day)+"&to="+today.AddDate(0, 0, 60).Format(day), nil).
		Expect(t, http.StatusOK).List() {
		m := x.(map[string]any)
		kinds[m["kind"].(string)]++
		if m["kind"] == "goal_target" && m["entity_id"] != near["id"] {
			t.Fatalf("unexpected goal target %v", m)
		}
	}
	if kinds["bill"] < 2 || kinds["trial_end"] != 1 || kinds["subscription_renewal"] < 1 || kinds["goal_target"] != 1 {
		t.Fatalf("calendar kinds = %v", kinds)
	}
	if r := c.Do(t, http.MethodGet, "/calendar?from="+today.Format(day)+"&to="+today.AddDate(1, 0, 0).Format(day), nil); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("oversized calendar range: %s", r.Raw)
	}
}

func TestSubscriptionTrialAndRenewalRemindersOnce(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "renewals"))
	today := time.Now()
	trial := c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "CloudDocs", "amount": "250", "billing_frequency": "monthly",
		"start_date": today.Format(day), "trial_ends_on": today.AddDate(0, 0, 2).Format(day), "reminder_days_before": []int{3}}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	renew := c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "NewsPlus", "amount": "99", "billing_frequency": "monthly",
		"start_date": today.AddDate(0, -2, 0).Format(day), "next_renewal_date": today.AddDate(0, 0, 2).Format(day), "reminder_days_before": []int{3}}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	if trial["status"] != "trial" || renew["status"] != "active" {
		t.Fatalf("statuses = %v / %v", trial["status"], renew["status"])
	}
	ctx := context.Background()
	for i := 0; i < 2; i++ {
		if err := s.WorkerSvcs.Subs.Renewals(ctx); err != nil {
			t.Fatal(err)
		}
	}
	s.RunJobs(t)
	if n := notificationsOf(t, c, "subscription", "trial_ending"); n != 1 {
		t.Fatalf("trial-ending notices = %d, want 1", n)
	}
	if n := notificationsOf(t, c, "subscription", "renewal_due"); n != 1 {
		t.Fatalf("renewal notices = %d, want 1", n)
	}
	// After the trial ends it is expected to renew as paid; passed renewal
	// dates advance (expectations, not recorded payments).
	sim := time.Now().AddDate(0, 0, 4)
	s.WorkerSvcs.Subs.Now = func() time.Time { return sim }
	for i := 0; i < 2; i++ {
		if err := s.WorkerSvcs.Subs.Renewals(ctx); err != nil {
			t.Fatal(err)
		}
	}
	got := c.Do(t, http.MethodGet, "/subscriptions/"+trial["id"].(string), nil).Expect(t, http.StatusOK).Data()
	next, _ := time.Parse(day, fmt.Sprint(got["next_renewal_date"]))
	if got["status"] != "active" || next.Before(time.Date(sim.Year(), sim.Month(), sim.Day(), 0, 0, 0, 0, time.UTC)) {
		t.Fatalf("after trial: status %v next %v", got["status"], got["next_renewal_date"])
	}
	if got["last_payment"] != nil {
		t.Fatal("an expected renewal must not be recorded as a payment")
	}
	n := 0
	for _, e := range got["events"].([]any) {
		if e.(map[string]any)["kind"] == "trial_ending" {
			n++
		}
	}
	if n != 1 {
		t.Fatalf("trial_ending events = %d", n)
	}
}

func TestGoalContributionRemindersOncePerPeriod(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "goalremind"))
	goal := c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Laptop", "goal_type": "device", "target_amount": "90000",
		"contribution_schedule": "monthly", "planned_contribution": "10000", "reminders_enabled": true}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	quiet := c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Quiet", "goal_type": "custom", "target_amount": "100",
		"contribution_schedule": "monthly", "planned_contribution": "10"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	_ = quiet
	ctx := context.Background()
	run := func() {
		t.Helper()
		for i := 0; i < 2; i++ {
			if err := s.WorkerSvcs.Goals.Reminders(ctx); err != nil {
				t.Fatal(err)
			}
		}
		s.RunJobs(t)
	}
	run()
	if n := notificationsOf(t, c, "goal", "goal_contribution_due"); n != 1 { // reminders off for "Quiet"
		t.Fatalf("reminders = %d, want 1", n)
	}
	// A contribution in the next period suppresses that period's reminder.
	next := time.Now().AddDate(0, 1, 0)
	next = time.Date(next.Year(), next.Month(), 2, 12, 0, 0, 0, time.UTC)
	if r := c.Do(t, http.MethodPost, "/goals/"+goal["id"].(string)+"/contributions", map[string]any{"amount": "10000",
		"contributed_on": next.Format(day)}, "Idempotency-Key", key()); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("future recorded contribution accepted: %s", r.Raw)
	}
	s.WorkerSvcs.Goals.Now = func() time.Time { return next }
	s.Svcs.Goals.Now = func() time.Time { return next }
	c.Do(t, http.MethodPost, "/goals/"+goal["id"].(string)+"/contributions", map[string]any{"amount": "10000",
		"contributed_on": next.Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	run()
	if n := notificationsOf(t, c, "goal", "goal_contribution_due"); n != 1 {
		t.Fatalf("reminder sent despite this period's contribution: %d", n)
	}
	// The following period without a contribution gets exactly one reminder.
	later := next.AddDate(0, 1, 0)
	s.WorkerSvcs.Goals.Now = func() time.Time { return later }
	run()
	if n := notificationsOf(t, c, "goal", "goal_contribution_due"); n != 2 {
		t.Fatalf("reminders after an empty period = %d, want 2", n)
	}
}
