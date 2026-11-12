// Package imports implements statement imports (spec §4.10, §20B.11):
// upload → isolated parse → mapping → preview with duplicate detection →
// user confirmation → idempotent processing, with cancellation, retry of
// failed rows and rollback of untouched imports. Raw rows are kept separate
// from posted transactions and every row carries its status and reason.
package imports

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/domain/reconcile"
	"montra/backend/internal/domain/statement"
	"montra/backend/internal/files"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/observability"
)

// Job types.
const (
	JobParse     = "imports.parse"     // read + parse the file, apply the suggested mapping
	JobNormalize = "imports.normalize" // apply a user mapping
	JobProcess   = "imports.process"   // create transactions for confirmed rows
	JobRollback  = "imports.rollback"  // void untouched imported transactions
)

const (
	maxFileBytes = 10 << 20
	// duplicateMinScore: same amount/direction and dates within a day, or
	// within three days with a similar description (domain/reconcile).
	duplicateMinScore = 640
)

// Service implements imports.
type Service struct {
	DB      *database.DB
	Finance *finance.Service
	Files   *files.Service
	// PDF reads statement PDFs (AI); nil or unconfigured means PDFs are
	// refused with a hint to export CSV/XLSX/OFX.
	PDF PDFReader
	Now func() time.Time
	// Metrics counts imported/failed/duplicate rows (optional).
	Metrics *observability.Metrics
}

// PDFReader turns a statement PDF into a table for the normal review flow.
type PDFReader interface {
	Configured() bool
	ReadStatement(ctx context.Context, pdf []byte) (*statement.Table, error)
}

