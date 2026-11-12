// Package privacy implements data export, account closure and account
// deletion (spec §4.1, §18 "Account deletion", ADR-021/022). Deletion is a
// durable, resumable job: sessions and integrations are revoked, stored
// objects removed, personal records deleted, shared group records retained
// for other members but anonymized, and completion reported.
package privacy

import (
	"archive/zip"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/files"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/platform/ratelimit"
	"montra/backend/internal/platform/storage"
)

// Job types.
const (
	JobExport        = "privacy.export"
	JobDeletionDue   = "privacy.deletion_due"
	JobDeleteAccount = "privacy.delete_account"
)

// Service implements privacy workflows.
type Service struct {
	DB     *database.DB
	Cfg    *config.Config
	Store  storage.Store
	Files  *files.Service
	IPSalt string
	Sender email.Sender
	// Metrics exposes the overdue-deletion backlog (optional).
	Metrics *observability.Metrics
	// Integrations revokes provider access before tokens are deleted
	// (best effort; nil when no integration service is wired).
	Integrations interface {
		RevokeAllForUser(ctx context.Context, uid uuid.UUID) error
	}
}

// ExportDTO is a data export request.
type ExportDTO struct {
	ID          uuid.UUID  `json:"id"`
	Status      string     `json:"status" enum:"queued,running,completed,failed,expired"`
	Format      string     `json:"format"`
	FileID      *uuid.UUID `json:"file_id,omitempty" doc:"Download via GET /files/{file_id}/access when completed"`
	ErrorCode   *string    `json:"error_code,omitempty"`
	RequestedAt time.Time  `json:"requested_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
}

// exportCols reads an export; a completed export whose download window
// passed reads as expired.
const exportCols = `id, case when status = 'completed' and expires_at < now() then 'expired' else status end, format, file_id, error_code,
	requested_at, completed_at, expires_at`

func scanExport(r pgx.Row) (*ExportDTO, error) {
	var e ExportDTO
	err := r.Scan(&e.ID, &e.Status, &e.Format, &e.FileID, &e.ErrorCode, &e.RequestedAt, &e.CompletedAt, &e.ExpiresAt)
	return &e, err
}

// RequestExport queues an export (reusing an in-progress one).
func (s *Service) RequestExport(ctx context.Context) (*ExportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ExportDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		e, err := scanExport(tx.QueryRow(ctx, `select `+exportCols+` from data_exports where user_id = $1 and status in ('queued','running')
			order by requested_at desc limit 1`, uid))
		if err == nil {
			out = e
			return nil
		}
		if !database.IsNoRows(err) {
			return err
		}
		out, err = scanExport(tx.QueryRow(ctx, `insert into data_exports (user_id) values ($1) returning `+exportCols, uid))
		if err != nil {
			return err
		}
		id, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobExport, UserID: &uid, Payload: map[string]string{"export_id": out.ID.String()},
			DedupeKey: "export:" + out.ID.String(), Priority: 120})
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update data_exports set job_id = $2 where id = $1`, out.ID, id); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "data_export", EntityID: &out.ID, Action: "requested"})
	})
	return out, database.MapError(err)
}

// GetExport returns one export.
func (s *Service) GetExport(ctx context.Context, id uuid.UUID) (*ExportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ExportDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out, err = scanExport(tx.QueryRow(ctx, `select `+exportCols+` from data_exports where id = $1 and user_id = $2`, id, uid))
		if database.IsNoRows(err) {
			return apperr.NotFound("export")
		}
		return err
	})
	return out, database.MapError(err)
}

