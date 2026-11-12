// Package reports generates reproducible reports and exports (spec §4.11,
// §20B.12): a filter snapshot and the resolved dates are stored with each
// report, generation runs as a durable job (queued → running →
// completed/failed → expired), files are private, downloads use short-lived
// signed links, and every format escapes untrusted content.
package reports

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"slices"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/analytics"
	"montra/backend/internal/budgets"
	"montra/backend/internal/files"
	"montra/backend/internal/finance"
	"montra/backend/internal/goals"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/storage"
	"montra/backend/internal/subscriptions"
)

// Job types.
const (
	JobGenerate  = "reports.generate"
	JobSchedules = "reports.schedules"
)

// Limits.
const (
	MaxTransactionRows = 100_000
)

// Report error codes (ReportDTO.error_code): why a report failed.
const (
	ErrCodeUnavailable      = "reports_unavailable" // report generation is not configured here
	ErrCodeInvalid          = "report_invalid"      // the stored request no longer validates
	ErrCodeTooManyRows      = "too_many_rows"       // more than MaxTransactionRows transactions
	ErrCodePDFTooLarge      = "pdf_too_large"       // too many rows for a PDF
	ErrCodeStorage          = "storage_unavailable" // the file could not be stored on any attempt
	ErrCodeGenerationFailed = "generation_failed"   // every attempt failed for another reason
)

// Readers compute report data under the report owner's identity through
// the RLS-enforcing application role (never the worker role).
type Readers struct {
	Analytics *analytics.Service
	Budgets   *budgets.Service
	Subs      *subscriptions.Service
	Goals     *goals.Service
}

