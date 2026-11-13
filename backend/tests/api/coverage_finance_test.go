package api_test

import (
	"net/http"
	"net/url"
	"slices"
	"testing"

	"montra/backend/internal/testutil/apitest"
)

// Coverage for personal-finance endpoints no other API test exercised:
// account balance history and account transaction lists, payment methods,
// search, transfers, bulk delete, duplicate, attachments, saved filters,
// category restore, rule and tag deletion.

const cvDay = "2006-01-02"

// cvAudit returns the actions of a transaction's audit history in order.
func cvAudit(t *testing.T, c *apitest.Client, id string) []string {
	t.Helper()
	var out []string
	for _, x := range c.Do(t, http.MethodGet, "/transactions/"+id+"/audit", nil).Expect(t, http.StatusOK).List() {
		out = append(out, x.(map[string]any)["action"].(string))
	}
	return out
}

func TestCoverageAccountBalanceHistoryAndAccountTransactions(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvbalance"))
	other, _ := s.Login(t, s.Register(t, "cvbalsnoop"))
	today := todayIn(t, "Asia/Kolkata")
	d := func(n int) string { return today.AddDate(0, 0, n).Format(cvDay) }

	acct := createAccount(t, c, map[string]any{"name": "Main", "account_type": "bank", "currency": "INR", "opening_balance": "1000",
		"opening_date": d(-5)})["id"].(string)
	second := createAccount(t, c, map[string]any{"name": "Wallet", "account_type": "cash", "currency": "INR"})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "100", "local_date": d(-3), "description": "Groceries"})
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "250.50", "local_date": d(-1), "description": "Refund cheque"})
	voided := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "40", "local_date": d(-2), "description": "Typo"})
	c.Do(t, http.MethodDelete, "/transactions/"+voided["id"].(string), nil).Expect(t, http.StatusOK)
	createTx(t, c, map[string]any{"type": "expense", "account_id": second, "amount": "5", "local_date": d(-1), "description": "Other account"})

	// As of a date: only ledger entries effective on or before it count;
	// voided transactions are reversed and do not count.
	at := c.Do(t, http.MethodGet, "/accounts/"+acct+"/balance?as_of="+d(-3), nil).Expect(t, http.StatusOK).Data()
	if at["account_id"] != acct || at["as_of"] != d(-3) || money(at, "balance") != "900.00" || at["balance_source"] != "calculated" ||
		at["verified"] != false || len(at["history"].([]any)) != 0 {
		t.Fatalf("balance as of %s = %v", d(-3), at)
	}
	if b := c.Do(t, http.MethodGet, "/accounts/"+acct+"/balance?as_of="+d(-6), nil).Expect(t, http.StatusOK).Data(); money(b, "balance") != "0.00" {
		t.Fatalf("balance before the opening date = %v", b["balance"])
	}
	// Default as_of is today in the user's time zone.
	now := c.Do(t, http.MethodGet, "/accounts/"+acct+"/balance", nil).Expect(t, http.StatusOK).Data()
	if now["as_of"] != d(0) || money(now, "balance") != "1150.50" || money(now, "balance") != balance(t, c, acct) {
		t.Fatalf("balance today = %v (account says %s)", now, balance(t, c, acct))
	}
	// Daily history: one point per day, running balance.
	h := c.Do(t, http.MethodGet, "/accounts/"+acct+"/balance?from="+d(-4)+"&to="+d(-1), nil).Expect(t, http.StatusOK).Data()["history"].([]any)
	want := [][2]string{{d(-4), "1000.00"}, {d(-3), "900.00"}, {d(-2), "900.00"}, {d(-1), "1150.50"}}
	if len(h) != len(want) {
		t.Fatalf("history = %v", h)
	}
	for i, w := range want {
		p := h[i].(map[string]any)
		if p["date"] != w[0] || money(p, "balance") != w[1] {
			t.Fatalf("history[%d] = %v, want %v", i, p, w)
		}
	}
	// Range validation: to before from, longer than two years, bad dates.
	gfField(t, c.Do(t, http.MethodGet, "/accounts/"+acct+"/balance?from="+d(-1)+"&to="+d(-4), nil), "query.from")
	gfField(t, c.Do(t, http.MethodGet, "/accounts/"+acct+"/balance?from="+today.AddDate(-3, 0, 0).Format(cvDay), nil), "query.from")
	gfField(t, c.Do(t, http.MethodGet, "/accounts/"+acct+"/balance?as_of=13-11-2026", nil), "query.as_of")
	// Owner only.
	other.Do(t, http.MethodGet, "/accounts/"+acct+"/balance", nil).Expect(t, http.StatusNotFound)

	// Account transactions: only this account, newest first, deleted
	// excluded by default and included with status=all, paginated.
	list := c.Do(t, http.MethodGet, "/accounts/"+acct+"/transactions", nil).Expect(t, http.StatusOK).List()
	var descs []string
	for _, x := range list {
		m := x.(map[string]any)
		if m["account_id"] != acct {
			t.Fatalf("another account's transaction listed: %v", m)
		}
		if m["description"] != nil {
			descs = append(descs, m["description"].(string))
		}
	}
	if !slices.Equal(descs, []string{"Refund cheque", "Groceries", "Opening balance"}) {
		t.Fatalf("account transactions = %v", descs)
	}
	all := c.Do(t, http.MethodGet, "/accounts/"+acct+"/transactions?status=all&type=expense", nil).Expect(t, http.StatusOK).List()
	if len(all) != 2 || !contains(ids(all, "id"), voided["id"].(string)) {
		t.Fatalf("status=all expenses = %v", all)
	}
	p1 := c.Do(t, http.MethodGet, "/accounts/"+acct+"/transactions?limit=1", nil).Expect(t, http.StatusOK)
	next, _ := p1.Body["meta"].(map[string]any)["next_cursor"].(string)
	if len(p1.List()) != 1 || next == "" {
		t.Fatalf("first page = %s", p1.Raw)
	}
	p2 := c.Do(t, http.MethodGet, "/accounts/"+acct+"/transactions?limit=1&cursor="+url.QueryEscape(next), nil).Expect(t, http.StatusOK).List()
	if len(p2) != 1 || p2[0].(map[string]any)["description"] != "Groceries" {
		t.Fatalf("second page = %v", p2)
	}
	if l := other.Do(t, http.MethodGet, "/accounts/"+acct+"/transactions", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("another user listed this account's transactions: %v", l)
	}
	gfField(t, c.Do(t, http.MethodGet, "/accounts/"+acct+"/transactions?limit=500", nil), "query.limit")
}

