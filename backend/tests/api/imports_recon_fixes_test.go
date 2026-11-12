package api_test

import (
	"fmt"
	"net/http"
	"net/url"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/testutil/apitest"
)

// pageOf fetches one cursor page and returns its items and meta.
func pageOf(t *testing.T, c *apitest.Client, path string) ([]any, map[string]any) {
	t.Helper()
	r := c.Do(t, http.MethodGet, path, nil).Expect(t, http.StatusOK)
	meta, _ := r.Body["meta"].(map[string]any)
	if _, ok := meta["has_more"]; !ok {
		t.Fatalf("%s is not paged: %s", path, r.Raw)
	}
	return r.List(), meta
}

// walkPages follows next_cursor from path (which already has a query string)
// and returns the IDs of every item in order, failing on repeats.
func walkPages(t *testing.T, c *apitest.Client, path, idField string) (got []string, pages int) {
	t.Helper()
	seen := map[string]bool{}
	next := path
	for next != "" {
		items, meta := pageOf(t, c, next)
		pages++
		for _, x := range items {
			id := x.(map[string]any)[idField].(string)
			if seen[id] {
				t.Fatalf("%s repeated across pages", id)
			}
			seen[id] = true
			got = append(got, id)
		}
		next = ""
		if meta["has_more"] == true {
			cur, _ := meta["next_cursor"].(string)
			if cur == "" {
				t.Fatalf("has_more without next_cursor: %v", meta)
			}
			next = path + "&cursor=" + url.QueryEscape(cur)
		}
	}
	return got, pages
}

func fieldsOf(items []any, field string) []string {
	var out []string
	for _, x := range items {
		out = append(out, x.(map[string]any)[field].(string))
	}
	return out
}

func rowContaining(t *testing.T, rows []map[string]any, contains string) map[string]any {
	t.Helper()
	for _, r := range rows {
		if d, _ := r["description"].(string); strings.Contains(d, contains) {
			return r
		}
	}
	t.Fatalf("no row with %q in %v", contains, rows)
	return nil
}

func paramsOf(v any) map[string]any {
	p, _ := v.(map[string]any)
	return p
}