// ListExports lists the caller's exports, newest first.
func (s *Service) ListExports(ctx context.Context) ([]ExportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []ExportDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+exportCols+` from data_exports where user_id = $1 order by requested_at desc, id desc limit 50`, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			e, err := scanExport(rows)
			if err != nil {
				return err
			}
			out = append(out, *e)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// exportSections lists the user's own data. Secrets (password hashes, MFA
// secrets, session/token hashes, provider tokens, push keys) are excluded.
var exportSections = []struct{ name, sql string }{
	{"account", `select to_jsonb(u) - 'email_normalized' from users u where id = $1`},
	{"profile", `select to_jsonb(p) from profiles p where user_id = $1`},
	{"preferences", `select to_jsonb(p) from user_preferences p where user_id = $1`},
	{"consents", `select to_jsonb(c) from user_consents c where user_id = $1`},
	{"sessions", `select to_jsonb(s) - 'access_token_hash' - 'refresh_token_hash' from user_sessions s where user_id = $1`},
	{"security_events", `select to_jsonb(e) from security_events e where user_id = $1`},
	{"accounts", `select to_jsonb(a) from financial_accounts a where user_id = $1`},
	{"payment_methods", `select to_jsonb(p) from payment_methods p where user_id = $1`},
	{"categories", `select to_jsonb(c) from categories c where user_id = $1`},
	{"category_rules", `select to_jsonb(r) from category_rules r where user_id = $1`},
	{"tags", `select to_jsonb(t) from tags t where user_id = $1`},
	{"merchants", `select to_jsonb(m) from merchants m where user_id = $1`},
	{"merchant_aliases", `select to_jsonb(m) from merchant_aliases m where user_id = $1`},
	{"transactions", `select to_jsonb(t) from transactions t where user_id = $1`},
	{"transaction_tags", `select to_jsonb(t) from transaction_tags t where user_id = $1`},
	{"transfers", `select to_jsonb(t) from transfers t where user_id = $1`},
	{"ledger_entries", `select to_jsonb(l) from account_ledger_entries l where user_id = $1`},
	{"transaction_audit", `select to_jsonb(a) from transaction_audit_events a where user_id = $1`},
	{"saved_filters", `select to_jsonb(f) from saved_filters f where user_id = $1`},
	{"fx_rates_manual", `select to_jsonb(r) from fx_rates r where user_id = $1`},
	{"files", `select to_jsonb(f) - 'upload_token_hash' - 'bucket' - 'object_key' from files f where owner_user_id = $1`},
	{"receipts", `select to_jsonb(r) from receipts r where user_id = $1`},
	{"receipt_extractions", `select to_jsonb(r) from receipt_extractions r where user_id = $1`},
	{"receipt_line_items", `select to_jsonb(r) from receipt_line_items r where user_id = $1`},
	{"imports", `select to_jsonb(b) from import_batches b where user_id = $1`},
	{"import_rows", `select to_jsonb(r) - 'raw' from import_rows r where user_id = $1`},
	{"reconciliations", `select to_jsonb(r) from account_reconciliations r where user_id = $1`},
	{"budgets", `select to_jsonb(b) from budgets b where owner_user_id = $1`},
	{"budget_alerts", `select to_jsonb(a) from budget_alerts a where user_id = $1`},
	{"recurring_rules", `select to_jsonb(r) from recurring_rules r where user_id = $1`},
	{"recurring_occurrences", `select to_jsonb(o) from recurring_occurrences o where user_id = $1`},
	{"bills", `select to_jsonb(b) from bills b where user_id = $1`},
	{"subscriptions", `select to_jsonb(s) from subscriptions s where user_id = $1`},
	{"subscription_events", `select to_jsonb(e) from subscription_events e where user_id = $1`},
	{"subscription_payments", `select to_jsonb(p) from subscription_payments p where user_id = $1`},
	{"goals", `select to_jsonb(g) from goals g where owner_user_id = $1`},
	{"goal_contributions", `select to_jsonb(c) from goal_contributions c where user_id = $1`},
	{"group_memberships", `select jsonb_build_object('group_id', m.group_id, 'group_name', g.name, 'role', m.role, 'status', m.status,
		'joined_at', m.joined_at) from group_members m join groups g on g.id = m.group_id where m.user_id = $1`},
	{"group_expense_shares", `select to_jsonb(s) from group_expense_shares s where user_id = $1`},
	{"group_expense_payments", `select to_jsonb(p) from group_expense_payers p where user_id = $1`},
	{"settlements", `select to_jsonb(s) from settlements s where payer_user_id = $1 or payee_user_id = $1`},
	{"friends", `select jsonb_build_object('friend_id', friend_id, 'since', created_at) from user_connections where user_id = $1`},
	{"blocks", `select to_jsonb(b) from user_blocks b where blocker_id = $1`},
	{"community_posts", `select to_jsonb(p) from community_posts p where author_id = $1`},
	{"community_comments", `select to_jsonb(c) from community_comments c where author_id = $1`},
	{"challenge_participation", `select to_jsonb(c) from challenge_participants c where user_id = $1`},
	{"challenge_progress", `select to_jsonb(c) from challenge_progress_events c where user_id = $1`},
	{"notifications", `select to_jsonb(n) from notifications n where user_id = $1`},
	{"notification_preferences", `select to_jsonb(n) from notification_preferences n where user_id = $1`},
	{"ai_conversations", `select to_jsonb(c) from ai_conversations c where user_id = $1`},
	{"ai_messages", `select to_jsonb(m) from ai_messages m where user_id = $1`},
	{"insights", `select to_jsonb(i) from insights i where user_id = $1`},
	{"reports", `select to_jsonb(r) from reports r where user_id = $1`},
	{"search_history", `select to_jsonb(h) from search_history h where user_id = $1`},
	{"audit_events", `select to_jsonb(a) from audit_events a where user_id = $1`},
	{"integration_connections", `select to_jsonb(c) - 'token_ciphertext' - 'oauth_state_hash' from integration_connections c where user_id = $1`},
}

func (s *Service) runExport(ctx context.Context, exportID uuid.UUID) error {
	var uid uuid.UUID
	var status string
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select user_id, status from data_exports where id = $1`, exportID).Scan(&uid, &status)
	})
	if database.IsNoRows(err) || status == "completed" {
		return nil
	}
	if err != nil {
		return err
	}
	if err := s.setExport(ctx, exportID, "running", nil, nil); err != nil {
		return err
	}
	tmp, err := os.CreateTemp("", "montra-export-*.zip")
	if err != nil {
		return err
	}
	defer func() { _ = os.Remove(tmp.Name()) }()
	zw := zip.NewWriter(tmp)
	manifest := map[string]any{"generated_at": time.Now().UTC(), "user_id": uid, "format_version": 1,
		"notes":    "Amounts are integer minor units with ISO 4217 currency codes. Secrets (password hashes, MFA secrets, tokens) are excluded. Stored documents are listed in files.json and can be downloaded from the app.",
		"sections": []string{}}
	err = s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		for _, sec := range exportSections {
			rows, err := tx.Query(ctx, sec.sql, uid)
			if err != nil {
				return fmt.Errorf("export %s: %w", sec.name, err)
			}
			var items []json.RawMessage
			for rows.Next() {
				var b json.RawMessage
				if err := rows.Scan(&b); err != nil {
					rows.Close()
					return err
				}
				items = append(items, b)
			}
			rows.Close()
			if err := rows.Err(); err != nil {
				return err
			}
			if items == nil {
				items = []json.RawMessage{}
			}
			w, err := zw.Create(sec.name + ".json")
			if err != nil {
				return err
			}
			enc := json.NewEncoder(w)
			enc.SetIndent("", "  ")
			if err := enc.Encode(items); err != nil {
				return err
			}
			manifest["sections"] = append(manifest["sections"].([]string), sec.name)
		}
		return nil
	})
	if err != nil {
		code := "export_failed"
		_ = s.setExport(ctx, exportID, "failed", nil, &code)
		return err
	}
	mw, _ := zw.Create("manifest.json")
	_ = json.NewEncoder(mw).Encode(manifest)
	if err := zw.Close(); err != nil {
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	st, _ := os.Stat(tmp.Name())
	key := storage.NewKey()
	if err := s.Store.Put(ctx, storage.AreaExports, key, tmp.Name(), "application/zip"); err != nil {
		return jobs.WithCode("storage_unavailable", err)
	}
	expires := time.Now().Add(s.Cfg.Product.Retention.ExportFiles)
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var fileID uuid.UUID
		if err := tx.QueryRow(ctx, `insert into files (owner_user_id, storage_area, provider, bucket, object_key, purpose, original_filename,
			detected_mime, extension, size_bytes, status, retention_until, scan_status)
			values ($1,'exports',$2,$3,$4,'user_export',$5,'application/zip','zip',$6,'ready',$7,'skipped') returning id`,
			uid, s.Store.Provider(), s.Store.Bucket(storage.AreaExports), key, "montra-export-"+time.Now().UTC().Format("20060102")+".zip",
			st.Size(), expires).Scan(&fileID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update data_exports set status = 'completed', file_id = $2, completed_at = now(), expires_at = $3 where id = $1`,
			exportID, fileID, expires); err != nil {
			return err
		}
		_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "export", EventType: "data_export_ready",
			Title: "Your data export is ready", Body: "Download it from Settings → Privacy before it expires.",
			DeepLink: "/settings/privacy?export=" + exportID.String(), EntityType: "data_export", EntityID: &exportID,
			DedupeKey: "export_ready:" + exportID.String()})
		return err
	})
}

