package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/rand/v2"
	"os"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/logging"
	"montra/backend/internal/platform/observability"
)

// HandlerFunc processes one job. It must be idempotent: at-least-once
// delivery means it can run more than once for the same job.
type HandlerFunc func(ctx context.Context, j Job) error

type handlerEntry struct {
	fn          HandlerFunc
	timeout     time.Duration
	concurrency int
}

// Registry maps job types to handlers.
type Registry struct {
	handlers map[string]handlerEntry
}

// NewRegistry creates an empty registry.
func NewRegistry() *Registry { return &Registry{handlers: map[string]handlerEntry{}} }

// HandlerOption customizes a handler.
type HandlerOption func(*handlerEntry)

// WithTimeout bounds a handler's execution.
func WithTimeout(d time.Duration) HandlerOption { return func(h *handlerEntry) { h.timeout = d } }

// WithConcurrency limits concurrent executions of a job type per worker.
func WithConcurrency(n int) HandlerOption { return func(h *handlerEntry) { h.concurrency = n } }

// Register adds a handler.
func (r *Registry) Register(jobType string, fn HandlerFunc, opts ...HandlerOption) {
	h := handlerEntry{fn: fn, timeout: 2 * time.Minute}
	for _, o := range opts {
		o(&h)
	}
	r.handlers[jobType] = h
}

// HandlerInfo describes a registered handler (documentation, tests).
type HandlerInfo struct {
	Type        string
	Timeout     time.Duration
	Concurrency int // 0 = worker default
}

// Describe lists registered handlers sorted by type.
func (r *Registry) Describe() []HandlerInfo {
	out := make([]HandlerInfo, 0, len(r.handlers))
	for t, h := range r.handlers {
		out = append(out, HandlerInfo{Type: t, Timeout: h.timeout, Concurrency: h.concurrency})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Type < out[j].Type })
	return out
}

// Types lists registered job types.
func (r *Registry) Types() []string {
	out := make([]string, 0, len(r.handlers))
	for t := range r.handlers {
		out = append(out, t)
	}
	return out
}

// WorkerOptions configures a worker.
type WorkerOptions struct {
	Concurrency  int
	PollInterval time.Duration
	Lease        time.Duration
	Queues       []string
	Metrics      *observability.Metrics
}

// Worker claims and executes jobs.
type Worker struct {
	db   *database.DB
	reg  *Registry
	id   string
	opts WorkerOptions

	mu       sync.Mutex
	inFlight map[string]int
}

// NewWorker creates a worker with a unique ID.
func NewWorker(db *database.DB, reg *Registry, o WorkerOptions) *Worker {
	if o.Concurrency <= 0 {
		o.Concurrency = 4
	}
	if o.PollInterval <= 0 {
		o.PollInterval = time.Second
	}
	if o.Lease <= 0 {
		o.Lease = 5 * time.Minute
	}
	if len(o.Queues) == 0 {
		o.Queues = []string{"default"}
	}
	host, _ := os.Hostname()
	return &Worker{db: db, reg: reg, opts: o, inFlight: map[string]int{},
		id: fmt.Sprintf("%s-%d-%s", host, os.Getpid(), uuid.NewString()[:8])}
}

// ID returns the worker identifier.
func (w *Worker) ID() string { return w.id }

// Run claims jobs until ctx is cancelled, then waits for in-flight jobs.
func (w *Worker) Run(ctx context.Context) error {
	var wg sync.WaitGroup
	slots := make(chan struct{}, w.opts.Concurrency)
	sweep := time.NewTicker(30 * time.Second)
	defer sweep.Stop()
	slog.InfoContext(ctx, "worker started", slog.String("worker_id", w.id), slog.Int("concurrency", w.opts.Concurrency))
	for {
		if err := ctx.Err(); err != nil {
			break
		}
		select {
		case <-sweep.C:
			if err := w.RecoverExpiredLeases(ctx); err != nil && ctx.Err() == nil {
				slog.ErrorContext(ctx, "lease recovery failed", slog.Any("error", err))
			}
		default:
		}
		free := cap(slots) - len(slots)
		if free == 0 {
			select {
			case <-ctx.Done():
			case <-time.After(50 * time.Millisecond):
			}
			continue
		}
		claimed, err := w.claim(ctx, free)
		if err != nil {
			if ctx.Err() == nil {
				slog.ErrorContext(ctx, "claim failed", slog.Any("error", err))
			}
			select {
			case <-ctx.Done():
			case <-time.After(w.opts.PollInterval):
			}
			continue
		}
		for _, j := range claimed {
			slots <- struct{}{}
			wg.Add(1)
			w.track(j.Type, 1)
			go func(j Job) {
				defer wg.Done()
				defer func() { <-slots }()
				defer w.track(j.Type, -1)
				w.execute(context.WithoutCancel(ctx), ctx, j)
			}(j)
		}
		if len(claimed) == 0 {
			select {
			case <-ctx.Done():
			case <-time.After(w.opts.PollInterval):
			}
		}
	}
	slog.Info("worker draining in-flight jobs", slog.String("worker_id", w.id))
	wg.Wait()
	return nil
}