// Service implements reports.
type Service struct {
	DB      *database.DB // bookkeeping
	Files   *files.Service
	Store   storage.Store
	Cfg     *config.Config
	Readers *Readers
	Now     func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Types available now; group, trip and household reports arrive with the
// group features.
var supportedTypes = map[string]bool{"monthly_summary": true, "yearly_summary": true, "income": true, "expense": true, "cash_flow": true,
	"category": true, "merchant": true, "account": true, "budget": true, "subscription": true, "recurring": true, "goal": true, "transactions": true}

// windowed lists the report types that cover a date range. The others show
// current state (balances, budgets, subscriptions, goals, recurring rules)
// and have no window.
var windowed = map[string]bool{"monthly_summary": true, "yearly_summary": true, "income": true, "expense": true, "cash_flow": true,
	"category": true, "merchant": true, "transactions": true}

// typeSet is the transaction types an income or expense report covers: the
// same sets as /analytics/income and /analytics/expenses. Nil for the other
// report types.
func typeSet(reportType string) []string {
	switch reportType {
	case "income":
		return analytics.IncomeTypes()
	case "expense":
		return analytics.ExpenseTypes()
	}
	return nil
}

var typeSetMessages = map[string]string{
	"income":  "An income report covers income transactions only.",
	"expense": "An expense report covers expenses, group expenses, refunds and reimbursements only.",
}

// checkTypes rejects filters.types outside an income or expense report's
// type set (an income report never contains expenses). Types inside the
// set narrow the report further.
func checkTypes(reportType string, types []string, field string) error {
	set := typeSet(reportType)
	for _, t := range types {
		if set != nil && !slices.Contains(set, t) {
			return apperr.FieldError(field, typeSetMessages[reportType])
		}
	}
	return nil
}

// Filters is the stored filter snapshot.
type Filters struct {
	Range           string      `json:"range,omitempty" enum:"today,yesterday,this_week,last_week,this_month,last_month,this_year,last_year,last_7_days,last_30_days,last_90_days"`
	From            string      `json:"from,omitempty" doc:"YYYY-MM-DD (with to; overrides range)"`
	To              string      `json:"to,omitempty"`
	AccountIDs      []uuid.UUID `json:"account_ids,omitempty" maxItems:"50"`
	CategoryIDs     []uuid.UUID `json:"category_ids,omitempty" maxItems:"50"`
	MerchantIDs     []uuid.UUID `json:"merchant_ids,omitempty" maxItems:"50"`
	Tags            []string    `json:"tags,omitempty" maxItems:"20"`
	Currency        string      `json:"currency,omitempty" pattern:"^[A-Z]{3}$"`
	Types           []string    `json:"types,omitempty" maxItems:"9" doc:"Transaction types. Income reports accept only income and expense reports only expense, group_expense, refund and reimbursement (422 otherwise); without types they cover that whole set"`
	IncludePending  bool        `json:"include_pending,omitempty"`
	DisplayCurrency string      `json:"display_currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Adds converted totals with disclosed rates"`
}

func (f Filters) analytics() analytics.Filter {
	return analytics.Filter{Range: f.Range, From: f.From, To: f.To, AccountIDs: f.AccountIDs, CategoryIDs: f.CategoryIDs, MerchantIDs: f.MerchantIDs,
		Tags: f.Tags, Currency: f.Currency, Types: f.Types, IncludePending: f.IncludePending, DisplayCurrency: f.DisplayCurrency}
}

// ReportInput requests a report.
type ReportInput struct {
	ReportType string  `json:"report_type" enum:"monthly_summary,yearly_summary,income,expense,cash_flow,category,merchant,account,budget,subscription,recurring,goal,transactions"`
	Format     string  `json:"format" enum:"csv,xlsx,pdf,json"`
	Title      string  `json:"title,omitempty" maxLength:"160"`
	Filters    Filters `json:"filters,omitempty"`
}

// ReportDTO is a report request and its state.
type ReportDTO struct {
	ID          uuid.UUID         `json:"id"`
	ReportType  string            `json:"report_type" enum:"monthly_summary,yearly_summary,income,expense,cash_flow,category,merchant,account,budget,subscription,recurring,goal,transactions"`
	Title       string            `json:"title"`
	Format      string            `json:"format" enum:"csv,xlsx,pdf,json"`
	Filters     Filters           `json:"filters" doc:"The request as sent (a named range stays a name; window holds its dates)"`
	Window      *analytics.Window `json:"window,omitempty" doc:"The dates the report covers, resolved in your time zone when it was requested, so a named range such as last_month stays fixed for this report. Requesting it again (POST /reports with the same filters) resolves the range from the new request date. Absent for reports of current state (account, budget, subscription, goal, recurring) and for reports requested before windows were stored"`
	Timezone    string            `json:"timezone"`
	Currency    *string           `json:"display_currency,omitempty"`
	Status      string            `json:"status" enum:"queued,running,completed,failed,expired" doc:"expired as soon as expires_at has passed (list, get and download agree)"`
	RowCount    *int32            `json:"row_count,omitempty"`
	ErrorCode   *string           `json:"error_code,omitempty" enum:"reports_unavailable,report_invalid,too_many_rows,pdf_too_large,storage_unavailable,generation_failed" doc:"Why the report failed: reports_unavailable (generation is not configured), report_invalid (the request no longer validates), too_many_rows (more than 100000 transactions), pdf_too_large (too many rows for a PDF; choose CSV or XLSX), storage_unavailable (the file could not be stored on any attempt), generation_failed (every attempt failed)"`
	RequestedAt time.Time         `json:"requested_at"`
	CompletedAt *time.Time        `json:"completed_at,omitempty"`
	ExpiresAt   *time.Time        `json:"expires_at,omitempty"`
}

const reportCols = `id, report_type, title, format, filters, timezone, currency, status, row_count, error_code, requested_at, completed_at, expires_at,
	window_from::text, window_to::text`

func scanReport(r pgx.Row) (*ReportDTO, error) {
	var x ReportDTO
	var f []byte
	var from, to *string
	if err := r.Scan(&x.ID, &x.ReportType, &x.Title, &x.Format, &f, &x.Timezone, &x.Currency, &x.Status, &x.RowCount, &x.ErrorCode,
		&x.RequestedAt, &x.CompletedAt, &x.ExpiresAt, &from, &to); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(f, &x.Filters); err != nil {
		return nil, err
	}
	x.Window = storedWindow(from, to, x.Timezone)
	return &x, nil
}

// storedWindow rebuilds a report's stored window (nil when it has none).
func storedWindow(from, to *string, tz string) *analytics.Window {
	if from == nil || to == nil {
		return nil
	}
	f, err := time.Parse(time.DateOnly, *from)
	if err != nil {
		return nil
	}
	t, err := time.Parse(time.DateOnly, *to)
	if err != nil {
		return nil
	}
	return &analytics.Window{From: *from, To: *to, Days: int(t.Sub(f).Hours()/24) + 1, Timezone: tz}
}

// isExpired reports whether a report's download period has passed. The
// hourly retention job also stores the status; reads derive it so list,
// get and download always agree.
func isExpired(status string, expiresAt *time.Time, now time.Time) bool {
	return status == "expired" || (status == "completed" && expiresAt != nil && expiresAt.Before(now))
}

// present applies the derived status to a report read for its owner.
func (s *Service) present(r *ReportDTO) *ReportDTO {
	if isExpired(r.Status, r.ExpiresAt, s.now()) {
		r.Status = "expired"
	}
	return r
}

var titles = map[string]string{"monthly_summary": "Monthly summary", "yearly_summary": "Yearly summary", "income": "Income", "expense": "Expenses",
	"cash_flow": "Cash flow", "category": "Spending by category", "merchant": "Spending by merchant", "account": "Accounts", "budget": "Budgets",
	"subscription": "Subscriptions", "recurring": "Recurring commitments", "goal": "Goals", "transactions": "Transactions"}

func (s *Service) createTx(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in ReportInput, source string) (uuid.UUID, error) {
	if !supportedTypes[in.ReportType] {
		return uuid.Nil, apperr.FieldError("body.report_type", "This report type is not available yet.")
	}
	u, err := finance.LoadUser(ctx, tx, uid)
	if err != nil {
		return uuid.Nil, err
	}
	f := in.Filters
	if f.Range == "" && f.From == "" && f.To == "" {
		f.Range = map[string]string{"yearly_summary": "this_year"}[in.ReportType]
		if f.Range == "" {
			f.Range = "this_month"
		}
	}
	if err := checkTypes(in.ReportType, f.Types, "body.filters.types"); err != nil {
		return uuid.Nil, err
	}
	// The dates are resolved now, in the owner's calendar, and stored: a
	// named range keeps meaning the period it meant at request time, however
	// late (or how many times) the report is generated.
	win, err := analytics.ResolveWindow(f.analytics(), s.now(), u, "body.filters.")
	if err != nil {
		return uuid.Nil, err
	}
	var winFrom, winTo *string
	if windowed[in.ReportType] {
		winFrom, winTo = &win.From, &win.To
	}
	title := strings.TrimSpace(in.Title)
	if title == "" {
		title = titles[in.ReportType]
	}
	raw, err := json.Marshal(f)
	if err != nil {
		return uuid.Nil, err
	}
	var display *string
	if f.DisplayCurrency != "" {
		display = &f.DisplayCurrency
	}
	id := uuid.New()
	if _, err := tx.Exec(ctx, `insert into reports (id, user_id, report_type, title, filters, format, timezone, currency, status, window_from, window_to)
		values ($1,$2,$3,$4,$5,$6,$7,$8,'queued',$9::date,$10::date)`, id, uid, in.ReportType, title, raw, in.Format, u.Timezone, display,
		winFrom, winTo); err != nil {
		return uuid.Nil, err
	}
	jid, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobGenerate, UserID: &uid, Payload: map[string]any{"report_id": id},
		DedupeKey: "reports.generate:" + id.String(), Priority: 140, MaxAttempts: 3})
	if err != nil {
		return uuid.Nil, err
	}
	if _, err := tx.Exec(ctx, `update reports set job_id = $2 where id = $1`, id, jid); err != nil {
		return uuid.Nil, err
	}
	return id, audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: actorFor(source, uid), EntityType: "report", EntityID: &id, Action: "requested",
		Changes: map[string]any{"type": in.ReportType, "format": in.Format, "source": source}})
}

