package jobs

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/database"
)

// schedulerLockKey is the advisory lock for scheduler leadership.
const schedulerLockKey int64 = 7_210_391_004_512

// Periodic is a recurring job definition. Each run is enqueued with a
// time-bucketed dedupe key, so duplicate schedulers or restarts can never
// enqueue the same bucket twice. Handlers process everything due up to
// "now", so a single run after downtime recovers missed buckets.
type Periodic struct {
	Name     string
	Every    time.Duration
	JobType  string
	Priority int
	Payload  any
}

// Scheduler enqueues periodic jobs while holding leadership.
type Scheduler struct {
	db       *database.DB
	periodic []Periodic
	tick     time.Duration
}

// NewScheduler creates a scheduler.
func NewScheduler(db *database.DB, periodic []Periodic) *Scheduler {
	return &Scheduler{db: db, periodic: periodic, tick: 15 * time.Second}
}

// Run competes for leadership and enqueues due buckets until ctx ends.
func (s *Scheduler) Run(ctx context.Context) error {
	for ctx.Err() == nil {
		if err := s.lead(ctx); err != nil && ctx.Err() == nil {
			slog.WarnContext(ctx, "scheduler leadership loop error", slog.Any("error", err))
		}
		select {
		case <-ctx.Done():
		case <-time.After(10 * time.Second):
		}
	}
	return nil
}

func (s *Scheduler) lead(ctx context.Context) error {
	conn, err := s.db.Pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer conn.Release()
	var got bool
	if err := conn.QueryRow(ctx, `select pg_try_advisory_lock($1)`, schedulerLockKey).Scan(&got); err != nil {
		return err
	}
	if !got {
		return nil // another instance leads
	}
	defer func() {
		_, _ = conn.Exec(context.WithoutCancel(ctx), `select pg_advisory_unlock($1)`, schedulerLockKey)
	}()
	slog.InfoContext(ctx, "scheduler leadership acquired")
	t := time.NewTicker(s.tick)
	defer t.Stop()
	for {
		if err := s.EnqueueDue(ctx, time.Now()); err != nil {
			slog.ErrorContext(ctx, "scheduler enqueue failed", slog.Any("error", err))
		}
		// Verify the session (and therefore the lock) is still alive.
		if err := conn.Ping(ctx); err != nil {
			return fmt.Errorf("leadership connection lost: %w", err)
		}
		select {
		case <-ctx.Done():
			return nil
		case <-t.C:
		}
	}
}

// EnqueueDue enqueues the current bucket for each periodic job.
func (s *Scheduler) EnqueueDue(ctx context.Context, now time.Time) error {
	return s.db.WithSystemTx(ctx, func(tx pgx.Tx) error {
		for _, p := range s.periodic {
			bucket := now.UTC().Truncate(p.Every)
			_, _, err := Enqueue(ctx, tx, Spec{
				Type:      p.JobType,
				Payload:   p.Payload,
				RunAfter:  bucket,
				Priority:  p.Priority,
				DedupeKey: fmt.Sprintf("sched:%s:%d", p.Name, bucket.Unix()),
			})
			if err != nil {
				return err
			}
		}
		return nil
	})
}
