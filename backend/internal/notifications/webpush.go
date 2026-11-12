package notifications

import (
	"bytes"
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
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// Push delivery outcomes.
var (
	ErrEndpointGone = errors.New("push endpoint no longer exists") // 404/410: disable it
	ErrPushRejected = errors.New("push service rejected the message")
	ErrPushRetry    = errors.New("push service temporarily unavailable")
)

// pushHosts are the browser push services Montra will send to. Anything
// else is refused at registration and before sending (no request to an
// arbitrary URL — SSRF protection).
var pushHosts = []string{"fcm.googleapis.com", "updates.push.services.mozilla.com", "web.push.apple.com", ".push.apple.com",
	".notify.windows.com", "push.services.mozilla.com"}

// AllowedPushHost reports whether a Web Push endpoint host is a known push
// service. extra hosts (tests only) are allowed exactly.
func AllowedPushHost(host string, extra []string) bool {
	host = strings.ToLower(host)
	for _, h := range extra {
		if host == strings.ToLower(h) {
			return true
		}
	}
	for _, h := range pushHosts {
		if host == h || (strings.HasPrefix(h, ".") && strings.HasSuffix(host, h)) {
			return true
		}
	}
	return false
}

// WebPushSubscription is a browser PushSubscription.
type WebPushSubscription struct {
	Endpoint string `json:"endpoint"`
	Keys     struct {
		P256dh string `json:"p256dh"`
		Auth   string `json:"auth"`
	} `json:"keys"`
}

// WebPush sends encrypted Web Push messages (RFC 8291) authenticated with
// VAPID (RFC 8292).
type WebPush struct {
	publicKey []byte // uncompressed P-256 point
	private   *ecdsa.PrivateKey
	subject   string
	client    *http.Client
	extra     []string
	now       func() time.Time
}

// NewWebPush parses VAPID keys (base64url: 65-byte public point, 32-byte
// private scalar).
func NewWebPush(publicB64, privateB64, subject string, extraHosts []string) (*WebPush, error) {
	pub, err := b64(publicB64)
	if err != nil || len(pub) != 65 || pub[0] != 4 {
		return nil, errors.New("VAPID_PUBLIC_KEY must be a base64url uncompressed P-256 point")
	}
	raw, err := b64(privateB64)
	if err != nil || len(raw) != 32 {
		return nil, errors.New("VAPID_PRIVATE_KEY must be a base64url 32-byte P-256 scalar")
	}
	priv, err := ecdsa.ParseRawPrivateKey(elliptic.P256(), raw)
	if err != nil {
		return nil, fmt.Errorf("VAPID_PRIVATE_KEY: %w", err)
	}
	ek, err := priv.PublicKey.ECDH()
	if err != nil || !bytes.Equal(ek.Bytes(), pub) {
		return nil, errors.New("VAPID public and private keys do not match")
	}
	if !strings.HasPrefix(subject, "mailto:") && !strings.HasPrefix(subject, "https://") {
		return nil, errors.New("VAPID_SUBJECT must be a mailto: or https: URL")
	}
	return &WebPush{publicKey: pub, private: priv, subject: subject, client: &http.Client{Timeout: 15 * time.Second}, extra: extraHosts,
		now: time.Now}, nil
}

func b64(s string) ([]byte, error) {
	s = strings.TrimRight(strings.TrimSpace(s), "=")
	return base64.RawURLEncoding.DecodeString(s)
}

// SetHTTPClient replaces the HTTP client (tests).
func (w *WebPush) SetHTTPClient(c *http.Client) { w.client = c }

// PublicKey returns the VAPID public key (base64url) for clients.
func (w *WebPush) PublicKey() string { return base64.RawURLEncoding.EncodeToString(w.publicKey) }

// Encrypt produces an aes128gcm body for a subscription (RFC 8291 §3).
func Encrypt(sub WebPushSubscription, payload []byte, salt []byte, sender *ecdh.PrivateKey) ([]byte, error) {
	uaPublic, err := b64(sub.Keys.P256dh)
	if err != nil || len(uaPublic) != 65 {
		return nil, errors.New("invalid subscription key")
	}
	authSecret, err := b64(sub.Keys.Auth)
	if err != nil || len(authSecret) != 16 {
		return nil, errors.New("invalid subscription auth secret")
	}
	ua, err := ecdh.P256().NewPublicKey(uaPublic)
	if err != nil {
		return nil, err
	}
	shared, err := sender.ECDH(ua)
	if err != nil {
		return nil, err
	}
	asPublic := sender.PublicKey().Bytes()
	keyInfo := "WebPush: info\x00" + string(uaPublic) + string(asPublic)
	prkKey, err := hkdf.Extract(sha256.New, shared, authSecret)
	if err != nil {
		return nil, err
	}
	ikm, err := hkdf.Expand(sha256.New, prkKey, keyInfo, 32)
	if err != nil {
		return nil, err
	}
	prk, err := hkdf.Extract(sha256.New, ikm, salt)
	if err != nil {
		return nil, err
	}
	cek, err := hkdf.Expand(sha256.New, prk, "Content-Encoding: aes128gcm\x00", 16)
	if err != nil {
		return nil, err
	}
	nonce, err := hkdf.Expand(sha256.New, prk, "Content-Encoding: nonce\x00", 12)
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(cek)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	plain := append(append([]byte{}, payload...), 0x02) // last-record delimiter, no padding
	ct := gcm.Seal(nil, nonce, plain, nil)
	var hdr bytes.Buffer
	hdr.Write(salt)
	_ = binary.Write(&hdr, binary.BigEndian, uint32(4096))
	hdr.WriteByte(byte(len(asPublic)))
	hdr.Write(asPublic)
	return append(hdr.Bytes(), ct...), nil
}

// vapidJWT signs the VAPID token for the push service origin (ES256).
func (w *WebPush) vapidJWT(aud string) (string, error) {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"typ":"JWT","alg":"ES256"}`))
	claims, err := json.Marshal(map[string]any{"aud": aud, "exp": w.now().Add(12 * time.Hour).Unix(), "sub": w.subject})
	if err != nil {
		return "", err
	}
	signing := header + "." + base64.RawURLEncoding.EncodeToString(claims)
	digest := sha256.Sum256([]byte(signing))
	r, s, err := ecdsa.Sign(rand.Reader, w.private, digest[:])
	if err != nil {
		return "", err
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	return signing + "." + base64.RawURLEncoding.EncodeToString(sig), nil
}

// Send encrypts and posts one message. ttl is seconds; urgency is
// very-low | low | normal | high.
func (w *WebPush) Send(ctx context.Context, sub WebPushSubscription, payload []byte, ttl int, urgency string) error {
	u, err := url.Parse(sub.Endpoint)
	if err != nil || u.Scheme != "https" || !AllowedPushHost(u.Hostname(), w.extra) {
		return fmt.Errorf("%w: endpoint host not allowed", ErrPushRejected)
	}
	sender, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		return err
	}
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return err
	}
	body, err := Encrypt(sub, payload, salt, sender)
	if err != nil {
		return fmt.Errorf("%w: %w", ErrPushRejected, err)
	}
	jwt, err := w.vapidJWT(u.Scheme + "://" + u.Host)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, sub.Endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("Content-Encoding", "aes128gcm")
	req.Header.Set("TTL", strconv.Itoa(ttl))
	req.Header.Set("Urgency", urgency)
	req.Header.Set("Authorization", "vapid t="+jwt+", k="+base64.RawURLEncoding.EncodeToString(w.publicKey))
	resp, err := w.client.Do(req)
	if err != nil {
		return fmt.Errorf("%w: %w", ErrPushRetry, err)
	}
	defer func() { _ = resp.Body.Close() }()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
	switch {
	case resp.StatusCode >= 200 && resp.StatusCode < 300:
		return nil
	case resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusGone:
		return ErrEndpointGone
	case resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500:
		return fmt.Errorf("%w (status %d)", ErrPushRetry, resp.StatusCode)
	default:
		return fmt.Errorf("%w (status %d)", ErrPushRejected, resp.StatusCode)
	}
}
