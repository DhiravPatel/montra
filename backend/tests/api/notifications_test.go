package api_test

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/hkdf"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
	"montra/backend/internal/testutil/apitest"
)

var b64u = base64.RawURLEncoding

// pushService is a local stand-in for a browser push service: it records
// requests and answers with scripted statuses (201 once the script ends).
type pushService struct {
	mu       sync.Mutex
	statuses []int
	got      []pushRequest
}

type pushRequest struct {
	header http.Header
	body   []byte
}

func (p *pushService) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	p.mu.Lock()
	p.got = append(p.got, pushRequest{header: r.Header.Clone(), body: body})
	status := http.StatusCreated
	if len(p.statuses) > 0 {
		status, p.statuses = p.statuses[0], p.statuses[1:]
	}
	p.mu.Unlock()
	w.WriteHeader(status)
}

func (p *pushService) script(statuses ...int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.statuses = statuses
}

func (p *pushService) requests() []pushRequest {
	p.mu.Lock()
	defer p.mu.Unlock()
	return append([]pushRequest(nil), p.got...)
}

// decryptPush reverses RFC 8291 aes128gcm as a browser would.
func decryptPush(t *testing.T, ua *ecdh.PrivateKey, auth, body []byte) []byte {
	t.Helper()
	if len(body) < 21 {
		t.Fatal("push body too short")
	}
	salt, rs, idlen := body[:16], binary.BigEndian.Uint32(body[16:20]), int(body[20])
	if rs < 18 || len(body) < 21+idlen {
		t.Fatalf("bad header rs=%d idlen=%d", rs, idlen)
	}
	keyid, ct := body[21:21+idlen], body[21+idlen:]
	as, err := ecdh.P256().NewPublicKey(keyid)
	if err != nil {
		t.Fatalf("sender key: %v", err)
	}
	shared, err := ua.ECDH(as)
	if err != nil {
		t.Fatal(err)
	}
	prkKey, _ := hkdf.Extract(sha256.New, shared, auth)
	info := "WebPush: info\x00" + string(ua.PublicKey().Bytes()) + string(keyid)
	ikm, _ := hkdf.Expand(sha256.New, prkKey, info, 32)
	prk, _ := hkdf.Extract(sha256.New, ikm, salt)
	cek, _ := hkdf.Expand(sha256.New, prk, "Content-Encoding: aes128gcm\x00", 16)
	nonce, _ := hkdf.Expand(sha256.New, prk, "Content-Encoding: nonce\x00", 12)
	block, err := aes.NewCipher(cek)
	if err != nil {
		t.Fatal(err)
	}
	gcm, _ := cipher.NewGCM(block)
	plain, err := gcm.Open(nil, nonce, ct, nil)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}
	i := len(plain) - 1
	for i >= 0 && plain[i] == 0 {
		i--
	}
	if i < 0 || plain[i] != 2 {
		t.Fatal("missing last-record delimiter")
	}
	return plain[:i]
}

// verifyVAPID checks the RFC 8292 Authorization header.
func verifyVAPID(t *testing.T, header string, pub *ecdsa.PublicKey, pubB64, aud, sub string) {
	t.Helper()
	m := regexp.MustCompile(`^vapid t=([^,]+), k=(.+)$`).FindStringSubmatch(header)
	if m == nil || m[2] != pubB64 {
		t.Fatalf("authorization header: %q", header)
	}
	parts := strings.Split(m[1], ".")
	if len(parts) != 3 {
		t.Fatal("jwt shape")
	}
	sig, _ := b64u.DecodeString(parts[2])
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if len(sig) != 64 || !ecdsa.Verify(pub, digest[:], new(big.Int).SetBytes(sig[:32]), new(big.Int).SetBytes(sig[32:])) {
		t.Fatal("VAPID signature does not verify")
	}
	raw, _ := b64u.DecodeString(parts[1])
	var claims struct {
		Aud string `json:"aud"`
		Sub string `json:"sub"`
		Exp int64  `json:"exp"`
	}
	if err := json.Unmarshal(raw, &claims); err != nil || claims.Aud != aud || claims.Sub != sub ||
		claims.Exp <= time.Now().Unix() || claims.Exp > time.Now().Add(24*time.Hour).Unix() {
		t.Fatalf("claims: %+v (want aud %s)", claims, aud)
	}
}

