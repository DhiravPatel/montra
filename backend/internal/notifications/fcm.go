package notifications

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

// FCM sends native push through the Firebase Cloud Messaging HTTP v1 API
// with a service account (OAuth 2.0 JWT bearer grant).
type FCM struct {
	project  string
	email    string
	key      *rsa.PrivateKey
	tokenURI string
	baseURL  string
	client   *http.Client
	now      func() time.Time

	mu      sync.Mutex
	token   string
	expires time.Time
}

type serviceAccount struct {
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
	TokenURI    string `json:"token_uri"`
	ProjectID   string `json:"project_id"`
}

// NewFCM loads a service-account JSON file. baseURL overrides the FCM API
// origin (tests); empty means https://fcm.googleapis.com.
func NewFCM(project, credentialsFile, baseURL string) (*FCM, error) {
	raw, err := os.ReadFile(credentialsFile) //nolint:gosec // owner-configured path
	if err != nil {
		return nil, fmt.Errorf("FCM_CREDENTIALS_FILE: %w", err)
	}
	var sa serviceAccount
	if err := json.Unmarshal(raw, &sa); err != nil || sa.ClientEmail == "" || sa.PrivateKey == "" {
		return nil, errors.New("FCM_CREDENTIALS_FILE is not a service-account key")
	}
	block, _ := pem.Decode([]byte(sa.PrivateKey))
	if block == nil {
		return nil, errors.New("FCM service-account private key is not PEM")
	}
	k, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("FCM private key: %w", err)
	}
	rk, ok := k.(*rsa.PrivateKey)
	if !ok {
		return nil, errors.New("FCM private key must be RSA")
	}
	if sa.TokenURI == "" {
		sa.TokenURI = "https://oauth2.googleapis.com/token"
	}
	if project == "" {
		project = sa.ProjectID
	}
	if baseURL == "" {
		baseURL = "https://fcm.googleapis.com"
	}
	return &FCM{project: project, email: sa.ClientEmail, key: rk, tokenURI: sa.TokenURI, baseURL: strings.TrimRight(baseURL, "/"),
		client: &http.Client{Timeout: 15 * time.Second}, now: time.Now}, nil
}

func (f *FCM) accessToken(ctx context.Context) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.token != "" && f.now().Before(f.expires.Add(-time.Minute)) {
		return f.token, nil
	}
	enc := base64.RawURLEncoding
	now := f.now()
	claims, _ := json.Marshal(map[string]any{"iss": f.email, "scope": "https://www.googleapis.com/auth/firebase.messaging", "aud": f.tokenURI,
		"iat": now.Unix(), "exp": now.Add(time.Hour).Unix()})
	signing := enc.EncodeToString([]byte(`{"alg":"RS256","typ":"JWT"}`)) + "." + enc.EncodeToString(claims)
	sum := sha256.Sum256([]byte(signing))
	sig, err := rsa.SignPKCS1v15(rand.Reader, f.key, crypto.SHA256, sum[:])
	if err != nil {
		return "", err
	}
	form := url.Values{"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"}, "assertion": {signing + "." + enc.EncodeToString(sig)}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.tokenURI, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := f.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("%w: %w", ErrPushRetry, err)
	}
	defer func() { _ = resp.Body.Close() }()
	var tok struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if resp.StatusCode != http.StatusOK || json.NewDecoder(io.LimitReader(resp.Body, 1<<16)).Decode(&tok) != nil || tok.AccessToken == "" {
		return "", fmt.Errorf("%w: token exchange failed (status %d)", ErrPushRetry, resp.StatusCode)
	}
	f.token, f.expires = tok.AccessToken, now.Add(time.Duration(max(tok.ExpiresIn, 60))*time.Second)
	return f.token, nil
}

// Send delivers one message to a registration token.
func (f *FCM) Send(ctx context.Context, token, title, body string, data map[string]string, high bool) error {
	at, err := f.accessToken(ctx)
	if err != nil {
		return err
	}
	priority := "NORMAL"
	if high {
		priority = "HIGH"
	}
	msg, _ := json.Marshal(map[string]any{"message": map[string]any{"token": token, "notification": map[string]string{"title": title, "body": body},
		"data": data, "android": map[string]any{"priority": priority}, "apns": map[string]any{"headers": map[string]string{"apns-priority": map[bool]string{true: "10", false: "5"}[high]}}}})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.baseURL+"/v1/projects/"+url.PathEscape(f.project)+"/messages:send", bytes.NewReader(msg))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+at)
	resp, err := f.client.Do(req)
	if err != nil {
		return fmt.Errorf("%w: %w", ErrPushRetry, err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))
	switch {
	case resp.StatusCode == http.StatusOK:
		return nil
	case resp.StatusCode == http.StatusNotFound || strings.Contains(string(raw), "UNREGISTERED"):
		return ErrEndpointGone
	case resp.StatusCode == http.StatusUnauthorized:
		f.mu.Lock()
		f.token = "" // refresh on retry
		f.mu.Unlock()
		return fmt.Errorf("%w (status 401)", ErrPushRetry)
	case resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500:
		return fmt.Errorf("%w (status %d)", ErrPushRetry, resp.StatusCode)
	default:
		return fmt.Errorf("%w (status %d)", ErrPushRejected, resp.StatusCode)
	}
}