func TestCoveragePaymentMethodsListSearchAndTransferGet(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvpm"))
	other, _ := s.Login(t, s.Register(t, "cvpmsnoop"))
	acct := createAccount(t, c, map[string]any{"name": "Main", "account_type": "bank", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	savings := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR"})["id"].(string)

	// Payment methods: default first, then by label; archived hidden unless asked.
	cash := c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "cash", "label": "Pocket"}).Expect(t, http.StatusCreated).Data()
	card := c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "credit_card", "label": "Amex", "masked_hint": "1234",
		"account_id": acct}).Expect(t, http.StatusCreated).Data()
	upi := c.Do(t, http.MethodPost, "/payment-methods", map[string]any{"kind": "upi", "label": "Zeta UPI", "is_default": true}).Expect(t, http.StatusCreated).Data()
	// Deleting a payment method that transactions use archives it.
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "15", "description": "Chai", "payment_method_id": cash["id"]})
	if r := c.Do(t, http.MethodDelete, "/payment-methods/"+cash["id"].(string), nil).Expect(t, http.StatusOK).Data(); r["archived"] != true {
		t.Fatalf("deleting a used payment method = %v", r)
	}
	pms := c.Do(t, http.MethodGet, "/payment-methods", nil).Expect(t, http.StatusOK).List()
	if got := ids(pms, "id"); !slices.Equal(got, []string{upi["id"].(string), card["id"].(string)}) {
		t.Fatalf("payment methods = %v", pms)
	}
	first := pms[0].(map[string]any)
	second := pms[1].(map[string]any)
	if first["is_default"] != true || second["masked_hint"] != "1234" || second["account_id"] != acct || second["kind"] != "credit_card" {
		t.Fatalf("payment method fields = %v", pms)
	}
	withArchived := c.Do(t, http.MethodGet, "/payment-methods?include_archived=true", nil).Expect(t, http.StatusOK).List()
	if a := gfFind(withArchived, "id", cash["id"].(string)); len(withArchived) != 3 || a == nil || a["archived_at"] == nil {
		t.Fatalf("with archived = %v", withArchived)
	}
	if l := other.Do(t, http.MethodGet, "/payment-methods?include_archived=true", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("another user's payment methods = %v", l)
	}

	// Search uses the same filters as the list.
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "120", "description": "Blue Tokai coffee",
		"payment_method_id": card["id"]})
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "900", "description": "Electricity bill"})
	createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "60", "notes": "coffee money back"})
	hits := c.Do(t, http.MethodGet, "/transactions/search?q=coffee", nil).Expect(t, http.StatusOK).List()
	if len(hits) != 2 {
		t.Fatalf("search q=coffee = %v", hits)
	}
	if h := c.Do(t, http.MethodGet, "/transactions/search?q=coffee&type=expense", nil).Expect(t, http.StatusOK).List(); len(h) != 1 ||
		money(h[0].(map[string]any), "amount") != "120.00" || h[0].(map[string]any)["payment_method_id"] != card["id"] {
		t.Fatalf("search q=coffee&type=expense = %v", h)
	}
	if h := c.Do(t, http.MethodGet, "/transactions/search?payment_method_id="+card["id"].(string), nil).Expect(t, http.StatusOK).List(); len(h) != 1 {
		t.Fatalf("search by payment method = %v", h)
	}
	if h := c.Do(t, http.MethodGet, "/transactions/search?min_amount=100&currency=INR&type=expense&sort=amount_asc", nil).Expect(t, http.StatusOK).List(); len(h) != 2 ||
		money(h[0].(map[string]any), "amount") != "120.00" {
		t.Fatalf("search by amount = %v", h)
	}
	if h := other.Do(t, http.MethodGet, "/transactions/search?q=coffee", nil).Expect(t, http.StatusOK).List(); len(h) != 0 {
		t.Fatalf("search leaked another user's transactions: %v", h)
	}
	gfField(t, c.Do(t, http.MethodGet, "/transactions/search?sort=sideways", nil), "query.sort")

	// Transfers: read back with both legs and the fee; owner only; voided
	// transfers stay readable with status voided.
	tr := c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": acct, "to_account_id": savings, "amount": "700",
		"fee": "5", "description": "Monthly saving"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	id := tr["id"].(string)
	got := c.Do(t, http.MethodGet, "/transactions/transfers/"+id, nil).Expect(t, http.StatusOK).Data()
	if got["from_account_id"] != acct || got["to_account_id"] != savings || money(got, "from_amount") != "700.00" ||
		money(got, "to_amount") != "700.00" || money(got, "fee") != "5.00" || got["status"] != "posted" || got["description"] != "Monthly saving" ||
		got["from_transaction_id"] != tr["from_transaction_id"] || got["fee_transaction_id"] == nil || got["fx_rate"] != nil {
		t.Fatalf("transfer = %v", got)
	}
	leg := c.Do(t, http.MethodGet, "/transactions/"+got["to_transaction_id"].(string), nil).Expect(t, http.StatusOK).Data()
	if leg["transfer_id"] != id || leg["direction"] != "inflow" {
		t.Fatalf("incoming leg = %v", leg)
	}
	other.Do(t, http.MethodGet, "/transactions/transfers/"+id, nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodGet, "/transactions/transfers/"+leg["id"].(string), nil).Expect(t, http.StatusNotFound) // a leg id is not a transfer id
	c.Do(t, http.MethodDelete, "/transactions/transfers/"+id, nil).Expect(t, http.StatusOK)
	if v := c.Do(t, http.MethodGet, "/transactions/transfers/"+id, nil).Expect(t, http.StatusOK).Data(); v["status"] != "voided" {
		t.Fatalf("voided transfer = %v", v)
	}
	if r := c.Do(t, http.MethodGet, "/transactions/transfers/not-a-uuid", nil); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("malformed transfer id: %d %s", r.Status, r.Raw)
	}
}

