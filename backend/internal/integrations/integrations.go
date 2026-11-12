// Package integrations is the financial-data integration framework (spec
// §4.18, §20B.19, ADR-016): a provider registry, consent-bound OAuth
// connections with encrypted tokens, idempotent syncs with cursors,
// revocation with optional data deletion, and signed, replay-protected
// webhooks. No provider is enabled by default: Montra's core works fully
// with manual entry and statement imports, and a provider is registered
// only with real credentials after legal and security review. Montra never
// collects bank passwords, UPI PINs, OTPs or CVVs.
package integrations

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
)

// ProviderInfo describes a provider in the registry.
type ProviderInfo struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Kind           string   `json:"kind" enum:"bank_data,account_aggregator,card,payments"`
	Countries      []string `json:"countries"`
	Capabilities   []string `json:"capabilities" doc:"transactions, balances, webhooks"`
	Status         string   `json:"status" enum:"available,not_configured,unavailable" doc:"available only with real credentials and approvals"`
	StatusReason   string   `json:"status_reason,omitempty"`
	ConsentPurpose string   `json:"consent_purpose"`
	ConsentScope   []string `json:"consent_scope"`
	ConsentDays    int      `json:"consent_days"`
}

// Token is provider credentials (stored encrypted, never returned).
type Token struct {
	Access      string    `json:"access"`
	Refresh     string    `json:"refresh,omitempty"`
	Expires     time.Time `json:"expires"`
	ExternalRef string    `json:"external_ref,omitempty" doc:"Provider's ID for this connection"`
}

// ProviderTx is a transaction as reported by a provider.
type ProviderTx struct {
	ID          string // stable provider ID
	Date        string // YYYY-MM-DD
	Amount      string // signed decimal: negative = money out
	Currency    string
	Description string
	Status      string // posted | pending | reversed
}

// Batch is one page of provider data.
type Batch struct {
	Transactions []ProviderTx
	NextCursor   string
	HasMore      bool
}

// WebhookEvent is a verified provider event.
type WebhookEvent struct {
	ID          string
	Type        string
	SignedAt    time.Time
	ExternalRef string
}

// Adapter implements one provider. It is registered only when the owner
// configured real credentials.
type Adapter interface {
	Info() ProviderInfo
	AuthorizeURL(state, redirectURI string) string
	Exchange(ctx context.Context, code, redirectURI string) (*Token, error)
	Refresh(ctx context.Context, t *Token) (*Token, error)
	Revoke(ctx context.Context, t *Token) error
	Fetch(ctx context.Context, t *Token, cursor string) (*Batch, error)
	VerifyWebhook(h http.Header, body []byte, now time.Time) (*WebhookEvent, error)
}

// Errors from adapters.
var (
	ErrConsentExpired = errors.New("provider consent expired")
	ErrBadSignature   = errors.New("webhook signature invalid")
)

// known lists providers Montra may support, with why they are not live.
var known = []ProviderInfo{
	{ID: "account_aggregator_in", Name: "Account Aggregator (India)", Kind: "account_aggregator", Countries: []string{"IN"},
		Capabilities: []string{"transactions", "balances"}, Status: "unavailable",
		StatusReason:   "Needs an approved Account Aggregator partner, FIU registration and legal review before launch.",
		ConsentPurpose: "Read your bank transactions and balances to keep Montra up to date", ConsentScope: []string{"transactions", "balances"},
		ConsentDays: 365},
}