// pdfAllowed reports whether the user may have a PDF read by AI: AI on and
// the ai_processing consent active (the per-import opt-in is separate).
func pdfAllowed(ctx context.Context, tx pgx.Tx, uid uuid.UUID) (bool, error) {
	var ok bool
	err := tx.QueryRow(ctx, `select coalesce((select ai_enabled from user_preferences where user_id = $1), false)
		and exists (select 1 from user_consents where user_id = $1 and consent_type = 'ai_processing' and revoked_at is null)`, uid).Scan(&ok)
	return ok, err
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// ImportBatchDTO is an import batch.
type ImportBatchDTO struct {
	ID                uuid.UUID                `json:"id"`
	AccountID         uuid.UUID                `json:"account_id"`
	Currency          string                   `json:"currency" doc:"Account currency used for all rows"`
	FileID            *uuid.UUID               `json:"file_id,omitempty"`
	SourceFormat      *string                  `json:"source_format,omitempty" enum:"csv,xlsx,ofx,qfx,pdf"`
	ParserVersion     *string                  `json:"parser_version,omitempty"`
	Status            string                   `json:"status" enum:"awaiting_upload,uploaded,parsing,needs_mapping,preview_ready,confirmed,processing,completed,completed_with_errors,failed,cancelled"`
	Encoding          *string                  `json:"encoding,omitempty"`
	Header            []string                 `json:"header"`
	Mapping           *statement.ColumnMapping `json:"mapping,omitempty"`
	MappingNotes      []string                 `json:"mapping_notes" doc:"What to check in the suggested mapping (English; localize by mapping_note_codes)"`
	MappingNoteCodes  []string                 `json:"mapping_note_codes" enum:"no_header_row,ambiguous_date_order,unknown_date_format,decimal_comma,mapping_incomplete,check_sign_convention,pdf_read_by_ai" doc:"Stable codes for mapping_notes, same order (empty only for imports read before codes existed whose notes were not recognized)"`
	MappingNoteParams map[string]string        `json:"mapping_note_params" doc:"Values the note codes refer to: assumed_date_format and alternative_date_format (ambiguous_date_order)"`
	TotalRows         int32                    `json:"total_rows" doc:"Data rows after the header"`
	ValidRows         int32                    `json:"valid_rows"`
	InvalidRows       int32                    `json:"invalid_rows"`
	DuplicateRows     int32                    `json:"duplicate_rows"`
	ImportedCount     int32                    `json:"imported_count"`
	SkippedCount      int32                    `json:"skipped_count"`
	FailedCount       int32                    `json:"failed_count"`
	ToImportRows      int32                    `json:"to_import_rows" doc:"Rows that confirm (or retry-failed) would import now under the current decisions: ready rows not skipped plus duplicates marked import. While processing, the rows still to import"`
	StatementStart    *string                  `json:"statement_start,omitempty"`
	StatementEnd      *string                  `json:"statement_end,omitempty"`
	OpeningBalance    *apitypes.Money          `json:"statement_opening_balance,omitempty"`
	ClosingBalance    *apitypes.Money          `json:"statement_closing_balance,omitempty"`
	Totals            *RowTotals               `json:"totals,omitempty" doc:"Sums of valid rows and running-balance check"`
	ErrorCode         *string                  `json:"error_code,omitempty" doc:"Why the import failed or was undone (stable; localize by it): unsupported_format, pdf_needs_ai, pdf_unreadable, file_unavailable, empty, malformed, too_large, too_many_rows, too_many_columns, currency_mismatch, rolled_back"`
	ErrorMessage      *string                  `json:"error_message,omitempty" doc:"English; localize by error_code"`
	ErrorParams       map[string]string        `json:"error_params,omitempty" doc:"Values error_code refers to: currency_mismatch has statement_currency and account_currency; rolled_back has voided and kept (counts)"`
	PreviousImport    *uuid.UUID               `json:"previous_import_of_file,omitempty" doc:"An earlier batch of the same file into this account"`
	CancelRequested   bool                     `json:"cancel_requested"`
	Version           int32                    `json:"version"`
	CreatedAt         time.Time                `json:"created_at"`
	ConfirmedAt       *time.Time               `json:"confirmed_at,omitempty"`
	CompletedAt       *time.Time               `json:"completed_at,omitempty"`
	CancelledAt       *time.Time               `json:"cancelled_at,omitempty"`
}

// RowTotals sums an import's valid rows and checks the running balance.
// Amounts are Money objects; the *_minor fields repeat them for older
// clients.
type RowTotals struct {
	ValidRows           int             `json:"valid_rows"`
	Inflow              apitypes.Money  `json:"inflow" doc:"Money in"`
	Outflow             apitypes.Money  `json:"outflow" doc:"Money out (a positive amount)"`
	Net                 apitypes.Money  `json:"net" doc:"inflow − outflow"`
	OpeningBalance      *apitypes.Money `json:"opening_balance,omitempty" doc:"Balance before the first row, from the running balances"`
	ClosingBalance      *apitypes.Money `json:"closing_balance,omitempty" doc:"Running balance after the last row"`
	BalanceCheck        string          `json:"balance_check" enum:"ok,mismatch,not_available"`
	MismatchedRows      []int           `json:"mismatched_rows,omitempty" doc:"Row numbers whose running balance does not follow"`
	FirstDate           string          `json:"first_date,omitempty"`
	LastDate            string          `json:"last_date,omitempty"`
	Order               string          `json:"order,omitempty" enum:"ascending,descending,mixed"`
	InflowMinor         int64           `json:"inflow_minor" deprecated:"true" doc:"Deprecated: use inflow"`
	OutflowMinor        int64           `json:"outflow_minor" deprecated:"true" doc:"Deprecated: use outflow"`
	NetMinor            int64           `json:"net_minor" deprecated:"true" doc:"Deprecated: use net"`
	OpeningBalanceMinor *int64          `json:"opening_balance_minor,omitempty" deprecated:"true" doc:"Deprecated: use opening_balance"`
	ClosingBalanceMinor *int64          `json:"closing_balance_minor,omitempty" deprecated:"true" doc:"Deprecated: use closing_balance"`
}

func totalsDTO(t statement.RowTotals, cur string) *RowTotals {
	return &RowTotals{ValidRows: t.ValidRows, Inflow: apitypes.M(t.InflowMinor, cur), Outflow: apitypes.M(t.OutflowMinor, cur),
		Net: apitypes.M(t.NetMinor, cur), OpeningBalance: apitypes.MP(t.OpeningBalance, cur), ClosingBalance: apitypes.MP(t.ClosingBalance, cur),
		BalanceCheck: t.BalanceCheck, MismatchedRows: t.MismatchedRows, FirstDate: t.FirstDate, LastDate: t.LastDate, Order: t.ChronologicalHint,
		InflowMinor: t.InflowMinor, OutflowMinor: t.OutflowMinor, NetMinor: t.NetMinor, OpeningBalanceMinor: t.OpeningBalance,
		ClosingBalanceMinor: t.ClosingBalance}
}

// importable is the rule confirm, retry-failed and processing share (and
// to_import_rows counts): rows not imported yet that are ready, unless the
// user chose to skip them, plus duplicates the user chose to import.
const importable = `r.transaction_id is null and ((r.status = 'ready' and coalesce(r.user_decision, 'import') = 'import')
	or (r.status = 'duplicate' and r.user_decision = 'import'))`

const batchCols = `b.id, b.account_id, a.currency, b.file_id, b.source_format, b.parser_version, b.status, b.detected_encoding,
	coalesce(b.header_row, '{}'), b.mapping, b.mapping_notes, b.mapping_note_codes, b.mapping_note_params, b.total_rows, b.valid_rows,
	b.invalid_rows, b.duplicate_rows, b.imported_count, b.skipped_count, b.failed_count,
	(select count(*) from import_rows r where r.batch_id = b.id and ` + importable + `)::int,
	b.statement_start_date, b.statement_end_date,
	b.statement_opening_balance_minor, b.statement_closing_balance_minor, b.totals_check, b.error_code, b.error_message, b.error_params,
	b.cancel_requested_at is not null, b.version, b.created_at, b.confirmed_at, b.completed_at, b.cancelled_at, b.user_id,
	b.file_fingerprint`

const batchFrom = ` from import_batches b join financial_accounts a on a.id = b.account_id`

type batchRow struct {
	ImportBatchDTO
	userID      uuid.UUID
	fingerprint *string
	mapping     statement.ColumnMapping
	hasMapping  bool
}

func scanBatch(r pgx.Row) (*batchRow, error) {
	var b batchRow
	var mapping, totals []byte
	var start, end *time.Time
	var open, closing *int64
	if err := r.Scan(&b.ID, &b.AccountID, &b.Currency, &b.FileID, &b.SourceFormat, &b.ParserVersion, &b.Status, &b.Encoding, &b.Header,
		&mapping, &b.MappingNotes, &b.MappingNoteCodes, &b.MappingNoteParams, &b.TotalRows, &b.ValidRows, &b.InvalidRows, &b.DuplicateRows,
		&b.ImportedCount, &b.SkippedCount, &b.FailedCount, &b.ToImportRows, &start, &end, &open, &closing, &totals, &b.ErrorCode,
		&b.ErrorMessage, &b.ErrorParams, &b.CancelRequested, &b.Version, &b.CreatedAt, &b.ConfirmedAt, &b.CompletedAt, &b.CancelledAt,
		&b.userID, &b.fingerprint); err != nil {
		return nil, err
	}
	if len(mapping) > 2 {
		if err := json.Unmarshal(mapping, &b.mapping); err != nil {
			return nil, err
		}
		b.hasMapping = true
		m := b.mapping
		b.Mapping = &m
	}
	if len(totals) > 2 {
		var t statement.RowTotals
		if err := json.Unmarshal(totals, &t); err != nil {
			return nil, err
		}
		b.Totals = totalsDTO(t, b.Currency)
	}
	if start != nil {
		v := finance.LocalDateString(*start)
		b.StatementStart = &v
	}
	if end != nil {
		v := finance.LocalDateString(*end)
		b.StatementEnd = &v
	}
	b.OpeningBalance, b.ClosingBalance = apitypes.MP(open, b.Currency), apitypes.MP(closing, b.Currency)
	if b.Header == nil {
		b.Header = []string{}
	}
	if b.MappingNotes == nil {
		b.MappingNotes = []string{}
	}
	if b.MappingNoteCodes == nil {
		b.MappingNoteCodes = []string{}
	}
	if b.MappingNoteParams == nil {
		b.MappingNoteParams = map[string]string{}
	}
	if len(b.ErrorParams) == 0 {
		b.ErrorParams = nil
	}
	return &b, nil
}

func (s *Service) loadBatch(ctx context.Context, tx pgx.Tx, id uuid.UUID, lock bool) (*batchRow, error) {
	q := `select ` + batchCols + batchFrom + ` where b.id = $1`
	if lock {
		q += ` for update of b`
	}
	b, err := scanBatch(tx.QueryRow(ctx, q, id))
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("import")
	}
	if err != nil {
		return nil, err
	}
	if b.fingerprint != nil {
		var prev uuid.UUID
		if err := tx.QueryRow(ctx, `select id from import_batches where user_id = $1 and account_id = $2 and file_fingerprint = $3
			and id <> $4 and status not in ('cancelled','failed') order by created_at limit 1`, b.userID, b.AccountID, *b.fingerprint, b.ID).
			Scan(&prev); err == nil {
			b.PreviousImport = &prev
		}
	}
	return b, nil
}

