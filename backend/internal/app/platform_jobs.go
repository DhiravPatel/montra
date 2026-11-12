package app

import (
	"context"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"

	"montra/backend/internal/budgets"
	"montra/backend/internal/challenges"
	"montra/backend/internal/communities"
	"montra/backend/internal/goals"
	"montra/backend/internal/groups"
	"montra/backend/internal/moderation"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/outbox"
	"montra/backend/internal/social"
)

// RegisterPlatformJobs registers cross-cutting maintenance jobs.
func RegisterPlatformJobs(reg *jobs.Registry, d Deps) {
	reg.Register(JobRetentionCleanup, func(ctx context.Context, _ jobs.Job) error {
		return retentionCleanup(ctx, d)
	}, jobs.WithTimeout(10*time.Minute), jobs.WithConcurrency(1))
}

// RegisterOutboxRoutes maps domain events to jobs. Feature packages add
// their routes here as they are implemented.
func RegisterOutboxRoutes(relay *outbox.Relay) {
	budgets.Routes(relay)
	goals.OutboxRoutes(relay)
	groups.OutboxRoutes(relay)
	social.OutboxRoutes(relay)
	communities.OutboxRoutes(relay)
	moderation.OutboxRoutes(relay)
	challenges.OutboxRoutes(relay)
}

// retentionCleanup enforces retention windows (ADR-021) in bounded batches.
func retentionCleanup(ctx context.Context, d Deps) error {
	r := d.Cfg.Product.Retention
	stmts := []struct {
		name string
		sql  string
		arg  any
	}{
		{"login_attempts", `delete from login_attempts where attempted_at < now() - interval '2 days'`, nil},
		{"auth_tokens", `delete from auth_tokens where expires_at < now() - interval '7 days'`, nil},
		{"idempotency_keys", `delete from idempotency_keys where expires_at < now()`, nil},
		{"refresh_history", `delete from user_session_refresh_history h using user_sessions s
			where h.session_id = s.id and (s.revoked_at < now() - interval '30 days' or s.absolute_expires_at < now() - interval '30 days')`, nil},
		{"sessions", `delete from user_sessions where (revoked_at is not null and revoked_at < now() - interval '90 days')
			or absolute_expires_at < now() - interval '90 days'`, nil},
		{"security_events", `delete from security_events where created_at < now() - make_interval(secs => $1)`, r.SecurityEvents.Seconds()},
		{"jobs", `delete from jobs where status in ('succeeded','cancelled') and finished_at < now() - interval '14 days'`, nil},
		{"outbox", `delete from outbox_events where processed_at < now() - interval '7 days'`, nil},
		{"reports", `update reports set status = 'expired' where status = 'completed' and expires_at < now()`, nil},
		// Webhook inbox: encrypted provider payloads kept 30 days for investigation.
		{"webhook_events", `delete from integration_webhook_events where received_at < now() - interval '30 days' and status <> 'received'`, nil},
		{"integration_sync_runs", `delete from integration_sync_runs where finished_at < now() - interval '180 days'`, nil},
		// AI conversation history (messages cascade).
		{"ai_history", `delete from ai_conversations where id in (select id from ai_conversations
			where updated_at < now() - make_interval(secs => $1) limit 5000)`, r.AIHistory.Seconds()},
		// Raw statement cells of finished imports; parsed values, links and
		// fingerprints stay for traceability and duplicate detection.
		{"import_raw_rows", `update import_rows set raw = '[]'::jsonb where id in (select r.id from import_rows r join import_batches b on b.id = r.batch_id
			where r.raw <> '[]'::jsonb and b.created_at < now() - make_interval(secs => $1)
			and b.status in ('completed','completed_with_errors','failed','cancelled') limit 5000)`, r.ImportRawRows.Seconds()},
	}
	for _, st := range stmts {
		err := d.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			var err error
			if st.arg != nil {
				_, err = tx.Exec(ctx, st.sql, st.arg)
			} else {
				_, err = tx.Exec(ctx, st.sql)
			}
			return err
		})
		if err != nil {
			slog.ErrorContext(ctx, "retention step failed", slog.String("step", st.name), slog.Any("error", err))
			return err
		}
	}
	return nil
}