// notify creates a notification the way services do (worker role).
func notify(t *testing.T, s *apitest.Server, n notifications.Notification) uuid.UUID {
	t.Helper()
	ctx := context.Background()
	var id uuid.UUID
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var err error
		id, _, err = notifications.Create(ctx, tx, n)
		return err
	}); err != nil {
		t.Fatal(err)
	}
	return id
}

func deliveryOf(t *testing.T, s *apitest.Server, nid uuid.UUID, channel string) (status, reason string) {
	t.Helper()
	ctx := context.Background()
	var r *string
	err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select status, skip_reason from notification_deliveries where notification_id = $1 and channel = $2`, nid, channel).
			Scan(&status, &r)
	})
	if err != nil {
		return "none", ""
	}
	if r != nil {
		reason = *r
	}
	return status, reason
}

func TestWebPushEncryptedDeliveryRetriesAndGoneEndpoints(t *testing.T) {
	s := apitest.New(t, nil)
	svc := &pushService{}
	ts := httptest.NewTLSServer(svc)
	t.Cleanup(ts.Close)

	vapid, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	vpub, _ := vapid.PublicKey.ECDH()
	pubB64 := b64u.EncodeToString(vpub.Bytes())
	vpriv, err := vapid.Bytes()
	if err != nil {
		t.Fatal(err)
	}
	wp, err := notifications.NewWebPush(pubB64, b64u.EncodeToString(vpriv), "mailto:ops@montra.test", []string{"127.0.0.1"})
	if err != nil {
		t.Fatal(err)
	}
	wp.SetHTTPClient(ts.Client())
	s.WorkerSvcs.Notify.WebPush = wp
	s.Svcs.Notify.PushHostsExtra = []string{"127.0.0.1"}

	pushAddr := s.Register(t, "pushy")
	c, _ := s.Login(t, pushAddr)
	uid := userID(t, s, pushAddr)
	ua, _ := ecdh.P256().GenerateKey(rand.Reader)
	auth := make([]byte, 16)
	_, _ = rand.Read(auth)
	sub := func(endpoint string) map[string]any {
		return map[string]any{"kind": "webpush", "device_label": "Test browser", "subscription": map[string]any{"endpoint": endpoint,
			"keys": map[string]any{"p256dh": b64u.EncodeToString(ua.PublicKey().Bytes()), "auth": b64u.EncodeToString(auth)}}}
	}

	// Montra only posts to known push services, over HTTPS, with sane keys.
	c.Do(t, http.MethodPost, "/me/push-endpoints", sub("https://push.evil.example/abc")).Expect(t, http.StatusUnprocessableEntity)
	c.Do(t, http.MethodPost, "/me/push-endpoints", sub(strings.Replace(ts.URL, "https://", "http://", 1)+"/abc")).Expect(t, http.StatusUnprocessableEntity)
	bad := sub(ts.URL + "/abc")
	bad["subscription"].(map[string]any)["keys"].(map[string]any)["p256dh"] = "c2hvcnQ"
	c.Do(t, http.MethodPost, "/me/push-endpoints", bad).Expect(t, http.StatusUnprocessableEntity)
	ep := c.Do(t, http.MethodPost, "/me/push-endpoints", sub(ts.URL+"/push/abc")).Expect(t, http.StatusCreated).Data()["id"].(string)

	// Delivery: encrypted for the browser's keys, VAPID-signed for the push
	// service, carrying only the safe title/body and an app path.
	n1 := notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.milestone", Title: "Goal milestone reached",
		Body: "You are halfway to a goal.", DeepLink: "/goals", Priority: "normal"})
	s.RunJobs(t)
	reqs := svc.requests()
	if len(reqs) != 1 {
		t.Fatalf("push requests: %d", len(reqs))
	}
	h := reqs[0].header
	if h.Get("Content-Encoding") != "aes128gcm" || h.Get("TTL") != "86400" || h.Get("Urgency") != "normal" {
		t.Fatalf("push headers: %v", h)
	}
	verifyVAPID(t, h.Get("Authorization"), &vapid.PublicKey, pubB64, ts.URL, "mailto:ops@montra.test")
	if strings.Contains(string(reqs[0].body), "Goal milestone") {
		t.Fatal("push body is not encrypted")
	}
	var payload map[string]string
	if err := json.Unmarshal(decryptPush(t, ua, auth, reqs[0].body), &payload); err != nil {
		t.Fatal(err)
	}
	if payload["title"] != "Goal milestone reached" || payload["url"] != "/goals" || payload["id"] != n1.String() || payload["tag"] != "goal" {
		t.Fatalf("payload: %v", payload)
	}
	if st, _ := deliveryOf(t, s, n1, "web_push"); st != "sent" {
		t.Fatalf("delivery: %s", st)
	}

	// A transient push-service failure is retried.
	svc.script(http.StatusServiceUnavailable)
	n2 := notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.milestone", Title: "Another milestone",
		Body: "Keep going.", DeepLink: "/goals", Priority: "high"})
	s.RunJobs(t)
	if st, _ := deliveryOf(t, s, n2, "web_push"); st != "sent" || len(svc.requests()) != 3 {
		t.Fatalf("retry: %s after %d requests", st, len(svc.requests()))
	}
	if svc.requests()[2].header.Get("Urgency") != "high" {
		t.Fatal("high priority should be urgent")
	}

	// An unsubscribed browser (410) disables the endpoint; later
	// notifications no longer target it.
	svc.script(http.StatusGone)
	n3 := notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.milestone", Title: "Third", Body: "x", Priority: "normal"})
	s.RunJobs(t)
	if st, reason := deliveryOf(t, s, n3, "web_push"); st != "skipped" || reason != "endpoint_gone" {
		t.Fatalf("gone: %s/%s", st, reason)
	}
	if n := workerCount(t, s, `select count(*) from push_endpoints where id = $1 and disabled_at is not null`, ep); n != 1 {
		t.Fatal("endpoint not disabled")
	}
	n4 := notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.milestone", Title: "Fourth", Body: "x", Priority: "normal"})
	s.RunJobs(t)
	if st, _ := deliveryOf(t, s, n4, "web_push"); st != "none" || len(svc.requests()) != 4 {
		t.Fatalf("after gone: %s, %d requests", st, len(svc.requests()))
	}

	// Subscriptions are stored encrypted, never as the raw endpoint.
	if n := workerCount(t, s, `select count(*) from push_endpoints where position('127.0.0.1' in encode(subscription_ciphertext, 'escape')) > 0`); n != 0 {
		t.Fatal("subscription stored in clear")
	}
}

var unsubRe = regexp.MustCompile(`#token=([A-Za-z0-9_.-]+)`)

func TestEmailDigestAndOneClickUnsubscribe(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "digest")
	c, _ := s.Login(t, addr)
	uid := userID(t, s, addr)
	c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"email_digest": "daily"}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPatch, "/notifications/preferences", map[string]any{"items": []any{
		map[string]any{"category": "goal", "channel": "email", "enabled": true}}}).Expect(t, http.StatusOK)
	before := len(s.Mail.Messages(addr))

	// Routine emails wait for the digest; urgent ones go now with an
	// unsubscribe link; security emails never carry one.
	routine := notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.milestone", Title: "Routine goal update",
		Body: "Progress.", DeepLink: "/goals", Priority: "normal"})
	urgent := notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.deadline", Title: "Goal deadline tomorrow",
		Body: "A goal is due tomorrow.", DeepLink: "/goals", Priority: "high"})
	security := notify(t, s, notifications.Notification{UserID: uid, Category: "security", EventType: "security.test", Title: "New sign-in",
		Body: "A new device signed in.", Priority: "normal"})
	s.RunJobs(t)
	if st, reason := deliveryOf(t, s, routine, "email"); st != "skipped" || reason != "digest" {
		t.Fatalf("routine: %s/%s", st, reason)
	}
	for _, id := range []uuid.UUID{urgent, security} {
		if st, _ := deliveryOf(t, s, id, "email"); st != "sent" {
			t.Fatalf("immediate email %s: %s", id, st)
		}
	}
	var unsub, secText string
	for _, m := range s.Mail.Messages(addr)[before:] {
		switch {
		case strings.Contains(m.Subject, "Routine goal update"):
			t.Fatal("routine email was not held for the digest")
		case strings.Contains(m.Subject, "Goal deadline tomorrow"):
			if mm := unsubRe.FindStringSubmatch(m.Text); mm != nil {
				unsub = mm[1]
			}
		case strings.Contains(m.Subject, "New sign-in"):
			secText = m.Text
		}
	}
	if unsub == "" || secText == "" || strings.Contains(secText, "#token=") {
		t.Fatalf("unsubscribe link: %q, security email: %q", unsub, secText)
	}

	// The digest goes out at 08:00 local time, once.
	n := time.Now().UTC()
	at := time.Date(n.Year(), n.Month(), n.Day(), 2, 30, 0, 0, time.UTC) // 08:00 in Asia/Kolkata
	sent := len(s.Mail.Messages(addr))
	for i := 0; i < 2; i++ {
		if err := s.WorkerSvcs.Notify.DigestScan(context.Background(), at); err != nil {
			t.Fatal(err)
		}
		s.RunJobs(t)
	}
	msgs := s.Mail.Messages(addr)[sent:]
	if len(msgs) != 1 || msgs[0].Subject != "Your Montra digest: 1 update" || !strings.Contains(msgs[0].Text, "Routine goal update") {
		t.Fatalf("digest emails: %+v", msgs)
	}
	if _, reason := deliveryOf(t, s, routine, "email"); reason != "digested" {
		t.Fatalf("after digest: %s", reason)
	}
	if err := s.WorkerSvcs.Notify.DigestScan(context.Background(), at.Add(time.Hour)); err != nil { // 09:00: not digest time
		t.Fatal(err)
	}
	s.RunJobs(t)
	if len(s.Mail.Messages(addr)) != sent+1 {
		t.Fatal("digest sent twice")
	}

	// One-click unsubscribe works without signing in, only with an intact token.
	anon := s.NewClient("web")
	tampered := unsub[:len(unsub)-2] + map[bool]string{true: "AA", false: "BB"}[!strings.HasSuffix(unsub, "AA")]
	anon.Do(t, http.MethodPost, "/notifications/unsubscribe", map[string]any{"token": tampered}).Expect(t, http.StatusGone)
	r := anon.Do(t, http.MethodPost, "/notifications/unsubscribe", map[string]any{"token": unsub}).Expect(t, http.StatusOK).Data()
	if r["category"] != "goal" || r["channel"] != "email" {
		t.Fatalf("unsubscribe: %v", r)
	}
	for _, p := range c.Do(t, http.MethodGet, "/notifications/preferences", nil).Expect(t, http.StatusOK).List() {
		m := p.(map[string]any)
		if m["category"] == "goal" && m["channel"] == "email" && m["enabled"] != false {
			t.Fatalf("goal email still enabled: %v", m)
		}
	}
	later := notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.deadline", Title: "After unsubscribe",
		Body: "x", Priority: "high"})
	s.RunJobs(t)
	if st, _ := deliveryOf(t, s, later, "email"); st != "none" {
		t.Fatalf("email after unsubscribe: %s", st)
	}
}