func (s *Service) setExport(ctx context.Context, id uuid.UUID, status string, fileID *uuid.UUID, code *string) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `update data_exports set status = $2, file_id = coalesce($3, file_id), error_code = $4 where id = $1`, id, status, fileID, code)
		return err
	})
}

// GroupImpactDTO is one group the deletion changes: its code and params
// localize the English text.
type GroupImpactDTO struct {
	Code   string            `json:"code" enum:"ownership_transfer,group_deleted"`
	Params map[string]string `json:"params" doc:"group_id, group_name and outcome (ownership_transfer or deleted)"`
	Text   string            `json:"text" doc:"English"`
}

// DeletionDTO is the deletion request status and disclosure.
type DeletionDTO struct {
	ID               *uuid.UUID       `json:"id,omitempty"`
	Status           string           `json:"status" enum:"none,scheduled,cancelled,processing,completed,failed"`
	RequestedAt      *time.Time       `json:"requested_at,omitempty"`
	ScheduledFor     *time.Time       `json:"scheduled_for,omitempty"`
	CompletedAt      *time.Time       `json:"completed_at,omitempty"`
	Consequences     []string         `json:"consequences" doc:"English; localize with consequence_codes (same order)"`
	ConsequenceCodes []string         `json:"consequence_codes" doc:"Stable codes for consequences, same order: signed_out_and_integrations_revoked, personal_records_deleted, documents_removed, profile_removed_posts_anonymized, irreversible_after_date"`
	Retained         []string         `json:"retained" doc:"Records kept after deletion and why (English; localize with retained_codes, same order)"`
	RetainedCodes    []string         `json:"retained_codes" doc:"Stable codes for retained, same order: shared_group_records_anonymized, security_audit_records_retained"`
	GroupImpact      []string         `json:"group_impact" doc:"English; see group_impact_details"`
	GroupImpactItems []GroupImpactDTO `json:"group_impact_details" doc:"Groups you own, with codes and params (same order as group_impact)"`
}