// I9 + I6: creating an import needs an Idempotency-Key and a retry returns
// the same batch; the import list pages with a cursor and keeps its default.
func TestImportCreateIdempotentAndImportPages(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "importkeys"))
	other, _ := s.Login(t, s.Register(t, "importkeysother"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	csv := func(desc string) []byte {
		return []byte("Date,Description,Amount\n" + time.Now().AddDate(0, 0, -1).Format(day) + "," + desc + ",-10.00\n")
	}
	fid := uploadFile(t, c, "statement_import", "a.csv", "text/csv", csv("Snack"))
	body := map[string]any{"account_id": acct, "file_id": fid}

	if r := c.Do(t, http.MethodPost, "/imports", body); r.Status != http.StatusUnprocessableEntity || r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("create without Idempotency-Key: %d %s", r.Status, r.Raw)
	}
	k := key()
	first := c.Do(t, http.MethodPost, "/imports", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	again := c.Do(t, http.MethodPost, "/imports", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	bid := first.Data()["id"].(string)
	if first.Headers.Get("Idempotent-Replayed") != "" || again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["id"] != bid ||
		again.Data()["status"] != "uploaded" {
		t.Fatalf("create replay: %s / %s", first.Raw, again.Raw)
	}
	s.RunJobs(t)
	// One batch and one parse, however often the request was sent.
	if n := workerCount(t, s, `select count(*) from import_batches where account_id = $1`, uuid.MustParse(acct)); n != 1 {
		t.Fatalf("a retried create made %d batches", n)
	}
	if n := workerCount(t, s, `select count(*) from jobs where type = 'imports.parse' and payload->>'batch_id' = $1`, bid); n != 1 {
		t.Fatalf("a retried create queued %d parses", n)
	}
	if b := batch(t, c, bid); b["status"] != "preview_ready" || b["to_import_rows"] != float64(1) {
		t.Fatalf("batch after parse = %v", b)
	}
	// The key belongs to that request.
	fid2 := uploadFile(t, c, "statement_import", "b.csv", "text/csv", csv("Tea"))
	if r := c.Do(t, http.MethodPost, "/imports", map[string]any{"account_id": acct, "file_id": fid2}, "Idempotency-Key", k); r.ErrorCode() != "IDEMPOTENCY_CONFLICT" {
		t.Fatalf("key reused for another file: %d %s", r.Status, r.Raw)
	}

	created := []string{bid}
	for _, f := range []string{fid2, uploadFile(t, c, "statement_import", "c.csv", "text/csv", csv("Lunch"))} {
		b := c.Do(t, http.MethodPost, "/imports", map[string]any{"account_id": acct, "file_id": f}, "Idempotency-Key", key()).
			Expect(t, http.StatusCreated).Data()
		created = append(created, b["id"].(string))
	}
	slices.Reverse(created) // newest first
	all, meta := pageOf(t, c, "/imports")
	if !slices.Equal(fieldsOf(all, "id"), created) || meta["has_more"] != false || meta["next_cursor"] != nil {
		t.Fatalf("default page = %v %v, want %v", fieldsOf(all, "id"), meta, created)
	}
	got, pages := walkPages(t, c, "/imports?limit=2", "id")
	if !slices.Equal(got, created) || pages != 2 {
		t.Fatalf("paged %v in %d pages, want %v in 2", got, pages, created)
	}
	if got, _ := walkPages(t, c, "/imports?account_id="+acct+"&limit=1", "id"); !slices.Equal(got, created) {
		t.Fatalf("paged by account %v, want %v", got, created)
	}
	r := c.Do(t, http.MethodGet, "/imports?cursor=not-a-cursor", nil).Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["field"] != "query.cursor" {
		t.Fatalf("bad cursor: %v", d)
	}
	// Owner only.
	if l, _ := pageOf(t, other, "/imports"); len(l) != 0 {
		t.Fatalf("another user listed %d imports", len(l))
	}
	other.Do(t, http.MethodPost, "/imports", body, "Idempotency-Key", key()).Expect(t, http.StatusUnprocessableEntity)
}

// I1, I3 (last_import_at), I4, I7 (row codes) and I8: processing failures
// keep their specific reason, to_import_rows follows confirm's rule, totals
// are Money, and the account records the import without a version bump.
func TestImportFailureReasonsCountsTotalsAndLastImport(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "importreasons"))
	today := time.Now()
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "10000",
		"opening_date": today.AddDate(0, -2, 0).Format(day)})["id"].(string)
	d := func(n int) time.Time { return today.AddDate(0, 0, -n) }
	manual := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1250.50", "description": "Grocer weekly shop",
		"local_date": d(10).Format(day)})
	before := c.Do(t, http.MethodGet, "/accounts/"+acct, nil).Expect(t, http.StatusOK).Data()
	if before["last_import_at"] != nil {
		t.Fatalf("new account has last_import_at: %v", before)
	}
	csv := strings.Join([]string{
		"Txn Date,Narration,Ref No,Withdrawal Amt,Deposit Amt,Closing Balance",
		ddmmyyyy(d(10)) + ",UPI-GROCER-WEEKLY SHOP,UPI001,\"1,250.50\",,\"8,749.50\"",
		ddmmyyyy(d(9)) + ",SALARY ACME LTD,NEFT77,,\"60,000.00\",\"68,749.50\"",
		ddmmyyyy(d(8)) + ",COFFEE HOUSE,,120.00,,\"68,629.50\"",
		ddmmyyyy(d(5)) + ",BOOKSTORE,,abc,,\"68,629.50\"",
		ddmmyyyy(today.AddDate(3, 0, 0)) + ",ANNUAL PLAN,,999.00,,\"67,630.50\"", // three years ahead: refused when processed
	}, "\n") + "\n"
	b := startImport(t, s, c, acct, []byte(csv))
	bid := b["id"].(string)
	if b["status"] != "preview_ready" || b["to_import_rows"] != float64(3) {
		t.Fatalf("preview = %v (to_import_rows %v)", b["status"], b["to_import_rows"])
	}
	// Totals are Money objects; the minor-unit fields stay.
	tot := b["totals"].(map[string]any)
	if money(tot, "inflow") != "60000.00" || money(tot, "outflow") != "2369.50" || money(tot, "net") != "57630.50" ||
		money(tot, "opening_balance") != "10000.00" || money(tot, "closing_balance") != "67630.50" || tot["balance_check"] != "ok" ||
		tot["inflow"].(map[string]any)["currency"] != "INR" || tot["inflow_minor"] != float64(6000000) || tot["outflow_minor"] != float64(236950) ||
		tot["net_minor"] != float64(5763050) || tot["opening_balance_minor"] != float64(1000000) || tot["closing_balance_minor"] != float64(6763050) {
		t.Fatalf("totals = %v", tot)
	}
	// Reading reasons carry codes, the field to correct and values.
	bad := importRows(t, c, bid, "invalid")
	if len(bad) != 1 || bad[0]["error_code"] != "bad_amount" || bad[0]["error_field"] != "amount" || paramsOf(bad[0]["error_params"])["currency"] != "INR" {
		t.Fatalf("invalid row = %v", bad)
	}
	dup := importRows(t, c, bid, "duplicate")
	if len(dup) != 1 || dup[0]["error_code"] != "possible_duplicate" || dup[0]["duplicate_of_transaction_id"] != manual["id"] ||
		!slices.Equal(strList(dup[0]["duplicate_reason_codes"]), []string{"same_amount_direction", "same_date", "similar_description"}) ||
		paramsOf(dup[0]["error_params"])["days_apart"] != "0" || dup[0]["error_field"] != nil {
		t.Fatalf("possible duplicate = %v", dup)
	}
	// to_import_rows follows the decisions confirm uses.
	ready := importRows(t, c, bid, "ready")
	coffee, future := rowContaining(t, ready, "COFFEE"), rowContaining(t, ready, "ANNUAL")
	c.Do(t, http.MethodPatch, "/imports/"+bid+"/rows/"+coffee["id"].(string), map[string]any{"decision": "skip"}).Expect(t, http.StatusOK)
	if n := batch(t, c, bid)["to_import_rows"]; n != float64(2) {
		t.Fatalf("after skipping a row to_import_rows = %v", n)
	}
	c.Do(t, http.MethodPatch, "/imports/"+bid+"/rows/"+dup[0]["id"].(string), map[string]any{"decision": "import"}).Expect(t, http.StatusOK)
	b = batch(t, c, bid)
	if b["to_import_rows"] != float64(3) {
		t.Fatalf("after choosing to import the duplicate to_import_rows = %v", b["to_import_rows"])
	}
	c.Do(t, http.MethodPost, "/imports/"+bid+"/confirm", map[string]any{"version": b["version"]}, "Idempotency-Key", key()).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	b = batch(t, c, bid)
	if b["status"] != "completed_with_errors" || b["imported_count"] != float64(2) || b["failed_count"] != float64(1) || b["to_import_rows"] != float64(0) {
		t.Fatalf("after processing = %v imported %v failed %v to_import %v", b["status"], b["imported_count"], b["failed_count"], b["to_import_rows"])
	}
	// I1: the stored reason is the specific one, with a stable code.
	failed := importRows(t, c, bid, "failed")
	if len(failed) != 1 || failed[0]["id"] != future["id"] || failed[0]["error_code"] != "invalid_date" || failed[0]["error_field"] != "posted_date" ||
		failed[0]["error_message"] != "Date is too far in the future." {
		t.Fatalf("failed row = %v", failed)
	}
	// I3: the account knows when statement data arrived; no version bump.
	acc := c.Do(t, http.MethodGet, "/accounts/"+acct, nil).Expect(t, http.StatusOK).Data()
	first, _ := acc["last_import_at"].(string)
	if first == "" || !sameInstant(t, first, b["completed_at"]) || acc["version"] != before["version"] {
		t.Fatalf("account after import = %v (batch completed_at %v)", acc, b["completed_at"])
	}
	// Correcting the row makes it importable again; the retry imports it.
	c.Do(t, http.MethodPatch, "/imports/"+bid+"/rows/"+future["id"].(string), map[string]any{"posted_date": today.Format(day)}).Expect(t, http.StatusOK)
	if n := batch(t, c, bid)["to_import_rows"]; n != float64(1) {
		t.Fatalf("after correcting the failed row to_import_rows = %v", n)
	}
	c.Do(t, http.MethodPost, "/imports/"+bid+"/retry-failed", nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	b = batch(t, c, bid)
	acc = c.Do(t, http.MethodGet, "/accounts/"+acct, nil).Expect(t, http.StatusOK).Data()
	if b["status"] != "completed" || b["imported_count"] != float64(3) || !sameInstant(t, acc["last_import_at"].(string), b["completed_at"]) ||
		!isLater(t, acc["last_import_at"].(string), first) {
		t.Fatalf("after retry = %v imported %v; account last_import_at %v (was %s)", b["status"], b["imported_count"], acc["last_import_at"], first)
	}
	// Rollback reports its counts as values, not only in English.
	c.Do(t, http.MethodPost, "/imports/"+bid+"/rollback", nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	b = batch(t, c, bid)
	if b["error_code"] != "rolled_back" || paramsOf(b["error_params"])["voided"] != "3" || paramsOf(b["error_params"])["kept"] != "0" {
		t.Fatalf("rollback = %v %v %v", b["error_code"], b["error_message"], b["error_params"])
	}
}

func sameInstant(t *testing.T, a string, b any) bool {
	t.Helper()
	bs, _ := b.(string)
	ta, err1 := time.Parse(time.RFC3339Nano, a)
	tb, err2 := time.Parse(time.RFC3339Nano, bs)
	return err1 == nil && err2 == nil && ta.Equal(tb)
}

func isLater(t *testing.T, a, b string) bool {
	t.Helper()
	ta, err1 := time.Parse(time.RFC3339Nano, a)
	tb, err2 := time.Parse(time.RFC3339Nano, b)
	return err1 == nil && err2 == nil && ta.After(tb)
}

// I7 (mapping notes and batch errors): notes and failures carry codes and
// the values they refer to next to the English text.
func TestImportNoteCodesAndBatchErrorParams(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "importnotes"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	// Every date reads day-first or month-first; amounts use a decimal comma.
	b := startImport(t, s, c, acct, []byte("Date;Description;Amount\n01/02/2026;Bakery;-12,50\n03/04/2026;Tea;-4,00\n"))
	codes, notes := strList(b["mapping_note_codes"]), strList(b["mapping_notes"])
	np := paramsOf(b["mapping_note_params"])
	if !slices.Equal(codes, []string{"ambiguous_date_order", "decimal_comma", "check_sign_convention"}) || len(notes) != len(codes) ||
		!strings.Contains(notes[0], "DD/MM/YYYY") || np["assumed_date_format"] != "DD/MM/YYYY" || np["alternative_date_format"] != "MM/DD/YYYY" {
		t.Fatalf("notes = %v / %v / %v", notes, codes, np)
	}
	// No recognizable header, then a header without a date column.
	b = startImport(t, s, c, acct, []byte("When,What,How much\n2026-01-02,Lunch,-250.00\n"))
	if b["status"] != "needs_mapping" || !slices.Equal(strList(b["mapping_note_codes"]), []string{"no_header_row"}) ||
		len(strList(b["mapping_notes"])) != 1 || len(paramsOf(b["mapping_note_params"])) != 0 {
		t.Fatalf("no header notes = %v", b)
	}
	b = startImport(t, s, c, acct, []byte("When,Description,Amount\n2026-01-02,Lunch,-250.00\n"))
	if b["status"] != "needs_mapping" || !slices.Equal(strList(b["mapping_note_codes"]), []string{"mapping_incomplete", "check_sign_convention"}) ||
		len(strList(b["mapping_notes"])) != 2 {
		t.Fatalf("incomplete mapping notes = %v", b)
	}
	// A statement in another currency names both currencies as values.
	ofx := strings.ReplaceAll(`OFXHEADER:100
DATA:OFXSGML
VERSION:102

<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><CURDEF>USD
<BANKTRANLIST><DTSTART>20251001<DTEND>20251031
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20251005<TRNAMT>-4.99<FITID>FIT-1<NAME>STREAMING</STMTTRN>
</BANKTRANLIST><LEDGERBAL><BALAMT>95.01<DTASOF>20251031</LEDGERBAL></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>`, "\n", "\r\n")
	fid := uploadFile(t, c, "statement_import", "statement.ofx", "application/x-ofx", []byte(ofx))
	created := c.Do(t, http.MethodPost, "/imports", map[string]any{"account_id": acct, "file_id": fid}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	s.RunJobs(t)
	b = batch(t, c, created["id"].(string))
	if b["status"] != "failed" || b["error_code"] != "currency_mismatch" || paramsOf(b["error_params"])["statement_currency"] != "USD" ||
		paramsOf(b["error_params"])["account_currency"] != "INR" {
		t.Fatalf("currency mismatch = %v", b)
	}
}

// I2, I3 (reconciliation) and I6 (history): reconciliations keep what they
// found, the account follows its latest reconciled statement without a
// version bump, and the history pages.
func TestReconciliationHistoryCountsAndAccountFields(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "reconhistory"))
	other, _ := s.Login(t, s.Register(t, "reconhistoryother"))
	today := time.Now()
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "5000",
		"opening_date": today.AddDate(0, -2, 0).Format(day)})["id"].(string)
	d := func(n int) time.Time { return today.AddDate(0, 0, -n) }
	csv := fmt.Sprintf("Date,Description,Amount\n%s,SALARY,1000.00\n%s,SNACK,-50.00\n%s,BOOK,-200.00\n", d(10).Format(day), d(9).Format(day), d(8).Format(day))
	b := startImport(t, s, c, acct, []byte(csv))
	bid := b["id"].(string)
	snack := rowContaining(t, importRows(t, c, bid, "ready"), "SNACK")
	c.Do(t, http.MethodPatch, "/imports/"+bid+"/rows/"+snack["id"].(string), map[string]any{"decision": "skip"}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/imports/"+bid+"/confirm", map[string]any{"version": batch(t, c, bid)["version"]}, "Idempotency-Key", key()).
		Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	start := c.Do(t, http.MethodGet, "/accounts/"+acct, nil).Expect(t, http.StatusOK).Data()
	reconcile := func(date time.Time, bal string, extra map[string]any) map[string]any {
		body := map[string]any{"statement_date": date.Format(day), "statement_balance": bal}
		for k, v := range extra {
			body[k] = v
		}
		return c.Do(t, http.MethodPost, "/accounts/"+acct+"/reconciliations", body).Expect(t, http.StatusCreated).Data()
	}
	account := func() map[string]any {
		return c.Do(t, http.MethodGet, "/accounts/"+acct, nil).Expect(t, http.StatusOK).Data()
	}

	off := reconcile(today, "1", nil)
	if off["status"] != "unbalanced" || account()["last_reconciled_at"] != nil {
		t.Fatalf("unbalanced = %v; account %v", off, account())
	}
	// Opening balance + salary as of the salary's day.
	older := reconcile(d(9), "6000.00", map[string]any{"import_batch_id": bid})
	if older["status"] != "balanced" || older["reconciled_count"] != float64(2) || older["unmatched_statement_rows"] != float64(1) ||
		older["unreconciled_transactions"] != float64(0) {
		t.Fatalf("balanced at the salary = %v", older)
	}
	if lines, _ := pageOf(t, c, "/accounts/"+acct+"/statement-lines?batch_id="+bid); len(lines) != 1 {
		t.Fatalf("unmatched_statement_rows disagrees with the statement lines: %v", lines)
	}
	a := account()
	if !sameInstant(t, a["last_reconciled_at"].(string), older["created_at"]) || money(a, "last_reconciled_balance") != "6000.00" ||
		a["version"] != start["version"] {
		t.Fatalf("account after reconciling = %v", a)
	}
	latest := reconcile(today, "5800.00", nil)
	if latest["status"] != "balanced" || latest["reconciled_count"] != float64(1) || latest["unmatched_statement_rows"] != float64(0) {
		t.Fatalf("balanced today = %v", latest)
	}
	// Reconciling an older statement again does not move the account back.
	again := reconcile(d(9), "6000.00", nil)
	a = account()
	if again["status"] != "balanced" || again["reconciled_count"] != float64(0) || !sameInstant(t, a["last_reconciled_at"].(string), latest["created_at"]) ||
		money(a, "last_reconciled_balance") != "5800.00" || a["version"] != start["version"] || a["last_import_at"] == nil {
		t.Fatalf("account after an older reconciliation = %v", a)
	}

	// The history keeps the counts; latest statement date first.
	want := []map[string]any{latest, off, again, older}
	hist, meta := pageOf(t, c, "/accounts/"+acct+"/reconciliations")
	if len(hist) != 4 || meta["has_more"] != false {
		t.Fatalf("history = %v", hist)
	}
	for i, h := range hist {
		h := h.(map[string]any)
		w := want[i]
		for _, f := range []string{"id", "status", "reconciled_count", "unmatched_statement_rows", "unreconciled_transactions"} {
			if h[f] != w[f] {
				t.Fatalf("history[%d].%s = %v, want %v (%v)", i, f, h[f], w[f], h)
			}
		}
	}
	if got, pages := walkPages(t, c, "/accounts/"+acct+"/reconciliations?limit=3", "id"); !slices.Equal(got, fieldsOf(hist, "id")) || pages != 2 {
		t.Fatalf("history pages %v (%d), want %v", got, pages, fieldsOf(hist, "id"))
	}
	other.Do(t, http.MethodGet, "/accounts/"+acct+"/reconciliations", nil).Expect(t, http.StatusNotFound)
}