// Drain synchronously claims and executes ready jobs until none remain (or
// limit iterations). Used by tests and operator tooling.
func (w *Worker) Drain(ctx context.Context, limit int) (int, error) {
	total := 0
	for i := 0; i < limit; i++ {
		claimed, err := w.claim(ctx, w.opts.Concurrency)
		if err != nil {
			return total, err
		}
		if len(claimed) == 0 {
			return total, nil
		}
		for _, j := range claimed {
			w.execute(ctx, ctx, j)
			total++
		}
	}
	return total, nil
}

func (w *Worker) track(t string, d int) {
	w.mu.Lock()
	w.inFlight[t] += d
	w.mu.Unlock()
}

// saturatedTypes lists job types at their concurrency limit.
func (w *Worker) saturatedTypes() []string {
	w.mu.Lock()
	defer w.mu.Unlock()
	// Never nil: pgx encodes a nil slice as NULL, and NOT (x = ANY(NULL)) is
	// NULL, which would silently exclude every job.
	out := []string{}
	for t, h := range w.reg.handlers {
		if h.concurrency > 0 && w.inFlight[t] >= h.concurrency {
			out = append(out, t)
		}
	}
	return out
}

func (w *Worker) claim(ctx context.Context, limit int) ([]Job, error) {
	var out []Job
	err := w.db.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `
with picked as (
  select id from jobs
  where status = 'queued' and run_after <= now() and queue = any($2::text[])
    and type = any($3::text[]) and not (type = any($4::text[]))
  order by priority, run_after
  limit $5
  for update skip locked
)
update jobs j set status = 'running', locked_by = $1, locked_until = now() + make_interval(secs => $6),
  attempts = j.attempts + 1, started_at = coalesce(j.started_at, now()), updated_at = now()
from picked where j.id = picked.id
returning j.id, j.type, j.user_id, j.payload, j.attempts, j.max_attempts, coalesce(j.correlation_id, ''), j.cancel_requested`,
			w.id, w.opts.Queues, w.reg.Types(), w.saturatedTypes(), limit, w.opts.Lease.Seconds())
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var j Job
			var cancel bool
			if err := rows.Scan(&j.ID, &j.Type, &j.UserID, &j.Payload, &j.Attempt, &j.MaxAttempts, &j.CorrelationID, &cancel); err != nil {
				return err
			}
			if cancel {
				if _, err := tx.Exec(ctx, `update jobs set status='cancelled', finished_at=now(), locked_by=null, locked_until=null where id=$1`, j.ID); err != nil {
					return err
				}
				continue
			}
			out = append(out, j)
		}
		return rows.Err()
	})
	return out, err
}

// execute runs a handler with a timeout and lease heartbeat. bgCtx survives
// shutdown so results are recorded; runCtx cancels on shutdown.
func (w *Worker) execute(bgCtx, runCtx context.Context, j Job) {
	h, ok := w.reg.handlers[j.Type]
	start := time.Now()
	ctx := logging.WithJobID(bgCtx, j.ID.String())
	if !ok {
		w.finish(ctx, j, start, Permanent(fmt.Errorf("no handler for %s", j.Type)))
		return
	}
	// On shutdown (runCtx cancelled) in-flight handlers keep their timeout
	// budget instead of being cancelled abruptly; results are still recorded.
	_ = runCtx
	hctx, cancel := context.WithTimeout(ctx, h.timeout)
	defer cancel()
	stopBeat := w.heartbeat(ctx, j.ID)
	var err error
	func() {
		defer func() {
			if p := recover(); p != nil {
				err = fmt.Errorf("handler panic: %v", p)
			}
		}()
		err = h.fn(hctx, j)
	}()
	stopBeat()
	w.finish(ctx, j, start, err)
}

func (w *Worker) heartbeat(ctx context.Context, id uuid.UUID) func() {
	done := make(chan struct{})
	go func() {
		t := time.NewTicker(w.opts.Lease / 3)
		defer t.Stop()
		for {
			select {
			case <-done:
				return
			case <-t.C:
				_ = w.db.WithSystemTx(ctx, func(tx pgx.Tx) error {
					_, err := tx.Exec(ctx, `update jobs set locked_until = now() + make_interval(secs => $3) where id = $1 and locked_by = $2 and status = 'running'`,
						id, w.id, w.opts.Lease.Seconds())
					return err
				})
			}
		}
	}()
	return func() { close(done) }
}