// Service implements integrations.
type Service struct {
	DB          *database.DB
	Finance     *finance.Service
	Keyring     *crypto.Keyring
	RedirectURL string // web app path base for OAuth returns
	Now         func() time.Time

	mu       sync.RWMutex
	adapters map[string]Adapter
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Register enables an adapter (only with real credentials; tests register
// sandbox adapters).
func (s *Service) Register(a Adapter) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.adapters == nil {
		s.adapters = map[string]Adapter{}
	}
	s.adapters[a.Info().ID] = a
}

func (s *Service) adapter(id string) (Adapter, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.adapters[id]
	return a, ok
}

// Providers lists the registry: registered adapters are available; known
// providers without an adapter state why they are not.
func (s *Service) Providers() []ProviderInfo {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := []ProviderInfo{}
	seen := map[string]bool{}
	for _, a := range s.adapters {
		info := a.Info()
		info.Status, info.StatusReason = "available", ""
		out, seen[info.ID] = append(out, info), true
	}
	for _, k := range known {
		if !seen[k.ID] {
			out = append(out, k)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

// ConnectionDTO is a user's connection (no tokens).
type ConnectionDTO struct {
	ID               uuid.UUID  `json:"id"`
	Provider         string     `json:"provider"`
	Status           string     `json:"status" enum:"pending,connected,disconnected,consent_expired,syncing,partial,failed,revoked"`
	ConsentPurpose   *string    `json:"consent_purpose,omitempty"`
	ConsentScope     []string   `json:"consent_scope"`
	ConsentGrantedAt *time.Time `json:"consent_granted_at,omitempty"`
	ConsentExpiresAt *time.Time `json:"consent_expires_at,omitempty"`
	LinkedAccountID  *uuid.UUID `json:"linked_account_id,omitempty"`
	LastSyncAt       *time.Time `json:"last_sync_at,omitempty"`
	LastSyncStatus   *string    `json:"last_sync_status,omitempty"`
	LastErrorCode    *string    `json:"last_error_code,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
}

const connCols = `id, provider, status, consent_purpose, consent_scope, consent_granted_at, consent_expires_at, linked_account_id, last_sync_at,
	last_sync_status, last_error_code, created_at`

func scanConn(r pgx.CollectableRow) (ConnectionDTO, error) {
	var c ConnectionDTO
	err := r.Scan(&c.ID, &c.Provider, &c.Status, &c.ConsentPurpose, &c.ConsentScope, &c.ConsentGrantedAt, &c.ConsentExpiresAt, &c.LinkedAccountID,
		&c.LastSyncAt, &c.LastSyncStatus, &c.LastErrorCode, &c.CreatedAt)
	if c.ConsentScope == nil {
		c.ConsentScope = []string{}
	}
	return c, err
}

// Overview is the registry plus the caller's connections.
type Overview struct {
	Providers   []ProviderInfo  `json:"providers"`
	Connections []ConnectionDTO `json:"connections"`
	Note        string          `json:"note"`
}

// List returns providers and the caller's connections.
func (s *Service) List(ctx context.Context) (*Overview, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &Overview{Providers: s.Providers(), Connections: []ConnectionDTO{},
		Note: "Montra works fully without connections: add transactions manually or import statements. Montra never asks for bank passwords, UPI PINs or OTPs."}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+connCols+` from integration_connections where user_id = $1 order by created_at desc`, uid)
		if err != nil {
			return err
		}
		out.Connections, err = pgx.CollectRows(rows, scanConn)
		return err
	})
	return out, database.MapError(err)
}

// ConnectInput starts a connection.
type ConnectInput struct {
	AccountID      uuid.UUID `json:"account_id" doc:"The Montra account to fill"`
	ConsentConfirm bool      `json:"consent_confirm" doc:"Must be true: you agree to the purpose, scope and duration shown for this provider"`
}

// ConnectResult carries the provider authorization URL.
type ConnectResult struct {
	ConnectionID uuid.UUID `json:"connection_id"`
	AuthorizeURL string    `json:"authorize_url" doc:"Open this to approve access at the provider; Montra never sees your bank credentials"`
}

func hashState(state string) []byte { return crypto.HashToken(state) }

// Connect creates a pending connection bound to a one-time OAuth state.
func (s *Service) Connect(ctx context.Context, provider string, in ConnectInput) (*ConnectResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	a, ok := s.adapter(provider)
	if !ok {
		return nil, apperr.Unavailable(apperr.CodeNotConfigured, "This provider is not available. Add transactions manually or import a statement.")
	}
	if !in.ConsentConfirm {
		return nil, apperr.FieldError("body.consent_confirm", "Review and accept the consent to connect.")
	}
	info := a.Info()
	raw := make([]byte, 24)
	if _, err := rand.Read(raw); err != nil {
		return nil, err
	}
	state := base64.RawURLEncoding.EncodeToString(raw)
	out := &ConnectResult{ConnectionID: uuid.New()}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var cur, status string
		if err := tx.QueryRow(ctx, `select currency, status from financial_accounts where id = $1 and user_id = $2`, in.AccountID, uid).Scan(&cur, &status); err != nil {
			if database.IsNoRows(err) {
				return apperr.FieldError("body.account_id", "Choose one of your accounts.")
			}
			return err
		}
		if status != "active" {
			return apperr.Rule("account_inactive", "Connect an active account.", nil)
		}
		exp := s.now().AddDate(0, 0, max(info.ConsentDays, 1))
		var consentID uuid.UUID
		if err := tx.QueryRow(ctx, `insert into user_consents (user_id, consent_type, version, scope, metadata) values ($1,'integration',$2,$3,$4) returning id`,
			uid, "2026-11-01", provider+":"+out.ConnectionID.String(), map[string]any{"purpose": info.ConsentPurpose, "scope": info.ConsentScope,
				"expires_at": exp}).Scan(&consentID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into integration_connections (id, user_id, provider, status, consent_id, consent_purpose, consent_scope,
			consent_expires_at, oauth_state_hash, linked_account_id) values ($1,$2,$3,'pending',$4,$5,$6,$7,$8,$9)`, out.ConnectionID, uid, provider,
			consentID, info.ConsentPurpose, info.ConsentScope, exp, hashState(state), in.AccountID); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "integration_connection", EntityID: &out.ConnectionID,
			Action: "connect_started", Changes: map[string]any{"provider": provider}})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	out.AuthorizeURL = a.AuthorizeURL(state, s.redirect(provider))
	return out, nil
}

func (s *Service) redirect(provider string) string {
	return strings.TrimRight(s.RedirectURL, "/") + "/integrations/" + url.PathEscape(provider) + "/callback"
}

// Callback completes the OAuth flow: the state must match the caller's
// pending connection; tokens are stored encrypted and a first sync queued.
func (s *Service) Callback(ctx context.Context, provider, state, code string) (*ConnectionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	a, ok := s.adapter(provider)
	if !ok {
		return nil, apperr.Unavailable(apperr.CodeNotConfigured, "This provider is not available.")
	}
	// Claim the state before talking to the provider so it is single-use
	// even under concurrent or replayed callbacks.
	var connID uuid.UUID
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `update integration_connections set oauth_state_hash = null where user_id = $1 and provider = $2 and status = 'pending'
			and oauth_state_hash = $3 and created_at > now() - interval '30 minutes' returning id`, uid, provider, hashState(state)).Scan(&connID)
	})
	if database.IsNoRows(err) {
		return nil, apperr.New(apperr.CodeGone, http.StatusGone, "This connection request expired. Start again from Integrations.")
	}
	if err != nil {
		return nil, database.MapError(err)
	}
	tok, err := a.Exchange(ctx, code, s.redirect(provider))
	if err != nil {
		_ = s.fail(ctx, uid, connID, "token_exchange_failed")
		return nil, apperr.Unavailable(apperr.CodeProviderUnavailable, "The provider did not complete the connection. Try again.")
	}
	ct, kid, err := s.sealToken(connID, tok)
	if err != nil {
		return nil, err
	}
	var out ConnectionDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update integration_connections set status = 'connected', token_ciphertext = $3, token_key_id = $4,
			token_expires_at = $5, external_ref = $6, consent_granted_at = now() where id = $1 and user_id = $2 and status = 'pending'`, connID, uid, ct, kid,
			nullTime(tok.Expires), nullStr(tok.ExternalRef))
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.New(apperr.CodeGone, http.StatusGone, "This connection request is no longer pending. Start again from Integrations.")
		}
		if _, err := s.enqueueSync(ctx, tx, uid, connID, "backfill"); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "integration_connection", EntityID: &connID,
			Action: "connected", Changes: map[string]any{"provider": provider}}); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select `+connCols+` from integration_connections where id = $1`, connID)
		if err != nil {
			return err
		}
		out, err = pgx.CollectExactlyOneRow(rows, scanConn)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