// I5, I6 (matches) and I7 (reason codes, status/source): candidates and
// matches explain themselves with codes and values, match items show the
// records and the match total, and matches page.
func TestReconciliationReasonCodesItemsTotalsAndPages(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "reconcodes"))
	today := time.Now()
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "20000",
		"opening_date": today.AddDate(0, -1, 0).Format(day)})["id"].(string)
	d5, d3 := today.AddDate(0, 0, -5), today.AddDate(0, 0, -3)
	manual := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "499", "description": "Streaming plan", "local_date": d5.Format(day)})
	b := startImport(t, s, c, acct, []byte(fmt.Sprintf("Date,Description,Amount\n%s,STREAMING PLAN,-499.00\n%s,INTEREST CREDIT,1200.00\n",
		d5.Format(day), d3.Format(day))))
	c.Do(t, http.MethodPost, "/imports/"+b["id"].(string)+"/confirm", map[string]any{"version": b["version"]}, "Idempotency-Key", key()).
		Expect(t, http.StatusAccepted)
	s.RunJobs(t)

	cands := c.Do(t, http.MethodGet, "/reconciliation/candidates?account_id="+acct+"&kind=statement_to_ledger", nil).Expect(t, http.StatusOK).List()
	if len(cands) != 1 {
		t.Fatalf("candidates = %v", cands)
	}
	cand := cands[0].(map[string]any)
	left, right := cand["left"].(map[string]any), cand["right"].([]any)[0].(map[string]any)
	if !slices.Equal(strList(cand["reason_codes"]), []string{"same_amount_direction", "same_date", "similar_description"}) ||
		len(strList(cand["reasons"])) != 3 || paramsOf(cand["reason_params"])["days_apart"] != "0" {
		t.Fatalf("candidate reasons = %v", cand)
	}
	if left["record_status"] != "skipped" || left["status"] != "skipped" || left["source"] != nil ||
		right["record_status"] != "posted" || right["source"] != "manual" || right["status"] != "posted/manual" {
		t.Fatalf("candidate items = %v / %v", left, right)
	}
	m1 := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "statement_to_ledger", "account_id": acct,
		"statement_row_ids": []string{left["import_row_id"].(string)}, "transaction_ids": []string{manual["id"].(string)}}).Expect(t, http.StatusCreated).Data()
	items := m1["items"].([]any)
	st, lg := items[0].(map[string]any), items[1].(map[string]any)
	if !slices.Equal(strList(m1["reason_codes"]), []string{"same_amount_direction", "same_date", "similar_description"}) ||
		paramsOf(m1["reason_params"])["days_apart"] != "0" || m1["confidence"] != "0.950" || money(m1, "total") != "499.00" {
		t.Fatalf("match = %v", m1)
	}
	if st["side"] != "statement" || st["date"] != d5.Format(day) || st["description"] != "STREAMING PLAN" || st["record_status"] != "skipped" ||
		st["direction"] != "outflow" || st["effect"] != "row_skipped" || lg["side"] != "ledger" || lg["date"] != d5.Format(day) ||
		lg["description"] != "Streaming plan" || lg["record_status"] != "posted" || lg["source"] != "manual" || lg["effect"] != "none" {
		t.Fatalf("match items = %v", items)
	}

	// A pending hold replaced by a different posted amount.
	pend := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "300", "status": "pending", "description": "Hotel hold"})
	post := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "310", "description": "Hotel"})
	m2 := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "pending_to_posted", "account_id": acct,
		"transaction_ids": []string{post["id"].(string), pend["id"].(string)}}).Expect(t, http.StatusCreated).Data()
	p2 := paramsOf(m2["reason_params"])
	if !slices.Equal(strList(m2["reason_codes"]), []string{"pending_replaced_by_posted", "pending_amount_differs"}) || p2["pending_amount"] != "300.00" ||
		p2["posted_amount"] != "310.00" || p2["currency"] != "INR" || p2["days_apart"] != "0" || money(m2, "total") != "310.00" {
		t.Fatalf("pending match = %v", m2)
	}
	for _, x := range m2["items"].([]any) {
		x := x.(map[string]any)
		if (x["transaction_id"] == pend["id"]) != (x["record_status"] == "voided" && x["effect"] == "voided") {
			t.Fatalf("pending match items = %v", m2["items"])
		}
	}

	// The same income typed in by hand: keep the manual one.
	typed := createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "1200", "description": "Interest", "local_date": d3.Format(day)})
	mi := c.Do(t, http.MethodGet, "/reconciliation/candidates?account_id="+acct+"&kind=manual_to_imported", nil).Expect(t, http.StatusOK).List()
	if len(mi) != 1 || mi[0].(map[string]any)["right"].([]any)[0].(map[string]any)["source"] != "import" {
		t.Fatalf("manual/imported candidates = %v", mi)
	}
	imported := mi[0].(map[string]any)["right"].([]any)[0].(map[string]any)["transaction_id"].(string)
	m3 := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "manual_to_imported", "account_id": acct,
		"transaction_ids": []string{typed["id"].(string), imported}, "keep_transaction_id": typed["id"]}).Expect(t, http.StatusCreated).Data()
	if !slices.Equal(strList(m3["reason_codes"]), []string{"entered_manually_and_imported"}) || money(m3, "total") != "1200.00" {
		t.Fatalf("manual/imported match = %v", m3)
	}

	// Matches page, newest first; the default page is unchanged.
	want := []string{m3["id"].(string), m2["id"].(string), m1["id"].(string)}
	all, meta := pageOf(t, c, "/reconciliation/matches?account_id="+acct)
	if !slices.Equal(fieldsOf(all, "id"), want) || meta["has_more"] != false {
		t.Fatalf("matches = %v, want %v", fieldsOf(all, "id"), want)
	}
	if got, pages := walkPages(t, c, "/reconciliation/matches?account_id="+acct+"&limit=2", "id"); !slices.Equal(got, want) || pages != 2 {
		t.Fatalf("match pages %v (%d), want %v", got, pages, want)
	}
	listed := all[2].(map[string]any)
	if money(listed, "total") != "499.00" || listed["items"].([]any)[0].(map[string]any)["description"] != "STREAMING PLAN" {
		t.Fatalf("listed match = %v", listed)
	}
	// Undo shows the restored records.
	u := c.Do(t, http.MethodDelete, "/reconciliation/matches/"+m3["id"].(string), nil).Expect(t, http.StatusOK).Data()
	for _, x := range u["items"].([]any) {
		if x := x.(map[string]any); x["active"] != false || x["record_status"] != "posted" {
			t.Fatalf("unmatched items = %v", u["items"])
		}
	}
}