var consequences = []string{
	"You will be signed out of every device and all active integrations will be revoked.",
	"Your accounts, transactions, budgets, goals, subscriptions, receipts, imports, reports and AI history will be permanently deleted.",
	"Uploaded documents will be removed from storage.",
	"Your profile will be removed; community posts and comments will be anonymized.",
	"This cannot be undone after the scheduled date.",
}

var consequenceCodes = []string{"signed_out_and_integrations_revoked", "personal_records_deleted", "documents_removed",
	"profile_removed_posts_anonymized", "irreversible_after_date"}

var retained = []string{
	"Shared group expense shares and settlements remain so other members' balances stay correct; your name is replaced with \"Deleted member\".",
	"Security and audit records are kept in anonymized form for the documented retention period to meet legal and fraud-prevention obligations.",
}

var retainedCodes = []string{"shared_group_records_anonymized", "security_audit_records_retained"}

// DeletionStatus returns the latest deletion request.
func (s *Service) DeletionStatus(ctx context.Context) (*DeletionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &DeletionDTO{Status: "none", Consequences: consequences, ConsequenceCodes: consequenceCodes, Retained: retained, RetainedCodes: retainedCodes,
		GroupImpact: []string{}, GroupImpactItems: []GroupImpactDTO{}}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var id uuid.UUID
		var st string
		var req, sch time.Time
		var done *time.Time
		err := tx.QueryRow(ctx, `select id, status, requested_at, scheduled_for, completed_at from account_deletion_requests
			where user_id = $1 order by requested_at desc limit 1`, uid).Scan(&id, &st, &req, &sch, &done)
		if err == nil {
			out.ID, out.Status, out.RequestedAt, out.ScheduledFor, out.CompletedAt = &id, st, &req, &sch, done
		} else if !database.IsNoRows(err) {
			return err
		}
		out.GroupImpactItems, err = groupImpact(ctx, tx, uid)
		for _, g := range out.GroupImpactItems {
			out.GroupImpact = append(out.GroupImpact, g.Text)
		}
		return err
	})
	return out, database.MapError(err)
}

