package api_test

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/receipts"
	"montra/backend/internal/testutil/apitest"
)

// uploadFile runs the upload-intent → content → complete flow.
func uploadFile(t *testing.T, c *apitest.Client, purpose, name, ctype string, body []byte) string {
	t.Helper()
	sum := sha256.Sum256(body)
	intent := c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": purpose, "filename": name, "content_type": ctype,
		"size_bytes": len(body), "checksum_sha256": hex.EncodeToString(sum[:])}).Expect(t, http.StatusCreated).Data()
	putContent(t, c, intent, body).Expect(t, http.StatusOK)
	id := intent["file"].(map[string]any)["id"].(string)
	c.Do(t, http.MethodPost, "/files/"+id+"/complete", nil).Expect(t, http.StatusOK)
	return id
}

func ddmmyyyy(t time.Time) string { return t.Format("02/01/2006") }

func batch(t *testing.T, c *apitest.Client, id string) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodGet, "/imports/"+id, nil).Expect(t, http.StatusOK).Data()
}

func importRows(t *testing.T, c *apitest.Client, id, status string) []map[string]any {
	t.Helper()
	var out []map[string]any
	for _, r := range c.Do(t, http.MethodGet, "/imports/"+id+"/rows?status="+status, nil).Expect(t, http.StatusOK).Data()["rows"].([]any) {
		out = append(out, r.(map[string]any))
	}
	return out
}

