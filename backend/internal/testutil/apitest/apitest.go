// Package apitest runs the real HTTP stack (router, middleware, Huma, auth,
// RLS-scoped database) against the local integration database, with a
// capturing email sender as the only test double (spec §14).
package apitest

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/app"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/platform/outbox"
	"montra/backend/internal/testutil/dbtest"
)

// Mailbox captures outgoing emails (test double for the email provider).
type Mailbox struct {
	mu   sync.Mutex
	msgs []email.Message
}

// Send implements email.Sender.
func (m *Mailbox) Send(_ context.Context, msg email.Message) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.msgs = append(m.msgs, msg)
	return nil
}

// Provider implements email.Sender.
func (m *Mailbox) Provider() string { return "test_mailbox" }

// Configured implements email.Sender.
func (m *Mailbox) Configured() bool { return true }

// Messages returns messages sent to an address.
func (m *Mailbox) Messages(to string) []email.Message {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []email.Message
	for _, x := range m.msgs {
		if strings.EqualFold(x.To, to) {
			out = append(out, x)
		}
	}
	return out
}

var tokenRe = regexp.MustCompile(`#token=([A-Za-z0-9_-]+)`)

// LatestToken extracts the fragment token from the newest message to `to`
// whose category matches.
func (m *Mailbox) LatestToken(t testing.TB, to, category string) string {
	t.Helper()
	msgs := m.Messages(to)
	for i := len(msgs) - 1; i >= 0; i-- {
		if msgs[i].Category == category {
			if mm := tokenRe.FindStringSubmatch(msgs[i].Text); mm != nil {
				return mm[1]
			}
		}
	}
	t.Fatalf("no %s email with token for %s", category, to)
	return ""
}

// Server is an in-process Montra API plus a synchronous job runner.
type Server struct {
	URL    string
	Env    *dbtest.Env
	Cfg    *config.Config
	Mail   *Mailbox
	Worker *jobs.Worker
	Relay  *outbox.Relay
	Svcs   *app.Services
	// WorkerSvcs are the worker-process services (montra_worker role); tests
	// drive scheduled jobs through them, e.g. with a simulated clock.
	WorkerSvcs *app.Services
	httpSrv    *httptest.Server
}

var testKey = base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{42}, 32))

// New starts a server. Overrides adjust configuration (key → value).
func New(t testing.TB, overrides map[string]string) *Server {
	t.Helper()
	env := dbtest.Setup(t)
	vals := map[string]string{
		"APP_ENV": "test", "DATABASE_URL": "postgres://unused-in-tests/none", "DATA_ENCRYPTION_KEYS": "t1:" + testKey,
		"URL_SIGNING_KEY": testKey, "EMAIL_PROVIDER": "dev_mailbox", "AUTH_COOKIE_SECURE": "false",
		"HTTP_TRUST_PROXY_HEADERS": "true", "STORAGE_PROVIDER": "local_disk", "STORAGE_LOCAL_DIR": t.TempDir(),
		"WEB_APP_URL": "http://localhost:5173",
	}
	for k, v := range overrides {
		vals[k] = v
	}
	cfg, err := config.LoadFrom(func(k string) (string, bool) { v, ok := vals[k]; return v, ok })
	if err != nil {
		t.Fatalf("config: %v", err)
	}
	metrics := observability.New("montra-test")
	deps := app.Deps{Cfg: cfg, DB: env.App, Metrics: metrics}
	svcs, err := app.NewServices(deps)
	if err != nil {
		t.Fatal(err)
	}
	// Fast password hashing keeps tests quick; production uses DefaultArgon2.
	svcs.Auth.Argon = crypto.Argon2Params{Memory: 8 * 1024, Time: 1, Threads: 1, KeyLen: 32, SaltLen: 16}
	handler, _ := app.NewRouter(deps, svcs)
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)

	mail := &Mailbox{}
	// The worker uses the montra_worker role, exactly like production.
	workerDeps := app.Deps{Cfg: cfg, DB: env.Worker, Metrics: metrics, AppDB: env.App, Worker: true}
	workerSvcs, err := app.NewServices(workerDeps)
	if err != nil {
		t.Fatal(err)
	}
	reg := jobs.NewRegistry()
	app.RegisterJobs(reg, workerSvcs, mail)
	app.RegisterPlatformJobs(reg, workerDeps)
	w := jobs.NewWorker(env.Worker, reg, jobs.WorkerOptions{Concurrency: 4, Lease: time.Minute})
	relay := outbox.NewRelay(env.Worker)
	app.RegisterOutboxRoutes(relay)
	watchNotificationText(t)
	return &Server{URL: srv.URL, Env: env, Cfg: cfg, Mail: mail, Worker: w, Relay: relay, Svcs: svcs, WorkerSvcs: workerSvcs, httpSrv: srv}
}

// Notification titles and bodies are shown on lock screens and in email
// previews, so they must never carry amounts or currency (spec §4.17).
// Every API test checks every notification it caused.
var (
	moneyInText    = regexp.MustCompile(`\d+[.,]\d{2}\b|[₹$€£¥]`)
	currencyInText = regexp.MustCompile(`\b(INR|USD|EUR|GBP|AED|SGD|JPY|AUD|CAD)\b`)
)