// Backoff returns the full-jitter exponential delay for an attempt.
func Backoff(attempt int) time.Duration {
	base := 5 * time.Second
	capD := time.Hour
	if attempt < 1 {
		attempt = 1
	}
	d := base << min(attempt-1, 20)
	if d > capD || d <= 0 {
		d = capD
	}
	return time.Duration(rand.Int64N(int64(d))) + time.Second //nolint:gosec // retry jitter needs no cryptographic randomness
}

func (w *Worker) finish(ctx context.Context, j Job, start time.Time, herr error) {
	dur := time.Since(start)
	outcome := "succeeded"
	status := "succeeded"
	var runAfter time.Time
	code := ""
	msg := ""
	if herr != nil {
		code = errorCode(herr)
		msg = truncate(herr.Error(), 300)
		switch {
		case IsPermanent(herr):
			status, outcome = "failed", "failed"
		case j.Attempt >= j.MaxAttempts:
			status, outcome = "dead", "dead"
		default:
			status, outcome = "queued", "retry"
			delay := Backoff(j.Attempt)
			var ra retryAfterError
			if errors.As(herr, &ra) && ra.delay > 0 {
				delay = ra.delay
			}
			// An open circuit breaker fails fast; retrying before its
			// cool-down ends would only burn an attempt.
			if d := minRetryDelay(herr); d > delay {
				delay = d
			}
			runAfter = time.Now().Add(delay)
		}
	}
	err := w.db.WithSystemTx(ctx, func(tx pgx.Tx) error {
		if status == "queued" {
			if _, err := tx.Exec(ctx, `update jobs set status='queued', run_after=$3, locked_by=null, locked_until=null,
				last_error_code=$4, last_error=$5 where id=$1 and locked_by=$2`, j.ID, w.id, runAfter, code, msg); err != nil {
				return err
			}
		} else {
			if _, err := tx.Exec(ctx, `update jobs set status=$3, finished_at=now(), locked_by=null, locked_until=null,
				last_error_code=nullif($4,''), last_error=nullif($5,'') where id=$1 and locked_by=$2`, j.ID, w.id, status, code, msg); err != nil {
				return err
			}
		}
		_, err := tx.Exec(ctx, `insert into job_attempts (job_id, attempt, worker_id, started_at, finished_at, outcome, error_code, error, duration_ms)
			values ($1,$2,$3,$4,now(),$5,nullif($6,''),nullif($7,''),$8)`, j.ID, j.Attempt, w.id, start, outcome, code, msg, dur.Milliseconds())
		return err
	})
	if err != nil {
		slog.ErrorContext(ctx, "failed to record job result", slog.Any("error", err))
	}
	if m := w.opts.Metrics; m != nil {
		m.JobsProcessed.WithLabelValues(j.Type, outcome).Inc()
		m.JobDuration.WithLabelValues(j.Type).Observe(dur.Seconds())
		if outcome == "retry" {
			m.JobRetries.WithLabelValues(j.Type).Inc()
		}
	}
	level := slog.LevelInfo
	switch outcome {
	case "dead", "failed":
		level = slog.LevelError
	case "retry":
		level = slog.LevelWarn
	}
	slog.Log(ctx, level, "job finished", slog.String("type", j.Type), slog.String("outcome", outcome),
		slog.Int("attempt", j.Attempt), slog.Int64("duration_ms", dur.Milliseconds()), slog.String("error_code", code))
}

// RecoverExpiredLeases re-queues jobs whose worker died (lease expired).
func (w *Worker) RecoverExpiredLeases(ctx context.Context) error {
	return w.db.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `
with expired as (
  select id, attempts, max_attempts, locked_by from jobs
  where status = 'running' and locked_until < now()
  for update skip locked
), upd as (
  update jobs j set status = case when e.attempts >= e.max_attempts then 'dead' else 'queued' end,
    locked_by = null, locked_until = null, run_after = now(), last_error_code = 'lease_expired',
    finished_at = case when e.attempts >= e.max_attempts then now() else null end
  from expired e where j.id = e.id
  returning j.id, j.attempts, e.locked_by
)
insert into job_attempts (job_id, attempt, worker_id, outcome, error_code, finished_at)
select id, attempts, coalesce(locked_by, 'unknown'), 'lease_expired', 'lease_expired', now() from upd`)
		return err
	})
}

// QueueDepth reports job counts by status (for metrics/admin).
func QueueDepth(ctx context.Context, db *database.DB) (map[string]int64, error) {
	out := map[string]int64{}
	err := db.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select status, count(*) from jobs where status in ('queued','running','dead','failed') group by status`)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var s string
			var n int64
			if err := rows.Scan(&s, &n); err != nil {
				return err
			}
			out[s] = n
		}
		return rows.Err()
	})
	return out, err
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// MarshalResult is a helper for handlers that store a JSON result.
func MarshalResult(v any) json.RawMessage {
	b, _ := json.Marshal(v)
	return b
}
