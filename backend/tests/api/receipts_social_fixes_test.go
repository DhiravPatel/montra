package api_test

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"

	"montra/backend/internal/receipts"
	"montra/backend/internal/testutil/apitest"
)

// countingReader is a receipt reader test double that counts calls and can
// be told to fail.
type countingReader struct {
	mu    sync.Mutex
	calls int
	fail  bool
	res   receipts.Extracted
}

func (f *countingReader) Info() (string, string, string, string) {
	return "ai_vision", "test", "fake-model", "fake-1"
}
func (f *countingReader) Configured() bool { return true }
func (f *countingReader) Extract(_ context.Context, pages []receipts.Page) (*receipts.Extracted, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	if f.fail || len(pages) == 0 {
		return nil, errors.New("reader failed")
	}
	r := f.res
	return &r, nil
}

func (f *countingReader) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

func (f *countingReader) failing(v bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.fail = v
}

// receiptPage uploads a receipt image with distinct content per n (trailing
// bytes after the PNG end are tolerated), so no duplicate warning appears.
func receiptPage(t *testing.T, c *apitest.Client, n int) string {
	t.Helper()
	return uploadFile(t, c, "receipt", fmt.Sprintf("page%d.png", n), "image/png", append(pngBytes(t), make([]byte, n)...))
}

func newReceipt(t *testing.T, c *apitest.Client, body map[string]any) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodPost, "/receipts", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
}

func getReceipt(t *testing.T, c *apitest.Client, id string) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodGet, "/receipts/"+id, nil).Expect(t, http.StatusOK).Data()
}

// wantConflict asserts a 409 with the top-level and detail codes and returns
// the detail params.
func wantConflict(t *testing.T, r *apitest.Response, code, reason string) map[string]any {
	t.Helper()
	if r.Status != http.StatusConflict || r.ErrorCode() != code || detail(t, r)["code"] != reason {
		t.Fatalf("want 409 %s/%s, got %d %s", code, reason, r.Status, r.Raw)
	}
	p, _ := detail(t, r)["params"].(map[string]any)
	return p
}

// receiptIDs pages through GET /receipts (query starts with &) and returns
// the IDs in order, checking every page's size and paging metadata.
func receiptIDs(t *testing.T, c *apitest.Client, query string, limit int) []string {
	t.Helper()
	var out []string
	cursor := ""
	for page := 0; page < 20; page++ {
		path := "/receipts?limit=" + strconv.Itoa(limit) + query
		if cursor != "" {
			path += "&cursor=" + url.QueryEscape(cursor)
		}
		r := c.Do(t, http.MethodGet, path, nil).Expect(t, http.StatusOK)
		meta := r.Body["meta"].(map[string]any)
		more, _ := meta["has_more"].(bool)
		next, _ := meta["next_cursor"].(string)
		if _, ok := meta["has_more"]; !ok || len(r.List()) > limit || more != (next != "") || (more && len(r.List()) != limit) {
			t.Fatalf("page %d of %s: %d items, meta %v", page, path, len(r.List()), meta)
		}
		out = append(out, ids(r.List(), "id")...)
		if !more {
			return out
		}
		cursor = next
	}
	t.Fatal("too many pages")
	return nil
}

func reversed(in []string) []string {
	out := make([]string, 0, len(in))
	for i := len(in) - 1; i >= 0; i-- {
		out = append(out, in[i])
	}
	return out
}