// groupImpact describes ownership transfers deletion would cause.
func groupImpact(ctx context.Context, tx pgx.Tx, uid uuid.UUID) ([]GroupImpactDTO, error) {
	rows, err := tx.Query(ctx, `select g.id, g.name, (select count(*) from group_members o where o.group_id = g.id and o.status = 'active' and o.user_id <> $1)
		from group_members m join groups g on g.id = m.group_id
		where m.user_id = $1 and m.status = 'active' and m.role = 'owner' and g.status = 'active' order by g.name, g.id`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []GroupImpactDTO{}
	for rows.Next() {
		var id uuid.UUID
		var name string
		var others int
		if err := rows.Scan(&id, &name, &others); err != nil {
			return nil, err
		}
		g := GroupImpactDTO{Params: map[string]string{"group_id": id.String(), "group_name": name}}
		if others > 0 {
			g.Code, g.Params["outcome"] = "ownership_transfer", "ownership_transfer"
			g.Text = fmt.Sprintf("Ownership of %q will transfer to its longest-standing admin or member.", name)
		} else {
			g.Code, g.Params["outcome"] = "group_deleted", "deleted"
			g.Text = fmt.Sprintf("%q has no other members and will be deleted.", name)
		}
		out = append(out, g)
	}
	return out, rows.Err()
}

// RequestDeletion schedules account deletion after the grace period.
func (s *Service) RequestDeletion(ctx context.Context, confirm, reason string) (*DeletionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if confirm != "DELETE" {
		return nil, apperr.FieldError("body.confirm", `Type DELETE to confirm.`)
	}
	when := time.Now().Add(s.Cfg.Product.Retention.DeletionGrace)
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var id uuid.UUID
		err := tx.QueryRow(ctx, `insert into account_deletion_requests (user_id, reason, scheduled_for, exceptions)
			values ($1, nullif($2,''), $3, $4) returning id`, uid, strings.TrimSpace(reason), when, mustJSON(retained)).Scan(&id)
		if database.IsUniqueViolation(err, "deletion_one_open") {
			return apperr.Conflict("A deletion request is already scheduled.")
		}
		if err != nil {
			return err
		}
		if err := audit.Security(ctx, tx, s.IPSalt, audit.SecurityEvent{UserID: &uid, Type: "account_deletion_requested", Severity: "warning"}); err != nil {
			return err
		}
		_, _, err = notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "account", EventType: "deletion_scheduled",
			Title: "Account deletion scheduled", Body: "Your account will be deleted on " + when.UTC().Format("2 Jan 2006") + ". You can cancel before then.",
			DeepLink: "/settings/privacy", Priority: "high", DedupeKey: "deletion_scheduled:" + id.String()})
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.DeletionStatus(ctx)
}

// CancelDeletion cancels a scheduled deletion.
func (s *Service) CancelDeletion(ctx context.Context) (*DeletionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update account_deletion_requests set status = 'cancelled', cancelled_at = now()
			where user_id = $1 and status = 'scheduled'`, uid)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.Conflict("There is no scheduled deletion to cancel.")
		}
		return audit.Security(ctx, tx, s.IPSalt, audit.SecurityEvent{UserID: &uid, Type: "account_deletion_cancelled"})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.DeletionStatus(ctx)
}

// Deactivate closes the account reversibly (signing in again reactivates).
func (s *Service) Deactivate(ctx context.Context) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `update users set status = 'deactivated', deactivated_at = now() where id = $1 and status = 'active'`, uid); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update user_sessions set revoked_at = now(), revoked_reason = 'logout_all' where user_id = $1 and revoked_at is null`, uid); err != nil {
			return err
		}
		return audit.Security(ctx, tx, s.IPSalt, audit.SecurityEvent{UserID: &uid, Type: "account_deactivated", Severity: "warning"})
	}))
}

func mustJSON(v any) []byte {
	b, _ := json.Marshal(v)
	return b
}

// RegisterJobs registers worker handlers.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobExport, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ExportID uuid.UUID `json:"export_id"`
		}
		if err := j.Decode(&p); err != nil {
			return err
		}
		return s.runExport(ctx, p.ExportID)
	}, jobs.WithTimeout(10*time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobDeletionDue, func(ctx context.Context, _ jobs.Job) error {
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			rows, err := tx.Query(ctx, `select id, user_id from account_deletion_requests where status in ('scheduled','processing') and scheduled_for <= now() limit 100`)
			if err != nil {
				return err
			}
			type due struct{ id, user uuid.UUID }
			var list []due
			for rows.Next() {
				var d due
				if err := rows.Scan(&d.id, &d.user); err != nil {
					rows.Close()
					return err
				}
				list = append(list, d)
			}
			rows.Close()
			if s.Metrics != nil {
				var backlog int
				if err := tx.QueryRow(ctx, `select count(*) from account_deletion_requests where status in ('scheduled','processing')
					and scheduled_for <= now() - interval '1 hour'`).Scan(&backlog); err == nil {
					s.Metrics.DeletionBacklog.Set(float64(backlog))
				}
			}
			for _, d := range list {
				uid := d.user
				if _, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobDeleteAccount, UserID: &uid, Payload: map[string]string{"request_id": d.id.String()},
					DedupeKey: "delete_account:" + d.id.String(), MaxAttempts: 20, Priority: 60}); err != nil {
					return err
				}
			}
			return rows.Err()
		})
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(1))
	reg.Register(JobDeleteAccount, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			RequestID uuid.UUID `json:"request_id"`
		}
		if err := j.Decode(&p); err != nil {
			return err
		}
		return s.deleteAccount(ctx, p.RequestID)
	}, jobs.WithTimeout(15*time.Minute), jobs.WithConcurrency(2))
}