func nullTime(t time.Time) *time.Time {
	if t.IsZero() {
		return nil
	}
	return &t
}

func nullStr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (s *Service) sealToken(connID uuid.UUID, t *Token) ([]byte, string, error) {
	raw, err := json.Marshal(t)
	if err != nil {
		return nil, "", err
	}
	return s.Keyring.Encrypt(raw, []byte("integration:"+connID.String()))
}

func (s *Service) openToken(connID uuid.UUID, ct []byte, kid string) (*Token, error) {
	raw, err := s.Keyring.Decrypt(ct, kid, []byte("integration:"+connID.String()))
	if err != nil {
		return nil, err
	}
	var t Token
	return &t, json.Unmarshal(raw, &t)
}

func (s *Service) fail(ctx context.Context, uid, connID uuid.UUID, code string) error {
	return s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `update integration_connections set status = 'failed', last_error_code = $2 where id = $1`, connID, code)
		return err
	})
}

// SyncRunDTO is one sync attempt.
type SyncRunDTO struct {
	ID           uuid.UUID  `json:"id"`
	Status       string     `json:"status" enum:"queued,running,succeeded,partial,failed"`
	Trigger      string     `json:"trigger" enum:"manual,scheduled,webhook,backfill"`
	ItemsFetched int        `json:"items_fetched"`
	ItemsCreated int        `json:"items_created"`
	ItemsUpdated int        `json:"items_updated"`
	ItemsSkipped int        `json:"items_skipped"`
	ErrorCode    *string    `json:"error_code,omitempty"`
	StartedAt    *time.Time `json:"started_at,omitempty"`
	FinishedAt   *time.Time `json:"finished_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

// ConnectionStatus is a connection with recent syncs.
type ConnectionStatus struct {
	ConnectionDTO
	Runs []SyncRunDTO `json:"runs"`
}

// Status returns a connection's status and recent syncs.
func (s *Service) Status(ctx context.Context, id uuid.UUID) (*ConnectionStatus, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out ConnectionStatus
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+connCols+` from integration_connections where id = $1 and user_id = $2`, id, uid)
		if err != nil {
			return err
		}
		if out.ConnectionDTO, err = pgx.CollectExactlyOneRow(rows, scanConn); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("connection")
			}
			return err
		}
		rrows, err := tx.Query(ctx, `select id, status, trigger, items_fetched, items_created, items_updated, items_skipped, error_code, started_at,
			finished_at, created_at from integration_sync_runs where connection_id = $1 order by created_at desc limit 20`, id)
		if err != nil {
			return err
		}
		out.Runs, err = pgx.CollectRows(rrows, func(r pgx.CollectableRow) (SyncRunDTO, error) {
			var x SyncRunDTO
			err := r.Scan(&x.ID, &x.Status, &x.Trigger, &x.ItemsFetched, &x.ItemsCreated, &x.ItemsUpdated, &x.ItemsSkipped, &x.ErrorCode, &x.StartedAt,
				&x.FinishedAt, &x.CreatedAt)
			return x, err
		})
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// JobSync syncs one connection.
const JobSync = "integrations.sync"

func (s *Service) enqueueSync(ctx context.Context, tx pgx.Tx, uid, connID uuid.UUID, trigger string) (uuid.UUID, error) {
	runID := uuid.New()
	if _, err := tx.Exec(ctx, `insert into integration_sync_runs (id, connection_id, user_id, trigger) values ($1,$2,$3,$4)`, runID, connID, uid, trigger); err != nil {
		return uuid.Nil, err
	}
	_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSync, UserID: &uid, Payload: map[string]any{"run_id": runID}, DedupeKey: "integration_sync:" + runID.String(),
		Priority: 120, MaxAttempts: 5})
	return runID, err
}

// SyncNow queues a sync (one at a time per connection).
func (s *Service) SyncNow(ctx context.Context, id uuid.UUID) (*SyncRunDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out SyncRunDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var status, provider string
		if err := tx.QueryRow(ctx, `select status, provider from integration_connections where id = $1 and user_id = $2 for update`, id, uid).Scan(&status, &provider); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("connection")
			}
			return err
		}
		if _, ok := s.adapter(provider); !ok {
			return apperr.Unavailable(apperr.CodeNotConfigured, "This provider is not available any more.")
		}
		switch status {
		case "revoked", "disconnected", "pending":
			return apperr.Rule("reconnect_required", "Connect again before syncing.", nil)
		case "consent_expired":
			return apperr.Rule("consent_expired", "Your consent for this connection expired. Connect again to renew it.", nil)
		}
		var running bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from integration_sync_runs where connection_id = $1 and status in ('queued','running'))`, id).Scan(&running); err != nil {
			return err
		}
		if running {
			return apperr.ConflictCode("sync_running", "A sync is already running.", nil)
		}
		runID, err := s.enqueueSync(ctx, tx, uid, id, "manual")
		if err != nil {
			return err
		}
		out = SyncRunDTO{ID: runID, Status: "queued", Trigger: "manual", CreatedAt: s.now()}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// DisconnectResult reports a disconnection.
