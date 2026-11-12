package api_test

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/integrations"
	"montra/backend/internal/testutil/apitest"
)

// sandboxBank is a test-only provider adapter: OAuth code exchange,
// cursor pages and HMAC-signed webhooks, with no network access.
type sandboxBank struct {
	mu      sync.Mutex
	secret  []byte
	ref     string
	pages   map[string]integrations.Batch
	revoked int
}

func (b *sandboxBank) Info() integrations.ProviderInfo {
	return integrations.ProviderInfo{ID: "sandbox_bank", Name: "Sandbox Bank", Kind: "bank_data", Countries: []string{"IN"},
		Capabilities: []string{"transactions", "webhooks"}, ConsentPurpose: "Keep your Montra account up to date",
		ConsentScope: []string{"transactions"}, ConsentDays: 90}
}

func (b *sandboxBank) AuthorizeURL(state, redirectURI string) string {
	return "https://sandbox-bank.invalid/authorize?state=" + url.QueryEscape(state) + "&redirect_uri=" + url.QueryEscape(redirectURI)
}

func (b *sandboxBank) Exchange(_ context.Context, code, _ string) (*integrations.Token, error) {
	if code != "good-code" {
		return nil, errors.New("invalid code")
	}
	return &integrations.Token{Access: "sandbox-access-secret", Refresh: "sandbox-refresh-secret", Expires: time.Now().Add(time.Hour),
		ExternalRef: b.ref}, nil
}

func (b *sandboxBank) Refresh(_ context.Context, t *integrations.Token) (*integrations.Token, error) {
	n := *t
	n.Expires = time.Now().Add(time.Hour)
	return &n, nil
}

func (b *sandboxBank) Revoke(context.Context, *integrations.Token) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.revoked++
	return nil
}

func (b *sandboxBank) Fetch(_ context.Context, t *integrations.Token, cursor string) (*integrations.Batch, error) {
	if t.Access != "sandbox-access-secret" {
		return nil, errors.New("bad token")
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	p, ok := b.pages[cursor]
	if !ok {
		return &integrations.Batch{NextCursor: cursor}, nil
	}
	return &p, nil
}

func (b *sandboxBank) VerifyWebhook(h http.Header, body []byte, now time.Time) (*integrations.WebhookEvent, error) {
	at, err := integrations.VerifyHMAC(b.secret, h.Get("Sandbox-Signature"), body, now, 5*time.Minute)
	if err != nil {
		return nil, err
	}
	var p struct {
		ID   string `json:"id"`
		Type string `json:"type"`
		Ref  string `json:"ref"`
	}
	if err := json.Unmarshal(body, &p); err != nil {
		return nil, integrations.ErrBadSignature
	}
	return &integrations.WebhookEvent{ID: p.ID, Type: p.Type, SignedAt: at, ExternalRef: p.Ref}, nil
}

func (b *sandboxBank) setPage(cursor string, next string, more bool, txs ...integrations.ProviderTx) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.pages[cursor] = integrations.Batch{Transactions: txs, NextCursor: next, HasMore: more}
}

func (b *sandboxBank) sign(body []byte, at time.Time) string {
	ts := strconv.FormatInt(at.Unix(), 10)
	m := hmac.New(sha256.New, b.secret)
	m.Write([]byte(ts + "."))
	m.Write(body)
	return "t=" + ts + ",v1=" + hex.EncodeToString(m.Sum(nil))
}

// postWebhook sends exact bytes (the signature covers them).
func postWebhook(t *testing.T, s *apitest.Server, provider string, body []byte, signature string) (int, map[string]any) {
	t.Helper()
	req, err := http.NewRequestWithContext(context.Background(), http.MethodPost, s.URL+"/api/v1/webhooks/"+provider, bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Sandbox-Signature", signature)
	req.Header.Set("X-Forwarded-For", "203.0.113.50")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, _ := io.ReadAll(resp.Body)
	var out map[string]any
	_ = json.Unmarshal(raw, &out)
	return resp.StatusCode, out
}

func workerString(t *testing.T, s *apitest.Server, q string, args ...any) string {
	t.Helper()
	var v *string
	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error { return tx.QueryRow(ctx, q, args...).Scan(&v) }); err != nil {
		t.Fatal(err)
	}
	if v == nil {
		return ""
	}
	return *v
}