func startImport(t *testing.T, s *apitest.Server, c *apitest.Client, acct string, csv []byte) map[string]any {
	t.Helper()
	fid := uploadFile(t, c, "statement_import", "statement.csv", "text/csv", csv)
	b := c.Do(t, http.MethodPost, "/imports", map[string]any{"account_id": acct, "file_id": fid}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	s.RunJobs(t)
	return batch(t, c, b["id"].(string))
}

func TestStatementImportDuplicatesIdempotencyAndReimport(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "importer"))
	today := time.Now()
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000",
		"opening_date": today.AddDate(0, -2, 0).Format(day)})["id"].(string)
	d := func(n int) time.Time { return today.AddDate(0, 0, -n) }
	// A purchase already entered by hand (the statement has it too).
	manual := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1250.50", "description": "Grocer weekly shop",
		"local_date": d(10).Format(day)})
	csv := strings.Join([]string{
		"Statement for account XXXX1234,,,,",
		"Txn Date,Narration,Ref No,Withdrawal Amt,Deposit Amt,Closing Balance",
		ddmmyyyy(d(10)) + ",UPI-GROCER-WEEKLY SHOP,UPI001,\"1,250.50\",,\"48,749.50\"",
		ddmmyyyy(d(9)) + ",SALARY ACME LTD,NEFT77,,\"60,000.00\",\"1,08,749.50\"",
		ddmmyyyy(d(8)) + ",COFFEE HOUSE,,120.00,,\"1,08,629.50\"",
		ddmmyyyy(d(8)) + ",COFFEE HOUSE,,120.00,,\"1,08,509.50\"",
		ddmmyyyy(d(5)) + ",BOOKSTORE,,abc,,\"1,08,509.50\"",
		ddmmyyyy(d(2)) + ",ELECTRICITY BILL,BBPS9,\"2,000.00\",,\"1,06,509.50\"",
		",Closing balance,,,,\"1,06,509.50\"",
	}, "\n") + "\n"
	b := startImport(t, s, c, acct, []byte(csv))
	bid := b["id"].(string)
	if b["status"] != "preview_ready" || b["mapping"].(map[string]any)["date_format"] != "DD/MM/YYYY" || b["source_format"] != "csv" {
		t.Fatalf("batch = %v", b)
	}
	if b["total_rows"] != float64(7) || b["invalid_rows"] != float64(2) || b["duplicate_rows"] != float64(1) || b["valid_rows"] != float64(5) {
		t.Fatalf("counts = total %v invalid %v dup %v valid %v", b["total_rows"], b["invalid_rows"], b["duplicate_rows"], b["valid_rows"])
	}
	if b["totals"].(map[string]any)["balance_check"] != "ok" {
		t.Fatalf("totals = %v", b["totals"])
	}
	dups := importRows(t, c, bid, "duplicate")
	if len(dups) != 1 || dups[0]["duplicate_of_transaction_id"] != manual["id"] || dups[0]["error_code"] != "possible_duplicate" {
		t.Fatalf("duplicates = %v", dups)
	}
	invalid := importRows(t, c, bid, "invalid")
	if len(invalid) != 2 || invalid[0]["error_code"] != "bad_amount" || invalid[1]["error_code"] != "missing_date" || invalid[0]["row_number"] != float64(7) {
		t.Fatalf("invalid rows (never silently dropped) = %v", invalid)
	}
	// Skip the electricity row for now.
	var elec string
	for _, r := range importRows(t, c, bid, "ready") {
		if strings.Contains(r["description"].(string), "ELECTRICITY") {
			elec = r["id"].(string)
		}
	}
	c.Do(t, http.MethodPatch, "/imports/"+bid+"/rows/"+elec, map[string]any{"decision": "skip"}).Expect(t, http.StatusOK)
	b = batch(t, c, bid)
	k := key()
	conf := c.Do(t, http.MethodPost, "/imports/"+bid+"/confirm", map[string]any{"version": b["version"]}, "Idempotency-Key", k).Expect(t, http.StatusAccepted)
	again := c.Do(t, http.MethodPost, "/imports/"+bid+"/confirm", map[string]any{"version": b["version"]}, "Idempotency-Key", k).Expect(t, http.StatusAccepted)
	if conf.Data()["status"] != "confirmed" || again.Headers.Get("Idempotent-Replayed") != "true" {
		t.Fatalf("confirm %s / replay %s", conf.Raw, again.Raw)
	}
	s.RunJobs(t)
	b = batch(t, c, bid)
	if b["status"] != "completed" || b["imported_count"] != float64(3) {
		t.Fatalf("after processing = %v (imported %v)", b["status"], b["imported_count"])
	}
	// Salary + two identical coffees (distinct fingerprints) were imported;
	// the possible duplicate and the skipped row were not.
	if bal := balance(t, c, acct); bal != "108509.50" {
		t.Fatalf("balance = %s", bal)
	}
	if n := workerCount(t, s, `select count(*) from transactions where account_id = $1 and source = 'import'`, uuid.MustParse(acct)); n != 3 {
		t.Fatalf("imported transactions = %d", n)
	}
	if n := notificationsOf(t, c, "import", "import_completed"); n != 1 {
		t.Fatalf("completion notices = %d", n)
	}
	// Re-importing the same file: imported rows are exact duplicates and
	// cannot be forced; only the previously skipped row remains.
	b2 := startImport(t, s, c, acct, []byte(csv))
	b2id := b2["id"].(string)
	if b2["previous_import_of_file"] != bid || b2["status"] != "preview_ready" {
		t.Fatalf("re-import = %v", b2)
	}
	var already string
	for _, r := range importRows(t, c, b2id, "duplicate") {
		if r["error_code"] == "already_imported" {
			already = r["id"].(string)
		}
	}
	if already == "" {
		t.Fatal("re-import did not flag already imported rows")
	}
	if r := c.Do(t, http.MethodPatch, "/imports/"+b2id+"/rows/"+already, map[string]any{"decision": "import"}); r.ErrorCode() != "DUPLICATE" {
		t.Fatalf("forced re-import accepted: %s", r.Raw)
	}
	if ready := importRows(t, c, b2id, "ready"); len(ready) != 1 || !strings.Contains(ready[0]["description"].(string), "ELECTRICITY") {
		t.Fatalf("re-import ready rows = %v", ready)
	}
	c.Do(t, http.MethodPost, "/imports/"+b2id+"/confirm", map[string]any{"version": b2["version"]}, "Idempotency-Key", key()).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	if bal := balance(t, c, acct); bal != "106509.50" {
		t.Fatalf("balance after re-import = %s", bal)
	}
	other, _ := s.Login(t, s.Register(t, "importsnoop"))
	other.Do(t, http.MethodGet, "/imports/"+bid, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodGet, "/imports/"+bid+"/rows", nil).Expect(t, http.StatusNotFound)
}