// deleteAccount performs the durable deletion workflow. Every step is
// idempotent so retries resume safely.
func (s *Service) deleteAccount(ctx context.Context, requestID uuid.UUID) error {
	var uid uuid.UUID
	var status, addr, locale string
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select r.user_id, r.status, u.email, coalesce(pr.locale, 'en') from account_deletion_requests r
			join users u on u.id = r.user_id left join user_preferences pr on pr.user_id = u.id where r.id = $1`, requestID).Scan(&uid, &status, &addr, &locale)
	})
	if database.IsNoRows(err) || status == "completed" || status == "cancelled" {
		return nil
	}
	if err != nil {
		return err
	}
	step := func(name string, fn func(tx pgx.Tx) error) error {
		err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			if err := fn(tx); err != nil {
				return err
			}
			_, err := tx.Exec(ctx, `update account_deletion_requests set steps = steps || jsonb_build_object($2::text, now()) where id = $1`, requestID, name)
			return err
		})
		if err != nil {
			slog.ErrorContext(ctx, "account deletion step failed", slog.String("step", name), slog.Any("error", err))
			return jobs.WithCode("deletion_step_"+name, err)
		}
		return nil
	}
	// 1. Revoke provider access while tokens still exist (best effort:
	// local access ends below regardless), then block access.
	if s.Integrations != nil {
		if err := s.Integrations.RevokeAllForUser(ctx, uid); err != nil {
			slog.WarnContext(ctx, "provider revoke during deletion failed", slog.String("error_code", "integration_revoke_failed"))
		}
	}
	if err := step("block_access", func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `update account_deletion_requests set status = 'processing', started_at = coalesce(started_at, now()) where id = $1`, requestID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update users set status = 'pending_deletion' where id = $1 and status <> 'deleted'`, uid); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update user_sessions set revoked_at = now(), revoked_reason = 'account_deleted' where user_id = $1 and revoked_at is null`, uid); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `delete from push_endpoints where user_id = $1`, uid); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `update integration_connections set status = 'revoked', consent_revoked_at = now(), token_ciphertext = null
			where user_id = $1`, uid)
		return err
	}); err != nil {
		return err
	}
	// 2. Remove stored objects (Appwrite in hosted environments).
	if _, err := s.Files.PurgeUserFiles(ctx, uid); err != nil {
		return jobs.WithCode("deletion_files", err)
	}
	// 3. Group ownership transfer / archival (ADR-022).
	if err := step("groups", func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select group_id from group_members where user_id = $1 and role = 'owner' and status = 'active'`, uid)
		if err != nil {
			return err
		}
		var owned []uuid.UUID
		for rows.Next() {
			var g uuid.UUID
			if err := rows.Scan(&g); err != nil {
				rows.Close()
				return err
			}
			owned = append(owned, g)
		}
		rows.Close()
		for _, g := range owned {
			var heir *uuid.UUID
			err := tx.QueryRow(ctx, `select user_id from group_members where group_id = $1 and status = 'active' and user_id <> $2
				order by (role = 'admin') desc, joined_at asc limit 1`, g, uid).Scan(&heir)
			if database.IsNoRows(err) {
				if _, err := tx.Exec(ctx, `update groups set status = 'deleted', deleted_at = now() where id = $1`, g); err != nil {
					return err
				}
			} else if err != nil {
				return err
			} else {
				if _, err := tx.Exec(ctx, `update group_members set role = 'member', status = 'left', left_at = now() where group_id = $1 and user_id = $2`, g, uid); err != nil {
					return err
				}
				if _, err := tx.Exec(ctx, `update group_members set role = 'owner' where group_id = $1 and user_id = $2`, g, *heir); err != nil {
					return err
				}
				if _, err := tx.Exec(ctx, `insert into group_activity_events (group_id, kind, entity_type, summary) values ($1,'ownership_transferred','group',
					jsonb_build_object('reason','account_deleted'))`, g); err != nil {
					return err
				}
			}
		}
		_, err = tx.Exec(ctx, `update group_members set status = 'left', left_at = coalesce(left_at, now()), display_name_snapshot = 'Deleted member'
			where user_id = $1`, uid)
		return err
	}); err != nil {
		return err
	}
	// 4. Delete personal records (children cascade) and anonymize community content.
	if err := step("personal_data", func(tx pgx.Tx) error {
		for _, q := range []string{
			// Shared (group-scoped) planning records stay with the group: reassign to its owner.
			`update budgets b set owner_user_id = m.user_id from group_members m where b.owner_user_id = $1 and b.group_id is not null
				and m.group_id = b.group_id and m.role = 'owner' and m.status = 'active' and m.user_id <> $1`,
			`update goals g set owner_user_id = m.user_id from group_members m where g.owner_user_id = $1 and g.group_id is not null
				and m.group_id = g.group_id and m.role = 'owner' and m.status = 'active' and m.user_id <> $1`,
			`update bills b set user_id = m.user_id, payment_account_id = null from group_members m where b.user_id = $1 and b.group_id is not null
				and m.group_id = b.group_id and m.role = 'owner' and m.status = 'active' and m.user_id <> $1`,
			`update recurring_rules r set user_id = m.user_id, account_id = null, to_account_id = null, payment_method_id = null, category_id = null, merchant_id = null
				from group_members m where r.user_id = $1 and r.group_id is not null and m.group_id = r.group_id and m.role = 'owner' and m.status = 'active' and m.user_id <> $1`,
			`update recurring_occurrences o set user_id = r.user_id from recurring_rules r where o.rule_id = r.id and o.user_id = $1 and r.user_id <> $1`,
			`update subscriptions s set user_id = m.user_id, payment_account_id = null, payment_method_id = null, merchant_id = null, category_id = null
				from group_members m where s.user_id = $1 and s.group_id is not null and m.group_id = s.group_id and m.role = 'owner' and m.status = 'active' and m.user_id <> $1`,
			`delete from reconciliation_matches where user_id = $1`,
			`delete from import_batches where user_id = $1`,
			`delete from receipts where user_id = $1`,
			`delete from goals where owner_user_id = $1`,
			`delete from budget_alerts where user_id = $1`,
			`delete from budgets where owner_user_id = $1`,
			`delete from bills where user_id = $1`,
			`delete from subscriptions where user_id = $1`,
			`delete from subscription_detection_candidates where user_id = $1`,
			`update transactions set recurring_rule_id = null, recurring_occurrence_id = null where user_id = $1`,
			`delete from recurring_occurrences where user_id = $1`,
			`delete from recurring_rules where user_id = $1`,
			`delete from transfers where user_id = $1`,
			`update financial_accounts set opening_transaction_id = null where user_id = $1`,
			`delete from transactions where user_id = $1`,
			`delete from category_rules where user_id = $1`,
			`delete from merchant_aliases where user_id = $1`,
			`update categories set merged_into_id = null where user_id = $1`,
			`delete from merchants where user_id = $1`,
			`delete from payment_methods where user_id = $1`,
			`update user_preferences set default_account_id = null where user_id = $1`,
			`delete from financial_accounts where user_id = $1`,
			`delete from categories where user_id = $1 and parent_id is not null`,
			`delete from categories where user_id = $1`,
			`delete from tags where user_id = $1`,
			`delete from saved_filters where user_id = $1`,
			`delete from fx_rates where user_id = $1`,
			`delete from notifications where user_id = $1`,
			`delete from notification_preferences where user_id = $1`,
			`delete from ai_conversations where user_id = $1`,
			`delete from insights where user_id = $1`,
			`delete from insight_mutes where user_id = $1`,
			`delete from reports where user_id = $1`,
			`delete from scheduled_reports where user_id = $1`,
			`delete from search_history where user_id = $1`,
			`delete from data_exports where user_id = $1`,
			`delete from integration_connections where user_id = $1`,
			`delete from user_connections where user_id = $1 or friend_id = $1`,
			`delete from friend_requests where requester_id = $1 or addressee_id = $1`,
			`delete from user_blocks where blocker_id = $1 or blocked_id = $1`,
			`delete from user_mutes where muter_id = $1 or muted_id = $1`,
			`delete from community_reactions where user_id = $1`,
			`delete from community_poll_votes where user_id = $1`,
			`delete from challenge_progress_events where user_id = $1`,
			`delete from challenge_participants where user_id = $1`,
			`update community_members set status = 'left' where user_id = $1`,
			`update community_posts set author_id = null, title = '[deleted]', body = '[deleted by user]', link_url = null, status = 'deleted' where author_id = $1`,
			`update community_comments set author_id = null, body = '[deleted by user]', status = 'deleted' where author_id = $1`,
			`delete from mfa_recovery_codes where user_id = $1`,
			`delete from mfa_factors where user_id = $1`,
			`delete from auth_tokens where user_id = $1`,
			`delete from user_credentials where user_id = $1`,
			`delete from dashboard_widgets where user_id = $1`,
		} {
			if _, err := tx.Exec(ctx, q, uid); err != nil {
				return fmt.Errorf("%s: %w", strings.Fields(q)[2], err)
			}
		}
		return nil
	}); err != nil {
		return err
	}
	// 5. Notify the original address, then anonymize identity.
	if msg, err := email.Build(email.TplDeletionDone, locale, addr, email.Data{}); err == nil && s.Sender != nil {
		if err := s.Sender.Send(ctx, msg); err != nil && !strings.Contains(err.Error(), "not configured") {
			return jobs.WithCode("deletion_email", err)
		}
	}
	return step("anonymize", func(tx pgx.Tx) error {
		anon := fmt.Sprintf("deleted+%s@deleted.montra.invalid", uid)
		if _, err := tx.Exec(ctx, `update users set email = $2, email_normalized = $2, status = 'deleted', deleted_at = now(), email_verified_at = null
			where id = $1`, uid, anon); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update profiles set display_name = 'Deleted member', username = null, bio = null, interests = '{}',
			coarse_location = null, avatar_file_id = null, profile_visibility = 'private', discoverable_by_username = false where user_id = $1`, uid); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `delete from user_consents where user_id = $1`, uid); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update user_sessions set user_agent = null, ip_hash = null, device_name = null where user_id = $1`, uid); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `update account_deletion_requests set status = 'completed', completed_at = now(), reason = null where id = $1`, requestID)
		return err
	})
}