// ImportCreateInput starts an import from an uploaded statement file.
type ImportCreateInput struct {
	AccountID uuid.UUID `json:"account_id"`
	FileID    uuid.UUID `json:"file_id" doc:"A ready file uploaded with purpose statement_import"`
	// AllowAIExtraction is the explicit per-import opt-in for PDFs.
	AllowAIExtraction bool `json:"allow_ai_extraction,omitempty" doc:"PDF statements only: let AI read this PDF (needs AI turned on with the ai_processing consent); every row is reviewed before import"`
}

func formatFor(mime string) string {
	switch mime {
	case "text/csv":
		return "csv"
	case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
		return "xlsx"
	case "application/x-ofx":
		return "ofx"
	case "application/pdf":
		return "pdf"
	}
	return ""
}

// Create creates a batch and queues parsing. A retry with the same
// Idempotency-Key returns the batch created first (no second batch or parse).
func (s *Service) Create(ctx context.Context, key string, in ImportCreateInput) (*ImportBatchDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out ImportBatchDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "import.create", in, func() (ImportBatchDTO, error) {
			b, err := s.createTx(ctx, tx, uid, in)
			if err != nil {
				return ImportBatchDTO{}, err
			}
			return *b, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

func (s *Service) createTx(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in ImportCreateInput) (*ImportBatchDTO, error) {
	var status string
	if err := tx.QueryRow(ctx, `select status from financial_accounts where id = $1 and user_id = $2`, in.AccountID, uid).Scan(&status); err != nil {
		if database.IsNoRows(err) {
			return nil, apperr.FieldError("body.account_id", "Choose one of your accounts.")
		}
		return nil, err
	}
	if status != "active" {
		return nil, apperr.Rule("account_inactive", "Imports need an active account.", nil)
	}
	f, err := files.Get(ctx, tx, in.FileID)
	if err != nil {
		return nil, apperr.FieldError("body.file_id", "Upload the statement first.")
	}
	if f.OwnerID != uid || f.Purpose != "statement_import" {
		return nil, apperr.FieldError("body.file_id", "Upload the statement with purpose statement_import.")
	}
	if f.Status != "ready" {
		return nil, apperr.Conflict("The statement upload is not complete yet.")
	}
	format := ""
	if f.ContentType != nil {
		format = formatFor(*f.ContentType)
	}
	id := uuid.New()
	batchStatus, code, msg := "uploaded", (*string)(nil), (*string)(nil)
	switch format {
	case "":
		c, m := "unsupported_format", "This file type cannot be imported. Use CSV, XLSX, OFX/QFX or a PDF statement."
		batchStatus, code, msg = "failed", &c, &m
	case "pdf":
		allowed := false
		if s.PDF != nil && s.PDF.Configured() && in.AllowAIExtraction {
			if allowed, err = pdfAllowed(ctx, tx, uid); err != nil {
				return nil, err
			}
		}
		if !allowed {
			c, m := "pdf_needs_ai", "PDF statements are read by AI. Turn AI on (Settings → AI), then import again with allow_ai_extraction, "+
				"or export CSV, XLSX or OFX from your bank."
			if s.PDF == nil || !s.PDF.Configured() {
				c, m = "unsupported_format", "PDF statements cannot be read in this environment. Export CSV, XLSX or OFX from your bank."
			}
			batchStatus, code, msg = "failed", &c, &m
		}
	}
	var fmtPtr *string
	if format != "" {
		fmtPtr = &format
	}
	if _, err := tx.Exec(ctx, `insert into import_batches (id, user_id, account_id, file_id, source_format, status, file_fingerprint,
		error_code, error_message) values ($1,$2,$3,$4,$5,$6,$7,$8,$9)`, id, uid, in.AccountID, in.FileID, fmtPtr, batchStatus,
		f.ChecksumSHA256, code, msg); err != nil {
		return nil, err
	}
	if batchStatus == "uploaded" {
		if err := enqueue(ctx, tx, JobParse, uid, id, ""); err != nil {
			return nil, err
		}
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "import_batch", EntityID: &id, Action: "created",
		Changes: map[string]any{"format": format}}); err != nil {
		return nil, err
	}
	b, err := s.loadBatch(ctx, tx, id, false)
	if err != nil {
		return nil, err
	}
	return &b.ImportBatchDTO, nil
}

type batchCursor struct {
	At time.Time `json:"t"`
	ID uuid.UUID `json:"i"`
}

// List returns the caller's import batches, newest first, a page at a time
// (keyset on created_at, id).
func (s *Service) List(ctx context.Context, accountID *uuid.UUID, cursor string, limit int) ([]ImportBatchDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	var at *time.Time
	var after *uuid.UUID
	if cursor != "" {
		var c batchCursor
		if err := httpx.DecodeCursor(cursor, &c); err != nil {
			return nil, "", err
		}
		at, after = &c.At, &c.ID
	}
	out := []ImportBatchDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+batchCols+batchFrom+` where b.user_id = $1 and ($2::uuid is null or b.account_id = $2)
			and ($3::timestamptz is null or (b.created_at, b.id) < ($3, $4)) order by b.created_at desc, b.id desc limit $5`,
			uid, accountID, at, after, limit+1)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			b, err := scanBatch(rows)
			if err != nil {
				return err
			}
			out = append(out, b.ImportBatchDTO)
		}
		if err := rows.Err(); err != nil {
			return err
		}
		if len(out) > limit {
			out = out[:limit]
			last := out[limit-1]
			if next, err = httpx.EncodeCursor(batchCursor{At: last.CreatedAt, ID: last.ID}); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	return out, next, nil
}