// I10: a statement line without a suggestion can be listed and matched by
// hand (owner only, audited); undoing a match restores the line exactly.
func TestStatementLinesManualMatchAndExactUndo(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "manualmatch"))
	other, _ := s.Login(t, s.Register(t, "manualmatchother"))
	today := time.Now()
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000",
		"opening_date": today.AddDate(0, -2, 0).Format(day)})["id"].(string)
	d := func(n int) time.Time { return today.AddDate(0, 0, -n) }
	rent := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "15000", "description": "Rent", "local_date": d(20).Format(day)})
	grocer := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "800", "description": "Grocer", "local_date": d(4).Format(day)})
	b := startImport(t, s, c, acct, []byte(fmt.Sprintf("Date,Description,Amount\n%s,NEFT LANDLORD,-15000.00\n%s,COFFEE,-150.00\n%s,GROCER,-800.00\n",
		d(8).Format(day), d(6).Format(day), d(4).Format(day))))
	bid := b["id"].(string)
	landlord := rowContaining(t, importRows(t, c, bid, "ready"), "LANDLORD")
	c.Do(t, http.MethodPatch, "/imports/"+bid+"/rows/"+landlord["id"].(string), map[string]any{"decision": "skip"}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/imports/"+bid+"/confirm", map[string]any{"version": batch(t, c, bid)["version"]}, "Idempotency-Key", key()).
		Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	dupRow := rowContaining(t, importRows(t, c, bid, "skipped"), "GROCER")
	if dupRow["error_code"] != "possible_duplicate" || len(strList(dupRow["duplicate_reason_codes"])) == 0 {
		t.Fatalf("grocer row = %v", dupRow)
	}

	// The unmatched lines: the skipped rent and the skipped possible
	// duplicate (the coffee was imported), oldest first, a page at a time.
	lines := "/accounts/" + acct + "/statement-lines"
	unmatched, meta := pageOf(t, c, lines)
	if !slices.Equal(fieldsOf(unmatched, "import_row_id"), []string{landlord["id"].(string), dupRow["id"].(string)}) || meta["has_more"] != false {
		t.Fatalf("unmatched lines = %v", unmatched)
	}
	l0 := unmatched[0].(map[string]any)
	if l0["batch_id"] != bid || l0["date"] != d(8).Format(day) || money(l0, "amount") != "15000.00" || l0["direction"] != "outflow" ||
		l0["record_status"] != "skipped" || l0["match_id"] != nil {
		t.Fatalf("line = %v", l0)
	}
	if got, pages := walkPages(t, c, lines+"?status=unmatched&limit=1", "import_row_id"); !slices.Equal(got, fieldsOf(unmatched, "import_row_id")) || pages != 2 {
		t.Fatalf("line pages %v (%d)", got, pages)
	}
	if l, _ := pageOf(t, c, lines+"?batch_id="+bid); len(l) != 2 {
		t.Fatalf("lines of the import = %v", l)
	}
	c.Do(t, http.MethodGet, lines+"?batch_id=nope", nil).Expect(t, http.StatusUnprocessableEntity)
	c.Do(t, http.MethodGet, lines+"?batch_id="+uuid.NewString(), nil).Expect(t, http.StatusUnprocessableEntity)
	// No suggestion for the rent line (twelve days from the ledger record).
	for _, x := range c.Do(t, http.MethodGet, "/reconciliation/candidates?account_id="+acct+"&kind=statement_to_ledger", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["left"].(map[string]any)["import_row_id"] == landlord["id"] {
			t.Fatalf("unexpected suggestion for the rent line: %v", x)
		}
	}
	// Owner only.
	other.Do(t, http.MethodGet, lines, nil).Expect(t, http.StatusNotFound)
	manualBody := map[string]any{"kind": "statement_to_ledger", "account_id": acct, "statement_row_ids": []string{landlord["id"].(string)},
		"transaction_ids": []string{rent["id"].(string)}}
	other.Do(t, http.MethodPost, "/reconciliation/matches", manualBody).Expect(t, http.StatusNotFound)
	r := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "statement_to_ledger", "account_id": acct,
		"statement_row_ids": []string{landlord["id"].(string), landlord["id"].(string)}, "transaction_ids": []string{rent["id"].(string)}}).
		Expect(t, http.StatusUnprocessableEntity)
	if d := detail(t, r); d["field"] != "body.statement_row_ids" {
		t.Fatalf("a line sent twice: %v", d)
	}

	// Matched by hand: explained, without a matcher score, and audited.
	m := c.Do(t, http.MethodPost, "/reconciliation/matches", manualBody).Expect(t, http.StatusCreated).Data()
	if !slices.Equal(strList(m["reason_codes"]), []string{"same_amount_direction", "dates_far_apart"}) || paramsOf(m["reason_params"])["days_apart"] != "12" ||
		m["confidence"] != nil || money(m, "total") != "15000.00" || m["status"] != "confirmed" {
		t.Fatalf("manual match = %v", m)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'reconciliation_match' and entity_id = $1 and action = 'confirmed'
		and actor_user_id is not null and changes->'statement_row_ids' ? $2`, uuid.MustParse(m["id"].(string)), landlord["id"]); n != 1 {
		t.Fatalf("manual match audit events = %d", n)
	}
	if c.Do(t, http.MethodGet, "/transactions/"+rent["id"].(string), nil).Data()["reconciliation_state"] != "matched" {
		t.Fatal("rent not matched")
	}
	if l, _ := pageOf(t, c, lines); !slices.Equal(fieldsOf(l, "import_row_id"), []string{dupRow["id"].(string)}) {
		t.Fatalf("unmatched after the manual match = %v", l)
	}
	matched, _ := pageOf(t, c, lines+"?status=matched")
	if len(matched) != 1 || matched[0].(map[string]any)["match_id"] != m["id"] || matched[0].(map[string]any)["error_code"] != "reconciled" {
		t.Fatalf("matched lines = %v", matched)
	}
	other.Do(t, http.MethodDelete, "/reconciliation/matches/"+m["id"].(string), nil).Expect(t, http.StatusNotFound)

	// Undo restores each line as it was: reason, explanation and decision.
	g := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "statement_to_ledger", "account_id": acct,
		"statement_row_ids": []string{dupRow["id"].(string)}, "transaction_ids": []string{grocer["id"].(string)}}).Expect(t, http.StatusCreated).Data()
	c.Do(t, http.MethodDelete, "/reconciliation/matches/"+g["id"].(string), nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodDelete, "/reconciliation/matches/"+m["id"].(string), nil).Expect(t, http.StatusOK)
	skipped := importRows(t, c, bid, "skipped")
	back, rentBack := rowContaining(t, skipped, "GROCER"), rowContaining(t, skipped, "LANDLORD")
	if back["error_code"] != "possible_duplicate" || back["error_message"] != dupRow["error_message"] ||
		!slices.Equal(strList(back["duplicate_reason_codes"]), strList(dupRow["duplicate_reason_codes"])) ||
		paramsOf(back["error_params"])["days_apart"] != paramsOf(dupRow["error_params"])["days_apart"] ||
		back["duplicate_of_transaction_id"] != grocer["id"] || back["user_decision"] != nil {
		t.Fatalf("undone duplicate line = %v (was %v)", back, dupRow)
	}
	if rentBack["user_decision"] != "skip" || rentBack["error_code"] != nil {
		t.Fatalf("undone rent line = %v", rentBack)
	}
	if l, _ := pageOf(t, c, lines); len(l) != 2 {
		t.Fatalf("unmatched after undo = %v", l)
	}
}

// The contract publishes the new shapes and the required key.
func TestImportsReconciliationContractShapes(t *testing.T) {
	s := apitest.New(t, map[string]string{"HTTP_ENABLE_DOCS": "true"})
	c, _ := s.Login(t, s.Register(t, "importsdoc"))
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
	matchReasons := "[same_amount_direction same_date one_day_apart within_3_days within_a_week same_reference similar_description amounts_add_up " +
		"all_within_a_week dates_far_apart pending_replaced_by_posted pending_amount_differs entered_manually_and_imported]"
	for _, x := range []struct{ schema, field, want string }{
		{"ImportBatchDTO", "mapping_note_codes", "[no_header_row ambiguous_date_order unknown_date_format decimal_comma mapping_incomplete check_sign_convention pdf_read_by_ai]"},
		{"ImportRowDTO", "error_field", "[posted_date amount category_id description]"},
		{"ImportRowDTO", "duplicate_reason_codes", "[same_amount_direction same_date one_day_apart within_3_days within_a_week same_reference similar_description]"},
		{"ReconCandidate", "reason_codes", "[same_amount_direction same_date one_day_apart within_3_days within_a_week same_reference similar_description amounts_add_up all_within_a_week]"},
		{"ReconMatchDTO", "reason_codes", matchReasons},
		{"ReconCandidateItem", "source", "[manual import receipt recurring integration correction group system]"},
		{"StatementLineDTO", "record_status", "[duplicate skipped ready failed]"},
	} {
		if got := enum(x.schema, x.field); got != x.want {
			t.Errorf("%s.%s enum = %s, want %s", x.schema, x.field, got, x.want)
		}
	}
	for _, x := range []struct{ schema, field string }{{"ImportBatchDTO", "to_import_rows"}, {"ImportBatchDTO", "mapping_note_params"},
		{"ReconMatchItemDTO", "date"}, {"ReconMatchItemDTO", "description"}, {"ReconMatchItemDTO", "record_status"}, {"ReconMatchDTO", "reason_params"}} {
		prop(x.schema, x.field)
	}
	if !strings.HasSuffix(fmt.Sprint(prop("RowTotals", "inflow")["$ref"]), "/Money") || prop("RowTotals", "inflow_minor")["deprecated"] != true ||
		prop("ReconCandidateItem", "status")["deprecated"] != true {
		t.Errorf("RowTotals.inflow = %v, inflow_minor = %v, candidate status = %v", prop("RowTotals", "inflow"), prop("RowTotals", "inflow_minor"),
			prop("ReconCandidateItem", "status"))
	}
	paths := doc["paths"].(map[string]any)
	param := func(path, method, in, name string) map[string]any {
		t.Helper()
		op, ok := paths[path].(map[string]any)[method].(map[string]any)
		if !ok {
			t.Fatalf("%s %s missing", method, path)
		}
		for _, p := range op["parameters"].([]any) {
			if p := p.(map[string]any); p["in"] == in && p["name"] == name {
				return p
			}
		}
		t.Fatalf("%s %s has no %s parameter %s", method, path, in, name)
		return nil
	}
	if p := param("/imports", "post", "header", "Idempotency-Key"); p["required"] != true {
		t.Errorf("imports-create Idempotency-Key = %v", p)
	}
	for _, path := range []string{"/imports", "/reconciliation/matches", "/accounts/{id}/reconciliations", "/accounts/{id}/statement-lines"} {
		param(path, "get", "query", "cursor")
		param(path, "get", "query", "limit")
	}
	if p := param("/accounts/{id}/statement-lines", "get", "query", "status"); fmt.Sprint(p["schema"].(map[string]any)["enum"]) != "[unmatched matched]" {
		t.Errorf("statement-lines status = %v", p)
	}
}

// A row found to be imported already while processing (the same file
// confirmed twice) becomes an already_imported duplicate linked to the
// existing transaction, and stops being importable even when the user had
// chosen to import it (it was picked up again and again before).
func TestImportRowAlreadyImportedWhileProcessing(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "importtwice"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	csv := []byte("Date,Description,Amount\n" + time.Now().AddDate(0, 0, -2).Format(day) + ",Groceries,-120.00\n")
	b1, b2 := startImport(t, s, c, acct, csv), startImport(t, s, c, acct, csv) // both previewed before either imports
	b2id := b2["id"].(string)
	row := importRows(t, c, b2id, "ready")[0]
	c.Do(t, http.MethodPatch, "/imports/"+b2id+"/rows/"+row["id"].(string), map[string]any{"decision": "import"}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/imports/"+b1["id"].(string)+"/confirm", map[string]any{"version": b1["version"]}, "Idempotency-Key", key()).
		Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	c.Do(t, http.MethodPost, "/imports/"+b2id+"/confirm", map[string]any{"version": batch(t, c, b2id)["version"]}, "Idempotency-Key", key()).
		Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	first := importRows(t, c, b1["id"].(string), "imported")
	dup := importRows(t, c, b2id, "duplicate")
	if len(first) != 1 || len(dup) != 1 || dup[0]["error_code"] != "already_imported" || paramsOf(dup[0]["error_params"])["matched_by"] != "fingerprint" ||
		dup[0]["duplicate_of_transaction_id"] != first[0]["transaction_id"] || dup[0]["user_decision"] != nil {
		t.Fatalf("second import of the row = %v (first %v)", dup, first)
	}
	if b := batch(t, c, b2id); b["status"] != "completed" || b["imported_count"] != float64(0) || b["to_import_rows"] != float64(0) {
		t.Fatalf("second batch = %v", b)
	}
	if bal := balance(t, c, acct); bal != "880.00" {
		t.Fatalf("balance = %s (the row was imported twice?)", bal)
	}
}
