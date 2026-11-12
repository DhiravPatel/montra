package receipts

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
)

// RegisterJobs registers the extraction job.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobExtract, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ReceiptID uuid.UUID `json:"receipt_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.extract(ctx, p.ReceiptID)
	}, jobs.WithTimeout(2*time.Minute), jobs.WithConcurrency(2))
}

// extract reads the pages, stores a new extraction version with candidate
// values and confidences, and moves the receipt to needs_review. Extraction
// never confirms values or touches the ledger.
func (s *Service) extract(ctx context.Context, id uuid.UUID) error {
	var owner uuid.UUID
	var pages []Page
	var baseCurrency string
	proceed, consentMissing := false, false
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx, `select user_id, status from receipts where id = $1`, id).Scan(&owner, &status); err != nil {
			if database.IsNoRows(err) {
				return nil
			}
			return err
		}
		if status != "processing" {
			return nil
		}
		if err := tx.QueryRow(ctx, `select base_currency from user_preferences where user_id = $1`, owner).Scan(&baseCurrency); err != nil {
			return err
		}
		if s.externalExtraction() {
			ok, err := receiptConsent(ctx, tx, owner)
			if err != nil {
				return err
			}
			if !ok {
				consentMissing = true
				return nil
			}
		}
		rows, err := tx.Query(ctx, `select file_id from receipt_files where receipt_id = $1 order by page_no limit $2`, id, maxPages)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, fid := range ids {
			data, f, err := s.Files.ReadOwned(ctx, tx, fid, owner, "receipt", maxPageBytes)
			if err != nil {
				return err
			}
			mime := ""
			if f.ContentType != nil {
				mime = *f.ContentType
			}
			pages = append(pages, Page{MIME: mime, Data: data})
		}
		proceed = true
		return nil
	})
	if err != nil {
		var ae *apperr.Error
		if errors.As(err, &ae) && ae.Status < 500 {
			return s.store(ctx, id, owner, nil, "file_unavailable", baseCurrency)
		}
		return err
	}
	if consentMissing {
		// Consent was withdrawn after upload: nothing leaves Montra.
		return s.store(ctx, id, owner, nil, "consent_required", baseCurrency)
	}
	if !proceed {
		return nil
	}
	ex := s.extractor()
	if !ex.Configured() {
		return s.store(ctx, id, owner, nil, "extractor_not_configured", baseCurrency)
	}
	cctx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	// The owner's identity lets the extractor attribute usage accounting.
	res, xerr := ex.Extract(identity.With(cctx, identity.Principal{UserID: owner}), pages)
	if xerr != nil {
		code := "provider_error"
		if errors.Is(xerr, context.DeadlineExceeded) {
			code = "timeout"
		}
		return s.store(ctx, id, owner, nil, code, baseCurrency)
	}
	return s.store(ctx, id, owner, res, "", baseCurrency)
}

func conf(v float64) float64 {
	switch {
	case v < 0:
		return 0
	case v > 1:
		return 1
	}
	return v
}

// failureText explains a reading that produced no values; the code is
// stored as the extraction's error_code and as its warning code.
var failureText = map[string]string{
	"extractor_not_configured": "Automatic reading is not configured; enter the details yourself.",
	"consent_required":         "Automatic reading needs your AI permission (Settings → AI); enter the details yourself.",
	"file_unavailable":         "The receipt file could not be read; enter the details or upload it again.",
	"timeout":                  "Reading the receipt took too long; try again or enter the details yourself.",
	"provider_error":           "The receipt could not be read automatically; try again or enter the details yourself.",
}

