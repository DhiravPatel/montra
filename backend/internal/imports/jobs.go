package imports

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/statement"
	"montra/backend/internal/finance"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/subscriptions"
)

func enqueue(ctx context.Context, tx pgx.Tx, jobType string, uid, batchID uuid.UUID, salt string) error {
	_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: jobType, UserID: &uid, Payload: map[string]any{"batch_id": batchID},
		DedupeKey: fmt.Sprintf("%s:%s:%s", jobType, batchID, salt), Priority: 90, MaxAttempts: 5})
	return err
}

type jobPayload struct {
	BatchID uuid.UUID `json:"batch_id"`
}

// RegisterJobs registers the import pipeline jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	handler := func(fn func(context.Context, uuid.UUID) error) jobs.HandlerFunc {
		return func(ctx context.Context, j jobs.Job) error {
			var p jobPayload
			if err := j.Decode(&p); err != nil {
				return jobs.Permanent(err)
			}
			return fn(ctx, p.BatchID)
		}
	}
	reg.Register(JobParse, handler(s.parse), jobs.WithTimeout(3*time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobNormalize, handler(s.normalize), jobs.WithTimeout(3*time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobProcess, handler(s.process), jobs.WithTimeout(15*time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobRollback, handler(s.rollback), jobs.WithTimeout(15*time.Minute), jobs.WithConcurrency(1))
}

func (s *Service) failBatch(ctx context.Context, id uuid.UUID, code, msg string) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `update import_batches set status = 'failed', error_code = $2, error_message = left($3, 500), error_params = null
			where id = $1`, id, code, msg)
		return err
	})
}

// parse reads the stored file, parses it under resource limits, stores raw
// rows and applies the suggested mapping when it is complete.
func (s *Service) parse(ctx context.Context, id uuid.UUID) error {
	var b *batchRow
	var data []byte
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var err error
		if b, err = s.loadBatch(ctx, tx, id, true); err != nil {
			return err
		}
		// 'parsing' means an earlier attempt was interrupted: parsing is
		// re-runnable (rows not yet imported are replaced).
		if b.Status != "uploaded" && b.Status != "parsing" {
			b = nil
			return nil // already parsed or cancelled
		}
		if b.FileID == nil {
			return apperr.Conflict("missing file")
		}
		data, _, err = s.Files.ReadOwned(ctx, tx, *b.FileID, b.userID, "statement_import", maxFileBytes)
		return err
	})
	if err != nil {
		var ae *apperr.Error
		if errors.As(err, &ae) && ae.Status < 500 {
			return s.failBatch(ctx, id, "file_unavailable", ae.Message)
		}
		return err
	}
	if b == nil || data == nil {
		return nil
	}
	format := ""
	if b.SourceFormat != nil {
		format = *b.SourceFormat
	}
	var t *statement.Table
	var perr error
	if format == "pdf" {
		// Re-checked at processing time: consent may have been withdrawn.
		allowed := false
		if s.PDF != nil && s.PDF.Configured() {
			if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
				var err error
				allowed, err = pdfAllowed(ctx, tx, b.userID)
				return err
			}); err != nil {
				return err
			}
		}
		if !allowed {
			return s.failBatch(ctx, id, "pdf_needs_ai", "AI reading of PDF statements is off, so this PDF was not read. Nothing left Montra.")
		}
		t, perr = s.PDF.ReadStatement(identity.With(ctx, identity.Principal{UserID: b.userID}), data)
		if perr != nil {
			return s.failBatch(ctx, id, "pdf_unreadable", "This PDF could not be read reliably. Export CSV, XLSX or OFX from your bank instead.")
		}
		return s.storeParsed(ctx, id, b, t, []statement.Note{{Code: NotePDFReadByAI,
			Text: "Read by AI from a PDF: check every row, date and amount before confirming."}})
	}
	t, perr = statement.Parse(data, format, statement.DefaultLimits)
	if perr != nil {
		var se *statement.Error
		if errors.As(perr, &se) {
			return s.failBatch(ctx, id, se.Code, se.Message)
		}
		return s.failBatch(ctx, id, "malformed", "The file could not be read.")
	}
	return s.storeParsed(ctx, id, b, t, nil)
}

// NotePDFReadByAI is the mapping note code of statements read from a PDF.
const NotePDFReadByAI = "pdf_read_by_ai"