func TestImportMappingRetryRollbackCancelAndUnsupported(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "mapper"))
	today := time.Now()
	acct := createAccount(t, c, map[string]any{"name": "Card", "account_type": "bank", "currency": "INR", "opening_balance": "10000",
		"opening_date": today.AddDate(0, -1, 0).Format(day)})["id"].(string)
	csv := fmt.Sprintf("When,What,How much\n%s,Lunch,-250.00\n%s,Refund,80.00\n%s,Taxi,-150.00\n%s,Future,-99.00\n",
		today.AddDate(0, 0, -3).Format(day), today.AddDate(0, 0, -2).Format(day), today.AddDate(0, 0, -1).Format(day), today.AddDate(2, 0, 0).Format(day))
	b := startImport(t, s, c, acct, []byte(csv))
	bid := b["id"].(string)
	if b["status"] != "needs_mapping" || len(b["mapping_notes"].([]any)) == 0 {
		t.Fatalf("unrecognized headers should need mapping: %v", b)
	}
	m := map[string]any{"header_row": 0, "date_column": 0, "date_format": "YYYY-MM-DD", "amount_column": 2, "sign_convention": "negative_is_outflow",
		"description_columns": []int{1}}
	if r := c.Do(t, http.MethodPatch, "/imports/"+bid+"/mapping", map[string]any{"mapping": map[string]any{"header_row": 0, "date_column": 9,
		"date_format": "YYYY-MM-DD", "amount_column": 2, "sign_convention": "negative_is_outflow"}, "version": b["version"]}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("out-of-range column accepted: %s", r.Raw)
	}
	c.Do(t, http.MethodPatch, "/imports/"+bid+"/mapping", map[string]any{"mapping": m, "version": b["version"]}).Expect(t, http.StatusOK)
	s.RunJobs(t)
	b = batch(t, c, bid)
	if b["status"] != "preview_ready" || b["valid_rows"] != float64(4) {
		t.Fatalf("after mapping = %v valid %v", b["status"], b["valid_rows"])
	}
	c.Do(t, http.MethodPost, "/imports/"+bid+"/confirm", map[string]any{"version": b["version"]}, "Idempotency-Key", key()).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	b = batch(t, c, bid)
	failed := importRows(t, c, bid, "failed")
	if b["status"] != "completed_with_errors" || b["imported_count"] != float64(3) || len(failed) != 1 {
		t.Fatalf("partial failure = %v imported %v failed %v", b["status"], b["imported_count"], failed)
	}
	// Correct the failed row, then retry: no duplicates of the imported rows.
	c.Do(t, http.MethodPatch, "/imports/"+bid+"/rows/"+failed[0]["id"].(string), map[string]any{"posted_date": today.Format(day)}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/imports/"+bid+"/retry-failed", nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	b = batch(t, c, bid)
	if b["status"] != "completed" || b["imported_count"] != float64(4) {
		t.Fatalf("after retry = %v imported %v", b["status"], b["imported_count"])
	}
	if bal := balance(t, c, acct); bal != "9581.00" {
		t.Fatalf("balance = %s", bal)
	}
	// Edit one imported transaction; rollback keeps it and voids the rest.
	var lunch map[string]any
	for _, r := range importRows(t, c, bid, "imported") {
		if r["description"] == "Lunch" {
			lunch = c.Do(t, http.MethodGet, "/transactions/"+r["transaction_id"].(string), nil).Expect(t, http.StatusOK).Data()
		}
	}
	c.Do(t, http.MethodPatch, "/transactions/"+lunch["id"].(string), map[string]any{"description": "Team lunch", "version": lunch["version"]},
		"Idempotency-Key", key()).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/imports/"+bid+"/rollback", nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	b = batch(t, c, bid)
	if b["status"] != "cancelled" || !strings.Contains(fmt.Sprint(b["error_message"]), "kept 1") {
		t.Fatalf("rollback = %v %v", b["status"], b["error_message"])
	}
	if bal := balance(t, c, acct); bal != "9750.00" {
		t.Fatalf("balance after rollback = %s", bal)
	}
	// Cancel before confirmation.
	b2 := startImport(t, s, c, acct, []byte("Date,Description,Amount\n"+today.Format(day)+",Snack,-10\n"))
	c.Do(t, http.MethodPost, "/imports/"+b2["id"].(string)+"/cancel", nil).Expect(t, http.StatusOK)
	if r := c.Do(t, http.MethodPost, "/imports/"+b2["id"].(string)+"/confirm", map[string]any{"version": batch(t, c, b2["id"].(string))["version"]},
		"Idempotency-Key", key()); r.ErrorCode() != "CONFLICT" {
		t.Fatalf("confirm after cancel: %s", r.Raw)
	}
	// PDF statements are not parsed (no unreviewed extraction).
	pdf := []byte("%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n" +
		"3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 10 10]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n")
	pid := uploadFile(t, c, "statement_import", "statement.pdf", "application/pdf", pdf)
	pb := c.Do(t, http.MethodPost, "/imports", map[string]any{"account_id": acct, "file_id": pid}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	if pb["status"] != "failed" || pb["error_code"] != "unsupported_format" {
		t.Fatalf("pdf import = %v", pb)
	}
}

// fakeExtractor is a test double for the receipt reading provider.
type fakeExtractor struct{ res receipts.Extracted }

func (f fakeExtractor) Info() (string, string, string, string) {
	return "ai_vision", "test", "fake-model", "fake-1"
}
func (f fakeExtractor) Configured() bool { return true }
func (f fakeExtractor) Extract(_ context.Context, pages []receipts.Page) (*receipts.Extracted, error) {
	if len(pages) == 0 || len(pages[0].Data) == 0 {
		return nil, fmt.Errorf("no pages")
	}
	r := f.res
	return &r, nil
}

func TestReceiptsExtractionReviewMatchAndCreate(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "receipter"))
	acct := createAccount(t, c, map[string]any{"name": "Card", "account_type": "bank", "currency": "INR", "opening_balance": "10000"})["id"].(string)
	img := pngBytes(t)
	f1 := uploadFile(t, c, "receipt", "r1.png", "image/png", img)
	// No extractor configured: manual entry.
	r1 := c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{f1}}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if r1["status"] != "needs_review" {
		t.Fatalf("manual receipt = %v", r1["status"])
	}
	if r := c.Do(t, http.MethodPost, "/receipts/"+r1["id"].(string)+"/process", nil); r.ErrorCode() != "FEATURE_NOT_CONFIGURED" {
		t.Fatalf("process without extractor: %s", r.Raw)
	}
	today := time.Now().Format(day)
	fake := fakeExtractor{res: receipts.Extracted{MerchantName: "Cafe Blue", Date: today, Time: "13:05", Currency: "INR", Subtotal: "400.00",
		Tax: "20.00", Tip: "30.00", Total: "450.00", PaymentHint: "card 4111111111111111", ReceiptNumber: "INV-77",
		LineItems:       []receipts.ExtractedLine{{Description: "Latte", Quantity: "2", UnitPrice: "150.00", Amount: "300.00", Confidence: 0.9}, {Description: "Cake", Quantity: "1", UnitPrice: "100.00", Amount: "100.00", Confidence: 0.6}},
		FieldConfidence: map[string]float64{"total": 0.95, "merchant_name": 0.7}, Overall: 0.82}}
	s.Svcs.Receipts.Extractor, s.WorkerSvcs.Receipts.Extractor = fake, fake
	// An outside reader needs AI on plus both AI consents (receipts never
	// leave Montra otherwise).
	grantAI(t, c, true)
	img2 := append(append([]byte{}, img...), 0) // different bytes (trailing byte after IEND is tolerated)
	f2 := uploadFile(t, c, "receipt", "r2.png", "image/png", img2)
	r2 := c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{f2}, "read_automatically": true}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	rid := r2["id"].(string)
	if r2["status"] != "processing" {
		t.Fatalf("receipt with extractor = %v", r2["status"])
	}
	s.RunJobs(t)
	got := c.Do(t, http.MethodGet, "/receipts/"+rid, nil).Expect(t, http.StatusOK).Data()
	cur := got["current"].(map[string]any)
	if got["status"] != "needs_review" || cur["method"] != "ai_vision" || cur["provider"] != "test" || money(cur, "total") != "450.00" ||
		cur["payment_hint"] != "card •••• 1111" || len(cur["line_items"].([]any)) != 2 || cur["field_confidence"].(map[string]any)["total"] != 0.95 {
		t.Fatalf("extraction = %v", cur)
	}
	if n := notificationsOf(t, c, "receipt", "receipt_ready"); n != 1 {
		t.Fatalf("receipt notices = %d", n)
	}
	// Values must be reviewed before a transaction is recorded.
	if r := c.Do(t, http.MethodPost, "/receipts/"+rid+"/create-transaction", map[string]any{"account_id": acct}, "Idempotency-Key", key()); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("unreviewed create: %s", r.Raw)
	}
	rev := c.Do(t, http.MethodPatch, "/receipts/"+rid+"/review", map[string]any{"merchant_name": "Cafe Blue", "receipt_date": today, "subtotal": "400",
		"tax": "20", "tip": "40", "total": "460", "line_items": []any{map[string]any{"description": "Latte x2", "amount": "300"},
			map[string]any{"description": "Cake", "amount": "100"}}, "version": got["version"]}).Expect(t, http.StatusOK).Data()
	if rev["status"] != "reviewed" || rev["current"].(map[string]any)["method"] != "manual" || money(rev["current"].(map[string]any), "total") != "460.00" ||
		rev["reviewed_by"] == nil {
		t.Fatalf("review = %v", rev)
	}
	hist := c.Do(t, http.MethodGet, "/receipts/"+rid, nil).Data()["history"].([]any)
	if len(hist) != 2 || hist[1].(map[string]any)["method"] != "ai_vision" {
		t.Fatalf("machine extraction must be preserved: %v", hist)
	}
	// Match an existing transaction, then unlink.
	tx := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "460", "merchant_name": "Cafe Blue"})
	cands := c.Do(t, http.MethodGet, "/receipts/"+rid+"/match-candidates", nil).Expect(t, http.StatusOK).List()
	if len(cands) != 1 || cands[0].(map[string]any)["transaction_id"] != tx["id"] || !strings.Contains(fmt.Sprint(cands[0].(map[string]any)["reasons"]), "Same merchant") ||
		fmt.Sprint(cands[0].(map[string]any)["reason_codes"]) != "[same_amount same_date same_merchant]" {
		t.Fatalf("candidates = %v", cands)
	}
	m := c.Do(t, http.MethodPost, "/receipts/"+rid+"/match-transaction", map[string]any{"transaction_id": tx["id"]}).Expect(t, http.StatusOK).Data()
	linked := c.Do(t, http.MethodGet, "/transactions/"+tx["id"].(string), nil).Data()
	if m["status"] != "matched" || linked["receipt_id"] != rid || linked["attachment_count"] != float64(1) {
		t.Fatalf("match = %v / tx %v", m["status"], linked)
	}
	c.Do(t, http.MethodPost, "/receipts/"+rid+"/unlink", nil).Expect(t, http.StatusOK)
	if l := c.Do(t, http.MethodGet, "/transactions/"+tx["id"].(string), nil).Data(); l["receipt_id"] != nil || l["attachment_count"] != float64(0) {
		t.Fatalf("unlink left links: %v", l)
	}
	// Record a new purchase from the reviewed values (idempotent).
	k := key()
	cr := c.Do(t, http.MethodPost, "/receipts/"+rid+"/create-transaction", map[string]any{"account_id": acct}, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	rep := c.Do(t, http.MethodPost, "/receipts/"+rid+"/create-transaction", map[string]any{"account_id": acct}, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	if rep.Headers.Get("Idempotent-Replayed") != "true" || cr.Data()["transaction_id"] != rep.Data()["transaction_id"] {
		t.Fatalf("create replay: %s / %s", cr.Raw, rep.Raw)
	}
	made := c.Do(t, http.MethodGet, "/transactions/"+cr.Data()["transaction_id"].(string), nil).Data()
	if made["source"] != "receipt" || money(made, "amount") != "460.00" || made["merchant"].(map[string]any)["name"] != "Cafe Blue" {
		t.Fatalf("created = %v", made)
	}
	if bal := balance(t, c, acct); bal != "9080.00" {
		t.Fatalf("balance = %s", bal)
	}
	// Same file content again → duplicate warning (not merged).
	f3 := uploadFile(t, c, "receipt", "again.png", "image/png", img2)
	r3 := c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{f3}, "skip_extraction": true}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	if r3["duplicate_of_id"] != rid {
		t.Fatalf("duplicate = %v", r3["duplicate_of_id"])
	}
	c.Do(t, http.MethodPost, "/receipts/"+r3["id"].(string)+"/discard", nil).Expect(t, http.StatusOK)
	other, _ := s.Login(t, s.Register(t, "receiptsnoop"))
	other.Do(t, http.MethodGet, "/receipts/"+rid, nil).Expect(t, http.StatusNotFound)
	if r := other.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{f1}}, "Idempotency-Key", key()); r.Status != http.StatusUnprocessableEntity ||
		firstDetailField(r) != "body.file_ids" {
		t.Fatalf("someone else's file: %d %s", r.Status, r.Raw)
	}
}