func TestCoverageBulkDeleteAndDuplicate(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvbulk"))
	other, _ := s.Login(t, s.Register(t, "cvbulksnoop"))
	today := todayIn(t, "Asia/Kolkata")
	acct := createAccount(t, c, map[string]any{"name": "Main", "account_type": "bank", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	savings := createAccount(t, c, map[string]any{"name": "Savings", "account_type": "savings", "currency": "INR"})["id"].(string)
	otherAcct := createAccount(t, other, map[string]any{"name": "Theirs", "account_type": "cash", "currency": "INR"})["id"].(string)
	theirs := createTx(t, other, map[string]any{"type": "expense", "account_id": otherAcct, "amount": "1"})["id"].(string)

	food := categoryID(t, c, "Food & dining")
	tag := c.Do(t, http.MethodPost, "/tags", map[string]any{"name": "Lunch"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	a := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "100", "description": "A"})["id"].(string)
	b := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "50", "description": "B"})["id"].(string)
	tr := c.Do(t, http.MethodPost, "/transactions/transfers", map[string]any{"from_account_id": acct, "to_account_id": savings, "amount": "200"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()

	// Confirmation is required, the list must be non-empty and bounded.
	gfField(t, c.Do(t, http.MethodPost, "/transactions/bulk-delete", map[string]any{"transaction_ids": []string{a}, "confirm": false}), "body.confirm")
	gfField(t, c.Do(t, http.MethodPost, "/transactions/bulk-delete", map[string]any{"transaction_ids": []string{}, "confirm": true}), "body.transaction_ids")
	// All or nothing: one id the caller cannot see fails the whole request.
	c.Do(t, http.MethodPost, "/transactions/bulk-delete", map[string]any{"transaction_ids": []string{a, theirs}, "confirm": true}).Expect(t, http.StatusNotFound)
	if balance(t, c, acct) != "650.00" {
		t.Fatalf("a failed bulk delete changed the balance: %s", balance(t, c, acct))
	}
	if g := other.Do(t, http.MethodGet, "/transactions/"+theirs, nil).Expect(t, http.StatusOK).Data(); g["status"] != "posted" {
		t.Fatalf("another user's transaction touched: %v", g)
	}
	// Deleting a transfer leg removes the whole transfer; duplicates in the
	// list are ignored.
	res := c.Do(t, http.MethodPost, "/transactions/bulk-delete", map[string]any{"transaction_ids": []string{a, b, a, tr["from_transaction_id"].(string)},
		"confirm": true}).Expect(t, http.StatusOK).Data()
	if res["updated"] != float64(3) {
		t.Fatalf("bulk delete result = %v", res)
	}
	if balance(t, c, acct) != "1000.00" || balance(t, c, savings) != "0.00" {
		t.Fatalf("balances after bulk delete: %s %s", balance(t, c, acct), balance(t, c, savings))
	}
	if g := c.Do(t, http.MethodGet, "/transactions/transfers/"+tr["id"].(string), nil).Expect(t, http.StatusOK).Data(); g["status"] != "voided" {
		t.Fatalf("transfer after bulk delete = %v", g)
	}
	if acts := cvAudit(t, c, a); acts[len(acts)-1] != "voided" {
		t.Fatalf("audit of a bulk-deleted transaction = %v", acts)
	}
	// Restorable afterwards.
	c.Do(t, http.MethodPost, "/transactions/"+a+"/restore", nil).Expect(t, http.StatusOK)
	if balance(t, c, acct) != "900.00" {
		t.Fatalf("restore after bulk delete: %s", balance(t, c, acct))
	}

	// Duplicate: a new posted transaction with the same details on the
	// requested date (default today), idempotent, audited with its source.
	src := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "75.25", "description": "Thali", "notes": "office",
		"category_id": food, "tag_ids": []string{tag}, "local_date": today.AddDate(0, 0, -10).Format(cvDay)})
	k := key()
	day := today.AddDate(0, 0, -2).Format(cvDay)
	dup := c.Do(t, http.MethodPost, "/transactions/"+src["id"].(string)+"/duplicate", map[string]any{"local_date": day}, "Idempotency-Key", k).
		Expect(t, http.StatusCreated).Data()["transaction"].(map[string]any)
	if dup["id"] == src["id"] || dup["description"] != "Thali" || dup["notes"] != "office" || money(dup, "amount") != "75.25" ||
		dup["category"].(map[string]any)["id"] != food || len(dup["tags"].([]any)) != 1 || dup["local_date"] != day || dup["status"] != "posted" ||
		dup["account_id"] != acct {
		t.Fatalf("duplicate = %v", dup)
	}
	again := c.Do(t, http.MethodPost, "/transactions/"+src["id"].(string)+"/duplicate", map[string]any{"local_date": day}, "Idempotency-Key", k).
		Expect(t, http.StatusCreated)
	if again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["transaction"].(map[string]any)["id"] != dup["id"] {
		t.Fatalf("duplicate retry did not replay: %s", again.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/transactions/"+src["id"].(string)+"/duplicate", map[string]any{}, "Idempotency-Key", k); r.ErrorCode() != "IDEMPOTENCY_CONFLICT" {
		t.Fatalf("same key with a different body: %s", r.Raw)
	}
	if balance(t, c, acct) != "749.50" { // 900 - 75.25 - 75.25
		t.Fatalf("balance after one duplicate = %s", balance(t, c, acct))
	}
	if acts := cvAudit(t, c, dup["id"].(string)); !slices.Equal(acts, []string{"created", "duplicated"}) {
		t.Fatalf("duplicate audit = %v", acts)
	}
	def := c.Do(t, http.MethodPost, "/transactions/"+src["id"].(string)+"/duplicate", map[string]any{}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()["transaction"].(map[string]any)
	if def["local_date"] != today.Format(cvDay) {
		t.Fatalf("default duplicate date = %v", def["local_date"])
	}
	// Key required; transfers cannot be duplicated; others' transactions are not found.
	if r := c.Do(t, http.MethodPost, "/transactions/"+src["id"].(string)+"/duplicate", map[string]any{}); r.Status != http.StatusUnprocessableEntity &&
		r.Status != http.StatusBadRequest {
		t.Fatalf("duplicate without Idempotency-Key: %d %s", r.Status, r.Raw)
	}
	gfCoded(t, c.Do(t, http.MethodPost, "/transactions/"+tr["to_transaction_id"].(string)+"/duplicate", map[string]any{}, "Idempotency-Key", key()),
		http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "cannot_duplicate")
	c.Do(t, http.MethodPost, "/transactions/"+theirs+"/duplicate", map[string]any{}, "Idempotency-Key", key()).Expect(t, http.StatusNotFound)
}

func TestCoverageTransactionAttachments(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvattach"))
	other, _ := s.Login(t, s.Register(t, "cvattachsnoop"))
	acct := createAccount(t, c, map[string]any{"name": "Main", "account_type": "bank", "currency": "INR"})["id"].(string)
	tx := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "10", "description": "Lunch"})["id"].(string)
	img := pngBytes(t)
	receipt := uploadFile(t, c, "receipt", "lunch.png", "image/png", img)
	doc := uploadFile(t, c, "transaction_attachment", "invoice.png", "image/png", img)
	avatar := uploadFile(t, c, "avatar", "me.png", "image/png", img)
	pending := c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": "receipt", "filename": "later.png", "content_type": "image/png",
		"size_bytes": len(img)}).Expect(t, http.StatusCreated).Data()["file"].(map[string]any)["id"].(string)
	theirs := uploadFile(t, other, "receipt", "theirs.png", "image/png", img)

	if l := c.Do(t, http.MethodGet, "/transactions/"+tx+"/attachments", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("new transaction attachments = %v", l)
	}
	got := c.Do(t, http.MethodPost, "/transactions/"+tx+"/attachments", map[string]any{"file_id": receipt}).Expect(t, http.StatusOK).Data()
	if got["id"] != tx || got["attachment_count"] != float64(1) {
		t.Fatalf("attach result = %v", got)
	}
	// Attaching the same file twice is a no-op.
	c.Do(t, http.MethodPost, "/transactions/"+tx+"/attachments", map[string]any{"file_id": receipt}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/transactions/"+tx+"/attachments", map[string]any{"file_id": doc}).Expect(t, http.StatusOK)
	l := c.Do(t, http.MethodGet, "/transactions/"+tx+"/attachments", nil).Expect(t, http.StatusOK).List()
	if !slices.Equal(ids(l, "file_id"), []string{receipt, doc}) {
		t.Fatalf("attachments = %v", l)
	}
	first := l[0].(map[string]any)
	if first["purpose"] != "receipt" || first["filename"] != "lunch.png" || first["content_type"] != "image/png" ||
		first["size_bytes"] != float64(len(img)) || first["attached_at"] == nil {
		t.Fatalf("attachment fields = %v", first)
	}
	if g := c.Do(t, http.MethodGet, "/transactions/"+tx, nil).Expect(t, http.StatusOK).Data(); g["attachment_count"] != float64(2) {
		t.Fatalf("attachment_count = %v", g["attachment_count"])
	}
	if h := c.Do(t, http.MethodGet, "/transactions?has_attachment=true", nil).Expect(t, http.StatusOK).List(); len(h) != 1 || h[0].(map[string]any)["id"] != tx {
		t.Fatalf("has_attachment filter = %v", h)
	}

	// Validation: unknown/others' file, wrong purpose, not uploaded yet.
	gfField(t, c.Do(t, http.MethodPost, "/transactions/"+tx+"/attachments", map[string]any{"file_id": theirs}), "body.file_id")
	gfCoded(t, c.Do(t, http.MethodPost, "/transactions/"+tx+"/attachments", map[string]any{"file_id": avatar}),
		http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "file_not_attachable")
	gfCoded(t, c.Do(t, http.MethodPost, "/transactions/"+tx+"/attachments", map[string]any{"file_id": pending}),
		http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "file_not_ready")
	// Ownership: another user can neither list, attach to nor detach from it.
	other.Do(t, http.MethodGet, "/transactions/"+tx+"/attachments", nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodPost, "/transactions/"+tx+"/attachments", map[string]any{"file_id": theirs}).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodDelete, "/transactions/"+tx+"/attachments/"+receipt, nil).Expect(t, http.StatusNotFound)

	// Detach keeps the file; detaching again is not found.
	c.Do(t, http.MethodDelete, "/transactions/"+tx+"/attachments/"+receipt, nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodDelete, "/transactions/"+tx+"/attachments/"+receipt, nil).Expect(t, http.StatusNotFound)
	if l := c.Do(t, http.MethodGet, "/transactions/"+tx+"/attachments", nil).Expect(t, http.StatusOK).List(); !slices.Equal(ids(l, "file_id"), []string{doc}) {
		t.Fatalf("attachments after detach = %v", l)
	}
	if f := c.Do(t, http.MethodGet, "/files/"+receipt, nil).Expect(t, http.StatusOK).Data(); f["status"] != "ready" {
		t.Fatalf("detached file = %v", f)
	}
	// A deleted file drops out of the list.
	c.Do(t, http.MethodDelete, "/files/"+doc, nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	if l := c.Do(t, http.MethodGet, "/transactions/"+tx+"/attachments", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("deleted file still listed: %v", l)
	}
	acts := cvAudit(t, c, tx)
	if n := len(slices.DeleteFunc(slices.Clone(acts), func(a string) bool { return a != "attachment_added" })); n != 3 || !slices.Contains(acts, "attachment_removed") {
		t.Fatalf("attachment audit = %v", acts)
	}
}