// storeParsed stores parsed rows, applies the suggested mapping and, when
// complete, normalizes the batch.
func (s *Service) storeParsed(ctx context.Context, id uuid.UUID, b *batchRow, t *statement.Table, extraNotes []statement.Note) error {
	sg := statement.Suggest(t)
	// Never nil: mapping_notes and mapping_note_codes are NOT NULL. Codes
	// keep the order of the English notes; each code appears once, so its
	// values share one map.
	notes := append(append(make([]statement.Note, 0, len(extraNotes)+len(sg.Notes)), extraNotes...), sg.Notes...)
	texts, codes, params := make([]string, 0, len(notes)), make([]string, 0, len(notes)), map[string]string{}
	for _, n := range notes {
		texts, codes = append(texts, n.Text), append(codes, n.Code)
		maps.Copy(params, n.Params)
	}
	noteParams, err := json.Marshal(params)
	if err != nil {
		return err
	}
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx, `select status from import_batches where id = $1 for update`, id).Scan(&status); err != nil {
			return err
		}
		if status != "uploaded" && status != "parsing" {
			return nil // cancelled meanwhile
		}
		if _, err := tx.Exec(ctx, `delete from import_rows where batch_id = $1 and status <> 'imported'`, id); err != nil {
			return err
		}
		// Bulk insert in chunks (COPY is not allowed on RLS-protected tables).
		ids := make([]uuid.UUID, 0, len(t.Rows))
		nums := make([]int32, 0, len(t.Rows))
		raws := make([]string, 0, len(t.Rows))
		for i, cells := range t.Rows {
			raw, err := json.Marshal(cells)
			if err != nil {
				return err
			}
			num := i + 1
			if t.Format != "ofx" && i < len(t.Source) && t.Source[i] > 0 {
				num = t.Source[i]
			}
			ids, nums, raws = append(ids, uuid.New()), append(nums, int32(num)), append(raws, string(raw))
		}
		for lo := 0; lo < len(ids); lo += 1000 {
			hi := min(lo+1000, len(ids))
			if _, err := tx.Exec(ctx, `insert into import_rows (id, batch_id, user_id, row_number, raw, status)
				select u.id, $1, $2, u.n, u.raw::jsonb, 'parsed' from unnest($3::uuid[], $4::int[], $5::text[]) as u(id, n, raw)`,
				id, b.userID, ids[lo:hi], nums[lo:hi], raws[lo:hi]); err != nil {
				return err
			}
		}
		var header []string
		if t.HeaderRow >= 0 && t.HeaderRow < len(t.Rows) {
			header = t.Rows[t.HeaderRow]
		}
		mapping, err := json.Marshal(sg.Mapping)
		if err != nil {
			return err
		}
		var start, end, closing any
		if t.Statement != nil {
			if t.Statement.Currency != "" && t.Statement.Currency != b.Currency {
				pj, err := paramsJSON(map[string]string{"statement_currency": t.Statement.Currency, "account_currency": b.Currency})
				if err != nil {
					return err
				}
				_, err = tx.Exec(ctx, `update import_batches set status = 'failed', error_code = 'currency_mismatch',
					error_message = $2, error_params = $3::jsonb where id = $1`, id,
					"The statement is in "+t.Statement.Currency+" but the account is in "+b.Currency+".", pj)
				return err
			}
			start, end = nullIfEmpty(t.Statement.Start), nullIfEmpty(t.Statement.End)
			closing = moneyOf(t.Statement.ClosingBalance, b.Currency)
		}
		status = "needs_mapping"
		if _, err := tx.Exec(ctx, `update import_batches set status = $2, parser_version = $3, detected_encoding = $4, header_row = $5,
			mapping = $6, mapping_notes = $7, statement_start_date = $8::date, statement_end_date = $9::date,
			statement_closing_balance_minor = $10, mapping_note_codes = $11, mapping_note_params = $12::jsonb where id = $1`, id, status,
			t.ParserVersion, t.Encoding, header, mapping, texts, start, end, closing, codes, string(noteParams)); err != nil {
			return err
		}
		if !sg.Complete {
			return nil
		}
		nb, err := s.loadBatch(ctx, tx, id, true)
		if err != nil {
			return err
		}
		return s.normalizeBatch(ctx, tx, nb)
	})
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// normalize applies the stored mapping (queued by SetMapping).
func (s *Service) normalize(ctx context.Context, id uuid.UUID) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		b, err := s.loadBatch(ctx, tx, id, true)
		if err != nil {
			return err
		}
		if b.Status != "parsing" || !b.hasMapping {
			return nil
		}
		return s.normalizeBatch(ctx, tx, b)
	})
}