// R1, R2, R4: the inbox pages newest first, creating a receipt is
// idempotent, and a file is a page of one receipt in the inbox at a time.
func TestReceiptInboxPagesIdempotentCreateAndExclusivePages(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "inbox"))
	var pages []string
	for i := 0; i < 5; i++ {
		pages = append(pages, receiptPage(t, c, i))
	}

	// Creating needs an Idempotency-Key; a retry returns the first receipt.
	body := map[string]any{"file_ids": []string{pages[0]}, "notes": "Lunch"}
	if r := c.Do(t, http.MethodPost, "/receipts", body); r.Status != http.StatusUnprocessableEntity || !strings.Contains(string(r.Raw), "Idempotency-Key") {
		t.Fatalf("create without Idempotency-Key: %d %s", r.Status, r.Raw)
	}
	k := key()
	first := c.Do(t, http.MethodPost, "/receipts", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	again := c.Do(t, http.MethodPost, "/receipts", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	if first.Headers.Get("Idempotent-Replayed") != "" || again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["id"] != first.Data()["id"] ||
		again.Data()["notes"] != "Lunch" {
		t.Fatalf("replay: %s / %s", first.Raw, again.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{pages[1]}}, "Idempotency-Key", k); r.ErrorCode() != "IDEMPOTENCY_CONFLICT" {
		t.Fatalf("key reused for another receipt: %s", r.Raw)
	}
	created := []string{first.Data()["id"].(string)}
	for _, p := range pages[1:] {
		created = append(created, newReceipt(t, c, map[string]any{"file_ids": []string{p}})["id"].(string))
	}

	// Pages: newest first, has_more/next_cursor, filters kept on every page.
	if got := receiptIDs(t, c, "", 2); fmt.Sprint(got) != fmt.Sprint(reversed(created)) {
		t.Fatalf("paged inbox = %v, want %v (newest first; the replay created nothing)", got, reversed(created))
	}
	c.Do(t, http.MethodPost, "/receipts/"+created[3]+"/discard", nil).Expect(t, http.StatusOK)
	inbox := []string{created[4], created[2], created[1], created[0]}
	if got := receiptIDs(t, c, "", 2); fmt.Sprint(got) != fmt.Sprint(inbox) {
		t.Fatalf("inbox without the discarded receipt = %v, want %v", got, inbox)
	}
	if got := receiptIDs(t, c, "&status=needs_review", 3); fmt.Sprint(got) != fmt.Sprint(inbox) {
		t.Fatalf("needs_review pages = %v", got)
	}
	if got := receiptIDs(t, c, "&status=discarded", 1); len(got) != 1 || got[0] != created[3] {
		t.Fatalf("discarded = %v", got)
	}
	whole := c.Do(t, http.MethodGet, "/receipts", nil).Expect(t, http.StatusOK)
	if meta := whole.Body["meta"].(map[string]any); len(whole.List()) != 4 || meta["has_more"] != false || meta["next_cursor"] != nil {
		t.Fatalf("default page (limit 200): %d items, meta %v", len(whole.List()), meta)
	}
	c.Do(t, http.MethodGet, "/receipts?cursor=not-a-cursor", nil).Expect(t, http.StatusUnprocessableEntity)
	c.Do(t, http.MethodGet, "/receipts?limit=201", nil).Expect(t, http.StatusUnprocessableEntity)

	// A file in a receipt cannot start another one.
	p := wantConflict(t, c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{pages[0]}}, "Idempotency-Key", key()), "CONFLICT", "file_in_use")
	if p["file_id"] != pages[0] || p["receipt_id"] != created[0] {
		t.Fatalf("file_in_use params = %v", p)
	}
	// Discarding frees its pages; restoring then names the receipt that took them.
	c.Do(t, http.MethodPost, "/receipts/"+created[0]+"/discard", nil).Expect(t, http.StatusOK)
	newer := newReceipt(t, c, map[string]any{"file_ids": []string{pages[0]}})["id"].(string)
	p = wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+created[0]+"/restore", nil), "CONFLICT", "file_in_use")
	if p["file_id"] != pages[0] || p["receipt_id"] != newer {
		t.Fatalf("restore file_in_use params = %v", p)
	}
	c.Do(t, http.MethodPost, "/receipts/"+newer+"/discard", nil).Expect(t, http.StatusOK)
	if r := c.Do(t, http.MethodPost, "/receipts/"+created[0]+"/restore", nil).Expect(t, http.StatusOK).Data(); r["status"] != "needs_review" {
		t.Fatalf("restored = %v", r["status"])
	}
}

