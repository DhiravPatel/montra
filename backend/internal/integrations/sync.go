package integrations

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/finance"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/breaker"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
)

// maxPages bounds one sync run (the cursor resumes the rest next time).
const maxPages = 20

// RegisterJobs registers integration jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobSync, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			RunID uuid.UUID `json:"run_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.sync(ctx, p.RunID)
	}, jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobWebhook, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			EventID uuid.UUID `json:"event_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.processWebhook(ctx, p.EventID)
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobSchedule, func(ctx context.Context, _ jobs.Job) error { return s.Schedule(ctx) },
		jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(1))
}

// JobSchedule expires lapsed consents and queues scheduled syncs.
const JobSchedule = "integrations.schedule"

// syncEvery is how stale a connection gets before a scheduled sync.
const syncEvery = 6 * time.Hour

// Schedule recovers abandoned runs, marks connections whose consent lapsed
// (and tells the owner) and queues a sync for connections not synced
// recently. It is the periodic job; exported for operations and tests.
func (s *Service) Schedule(ctx context.Context) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		// Runs abandoned by a crashed worker would block syncs forever.
		if _, err := tx.Exec(ctx, `with stuck as (update integration_sync_runs set status = 'failed', error_code = 'timed_out', finished_at = now()
				where status in ('queued','running') and created_at < $1 returning connection_id)
			update integration_connections set status = 'failed', last_error_code = 'sync_timed_out' where status = 'syncing'
				and id in (select connection_id from stuck)`, s.now().Add(-2*time.Hour)); err != nil {
			return err
		}
		// Verified webhook events still waiting (their job was lost) are re-queued.
		waiting, err := tx.Query(ctx, `select id from integration_webhook_events where status = 'received' and signature_valid
			and received_at < $1 order by received_at limit 500`, s.now().Add(-5*time.Minute))
		if err != nil {
			return err
		}
		events, err := pgx.CollectRows(waiting, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, id := range events {
			if _, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobWebhook, Payload: map[string]any{"event_id": id},
				DedupeKey: "webhook:" + id.String() + ":" + s.now().UTC().Format("2006010215"), Priority: 100}); err != nil {
				return err
			}
		}
		rows, err := tx.Query(ctx, `update integration_connections set status = 'consent_expired', last_error_code = 'consent_expired'
			where status in ('connected','partial','failed') and consent_expires_at is not null and consent_expires_at < $1
			returning id, user_id, provider`, s.now())
		if err != nil {
			return err
		}
		type expired struct {
			id, user uuid.UUID
			provider string
		}
		var gone []expired
		for rows.Next() {
			var e expired
			if err := rows.Scan(&e.id, &e.user, &e.provider); err != nil {
				rows.Close()
				return err
			}
			gone = append(gone, e)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		for _, e := range gone {
			if err := notifyConsentExpired(ctx, tx, e.user, e.id); err != nil {
				return err
			}
		}
		due, err := tx.Query(ctx, `select c.id, c.user_id, c.provider from integration_connections c where c.status in ('connected','partial')
			and (c.last_sync_at is null or c.last_sync_at < $1)
			and not exists (select 1 from integration_sync_runs r where r.connection_id = c.id and r.status in ('queued','running'))
			order by c.last_sync_at nulls first limit 1000`, s.now().Add(-syncEvery))
		if err != nil {
			return err
		}
		var queue []expired
		for due.Next() {
			var e expired
			if err := due.Scan(&e.id, &e.user, &e.provider); err != nil {
				due.Close()
				return err
			}
			queue = append(queue, e)
		}
		due.Close()
		if err := due.Err(); err != nil {
			return err
		}
		for _, e := range queue {
			if _, ok := s.adapter(e.provider); !ok {
				continue
			}
			if _, err := s.enqueueSync(ctx, tx, e.user, e.id, "scheduled"); err != nil {
				return err
			}
		}
		return nil
	})
}

// notifyConsentExpired tells the owner a connection stopped because its
// consent lapsed (no provider data in the message).
func notifyConsentExpired(ctx context.Context, tx pgx.Tx, uid, connID uuid.UUID) error {
	id := connID
	_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "account", EventType: "integration.consent_expired",
		Title: "A connection needs renewing", Body: "Your consent for a connected account expired, so syncing stopped. Reconnect to continue.",
		DeepLink: "/settings/integrations", EntityType: "integration_connection", EntityID: &id, Priority: "normal",
		DedupeKey: "integration_consent_expired:" + connID.String()})
	return err
}

type connRow struct {
	id, user  uuid.UUID
	provider  string
	status    string
	ct        []byte
	kid       *string
	cursor    *string
	account   *uuid.UUID
	consentTo *time.Time
	currency  string
}

// sync fetches provider pages and records transactions idempotently:
// external IDs dedupe repeats, pending→posted updates in place, reversed
// items are voided, and consent expiry stops the connection.
func (s *Service) sync(ctx context.Context, runID uuid.UUID) error {
	var c connRow
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx, `select r.status, c.id, c.user_id, c.provider, c.status, c.token_ciphertext, c.token_key_id, c.sync_cursor,
			c.linked_account_id, c.consent_expires_at, coalesce(a.currency, '')
			from integration_sync_runs r join integration_connections c on c.id = r.connection_id left join financial_accounts a on a.id = c.linked_account_id
			where r.id = $1 for update of r`, runID).Scan(&status, &c.id, &c.user, &c.provider, &c.status, &c.ct, &c.kid, &c.cursor, &c.account,
			&c.consentTo, &c.currency); err != nil {
			return err
		}
		if status != "queued" && status != "running" {
			c.id = uuid.Nil
			return nil
		}
		_, err := tx.Exec(ctx, `update integration_sync_runs set status = 'running', started_at = coalesce(started_at, now()), cursor_before = $2
			where id = $1`, runID, c.cursor)
		if err == nil {
			_, err = tx.Exec(ctx, `update integration_connections set status = 'syncing' where id = $1 and status in ('connected','partial','failed')`, c.id)
		}
		return err
	})
	if database.IsNoRows(err) || (err == nil && c.id == uuid.Nil) {
		return nil
	}
	if err != nil {
		return err
	}
	finish := func(status, code string, counts [4]int, cursor *string, connStatus string) error {
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			if _, err := tx.Exec(ctx, `update integration_sync_runs set status = $2, error_code = nullif($3, ''), finished_at = now(), items_fetched = $4,
				items_created = $5, items_updated = $6, items_skipped = $7, cursor_after = $8 where id = $1`, runID, status, code, counts[0], counts[1], counts[2],
				counts[3], cursor); err != nil {
				return err
			}
			tag, err := tx.Exec(ctx, `update integration_connections set status = $2, last_sync_at = now(), last_sync_status = $3, last_error_code = nullif($4, ''),
				sync_cursor = coalesce($5, sync_cursor) where id = $1 and status not in ('revoked','disconnected','consent_expired')`, c.id, connStatus, status, code,
				cursor)
			if err != nil || tag.RowsAffected() == 0 || connStatus != "consent_expired" {
				return err
			}
			return notifyConsentExpired(ctx, tx, c.user, c.id)
		})
	}
	a, ok := s.adapter(c.provider)
	if !ok || c.ct == nil || c.kid == nil || c.account == nil {
		return finish("failed", "provider_unavailable", [4]int{}, nil, "failed")
	}
	if c.consentTo != nil && s.now().After(*c.consentTo) {
		return finish("failed", "consent_expired", [4]int{}, nil, "consent_expired")
	}
	tok, err := s.openToken(c.id, c.ct, *c.kid)
	if err != nil {
		return finish("failed", "token_unreadable", [4]int{}, nil, "failed")
	}
	if !tok.Expires.IsZero() && s.now().After(tok.Expires.Add(-time.Minute)) {
		nt, err := a.Refresh(ctx, tok)
		if errors.Is(err, ErrConsentExpired) {
			return finish("failed", "consent_expired", [4]int{}, nil, "consent_expired")
		}
		if err != nil {
			return fmt.Errorf("refresh: %w", err) // retried by the job
		}
		ct, kid, err := s.sealToken(c.id, nt)
		if err != nil {
			return err
		}
		if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			_, err := tx.Exec(ctx, `update integration_connections set token_ciphertext = $2, token_key_id = $3, token_expires_at = $4 where id = $1`,
				c.id, ct, kid, nullTime(nt.Expires))
			return err
		}); err != nil {
			return err
		}
		tok = nt
	}
	cursor := ""
	if c.cursor != nil {
		cursor = *c.cursor
	}
	var counts [4]int
	uctx := identity.With(ctx, identity.Principal{UserID: c.user})
	for page := 0; page < maxPages; page++ {
		b, err := a.Fetch(ctx, tok, cursor)
		if errors.Is(err, ErrConsentExpired) {
			return finish("failed", "consent_expired", counts, &cursor, "consent_expired")
		}
		if breaker.IsOpen(err) && counts[0] == 0 {
			// The provider is known to be failing and nothing was fetched:
			// leave the run running and let the job retry after a backoff.
			return fmt.Errorf("fetch: %w", err)
		}
		if err != nil {
			status := "failed"
			if counts[0] > 0 {
				status = "partial"
			}
			return finish(status, "provider_error", counts, &cursor, map[bool]string{true: "partial", false: "failed"}[counts[0] > 0])
		}
		for _, t := range b.Transactions {
			counts[0]++
			res, err := s.apply(uctx, c, t)
			if err != nil {
				counts[3]++
				continue
			}
			switch res {
			case "created":
				counts[1]++
			case "updated":
				counts[2]++
			default:
				counts[3]++
			}
		}
		cursor = b.NextCursor
		if !b.HasMore {
			break
		}
	}
	return finish("succeeded", "", counts, &cursor, "connected")
}

// apply records one provider transaction (as the owner, so normal
// validation, ledger, audit and events apply).
func (s *Service) apply(ctx context.Context, c connRow, t ProviderTx) (string, error) {
	if t.ID == "" || len(t.ID) > 100 {
		return "skipped", errors.New("bad id")
	}
	if t.Currency != "" && !strings.EqualFold(t.Currency, c.currency) {
		return "skipped", errors.New("currency mismatch")
	}
	ext := c.provider + ":" + c.id.String() + ":" + t.ID
	amount := strings.TrimSpace(t.Amount)
	typ := "expense"
	if strings.HasPrefix(amount, "-") {
		amount = strings.TrimPrefix(amount, "-")
	} else {
		typ = "income"
	}
	status := "posted"
	if t.Status == "pending" {
		status = "pending"
	}
	var result string
	err := s.DB.WithUserTx(ctx, c.user, func(tx pgx.Tx) error {
		// Voided rows count as seen: a transaction the user deleted (or the
		// provider reversed) is never re-created by a later sync.
		var existing uuid.UUID
		var deleted bool
		err := tx.QueryRow(ctx, `select id, deleted_at is not null from transactions where user_id = $1 and account_id = $2 and external_id = $3
			order by (deleted_at is null) desc, created_at desc limit 1`, c.user, *c.account, ext).Scan(&existing, &deleted)
		switch {
		case err == nil:
			result = "skipped" // already recorded (replayed page or webhook)
			if deleted {
				return nil
			}
			var changed bool
			var err error
			switch {
			case t.Status == "reversed":
				changed, err = s.Finance.ProviderVoidInTx(ctx, tx, c.user, existing)
			case status == "posted":
				changed, err = s.Finance.ProviderPostInTx(ctx, tx, c.user, existing)
			}
			if changed {
				result = "updated"
			}
			return err
		case !database.IsNoRows(err):
			return err
		}
		if t.Status == "reversed" {
			result = "skipped"
			return nil
		}
		desc := clip(strings.ToValidUTF8(strings.TrimSpace(t.Description), ""), 500)
		id := ext
		_, err = s.Finance.CreateInTx(ctx, tx, c.user, finance.TransactionInput{Type: typ, AccountID: *c.account, Amount: amount, LocalDate: t.Date,
			Description: desc, Status: status}, "integration", &finance.Provenance{ExternalID: &id, ActorKind: "integration"})
		result = "created"
		return err
	})
	var ae *apperr.Error
	if errors.As(err, &ae) && ae.Code == apperr.CodeDuplicate {
		return "skipped", nil
	}
	return result, err
}

// JobWebhook processes one verified webhook event.
const JobWebhook = "integrations.webhook"

// WebhookResult acknowledges a webhook.
type WebhookResult struct {
	Status string `json:"status" enum:"accepted,duplicate"`
}

// ReceiveWebhook verifies, deduplicates and queues a provider event.
// Invalid signatures are quarantined and answered 401.
func (s *Service) ReceiveWebhook(ctx context.Context, provider string, h http.Header, body []byte) (*WebhookResult, error) {
	a, ok := s.adapter(provider)
	if !ok {
		return nil, apperr.NotFound("provider")
	}
	sum := sha256.Sum256(body)
	digest := hex.EncodeToString(sum[:])
	ev, verr := a.VerifyWebhook(h, body, s.now())
	var ct []byte
	var kid string
	if s.Keyring != nil {
		ct, kid, _ = s.Keyring.Encrypt(body, []byte("webhook:"+provider))
	}
	var eventID uuid.UUID
	duplicate := false
	err := s.DB.WithAnonTx(ctx, func(tx pgx.Tx) error {
		eid, etype, status := "invalid:"+digest[:32], "", "quarantined"
		var signedAt *time.Time
		if verr == nil {
			eid, etype, status, signedAt = ev.ID, ev.Type, "received", &ev.SignedAt
			if strings.TrimSpace(eid) == "" {
				eid = "body:" + digest[:32] // providers without event IDs dedupe on the payload
			}
		}
		eventID = uuid.New()
		ref := ""
		if verr == nil {
			ref = ev.ExternalRef
		}
		// No conflict target: the API role may insert but never read the inbox.
		tag, err := tx.Exec(ctx, `insert into integration_webhook_events (id, provider, event_id, event_type, signature_valid, signed_at, payload_sha256,
			payload_ciphertext, key_id, status, external_ref) values ($1,$2,$3,$4,$5,$6,$7,$8,nullif($9,''),$10,$11) on conflict do nothing`,
			eventID, provider, clip(strings.ToValidUTF8(eid, ""), 200), nullStr(clip(strings.ToValidUTF8(etype, ""), 120)), verr == nil, signedAt, digest, ct, kid,
			status, nullStr(clip(strings.ToValidUTF8(ref, ""), 200)))
		if err != nil {
			return err
		}
		duplicate = tag.RowsAffected() == 0
		if verr != nil || duplicate {
			return nil
		}
		// The API role queues jobs only for a signed-in user; this definer
		// helper queues the one webhook job for a verified event.
		_, err = tx.Exec(ctx, `select montra.enqueue_webhook_event($1)`, eventID)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	if verr != nil {
		return nil, apperr.New(apperr.CodeUnauthenticated, http.StatusUnauthorized, "The webhook signature is not valid.")
	}
	if duplicate {
		return &WebhookResult{Status: "duplicate"}, nil
	}
	return &WebhookResult{Status: "accepted"}, nil
}

// clip keeps at most n characters (never splitting one).
func clip(s string, n int) string {
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

// processWebhook queues a sync for the connection a verified event names.
func (s *Service) processWebhook(ctx context.Context, eventID uuid.UUID) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var provider, status string
		var ref *string
		if err := tx.QueryRow(ctx, `select provider, status, external_ref from integration_webhook_events where id = $1 for update`, eventID).
			Scan(&provider, &status, &ref); err != nil {
			if database.IsNoRows(err) {
				return nil
			}
			return err
		}
		if status != "received" {
			return nil
		}
		ignore := func() error {
			_, err := tx.Exec(ctx, `update integration_webhook_events set status = 'ignored', processed_at = now() where id = $1`, eventID)
			return err
		}
		if _, ok := s.adapter(provider); !ok || ref == nil {
			return ignore()
		}
		var connID, user uuid.UUID
		var cstatus string
		err := tx.QueryRow(ctx, `select id, user_id, status from integration_connections where provider = $1 and external_ref = $2`, provider, *ref).
			Scan(&connID, &user, &cstatus)
		if database.IsNoRows(err) || (err == nil && cstatus != "connected" && cstatus != "partial") {
			return ignore()
		}
		if err != nil {
			return err
		}
		if _, err := s.enqueueSync(ctx, tx, user, connID, "webhook"); err != nil {
			return err
		}
		_, err = tx.Exec(ctx, `update integration_webhook_events set status = 'processed', connection_id = $2, processed_at = now() where id = $1`, eventID, connID)
		return err
	})
}

// VerifyHMAC checks a "t=<unix>,v1=<hex>" signature over "<t>.<body>" with
// a shared secret, rejecting stale timestamps (replay window). Adapters may
// use it for their webhook scheme.
func VerifyHMAC(secret []byte, header string, body []byte, now time.Time, tolerance time.Duration) (time.Time, error) {
	var ts, sig string
	for _, part := range strings.Split(header, ",") {
		k, v, _ := strings.Cut(strings.TrimSpace(part), "=")
		switch k {
		case "t":
			ts = v
		case "v1":
			sig = v
		}
	}
	unix, err := strconv.ParseInt(ts, 10, 64)
	if err != nil || sig == "" {
		return time.Time{}, ErrBadSignature
	}
	at := time.Unix(unix, 0)
	if d := now.Sub(at); d > tolerance || d < -tolerance {
		return time.Time{}, ErrBadSignature
	}
	m := hmac.New(sha256.New, secret)
	m.Write([]byte(ts + "."))
	m.Write(body)
	want := hex.EncodeToString(m.Sum(nil))
	if !hmac.Equal([]byte(want), []byte(sig)) {
		return time.Time{}, ErrBadSignature
	}
	return at, nil
}