// Routes mounts privacy endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Privacy"
	httpx.Protected(api, httpx.Accepted(httpx.Reauth(httpx.Rate(httpx.Op("me-export-request", http.MethodPost, "/me/export",
		"Request a full data export", tag), ratelimit.Export.Name))),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[ExportDTO], error) {
			e, err := s.RequestExport(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *e), nil
		})
	httpx.Protected(api, httpx.Op("me-exports-list", http.MethodGet, "/me/exports", "Your data exports, newest first, with status and expiry", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]ExportDTO], error) {
			l, err := s.ListExports(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("me-export-get", http.MethodGet, "/me/export/{exportId}", "Get data export status", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"exportId"`
		}) (*httpx.Response[ExportDTO], error) {
			e, err := s.GetExport(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *e), nil
		})
	httpx.Protected(api, httpx.Reauth(httpx.Op("me-deletion-request", http.MethodPost, "/me/deletion-request",
		"Schedule account deletion (requires recent re-authentication)", tag)),
		func(ctx context.Context, in *struct {
			Body struct {
				Confirm string `json:"confirm" doc:"Must be DELETE"`
				Reason  string `json:"reason,omitempty" maxLength:"1000"`
			}
		}) (*httpx.Response[DeletionDTO], error) {
			d, err := s.RequestDeletion(ctx, in.Body.Confirm, in.Body.Reason)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, httpx.Op("me-deletion-status", http.MethodGet, "/me/deletion-request", "Deletion status, consequences and retention disclosure", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[DeletionDTO], error) {
			d, err := s.DeletionStatus(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, httpx.Op("me-deletion-cancel", http.MethodDelete, "/me/deletion-request", "Cancel a scheduled deletion", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[DeletionDTO], error) {
			d, err := s.CancelDeletion(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, httpx.Reauth(httpx.Op("me-deactivate", http.MethodPost, "/me/deactivate",
		"Close the account (reversible by signing in again)", tag)),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[httpx.Empty], error) {
			if err := s.Deactivate(ctx); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
}