// R3, R5 (processing), R6: receipts are read automatically only when the
// client asks and reading is allowed; restore returns a discarded receipt
// to the state it would have had.
func TestReceiptsReadOnlyWhenAskedAndRestore(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "manualfirst"))
	today := todayIn(t, "Asia/Kolkata").Format(day)

	// With AI off (the default) asking changes nothing: manual review and
	// no failed reading.
	r0 := newReceipt(t, c, map[string]any{"file_ids": []string{receiptPage(t, c, 0)}, "read_automatically": true})
	s.RunJobs(t)
	if g := getReceipt(t, c, r0["id"].(string)); r0["status"] != "needs_review" || g["status"] != "needs_review" || g["current"] != nil ||
		len(g["history"].([]any)) != 0 {
		t.Fatalf("AI off: %v", g)
	}
	reader := &countingReader{res: receipts.Extracted{MerchantName: "Cafe Blue", Date: today, Currency: "INR", Subtotal: "400.00", Total: "400.00",
		Overall: 0.9}}
	s.Svcs.Receipts.Extractor, s.WorkerSvcs.Receipts.Extractor = reader, reader
	// A reader but no AI consent: still manual.
	if r := newReceipt(t, c, map[string]any{"file_ids": []string{receiptPage(t, c, 1)}, "read_automatically": true}); r["status"] != "needs_review" {
		t.Fatalf("without consent = %v", r["status"])
	}
	grantAI(t, c, true)
	// Manual by default, even with AI on and consent given.
	f2 := receiptPage(t, c, 2)
	if r := newReceipt(t, c, map[string]any{"file_ids": []string{f2}}); r["status"] != "needs_review" || r["current"] != nil {
		t.Fatalf("default = %v", r)
	}
	// skip_extraction is deprecated: accepted alone, refused with read_automatically.
	if r := c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{f2}, "read_automatically": true, "skip_extraction": true},
		"Idempotency-Key", key()); r.Status != http.StatusUnprocessableEntity || firstDetailField(r) != "body.skip_extraction" {
		t.Fatalf("contradicting flags: %d %s", r.Status, r.Raw)
	}
	s.RunJobs(t)
	if n := reader.count(); n != 0 {
		t.Fatalf("receipts read without being asked: %d", n)
	}

	// Asked: read in the background; meanwhile other changes answer receipt_processing.
	r3 := newReceipt(t, c, map[string]any{"file_ids": []string{receiptPage(t, c, 3)}, "read_automatically": true})
	id3 := r3["id"].(string)
	if r3["status"] != "processing" {
		t.Fatalf("asked = %v", r3["status"])
	}
	wantConflict(t, c.Do(t, http.MethodPatch, "/receipts/"+id3+"/review", map[string]any{"receipt_date": today, "total": "400", "version": r3["version"]}),
		"CONFLICT", "receipt_processing")
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id3+"/process", nil), "CONFLICT", "receipt_processing")
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id3+"/match-transaction", map[string]any{"transaction_id": uuid.NewString()}),
		"CONFLICT", "receipt_processing")
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id3+"/create-transaction", map[string]any{"account_id": uuid.NewString()}, "Idempotency-Key", key()),
		"CONFLICT", "receipt_processing")
	// Discarding drops the reading; restoring brings the receipt back for review.
	d := c.Do(t, http.MethodPost, "/receipts/"+id3+"/discard", nil).Expect(t, http.StatusOK).Data()
	back := c.Do(t, http.MethodPost, "/receipts/"+id3+"/restore", nil).Expect(t, http.StatusOK).Data()
	if d["status"] != "discarded" || back["status"] != "needs_review" || back["version"].(float64) != d["version"].(float64)+1 {
		t.Fatalf("discard %v → restore %v", d, back)
	}
	s.RunJobs(t)
	if g := getReceipt(t, c, id3); reader.count() != 0 || g["status"] != "needs_review" || g["current"] != nil || len(g["history"].([]any)) != 0 {
		t.Fatalf("a dropped reading changed the receipt (%d reads): %v", reader.count(), g)
	}

	// Reading on request, then a review that discard and restore keep.
	c.Do(t, http.MethodPost, "/receipts/"+id3+"/process", nil).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	read := getReceipt(t, c, id3)
	if reader.count() != 1 || read["status"] != "needs_review" || read["current"].(map[string]any)["method"] != "ai_vision" {
		t.Fatalf("read on request (%d reads): %v", reader.count(), read)
	}
	rev := c.Do(t, http.MethodPatch, "/receipts/"+id3+"/review", map[string]any{"merchant_name": "Cafe Blue", "receipt_date": today, "total": "400",
		"version": read["version"]}).Expect(t, http.StatusOK).Data()
	gone := c.Do(t, http.MethodPost, "/receipts/"+id3+"/discard?version="+fmt.Sprint(rev["version"]), nil).Expect(t, http.StatusOK).Data()
	if r := c.Do(t, http.MethodPost, "/receipts/"+id3+"/restore?version="+fmt.Sprint(rev["version"]), nil); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale restore: %s", r.Raw)
	}
	kept := c.Do(t, http.MethodPost, "/receipts/"+id3+"/restore?version="+fmt.Sprint(gone["version"]), nil).Expect(t, http.StatusOK).Data()
	if kept["status"] != "reviewed" || kept["current"].(map[string]any)["method"] != "manual" || kept["version"].(float64) != gone["version"].(float64)+1 {
		t.Fatalf("restore after review = %v", kept)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'receipt' and entity_id = $1 and action = 'restored'`, id3); n != 2 {
		t.Fatalf("restores audited = %d", n)
	}
	// A failed re-read keeps the reviewed values and status; the failure
	// is kept in the history with its code.
	reader.failing(true)
	c.Do(t, http.MethodPost, "/receipts/"+id3+"/process", nil).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	if g := getReceipt(t, c, id3); g["status"] != "reviewed" || g["current"].(map[string]any)["method"] != "manual" {
		t.Fatalf("after a failed re-read: %v", g)
	}
	if codes := workerString(t, s, `select array_to_string(warning_codes, ',') || '|' || error_code from receipt_extractions
		where receipt_id = $1 and status = 'failed'`, id3); codes != "provider_error|provider_error" {
		t.Fatalf("failed reading codes = %q", codes)
	}
}

// R5, R7, R8: state conflicts carry stable codes, warnings and match
// reasons carry codes next to the English text, and card numbers are
// masked wherever a payment hint is stored.
func TestReceiptConflictCodesWarningCodesAndMaskedHints(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "receiptcodes"))
	acct := createAccount(t, c, map[string]any{"name": "Card", "account_type": "bank", "currency": "INR", "opening_balance": "10000"})["id"].(string)
	today := todayIn(t, "Asia/Kolkata")
	r1 := newReceipt(t, c, map[string]any{"file_ids": []string{receiptPage(t, c, 1)}})
	id1 := r1["id"].(string)

	// Review: coded warnings with values; a spaced card number is never
	// stored or returned.
	rv := c.Do(t, http.MethodPatch, "/receipts/"+id1+"/review", map[string]any{"merchant_name": "Cafe Blue", "receipt_date": today.Format(day),
		"subtotal": "400", "tax": "20", "tip": "40", "total": "450", "payment_hint": "Visa 4111 1111 1111 1111",
		"line_items": []any{map[string]any{"description": "Latte", "amount": "300"}, map[string]any{"description": "Cake", "amount": "50"}},
		"version":    r1["version"]}).Expect(t, http.StatusOK)
	cur := rv.Data()["current"].(map[string]any)
	if cur["payment_hint"] != "Visa •••• 1111" || strings.Contains(string(rv.Raw), "4111 1111") {
		t.Fatalf("payment hint = %v", cur["payment_hint"])
	}
	if fmt.Sprint(cur["warning_codes"]) != "[totals_mismatch line_items_mismatch]" || len(cur["warnings"].([]any)) != 2 ||
		cur["warnings"].([]any)[1] != "Line items add up to 350.00, not the subtotal." ||
		fmt.Sprint(cur["warning_params"]) != "[map[] map[currency:INR line_items_total:350.00 subtotal:400.00]]" {
		t.Fatalf("review warnings = %v / %v / %v", cur["warnings"], cur["warning_codes"], cur["warning_params"])
	}
	if got := getReceipt(t, c, id1)["current"].(map[string]any)["payment_hint"]; got != "Visa •••• 1111" {
		t.Fatalf("payment hint read back = %v", got)
	}
	if n := workerCount(t, s, `select count(*) from receipt_extractions e join receipts r on r.id = e.receipt_id
		where r.user_id = (select user_id from receipts where id = $1) and e.payment_hint ~ '[0-9][ .-]*[0-9][ .-]*[0-9][ .-]*[0-9][ .-]*[0-9]'`, id1); n != 0 {
		t.Fatalf("%d stored payment hints keep five or more digits", n)
	}

	// Match candidates carry reason codes in the order of the reasons.
	exact := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "450", "merchant_name": "Cafe Blue",
		"local_date": today.Format(day)})["id"].(string)
	near := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "500", "description": "Card payment",
		"local_date": today.AddDate(0, 0, -2).Format(day)})["id"].(string)
	want := map[string]string{exact: "[same_amount same_date same_merchant]", near: "[amount_close near_date]"}
	cands := c.Do(t, http.MethodGet, "/receipts/"+id1+"/match-candidates", nil).Expect(t, http.StatusOK).List()
	for _, x := range cands {
		m := x.(map[string]any)
		if fmt.Sprint(m["reason_codes"]) != want[m["transaction_id"].(string)] || len(m["reasons"].([]any)) != len(m["reason_codes"].([]any)) {
			t.Fatalf("candidate %v", m)
		}
	}
	if len(cands) != 2 {
		t.Fatalf("candidates = %v", cands)
	}

	// Linked: every change but unlink answers receipt_linked with the transaction.
	m := c.Do(t, http.MethodPost, "/receipts/"+id1+"/match-transaction", map[string]any{"transaction_id": exact}).Expect(t, http.StatusOK).Data()
	if p := wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/process", nil), "CONFLICT", "receipt_linked"); p["transaction_id"] != exact {
		t.Fatalf("receipt_linked params = %v", p)
	}
	wantConflict(t, c.Do(t, http.MethodPatch, "/receipts/"+id1+"/review", map[string]any{"receipt_date": today.Format(day), "total": "450",
		"version": m["version"]}), "CONFLICT", "receipt_linked")
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/match-transaction", map[string]any{"transaction_id": near}), "CONFLICT", "receipt_linked")
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/create-transaction", map[string]any{"account_id": acct}, "Idempotency-Key", key()),
		"CONFLICT", "receipt_linked")
	id2 := newReceipt(t, c, map[string]any{"file_ids": []string{receiptPage(t, c, 2)}})["id"].(string)
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id2+"/match-transaction", map[string]any{"transaction_id": exact}), "DUPLICATE",
		"transaction_has_receipt")
	// Unlinked: back to reviewed (its values were reviewed).
	if u := c.Do(t, http.MethodPost, "/receipts/"+id1+"/unlink", nil).Expect(t, http.StatusOK).Data(); u["status"] != "reviewed" || u["transaction_id"] != nil {
		t.Fatalf("unlinked = %v", u)
	}
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/unlink", nil), "CONFLICT", "receipt_not_linked")
	if p := wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/restore", nil), "CONFLICT", "receipt_not_discarded"); p["status"] != "reviewed" {
		t.Fatalf("receipt_not_discarded params = %v", p)
	}
	// Discarded: everything but restore answers receipt_discarded.
	gone := c.Do(t, http.MethodPost, "/receipts/"+id1+"/discard", nil).Expect(t, http.StatusOK).Data()
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/discard", nil), "CONFLICT", "receipt_discarded")
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/process", nil), "CONFLICT", "receipt_discarded")
	wantConflict(t, c.Do(t, http.MethodPatch, "/receipts/"+id1+"/review", map[string]any{"receipt_date": today.Format(day), "total": "450",
		"version": gone["version"]}), "CONFLICT", "receipt_discarded")
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/match-transaction", map[string]any{"transaction_id": exact}), "CONFLICT", "receipt_discarded")
	wantConflict(t, c.Do(t, http.MethodPost, "/receipts/"+id1+"/create-transaction", map[string]any{"account_id": acct}, "Idempotency-Key", key()),
		"CONFLICT", "receipt_discarded")
	if r := c.Do(t, http.MethodPost, "/receipts/"+id1+"/restore", nil).Expect(t, http.StatusOK).Data(); r["status"] != "reviewed" {
		t.Fatalf("restored = %v", r["status"])
	}
	// A page whose upload has not finished.
	intent := c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": "receipt", "filename": "late.png", "content_type": "image/png",
		"size_bytes": 100}).Expect(t, http.StatusCreated).Data()
	late := intent["file"].(map[string]any)["id"].(string)
	if p := wantConflict(t, c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{late}}, "Idempotency-Key", key()), "CONFLICT",
		"page_not_ready"); p["file_id"] != late || p["status"] != "pending_upload" {
		t.Fatalf("page_not_ready params = %v", p)
	}

	// Automatic reading: the reader's notes and Montra's checks are coded,
	// and the payment hint is masked as well.
	reader := &countingReader{res: receipts.Extracted{MerchantName: "Corner Shop", Date: "31/12/2026", Currency: "XYZ", Subtotal: "100.00", Tax: "abc",
		Total: "150.00", PaymentHint: "card 4111-1111-1111-1111", Warnings: []string{"Blurry photo", " "}, Overall: 0.5}}
	s.Svcs.Receipts.Extractor, s.WorkerSvcs.Receipts.Extractor = reader, reader
	grantAI(t, c, true)
	id3 := newReceipt(t, c, map[string]any{"file_ids": []string{receiptPage(t, c, 3)}, "read_automatically": true})["id"].(string)
	s.RunJobs(t)
	ex := getReceipt(t, c, id3)["current"].(map[string]any)
	if fmt.Sprint(ex["warning_codes"]) != "[reader_note currency_unrecognized amount_unreadable totals_mismatch date_unreadable]" ||
		len(ex["warnings"].([]any)) != 5 || ex["warnings"].([]any)[0] != "Blurry photo" ||
		fmt.Sprint(ex["warning_params"]) != "[map[] map[] map[value:abc] map[] map[]]" {
		t.Fatalf("reading warnings = %v / %v / %v", ex["warnings"], ex["warning_codes"], ex["warning_params"])
	}
	if ex["payment_hint"] != "card •••• 1111" {
		t.Fatalf("read payment hint = %v", ex["payment_hint"])
	}
}

// S1–S6: exact username search, opt-in discovery, '@' in usernames, coded
// friend-request conflicts, block and mute lists, and the requests tab link.
func TestSocialExactSearchOptInListsAndCodes(t *testing.T) {
	s := apitest.New(t, nil)
	// New accounts are not discoverable until they opt in.
	quiet, _ := s.Login(t, s.Register(t, "quiet"))
	if d := quiet.Do(t, http.MethodGet, "/me", nil).Expect(t, http.StatusOK).Data()["profile"].(map[string]any)["discoverable_by_username"]; d != false {
		t.Fatalf("discoverable by default: %v", d)
	}
	// A leading @ is ignored when setting a username, which is then
	// validated as before.
	handle := "quiet_" + uuid.NewString()[:6]
	if p := quiet.Do(t, http.MethodPatch, "/me", map[string]any{"username": " @" + strings.ToUpper(handle)}).Expect(t, http.StatusOK).Data(); p["username"] != handle {
		t.Fatalf("username = %v", p["username"])
	}
	for _, bad := range []string{"@", "@@" + handle, "@ab", "@montra_team", "@" + strings.Repeat("a", 31)} {
		if r := quiet.Do(t, http.MethodPatch, "/me", map[string]any{"username": bad}); r.Status != http.StatusUnprocessableEntity ||
			firstDetailField(r) != "body.username" {
			t.Fatalf("username %q: %d %s", bad, r.Status, r.Raw)
		}
	}
	long := "q" + strings.Repeat("x", 25) + uuid.NewString()[:4]
	if p := quiet.Do(t, http.MethodPatch, "/me", map[string]any{"username": "@" + long}).Expect(t, http.StatusOK).Data(); p["username"] != long {
		t.Fatalf("30-character username with @ = %v", p["username"])
	}
	quiet.Do(t, http.MethodPatch, "/me", map[string]any{"username": handle}).Expect(t, http.StatusOK)

	seeker := newPerson(t, s, "seeker", nil)
	search := func(p person, q string) []any {
		t.Helper()
		return p.c.Do(t, http.MethodGet, "/users/search?q="+url.QueryEscape(q), nil).Expect(t, http.StatusOK).List()
	}
	if l := search(seeker, handle); len(l) != 0 {
		t.Fatalf("a non-discoverable user was found: %v", l)
	}
	if r := seeker.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"username": handle}); r.Status != http.StatusNotFound {
		t.Fatalf("request to a non-discoverable username: %d", r.Status)
	}
	quiet.Do(t, http.MethodPatch, "/me", map[string]any{"discoverable_by_username": true}).Expect(t, http.StatusOK)
	for q, n := range map[string]int{handle: 1, "@" + strings.ToUpper(handle): 1, handle[:len(handle)-1]: 0, handle + "x": 0, "quiet_": 0} {
		if l := search(seeker, q); len(l) != n {
			t.Fatalf("search %q = %v, want %d result(s)", q, l, n)
		}
	}
	if r := seeker.c.Do(t, http.MethodGet, "/users/search?q=ab", nil); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("2-character search: %d", r.Status)
	}

	// Friend requests: coded conflicts; asking someone who asked you accepts theirs.
	a := newPerson(t, s, "asker", nil)
	b := newPerson(t, s, "pal", nil)
	req := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"username": "@" + b.user}).Expect(t, http.StatusCreated).Data()
	s.RunJobs(t)
	var link any
	for _, x := range b.c.Do(t, http.MethodGet, "/notifications?category=social", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["event_type"] == "friend_request" {
			link = x.(map[string]any)["deep_link"]
		}
	}
	if link != "/friends?tab=requests" {
		t.Fatalf("friend request deep link = %v", link)
	}
	wantConflict(t, a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}), "CONFLICT", "request_pending")
	acc := b.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": a.id}).Expect(t, http.StatusCreated).Data()
	if acc["id"] != req["id"] || acc["status"] != "accepted" {
		t.Fatalf("asking back = %v", acc)
	}
	wantConflict(t, a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}), "CONFLICT", "already_friends")
	wantConflict(t, b.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"username": a.user}), "CONFLICT", "already_friends")

	// Blocks and mutes: your own lists, newest first, with the profiles
	// shown elsewhere (blocked people by name and username only).
	pest := newPerson(t, s, "pest", map[string]any{"bio": "pest bio", "profile_visibility": "public"})
	noisy := newPerson(t, s, "noisy", map[string]any{"bio": "noisy bio", "profile_visibility": "public"})
	a.c.Do(t, http.MethodPost, "/users/"+pest.id+"/block", nil).Expect(t, http.StatusOK)
	a.c.Do(t, http.MethodPost, "/users/"+noisy.id+"/mute", map[string]any{"muted": true}).Expect(t, http.StatusOK)
	a.c.Do(t, http.MethodPost, "/users/"+b.id+"/mute", map[string]any{"muted": true}).Expect(t, http.StatusOK)
	blocks := a.c.Do(t, http.MethodGet, "/blocks", nil).Expect(t, http.StatusOK)
	if l := blocks.List(); len(l) != 1 || blocks.Body["meta"].(map[string]any)["has_more"] != false {
		t.Fatalf("blocks = %s", blocks.Raw)
	}
	bl := blocks.List()[0].(map[string]any)
	if bl["user_id"] != pest.id || bl["display_name"] != "Test pest" || bl["username"] != pest.user || bl["blocked_by_me"] != true ||
		bl["muted"] != false || bl["connection"] != "none" || bl["created_at"] == nil || bl["bio"] != nil || bl["avatar_file_id"] != nil {
		t.Fatalf("blocked person = %v", bl)
	}
	mutes := a.c.Do(t, http.MethodGet, "/mutes?limit=1", nil).Expect(t, http.StatusOK)
	next, _ := mutes.Body["meta"].(map[string]any)["next_cursor"].(string)
	rest := a.c.Do(t, http.MethodGet, "/mutes?limit=1&cursor="+url.QueryEscape(next), nil).Expect(t, http.StatusOK)
	if len(mutes.List()) != 1 || mutes.Body["meta"].(map[string]any)["has_more"] != true || len(rest.List()) != 1 ||
		rest.Body["meta"].(map[string]any)["has_more"] != false {
		t.Fatalf("mute pages: %s / %s", mutes.Raw, rest.Raw)
	}
	pal, other := mutes.List()[0].(map[string]any), rest.List()[0].(map[string]any)
	if pal["user_id"] != b.id || pal["connection"] != "friend" || pal["muted"] != true || pal["blocked_by_me"] != false || pal["created_at"] == nil {
		t.Fatalf("muted friend (newest first) = %v", pal)
	}
	if other["user_id"] != noisy.id || other["display_name"] != "Test noisy" || other["bio"] != "noisy bio" || other["muted"] != true {
		t.Fatalf("muted person = %v", other)
	}
	// The flags show wherever a person's profile is returned to you.
	if f := a.c.Do(t, http.MethodGet, "/connections", nil).Expect(t, http.StatusOK).List(); len(f) != 1 || f[0].(map[string]any)["muted"] != true {
		t.Fatalf("friends = %v", f)
	}
	if l := search(a, noisy.user); len(l) != 1 || l[0].(map[string]any)["muted"] != true || l[0].(map[string]any)["blocked_by_me"] != false {
		t.Fatalf("search result flags = %v", l)
	}
	// Own rows only: the blocked and muted people see nothing of it.
	for _, p := range []person{pest, noisy, b} {
		for _, path := range []string{"/blocks", "/mutes"} {
			if l := p.c.Do(t, http.MethodGet, path, nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
				t.Fatalf("%s sees %s rows: %v", p.user, path, l)
			}
		}
	}
	if r := a.c.Do(t, http.MethodPost, "/users/"+uuid.NewString()+"/mute", map[string]any{"muted": true}); r.Status != http.StatusNotFound {
		t.Fatalf("muting an unknown user: %d %s", r.Status, r.Raw)
	}
	a.c.Do(t, http.MethodDelete, "/users/"+pest.id+"/block", nil).Expect(t, http.StatusOK)
	a.c.Do(t, http.MethodPost, "/users/"+noisy.id+"/mute", map[string]any{"muted": false}).Expect(t, http.StatusOK)
	a.c.Do(t, http.MethodPost, "/users/"+b.id+"/mute", map[string]any{"muted": false}).Expect(t, http.StatusOK)
	if l := a.c.Do(t, http.MethodGet, "/blocks", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("blocks after unblocking = %v", l)
	}
	if l := a.c.Do(t, http.MethodGet, "/mutes", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("mutes after unmuting = %v", l)
	}
}