func actorFor(source string, uid uuid.UUID) *uuid.UUID {
	if source == "schedule" {
		return nil
	}
	return &uid
}

// Create queues a report.
func (s *Service) Create(ctx context.Context, in ReportInput) (*ReportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReportDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		id, err := s.createTx(ctx, tx, uid, in, "user")
		if err != nil {
			return err
		}
		out, err = scanReport(tx.QueryRow(ctx, `select `+reportCols+` from reports where id = $1`, id))
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.present(out), nil
}

// List returns recent reports.
func (s *Service) List(ctx context.Context) ([]ReportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []ReportDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+reportCols+` from reports where user_id = $1 order by requested_at desc limit 100`, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			r, err := scanReport(rows)
			if err != nil {
				return err
			}
			out = append(out, *s.present(r))
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// Get returns one report.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*ReportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReportDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		out, err = scanReport(tx.QueryRow(ctx, `select `+reportCols+` from reports where id = $1 and user_id = $2`, id, uid))
		if database.IsNoRows(err) {
			return apperr.NotFound("report")
		}
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.present(out), nil
}

// Download issues a short-lived signed link for a completed report.
func (s *Service) Download(ctx context.Context, id uuid.UUID) (*files.Access, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var fileID *uuid.UUID
	var status string
	var expires *time.Time
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx, `select status, file_id, expires_at from reports where id = $1 and user_id = $2`, id, uid).Scan(&status, &fileID, &expires)
		if database.IsNoRows(err) {
			return apperr.NotFound("report")
		}
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	if isExpired(status, expires, s.now()) {
		return nil, apperr.New(apperr.CodeGone, 410, "This report has expired. Generate it again.")
	}
	if status != "completed" || fileID == nil {
		return nil, apperr.Conflict("The report is not ready yet.")
	}
	return s.Files.IssueAccess(ctx, *fileID)
}

