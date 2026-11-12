// Command loadtest drives a realistic read/write mix against a Montra API
// and checks the planning latency targets (ADR-025: read p95 < 500 ms,
// write p95 < 800 ms, error rate < 1 %).
//
// It refuses non-local targets unless -allow-remote is given, and it must
// never be pointed at production. Synthetic users (loadtest.*@example.com)
// are created through the public API; in local development their
// verification emails are read from the dev mailbox directory.
//
//	go run ./cmd/loadtest -users 10 -duration 60s -rate 2
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"mime/quotedprintable"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

func main() {
	base := flag.String("base", "http://localhost:8080/api/v1", "API base URL")
	users := flag.Int("users", 10, "concurrent synthetic users")
	duration := flag.Duration("duration", 60*time.Second, "test duration")
	rate := flag.Float64("rate", 2, "requests per second per user")
	mailbox := flag.String("mailbox", ".data/mail", "dev mailbox directory (local development only)")
	state := flag.String("state", ".data/loadtest-users.json", "file that remembers created users between runs")
	allowRemote := flag.Bool("allow-remote", false, "allow a non-local target (staging only; never production)")
	flag.Parse()

	u, err := url.Parse(*base)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") {
		fail("invalid -base")
	}
	if !isLocal(u.Hostname()) && !*allowRemote {
		fail("refusing non-local target " + u.Host + " without -allow-remote (never use production)")
	}
	fmt.Printf("target: %s  users: %d  duration: %s  rate: %.1f req/s/user\n", *base, *users, *duration, *rate)

	c := &client{base: strings.TrimRight(*base, "/"), http: &http.Client{Timeout: 15 * time.Second}}
	people, err := loadOrCreateUsers(c, *users, *mailbox, *state)
	if err != nil {
		fail(err.Error())
	}

	res := &results{byOp: map[string][]time.Duration{}, errs: map[string]int{}}
	ctx, cancel := context.WithTimeout(context.Background(), *duration)
	defer cancel()
	var wg sync.WaitGroup
	for i := range people {
		wg.Add(1)
		go func(p *person) {
			defer wg.Done()
			runUser(ctx, c, p, *rate, res)
		}(people[i])
	}
	wg.Wait()
	if !res.report() {
		os.Exit(1)
	}
}

func fail(msg string) {
	fmt.Fprintln(os.Stderr, "loadtest:", msg)
	os.Exit(2)
}

