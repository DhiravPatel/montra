// Package jobs implements Montra's durable PostgreSQL job queue (ADR-008):
// at-least-once delivery, leases with heartbeats, exponential backoff with
// full jitter, max attempts with dead-lettering, per-type concurrency
// limits, cancellation and manual retry. Handlers must be idempotent.
package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/platform/database"
)

// Spec describes a job to enqueue.
type Spec struct {
	Type          string
	Queue         string
	UserID        *uuid.UUID
	Payload       any
	RunAfter      time.Time
	Priority      int
	MaxAttempts   int
	DedupeKey     string
	CorrelationID string
	// CoalesceQueued skips the insert while a job of the same type, user
	// and payload is still queued (not yet running): changes that arrive
	// before a debounced job starts share it, and changes that arrive after
	// it started get a new run. Use it for "re-evaluate after changes" jobs;
	// DedupeKey is for jobs that must run at most once ever.
	CoalesceQueued bool
}

// Enqueue inserts a job. When DedupeKey is set and a job with that key
// already exists, nothing is inserted and created is false (idempotent
// enqueue). With CoalesceQueued, nothing is inserted while an equal job is
// queued.
func Enqueue(ctx context.Context, q database.Querier, s Spec) (id uuid.UUID, created bool, err error) {
	if s.Type == "" {
		return uuid.Nil, false, errors.New("job type required")
	}
	if s.Queue == "" {
		s.Queue = "default"
	}
	if s.Priority == 0 {
		s.Priority = 100
	}
	if s.MaxAttempts == 0 {
		s.MaxAttempts = 8
	}
	if s.RunAfter.IsZero() {
		s.RunAfter = time.Now()
	}
	payload := []byte("{}")
	if s.Payload != nil {
		if payload, err = json.Marshal(s.Payload); err != nil {
			return uuid.Nil, false, fmt.Errorf("marshal job payload: %w", err)
		}
	}
	var dedupe *string
	if s.DedupeKey != "" {
		dedupe = &s.DedupeKey
	}
	var corr *string
	if s.CorrelationID != "" {
		corr = &s.CorrelationID
	}
	if s.CoalesceQueued {
		// A concurrent enqueue may slip through (two queued jobs): harmless
		// for an idempotent re-evaluation, so no lock is taken.
		err = q.QueryRow(ctx, `
insert into jobs (type, queue, user_id, payload, priority, max_attempts, run_after, dedupe_key, correlation_id)
select $1, $2, $3, $4, $5, $6, $7, $8, $9
where not exists (select 1 from jobs where type = $1 and user_id is not distinct from $3 and payload = $4::jsonb and status = 'queued')
returning id`, s.Type, s.Queue, s.UserID, payload, s.Priority, s.MaxAttempts, s.RunAfter, dedupe, corr).Scan(&id)
	} else {
		err = q.QueryRow(ctx, `
insert into jobs (type, queue, user_id, payload, priority, max_attempts, run_after, dedupe_key, correlation_id)
values ($1, $2, $3, $4, $5, $6, $7, $8, $9)
on conflict (dedupe_key) where dedupe_key is not null do nothing
returning id`, s.Type, s.Queue, s.UserID, payload, s.Priority, s.MaxAttempts, s.RunAfter, dedupe, corr).Scan(&id)
	}
	if database.IsNoRows(err) {
		return uuid.Nil, false, nil
	}
	if err != nil {
		return uuid.Nil, false, database.MapError(err)
	}
	return id, true, nil
}

// Job is a claimed job passed to handlers.
type Job struct {
	ID            uuid.UUID
	Type          string
	UserID        *uuid.UUID
	Payload       json.RawMessage
	Attempt       int
	MaxAttempts   int
	CorrelationID string
}

// Decode unmarshals the payload into v.
func (j Job) Decode(v any) error {
	if err := json.Unmarshal(j.Payload, v); err != nil {
		return Permanent(fmt.Errorf("decode payload: %w", err))
	}
	return nil
}

// permanentError marks a failure that must not be retried.
type permanentError struct{ err error }

func (p permanentError) Error() string { return p.err.Error() }
func (p permanentError) Unwrap() error { return p.err }

// Permanent wraps err so the job fails without retry.
func Permanent(err error) error { return permanentError{err: err} }

// IsPermanent reports whether err is permanent.
func IsPermanent(err error) bool {
	var p permanentError
	return errors.As(err, &p)
}

// retryAfterError requests a specific retry delay (e.g. provider throttling).
type retryAfterError struct {
	err   error
	delay time.Duration
}

func (r retryAfterError) Error() string { return r.err.Error() }
func (r retryAfterError) Unwrap() error { return r.err }

// RetryAfter wraps err with an explicit retry delay.
func RetryAfter(err error, d time.Duration) error { return retryAfterError{err: err, delay: d} }

// Coded errors carry a safe error code stored on the job (never payloads).
type codedError struct {
	code string
	err  error
}

func (c codedError) Error() string { return c.code + ": " + c.err.Error() }
func (c codedError) Unwrap() error { return c.err }

// WithCode attaches a safe classification code.
func WithCode(code string, err error) error { return codedError{code: code, err: err} }

// jobErrorCoder is implemented by errors from shared infrastructure that
// carry their own safe code (an open circuit breaker).
type jobErrorCoder interface{ JobErrorCode() string }

// minRetryDelayer is implemented by errors that know the earliest useful
// retry (an open circuit breaker's remaining cool-down).
type minRetryDelayer interface{ MinRetryDelay() time.Duration }

// minRetryDelay returns the longest minimum retry delay found in err's
// chain (0 when none).
func minRetryDelay(err error) time.Duration {
	var m minRetryDelayer
	if errors.As(err, &m) {
		return m.MinRetryDelay()
	}
	return 0
}

// errorCode classifies a handler error. Infrastructure codes (an open
// circuit breaker) win over the handler's own code: they say why the call
// never reached the provider.
func errorCode(err error) string {
	var jc jobErrorCoder
	if errors.As(err, &jc) {
		return jc.JobErrorCode()
	}
	var c codedError
	if errors.As(err, &c) {
		return c.code
	}
	if IsPermanent(err) {
		return "permanent"
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "timeout"
	}
	return "error"
}

// Cancel requests cancellation of a queued or running job owned by the
// current RLS user (API) or any job (worker).
func Cancel(ctx context.Context, q database.Querier, id uuid.UUID) (bool, error) {
	tag, err := q.Exec(ctx, `
update jobs set cancel_requested = true,
  status = case when status = 'queued' then 'cancelled' else status end,
  finished_at = case when status = 'queued' then now() else finished_at end
where id = $1 and status in ('queued','running')`, id)
	if err != nil {
		return false, database.MapError(err)
	}
	return tag.RowsAffected() > 0, nil
}

// Retry re-queues a failed/dead job (operator action).
func Retry(ctx context.Context, q database.Querier, id uuid.UUID) (bool, error) {
	tag, err := q.Exec(ctx, `
update jobs set status = 'queued', run_after = now(), locked_by = null, locked_until = null,
  max_attempts = greatest(max_attempts, attempts + 1), cancel_requested = false, finished_at = null
where id = $1 and status in ('failed','dead','cancelled')`, id)
	if err != nil {
		return false, database.MapError(err)
	}
	return tag.RowsAffected() > 0, nil
}