// Delete removes one of the caller's reports in any status. A queued or
// running generation is cancelled, and the stored file goes through the
// files deletion path (marked deleting and purged by the files.delete
// job) in the same transaction. Both deletions are audited.
func (s *Service) Delete(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var status, reportType, format string
		var fileID, jobID *uuid.UUID
		err := tx.QueryRow(ctx, `select status, report_type, format, file_id, job_id from reports where id = $1 and user_id = $2 for update`, id, uid).
			Scan(&status, &reportType, &format, &fileID, &jobID)
		if database.IsNoRows(err) {
			return apperr.NotFound("report")
		}
		if err != nil {
			return err
		}
		if jobID != nil && (status == "queued" || status == "running") {
			if _, err := jobs.Cancel(ctx, tx, *jobID); err != nil {
				return err
			}
		}
		tag, err := tx.Exec(ctx, `delete from reports where id = $1 and user_id = $2`, id, uid)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("report")
		}
		if fileID != nil {
			f, err := files.Get(ctx, tx, *fileID)
			var ae *apperr.Error
			switch {
			case errors.As(err, &ae) && ae.Code == apperr.CodeNotFound:
				// Already purged (the export's retention passed).
			case err != nil:
				return err
			case f.OwnerID == uid && f.Status != "deleting":
				if err := files.MarkDeleting(ctx, tx, f, uid); err != nil {
					return err
				}
			}
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "report", EntityID: &id, Action: "deleted",
			Changes: map[string]any{"type": reportType, "format": format, "status": status, "file_id": fileID}})
	}))
}

// ScheduleInput creates a recurring report.
type ScheduleInput struct {
	ReportType string  `json:"report_type" enum:"monthly_summary,yearly_summary,income,expense,cash_flow,category,merchant,account,budget,subscription,recurring,goal,transactions"`
	Format     string  `json:"format" enum:"csv,xlsx,pdf,json"`
	Title      string  `json:"title,omitempty" maxLength:"160"`
	Cadence    string  `json:"cadence" enum:"weekly,monthly" doc:"Each run covers the previous full week or month"`
	Filters    Filters `json:"filters,omitempty" doc:"Range is set by the cadence"`
}

