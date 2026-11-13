package api_test

import (
	"fmt"
	"net/http"
	"net/url"
	"slices"
	"testing"
	"time"

	"montra/backend/internal/testutil/apitest"
)

// Coverage for the expenses series, reconciliation match and statement-line
// lists, and the AI conversation list/delete and subscription detection
// endpoints (these three run without a model: answers are deterministic
// when no provider is configured, and detection is rule based).

func cvTotals(t *testing.T, r map[string]any, field, cur string) map[string]any {
	t.Helper()
	for _, x := range r[field].([]any) {
		if m := x.(map[string]any); m["currency"] == cur {
			return m
		}
	}
	return nil
}

func TestCoverageAnalyticsExpensesSeries(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvexpenses"))
	other, _ := s.Login(t, s.Register(t, "cvexpensesother"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000",
		"opening_date": "2026-08-01"})["id"].(string)
	savings := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR", "opening_date": "2026-08-01"})["id"].(string)
	usd := createAccount(t, c, map[string]any{"name": "USD", "account_type": "bank", "currency": "USD", "opening_balance": "100",
		"opening_date": "2026-08-01"})["id"].(string)
	tx := func(typ, account, amount, date string) map[string]any {
		return createTx(t, c, map[string]any{"type": typ, "account_id": account, "amount": amount, "local_date": date})
	}
	groceries := tx("expense", acct, "1000", "2026-10-05")
	tx("expense", acct, "500", "2026-10-20")
	tx("income", acct, "5000", "2026-10-10")
	tx("expense", usd, "10.50", "2026-10-11")
	tx("expense", acct, "100", "2026-09-15") // previous period
	tx("expense", acct, "70", "2026-11-01")  // outside the window
	c.Do(t, http.MethodPost, "/transactions/"+groceries["id"].(string)+"/refunds", map[string]any{"amount": "200", "local_date": "2026-10-22"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": acct, "to_account_id": savings, "amount": "300",
		"local_date": "2026-10-12"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	voided := tx("expense", acct, "999", "2026-10-13")
	c.Do(t, http.MethodDelete, "/transactions/"+voided["id"].(string), nil).Expect(t, http.StatusOK)

	r := c.Do(t, http.MethodGet, "/analytics/expenses?from=2026-10-01&to=2026-10-31&granularity=month", nil).Expect(t, http.StatusOK).Data()
	w := r["window"].(map[string]any)
	if w["from"] != "2026-10-01" || w["to"] != "2026-10-31" {
		t.Fatalf("window = %v", w)
	}
	// Expenses only: income and transfers never count, refunds reduce
	// spending, deleted records are left out, currencies stay separate.
	inr := cvTotals(t, r, "totals", "INR")
	if inr == nil || money(inr, "income") != "0.00" || money(inr, "gross_expense") != "1500.00" || money(inr, "refunds") != "200.00" ||
		money(inr, "net_expense") != "1300.00" || money(inr, "net_cash_flow") != "-1300.00" || inr["transaction_count"] != float64(3) {
		t.Fatalf("INR expense totals = %v", inr)
	}
	if u := cvTotals(t, r, "totals", "USD"); u == nil || money(u, "net_expense") != "10.50" {
		t.Fatalf("USD expense totals = %v", r["totals"])
	}
	pw := r["previous_window"].(map[string]any)
	if pw["from"] != "2026-08-31" || pw["to"] != "2026-09-30" {
		t.Fatalf("previous window = %v", pw)
	}
	if p := cvTotals(t, r, "previous_period", "INR"); p == nil || money(p, "net_expense") != "100.00" {
		t.Fatalf("previous period = %v", r["previous_period"])
	}
	if r["series_granularity"] != "month" {
		t.Fatalf("granularity = %v", r["series_granularity"])
	}
	var oct map[string]any
	for _, x := range r["series"].([]any) {
		if m := x.(map[string]any); m["bucket"] == "2026-10-01" && m["currency"] == "INR" {
			oct = m
		}
	}
	if oct == nil || money(oct, "net_expense") != "1300.00" || money(oct, "income") != "0.00" || money(oct, "net") != "-1300.00" {
		t.Fatalf("October bucket = %v", r["series"])
	}
	// Daily buckets add up to the same total.
	daily := c.Do(t, http.MethodGet, "/analytics/expenses?from=2026-10-01&to=2026-10-31&granularity=day&currency=INR", nil).Expect(t, http.StatusOK).Data()
	var sum int64
	n := 0
	for _, x := range daily["series"].([]any) {
		m := x.(map[string]any)
		if m["currency"] != "INR" {
			t.Fatalf("currency filter leaked %v", m)
		}
		sum += int64(m["net_expense"].(map[string]any)["amount_minor"].(float64))
		n++
	}
	if sum != 130000 || n != 31 || len(daily["totals"].([]any)) != 1 {
		t.Fatalf("daily series: sum=%d buckets=%d totals=%v", sum, n, daily["totals"])
	}
	// The income view of the same window is the complement.
	inc := cvTotals(t, c.Do(t, http.MethodGet, "/analytics/income?from=2026-10-01&to=2026-10-31", nil).Expect(t, http.StatusOK).Data(), "totals", "INR")
	if money(inc, "income") != "5000.00" || money(inc, "gross_expense") != "0.00" {
		t.Fatalf("income view = %v", inc)
	}
	// Filters: one account; another user's data never appears.
	if f := cvTotals(t, c.Do(t, http.MethodGet, "/analytics/expenses?from=2026-10-01&to=2026-10-31&account_id="+savings, nil).Expect(t, http.StatusOK).Data(),
		"totals", "INR"); f != nil && money(f, "net_expense") != "0.00" {
		t.Fatalf("savings-only expenses = %v", f)
	}
	if o := cvTotals(t, other.Do(t, http.MethodGet, "/analytics/expenses?from=2026-10-01&to=2026-10-31", nil).Expect(t, http.StatusOK).Data(),
		"totals", "INR"); o != nil && money(o, "gross_expense") != "0.00" {
		t.Fatalf("another user's expenses = %v", o)
	}
	gfField(t, c.Do(t, http.MethodGet, "/analytics/expenses?granularity=hour", nil), "query.granularity")
	gfField(t, c.Do(t, http.MethodGet, "/analytics/expenses?currency=inr", nil), "query.currency")
	s.NewClient("android").Do(t, http.MethodGet, "/analytics/expenses", nil).Expect(t, http.StatusUnauthorized)
}

func TestCoverageReconciliationMatchesAndStatementLines(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvrecon"))
	other, _ := s.Login(t, s.Register(t, "cvreconother"))
	today := time.Now()
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000",
		"opening_date": today.AddDate(0, -2, 0).Format(day)})["id"].(string)
	empty := createAccount(t, c, map[string]any{"name": "Empty", "account_type": "cash", "currency": "INR"})["id"].(string)
	d := func(n int) string { return today.AddDate(0, 0, -n).Format(day) }
	rent := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "15000", "description": "Rent", "local_date": d(20)})
	gym := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1200", "description": "Gym", "local_date": d(15)})
	b := startImport(t, s, c, acct, []byte(fmt.Sprintf("Date,Description,Amount\n%s,NEFT LANDLORD,-15000.00\n%s,FITCLUB,-1200.00\n%s,COFFEE,-150.00\n",
		d(8), d(7), d(6))))
	bid := b["id"].(string)
	ready := importRows(t, c, bid, "ready")
	landlord, fit := rowContaining(t, ready, "LANDLORD"), rowContaining(t, ready, "FITCLUB")
	for _, row := range []map[string]any{landlord, fit} {
		c.Do(t, http.MethodPatch, "/imports/"+bid+"/rows/"+row["id"].(string), map[string]any{"decision": "skip"}).Expect(t, http.StatusOK)
	}
	c.Do(t, http.MethodPost, "/imports/"+bid+"/confirm", map[string]any{"version": batch(t, c, bid)["version"]}, "Idempotency-Key", key()).
		Expect(t, http.StatusAccepted)
	s.RunJobs(t)

	// Statement lines: unmatched by default, oldest first, paged; owner only.
	lines := c.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines", nil).Expect(t, http.StatusOK)
	if got := fieldsOf(lines.List(), "import_row_id"); !slices.Equal(got, []string{landlord["id"].(string), fit["id"].(string)}) ||
		lines.Body["meta"].(map[string]any)["has_more"] != false {
		t.Fatalf("unmatched lines = %s", lines.Raw)
	}
	first := lines.List()[0].(map[string]any)
	if first["batch_id"] != bid || first["date"] != d(8) || money(first, "amount") != "15000.00" || first["direction"] != "outflow" ||
		first["record_status"] != "skipped" || first["match_id"] != nil || first["description"] != "NEFT LANDLORD" {
		t.Fatalf("statement line = %v", first)
	}
	p1 := c.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines?limit=1", nil).Expect(t, http.StatusOK)
	next, _ := p1.Body["meta"].(map[string]any)["next_cursor"].(string)
	p2 := c.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines?limit=1&cursor="+url.QueryEscape(next), nil).Expect(t, http.StatusOK).List()
	if len(p1.List()) != 1 || len(p2) != 1 || p2[0].(map[string]any)["import_row_id"] != fit["id"] {
		t.Fatalf("statement line pages: %s / %v", p1.Raw, p2)
	}
	if l := c.Do(t, http.MethodGet, "/accounts/"+empty+"/statement-lines", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("lines of an account without imports = %v", l)
	}
	other.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines", nil).Expect(t, http.StatusNotFound)
	gfField(t, c.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines?status=all", nil), "query.status")
	gfField(t, c.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines?batch_id=nope", nil), "query.batch_id")

	// Two matches by hand; the matches list is newest first and paged.
	mRent := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "statement_to_ledger", "account_id": acct,
		"statement_row_ids": []string{landlord["id"].(string)}, "transaction_ids": []string{rent["id"].(string)}}).Expect(t, http.StatusCreated).Data()
	mGym := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "statement_to_ledger", "account_id": acct,
		"statement_row_ids": []string{fit["id"].(string)}, "transaction_ids": []string{gym["id"].(string)}}).Expect(t, http.StatusCreated).Data()
	ml := c.Do(t, http.MethodGet, "/reconciliation/matches?account_id="+acct, nil).Expect(t, http.StatusOK).List()
	if got := ids(ml, "id"); !slices.Equal(got, []string{mGym["id"].(string), mRent["id"].(string)}) {
		t.Fatalf("matches = %v", got)
	}
	m0 := ml[1].(map[string]any)
	if m0["status"] != "confirmed" || m0["kind"] != "statement_to_ledger" || m0["account_id"] != acct || money(m0, "total") != "15000.00" ||
		len(m0["items"].([]any)) != 2 || m0["confirmed_at"] == nil || !slices.Contains(strList(m0["reason_codes"]), "same_amount_direction") {
		t.Fatalf("listed match = %v", m0)
	}
	pg := c.Do(t, http.MethodGet, "/reconciliation/matches?account_id="+acct+"&limit=1", nil).Expect(t, http.StatusOK)
	cur, _ := pg.Body["meta"].(map[string]any)["next_cursor"].(string)
	if pg2 := c.Do(t, http.MethodGet, "/reconciliation/matches?account_id="+acct+"&limit=1&cursor="+url.QueryEscape(cur), nil).Expect(t, http.StatusOK).List(); len(pg.List()) != 1 ||
		len(pg2) != 1 || pg2[0].(map[string]any)["id"] != mRent["id"] {
		t.Fatalf("match pages: %s", pg.Raw)
	}
	// Statement lines follow the matches.
	if l := c.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("unmatched lines after matching = %v", l)
	}
	matched := c.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines?status=matched&batch_id="+bid, nil).Expect(t, http.StatusOK).List()
	if len(matched) != 2 || gfFind(matched, "import_row_id", landlord["id"].(string))["match_id"] != mRent["id"] {
		t.Fatalf("matched lines = %v", matched)
	}
	// Undoing a match: it stays listed as unmatched and its line comes back.
	c.Do(t, http.MethodDelete, "/reconciliation/matches/"+mGym["id"].(string), nil).Expect(t, http.StatusOK)
	ml = c.Do(t, http.MethodGet, "/reconciliation/matches?account_id="+acct, nil).Expect(t, http.StatusOK).List()
	if u := gfFind(ml, "id", mGym["id"].(string)); u == nil || u["status"] != "unmatched" || u["unmatched_at"] == nil {
		t.Fatalf("matches after undo = %v", ml)
	}
	if l := c.Do(t, http.MethodGet, "/accounts/"+acct+"/statement-lines", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["import_row_id"] != fit["id"] {
		t.Fatalf("unmatched lines after undo = %v", l)
	}
	// Owner only; account_id is required; other accounts have none.
	other.Do(t, http.MethodGet, "/reconciliation/matches?account_id="+acct, nil).Expect(t, http.StatusNotFound)
	if r := c.Do(t, http.MethodGet, "/reconciliation/matches", nil); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("matches without account_id: %d", r.Status)
	}
	if l := c.Do(t, http.MethodGet, "/reconciliation/matches?account_id="+empty, nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("matches of another account = %v", l)
	}
}