type DisconnectResult struct {
	Status        string `json:"status" enum:"revoked"`
	DeletedRecord int64  `json:"deleted_records" doc:"Transactions voided because you asked to delete provider data"`
}

// Disconnect revokes access at the provider (best effort), deletes stored
// tokens, revokes the consent and optionally voids imported transactions.
func (s *Service) Disconnect(ctx context.Context, id uuid.UUID, deleteData bool) (*DisconnectResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var provider string
	var ct []byte
	var kid *string
	var consentID *uuid.UUID
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select provider, token_ciphertext, token_key_id, consent_id from integration_connections where id = $1 and user_id = $2`,
			id, uid).Scan(&provider, &ct, &kid, &consentID)
	})
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("connection")
	}
	if err != nil {
		return nil, database.MapError(err)
	}
	if a, ok := s.adapter(provider); ok && ct != nil && kid != nil {
		if tok, err := s.openToken(id, ct, *kid); err == nil {
			_ = a.Revoke(ctx, tok) // best effort; local access ends regardless
		}
	}
	out := &DisconnectResult{Status: "revoked"}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `update integration_connections set status = 'revoked', token_ciphertext = null, token_key_id = null,
			token_expires_at = null, sync_cursor = null, consent_revoked_at = now() where id = $1 and user_id = $2`, id, uid); err != nil {
			return err
		}
		if consentID != nil {
			if _, err := tx.Exec(ctx, `update user_consents set revoked_at = now() where id = $1 and user_id = $2 and revoked_at is null`, *consentID, uid); err != nil {
				return err
			}
		}
		if deleteData {
			rows, err := tx.Query(ctx, `select id from transactions where user_id = $1 and source = 'integration' and starts_with(external_id, $2) and deleted_at is null`,
				uid, provider+":"+id.String()+":")
			if err != nil {
				return err
			}
			ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
			if err != nil {
				return err
			}
			for _, t := range ids {
				if err := s.Finance.VoidInTx(ctx, tx, uid, t); err != nil {
					return err
				}
			}
			out.DeletedRecord = int64(len(ids))
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "integration_connection", EntityID: &id, Action: "revoked",
			Changes: map[string]any{"provider": provider, "delete_data": deleteData, "voided": out.DeletedRecord}})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return out, nil
}

// RevokeAllForUser asks each provider to revoke a user's connections
// (account deletion). Best effort: tokens are deleted by the caller
// either way. Runs in the worker.
func (s *Service) RevokeAllForUser(ctx context.Context, uid uuid.UUID) error {
	type conn struct {
		id       uuid.UUID
		provider string
		ct       []byte
		kid      string
	}
	var conns []conn
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id, provider, token_ciphertext, token_key_id from integration_connections
			where user_id = $1 and token_ciphertext is not null and token_key_id is not null`, uid)
		if err != nil {
			return err
		}
		conns, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (conn, error) {
			var c conn
			err := r.Scan(&c.id, &c.provider, &c.ct, &c.kid)
			return c, err
		})
		return err
	})
	if err != nil {
		return err
	}
	var failed error
	for _, c := range conns {
		a, ok := s.adapter(c.provider)
		if !ok {
			continue
		}
		tok, err := s.openToken(c.id, c.ct, c.kid)
		if err != nil {
			continue
		}
		if err := a.Revoke(ctx, tok); err != nil {
			failed = err
		}
	}
	return failed
}
