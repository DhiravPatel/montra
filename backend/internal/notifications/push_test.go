package notifications

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/hkdf"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	dto "github.com/prometheus/client_model/go"

	"montra/backend/internal/platform/observability"
)

var enc = base64.RawURLEncoding

// decrypt is the user agent side of RFC 8291 (for verification only).
func decrypt(t *testing.T, ua *ecdh.PrivateKey, auth, body []byte) []byte {
	t.Helper()
	salt, rs, idlen := body[:16], binary.BigEndian.Uint32(body[16:20]), int(body[20])
	if rs != 4096 || idlen != 65 {
		t.Fatalf("header rs=%d idlen=%d", rs, idlen)
	}
	asPub, ct := body[21:21+idlen], body[21+idlen:]
	as, err := ecdh.P256().NewPublicKey(asPub)
	if err != nil {
		t.Fatal(err)
	}
	shared, _ := ua.ECDH(as)
	prkKey, _ := hkdf.Extract(sha256.New, shared, auth)
	ikm, _ := hkdf.Expand(sha256.New, prkKey, "WebPush: info\x00"+string(ua.PublicKey().Bytes())+string(asPub), 32)
	prk, _ := hkdf.Extract(sha256.New, ikm, salt)
	cek, _ := hkdf.Expand(sha256.New, prk, "Content-Encoding: aes128gcm\x00", 16)
	nonce, _ := hkdf.Expand(sha256.New, prk, "Content-Encoding: nonce\x00", 12)
	block, _ := aes.NewCipher(cek)
	gcm, _ := cipher.NewGCM(block)
	plain, err := gcm.Open(nil, nonce, ct, nil)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}
	if plain[len(plain)-1] != 0x02 {
		t.Fatal("missing record delimiter")
	}
	return plain[:len(plain)-1]
}

func vapidKeys(t *testing.T) (string, string, *ecdsa.PublicKey) {
	t.Helper()
	k, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	ek, _ := k.PublicKey.ECDH()
	raw, _ := k.Bytes()
	return enc.EncodeToString(ek.Bytes()), enc.EncodeToString(raw), &k.PublicKey
}

func TestWebPushEncryptionVAPIDAndHosts(t *testing.T) {
	ua, _ := ecdh.P256().GenerateKey(rand.Reader)
	auth := make([]byte, 16)
	_, _ = rand.Read(auth)
	var got []byte
	var authz, encoding string
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got, _ = io.ReadAll(r.Body)
		authz, encoding = r.Header.Get("Authorization"), r.Header.Get("Content-Encoding")
		w.WriteHeader(http.StatusCreated)
	}))
	defer srv.Close()
	host := strings.TrimPrefix(srv.URL, "https://")
	pub, priv, vapidPub := vapidKeys(t)
	wp, err := NewWebPush(pub, priv, "mailto:ops@montra.example", []string{strings.Split(host, ":")[0]})
	if err != nil {
		t.Fatal(err)
	}
	wp.SetHTTPClient(srv.Client())
	sub := WebPushSubscription{Endpoint: srv.URL + "/push/abc"}
	sub.Keys.P256dh, sub.Keys.Auth = enc.EncodeToString(ua.PublicKey().Bytes()), enc.EncodeToString(auth)
	if err := wp.Send(context.Background(), sub, []byte(`{"title":"Hi"}`), 60, "normal"); err != nil {
		t.Fatal(err)
	}
	if encoding != "aes128gcm" || string(decrypt(t, ua, auth, got)) != `{"title":"Hi"}` {
		t.Fatalf("encoding=%s body decrypts wrong", encoding)
	}
	// VAPID: "vapid t=<jwt>, k=<public key>" with a valid ES256 signature for the origin.
	parts := strings.Split(strings.TrimPrefix(authz, "vapid t="), ", k=")
	if len(parts) != 2 || parts[1] != pub {
		t.Fatalf("authorization = %s", authz)
	}
	seg := strings.Split(parts[0], ".")
	var claims map[string]any
	cb, _ := enc.DecodeString(seg[1])
	_ = json.Unmarshal(cb, &claims)
	if claims["aud"] != srv.URL || claims["sub"] != "mailto:ops@montra.example" {
		t.Fatalf("claims = %v", claims)
	}
	sig, _ := enc.DecodeString(seg[2])
	digest := sha256.Sum256([]byte(seg[0] + "." + seg[1]))
	if !ecdsa.Verify(vapidPub, digest[:], new(big.Int).SetBytes(sig[:32]), new(big.Int).SetBytes(sig[32:])) {
		t.Fatal("VAPID signature does not verify")
	}
	// Unknown hosts are never contacted.
	bad := sub
	bad.Endpoint = "https://attacker.example/x"
	if err := wp.Send(context.Background(), bad, []byte("x"), 60, "normal"); !errors.Is(err, ErrPushRejected) {
		t.Fatalf("unknown host: %v", err)
	}
	for host, ok := range map[string]bool{"fcm.googleapis.com": true, "updates.push.services.mozilla.com": true, "web.push.apple.com": true,
		"wns2-par02p.notify.windows.com": true, "evil-fcm.googleapis.com.attacker.io": false, "169.254.169.254": false, "localhost": false} {
		if AllowedPushHost(host, nil) != ok {
			t.Fatalf("AllowedPushHost(%s) != %v", host, ok)
		}
	}
	if _, err := NewWebPush(pub, enc.EncodeToString(make([]byte, 32)), "mailto:x@y.z", nil); err == nil {
		t.Fatal("mismatched VAPID keys accepted")
	}
}

