// Package outbox implements the transactional outbox: domain writes emit
// events in the same database transaction; the worker relays them into
// durable jobs, so committed changes reliably trigger side effects.
package outbox

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/logging"
)

// Event is a domain event.
type Event struct {
	Type          string
	AggregateType string
	AggregateID   uuid.UUID
	UserID        *uuid.UUID
	GroupID       *uuid.UUID
	Payload       any
}

// Emit records an event inside the caller's transaction.
func Emit(ctx context.Context, q database.Querier, e Event) error {
	payload := []byte("{}")
	if e.Payload != nil {
		b, err := json.Marshal(e.Payload)
		if err != nil {
			return fmt.Errorf("marshal outbox payload: %w", err)
		}
		payload = b
	}
	var agg *uuid.UUID
	if e.AggregateID != uuid.Nil {
		agg = &e.AggregateID
	}
	rid := logging.RequestID(ctx)
	_, err := q.Exec(ctx, `insert into outbox_events (event_type, aggregate_type, aggregate_id, user_id, group_id, payload, request_id)
		values ($1,$2,$3,$4,$5,$6,nullif($7,''))`, e.Type, e.AggregateType, agg, e.UserID, e.GroupID, payload, rid)
	return database.MapError(err)
}

// Stored is an event read by the relay.
type Stored struct {
	ID            int64
	Type          string
	AggregateType string
	AggregateID   *uuid.UUID
	UserID        *uuid.UUID
	GroupID       *uuid.UUID
	Payload       json.RawMessage
	RequestID     string
	CreatedAt     time.Time
}

// Router maps an event to zero or more jobs.
type Router func(e Stored) []jobs.Spec

// Relay moves outbox events into jobs.
type Relay struct {
	db      *database.DB
	routers map[string][]Router
}

// NewRelay creates a relay.
func NewRelay(db *database.DB) *Relay { return &Relay{db: db, routers: map[string][]Router{}} }

// On registers a router for an event type ("*" matches all).
func (r *Relay) On(eventType string, fn Router) {
	r.routers[eventType] = append(r.routers[eventType], fn)
}

// Events lists event types with routers, sorted (documentation, tests).
func (r *Relay) Events() []string {
	out := make([]string, 0, len(r.routers))
	for e := range r.routers {
		out = append(out, e)
	}
	sort.Strings(out)
	return out
}

// Run polls until ctx is cancelled.
func (r *Relay) Run(ctx context.Context) error {
	for ctx.Err() == nil {
		n, err := r.RelayOnce(ctx, 200)
		if err != nil && ctx.Err() == nil {
			slog.ErrorContext(ctx, "outbox relay failed", slog.Any("error", err))
		}
		if n == 0 || err != nil {
			select {
			case <-ctx.Done():
			case <-time.After(time.Second):
			}
		}
	}
	return nil
}

// RelayOnce processes one batch atomically and returns the number relayed.
func (r *Relay) RelayOnce(ctx context.Context, limit int) (int, error) {
	n := 0
	err := r.db.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id, event_type, aggregate_type, aggregate_id, user_id, group_id, payload,
			coalesce(request_id,''), created_at from outbox_events where processed_at is null order by id limit $1 for update skip locked`, limit)
		if err != nil {
			return err
		}
		var batch []Stored
		for rows.Next() {
			var s Stored
			if err := rows.Scan(&s.ID, &s.Type, &s.AggregateType, &s.AggregateID, &s.UserID, &s.GroupID, &s.Payload, &s.RequestID, &s.CreatedAt); err != nil {
				rows.Close()
				return err
			}
			batch = append(batch, s)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		ids := make([]int64, 0, len(batch))
		for _, ev := range batch {
			// Each event routes inside a savepoint so one failing event cannot
			// block the rest of the batch.
			sp, err := tx.Begin(ctx)
			if err != nil {
				return err
			}
			routeErr := func() error {
				for _, route := range append(r.routers[ev.Type], r.routers["*"]...) {
					for _, spec := range route(ev) {
						if spec.CorrelationID == "" {
							spec.CorrelationID = ev.RequestID
						}
						if _, _, err := jobs.Enqueue(ctx, sp, spec); err != nil {
							return err
						}
					}
				}
				return nil
			}()
			if routeErr != nil {
				_ = sp.Rollback(ctx)
				slog.ErrorContext(ctx, "outbox event routing failed", slog.Int64("event_id", ev.ID), slog.String("type", ev.Type), slog.Any("error", routeErr))
				// Dead-letter after repeated failures (processed_at set, error kept).
				if _, err := tx.Exec(ctx, `update outbox_events set attempts = attempts + 1, last_error = $2,
					processed_at = case when attempts + 1 >= 10 then now() else null end where id = $1`, ev.ID, truncateErr(routeErr)); err != nil {
					return err
				}
				continue
			}
			if err := sp.Commit(ctx); err != nil {
				return err
			}
			ids = append(ids, ev.ID)
		}
		if len(ids) > 0 {
			if _, err := tx.Exec(ctx, `update outbox_events set processed_at = now(), attempts = attempts + 1 where id = any($1)`, ids); err != nil {
				return err
			}
		}
		n = len(ids)
		return nil
	})
	return n, err
}

func truncateErr(err error) string {
	s := err.Error()
	if len(s) > 300 {
		s = s[:300]
	}
	return s
}
