// Package receipts implements the receipt inbox (spec §4.9, §20B.10):
// upload pages, optional asynchronous extraction of candidate values (only
// when the client asks for it), user review (stored as a new extraction
// version so the original is preserved), duplicate warnings, and matching
// to an existing transaction or creating one from reviewed values only.
package receipts

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/files"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
)

// JobExtract reads candidate values from a receipt's files.
const JobExtract = "receipts.extract"

const (
	maxPages     = 20
	maxPageBytes = 15 << 20
	// maxListPage is the largest (and default) inbox page.
	maxListPage = 200
)

// Service implements receipts.
type Service struct {
	DB        *database.DB
	Files     *files.Service
	Finance   *finance.Service
	Extractor Extractor
	Now       func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// externalExtraction reports whether receipts would be sent to an outside
// AI provider (which needs the ai_receipt_processing consent).
func (s *Service) externalExtraction() bool {
	m, p, _, _ := s.extractor().Info()
	return m == "ai_vision" && p != ""
}

// receiptConsent reports whether the user allowed AI reading of receipts:
// both AI consents active and AI turned on (spec §4.12: receipts are never
// sent externally without explicit consent).
func receiptConsent(ctx context.Context, tx pgx.Tx, uid uuid.UUID) (bool, error) {
	var ok bool
	err := tx.QueryRow(ctx, `select coalesce((select ai_enabled from user_preferences where user_id = $1), false)
		and exists (select 1 from user_consents where user_id = $1 and consent_type = 'ai_processing' and revoked_at is null)
		and exists (select 1 from user_consents where user_id = $1 and consent_type = 'ai_receipt_processing' and revoked_at is null)`, uid).Scan(&ok)
	return ok, err
}

func (s *Service) extractor() Extractor {
	if s.Extractor == nil {
		return NotConfigured{}
	}
	return s.Extractor
}

// ReceiptFile is one page.
type ReceiptFile struct {
	FileID      uuid.UUID `json:"file_id"`
	PageNo      int16     `json:"page_no"`
	ContentType *string   `json:"content_type,omitempty"`
}

// ReceiptLineItemDTO is a receipt line.
type ReceiptLineItemDTO struct {
	Position    int16           `json:"position"`
	Description *string         `json:"description,omitempty"`
	Quantity    *string         `json:"quantity,omitempty"`
	UnitPrice   *apitypes.Money `json:"unit_price,omitempty"`
	Amount      *apitypes.Money `json:"amount,omitempty"`
	Tax         *apitypes.Money `json:"tax,omitempty"`
	Confidence  *string         `json:"confidence,omitempty"`
}

// ReceiptExtractionDTO is one extraction version (machine or user review).
type ReceiptExtractionDTO struct {
	ID                uuid.UUID            `json:"id"`
	Version           int32                `json:"version"`
	Method            string               `json:"method" enum:"deterministic_text,ai_vision,manual"`
	Provider          *string              `json:"provider,omitempty"`
	Model             *string              `json:"model,omitempty"`
	ExtractorVersion  string               `json:"extractor_version"`
	Status            string               `json:"status" enum:"queued,running,succeeded,failed"`
	MerchantName      *string              `json:"merchant_name,omitempty"`
	ReceiptDate       *string              `json:"receipt_date,omitempty"`
	ReceiptTime       *string              `json:"receipt_time,omitempty"`
	Currency          *string              `json:"currency,omitempty"`
	Subtotal          *apitypes.Money      `json:"subtotal,omitempty"`
	Tax               *apitypes.Money      `json:"tax,omitempty"`
	Tip               *apitypes.Money      `json:"tip,omitempty"`
	Discount          *apitypes.Money      `json:"discount,omitempty"`
	Total             *apitypes.Money      `json:"total,omitempty"`
	PaymentHint       *string              `json:"payment_hint,omitempty" doc:"Card and account numbers are masked to their last four digits"`
	ReceiptNumber     *string              `json:"receipt_number,omitempty"`
	FieldConfidence   map[string]float64   `json:"field_confidence" doc:"0–1 per field; low values need attention"`
	OverallConfidence *string              `json:"overall_confidence,omitempty"`
	Warnings          []string             `json:"warnings" doc:"English; localize by warning_codes"`
	WarningCodes      []string             `json:"warning_codes" enum:"totals_mismatch,line_items_mismatch,amount_unreadable,date_unreadable,currency_unrecognized,reader_note,extractor_not_configured,consent_required,file_unavailable,timeout,provider_error" doc:"Stable codes in the order of warnings: totals_mismatch (subtotal, tax, tip and discount do not add up to the total); line_items_mismatch (the line items do not add up to the subtotal); amount_unreadable, date_unreadable, currency_unrecognized (a value on the receipt could not be read; check it); reader_note (a note from automatic reading: show the English text). A failed reading carries its error_code: extractor_not_configured, consent_required, file_unavailable, timeout, provider_error"`
	WarningParams     []map[string]string  `json:"warning_params" doc:"Values for each warning, in the order of warnings (an empty object when the code has none): line_items_total, subtotal and currency (line_items_mismatch); value, the text that could not be read (amount_unreadable)"`
	ErrorCode         *string              `json:"error_code,omitempty"`
	LineItems         []ReceiptLineItemDTO `json:"line_items"`
	CreatedAt         time.Time            `json:"created_at"`
	CompletedAt       *time.Time           `json:"completed_at,omitempty"`
}

// ReceiptDTO is a receipt in the inbox.
type ReceiptDTO struct {
	ID            uuid.UUID             `json:"id"`
	Status        string                `json:"status" enum:"uploaded,processing,needs_review,reviewed,matched,failed,discarded"`
	Files         []ReceiptFile         `json:"files"`
	Current       *ReceiptExtractionDTO `json:"current,omitempty" doc:"Latest successful extraction or the reviewed values"`
	TransactionID *uuid.UUID            `json:"transaction_id,omitempty"`
	DuplicateOfID *uuid.UUID            `json:"duplicate_of_id,omitempty" doc:"Another receipt this one appears to duplicate"`
	ReviewedAt    *time.Time            `json:"reviewed_at,omitempty"`
	ReviewedBy    *uuid.UUID            `json:"reviewed_by,omitempty"`
	Notes         *string               `json:"notes,omitempty"`
	Version       int32                 `json:"version"`
	CreatedAt     time.Time             `json:"created_at"`
}

// ReceiptExtractionSummary lists past versions.
type ReceiptExtractionSummary struct {
	ID        uuid.UUID `json:"id"`
	Version   int32     `json:"version"`
	Method    string    `json:"method"`
	Status    string    `json:"status"`
	ErrorCode *string   `json:"error_code,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// ReceiptDetail adds the extraction history.
type ReceiptDetail struct {
	ReceiptDTO
	History []ReceiptExtractionSummary `json:"history"`
}

func (s *Service) loadReceipt(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*ReceiptDTO, uuid.UUID, error) {
	var r ReceiptDTO
	var owner uuid.UUID
	var current *uuid.UUID
	err := tx.QueryRow(ctx, `select id, status, current_extraction_id, transaction_id, duplicate_of_id, reviewed_at, reviewed_by, notes,
		version, created_at, user_id from receipts where id = $1`, id).Scan(&r.ID, &r.Status, &current, &r.TransactionID, &r.DuplicateOfID,
		&r.ReviewedAt, &r.ReviewedBy, &r.Notes, &r.Version, &r.CreatedAt, &owner)
	if database.IsNoRows(err) {
		return nil, uuid.Nil, apperr.NotFound("receipt")
	}
	if err != nil {
		return nil, uuid.Nil, err
	}
	rows, err := tx.Query(ctx, `select rf.file_id, rf.page_no, f.detected_mime from receipt_files rf join files f on f.id = rf.file_id
		where rf.receipt_id = $1 order by rf.page_no`, id)
	if err != nil {
		return nil, uuid.Nil, err
	}
	r.Files, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (ReceiptFile, error) {
		var f ReceiptFile
		err := row.Scan(&f.FileID, &f.PageNo, &f.ContentType)
		return f, err
	})
	if err != nil {
		return nil, uuid.Nil, err
	}
	if current != nil {
		if r.Current, err = loadExtraction(ctx, tx, *current); err != nil {
			return nil, uuid.Nil, err
		}
	}
	return &r, owner, nil
}

func loadExtraction(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*ReceiptExtractionDTO, error) {
	var e ReceiptExtractionDTO
	var d *time.Time
	var tm *string
	var sub, tax, tip, disc, total *int64
	var conf, warnParams []byte
	var warnCodes []string
	if err := tx.QueryRow(ctx, `select id, version, method, provider, model, extractor_version, status, merchant_name, receipt_date,
		to_char(receipt_time, 'HH24:MI'), currency, subtotal_minor, tax_minor, tip_minor, discount_minor, total_minor, payment_hint,
		receipt_number, field_confidence, overall_confidence::text, warnings, warning_codes, warning_params, error_code, created_at, completed_at
		from receipt_extractions where id = $1`, id).Scan(&e.ID, &e.Version, &e.Method, &e.Provider, &e.Model, &e.ExtractorVersion, &e.Status,
		&e.MerchantName, &d, &tm, &e.Currency, &sub, &tax, &tip, &disc, &total, &e.PaymentHint, &e.ReceiptNumber, &conf, &e.OverallConfidence,
		&e.Warnings, &warnCodes, &warnParams, &e.ErrorCode, &e.CreatedAt, &e.CompletedAt); err != nil {
		return nil, err
	}
	if d != nil {
		v := finance.LocalDateString(*d)
		e.ReceiptDate = &v
	}
	e.ReceiptTime = tm
	cur := ""
	if e.Currency != nil {
		cur = *e.Currency
	}
	if cur != "" {
		e.Subtotal, e.Tax, e.Tip, e.Discount, e.Total = apitypes.MP(sub, cur), apitypes.MP(tax, cur), apitypes.MP(tip, cur), apitypes.MP(disc, cur),
			apitypes.MP(total, cur)
	}
	e.FieldConfidence = map[string]float64{}
	_ = json.Unmarshal(conf, &e.FieldConfidence)
	if e.Warnings == nil {
		e.Warnings = []string{}
	}
	e.WarningCodes, e.WarningParams = alignWarnings(e.Warnings, warnCodes, warnParams)
	rows, err := tx.Query(ctx, `select position, description, quantity::text, unit_price_minor, amount_minor, tax_minor, confidence::text
		from receipt_line_items where extraction_id = $1 order by position`, id)
	if err != nil {
		return nil, err
	}
	e.LineItems, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (ReceiptLineItemDTO, error) {
		var li ReceiptLineItemDTO
		var up, amt, lt *int64
		if err := row.Scan(&li.Position, &li.Description, &li.Quantity, &up, &amt, &lt, &li.Confidence); err != nil {
			return li, err
		}
		if cur != "" {
			li.UnitPrice, li.Amount, li.Tax = apitypes.MP(up, cur), apitypes.MP(amt, cur), apitypes.MP(lt, cur)
		}
		return li, nil
	})
	return &e, err
}

// warning is a review or reading warning: a stable code, the English text
// and the values the code refers to.
type warning struct {
	Code   string
	Text   string
	Params map[string]string
}

const msgTotalsMismatch = "Subtotal, tax, tip and discount do not add up to the total."

// warningColumns splits warnings into the stored columns: English texts,
// codes and a JSON array with one params object per warning.
func warningColumns(ws []warning) ([]string, []string, []byte, error) {
	texts, codes, params := make([]string, 0, len(ws)), make([]string, 0, len(ws)), make([]map[string]string, 0, len(ws))
	for _, w := range ws {
		p := w.Params
		if p == nil {
			p = map[string]string{}
		}
		texts, codes, params = append(texts, w.Text), append(codes, w.Code), append(params, p)
	}
	b, err := json.Marshal(params)
	return texts, codes, b, err
}

// alignWarnings returns exactly one code and one params object per
// warning; anything missing (never expected after migration 000022) reads
// as a reader_note without values.
func alignWarnings(texts, codes []string, raw []byte) ([]string, []map[string]string) {
	var params []map[string]string
	_ = json.Unmarshal(raw, &params)
	outCodes, outParams := make([]string, len(texts)), make([]map[string]string, len(texts))
	for i := range texts {
		outCodes[i], outParams[i] = "reader_note", map[string]string{}
		if i < len(codes) && codes[i] != "" {
			outCodes[i] = codes[i]
		}
		if i < len(params) && params[i] != nil {
			outParams[i] = params[i]
		}
	}
	return outCodes, outParams
}

// ReceiptCreateInput adds a receipt from uploaded files.
type ReceiptCreateInput struct {
	FileIDs           []uuid.UUID `json:"file_ids" minItems:"1" maxItems:"20" doc:"Ready files with purpose receipt, in page order. A file can be a page of only one receipt that is not discarded"`
	Notes             string      `json:"notes,omitempty" maxLength:"1000"`
	ReadAutomatically bool        `json:"read_automatically,omitempty" doc:"Read the values automatically in the background (status processing). Default false: you enter the details (status needs_review). Reading also needs automatic reading to be configured and, for AI reading, AI turned on with both AI consents; otherwise the receipt starts in needs_review as well"`
	SkipExtraction    bool        `json:"skip_extraction,omitempty" deprecated:"true" doc:"Deprecated and ignored: receipts are entered manually unless read_automatically is true. Cannot be combined with read_automatically"`
}

// Create adds a receipt to the inbox (idempotent per key). The values are
// read automatically only when the client asks for it and reading is
// allowed; otherwise the user enters them.
func (s *Service) Create(ctx context.Context, key string, in ReceiptCreateInput) (*ReceiptDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	if in.ReadAutomatically && in.SkipExtraction {
		return nil, false, apperr.FieldError("body.skip_extraction", "skip_extraction is deprecated; leave it out when read_automatically is true.")
	}
	var out ReceiptDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "receipt.create", in, func() (ReceiptDTO, error) {
			r, err := s.create(ctx, tx, uid, in)
			if err != nil {
				return ReceiptDTO{}, err
			}
			return *r, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

func (s *Service) create(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in ReceiptCreateInput) (*ReceiptDTO, error) {
	seen := map[uuid.UUID]bool{}
	for _, fid := range in.FileIDs {
		if seen[fid] {
			return nil, apperr.FieldError("body.file_ids", "Each page can be added once.")
		}
		seen[fid] = true
	}
	// Two requests adding the same file wait for each other here (stable
	// order, so they cannot deadlock), then the second sees the first page.
	if err := lockPages(ctx, tx, uid, in.FileIDs); err != nil {
		return nil, err
	}
	var checksums []string
	for _, fid := range in.FileIDs {
		f, err := files.Get(ctx, tx, fid)
		if err != nil || f.OwnerID != uid || f.Purpose != "receipt" {
			return nil, apperr.FieldError("body.file_ids", "Upload receipt pages with purpose receipt first.")
		}
		if f.Status != "ready" {
			return nil, apperr.ConflictCode("page_not_ready", "A receipt page upload is not complete yet.",
				map[string]string{"file_id": fid.String(), "status": f.Status})
		}
		if err := pageFree(ctx, tx, uid, fid, uuid.Nil); err != nil {
			return nil, err
		}
		if f.ChecksumSHA256 != nil {
			checksums = append(checksums, *f.ChecksumSHA256)
		}
	}
	var dup *uuid.UUID
	if len(checksums) > 0 {
		var d uuid.UUID
		if err := tx.QueryRow(ctx, `select r.id from receipts r join receipt_files rf on rf.receipt_id = r.id join files f on f.id = rf.file_id
			where r.user_id = $1 and r.status <> 'discarded' and f.checksum_sha256 = any($2) order by r.created_at limit 1`, uid, checksums).Scan(&d); err == nil {
			dup = &d
		} else if !database.IsNoRows(err) {
			return nil, err
		}
	}
	read, err := s.startsReading(ctx, tx, uid, in.ReadAutomatically)
	if err != nil {
		return nil, err
	}
	id := uuid.New()
	status := "needs_review"
	if read {
		status = "processing"
	}
	if _, err := tx.Exec(ctx, `insert into receipts (id, user_id, status, duplicate_of_id, notes) values ($1,$2,$3,$4,$5)`,
		id, uid, status, dup, trim(in.Notes, 1000)); err != nil {
		return nil, err
	}
	for i, fid := range in.FileIDs {
		if _, err := tx.Exec(ctx, `insert into receipt_files (receipt_id, file_id, user_id, page_no) values ($1,$2,$3,$4)`, id, fid, uid, i+1); err != nil {
			return nil, err
		}
	}
	if read {
		if err := s.enqueue(ctx, tx, uid, id); err != nil {
			return nil, err
		}
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "receipt", EntityID: &id, Action: "created",
		Changes: map[string]any{"pages": len(in.FileIDs), "possible_duplicate": dup != nil, "read_automatically": read}}); err != nil {
		return nil, err
	}
	r, _, err := s.loadReceipt(ctx, tx, id)
	return r, err
}

// startsReading reports whether a new receipt is read automatically: only
// when the client asked for it, a reader is configured and, for an outside
// AI provider, the user turned AI on and gave both AI consents. Otherwise
// the receipt simply starts in needs_review (no failed reading is stored).
func (s *Service) startsReading(ctx context.Context, tx pgx.Tx, uid uuid.UUID, asked bool) (bool, error) {
	if !asked || !s.extractor().Configured() {
		return false, nil
	}
	if !s.externalExtraction() {
		return true, nil
	}
	return receiptConsent(ctx, tx, uid)
}

// lockPages locks the caller's file rows for the given pages in a stable
// order, so concurrent receipt writes that use the same file serialize.
func lockPages(ctx context.Context, tx pgx.Tx, uid uuid.UUID, ids []uuid.UUID) error {
	_, err := tx.Exec(ctx, `select id from files where id = any($1) and owner_user_id = $2 order by id for no key update`, ids, uid)
	return err
}

// pageFree answers 409 file_in_use when the file is already a page of
// another of the user's receipts that is not discarded (self excepted).
func pageFree(ctx context.Context, tx pgx.Tx, uid, fid, self uuid.UUID) error {
	var other uuid.UUID
	err := tx.QueryRow(ctx, `select rf.receipt_id from receipt_files rf join receipts r on r.id = rf.receipt_id
		where rf.file_id = $1 and rf.user_id = $2 and rf.receipt_id <> $3 and r.status <> 'discarded' order by r.created_at limit 1`, fid, uid, self).Scan(&other)
	if database.IsNoRows(err) {
		return nil
	}
	if err != nil {
		return err
	}
	return apperr.ConflictCode("file_in_use", "This file is already a page of another receipt.",
		map[string]string{"file_id": fid.String(), "receipt_id": other.String()})
}

func (s *Service) enqueue(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) error {
	_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobExtract, UserID: &uid, Payload: map[string]any{"receipt_id": id},
		DedupeKey: "receipts.extract:" + id.String() + ":" + strconv.FormatInt(s.now().UnixNano(), 36), Priority: 100, MaxAttempts: 3})
	return err
}

func trim(s string, n int) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	if r := []rune(s); len(r) > n {
		s = string(r[:n])
	}
	return &s
}

type receiptCursor struct {
	At *time.Time `json:"t"`
	ID uuid.UUID  `json:"i"`
}

// List returns a page of the receipt inbox, newest first, and the cursor of
// the next page ("" on the last page).
func (s *Service) List(ctx context.Context, status, cursor string, limit int) ([]ReceiptDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > maxListPage {
		limit = maxListPage
	}
	var cur receiptCursor
	if err := httpx.DecodeCursor(cursor, &cur); err != nil {
		return nil, "", err
	}
	out := []ReceiptDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		type pos struct {
			id uuid.UUID
			at time.Time
		}
		rows, err := tx.Query(ctx, `select id, created_at from receipts where user_id = $1 and (($2 = '' and status <> 'discarded') or status = $2)
			and ($3::timestamptz is null or (created_at, id) < ($3, $4)) order by created_at desc, id desc limit $5`,
			uid, status, cur.At, cur.ID, limit+1)
		if err != nil {
			return err
		}
		page, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (pos, error) {
			var p pos
			err := row.Scan(&p.id, &p.at)
			return p, err
		})
		if err != nil {
			return err
		}
		if len(page) > limit {
			last := page[limit-1]
			if next, err = httpx.EncodeCursor(receiptCursor{At: &last.at, ID: last.id}); err != nil {
				return err
			}
			page = page[:limit]
		}
		for _, p := range page {
			r, _, err := s.loadReceipt(ctx, tx, p.id)
			if err != nil {
				return err
			}
			out = append(out, *r)
		}
		return nil
	})
	return out, next, database.MapError(err)
}

// Get returns a receipt with its extraction history.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*ReceiptDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out ReceiptDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		r, _, err := s.loadReceipt(ctx, tx, id)
		if err != nil {
			return err
		}
		out.ReceiptDTO = *r
		rows, err := tx.Query(ctx, `select id, version, method, status, error_code, created_at from receipt_extractions where receipt_id = $1
			order by version desc`, id)
		if err != nil {
			return err
		}
		out.History, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (ReceiptExtractionSummary, error) {
			var e ReceiptExtractionSummary
			err := row.Scan(&e.ID, &e.Version, &e.Method, &e.Status, &e.ErrorCode, &e.CreatedAt)
			return e, err
		})
		return err
	})
	return &out, database.MapError(err)
}

// lockOwn locks a receipt the caller owns.
func lockOwn(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (status string, version int32, txID *uuid.UUID, err error) {
	var owner uuid.UUID
	if err := tx.QueryRow(ctx, `select user_id, status, version, transaction_id from receipts where id = $1 for update`, id).
		Scan(&owner, &status, &version, &txID); err != nil {
		if database.IsNoRows(err) {
			return "", 0, nil, apperr.NotFound("receipt")
		}
		return "", 0, nil, err
	}
	if owner != uid {
		return "", 0, nil, apperr.NotFound("receipt")
	}
	return status, version, txID, nil
}

// settledStatus is the status of a receipt that is in the inbox but not
// linked or being read: reviewed while its current values are the user's
// reviewed version (method manual), otherwise needs_review. Unlinking,
// restoring and a failed reading all return a receipt to it.
const settledStatus = `(case when exists (select 1 from receipt_extractions e where e.id = receipts.current_extraction_id and e.method = 'manual')
	then 'reviewed' else 'needs_review' end)`

// linkedParams names the linked transaction in a receipt_linked conflict.
func linkedParams(txID *uuid.UUID) map[string]string {
	if txID == nil {
		return nil
	}
	return map[string]string{"transaction_id": txID.String()}
}

// Process queues (re)extraction; a new version is created and earlier
// versions are kept.
func (s *Service) Process(ctx context.Context, id uuid.UUID) (*ReceiptDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReceiptDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		status, _, txID, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		switch status {
		case "matched":
			return apperr.ConflictCode("receipt_linked", "Unlink the transaction before reading the receipt again.", linkedParams(txID))
		case "discarded":
			return apperr.ConflictCode("receipt_discarded", "Restore the receipt before reading it again.", nil)
		case "processing":
			return apperr.ConflictCode("receipt_processing", "This receipt is already being read.", nil)
		}
		if !s.extractor().Configured() {
			return apperr.Unavailable(apperr.CodeNotConfigured, "Automatic receipt reading is not configured. Enter the details yourself.")
		}
		if s.externalExtraction() {
			ok, err := receiptConsent(ctx, tx, uid)
			if err != nil {
				return err
			}
			if !ok {
				return apperr.New(apperr.CodeConsentRequired, http.StatusForbidden,
					"Allow AI to read receipts (Settings → AI) or enter the details yourself.")
			}
		}
		if _, err := tx.Exec(ctx, `update receipts set status = 'processing', version = version + 1 where id = $1`, id); err != nil {
			return err
		}
		if err := s.enqueue(ctx, tx, uid, id); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "receipt", EntityID: &id, Action: "process"}); err != nil {
			return err
		}
		out, _, err = s.loadReceipt(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}

// ReceiptLineItemInput is a reviewed line.
type ReceiptLineItemInput struct {
	Description string `json:"description,omitempty" maxLength:"200"`
	Quantity    string `json:"quantity,omitempty" pattern:"^[0-9]{1,9}(\\.[0-9]{1,3})?$"`
	UnitPrice   string `json:"unit_price,omitempty"`
	Amount      string `json:"amount,omitempty"`
	Tax         string `json:"tax,omitempty"`
}

// ReceiptReviewInput confirms or corrects every value.
type ReceiptReviewInput struct {
	MerchantName  string                 `json:"merchant_name,omitempty" maxLength:"200"`
	ReceiptDate   string                 `json:"receipt_date" doc:"YYYY-MM-DD"`
	ReceiptTime   string                 `json:"receipt_time,omitempty" pattern:"^([01][0-9]|2[0-3]):[0-5][0-9]$"`
	Currency      string                 `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Default: extracted currency, then your base currency"`
	Subtotal      string                 `json:"subtotal,omitempty"`
	Tax           string                 `json:"tax,omitempty"`
	Tip           string                 `json:"tip,omitempty"`
	Discount      string                 `json:"discount,omitempty"`
	Total         string                 `json:"total"`
	PaymentHint   string                 `json:"payment_hint,omitempty" maxLength:"60" doc:"e.g. card ending 1234. Numbers with five or more digits (spaces, dashes and dots between digits ignored) are stored as their last four: •••• 1234"`
	ReceiptNumber string                 `json:"receipt_number,omitempty" maxLength:"80"`
	LineItems     []ReceiptLineItemInput `json:"line_items,omitempty" maxItems:"500"`
	Version       int32                  `json:"version"`
}

// Review stores the user's confirmed values as a new extraction version.
func (s *Service) Review(ctx context.Context, id uuid.UUID, in ReceiptReviewInput) (*ReceiptDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReceiptDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		status, version, txID, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if version != in.Version {
			return apperr.VersionConflict()
		}
		switch status {
		case "matched":
			return apperr.ConflictCode("receipt_linked", "Unlink the transaction before changing reviewed values.", linkedParams(txID))
		case "discarded":
			return apperr.ConflictCode("receipt_discarded", "Restore the receipt before reviewing it.", nil)
		case "processing":
			return apperr.ConflictCode("receipt_processing", "This receipt is still being read; review it when reading finishes.", nil)
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		cur := in.Currency
		if cur == "" {
			_ = tx.QueryRow(ctx, `select e.currency from receipts r join receipt_extractions e on e.id = r.current_extraction_id where r.id = $1`, id).Scan(&cur)
		}
		if cur == "" {
			cur = u.BaseCurrency
		}
		if !currency.Valid(cur) {
			return apperr.FieldError("body.currency", "Unsupported currency.")
		}
		d, err := finance.ParseDate("body.receipt_date", in.ReceiptDate, u.Loc)
		if err != nil {
			return err
		}
		if d.After(time.Date(s.now().Year(), s.now().Month(), s.now().Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, 1)) {
			return apperr.FieldError("body.receipt_date", "The receipt date cannot be in the future.")
		}
		amt := func(field, v string) (*int64, error) {
			if strings.TrimSpace(v) == "" {
				return nil, nil
			}
			x, err := money.Parse(v, cur, money.ParseOptions{AllowZero: true})
			if err != nil {
				return nil, apperr.FieldError(field, "Enter an amount in "+cur+" precision.")
			}
			return &x, nil
		}
		total, err := amt("body.total", in.Total)
		if err != nil {
			return err
		}
		if total == nil || *total <= 0 {
			return apperr.FieldError("body.total", "Enter the receipt total.")
		}
		sub, err := amt("body.subtotal", in.Subtotal)
		if err != nil {
			return err
		}
		tax, err := amt("body.tax", in.Tax)
		if err != nil {
			return err
		}
		tip, err := amt("body.tip", in.Tip)
		if err != nil {
			return err
		}
		disc, err := amt("body.discount", in.Discount)
		if err != nil {
			return err
		}
		warnings := arithmeticWarnings(sub, tax, tip, disc, total)
		var next int32
		if err := tx.QueryRow(ctx, `select coalesce(max(version), 0) + 1 from receipt_extractions where receipt_id = $1`, id).Scan(&next); err != nil {
			return err
		}
		eid := uuid.New()
		conf := map[string]float64{}
		for _, f := range []string{"merchant_name", "receipt_date", "currency", "total", "subtotal", "tax", "tip", "discount"} {
			conf[f] = 1
		}
		cj, _ := json.Marshal(conf)
		var tm *string
		if in.ReceiptTime != "" {
			tm = &in.ReceiptTime
		}
		var lineSum int64
		haveLines := false
		type li struct {
			desc                  *string
			qty                   *string
			unit, amount, taxLine *int64
		}
		var lines []li
		for i, l := range in.LineItems {
			field := fmt.Sprintf("body.line_items[%d]", i)
			unit, err := amt(field+".unit_price", l.UnitPrice)
			if err != nil {
				return err
			}
			a, err := amt(field+".amount", l.Amount)
			if err != nil {
				return err
			}
			lt, err := amt(field+".tax", l.Tax)
			if err != nil {
				return err
			}
			var q *string
			if l.Quantity != "" {
				q = &l.Quantity
			}
			if a != nil {
				haveLines = true
				lineSum += *a
			}
			lines = append(lines, li{trim(l.Description, 200), q, unit, a, lt})
		}
		if haveLines && sub != nil && lineSum != *sub {
			sum := money.Format(lineSum, cur)
			warnings = append(warnings, warning{Code: "line_items_mismatch", Text: "Line items add up to " + sum + ", not the subtotal.",
				Params: map[string]string{"line_items_total": sum, "subtotal": money.Format(*sub, cur), "currency": cur}})
		}
		texts, codes, params, err := warningColumns(warnings)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into receipt_extractions (id, receipt_id, user_id, version, method, extractor_version, status,
			merchant_name, receipt_date, receipt_time, currency, subtotal_minor, tax_minor, tip_minor, discount_minor, total_minor, payment_hint,
			receipt_number, field_confidence, overall_confidence, warnings, warning_codes, warning_params, completed_at)
			values ($1,$2,$3,$4,'manual','user-review-1','succeeded',$5,$6,$7::time,$8,$9,$10,$11,$12,$13,$14,$15,$16,1,$17,$18,$19,now())`,
			eid, id, uid, next, trim(in.MerchantName, 200), d, tm, cur, sub, tax, tip, disc, total, trim(maskPAN(in.PaymentHint), 60),
			trim(in.ReceiptNumber, 80), cj, texts, codes, params); err != nil {
			return err
		}
		for i, l := range lines {
			if _, err := tx.Exec(ctx, `insert into receipt_line_items (extraction_id, user_id, position, description, quantity, unit_price_minor,
				amount_minor, tax_minor, confidence) values ($1,$2,$3,$4,$5::numeric,$6,$7,$8,1)`, eid, uid, i+1, l.desc, l.qty, l.unit, l.amount, l.taxLine); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `update receipts set current_extraction_id = $2, status = 'reviewed', reviewed_by = $3, reviewed_at = now(),
			version = version + 1 where id = $1`, id, eid, uid); err != nil {
			return err
		}
		if err := s.flagDuplicate(ctx, tx, uid, id, d, *total, cur, in.MerchantName); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "receipt", EntityID: &id, Action: "reviewed",
			Changes: map[string]any{"extraction_version": next}}); err != nil {
			return err
		}
		out, _, err = s.loadReceipt(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}

// arithmeticWarnings checks that subtotal + tax + tip - discount = total.
func arithmeticWarnings(sub, tax, tip, disc, total *int64) []warning {
	w := []warning{}
	if sub == nil || total == nil {
		return w
	}
	v := *sub
	for _, p := range []*int64{tax, tip} {
		if p != nil {
			v += *p
		}
	}
	if disc != nil {
		v -= *disc
	}
	if v != *total {
		w = append(w, warning{Code: "totals_mismatch", Text: msgTotalsMismatch})
	}
	return w
}

// flagDuplicate links a likely duplicate receipt (same date, total,
// currency and merchant) as a warning; nothing is merged.
func (s *Service) flagDuplicate(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID, d time.Time, total int64, cur, merchant string) error {
	var other uuid.UUID
	err := tx.QueryRow(ctx, `select r.id from receipts r join receipt_extractions e on e.id = r.current_extraction_id
		where r.user_id = $1 and r.id <> $2 and r.status <> 'discarded' and e.receipt_date = $3 and e.total_minor = $4 and e.currency = $5
		and lower(coalesce(e.merchant_name, '')) = lower($6) order by r.created_at limit 1`, uid, id, d, total, cur, strings.TrimSpace(merchant)).Scan(&other)
	if database.IsNoRows(err) {
		_, err = tx.Exec(ctx, `update receipts set duplicate_of_id = null where id = $1 and duplicate_of_id is not null
			and not exists (select 1 from receipt_files rf join files f on f.id = rf.file_id join receipt_files rf2 on rf2.receipt_id = receipts.duplicate_of_id
			join files f2 on f2.id = rf2.file_id where rf.receipt_id = $1 and f.checksum_sha256 = f2.checksum_sha256)`, id)
		return err
	}
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `update receipts set duplicate_of_id = $2 where id = $1`, id, other)
	return err
}

// ReceiptMatchCandidate is a transaction that may be the receipt's purchase.
type ReceiptMatchCandidate struct {
	TransactionID uuid.UUID      `json:"transaction_id"`
	LocalDate     string         `json:"local_date"`
	Amount        apitypes.Money `json:"amount"`
	AccountName   string         `json:"account_name"`
	Merchant      *string        `json:"merchant,omitempty"`
	Description   *string        `json:"description,omitempty"`
	Reasons       []string       `json:"reasons" doc:"Why it was suggested (English; localize by reason_codes)"`
	ReasonCodes   []string       `json:"reason_codes" enum:"same_amount,amount_close,same_date,near_date,same_merchant" doc:"Stable reasons in the order of reasons: same_amount, or amount_close (up to 20% above the total: tip or fees); same_date, or near_date (within 3 days of the receipt date); same_merchant"`
}

// MatchCandidates suggests existing transactions (same currency, amount
// equal or within 20% for tips, ±3 days, no receipt yet).
func (s *Service) MatchCandidates(ctx context.Context, id uuid.UUID) ([]ReceiptMatchCandidate, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []ReceiptMatchCandidate{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		r, _, err := s.loadReceipt(ctx, tx, id)
		if err != nil {
			return err
		}
		e := r.Current
		if e == nil || e.Total == nil || e.ReceiptDate == nil || e.Currency == nil {
			return nil
		}
		merchant := ""
		if e.MerchantName != nil {
			merchant = strings.ToLower(*e.MerchantName)
		}
		rows, err := tx.Query(ctx, `select t.id, t.local_date, t.amount_minor, a.name, m.name, t.description
			from transactions t join financial_accounts a on a.id = t.account_id left join merchants m on m.id = t.merchant_id
			where t.user_id = $1 and t.deleted_at is null and t.status <> 'voided' and t.type in ('expense','group_expense') and t.receipt_id is null
			and t.currency = $2 and t.local_date between $3::date - 3 and $3::date + 3 and t.amount_minor between $4 and $4 * 6 / 5
			order by abs(t.amount_minor - $4), abs(t.local_date - $3::date) limit 10`, uid, *e.Currency, *e.ReceiptDate, e.Total.AmountMinor)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var c ReceiptMatchCandidate
			var d time.Time
			var amt int64
			if err := rows.Scan(&c.TransactionID, &d, &amt, &c.AccountName, &c.Merchant, &c.Description); err != nil {
				return err
			}
			c.LocalDate, c.Amount = finance.LocalDateString(d), apitypes.M(amt, *e.Currency)
			c.Reasons, c.ReasonCodes = []string{}, []string{}
			reason := func(code, text string) {
				c.ReasonCodes, c.Reasons = append(c.ReasonCodes, code), append(c.Reasons, text)
			}
			if amt == e.Total.AmountMinor {
				reason("same_amount", "Same amount as the total")
			} else {
				reason("amount_close", "Amount within 20% of the total (tip or fees)")
			}
			if c.LocalDate == *e.ReceiptDate {
				reason("same_date", "Same date")
			} else {
				reason("near_date", "Within 3 days")
			}
			if c.Merchant != nil && merchant != "" && (strings.Contains(strings.ToLower(*c.Merchant), merchant) || strings.Contains(merchant, strings.ToLower(*c.Merchant))) {
				reason("same_merchant", "Same merchant")
			}
			out = append(out, c)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// duplicate is a DUPLICATE error with a stable reason (details[0].code).
func duplicate(code, msg string) *apperr.Error {
	return apperr.New(apperr.CodeDuplicate, http.StatusConflict, msg).WithDetails(apperr.Detail{Code: code, Message: msg})
}

// link attaches the receipt to a transaction and its pages as attachments.
func link(ctx context.Context, tx pgx.Tx, uid, receiptID, txID uuid.UUID) error {
	var existing *uuid.UUID
	if err := tx.QueryRow(ctx, `select receipt_id from transactions where id = $1 and user_id = $2 and deleted_at is null for update`, txID, uid).
		Scan(&existing); err != nil {
		if database.IsNoRows(err) {
			return apperr.FieldError("body.transaction_id", "Transaction not found.")
		}
		return err
	}
	if existing != nil && *existing != receiptID {
		return duplicate("transaction_has_receipt", "This transaction already has a receipt.")
	}
	if _, err := tx.Exec(ctx, `update transactions set receipt_id = $2 where id = $1`, txID, receiptID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `insert into transaction_attachments (user_id, transaction_id, file_id)
		select $1, $2, file_id from receipt_files where receipt_id = $3 on conflict (transaction_id, file_id) do nothing`, uid, txID, receiptID); err != nil {
		return err
	}
	_, err := tx.Exec(ctx, `update receipts set transaction_id = $2, status = 'matched', version = version + 1 where id = $1`, receiptID, txID)
	return err
}

// ReceiptMatchInput links an existing transaction.
type ReceiptMatchInput struct {
	TransactionID uuid.UUID `json:"transaction_id"`
}

// Match links a receipt to an existing transaction (no new money is
// recorded).
func (s *Service) Match(ctx context.Context, id uuid.UUID, in ReceiptMatchInput) (*ReceiptDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReceiptDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		status, _, txID, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		switch status {
		case "discarded":
			return apperr.ConflictCode("receipt_discarded", "Restore the receipt before linking it to a transaction.", nil)
		case "processing":
			return apperr.ConflictCode("receipt_processing", "This receipt is still being read; link it when reading finishes.", nil)
		}
		if txID != nil && *txID != in.TransactionID {
			return apperr.ConflictCode("receipt_linked", "Unlink the current transaction first.", linkedParams(txID))
		}
		if err := link(ctx, tx, uid, id, in.TransactionID); err != nil {
			if database.IsUniqueViolation(err, "receipts_transaction_key") {
				return duplicate("transaction_has_receipt", "Another receipt is already linked to this transaction.")
			}
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "receipt", EntityID: &id, Action: "matched",
			Changes: map[string]any{"transaction_id": in.TransactionID}}); err != nil {
			return err
		}
		out, _, err = s.loadReceipt(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}

// ReceiptCreateTransactionInput records the purchase from reviewed values.
type ReceiptCreateTransactionInput struct {
	AccountID   uuid.UUID  `json:"account_id"`
	CategoryID  *uuid.UUID `json:"category_id,omitempty"`
	Description string     `json:"description,omitempty" maxLength:"500"`
}

// CreateTransaction records an expense from the reviewed values (never from
// unreviewed extraction candidates). Idempotent per key.
func (s *Service) CreateTransaction(ctx context.Context, key string, id uuid.UUID, in ReceiptCreateTransactionInput) (*ReceiptDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out ReceiptDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "receipt.create_transaction", struct {
			ID uuid.UUID
			In ReceiptCreateTransactionInput
		}{id, in}, func() (ReceiptDTO, error) {
			status, _, txID, err := lockOwn(ctx, tx, uid, id)
			if err != nil {
				return ReceiptDTO{}, err
			}
			switch {
			case status == "discarded":
				return ReceiptDTO{}, apperr.ConflictCode("receipt_discarded", "Restore the receipt before recording the purchase.", nil)
			case status == "processing":
				return ReceiptDTO{}, apperr.ConflictCode("receipt_processing", "This receipt is still being read; review it when reading finishes.", nil)
			case txID != nil:
				return ReceiptDTO{}, apperr.ConflictCode("receipt_linked", "This receipt is already linked to a transaction.", linkedParams(txID))
			case status != "reviewed":
				return ReceiptDTO{}, apperr.Rule("receipt_not_reviewed", "Review the receipt values before recording the purchase.", nil)
			}
			r, _, err := s.loadReceipt(ctx, tx, id)
			if err != nil {
				return ReceiptDTO{}, err
			}
			e := r.Current
			if e == nil || e.Method != "manual" {
				// Only values the user confirmed are ever recorded.
				return ReceiptDTO{}, apperr.Rule("receipt_not_reviewed", "Review the receipt values before recording the purchase.", nil)
			}
			if e.Total == nil || e.ReceiptDate == nil {
				return ReceiptDTO{}, apperr.Rule("receipt_incomplete", "The reviewed receipt needs a date and a total.", nil)
			}
			var acctCur string
			if err := tx.QueryRow(ctx, `select currency from financial_accounts where id = $1 and user_id = $2`, in.AccountID, uid).Scan(&acctCur); err != nil {
				if database.IsNoRows(err) {
					return ReceiptDTO{}, apperr.FieldError("body.account_id", "Choose one of your accounts.")
				}
				return ReceiptDTO{}, err
			}
			if acctCur != e.Total.Currency {
				return ReceiptDTO{}, apperr.FieldError("body.account_id", "Choose an account in "+e.Total.Currency+" (the receipt currency).")
			}
			desc := in.Description
			if desc == "" && e.MerchantName != nil {
				desc = *e.MerchantName
			}
			merchant := ""
			if e.MerchantName != nil {
				merchant = *e.MerchantName
			}
			rid := id
			txNew, err := s.Finance.CreateInTx(ctx, tx, uid, finance.TransactionInput{Type: "expense", AccountID: in.AccountID, Amount: e.Total.Amount,
				LocalDate: *e.ReceiptDate, CategoryID: in.CategoryID, MerchantName: merchant, Description: desc}, "receipt",
				&finance.Provenance{ReceiptID: &rid, ActorKind: "user"})
			if err != nil {
				return ReceiptDTO{}, err
			}
			if err := link(ctx, tx, uid, id, txNew); err != nil {
				return ReceiptDTO{}, err
			}
			if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "receipt", EntityID: &id, Action: "transaction_created",
				Changes: map[string]any{"transaction_id": txNew}}); err != nil {
				return ReceiptDTO{}, err
			}
			nr, _, err := s.loadReceipt(ctx, tx, id)
			if err != nil {
				return ReceiptDTO{}, err
			}
			return *nr, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// Unlink removes the transaction link (the transaction is not changed
// otherwise; receipt pages are detached from it).
func (s *Service) Unlink(ctx context.Context, id uuid.UUID) (*ReceiptDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReceiptDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, _, txID, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if txID == nil {
			return apperr.ConflictCode("receipt_not_linked", "This receipt is not linked to a transaction.", nil)
		}
		if err := unlink(ctx, tx, id, *txID); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "receipt", EntityID: &id, Action: "unlinked",
			Changes: map[string]any{"transaction_id": *txID}}); err != nil {
			return err
		}
		out, _, err = s.loadReceipt(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}

func unlink(ctx context.Context, tx pgx.Tx, receiptID, txID uuid.UUID) error {
	if _, err := tx.Exec(ctx, `update transactions set receipt_id = null where id = $1 and receipt_id = $2`, txID, receiptID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `delete from transaction_attachments where transaction_id = $1 and file_id in
		(select file_id from receipt_files where receipt_id = $2)`, txID, receiptID); err != nil {
		return err
	}
	_, err := tx.Exec(ctx, `update receipts set transaction_id = null, status = `+settledStatus+`, version = version + 1 where id = $1`, receiptID)
	return err
}

// Discard removes a receipt from the inbox (files stay until deleted). A
// linked transaction is unlinked; reading under way is dropped when it
// finishes. version, when not 0, must match the receipt's version.
func (s *Service) Discard(ctx context.Context, id uuid.UUID, version int32) (*ReceiptDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReceiptDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		status, current, txID, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if version != 0 && version != current {
			return apperr.VersionConflict()
		}
		if status == "discarded" {
			return apperr.ConflictCode("receipt_discarded", "This receipt is already discarded.", nil)
		}
		if txID != nil {
			if err := unlink(ctx, tx, id, *txID); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `update receipts set status = 'discarded', version = version + 1 where id = $1`, id); err != nil {
			return err
		}
		changes := map[string]any{"from": status}
		if txID != nil {
			changes["unlinked_transaction_id"] = *txID
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "receipt", EntityID: &id, Action: "discarded",
			Changes: changes}); err != nil {
			return err
		}
		out, _, err = s.loadReceipt(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}

// Restore returns a discarded receipt to the inbox in the status it would
// have without the discard: reviewed while its current values are the
// user's reviewed version, otherwise needs_review. A transaction unlinked
// by the discard stays unlinked and reading that was under way is not
// resumed (POST /receipts/{id}/process reads it again). version, when not
// 0, must match the receipt's version.
func (s *Service) Restore(ctx context.Context, id uuid.UUID, version int32) (*ReceiptDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReceiptDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		status, current, _, err := lockOwn(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if version != 0 && version != current {
			return apperr.VersionConflict()
		}
		if status != "discarded" {
			return apperr.ConflictCode("receipt_not_discarded", "Only a discarded receipt can be restored.", map[string]string{"status": status})
		}
		// A page may have been added to another receipt after the discard.
		rows, err := tx.Query(ctx, `select file_id from receipt_files where receipt_id = $1 order by page_no`, id)
		if err != nil {
			return err
		}
		pages, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		if err := lockPages(ctx, tx, uid, pages); err != nil {
			return err
		}
		for _, fid := range pages {
			if err := pageFree(ctx, tx, uid, fid, id); err != nil {
				return err
			}
		}
		var to string
		if err := tx.QueryRow(ctx, `update receipts set status = `+settledStatus+`, version = version + 1 where id = $1 returning status`, id).
			Scan(&to); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "receipt", EntityID: &id, Action: "restored",
			Changes: map[string]any{"status": to}}); err != nil {
			return err
		}
		out, _, err = s.loadReceipt(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}