func TestCoverageSavedFilters(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvfilters"))
	other, _ := s.Login(t, s.Register(t, "cvfiltersnoop"))

	f1 := c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "transactions", "name": "  Big spends ",
		"filter": map[string]any{"min_amount": "1000", "type": []string{"expense"}}}).Expect(t, http.StatusCreated).Data()
	if f1["name"] != "Big spends" || f1["scope"] != "transactions" || f1["filter"].(map[string]any)["min_amount"] != "1000" || f1["id"] == nil {
		t.Fatalf("saved filter = %v", f1)
	}
	c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "transactions", "name": "Alpha", "filter": map[string]any{}}).Expect(t, http.StatusCreated)
	rep := c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "reports", "name": "Big spends", "filter": map[string]any{"range": "this_year"}}).
		Expect(t, http.StatusCreated).Data()
	// Names are unique per scope, case-insensitively.
	if r := c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "transactions", "name": "BIG SPENDS", "filter": map[string]any{}}); r.Status != http.StatusConflict ||
		r.ErrorCode() != "CONFLICT" {
		t.Fatalf("duplicate name: %d %s", r.Status, r.Raw)
	}
	// Validation.
	gfField(t, c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "budgets", "name": "x", "filter": map[string]any{}}), "body.scope")
	gfField(t, c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "search", "name": "", "filter": map[string]any{}}), "body.name")
	gfField(t, c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "search", "name": "   ", "filter": map[string]any{}}), "body.name")
	big := map[string]any{}
	for i := 0; i < 300; i++ {
		big[key()] = i
	}
	gfField(t, c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "search", "name": "huge", "filter": big}), "body.filter")
	gfField(t, c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "search", "name": "list", "filter": []any{1, 2}}), "body.filter")
	if r := c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "search", "name": "none"}); r.Status != http.StatusUnprocessableEntity ||
		detail(t, r)["code"] != "required" || detail(t, r)["params"].(map[string]any)["property"] != "filter" {
		t.Fatalf("missing filter: %d %s", r.Status, r.Raw)
	}
	gfField(t, c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "search", "name": "null", "filter": nil}), "body.filter")

	// Listing: by name, optionally per scope; private to the owner.
	all := c.Do(t, http.MethodGet, "/saved-filters", nil).Expect(t, http.StatusOK).List()
	if names := fieldsOf(all, "name"); !slices.Equal(names, []string{"Alpha", "Big spends", "Big spends"}) {
		t.Fatalf("all filters = %v", names)
	}
	tx := c.Do(t, http.MethodGet, "/saved-filters?scope=transactions", nil).Expect(t, http.StatusOK).List()
	if names := fieldsOf(tx, "name"); !slices.Equal(names, []string{"Alpha", "Big spends"}) {
		t.Fatalf("transaction filters = %v", names)
	}
	gfField(t, c.Do(t, http.MethodGet, "/saved-filters?scope=budgets", nil), "query.scope")
	if l := other.Do(t, http.MethodGet, "/saved-filters", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("another user's filters = %v", l)
	}

	// Delete: owner only, then gone; the name can be reused.
	other.Do(t, http.MethodDelete, "/saved-filters/"+f1["id"].(string), nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodDelete, "/saved-filters/"+f1["id"].(string), nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodDelete, "/saved-filters/"+f1["id"].(string), nil).Expect(t, http.StatusNotFound)
	if l := c.Do(t, http.MethodGet, "/saved-filters?scope=transactions", nil).Expect(t, http.StatusOK).List(); len(l) != 1 {
		t.Fatalf("after delete = %v", l)
	}
	if l := c.Do(t, http.MethodGet, "/saved-filters?scope=reports", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != rep["id"] {
		t.Fatalf("other scope touched by delete: %v", l)
	}
	c.Do(t, http.MethodPost, "/saved-filters", map[string]any{"scope": "transactions", "name": "Big spends", "filter": map[string]any{}}).Expect(t, http.StatusCreated)
}