// integrationTxs maps description → status for the account's provider
// transactions (all statuses).
func integrationTxs(t *testing.T, c *apitest.Client, acct string) map[string]string {
	t.Helper()
	out := map[string]string{}
	for _, x := range c.Do(t, http.MethodGet, "/transactions?account_id="+acct+"&source=integration&status=all&limit=100", nil).Expect(t, http.StatusOK).List() {
		m := x.(map[string]any)
		out[m["description"].(string)] = m["status"].(string)
	}
	return out
}

func latestRun(t *testing.T, c *apitest.Client, conn string) map[string]any {
	t.Helper()
	st := c.Do(t, http.MethodGet, "/integrations/"+conn+"/status", nil).Expect(t, http.StatusOK).Data()
	runs := st["runs"].([]any)
	if len(runs) == 0 {
		t.Fatalf("no sync runs: %v", st)
	}
	return runs[0].(map[string]any)
}

func TestIntegrationConsentOAuthSyncWebhooksAndDisconnect(t *testing.T) {
	s := apitest.New(t, nil)
	bank := &sandboxBank{secret: []byte("sandbox-webhook-secret"), ref: "sbx-" + uuid.NewString()[:8], pages: map[string]integrations.Batch{}}
	s.Svcs.Integrations.Register(bank)
	s.WorkerSvcs.Integrations.Register(bank)
	alice := newPerson(t, s, "alice", nil)
	bob := newPerson(t, s, "bob", nil)
	acct := createAccount(t, alice.c, map[string]any{"name": "Sandbox Savings", "account_type": "savings", "currency": "INR", "opening_balance": "1000.00"})["id"].(string)
	bobAcct := createAccount(t, bob.c, map[string]any{"name": "Bob Savings", "account_type": "savings", "currency": "INR"})["id"].(string)

	// The registry is honest: only registered adapters are available.
	ov := alice.c.Do(t, http.MethodGet, "/integrations", nil).Expect(t, http.StatusOK).Data()
	statuses := map[string]string{}
	for _, p := range ov["providers"].([]any) {
		statuses[p.(map[string]any)["id"].(string)] = p.(map[string]any)["status"].(string)
	}
	if statuses["sandbox_bank"] != "available" || statuses["account_aggregator_in"] != "unavailable" || len(ov["connections"].([]any)) != 0 {
		t.Fatalf("overview: %v", ov)
	}
	if !strings.Contains(ov["note"].(string), "never asks for bank passwords") {
		t.Fatalf("note: %v", ov["note"])
	}

	// Connecting needs explicit consent, a registered provider and your own account.
	connect := func(c *apitest.Client, provider, account string, consent bool) *apitest.Response {
		return c.Do(t, http.MethodPost, "/integrations/"+provider+"/connect", map[string]any{"account_id": account, "consent_confirm": consent})
	}
	connect(alice.c, "sandbox_bank", acct, false).Expect(t, http.StatusUnprocessableEntity)
	connect(alice.c, "account_aggregator_in", acct, true).Expect(t, http.StatusServiceUnavailable)
	connect(alice.c, "sandbox_bank", bobAcct, true).Expect(t, http.StatusUnprocessableEntity)
	started := connect(alice.c, "sandbox_bank", acct, true).Expect(t, http.StatusCreated).Data()
	conn := started["connection_id"].(string)
	au, err := url.Parse(started["authorize_url"].(string))
	if err != nil {
		t.Fatal(err)
	}
	state := au.Query().Get("state")
	if len(state) < 16 || au.Query().Get("redirect_uri") != "http://localhost:5173/integrations/sandbox_bank/callback" {
		t.Fatalf("authorize url: %s", au)
	}
	if n := workerCount(t, s, `select count(*) from user_consents where consent_type = 'integration' and scope = $1 and revoked_at is null`,
		"sandbox_bank:"+conn); n != 1 {
		t.Fatalf("consent rows: %d", n)
	}

	// The first page carries three new items; the second repeats one and
	// reports a reversal Montra never saw.
	bank.setPage("", "c1", true,
		integrations.ProviderTx{ID: "t1", Date: time.Now().Format(day), Amount: "-450.00", Currency: "INR", Description: "Coffee Roasters", Status: "posted"},
		integrations.ProviderTx{ID: "t2", Date: time.Now().Format(day), Amount: "-1200.00", Currency: "INR", Description: "Grocery Mart", Status: "pending"},
		integrations.ProviderTx{ID: "t3", Date: time.Now().Format(day), Amount: "25000.00", Currency: "INR", Description: "Salary", Status: "posted"})
	bank.setPage("c1", "c2", false,
		integrations.ProviderTx{ID: "t1", Date: time.Now().Format(day), Amount: "-450.00", Currency: "INR", Description: "Coffee Roasters", Status: "posted"},
		integrations.ProviderTx{ID: "t4", Date: time.Now().Format(day), Amount: "-99.00", Currency: "INR", Description: "Declined", Status: "reversed"})

	// The OAuth state is bound to the user, single-use and unguessable.
	cb := func(c *apitest.Client, st, code string) *apitest.Response {
		return c.Do(t, http.MethodGet, "/integrations/sandbox_bank/callback?state="+url.QueryEscape(st)+"&code="+code, nil)
	}
	cb(alice.c, strings.Repeat("x", 32), "good-code").Expect(t, http.StatusGone)
	cb(bob.c, state, "good-code").Expect(t, http.StatusGone)
	done := cb(alice.c, state, "good-code").Expect(t, http.StatusOK)
	if done.Data()["status"] != "connected" || done.Data()["consent_granted_at"] == nil || strings.Contains(string(done.Raw), "sandbox-access") {
		t.Fatalf("callback: %s", done.Raw)
	}
	cb(alice.c, state, "good-code").Expect(t, http.StatusGone)

	// Tokens are encrypted at rest.
	var ct []byte
	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select token_ciphertext from integration_connections where id = $1`, conn).Scan(&ct)
	}); err != nil {
		t.Fatal(err)
	}
	if len(ct) == 0 || bytes.Contains(ct, []byte("sandbox-access")) || bytes.Contains(ct, []byte("sandbox-refresh")) {
		t.Fatal("token is not encrypted at rest")
	}

	// The backfill pages through the cursor and records each item once.
	s.RunJobs(t)
	run := latestRun(t, alice.c, conn)
	if run["status"] != "succeeded" || run["trigger"] != "backfill" || run["items_fetched"].(float64) != 5 || run["items_created"].(float64) != 3 ||
		run["items_skipped"].(float64) != 2 {
		t.Fatalf("backfill run: %v", run)
	}
	got := integrationTxs(t, alice.c, acct)
	if len(got) != 3 || got["Coffee Roasters"] != "posted" || got["Grocery Mart"] != "pending" || got["Salary"] != "posted" {
		t.Fatalf("after backfill: %v", got)
	}
	if b := balance(t, alice.c, acct); b != "24350.00" { // 1000 − 450 − 1200 + 25000
		t.Fatalf("balance after backfill: %s", b)
	}

	// Webhooks: signed, replay-protected and deduplicated; invalid ones are
	// quarantined and answered 401; unknown providers 404.
	bank.setPage("c2", "c3", false,
		integrations.ProviderTx{ID: "t2", Date: time.Now().Format(day), Amount: "-1200.00", Currency: "INR", Description: "Grocery Mart", Status: "posted"},
		integrations.ProviderTx{ID: "t1", Date: time.Now().Format(day), Amount: "-450.00", Currency: "INR", Description: "Coffee Roasters", Status: "reversed"})
	evt := []byte(`{"id":"evt_1","type":"transactions.updated","ref":"` + bank.ref + `"}`)
	if code, body := postWebhook(t, s, "sandbox_bank", evt, bank.sign(evt, time.Now())); code != http.StatusAccepted || body["data"].(map[string]any)["status"] != "accepted" {
		t.Fatalf("webhook: %d %v", code, body)
	}
	if code, body := postWebhook(t, s, "sandbox_bank", evt, bank.sign(evt, time.Now())); code != http.StatusAccepted || body["data"].(map[string]any)["status"] != "duplicate" {
		t.Fatalf("replayed webhook: %d %v", code, body)
	}
	forged := []byte(`{"id":"evt_forged","type":"transactions.updated","ref":"` + bank.ref + `"}`)
	if code, _ := postWebhook(t, s, "sandbox_bank", forged, "t="+strconv.FormatInt(time.Now().Unix(), 10)+",v1="+strings.Repeat("0", 64)); code != http.StatusUnauthorized {
		t.Fatalf("forged webhook: %d", code)
	}
	stale := []byte(`{"id":"evt_stale","type":"transactions.updated","ref":"` + bank.ref + `"}`)
	if code, _ := postWebhook(t, s, "sandbox_bank", stale, bank.sign(stale, time.Now().Add(-10*time.Minute))); code != http.StatusUnauthorized {
		t.Fatalf("stale webhook: %d", code)
	}
	if code, _ := postWebhook(t, s, "nobody", evt, bank.sign(evt, time.Now())); code != http.StatusNotFound {
		t.Fatalf("unknown provider: %d", code)
	}
	if n := workerCount(t, s, `select count(*) from integration_webhook_events where provider = 'sandbox_bank' and status = 'quarantined' and not signature_valid`); n != 2 {
		t.Fatalf("quarantined: %d", n)
	}
	s.RunJobs(t)
	if st := workerString(t, s, `select status from integration_webhook_events where provider = 'sandbox_bank' and event_id = 'evt_1'`); st != "processed" {
		t.Fatalf("webhook event status: %s", st)
	}
	run = latestRun(t, alice.c, conn)
	if run["trigger"] != "webhook" || run["status"] != "succeeded" || run["items_updated"].(float64) != 2 {
		t.Fatalf("webhook run: %v", run)
	}
	got = integrationTxs(t, alice.c, acct)
	if got["Grocery Mart"] != "posted" || got["Coffee Roasters"] != "voided" {
		t.Fatalf("after webhook: %v", got)
	}
	if b := balance(t, alice.c, acct); b != "24800.00" { // the reversed coffee no longer counts
		t.Fatalf("balance after webhook: %s", b)
	}
	if n := workerCount(t, s, `select count(*) from transaction_audit_events where user_id = $1 and actor_kind = 'integration' and action in ('updated','voided')`,
		alice.id); n != 2 {
		t.Fatalf("integration audit events: %d", n)
	}

	// A transaction the user deleted is never re-created by a later sync;
	// manual syncs run one at a time.
	var salary string
	for _, x := range alice.c.Do(t, http.MethodGet, "/transactions?account_id="+acct+"&source=integration&q=Salary", nil).Expect(t, http.StatusOK).List() {
		salary = x.(map[string]any)["id"].(string)
	}
	alice.c.Do(t, http.MethodDelete, "/transactions/"+salary, nil).Expect(t, http.StatusOK)
	bank.setPage("c3", "c4", false,
		integrations.ProviderTx{ID: "t3", Date: time.Now().Format(day), Amount: "25000.00", Currency: "INR", Description: "Salary", Status: "posted"},
		integrations.ProviderTx{ID: "t5", Date: time.Now().Format(day), Amount: "-75.50", Currency: "INR", Description: "Bus pass", Status: "posted"},
		integrations.ProviderTx{ID: "t6", Date: time.Now().Format(day), Amount: "-10.00", Currency: "USD", Description: "Wrong currency", Status: "posted"})
	q := alice.c.Do(t, http.MethodPost, "/integrations/"+conn+"/sync", nil).Expect(t, http.StatusAccepted).Data()
	if q["status"] != "queued" || q["trigger"] != "manual" {
		t.Fatalf("sync now: %v", q)
	}
	alice.c.Do(t, http.MethodPost, "/integrations/"+conn+"/sync", nil).Expect(t, http.StatusConflict)
	s.RunJobs(t)
	run = latestRun(t, alice.c, conn)
	if run["status"] != "succeeded" || run["items_created"].(float64) != 1 || run["items_skipped"].(float64) != 2 {
		t.Fatalf("manual run: %v", run)
	}
	got = integrationTxs(t, alice.c, acct)
	if got["Salary"] != "voided" || got["Bus pass"] != "posted" || len(got) != 4 {
		t.Fatalf("after manual sync: %v", got)
	}

	// Other users cannot see or act on the connection.
	bob.c.Do(t, http.MethodGet, "/integrations/"+conn+"/status", nil).Expect(t, http.StatusNotFound)
	bob.c.Do(t, http.MethodPost, "/integrations/"+conn+"/sync", nil).Expect(t, http.StatusNotFound)
	bob.c.Do(t, http.MethodDelete, "/integrations/"+conn+"?confirm=true", nil).Expect(t, http.StatusNotFound)
	if n := len(bob.c.Do(t, http.MethodGet, "/integrations", nil).Expect(t, http.StatusOK).Data()["connections"].([]any)); n != 0 {
		t.Fatalf("bob sees %d connections", n)
	}

	// Stale connections get a scheduled sync.
	s.Env.ExecWorker(t, `update integration_connections set last_sync_at = now() - interval '7 hours' where id = $1`, conn)
	if err := s.WorkerSvcs.Integrations.Schedule(ctx); err != nil {
		t.Fatal(err)
	}
	s.RunJobs(t)
	if run = latestRun(t, alice.c, conn); run["trigger"] != "scheduled" || run["status"] != "succeeded" {
		t.Fatalf("scheduled run: %v", run)
	}

	// Lapsed consent stops syncing and tells the user once.
	s.Env.ExecWorker(t, `update integration_connections set consent_expires_at = now() - interval '1 minute' where id = $1`, conn)
	for i := 0; i < 2; i++ {
		if err := s.WorkerSvcs.Integrations.Schedule(ctx); err != nil {
			t.Fatal(err)
		}
	}
	s.RunJobs(t)
	if st := alice.c.Do(t, http.MethodGet, "/integrations/"+conn+"/status", nil).Expect(t, http.StatusOK).Data(); st["status"] != "consent_expired" {
		t.Fatalf("after consent expiry: %v", st["status"])
	}
	if code := alice.c.Do(t, http.MethodPost, "/integrations/"+conn+"/sync", nil).Expect(t, http.StatusUnprocessableEntity).ErrorCode(); code != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("sync after expiry: %s", code)
	}
	if n := notificationsOf(t, alice.c, "account", "integration.consent_expired"); n != 1 {
		t.Fatalf("consent notifications: %d", n)
	}

	// Disconnecting needs confirmation, revokes at the provider, deletes
	// credentials, revokes consent and (when asked) voids imported data.
	alice.c.Do(t, http.MethodDelete, "/integrations/"+conn, nil).Expect(t, http.StatusUnprocessableEntity)
	d := alice.c.Do(t, http.MethodDelete, "/integrations/"+conn+"?delete_data=true&confirm=true", nil).Expect(t, http.StatusOK).Data()
	if d["status"] != "revoked" || d["deleted_records"].(float64) != 2 || bank.revoked != 1 {
		t.Fatalf("disconnect: %v (revoked %d)", d, bank.revoked)
	}
	if n := workerCount(t, s, `select count(*) from integration_connections where id = $1 and token_ciphertext is null and sync_cursor is null and status = 'revoked'`,
		conn); n != 1 {
		t.Fatal("credentials not removed")
	}
	if n := workerCount(t, s, `select count(*) from user_consents where scope = $1 and revoked_at is not null`, "sandbox_bank:"+conn); n != 1 {
		t.Fatal("consent not revoked")
	}
	if b := balance(t, alice.c, acct); b != "1000.00" {
		t.Fatalf("balance after delete_data: %s", b)
	}
	alice.c.Do(t, http.MethodPost, "/integrations/"+conn+"/sync", nil).Expect(t, http.StatusUnprocessableEntity)

	// Webhooks for a revoked connection are accepted but change nothing.
	late := []byte(`{"id":"evt_2","type":"transactions.updated","ref":"` + bank.ref + `"}`)
	if code, _ := postWebhook(t, s, "sandbox_bank", late, bank.sign(late, time.Now())); code != http.StatusAccepted {
		t.Fatalf("late webhook: %d", code)
	}
	s.RunJobs(t)
	if st := workerString(t, s, `select status from integration_webhook_events where provider = 'sandbox_bank' and event_id = 'evt_2'`); st != "ignored" {
		t.Fatalf("late webhook status: %s", st)
	}
}

func TestIntegrationFailedExchangeAndAbandonedRuns(t *testing.T) {
	s := apitest.New(t, nil)
	bank := &sandboxBank{secret: []byte("k"), ref: "sbx-" + uuid.NewString()[:8], pages: map[string]integrations.Batch{}}
	s.Svcs.Integrations.Register(bank)
	s.WorkerSvcs.Integrations.Register(bank)
	p := newPerson(t, s, "carol", nil)
	acct := createAccount(t, p.c, map[string]any{"name": "Main", "account_type": "savings", "currency": "INR"})["id"].(string)

	// A code the provider rejects fails the connection; the state is spent.
	started := p.c.Do(t, http.MethodPost, "/integrations/sandbox_bank/connect", map[string]any{"account_id": acct, "consent_confirm": true}).
		Expect(t, http.StatusCreated).Data()
	au, _ := url.Parse(started["authorize_url"].(string))
	state := url.QueryEscape(au.Query().Get("state"))
	p.c.Do(t, http.MethodGet, "/integrations/sandbox_bank/callback?state="+state+"&code=bad-code", nil).Expect(t, http.StatusServiceUnavailable)
	p.c.Do(t, http.MethodGet, "/integrations/sandbox_bank/callback?state="+state+"&code=good-code", nil).Expect(t, http.StatusGone)
	conn := started["connection_id"].(string)
	if st := p.c.Do(t, http.MethodGet, "/integrations/"+conn+"/status", nil).Expect(t, http.StatusOK).Data(); st["status"] != "failed" ||
		st["last_error_code"] != "token_exchange_failed" {
		t.Fatalf("failed exchange: %v", st)
	}

	// A run abandoned by a crashed worker no longer blocks syncing.
	started = p.c.Do(t, http.MethodPost, "/integrations/sandbox_bank/connect", map[string]any{"account_id": acct, "consent_confirm": true}).
		Expect(t, http.StatusCreated).Data()
	au, _ = url.Parse(started["authorize_url"].(string))
	conn = started["connection_id"].(string)
	p.c.Do(t, http.MethodGet, "/integrations/sandbox_bank/callback?state="+url.QueryEscape(au.Query().Get("state"))+"&code=good-code", nil).Expect(t, http.StatusOK)
	s.Env.ExecWorker(t, `update jobs set status = 'dead' where type = 'integrations.sync' and status = 'queued'`)
	s.Env.ExecWorker(t, `update integration_sync_runs set status = 'running', created_at = now() - interval '3 hours' where connection_id = $1`, conn)
	s.Env.ExecWorker(t, `update integration_connections set status = 'syncing' where id = $1`, conn)
	p.c.Do(t, http.MethodPost, "/integrations/"+conn+"/sync", nil).Expect(t, http.StatusConflict)
	if err := s.WorkerSvcs.Integrations.Schedule(context.Background()); err != nil {
		t.Fatal(err)
	}
	st := p.c.Do(t, http.MethodGet, "/integrations/"+conn+"/status", nil).Expect(t, http.StatusOK).Data()
	if st["status"] != "failed" || st["last_error_code"] != "sync_timed_out" {
		t.Fatalf("after recovery: %v", st)
	}
	p.c.Do(t, http.MethodPost, "/integrations/"+conn+"/sync", nil).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	if run := latestRun(t, p.c, conn); run["status"] != "succeeded" {
		t.Fatalf("sync after recovery: %v", run)
	}
}

// Deleting an account asks providers to revoke access before tokens go.
func TestAccountDeletionRevokesIntegrationsAtTheProvider(t *testing.T) {
	s := apitest.New(t, nil)
	bank := &sandboxBank{secret: []byte("k"), ref: "sbx-" + uuid.NewString()[:8], pages: map[string]integrations.Batch{}}
	s.Svcs.Integrations.Register(bank)
	s.WorkerSvcs.Integrations.Register(bank)
	addr := s.Register(t, "leaving")
	c, _ := s.Login(t, addr)
	uid := userID(t, s, addr)
	acct := createAccount(t, c, map[string]any{"name": "Main", "account_type": "savings", "currency": "INR"})["id"].(string)
	started := c.Do(t, http.MethodPost, "/integrations/sandbox_bank/connect", map[string]any{"account_id": acct, "consent_confirm": true}).
		Expect(t, http.StatusCreated).Data()
	au, _ := url.Parse(started["authorize_url"].(string))
	c.Do(t, http.MethodGet, "/integrations/sandbox_bank/callback?state="+url.QueryEscape(au.Query().Get("state"))+"&code=good-code", nil).
		Expect(t, http.StatusOK)
	s.RunJobs(t)

	c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/me/deletion-request", map[string]any{"confirm": "DELETE"}).Expect(t, http.StatusOK)
	s.Env.ExecWorker(t, `update account_deletion_requests set scheduled_for = now() - interval '1 minute' where status = 'scheduled' and user_id = $1`, uid)
	s.Env.ExecWorker(t, `insert into jobs (type, dedupe_key) values ('privacy.deletion_due', 'test-due-' || gen_random_uuid())`)
	s.RunJobs(t)

	if bank.revoked != 1 {
		t.Fatalf("provider revoke calls: %d", bank.revoked)
	}
	if n := workerCount(t, s, `select count(*) from integration_connections where user_id = $1`, uid); n != 0 {
		t.Fatalf("connections left after deletion: %d", n)
	}
}