func TestReconciliationMatchesUnmatchAndBalance(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "reconciler"))
	today := time.Now()
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "20000",
		"opening_date": today.AddDate(0, -1, 0).Format(day)})["id"].(string)
	d5 := today.AddDate(0, 0, -5)
	manual := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "499", "description": "Streaming plan", "local_date": d5.Format(day)})
	csv := fmt.Sprintf("Date,Description,Amount\n%s,STREAMING PLAN,-499.00\n%s,INTEREST CREDIT,1200.00\n", d5.Format(day), today.AddDate(0, 0, -3).Format(day))
	b := startImport(t, s, c, acct, []byte(csv))
	bid := b["id"].(string)
	c.Do(t, http.MethodPost, "/imports/"+bid+"/confirm", map[string]any{"version": b["version"]}, "Idempotency-Key", key()).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	cands := c.Do(t, http.MethodGet, "/reconciliation/candidates?account_id="+acct+"&kind=statement_to_ledger", nil).Expect(t, http.StatusOK).List()
	if len(cands) != 1 {
		t.Fatalf("statement candidates = %v", cands)
	}
	cand := cands[0].(map[string]any)
	row := cand["left"].(map[string]any)["import_row_id"].(string)
	if cand["right"].([]any)[0].(map[string]any)["transaction_id"] != manual["id"] || cand["confidence"].(string) < "0.700" {
		t.Fatalf("candidate = %v", cand)
	}
	if r := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "statement_to_ledger", "account_id": acct,
		"statement_row_ids": []string{row}, "transaction_ids": []string{manual["id"].(string), createTx(t, c, map[string]any{"type": "expense",
			"account_id": acct, "amount": "1"})["id"].(string)}}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("unequal sums accepted: %s", r.Raw)
	}
	mt := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "statement_to_ledger", "account_id": acct,
		"statement_row_ids": []string{row}, "transaction_ids": []string{manual["id"].(string)}}).Expect(t, http.StatusCreated).Data()
	if mt["status"] != "confirmed" || c.Do(t, http.MethodGet, "/transactions/"+manual["id"].(string), nil).Data()["reconciliation_state"] != "matched" {
		t.Fatalf("match = %v", mt)
	}
	if r := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "statement_to_ledger", "account_id": acct,
		"statement_row_ids": []string{row}, "transaction_ids": []string{manual["id"].(string)}}); r.Status < 400 {
		t.Fatalf("double match accepted: %s", r.Raw)
	}
	// The same income was also typed in by hand: keep the manual one.
	dupIncome := createTx(t, c, map[string]any{"type": "income", "account_id": acct, "amount": "1200", "description": "Interest",
		"local_date": today.AddDate(0, 0, -3).Format(day)})
	before := balance(t, c, acct)
	mi := c.Do(t, http.MethodGet, "/reconciliation/candidates?account_id="+acct+"&kind=manual_to_imported", nil).Expect(t, http.StatusOK).List()
	if len(mi) != 1 {
		t.Fatalf("manual/imported candidates = %v", mi)
	}
	imported := mi[0].(map[string]any)["right"].([]any)[0].(map[string]any)["transaction_id"].(string)
	m2 := c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "manual_to_imported", "account_id": acct,
		"transaction_ids": []string{dupIncome["id"].(string), imported}, "keep_transaction_id": dupIncome["id"]}).Expect(t, http.StatusCreated).Data()
	if bal := balance(t, c, acct); bal == before || c.Do(t, http.MethodGet, "/transactions/"+imported, nil).Data()["status"] != "voided" {
		t.Fatalf("duplicate not voided: balance %s → %s", before, bal)
	}
	c.Do(t, http.MethodDelete, "/reconciliation/matches/"+m2["id"].(string), nil).Expect(t, http.StatusOK)
	if st := c.Do(t, http.MethodGet, "/transactions/"+imported, nil).Data(); st["status"] != "posted" || st["reconciliation_state"] != "unreconciled" {
		t.Fatalf("unmatch did not restore: %v", st)
	}
	if bal := balance(t, c, acct); bal != before {
		t.Fatalf("balance after unmatch = %s, want %s", bal, before)
	}
	// Pending authorization replaced by the posted charge.
	pend := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "300", "status": "pending", "description": "Hotel hold"})
	post := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "300", "description": "Hotel"})
	c.Do(t, http.MethodPost, "/reconciliation/matches", map[string]any{"kind": "pending_to_posted", "account_id": acct,
		"transaction_ids": []string{post["id"].(string), pend["id"].(string)}}).Expect(t, http.StatusCreated)
	if c.Do(t, http.MethodGet, "/transactions/"+pend["id"].(string), nil).Data()["status"] != "voided" {
		t.Fatal("pending transaction not voided")
	}
	// Balance reconciliation.
	bal := balance(t, c, acct)
	off := c.Do(t, http.MethodPost, "/accounts/"+acct+"/reconciliations", map[string]any{"statement_date": today.Format(day), "statement_balance": "1"}).
		Expect(t, http.StatusCreated).Data()
	if off["status"] != "unbalanced" {
		t.Fatalf("unbalanced = %v", off)
	}
	ok := c.Do(t, http.MethodPost, "/accounts/"+acct+"/reconciliations", map[string]any{"statement_date": today.Format(day), "statement_balance": bal,
		"import_batch_id": bid}).Expect(t, http.StatusCreated).Data()
	if ok["status"] != "balanced" || ok["reconciled_count"].(float64) < 3 || money(ok, "difference") != "0.00" {
		t.Fatalf("balanced = %v", ok)
	}
	if n := len(c.Do(t, http.MethodGet, "/accounts/"+acct+"/reconciliations", nil).List()); n != 2 {
		t.Fatalf("history = %d", n)
	}
	other, _ := s.Login(t, s.Register(t, "reconsnoop"))
	other.Do(t, http.MethodGet, "/reconciliation/candidates?account_id="+acct, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodDelete, "/reconciliation/matches/"+mt["id"].(string), nil).Expect(t, http.StatusNotFound)
}