func TestCoverageAIConversationsAndSubscriptionDetection(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvai"))
	other, _ := s.Login(t, s.Register(t, "cvaiother"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000",
		"opening_date": time.Now().AddDate(0, -5, 0).Format(day)})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "250", "description": "Groceries"})

	if l := c.Do(t, http.MethodGet, "/ai/conversations", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("conversations before asking = %v", l)
	}
	ask := func(cl *apitest.Client, q string, conv any) map[string]any {
		body := map[string]any{"question": q}
		if conv != nil {
			body["conversation_id"] = conv
		}
		return cl.Do(t, http.MethodPost, "/ai/ask", body).Expect(t, http.StatusOK).Data()
	}
	a1 := ask(c, "How much did I spend this month?", nil)
	ask(c, "And last month?", a1["conversation_id"])
	a2 := ask(c, "How are my budgets?", nil)
	theirs := ask(other, "What is my income?", nil)
	if a1["source"] != "deterministic" || a1["conversation_id"] == nil || a2["conversation_id"] == a1["conversation_id"] {
		t.Fatalf("answers = %v / %v", a1, a2)
	}
	// List: own conversations, most recently updated first, with a title.
	l := c.Do(t, http.MethodGet, "/ai/conversations", nil).Expect(t, http.StatusOK).List()
	if got := ids(l, "id"); !slices.Equal(got, []string{a2["conversation_id"].(string), a1["conversation_id"].(string)}) {
		t.Fatalf("conversations = %v", l)
	}
	if c0 := l[1].(map[string]any); c0["title"] == "" || c0["updated_at"] == nil {
		t.Fatalf("conversation summary = %v", c0)
	}
	// Delete one: owner only; then gone with its messages.
	other.Do(t, http.MethodDelete, "/ai/conversations/"+a1["conversation_id"].(string), nil).Expect(t, http.StatusNotFound)
	del := c.Do(t, http.MethodDelete, "/ai/conversations/"+a1["conversation_id"].(string), nil).Expect(t, http.StatusOK).Data()
	if del["deleted"] != float64(1) {
		t.Fatalf("delete = %v", del)
	}
	c.Do(t, http.MethodGet, "/ai/conversations/"+a1["conversation_id"].(string), nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodDelete, "/ai/conversations/"+a1["conversation_id"].(string), nil).Expect(t, http.StatusNotFound)
	if got := ids(c.Do(t, http.MethodGet, "/ai/conversations", nil).Expect(t, http.StatusOK).List(), "id"); !slices.Equal(got, []string{a2["conversation_id"].(string)}) {
		t.Fatalf("conversations after delete = %v", got)
	}
	if n := workerCount(t, s, `select count(*) from ai_messages where conversation_id = $1`, a1["conversation_id"]); n != 0 {
		t.Fatalf("messages of a deleted conversation = %d", n)
	}
	if got := ids(other.Do(t, http.MethodGet, "/ai/conversations", nil).Expect(t, http.StatusOK).List(), "id"); !slices.Equal(got, []string{theirs["conversation_id"].(string)}) {
		t.Fatalf("other user's conversations = %v", got)
	}
	if r := c.Do(t, http.MethodDelete, "/ai/conversations/nope", nil); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("malformed conversation id: %d", r.Status)
	}

	// Detection: explainable rules over your own history; you confirm each.
	if r := c.Do(t, http.MethodPost, "/ai/subscriptions/detect", nil).Expect(t, http.StatusOK).Data(); r["new_candidates"] != float64(0) || r["pending_detections"] != float64(0) {
		t.Fatalf("detection without recurring charges = %v", r)
	}
	now := time.Now()
	for i := 3; i >= 0; i-- {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "149", "merchant_name": "Tune Stream",
			"local_date": now.AddDate(0, 0, -30*i).Format(day)})
	}
	r := c.Do(t, http.MethodPost, "/ai/subscriptions/detect", nil).Expect(t, http.StatusOK).Data()
	if r["new_candidates"] != float64(1) || r["pending_detections"] != float64(1) {
		t.Fatalf("detection = %v", r)
	}
	cands := c.Do(t, http.MethodGet, "/subscriptions/detections", nil).Expect(t, http.StatusOK).List()
	if len(cands) != 1 || cands[0].(map[string]any)["merchant_label"] != "Tune Stream" || cands[0].(map[string]any)["cadence"] != "monthly" {
		t.Fatalf("detections = %v", cands)
	}
	// Running again finds nothing new; nothing became a subscription.
	if again := c.Do(t, http.MethodPost, "/ai/subscriptions/detect", nil).Expect(t, http.StatusOK).Data(); again["new_candidates"] != float64(0) ||
		again["pending_detections"] != float64(1) {
		t.Fatalf("second detection = %v", again)
	}
	if subs := c.Do(t, http.MethodGet, "/subscriptions", nil).Expect(t, http.StatusOK).List(); len(subs) != 0 {
		t.Fatalf("detection created subscriptions: %v", subs)
	}
	if o := other.Do(t, http.MethodPost, "/ai/subscriptions/detect", nil).Expect(t, http.StatusOK).Data(); o["pending_detections"] != float64(0) {
		t.Fatalf("another user's detections = %v", o)
	}
}