// process creates one transaction per confirmed row, each in its own
// database transaction with the row locked, so retries and concurrent
// workers never import a row twice (the unique account fingerprint index
// is the final guard).
func (s *Service) process(ctx context.Context, id uuid.UUID) error {
	var b *batchRow
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var err error
		if b, err = s.loadBatch(ctx, tx, id, true); err != nil {
			return err
		}
		if b.Status != "confirmed" && b.Status != "processing" {
			b = nil
			return nil
		}
		if _, err := tx.Exec(ctx, `update import_batches set status = 'processing' where id = $1`, id); err != nil {
			return err
		}
		// Rows the user chose to skip, and duplicates not explicitly imported.
		_, err = tx.Exec(ctx, `update import_rows set status = 'skipped' where batch_id = $1 and
			((status = 'ready' and user_decision = 'skip') or (status = 'duplicate' and coalesce(user_decision, 'skip') = 'skip'))`, id)
		return err
	}); err != nil || b == nil {
		return err
	}
	cancelled := false
	for !cancelled {
		var ids []uuid.UUID
		if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			var req *time.Time
			if err := tx.QueryRow(ctx, `select cancel_requested_at from import_batches where id = $1`, id).Scan(&req); err != nil {
				return err
			}
			if req != nil {
				cancelled = true
				return nil
			}
			rows, err := tx.Query(ctx, `select r.id from import_rows r where r.batch_id = $1 and `+importable+`
				order by r.row_number limit 100`, id)
			if err != nil {
				return err
			}
			ids, err = pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
			return err
		}); err != nil {
			return err
		}
		if cancelled || len(ids) == 0 {
			break
		}
		for _, rid := range ids {
			if err := s.importRow(ctx, b, rid); err != nil {
				return err
			}
		}
	}
	return s.finish(ctx, b, cancelled)
}

func (s *Service) importRow(ctx context.Context, b *batchRow, rowID uuid.UUID) error {
	var rowErr *failure
	outcome := ""
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		outcome, rowErr = "", nil
		var d time.Time
		var amount int64
		var dir string
		var desc, ref, fp, ext *string
		var cat *uuid.UUID
		err := tx.QueryRow(ctx, `select r.posted_date, r.amount_minor, r.direction, r.description, r.reference, r.fingerprint, r.external_id,
			r.category_id from import_rows r where r.id = $1 and `+importable+` for update skip locked`, rowID).
			Scan(&d, &amount, &dir, &desc, &ref, &fp, &ext, &cat)
		if database.IsNoRows(err) {
			return nil // handled by another worker or no longer importable
		}
		if err != nil {
			return err
		}
		in := finance.TransactionInput{Type: "expense", AccountID: b.AccountID, Amount: apitypes.M(amount, b.Currency).Amount,
			LocalDate: finance.LocalDateString(d), CategoryID: cat}
		if dir == "inflow" {
			in.Type = "income"
		}
		if desc != nil {
			in.Description = *desc
		}
		if ref != nil && *ref != "" {
			in.Notes = "Statement reference: " + *ref
		}
		rid := rowID
		prov := &finance.Provenance{ImportRowID: &rid, ExternalID: ext, Fingerprint: fp, ActorKind: "import"}
		sp, err := tx.Begin(ctx)
		if err != nil {
			return err
		}
		txID, cerr := s.Finance.CreateInTx(ctx, sp, b.userID, in, "import", prov)
		if cerr != nil {
			_ = sp.Rollback(ctx)
			f, ok := rowFailure(cerr)
			if !ok {
				return cerr // infrastructure: the job retries
			}
			rowErr, outcome = &f, f.status
			pj, err := paramsJSON(f.params)
			if err != nil {
				return err
			}
			var dupOf *uuid.UUID
			if f.status == "duplicate" {
				// Link the transaction the row repeats.
				if err := tx.QueryRow(ctx, `select id from transactions where account_id = $1 and deleted_at is null
					and (source_fingerprint = $2 or external_id = $3) order by created_at limit 1`, b.AccountID, fp, ext).Scan(&dupOf); err != nil &&
					!database.IsNoRows(err) {
					return err
				}
			}
			// The new reason replaces any possible_duplicate explanation. A row
			// that turned out to be imported already is no longer importable,
			// even when the user chose to import it.
			_, err = tx.Exec(ctx, `update import_rows set status = $2, error_code = $3, error_message = left($4, 300), error_params = $5::jsonb,
				duplicate_of_transaction_id = coalesce($6, duplicate_of_transaction_id), duplicate_reason_codes = null,
				user_decision = case when $2 = 'duplicate' then null else user_decision end where id = $1`,
				rowID, f.status, f.code, f.message, pj, dupOf)
			return err
		}
		if err := sp.Commit(ctx); err != nil {
			return err
		}
		outcome = "imported"
		_, err = tx.Exec(ctx, `update import_rows set status = 'imported', transaction_id = $2, error_code = null, error_message = null,
			error_params = null where id = $1`, rowID, txID)
		return err
	})
	if err == nil && outcome != "" && s.Metrics != nil {
		s.Metrics.ImportRows.WithLabelValues(outcome).Inc()
	}
	if err == nil && rowErr != nil {
		slog.InfoContext(ctx, "import row not imported", slog.String("batch_id", b.ID.String()), slog.String("code", rowErr.code))
	}
	return err
}