func TestCoverageCategoryRestoreRuleAndTagDelete(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvlabels"))
	other, _ := s.Login(t, s.Register(t, "cvlabelsnoop"))
	acct := createAccount(t, c, map[string]any{"name": "Main", "account_type": "bank", "currency": "INR"})["id"].(string)
	food := categoryID(t, c, "Food & dining")

	// Restore: archived parent and its subcategory come back separately;
	// a name taken meanwhile blocks the restore.
	pets := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Pets", "kind": "expense"}).Expect(t, http.StatusCreated).Data()
	vet := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Vet", "kind": "expense", "parent_id": pets["id"]}).Expect(t, http.StatusCreated).Data()
	c.Do(t, http.MethodPost, "/categories/"+pets["id"].(string)+"/archive", nil).Expect(t, http.StatusOK)
	gfField(t, c.Do(t, http.MethodPost, "/transactions", map[string]any{"type": "expense", "account_id": acct, "amount": "1", "category_id": vet["id"]},
		"Idempotency-Key", key()), "body.category_id")
	other.Do(t, http.MethodPost, "/categories/"+pets["id"].(string)+"/restore", nil).Expect(t, http.StatusNotFound)
	r := c.Do(t, http.MethodPost, "/categories/"+pets["id"].(string)+"/restore", nil).Expect(t, http.StatusOK).Data()
	if r["status"] != "active" || r["version"].(float64) <= pets["version"].(float64) {
		t.Fatalf("restored = %v", r)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'category' and entity_id = $1 and action = 'restored'`, pets["id"]); n != 1 {
		t.Fatalf("restore audit rows = %d", n)
	}
	c.Do(t, http.MethodPost, "/categories/"+vet["id"].(string)+"/restore", nil).Expect(t, http.StatusOK)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1", "category_id": vet["id"]})
	c.Do(t, http.MethodPost, "/categories/"+pets["id"].(string)+"/archive", nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "pets", "kind": "expense"}).Expect(t, http.StatusCreated)
	gfCoded(t, c.Do(t, http.MethodPost, "/categories/"+pets["id"].(string)+"/restore", nil), http.StatusConflict, "CONFLICT", "name_taken")
	// Merged categories cannot be restored.
	tmp := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Snacks", "kind": "expense"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	c.Do(t, http.MethodPost, "/categories/merge", map[string]any{"source_ids": []any{tmp}, "target_id": food}).Expect(t, http.StatusOK)
	gfCoded(t, c.Do(t, http.MethodPost, "/categories/"+tmp+"/restore", nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "category_merged")

	// Rule delete: the rule stops applying; owner only; idempotent 404.
	rule := c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Coffee", "match_field": "description", "match_type": "contains",
		"pattern": "coffee", "set_category_id": food}).Expect(t, http.StatusCreated).Data()["id"].(string)
	if tx := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "3", "description": "coffee"}); tx["category"] == nil {
		t.Fatal("rule did not apply before deletion")
	}
	other.Do(t, http.MethodDelete, "/category-rules/"+rule, nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodDelete, "/category-rules/"+rule, nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodDelete, "/category-rules/"+rule, nil).Expect(t, http.StatusNotFound)
	if tx := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "3", "description": "coffee again"}); tx["category"] != nil {
		t.Fatalf("deleted rule still applied: %v", tx["category"])
	}
	if l := c.Do(t, http.MethodGet, "/category-rules", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("rules after delete = %v", l)
	}

	// Tag delete: transactions keep existing without the tag; audited.
	tag := c.Do(t, http.MethodPost, "/tags", map[string]any{"name": "Trip"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	keep := c.Do(t, http.MethodPost, "/tags", map[string]any{"name": "Keep"}).Expect(t, http.StatusCreated).Data()["id"].(string)
	tagged := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "9", "tag_ids": []string{tag, keep}})["id"].(string)
	other.Do(t, http.MethodDelete, "/tags/"+tag, nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodDelete, "/tags/"+tag, nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodDelete, "/tags/"+tag, nil).Expect(t, http.StatusNotFound)
	got := c.Do(t, http.MethodGet, "/transactions/"+tagged, nil).Expect(t, http.StatusOK).Data()
	if tags := ids(got["tags"].([]any), "id"); !slices.Equal(tags, []string{keep}) || got["status"] != "posted" {
		t.Fatalf("transaction after tag delete = %v", got)
	}
	if l := c.Do(t, http.MethodGet, "/tags", nil).Expect(t, http.StatusOK).List(); slices.Contains(ids(l, "id"), tag) {
		t.Fatalf("deleted tag still listed: %v", l)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'tag' and entity_id = $1 and action = 'deleted'`, tag); n != 1 {
		t.Fatalf("tag delete audit rows = %d", n)
	}
}