func watchNotificationText(t testing.TB) {
	var mu sync.Mutex
	var bad []string
	notifications.SetCreateHook(func(n notifications.Notification) {
		text := n.Title + " | " + n.Body
		if moneyInText.MatchString(text) || currencyInText.MatchString(text) {
			mu.Lock()
			bad = append(bad, n.EventType+": "+text)
			mu.Unlock()
		}
	})
	t.Cleanup(func() {
		notifications.SetCreateHook(nil)
		mu.Lock()
		defer mu.Unlock()
		for _, b := range bad {
			t.Errorf("notification text carries an amount or currency: %s", b)
		}
	})
}

// RunJobs relays outbox events and executes all queued jobs synchronously
// (debounced jobs are released immediately), repeating until idle.
func (s *Server) RunJobs(t testing.TB) int {
	t.Helper()
	total := 0
	for i := 0; i < 20; i++ {
		relayed, err := s.Relay.RelayOnce(context.Background(), 500)
		if err != nil {
			t.Fatalf("relay outbox: %v", err)
		}
		s.Env.ExecWorker(t, `update jobs set run_after = now() where status = 'queued' and run_after > now()`)
		n, err := s.Worker.Drain(context.Background(), 50)
		if err != nil {
			t.Fatalf("drain jobs: %v", err)
		}
		total += n
		if relayed == 0 && n == 0 {
			break
		}
	}
	return total
}

// Client is an HTTP client bound to a simulated device/IP.
type Client struct {
	S      *Server
	Kind   string // web | android | ios
	IP     string
	Bearer string
	Jar    http.CookieJar
	http   *http.Client
}

// NewClient creates a client with a unique simulated IP.
func (s *Server) NewClient(kind string) *Client {
	jar, _ := cookiejar.New(nil)
	ip := fmt.Sprintf("10.%d.%d.%d", uuid.New()[0], uuid.New()[1], uuid.New()[2]|1)
	return &Client{S: s, Kind: kind, IP: ip, Jar: jar, http: &http.Client{Jar: jar, Timeout: 30 * time.Second}}
}

// Response is a parsed API response.
type Response struct {
	Status  int
	Body    map[string]any
	Raw     []byte
	Headers http.Header
}

// Data returns body.data as a map.
func (r *Response) Data() map[string]any {
	d, _ := r.Body["data"].(map[string]any)
	return d
}

// List returns body.data as a list.
func (r *Response) List() []any {
	d, _ := r.Body["data"].([]any)
	return d
}

// ErrorCode returns body.error.code.
func (r *Response) ErrorCode() string {
	if e, ok := r.Body["error"].(map[string]any); ok {
		c, _ := e["code"].(string)
		return c
	}
	return ""
}

// Do performs a request. body may be nil or any JSON-serializable value.
func (c *Client) Do(t testing.TB, method, path string, body any, headers ...string) *Response {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(context.Background(), method, c.S.URL+"/api/v1"+path, rdr)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Montra-Client", c.Kind)
	req.Header.Set("X-Forwarded-For", c.IP)
	if c.Bearer != "" {
		req.Header.Set("Authorization", "Bearer "+c.Bearer)
	}
	if c.Kind == "web" && method != http.MethodGet {
		for _, ck := range c.Jar.Cookies(req.URL) {
			if ck.Name == "montra_csrf" {
				req.Header.Set("X-CSRF-Token", ck.Value)
			}
		}
	}
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	resp, err := c.http.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, _ := io.ReadAll(resp.Body)
	out := &Response{Status: resp.StatusCode, Raw: raw, Headers: resp.Header}
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &out.Body)
	}
	return out
}

// Expect asserts a status code.
func (r *Response) Expect(t testing.TB, status int) *Response {
	t.Helper()
	if r.Status != status {
		t.Fatalf("expected HTTP %d, got %d: %s", status, r.Status, string(r.Raw))
	}
	return r
}

// Password used for synthetic accounts.
const Password = "Synthetic-Pass-2026!"

// Register creates and verifies an account via the public API, returning
// its email.
func (s *Server) Register(t testing.TB, name string) string {
	t.Helper()
	addr := fmt.Sprintf("test.%s.%s@example.com", strings.ToLower(name), uuid.NewString()[:8])
	c := s.NewClient("android")
	c.Do(t, http.MethodPost, "/auth/register", map[string]any{
		"email": addr, "password": Password, "display_name": "Test " + name, "accept_terms": true, "confirm_adult": true,
		"terms_version": "2026-11-01", "privacy_version": "2026-11-01", "timezone": "Asia/Kolkata", "currency": "INR",
	}).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	tok := s.Mail.LatestToken(t, addr, email.TplVerifyEmail)
	c.Do(t, http.MethodPost, "/auth/email/verify", map[string]any{"token": tok}).Expect(t, http.StatusOK)
	return addr
}

// Login signs in as a mobile client and returns a client with a bearer
// token plus the refresh token.
func (s *Server) Login(t testing.TB, addr string) (*Client, string) {
	t.Helper()
	c := s.NewClient("android")
	r := c.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": Password}).Expect(t, http.StatusOK)
	d := r.Data()
	c.Bearer, _ = d["access_token"].(string)
	rt, _ := d["refresh_token"].(string)
	if c.Bearer == "" || rt == "" {
		t.Fatalf("login did not return tokens: %s", string(r.Raw))
	}
	return c, rt
}