func isLocal(host string) bool {
	if host == "localhost" {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

type client struct {
	base string
	http *http.Client
}

type person struct {
	Email   string `json:"email"`
	Account string `json:"account"`
	token   string
	n       int
}

const password = "Loadtest-Pass-2026!" //nolint:gosec // synthetic load-test users on local/staging only

func (c *client) do(ctx context.Context, method, path, token string, body any, idem bool) (int, map[string]any, time.Duration, error) {
	var rdr io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.base+path, rdr)
	if err != nil {
		return 0, nil, 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Montra-Client", "android")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if idem {
		req.Header.Set("Idempotency-Key", uuid.NewString())
	}
	start := time.Now()
	resp, err := c.http.Do(req)
	elapsed := time.Since(start)
	if err != nil {
		return 0, nil, elapsed, err
	}
	defer func() { _ = resp.Body.Close() }()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	var out map[string]any
	_ = json.Unmarshal(raw, &out)
	return resp.StatusCode, out, elapsed, nil
}

var tokenRe = regexp.MustCompile(`#token=([A-Za-z0-9_-]+)`)

func verificationToken(dir, addr string, since time.Time) (string, error) {
	for attempt := 0; attempt < 30; attempt++ {
		entries, _ := os.ReadDir(dir)
		sort.Slice(entries, func(i, j int) bool { return entries[i].Name() > entries[j].Name() })
		for _, e := range entries {
			info, err := e.Info()
			if err != nil || info.ModTime().Before(since) {
				continue
			}
			raw, err := os.ReadFile(filepath.Join(dir, e.Name())) //nolint:gosec // local dev mailbox
			if err != nil || !bytes.Contains(raw, []byte(addr)) {
				continue
			}
			// Bodies are quoted-printable ("=3D", soft line breaks).
			decoded, err := io.ReadAll(quotedprintable.NewReader(bytes.NewReader(raw)))
			if err != nil {
				continue
			}
			if m := tokenRe.FindSubmatch(decoded); m != nil {
				return string(m[1]), nil
			}
		}
		time.Sleep(time.Second) // the worker delivers the email
	}
	return "", errors.New("no verification email for " + addr + " in " + dir + " (is the worker running with EMAIL_PROVIDER=dev_mailbox?)")
}

func login(c *client, p *person) error {
	for attempt := 0; attempt < 20; attempt++ {
		st, out, _, err := c.do(context.Background(), http.MethodPost, "/auth/login", "", map[string]any{"email": p.Email, "password": password}, false)
		if err != nil {
			return err
		}
		if st == http.StatusTooManyRequests {
			time.Sleep(7 * time.Second) // auth rate limit (~10/min per IP)
			continue
		}
		if st != http.StatusOK {
			return fmt.Errorf("login %s: HTTP %d", p.Email, st)
		}
		d, _ := out["data"].(map[string]any)
		p.token, _ = d["access_token"].(string)
		if p.token == "" {
			return errors.New("login returned no access token (two-step verification on a load-test user?)")
		}
		return nil
	}
	return errors.New("login kept hitting the rate limit")
}

func authPost(c *client, path string, body any, want int) error {
	for attempt := 0; attempt < 20; attempt++ {
		st, _, _, err := c.do(context.Background(), http.MethodPost, path, "", body, false)
		if err != nil {
			return err
		}
		if st == http.StatusTooManyRequests {
			time.Sleep(7 * time.Second)
			continue
		}
		if st != want {
			return fmt.Errorf("%s: HTTP %d", path, st)
		}
		return nil
	}
	return errors.New(path + " kept hitting the rate limit")
}

func loadOrCreateUsers(c *client, n int, mailbox, statePath string) ([]*person, error) {
	var saved []*person
	if raw, err := os.ReadFile(statePath); err == nil { //nolint:gosec // local state file
		_ = json.Unmarshal(raw, &saved)
	}
	for len(saved) < n {
		addr := fmt.Sprintf("loadtest.%s@example.com", uuid.NewString()[:12])
		since := time.Now().Add(-time.Second)
		if err := authPost(c, "/auth/register", map[string]any{"email": addr, "password": password, "display_name": "Load test",
			"accept_terms": true, "confirm_adult": true, "terms_version": "2026-11-01", "privacy_version": "2026-11-01",
			"timezone": "Asia/Kolkata", "currency": "INR"}, http.StatusAccepted); err != nil {
			return nil, err
		}
		tok, err := verificationToken(mailbox, addr, since)
		if err != nil {
			return nil, err
		}
		if err := authPost(c, "/auth/email/verify", map[string]any{"token": tok}, http.StatusOK); err != nil {
			return nil, err
		}
		saved = append(saved, &person{Email: addr})
		fmt.Printf("created %s\n", addr)
	}
	people := saved[:n]
	for _, p := range people {
		if err := login(c, p); err != nil {
			return nil, err
		}
		if p.Account == "" {
			st, out, _, err := c.do(context.Background(), http.MethodPost, "/accounts", p.token,
				map[string]any{"name": "Load test", "account_type": "bank", "currency": "INR", "opening_balance": "100000"}, true)
			if err != nil {
				return nil, fmt.Errorf("create account: %w", err)
			}
			if st != http.StatusCreated {
				return nil, fmt.Errorf("create account: HTTP %d", st)
			}
			d, _ := out["data"].(map[string]any)
			p.Account, _ = d["id"].(string)
		}
	}
	if err := os.MkdirAll(filepath.Dir(statePath), 0o700); err == nil {
		raw, _ := json.MarshalIndent(saved, "", "  ")
		_ = os.WriteFile(statePath, raw, 0o600)
	}
	return people, nil
}

type op struct {
	name   string
	method string
	path   func(p *person) string
	body   func(p *person) any
	write  bool
}

// mix is weighted towards reads, like real use (8 reads : 2 writes).
var mix = []op{
	{name: "dashboard", method: http.MethodGet, path: func(*person) string { return "/dashboard/summary" }},
	{name: "transactions.list", method: http.MethodGet, path: func(*person) string { return "/transactions?limit=50" }},
	{name: "accounts.list", method: http.MethodGet, path: func(*person) string { return "/accounts" }},
	{name: "analytics.categories", method: http.MethodGet, path: func(*person) string { return "/analytics/categories?range=this_month" }},
	{name: "transactions.list", method: http.MethodGet, path: func(*person) string { return "/transactions?limit=50&type=expense" }},
	{name: "budgets.list", method: http.MethodGet, path: func(*person) string { return "/budgets" }},
	{name: "notifications.unread", method: http.MethodGet, path: func(*person) string { return "/notifications/unread-count" }},
	{name: "analytics.cash_flow", method: http.MethodGet, path: func(*person) string { return "/analytics/cash-flow?range=last_30_days" }},
	{name: "transactions.create", method: http.MethodPost, path: func(*person) string { return "/transactions" }, write: true,
		body: func(p *person) any {
			return map[string]any{"type": "expense", "account_id": p.Account, "amount": fmt.Sprintf("%d.%02d", 10+p.n%500, p.n%100),
				"description": "Load test purchase"}
		}},
	{name: "transactions.create", method: http.MethodPost, path: func(*person) string { return "/transactions" }, write: true,
		body: func(p *person) any {
			return map[string]any{"type": "income", "account_id": p.Account, "amount": "250.00", "description": "Load test income"}
		}},
}

func runUser(ctx context.Context, c *client, p *person, rate float64, res *results) {
	if rate <= 0 {
		rate = 1
	}
	tick := time.NewTicker(time.Duration(float64(time.Second) / rate))
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
		}
		o := mix[p.n%len(mix)]
		p.n++
		var body any
		if o.body != nil {
			body = o.body(p)
		}
		st, _, d, err := c.do(ctx, o.method, o.path(p), p.token, body, o.write)
		if errors.Is(err, context.DeadlineExceeded) || ctx.Err() != nil {
			return
		}
		res.add(o, st, d, err)
	}
}