// failure is why a row was not imported: a stable code with the specific
// message and the values it refers to.
type failure struct {
	status, code, message string
	params                map[string]string
}

// failureCodes name the row value behind a refused transaction field, so a
// client can point at what to correct (error_field).
var failureCodes = map[string]string{
	"body.local_date": "invalid_date", "body.occurred_at": "invalid_date", "body.amount": "invalid_amount",
	"body.category_id": "invalid_category", "body.description": "invalid_description", "body.notes": "invalid_reference",
}

// rowFailure explains why the ledger refused a row, never with the generic
// request envelope ("The request could not be processed."): field errors
// become the code of the row value to correct with the field's own message,
// domain rules keep their code and params. ok is false for infrastructure
// errors, which the job retries.
func rowFailure(err error) (f failure, ok bool) {
	if database.IsUniqueViolation(err, "transactions_source_fingerprint_key") {
		return failure{"duplicate", "already_imported", "This row was already imported into the account.",
			map[string]string{"matched_by": "fingerprint"}}, true
	}
	var ae *apperr.Error
	if !errors.As(err, &ae) || ae.Status >= 500 {
		return failure{}, false
	}
	if ae.Code == apperr.CodeDuplicate { // the ledger's only DUPLICATE here: the bank transaction ID is in the account
		return failure{"duplicate", "already_imported", "A transaction with this bank ID already exists.",
			map[string]string{"matched_by": "external_id"}}, true
	}
	f = failure{status: "failed", code: "rejected", message: ae.Message}
	if ae.Code == apperr.CodeValidation {
		f.code = "invalid_row"
	}
	if len(ae.Details) == 0 {
		return f, true
	}
	d := ae.Details[0]
	if d.Message != "" {
		f.message = d.Message
	}
	f.params = d.Params
	switch {
	case d.Code != "":
		f.code = d.Code
	case failureCodes[d.Field] != "":
		f.code = failureCodes[d.Field]
	}
	return f, true
}