// store persists an extraction version (succeeded or failed). Results only
// apply to a receipt still waiting for them: one discarded (and perhaps
// restored and reviewed) while it was being read keeps its own values.
func (s *Service) store(ctx context.Context, id, owner uuid.UUID, r *Extracted, failCode, baseCurrency string) error {
	method, provider, model, version := s.extractor().Info()
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx, `select status from receipts where id = $1 for update`, id).Scan(&status); err != nil {
			if database.IsNoRows(err) {
				return nil
			}
			return err
		}
		if status != "processing" {
			return nil
		}
		var next int32
		if err := tx.QueryRow(ctx, `select coalesce(max(version), 0) + 1 from receipt_extractions where receipt_id = $1`, id).Scan(&next); err != nil {
			return err
		}
		eid := uuid.New()
		nilIfEmpty := func(v string) *string {
			if v == "" {
				return nil
			}
			return &v
		}
		if r == nil {
			text, ok := failureText[failCode]
			if !ok {
				text = failureText["provider_error"]
			}
			texts, codes, params, err := warningColumns([]warning{{Code: failCode, Text: text}})
			if err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `insert into receipt_extractions (id, receipt_id, user_id, version, method, provider, model, extractor_version,
				status, warnings, warning_codes, warning_params, error_code, completed_at) values ($1,$2,$3,$4,$5,$6,$7,$8,'failed',$9,$10,$11,$12,now())`,
				eid, id, owner, next, method, nilIfEmpty(provider), nilIfEmpty(model), version, texts, codes, params, failCode); err != nil {
				return err
			}
			// The current values (if any) are unchanged, so the receipt
			// returns to the status they give it.
			_, err = tx.Exec(ctx, `update receipts set status = `+settledStatus+` where id = $1`, id)
			return err
		}
		cur := strings.ToUpper(strings.TrimSpace(r.Currency))
		var warnings []warning
		for _, w := range r.Warnings {
			if w = strings.TrimSpace(w); w != "" {
				warnings = append(warnings, warning{Code: "reader_note", Text: w})
			}
		}
		if !currency.Valid(cur) {
			if cur != "" {
				warnings = append(warnings, warning{Code: "currency_unrecognized", Text: "The currency on the receipt was not recognized; check it."})
			}
			cur = baseCurrency
		}
		amount := func(v string) *int64 {
			if strings.TrimSpace(v) == "" {
				return nil
			}
			x, err := money.Parse(strings.TrimSpace(v), cur, money.ParseOptions{AllowZero: true})
			if err != nil {
				shown := clipStr(v, 30)
				warnings = append(warnings, warning{Code: "amount_unreadable", Text: "An amount could not be read: " + shown,
					Params: map[string]string{"value": shown}})
				return nil
			}
			return &x
		}
		sub, tax, tip, disc, total := amount(r.Subtotal), amount(r.Tax), amount(r.Tip), amount(r.Discount), amount(r.Total)
		warnings = append(warnings, arithmeticWarnings(sub, tax, tip, disc, total)...)
		var date *time.Time
		if d, err := time.Parse("2006-01-02", strings.TrimSpace(r.Date)); err == nil {
			date = &d
		} else if r.Date != "" {
			warnings = append(warnings, warning{Code: "date_unreadable", Text: "The date could not be read; check it."})
		}
		var tm *string
		if t, err := time.Parse("15:04", strings.TrimSpace(r.Time)); err == nil {
			v := t.Format("15:04")
			tm = &v
		}
		fc := map[string]float64{}
		for k, v := range r.FieldConfidence {
			fc[k] = conf(v)
		}
		cj, err := json.Marshal(fc)
		if err != nil {
			return err
		}
		// Line amounts are parsed before the warnings are stored, so their
		// warnings are included.
		type line struct {
			unit, amt, tax *int64
		}
		lines := make([]line, 0, len(r.LineItems))
		for i, l := range r.LineItems {
			if i >= 500 {
				break
			}
			lines = append(lines, line{amount(l.UnitPrice), amount(l.Amount), amount(l.Tax)})
		}
		texts, codes, params, err := warningColumns(warnings)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into receipt_extractions (id, receipt_id, user_id, version, method, provider, model, extractor_version, status,
			merchant_name, receipt_date, receipt_time, currency, subtotal_minor, tax_minor, tip_minor, discount_minor, total_minor, payment_hint,
			receipt_number, field_confidence, overall_confidence, warnings, warning_codes, warning_params, completed_at)
			values ($1,$2,$3,$4,$5,$6,$7,$8,'succeeded',$9,$10,$11::time,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,now())`,
			eid, id, owner, next, method, nilIfEmpty(provider), nilIfEmpty(model), version, trim(r.MerchantName, 200), date, tm, cur, sub, tax, tip, disc,
			total, trim(maskPAN(r.PaymentHint), 60), trim(r.ReceiptNumber, 80), cj, conf(r.Overall), texts, codes, params); err != nil {
			return err
		}
		for i, l := range lines {
			src := r.LineItems[i]
			var q *string
			if v := strings.TrimSpace(src.Quantity); v != "" && len(v) <= 13 {
				q = &v
			}
			if _, err := tx.Exec(ctx, `insert into receipt_line_items (extraction_id, user_id, position, description, quantity, unit_price_minor,
				amount_minor, tax_minor, confidence) values ($1,$2,$3,$4,$5::numeric,$6,$7,$8,$9)`, eid, owner, i+1, trim(src.Description, 200), q,
				l.unit, l.amt, l.tax, conf(src.Confidence)); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `update receipts set current_extraction_id = $2, status = 'needs_review' where id = $1`, id, eid); err != nil {
			return err
		}
		if date != nil && total != nil {
			if err := s.flagDuplicate(ctx, tx, owner, id, *date, *total, cur, r.MerchantName); err != nil {
				return err
			}
		}
		_, _, err = notifications.Create(ctx, tx, notifications.Notification{UserID: owner, Category: "receipt", EventType: "receipt_ready",
			Title: "Receipt ready to review", Body: "Check the details before saving.", DeepLink: "/receipts/" + id.String(), EntityType: "receipt",
			EntityID: &id, DedupeKey: "receipt_ready:" + eid.String()})
		return err
	})
}

func clipStr(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n])
	}
	return s
}