// ScheduleDTO is a scheduled report.
type ScheduleDTO struct {
	ID         uuid.UUID `json:"id"`
	ReportType string    `json:"report_type" enum:"monthly_summary,yearly_summary,income,expense,cash_flow,category,merchant,account,budget,subscription,recurring,goal,transactions"`
	Title      string    `json:"title"`
	Format     string    `json:"format" enum:"csv,xlsx,pdf,json"`
	Cadence    string    `json:"cadence" enum:"weekly,monthly" doc:"Each run covers the previous full week or month"`
	Filters    Filters   `json:"filters" doc:"Filters of every run; the cadence sets the dates (last_week or last_month)"`
	NextRunAt  time.Time `json:"next_run_at" doc:"When the next report is requested (06:00 in your time zone at the start of a week or month); not used while paused"`
	Enabled    bool      `json:"enabled" doc:"false while paused (PATCH /reports/schedules/{id} with enabled)"`
	Version    int32     `json:"version" doc:"Send it with PATCH; a concurrent change answers 409 VERSION_CONFLICT"`
}

const scheduleCols = `id, report_type, title, format, cadence, filters, next_run_at, enabled, version`

func scanSchedule(r pgx.Row) (*ScheduleDTO, error) {
	var x ScheduleDTO
	var f []byte
	if err := r.Scan(&x.ID, &x.ReportType, &x.Title, &x.Format, &x.Cadence, &f, &x.NextRunAt, &x.Enabled, &x.Version); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(f, &x.Filters); err != nil {
		return nil, err
	}
	return &x, nil
}

// nextRun returns the next cadence boundary (06:00 local) after now.
func nextRun(now time.Time, loc *time.Location, cadence string) time.Time {
	l := now.In(loc)
	if cadence == "weekly" {
		days := (8 - int(l.Weekday())) % 7 // next Monday
		if days == 0 {
			days = 7
		}
		d := time.Date(l.Year(), l.Month(), l.Day(), 6, 0, 0, 0, loc).AddDate(0, 0, days)
		return d
	}
	return time.Date(l.Year(), l.Month()+1, 1, 6, 0, 0, 0, loc)
}

func defaultScheduleTitle(reportType, cadence string) string {
	return titles[reportType] + " (" + cadence + ")"
}

// scheduleFilters is the stored filter set of a schedule: the cadence sets
// the dates of every run.
func scheduleFilters(reportType string, f Filters) ([]byte, Filters, error) {
	f.Range, f.From, f.To = "", "", ""
	if err := checkTypes(reportType, f.Types, "body.filters.types"); err != nil {
		return nil, f, err
	}
	raw, err := json.Marshal(f)
	return raw, f, err
}

// CreateSchedule stores a recurring report.
func (s *Service) CreateSchedule(ctx context.Context, in ScheduleInput) (*ScheduleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if !supportedTypes[in.ReportType] {
		return nil, apperr.FieldError("body.report_type", "This report type is not available yet.")
	}
	raw, _, err := scheduleFilters(in.ReportType, in.Filters)
	if err != nil {
		return nil, err
	}
	var out *ScheduleDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		title := strings.TrimSpace(in.Title)
		if title == "" {
			title = defaultScheduleTitle(in.ReportType, in.Cadence)
		}
		next := nextRun(s.now(), u.Loc, in.Cadence)
		if out, err = scanSchedule(tx.QueryRow(ctx, `insert into scheduled_reports (user_id, report_type, title, filters, format, cadence, next_run_at)
			values ($1,$2,$3,$4,$5,$6,$7) returning `+scheduleCols, uid, in.ReportType, title, raw, in.Format, in.Cadence, next)); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "scheduled_report", EntityID: &out.ID, Action: "created"})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return out, nil
}