// finish recounts, sets the final status and notifies the owner.
func (s *Service) finish(ctx context.Context, b *batchRow, cancelled bool) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		if err := s.recount(ctx, tx, b.ID); err != nil {
			return err
		}
		var imported, failed, skipped int
		if err := tx.QueryRow(ctx, `select imported_count, failed_count, skipped_count from import_batches where id = $1`, b.ID).
			Scan(&imported, &failed, &skipped); err != nil {
			return err
		}
		status := "completed"
		switch {
		case cancelled:
			status = "cancelled"
		case failed > 0:
			status = "completed_with_errors"
		}
		if _, err := tx.Exec(ctx, `update import_batches set status = $2, completed_at = case when $2 <> 'cancelled' then now() else completed_at end,
			cancelled_at = case when $2 = 'cancelled' then now() else cancelled_at end where id = $1`, b.ID, status); err != nil {
			return err
		}
		uid := b.userID
		if imported > 0 {
			// When statement data last reached the account (now() is this
			// batch's completed_at or cancelled_at). System bookkeeping: the
			// account's version is not bumped, so an import finishing in the
			// background never makes the owner's edit of the account conflict.
			if _, err := tx.Exec(ctx, `update financial_accounts set last_import_at = now() where id = $1 and user_id = $2`,
				b.AccountID, uid); err != nil {
				return err
			}
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, EntityType: "import_batch", EntityID: &b.ID, Action: status,
			Changes: map[string]any{"imported": imported, "failed": failed, "skipped": skipped}}); err != nil {
			return err
		}
		bid := b.ID
		title := fmt.Sprintf("Import finished: %d imported", imported)
		if failed > 0 {
			title = fmt.Sprintf("Import finished: %d imported, %d need attention", imported, failed)
		}
		if cancelled {
			title = fmt.Sprintf("Import cancelled after %d rows", imported)
		}
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "import", EventType: "import_" + status,
			Title: title, Body: "Open the import to review skipped and failed rows.", DeepLink: "/imports/" + bid.String(),
			EntityType: "import_batch", EntityID: &bid, DedupeKey: "import_done:" + bid.String() + ":" + status}); err != nil {
			return err
		}
		if imported > 0 {
			// New charges may reveal subscriptions (suggestions only).
			if _, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: subscriptions.JobDetect, UserID: &uid, Payload: map[string]any{"user_id": uid},
				DedupeKey: "subdetect:import:" + bid.String(), Priority: 180}); err != nil {
				return err
			}
		}
		return nil
	})
}

// rollback voids imported transactions that are unchanged since import
// (version 1, unreconciled, no linked refunds); edited ones are kept.
func (s *Service) rollback(ctx context.Context, id uuid.UUID) error {
	var b *batchRow
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var err error
		b, err = s.loadBatch(ctx, tx, id, false)
		return err
	}); err != nil {
		return err
	}
	var rows []struct {
		row, tx uuid.UUID
	}
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		r, err := tx.Query(ctx, `select id, transaction_id from import_rows where batch_id = $1 and status = 'imported' and transaction_id is not null`, id)
		if err != nil {
			return err
		}
		defer r.Close()
		for r.Next() {
			var x struct{ row, tx uuid.UUID }
			if err := r.Scan(&x.row, &x.tx); err != nil {
				return err
			}
			rows = append(rows, x)
		}
		return r.Err()
	}); err != nil {
		return err
	}
	voided, kept := 0, 0
	for _, x := range rows {
		err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			var version int32
			var state, status string
			var refs int
			if err := tx.QueryRow(ctx, `select t.version, t.reconciliation_state, t.status,
				(select count(*) from transactions r where r.original_transaction_id = t.id and r.deleted_at is null)
				+ (select count(*) from receipts rc where rc.transaction_id = t.id and rc.status <> 'discarded')
				from transactions t where t.id = $1 for update`, x.tx).Scan(&version, &state, &status, &refs); err != nil {
				return err
			}
			if status == "voided" {
				return nil
			}
			if version != 1 || state != "unreconciled" || refs > 0 {
				kept++
				return nil
			}
			if err := s.Finance.VoidInTx(ctx, tx, b.userID, x.tx); err != nil {
				return err
			}
			voided++
			_, err := tx.Exec(ctx, `update import_rows set status = 'skipped', error_code = 'rolled_back',
				error_message = 'Removed by rolling back this import.', error_params = null where id = $1`, x.row)
			return err
		})
		if err != nil {
			return err
		}
	}
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		if err := s.recount(ctx, tx, id); err != nil {
			return err
		}
		msg := fmt.Sprintf("Rolled back %d transactions; kept %d that were edited or linked after import.", voided, kept)
		pj, err := paramsJSON(map[string]string{"voided": strconv.Itoa(voided), "kept": strconv.Itoa(kept)})
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update import_batches set status = 'cancelled', cancelled_at = now(), error_code = 'rolled_back',
			error_message = $2, error_params = $3::jsonb where id = $1`, id, msg, pj); err != nil {
			return err
		}
		uid := b.userID
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, EntityType: "import_batch", EntityID: &id, Action: "rolled_back",
			Changes: map[string]any{"voided": voided, "kept": kept}})
	})
}