func TestWebPushGoneAndRetry(t *testing.T) {
	code := http.StatusGone
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(code) }))
	defer srv.Close()
	pub, priv, _ := vapidKeys(t)
	u, _ := url.Parse(srv.URL)
	wp, _ := NewWebPush(pub, priv, "mailto:a@b.c", []string{u.Hostname()})
	wp.SetHTTPClient(srv.Client())
	ua, _ := ecdh.P256().GenerateKey(rand.Reader)
	sub := WebPushSubscription{Endpoint: srv.URL + "/p"}
	sub.Keys.P256dh, sub.Keys.Auth = enc.EncodeToString(ua.PublicKey().Bytes()), enc.EncodeToString(make([]byte, 16))
	if err := wp.Send(context.Background(), sub, []byte("x"), 60, "high"); !errors.Is(err, ErrEndpointGone) {
		t.Fatalf("410: %v", err)
	}
	code = http.StatusServiceUnavailable
	if err := wp.Send(context.Background(), sub, []byte("x"), 60, "high"); !errors.Is(err, ErrPushRetry) {
		t.Fatalf("503: %v", err)
	}
}

func TestFCMTokenExchangeAndSend(t *testing.T) {
	key, _ := rsa.GenerateKey(rand.Reader, 2048)
	der, _ := x509.MarshalPKCS8PrivateKey(key)
	var assertion, sent string
	status := http.StatusOK
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/token":
			_ = r.ParseForm()
			assertion = r.PostForm.Get("assertion")
			_, _ = io.WriteString(w, `{"access_token":"at-123","expires_in":3600}`)
		case "/v1/projects/proj-1/messages:send":
			if r.Header.Get("Authorization") != "Bearer at-123" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}
			b, _ := io.ReadAll(r.Body)
			sent = string(b)
			w.WriteHeader(status)
			if status == http.StatusNotFound {
				_, _ = io.WriteString(w, `{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}`)
			}
		}
	}))
	defer srv.Close()
	file := filepath.Join(t.TempDir(), "sa.json")
	sa, _ := json.Marshal(map[string]string{"client_email": "push@proj-1.iam.gserviceaccount.com", "token_uri": srv.URL + "/token", "project_id": "proj-1",
		"private_key": string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))})
	if err := os.WriteFile(file, sa, 0o600); err != nil {
		t.Fatal(err)
	}
	f, err := NewFCM("", file, srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Send(context.Background(), "device-token-123", "Budget alert", "Open Montra", map[string]string{"url": "/budgets"}, true); err != nil {
		t.Fatal(err)
	}
	seg := strings.Split(assertion, ".")
	cb, _ := enc.DecodeString(seg[1])
	var claims map[string]any
	_ = json.Unmarshal(cb, &claims)
	if claims["iss"] != "push@proj-1.iam.gserviceaccount.com" || claims["aud"] != srv.URL+"/token" || !strings.Contains(sent, `"token":"device-token-123"`) ||
		!strings.Contains(sent, `"priority":"HIGH"`) {
		t.Fatalf("claims=%v sent=%s", claims, sent)
	}
	status = http.StatusNotFound
	if err := f.Send(context.Background(), "gone", "t", "b", nil, false); !errors.Is(err, ErrEndpointGone) {
		t.Fatalf("unregistered: %v", err)
	}
	status = http.StatusInternalServerError
	if err := f.Send(context.Background(), "x", "t", "b", nil, false); !errors.Is(err, ErrPushRetry) {
		t.Fatalf("500: %v", err)
	}
}

func TestUsesDigest(t *testing.T) {
	if usesDigest("security", "normal", "daily", "") || usesDigest("budget", "high", "daily", "") || !usesDigest("budget", "normal", "daily", "immediate") ||
		usesDigest("budget", "normal", "off", "immediate") || !usesDigest("goal", "low", "off", "weekly") {
		t.Fatal("digest rules")
	}
}

func TestProviderCallMetrics(t *testing.T) {
	m := observability.New("montra-test")
	s := &Service{Metrics: m}
	s.providerCall("webpush", nil, time.Millisecond)
	s.providerCall("webpush", ErrEndpointGone, time.Millisecond)
	s.providerCall("fcm", fmt.Errorf("x: %w", ErrPushRetry), time.Millisecond)
	s.providerCall("smtp", errors.New("boom"), time.Millisecond)
	for _, c := range []struct{ provider, outcome string }{{"webpush", "ok"}, {"webpush", "gone"}, {"fcm", "retry"}, {"smtp", "error"}} {
		var got dto.Metric
		if err := m.ProviderCalls.WithLabelValues(c.provider, "send", c.outcome).Write(&got); err != nil || got.GetCounter().GetValue() != 1 {
			t.Fatalf("%s/%s = %v (%v)", c.provider, c.outcome, got.GetCounter().GetValue(), err)
		}
	}
}