// SchedulePatch changes only the fields sent.
type SchedulePatch struct {
	Title   *string  `json:"title,omitempty" maxLength:"160" doc:"Empty string restores the default title"`
	Format  *string  `json:"format,omitempty" enum:"csv,xlsx,pdf,json"`
	Cadence *string  `json:"cadence,omitempty" enum:"weekly,monthly" doc:"A new cadence moves next_run_at to the next start of a week or month"`
	Filters *Filters `json:"filters,omitempty" doc:"Replaces the filters (range, from and to are ignored: the cadence sets the dates)"`
	Enabled *bool    `json:"enabled,omitempty" doc:"false pauses the schedule (no reports are requested); true resumes it from the next start of a week or month (missed periods are not back-filled)"`
	Version int32    `json:"version,omitempty" doc:"The version you read; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

// UpdateSchedule edits or pauses/resumes a scheduled report.
func (s *Service) UpdateSchedule(ctx context.Context, id uuid.UUID, p SchedulePatch) (*ScheduleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ScheduleDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		cur, err := scanSchedule(tx.QueryRow(ctx, `select `+scheduleCols+` from scheduled_reports where id = $1 and user_id = $2 for update`, id, uid))
		if database.IsNoRows(err) {
			return apperr.NotFound("schedule")
		}
		if err != nil {
			return err
		}
		if p.Version != 0 && p.Version != cur.Version {
			return apperr.VersionConflict()
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		next := *cur
		changed := []string{}
		if p.Format != nil && *p.Format != cur.Format {
			next.Format = *p.Format
			changed = append(changed, "format")
		}
		if p.Cadence != nil && *p.Cadence != cur.Cadence {
			next.Cadence = *p.Cadence
			next.NextRunAt = nextRun(s.now(), u.Loc, next.Cadence)
			if p.Title == nil && cur.Title == defaultScheduleTitle(cur.ReportType, cur.Cadence) {
				next.Title = defaultScheduleTitle(cur.ReportType, next.Cadence)
			}
			changed = append(changed, "cadence")
		}
		if p.Title != nil {
			title := strings.TrimSpace(*p.Title)
			if title == "" {
				title = defaultScheduleTitle(cur.ReportType, next.Cadence)
			}
			if title != cur.Title {
				next.Title = title
				changed = append(changed, "title")
			}
		}
		raw, err := json.Marshal(cur.Filters)
		if err != nil {
			return err
		}
		if p.Filters != nil {
			nraw, nf, err := scheduleFilters(cur.ReportType, *p.Filters)
			if err != nil {
				return err
			}
			if !bytes.Equal(nraw, raw) {
				raw, next.Filters = nraw, nf
				changed = append(changed, "filters")
			}
		}
		action := "updated"
		if p.Enabled != nil && *p.Enabled != cur.Enabled {
			next.Enabled = *p.Enabled
			if next.Enabled {
				// Resuming starts from the next boundary: periods missed while
				// paused are not back-filled.
				next.NextRunAt = nextRun(s.now(), u.Loc, next.Cadence)
				action = "resumed"
			} else {
				action = "paused"
			}
			changed = append(changed, "enabled")
		}
		if len(changed) == 0 {
			out = cur
			return nil
		}
		if len(changed) > 1 {
			action = "updated"
		}
		if out, err = scanSchedule(tx.QueryRow(ctx, `update scheduled_reports set title = $2, format = $3, cadence = $4, filters = $5,
			enabled = $6, next_run_at = $7, version = version + 1 where id = $1 returning `+scheduleCols,
			id, next.Title, next.Format, next.Cadence, raw, next.Enabled, next.NextRunAt)); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "scheduled_report", EntityID: &id, Action: action,
			Changes: map[string]any{"fields": changed}})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return out, nil
}

// ListSchedules returns scheduled reports.
func (s *Service) ListSchedules(ctx context.Context) ([]ScheduleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []ScheduleDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+scheduleCols+` from scheduled_reports where user_id = $1 order by next_run_at, id`, uid)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (ScheduleDTO, error) {
			x, err := scanSchedule(r)
			if err != nil {
				return ScheduleDTO{}, err
			}
			return *x, nil
		})
		return err
	})
	return out, database.MapError(err)
}

// DeleteSchedule removes a scheduled report.
func (s *Service) DeleteSchedule(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from scheduled_reports where id = $1`, id)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("schedule")
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "scheduled_report", EntityID: &id, Action: "deleted"})
	}))
}