// Get returns a batch.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*ImportBatchDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ImportBatchDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		b, err := s.loadBatch(ctx, tx, id, false)
		if err != nil {
			return err
		}
		out = &b.ImportBatchDTO
		return nil
	})
	return out, database.MapError(err)
}

// ownBatch locks a batch owned by the caller.
func (s *Service) ownBatch(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (*batchRow, error) {
	b, err := s.loadBatch(ctx, tx, id, true)
	if err != nil {
		return nil, err
	}
	if b.userID != uid {
		return nil, apperr.NotFound("import")
	}
	return b, nil
}

// ImportMappingInput replaces the column mapping.
type ImportMappingInput struct {
	Mapping statement.ColumnMapping `json:"mapping"`
	Version int32                   `json:"version"`
}

// SetMapping stores a mapping and queues normalization (row decisions and
// corrections are reset because rows are re-derived).
func (s *Service) SetMapping(ctx context.Context, id uuid.UUID, in ImportMappingInput) (*ImportBatchDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ImportBatchDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		b, err := s.ownBatch(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if b.Version != in.Version {
			return apperr.VersionConflict()
		}
		if b.Status != "needs_mapping" && b.Status != "preview_ready" {
			return apperr.Conflict("The mapping can be changed only before the import is confirmed.")
		}
		width := len(b.Header)
		if in.Mapping.HeaderRow < 0 || width == 0 {
			if err := tx.QueryRow(ctx, `select coalesce(max(jsonb_array_length(raw)), 0) from import_rows where batch_id = $1`, id).Scan(&width); err != nil {
				return err
			}
		}
		if err := in.Mapping.Validate(width); err != nil {
			var se *statement.Error
			if errors.As(err, &se) {
				return apperr.FieldError("body.mapping", se.Message)
			}
			return err
		}
		raw, err := json.Marshal(in.Mapping)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update import_batches set mapping = $2, status = 'parsing', version = version + 1 where id = $1`, id, raw); err != nil {
			return err
		}
		if err := enqueue(ctx, tx, JobNormalize, uid, id, raw2key(raw)); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "import_batch", EntityID: &id, Action: "mapping_set"}); err != nil {
			return err
		}
		nb, err := s.loadBatch(ctx, tx, id, false)
		if err != nil {
			return err
		}
		out = &nb.ImportBatchDTO
		return nil
	})
	return out, database.MapError(err)
}

func raw2key(b []byte) string {
	if len(b) > 40 {
		b = b[:40]
	}
	return strings.NewReplacer(" ", "", "\"", "").Replace(string(b))
}

// ImportRowDTO is one statement row with its normalized values.
type ImportRowDTO struct {
	ID                       uuid.UUID         `json:"id"`
	RowNumber                int32             `json:"row_number" doc:"Line (CSV), sheet row (XLSX) or record (OFX) in the original file"`
	Raw                      []string          `json:"raw" doc:"Cells as read (never evaluated)"`
	PostedDate               *string           `json:"posted_date,omitempty"`
	Amount                   *apitypes.Money   `json:"amount,omitempty"`
	Direction                *string           `json:"direction,omitempty" enum:"inflow,outflow"`
	Description              *string           `json:"description,omitempty"`
	Reference                *string           `json:"reference,omitempty"`
	Balance                  *apitypes.Money   `json:"balance,omitempty"`
	CategoryID               *uuid.UUID        `json:"category_id,omitempty"`
	Status                   string            `json:"status" enum:"parsed,invalid,duplicate,ready,imported,skipped,failed"`
	ErrorCode                *string           `json:"error_code,omitempty" doc:"Why the row is not (or was not) imported as is (stable; localize by it). Reading: preamble, header, missing_date, bad_date, bad_amount, zero_amount, both_debit_credit, currency_mismatch. Duplicates: already_imported, possible_duplicate. Processing (status failed): invalid_date, invalid_amount, invalid_category, invalid_description, invalid_reference, invalid_row, rejected or a domain-rule code such as account_inactive. Later: reconciled, rolled_back"`
	ErrorMessage             *string           `json:"error_message,omitempty" doc:"The specific reason in English (localize by error_code)"`
	ErrorField               *string           `json:"error_field,omitempty" enum:"posted_date,amount,category_id,description" doc:"The value to correct (PATCH /imports/{id}/rows/{rowId}) for this error_code"`
	ErrorParams              map[string]string `json:"error_params,omitempty" doc:"Values error_code refers to: bad_date → format; bad_amount → currency; currency_mismatch → currency (the row's), account_currency; already_imported → matched_by (fingerprint or external_id); possible_duplicate → days_apart; a domain-rule code → its params"`
	DuplicateOfTransactionID *uuid.UUID        `json:"duplicate_of_transaction_id,omitempty"`
	DuplicateReasonCodes     []string          `json:"duplicate_reason_codes,omitempty" enum:"same_amount_direction,same_date,one_day_apart,within_3_days,within_a_week,same_reference,similar_description" doc:"possible_duplicate: why the row may repeat duplicate_of_transaction_id (the reconciliation reason codes)"`
	TransactionID            *uuid.UUID        `json:"transaction_id,omitempty"`
	UserDecision             *string           `json:"user_decision,omitempty" enum:"import,skip"`
}

// errorFields names the row value a reason points at.
var errorFields = map[string]string{
	"missing_date": "posted_date", "bad_date": "posted_date", "invalid_date": "posted_date",
	"bad_amount": "amount", "zero_amount": "amount", "both_debit_credit": "amount", "invalid_amount": "amount",
	"invalid_category": "category_id", "invalid_description": "description",
}

const rowCols = `r.id, r.row_number, r.raw, r.posted_date, r.amount_minor, r.direction, r.description, r.reference, r.balance_minor,
	r.category_id, r.status, r.error_code, r.error_message, r.error_params, r.duplicate_of_transaction_id, r.duplicate_reason_codes,
	r.transaction_id, r.user_decision, coalesce(r.currency, a.currency)`

func scanImportRow(r pgx.Row) (*ImportRowDTO, error) {
	var x ImportRowDTO
	var raw []byte
	var d *time.Time
	var amt, bal *int64
	var cur string
	if err := r.Scan(&x.ID, &x.RowNumber, &raw, &d, &amt, &x.Direction, &x.Description, &x.Reference, &bal, &x.CategoryID, &x.Status,
		&x.ErrorCode, &x.ErrorMessage, &x.ErrorParams, &x.DuplicateOfTransactionID, &x.DuplicateReasonCodes, &x.TransactionID,
		&x.UserDecision, &cur); err != nil {
		return nil, err
	}
	if x.ErrorCode != nil {
		if f, ok := errorFields[*x.ErrorCode]; ok {
			x.ErrorField = &f
		}
	}
	if len(x.ErrorParams) == 0 {
		x.ErrorParams = nil
	}
	if err := json.Unmarshal(raw, &x.Raw); err != nil {
		x.Raw = []string{}
	}
	if d != nil {
		v := finance.LocalDateString(*d)
		x.PostedDate = &v
	}
	x.Amount, x.Balance = apitypes.MP(amt, cur), apitypes.MP(bal, cur)
	return &x, nil
}

// ImportRowPage is a page of rows.
type ImportRowPage struct {
	Rows       []ImportRowDTO `json:"rows"`
	NextCursor *int32         `json:"next_cursor,omitempty" doc:"Pass as after_row for the next page"`
}

// Rows lists rows by status (keyset on row number).
func (s *Service) Rows(ctx context.Context, id uuid.UUID, status string, after int32, limit int) (*ImportRowPage, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	out := &ImportRowPage{Rows: []ImportRowDTO{}}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := s.loadBatch(ctx, tx, id, false); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select `+rowCols+` from import_rows r join import_batches b on b.id = r.batch_id
			join financial_accounts a on a.id = b.account_id where r.batch_id = $1 and ($2 = '' or r.status = $2) and r.row_number > $3
			order by r.row_number limit $4`, id, status, after, limit+1)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			x, err := scanImportRow(rows)
			if err != nil {
				return err
			}
			out.Rows = append(out.Rows, *x)
		}
		if len(out.Rows) > limit {
			out.Rows = out.Rows[:limit]
			n := out.Rows[limit-1].RowNumber
			out.NextCursor = &n
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// ImportRowUpdate is a user decision or correction for one row.
type ImportRowUpdate struct {
	Decision    string     `json:"decision,omitempty" enum:"import,skip"`
	CategoryID  *uuid.UUID `json:"category_id,omitempty"`
	PostedDate  string     `json:"posted_date,omitempty" doc:"Correction, YYYY-MM-DD"`
	Amount      string     `json:"amount,omitempty" doc:"Correction, positive decimal in the account currency"`
	Direction   string     `json:"direction,omitempty" enum:"inflow,outflow"`
	Description string     `json:"description,omitempty" maxLength:"500"`
}

// UpdateRow records a decision or correction before confirmation (or for
// failed rows before a retry).
func (s *Service) UpdateRow(ctx context.Context, batchID, rowID uuid.UUID, in ImportRowUpdate) (*ImportRowDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ImportRowDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		b, err := s.ownBatch(ctx, tx, uid, batchID)
		if err != nil {
			return err
		}
		if b.Status != "preview_ready" && b.Status != "completed_with_errors" {
			return apperr.Conflict("Rows can be changed while previewing, or after an import finished with errors.")
		}
		var status string
		var code *string
		var dateV *time.Time
		var amount *int64
		var dir, desc *string
		if err := tx.QueryRow(ctx, `select status, error_code, posted_date, amount_minor, direction, description from import_rows
			where id = $1 and batch_id = $2 for update`, rowID, batchID).Scan(&status, &code, &dateV, &amount, &dir, &desc); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("row")
			}
			return err
		}
		if status == "imported" || (b.Status == "completed_with_errors" && status != "failed") {
			return apperr.Conflict("Only rows that were not imported can be changed.")
		}
		if code != nil && *code == "already_imported" && in.Decision == "import" {
			return apperr.New(apperr.CodeDuplicate, 409, "This statement row was already imported into the account.")
		}
		if in.CategoryID != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from categories where id = $1 and user_id = $2 and status = 'active')`,
				*in.CategoryID, uid).Scan(&ok); err != nil || !ok {
				return apperr.FieldError("body.category_id", "Category not found.")
			}
		}
		corrected := in.PostedDate != "" || in.Amount != "" || in.Direction != "" || in.Description != ""
		if corrected {
			u, err := finance.LoadUser(ctx, tx, uid)
			if err != nil {
				return err
			}
			if in.PostedDate != "" {
				d, err := finance.ParseDate("body.posted_date", in.PostedDate, u.Loc)
				if err != nil {
					return err
				}
				dateV = &d
			}
			if in.Amount != "" {
				v, err := finance.ParseAmount("body.amount", in.Amount, b.Currency)
				if err != nil {
					return err
				}
				amount = &v
			}
			if in.Direction != "" {
				dir = &in.Direction
			}
			if strings.TrimSpace(in.Description) != "" {
				d := strings.TrimSpace(in.Description)
				desc = &d
			}
			if dateV == nil || amount == nil || dir == nil {
				return apperr.Validation("A corrected row needs a date, an amount and a direction.")
			}
			r := statement.Row{Date: *dateV, AmountMinor: *amount, Direction: *dir}
			if desc != nil {
				r.Description = *desc
			}
			var rowNum int
			if err := tx.QueryRow(ctx, `select row_number from import_rows where id = $1`, rowID).Scan(&rowNum); err != nil {
				return err
			}
			fp := statement.Fingerprint(b.AccountID.String(), r, 100000+rowNum) // corrected rows never collide with file rows
			status = "ready"
			if _, err := tx.Exec(ctx, `update import_rows set posted_date = $2, amount_minor = $3, direction = $4, description = $5,
				fingerprint = $6, status = 'ready', error_code = null, error_message = null, error_params = null, duplicate_of_transaction_id = null,
				duplicate_reason_codes = null where id = $1`,
				rowID, *dateV, *amount, *dir, desc, fp); err != nil {
				return err
			}
		} else if status == "invalid" && in.Decision == "import" {
			return apperr.Rule("row_invalid", "Correct the row (date, amount, direction) before importing it.", nil)
		}
		if in.Decision != "" || in.CategoryID != nil {
			if _, err := tx.Exec(ctx, `update import_rows set user_decision = coalesce(nullif($2, ''), user_decision),
				category_id = coalesce($3, category_id) where id = $1`, rowID, in.Decision, in.CategoryID); err != nil {
				return err
			}
		}
		if status == "failed" && (corrected || in.Decision == "import") {
			if _, err := tx.Exec(ctx, `update import_rows set status = 'ready', error_code = null, error_message = null, error_params = null
				where id = $1`, rowID); err != nil {
				return err
			}
		}
		if err := s.recount(ctx, tx, batchID); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "import_row", EntityID: &rowID, Action: "updated",
			Changes: map[string]any{"decision": in.Decision, "corrected": corrected}}); err != nil {
			return err
		}
		out, err = scanImportRow(tx.QueryRow(ctx, `select `+rowCols+` from import_rows r join import_batches b on b.id = r.batch_id
			join financial_accounts a on a.id = b.account_id where r.id = $1`, rowID))
		return err
	})
	return out, database.MapError(err)
}

// recount refreshes the batch counters from row states.
func (s *Service) recount(ctx context.Context, tx pgx.Tx, batchID uuid.UUID) error {
	_, err := tx.Exec(ctx, `update import_batches b set
		total_rows = c.total, valid_rows = c.valid, invalid_rows = c.invalid, duplicate_rows = c.dup,
		imported_count = c.imported, skipped_count = c.skipped, failed_count = c.failed
		from (select count(*) filter (where coalesce(error_code, '') not in ('header','preamble')) as total,
			count(*) filter (where status in ('ready','duplicate','imported','failed')) as valid,
			count(*) filter (where status = 'invalid') as invalid,
			count(*) filter (where status = 'duplicate') as dup,
			count(*) filter (where status = 'imported') as imported,
			count(*) filter (where status = 'skipped' and coalesce(error_code, '') not in ('header','preamble')) as skipped,
			count(*) filter (where status = 'failed') as failed
			from import_rows where batch_id = $1) c where b.id = $1`, batchID)
	return err
}

// ImportConfirmInput confirms an import.
type ImportConfirmInput struct {
	Version int32 `json:"version"`
}

// ConfirmIdempotent wraps Confirm with Idempotency-Key replay.
func (s *Service) ConfirmIdempotent(ctx context.Context, key string, id uuid.UUID, in ImportConfirmInput) (*ImportBatchDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out ImportBatchDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "import.confirm", struct {
			ID uuid.UUID
			In ImportConfirmInput
		}{id, in}, func() (ImportBatchDTO, error) {
			b, err := s.confirmTx(ctx, tx, uid, id, in)
			if err != nil {
				return ImportBatchDTO{}, err
			}
			return *b, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

func (s *Service) confirmTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID, in ImportConfirmInput) (*ImportBatchDTO, error) {
	b, err := s.ownBatch(ctx, tx, uid, id)
	if err != nil {
		return nil, err
	}
	if b.Version != in.Version {
		return nil, apperr.VersionConflict()
	}
	if b.Status != "preview_ready" {
		return nil, apperr.Conflict("Only a previewed import can be confirmed.")
	}
	var n int
	if err := tx.QueryRow(ctx, `select count(*) from import_rows r where r.batch_id = $1 and `+importable, id).Scan(&n); err != nil {
		return nil, err
	}
	if n == 0 {
		return nil, apperr.Rule("no_rows", "There are no rows to import.", nil)
	}
	if _, err := tx.Exec(ctx, `update import_batches set status = 'confirmed', confirmed_at = now(), version = version + 1 where id = $1`, id); err != nil {
		return nil, err
	}
	if err := enqueue(ctx, tx, JobProcess, uid, id, "confirm"); err != nil {
		return nil, err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "import_batch", EntityID: &id, Action: "confirmed",
		Changes: map[string]any{"rows": n}}); err != nil {
		return nil, err
	}
	nb, err := s.loadBatch(ctx, tx, id, false)
	if err != nil {
		return nil, err
	}
	return &nb.ImportBatchDTO, nil
}

// Cancel cancels a batch; processing stops between rows (imported rows stay
// and can be rolled back).
func (s *Service) Cancel(ctx context.Context, id uuid.UUID) (*ImportBatchDTO, error) {
	return s.transition(ctx, id, nil, func(ctx context.Context, tx pgx.Tx, _ uuid.UUID, b *batchRow) error {
		switch b.Status {
		case "processing":
			_, err := tx.Exec(ctx, `update import_batches set cancel_requested_at = now(), version = version + 1 where id = $1`, id)
			return err
		case "awaiting_upload", "uploaded", "parsing", "needs_mapping", "preview_ready", "confirmed":
			_, err := tx.Exec(ctx, `update import_batches set status = 'cancelled', cancelled_at = now(), version = version + 1 where id = $1`, id)
			return err
		}
		return apperr.Conflict("This import has already finished.")
	}, "cancelled")
}

// RetryFailed requeues failed rows.
func (s *Service) RetryFailed(ctx context.Context, id uuid.UUID) (*ImportBatchDTO, error) {
	return s.transition(ctx, id, nil, func(ctx context.Context, tx pgx.Tx, uid uuid.UUID, b *batchRow) error {
		if b.Status != "completed_with_errors" {
			return apperr.Conflict("Only imports that finished with errors can be retried.")
		}
		if _, err := tx.Exec(ctx, `update import_rows set status = 'ready', error_code = null, error_message = null, error_params = null
			where batch_id = $1 and status = 'failed'`, id); err != nil {
			return err
		}
		// Rows corrected by the user after the failure are already ready.
		var n int
		if err := tx.QueryRow(ctx, `select count(*) from import_rows r where r.batch_id = $1 and `+importable, id).Scan(&n); err != nil {
			return err
		}
		if n == 0 {
			return apperr.Conflict("There are no rows left to import.")
		}
		if _, err := tx.Exec(ctx, `update import_batches set status = 'confirmed', version = version + 1 where id = $1`, id); err != nil {
			return err
		}
		return enqueue(ctx, tx, JobProcess, uid, id, "retry:"+s.now().UTC().Format("150405.000"))
	}, "retry_failed")
}

// Rollback queues voiding of this batch's imported transactions that were
// not edited, linked or reconciled since import.
func (s *Service) Rollback(ctx context.Context, id uuid.UUID) (*ImportBatchDTO, error) {
	return s.transition(ctx, id, nil, func(ctx context.Context, tx pgx.Tx, uid uuid.UUID, b *batchRow) error {
		switch b.Status {
		case "completed", "completed_with_errors", "cancelled":
		default:
			return apperr.Conflict("Only finished or cancelled imports can be rolled back.")
		}
		if b.ImportedCount == 0 {
			return apperr.Conflict("Nothing was imported.")
		}
		if _, err := tx.Exec(ctx, `update import_batches set status = 'processing', version = version + 1 where id = $1`, id); err != nil {
			return err
		}
		return enqueue(ctx, tx, JobRollback, uid, id, "rollback")
	}, "rollback_requested")
}

func (s *Service) transition(ctx context.Context, id uuid.UUID, version *int32,
	fn func(context.Context, pgx.Tx, uuid.UUID, *batchRow) error, action string) (*ImportBatchDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ImportBatchDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		b, err := s.ownBatch(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if version != nil && *version != b.Version {
			return apperr.VersionConflict()
		}
		if err := fn(ctx, tx, uid, b); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "import_batch", EntityID: &id, Action: action}); err != nil {
			return err
		}
		nb, err := s.loadBatch(ctx, tx, id, false)
		if err != nil {
			return err
		}
		out = &nb.ImportBatchDTO
		return nil
	})
	return out, database.MapError(err)
}

// normalizeBatch derives row values from the mapping, flags exact and
// probable duplicates, and stores totals (worker scope).
func (s *Service) normalizeBatch(ctx context.Context, tx pgx.Tx, b *batchRow) error {
	rows, err := tx.Query(ctx, `select id, row_number, raw from import_rows where batch_id = $1 order by row_number`, b.ID)
	if err != nil {
		return err
	}
	type rec struct {
		id    uuid.UUID
		num   int
		cells []string
	}
	recs, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (rec, error) {
		var x rec
		var raw []byte
		if err := r.Scan(&x.id, &x.num, &raw); err != nil {
			return x, err
		}
		err := json.Unmarshal(raw, &x.cells)
		return x, err
	})
	if err != nil {
		return err
	}
	m := b.mapping
	headerLine := -1
	if m.HeaderRow >= 0 {
		// Rows are stored with their source line; the header is the
		// (HeaderRow+1)-th stored row.
		if m.HeaderRow < len(recs) {
			headerLine = recs[m.HeaderRow].num
		}
	}
	type out struct {
		status, code, msg string
		params            map[string]string
		row               statement.Row
		fp                string
		dup               *uuid.UUID
		dupReasons        []string
	}
	results := make([]out, len(recs))
	occurrences := map[string]int{}
	var valid []statement.NumberedRow
	var fps, extIDs []string
	for i, r := range recs {
		switch {
		case r.num < headerLine:
			results[i] = out{status: "skipped", code: "preamble", msg: "Text before the header row."}
			continue
		case r.num == headerLine:
			results[i] = out{status: "skipped", code: "header", msg: "Header row."}
			continue
		}
		nr, rerr := statement.Normalize(r.cells, m, b.Currency)
		if rerr != nil {
			results[i] = out{status: "invalid", code: rerr.Code, msg: rerr.Message, params: rerr.Params}
			continue
		}
		base := statement.Fingerprint(b.AccountID.String(), nr, 0)
		occ := occurrences[base]
		occurrences[base]++
		fp := statement.Fingerprint(b.AccountID.String(), nr, occ)
		results[i] = out{status: "ready", row: nr, fp: fp}
		valid = append(valid, statement.NumberedRow{Number: r.num, Row: nr})
		fps = append(fps, fp)
		if nr.ExternalID != "" {
			extIDs = append(extIDs, nr.ExternalID)
		}
	}
	// Exact duplicates: same fingerprint or bank transaction ID already in the account.
	exact := map[string]uuid.UUID{}
	ext := map[string]uuid.UUID{}
	if len(fps) > 0 {
		erows, err := tx.Query(ctx, `select source_fingerprint, id from transactions where account_id = $1 and deleted_at is null
			and source_fingerprint = any($2)`, b.AccountID, fps)
		if err != nil {
			return err
		}
		for erows.Next() {
			var fp string
			var id uuid.UUID
			if err := erows.Scan(&fp, &id); err != nil {
				erows.Close()
				return err
			}
			exact[fp] = id
		}
		erows.Close()
	}
	if len(extIDs) > 0 {
		erows, err := tx.Query(ctx, `select external_id, id from transactions where account_id = $1 and deleted_at is null
			and external_id = any($2)`, b.AccountID, extIDs)
		if err != nil {
			return err
		}
		for erows.Next() {
			var e string
			var id uuid.UUID
			if err := erows.Scan(&e, &id); err != nil {
				erows.Close()
				return err
			}
			ext[e] = id
		}
		erows.Close()
	}
	claimed := map[uuid.UUID]bool{}
	var probe []reconcile.Item
	probeIdx := map[string]int{}
	for i := range results {
		x := &results[i]
		if x.status != "ready" {
			continue
		}
		if id, ok := exact[x.fp]; ok {
			x.status, x.code, x.msg, x.dup = "duplicate", "already_imported", "This row was already imported into the account.", &id
			x.params = map[string]string{"matched_by": "fingerprint"}
			claimed[id] = true
			continue
		}
		if x.row.ExternalID != "" {
			if id, ok := ext[x.row.ExternalID]; ok {
				x.status, x.code, x.msg, x.dup = "duplicate", "already_imported", "A transaction with this bank ID already exists.", &id
				x.params = map[string]string{"matched_by": "external_id"}
				claimed[id] = true
				continue
			}
		}
		key := recs[i].id.String()
		probeIdx[key] = i
		probe = append(probe, reconcile.Item{ID: key, Date: x.row.Date, AmountMinor: x.row.AmountMinor, Direction: x.row.Direction,
			Description: x.row.Description, Reference: x.row.Reference})
	}
	// Probable duplicates: existing transactions (manual, other imports) with
	// the same amount and direction close in date.
	if len(probe) > 0 && len(valid) > 0 {
		lo, hi := valid[0].Row.Date, valid[0].Row.Date
		for _, v := range valid {
			if v.Row.Date.Before(lo) {
				lo = v.Row.Date
			}
			if v.Row.Date.After(hi) {
				hi = v.Row.Date
			}
		}
		trows, err := tx.Query(ctx, `select t.id, t.local_date, t.amount_minor, t.direction, coalesce(t.description, ''), coalesce(m.name, '')
			from transactions t left join merchants m on m.id = t.merchant_id
			where t.account_id = $1 and t.deleted_at is null and t.status <> 'voided' and t.local_date between $2::date - 7 and $3::date + 7
			and t.type not in ('opening_balance','adjustment')`, b.AccountID, lo, hi)
		if err != nil {
			return err
		}
		var existing []reconcile.Item
		for trows.Next() {
			var id uuid.UUID
			var d time.Time
			var amt int64
			var dir, desc, merch string
			if err := trows.Scan(&id, &d, &amt, &dir, &desc, &merch); err != nil {
				trows.Close()
				return err
			}
			if claimed[id] {
				continue
			}
			existing = append(existing, reconcile.Item{ID: id.String(), Date: d, AmountMinor: amt, Direction: dir,
				Description: strings.TrimSpace(merch + " " + desc)})
		}
		trows.Close()
		for _, c := range reconcile.BestOneToOne(probe, existing, duplicateMinScore) {
			i := probeIdx[c.Left.ID]
			id := uuid.MustParse(c.Right[0].ID)
			results[i].status, results[i].code = "duplicate", "possible_duplicate"
			results[i].msg = "Possible duplicate of an existing transaction (" + strings.Join(reconcile.Texts(c.Reasons), ", ") + ")."
			results[i].params = map[string]string{"days_apart": strconv.Itoa(c.DaysApart)}
			results[i].dup, results[i].dupReasons = &id, reconcile.Codes(c.Reasons)
		}
	}
	// Bulk update.
	n := len(recs)
	ids := make([]uuid.UUID, n)
	status := make([]string, n)
	codes, msgs, dates, dirs, descs, refs, fpsOut, extOut := make([]*string, n), make([]*string, n), make([]*string, n), make([]*string, n),
		make([]*string, n), make([]*string, n), make([]*string, n), make([]*string, n)
	amts, bals := make([]*int64, n), make([]*int64, n)
	dups := make([]*uuid.UUID, n)
	params, dupReasons := make([]*string, n), make([]*string, n)
	str := func(v string) *string {
		if v == "" {
			return nil
		}
		return &v
	}
	for i, r := range recs {
		x := results[i]
		ids[i], status[i] = r.id, x.status
		codes[i], msgs[i] = str(x.code), str(x.msg)
		pj, err := paramsJSON(x.params)
		if err != nil {
			return err
		}
		params[i] = pj
		if x.status == "ready" || x.status == "duplicate" {
			d := x.row.Date.Format("2006-01-02")
			amt := x.row.AmountMinor
			dates[i], amts[i], dirs[i] = &d, &amt, str(x.row.Direction)
			descs[i], refs[i], fpsOut[i], extOut[i], bals[i] = str(x.row.Description), str(x.row.Reference), str(x.fp), str(x.row.ExternalID), x.row.Balance
			dups[i], dupReasons[i] = x.dup, str(strings.Join(x.dupReasons, ","))
		}
	}
	if _, err := tx.Exec(ctx, `update import_rows r set status = v.status, error_code = v.code, error_message = v.msg,
		error_params = v.params::jsonb, posted_date = v.d::date, amount_minor = v.amt, direction = v.dir, description = v.descr,
		reference = v.ref, balance_minor = v.bal, fingerprint = v.fp, external_id = v.ext, duplicate_of_transaction_id = v.dup,
		duplicate_reason_codes = string_to_array(v.drc, ','), currency = $14, user_decision = null, transaction_id = null
		from (select unnest($1::uuid[]) id, unnest($2::text[]) status, unnest($3::text[]) code, unnest($4::text[]) msg, unnest($5::text[]) d,
			unnest($6::bigint[]) amt, unnest($7::text[]) dir, unnest($8::text[]) descr, unnest($9::text[]) ref, unnest($10::bigint[]) bal,
			unnest($11::text[]) fp, unnest($12::text[]) ext, unnest($13::uuid[]) dup, unnest($15::text[]) params, unnest($16::text[]) drc) v
		where r.id = v.id and r.status <> 'imported'`, ids, status, codes, msgs, dates, amts, dirs, descs, refs, bals, fpsOut, extOut, dups,
		b.Currency, params, dupReasons); err != nil {
		return err
	}
	totals, err := statement.ComputeTotals(valid)
	if err != nil {
		return err
	}
	tj, err := json.Marshal(totals)
	if err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `update import_batches set totals_check = $2, status = 'preview_ready',
		statement_start_date = coalesce(statement_start_date, nullif($3, '')::date), statement_end_date = coalesce(statement_end_date, nullif($4, '')::date),
		statement_opening_balance_minor = coalesce(statement_opening_balance_minor, $5),
		statement_closing_balance_minor = coalesce(statement_closing_balance_minor, $6), error_code = null, error_message = null,
		error_params = null where id = $1`,
		b.ID, tj, totals.FirstDate, totals.LastDate, totals.OpeningBalance, totals.ClosingBalance); err != nil {
		return err
	}
	return s.recount(ctx, tx, b.ID)
}

// paramsJSON encodes the values a reason code refers to (nil when none), for
// a jsonb parameter.
func paramsJSON(p map[string]string) (*string, error) {
	if len(p) == 0 {
		return nil, nil
	}
	b, err := json.Marshal(p)
	if err != nil {
		return nil, err
	}
	v := string(b)
	return &v, nil
}

// moneyOf parses a statement-level balance ("10701.50") in the currency.
func moneyOf(s, cur string) *int64 {
	if s == "" {
		return nil
	}
	v, err := money.Parse(s, cur, money.ParseOptions{AllowNegative: true, AllowZero: true})
	if err != nil {
		return nil
	}
	return &v
}