type results struct {
	mu   sync.Mutex
	byOp map[string][]time.Duration
	read []time.Duration
	wr   []time.Duration
	errs map[string]int
	n    int
}

func (r *results) add(o op, status int, d time.Duration, err error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.n++
	switch {
	case err != nil:
		r.errs["transport"]++
		return
	case status == http.StatusTooManyRequests:
		r.errs["429"]++
	case status >= 400:
		r.errs[fmt.Sprintf("%s %d", o.name, status)]++
	}
	r.byOp[o.name] = append(r.byOp[o.name], d)
	if o.write {
		r.wr = append(r.wr, d)
	} else {
		r.read = append(r.read, d)
	}
}

func pct(ds []time.Duration, q float64) time.Duration {
	if len(ds) == 0 {
		return 0
	}
	s := append([]time.Duration(nil), ds...)
	sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })
	i := int(q*float64(len(s))+0.5) - 1
	return s[min(max(i, 0), len(s)-1)]
}

func (r *results) report() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	names := make([]string, 0, len(r.byOp))
	for k := range r.byOp {
		names = append(names, k)
	}
	sort.Strings(names)
	fmt.Printf("\n%-24s %7s %9s %9s %9s\n", "operation", "count", "p50", "p95", "p99")
	for _, k := range names {
		ds := r.byOp[k]
		fmt.Printf("%-24s %7d %9s %9s %9s\n", k, len(ds), pct(ds, .5).Round(time.Millisecond), pct(ds, .95).Round(time.Millisecond),
			pct(ds, .99).Round(time.Millisecond))
	}
	errTotal := 0
	for k, v := range r.errs {
		fmt.Printf("errors %-30s %d\n", k, v)
		errTotal += v
	}
	readP95, writeP95 := pct(r.read, .95), pct(r.wr, .95)
	errRate := 0.0
	if r.n > 0 {
		errRate = float64(errTotal) / float64(r.n)
	}
	ok := r.n > 0 && readP95 < 500*time.Millisecond && writeP95 < 800*time.Millisecond && errRate < 0.01
	fmt.Printf("\nrequests %d  read p95 %s (target < 500ms)  write p95 %s (target < 800ms)  error rate %.2f%% (target < 1%%)  => %s\n",
		r.n, readP95.Round(time.Millisecond), writeP95.Round(time.Millisecond), errRate*100, map[bool]string{true: "PASS", false: "FAIL"}[ok])
	return ok
}
