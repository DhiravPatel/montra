package admin

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/ratelimit"
)

// Operator job visibility (JOB-007). Admins see operational facts about
// background jobs (type, status, attempts, error codes, timing) through
// SECURITY DEFINER helpers that never return payloads, results, error
// messages or the person a job acts for.

const maxJobPage = 200

// JobDTO is one background job as operators see it.
type JobDTO struct {
	ID              uuid.UUID  `json:"id"`
	Type            string     `json:"type"`
	Queue           string     `json:"queue"`
	Status          string     `json:"status" enum:"queued,running,succeeded,failed,dead,cancelled"`
	Priority        int        `json:"priority" doc:"Lower runs first"`
	Attempts        int        `json:"attempts" doc:"Attempts started so far"`
	MaxAttempts     int        `json:"max_attempts"`
	LastErrorCode   *string    `json:"last_error_code,omitempty" doc:"Safe code of the last failure (for example email_send_failed, provider_circuit_open, timeout); never the message"`
	UserScoped      bool       `json:"user_scoped" doc:"The job acts for one person (who is not disclosed)"`
	CancelRequested bool       `json:"cancel_requested"`
	Retryable       bool       `json:"retryable" doc:"Failed or dead: POST /admin/jobs/{id}/retry re-queues it"`
	RunAfter        time.Time  `json:"run_after"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	StartedAt       *time.Time `json:"started_at,omitempty"`
	FinishedAt      *time.Time `json:"finished_at,omitempty"`
}

// JobAttemptDTO is one execution attempt of a job.
type JobAttemptDTO struct {
	Attempt    int        `json:"attempt"`
	WorkerID   string     `json:"worker_id" doc:"Worker process that ran the attempt"`
	Outcome    *string    `json:"outcome,omitempty" enum:"succeeded,retry,failed,dead,cancelled,lease_expired" doc:"Absent while the attempt runs"`
	ErrorCode  *string    `json:"error_code,omitempty" doc:"Safe failure code; never the message"`
	StartedAt  time.Time  `json:"started_at"`
	FinishedAt *time.Time `json:"finished_at,omitempty"`
	DurationMS *int       `json:"duration_ms,omitempty"`
}

// JobDetail is one job with its attempts, oldest first.
type JobDetail struct {
	Job      JobDTO          `json:"job"`
	Attempts []JobAttemptDTO `json:"attempts"`
}

// JobFilter selects jobs. Dates are UTC calendar days (inclusive) of the
// job's creation.
type JobFilter struct {
	Status string `query:"status" enum:"queued,running,succeeded,failed,dead,cancelled," doc:"Only jobs with this status"`
	Type   string `query:"type" maxLength:"80" pattern:"^([a-z0-9_.]+)?$" doc:"Only jobs of this type, for example notifications.deliver"`
	From   string `query:"from" doc:"Created on or after this UTC date (YYYY-MM-DD)"`
	To     string `query:"to" doc:"Created on or before this UTC date (YYYY-MM-DD)"`
	Cursor string `query:"cursor" maxLength:"512"`
	Limit  int    `query:"limit" minimum:"1" maximum:"200" default:"50"`
}

type jobCursor struct {
	At time.Time `json:"a"`
	ID uuid.UUID `json:"i"`
}

func retryableStatus(status string) bool { return status == "failed" || status == "dead" }

func parseDay(field, v string) (*time.Time, error) {
	if v == "" {
		return nil, nil
	}
	d, err := time.Parse(time.DateOnly, v)
	if err != nil {
		return nil, apperr.FieldError(field, "Use a date in the form YYYY-MM-DD.")
	}
	return &d, nil
}

func nullable(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// queryJobs calls montra.admin_jobs (admin only; the helper checks too).
func queryJobs(ctx context.Context, tx pgx.Tx, id *uuid.UUID, f JobFilter, from, to *time.Time, cur *jobCursor, limit int) ([]JobDTO, error) {
	var afterAt *time.Time
	var afterID *uuid.UUID
	if cur != nil {
		afterAt, afterID = &cur.At, &cur.ID
	}
	rows, err := tx.Query(ctx, `select id, type, queue, status, priority, attempts, max_attempts, last_error_code, user_scoped, cancel_requested,
		run_after, created_at, updated_at, started_at, finished_at from montra.admin_jobs($1, $2, $3, $4, $5, $6, $7, $8)`,
		id, nullable(f.Status), nullable(f.Type), from, to, afterAt, afterID, limit)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(row pgx.CollectableRow) (JobDTO, error) {
		var j JobDTO
		var prio int16
		err := row.Scan(&j.ID, &j.Type, &j.Queue, &j.Status, &prio, &j.Attempts, &j.MaxAttempts, &j.LastErrorCode, &j.UserScoped,
			&j.CancelRequested, &j.RunAfter, &j.CreatedAt, &j.UpdatedAt, &j.StartedAt, &j.FinishedAt)
		j.Priority = int(prio)
		j.Retryable = retryableStatus(j.Status)
		return j, err
	})
}

// Jobs lists jobs newest first with a cursor ("" on the last page).
func (s *Service) Jobs(ctx context.Context, f JobFilter) ([]JobDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	from, err := parseDay("query.from", f.From)
	if err != nil {
		return nil, "", err
	}
	to, err := parseDay("query.to", f.To)
	if err != nil {
		return nil, "", err
	}
	if from != nil && to != nil && to.Before(*from) {
		return nil, "", apperr.FieldError("query.to", "The end date must be on or after the start date.")
	}
	if to != nil {
		end := to.AddDate(0, 0, 1) // inclusive day
		to = &end
	}
	limit := f.Limit
	if limit <= 0 || limit > maxJobPage {
		limit = 50
	}
	var cur *jobCursor
	if f.Cursor != "" {
		cur = &jobCursor{}
		if err := httpx.DecodeCursor(f.Cursor, cur); err != nil {
			return nil, "", err
		}
	}
	var out []JobDTO
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		if out, err = queryJobs(ctx, tx, nil, f, from, to, cur, limit+1); err != nil {
			return err
		}
		if len(out) > limit {
			last := out[limit-1]
			out = out[:limit]
			next, err = httpx.EncodeCursor(jobCursor{At: last.CreatedAt, ID: last.ID})
		}
		return err
	})
	return out, next, database.MapError(err)
}

func loadJob(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*JobDTO, error) {
	l, err := queryJobs(ctx, tx, &id, JobFilter{}, nil, nil, nil, 1)
	if err != nil {
		return nil, err
	}
	if len(l) == 0 {
		return nil, apperr.NotFound("job")
	}
	return &l[0], nil
}

// Job returns one job and its attempts.
func (s *Service) Job(ctx context.Context, id uuid.UUID) (*JobDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out JobDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		j, err := loadJob(ctx, tx, id)
		if err != nil {
			return err
		}
		out.Job = *j
		rows, err := tx.Query(ctx, `select attempt, worker_id, outcome, error_code, started_at, finished_at, duration_ms
			from montra.admin_job_attempts($1)`, id)
		if err != nil {
			return err
		}
		out.Attempts, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (JobAttemptDTO, error) {
			var a JobAttemptDTO
			err := row.Scan(&a.Attempt, &a.WorkerID, &a.Outcome, &a.ErrorCode, &a.StartedAt, &a.FinishedAt, &a.DurationMS)
			return a, err
		})
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	if out.Attempts == nil {
		out.Attempts = []JobAttemptDTO{}
	}
	return &out, nil
}

// errNotRetryable refuses a retry of a job that is not failed or dead.
func errNotRetryable(status string) *apperr.Error {
	return apperr.Rule("job_not_retryable", "Only failed or dead jobs can be retried.", map[string]string{"status": status, "from": status, "to": "queued"})
}

// RetryJob re-queues a failed or dead job (idempotent per key, audited).
// Other states answer 422 job_not_retryable with the current status.
func (s *Service) RetryJob(ctx context.Context, key string, id uuid.UUID) (*JobDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out JobDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "admin.job_retry", struct{ Job uuid.UUID }{id}, func() (JobDTO, error) {
			var prev *string
			if err := tx.QueryRow(ctx, `select montra.admin_job_retry($1)`, id).Scan(&prev); err != nil {
				return JobDTO{}, err
			}
			if prev == nil {
				return JobDTO{}, apperr.NotFound("job")
			}
			if !retryableStatus(*prev) {
				return JobDTO{}, errNotRetryable(*prev)
			}
			j, err := loadJob(ctx, tx, id)
			if err != nil {
				return JobDTO{}, err
			}
			if err := audit.Record(ctx, tx, audit.Event{ActorUserID: &uid, ActorKind: "admin", EntityType: "job", EntityID: &id,
				Action: "retried", Changes: map[string]any{"from": *prev, "to": j.Status, "type": j.Type}}); err != nil {
				return JobDTO{}, err
			}
			return *j, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// jobRoutes mounts the operator job endpoints (platform admins only).
func (s *Service) jobRoutes(api huma.API) {
	const tag = "Admin"
	listOp := httpx.Staff(httpx.Op("admin-jobs-list", http.MethodGet, "/admin/jobs", "Background jobs, newest first (admin; no payloads)", tag), "admin")
	listOp.Description = "Filters: status, type, from/to (UTC creation dates, inclusive). Pages with cursor and limit (at most 200; " +
		"meta.next_cursor). Each job carries its attempts count and last_error_code, never its payload, result, error message or " +
		"the person it acts for."
	httpx.Protected(api, listOp,
		func(ctx context.Context, in *struct{ JobFilter }) (*httpx.Response[[]JobDTO], error) {
			l, next, err := s.Jobs(ctx, in.JobFilter)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Staff(httpx.Op("admin-jobs-get", http.MethodGet, "/admin/jobs/{id}",
		"One background job with its attempts (admin; no payloads)", tag), "admin"),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[JobDetail], error) {
			d, err := s.Job(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	retryOp := httpx.Staff(httpx.Rate(httpx.Op("admin-jobs-retry", http.MethodPost, "/admin/jobs/{id}/retry",
		"Re-queue a failed or dead job (admin; audited)", tag), ratelimit.Write.Name), "admin")
	retryOp.Description = "Queues the job to run now with at least one more attempt. Requires Idempotency-Key: a retry with the same " +
		"key returns the original result. A job that is not failed or dead answers 422 DOMAIN_RULE_VIOLATION with details[0].code " +
		"job_not_retryable (params status, from, to); an unknown job answers 404."
	httpx.Protected(api, retryOp,
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
			httpx.IdemHeader
		}) (*httpx.ReplayOutput[JobDTO], error) {
			j, replayed, err := s.RetryJob(ctx, in.Key, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *j, replayed), nil
		})
}
