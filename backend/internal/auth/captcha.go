package auth

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"montra/backend/internal/platform/apperr"
)

// CaptchaVerifier validates bot-protection tokens.
type CaptchaVerifier interface {
	Verify(ctx context.Context, token, remoteIP string) error
	Enabled() bool
}

// NewTurnstile returns a Cloudflare Turnstile verifier, or a no-op verifier
// when no secret is configured (local development).
func NewTurnstile(secret string) CaptchaVerifier {
	if secret == "" {
		return noCaptcha{}
	}
	return &turnstile{secret: secret, endpoint: "https://challenges.cloudflare.com/turnstile/v0/siteverify",
		client: &http.Client{Timeout: 5 * time.Second}}
}

type noCaptcha struct{}

func (noCaptcha) Verify(context.Context, string, string) error { return nil }
func (noCaptcha) Enabled() bool                                { return false }

type turnstile struct {
	secret   string
	endpoint string
	client   *http.Client
}

func (t *turnstile) Enabled() bool { return true }

func (t *turnstile) Verify(ctx context.Context, token, remoteIP string) error {
	if token == "" || len(token) > 4096 {
		return apperr.FieldError("body.captcha_token", "Complete the security check.")
	}
	form := url.Values{"secret": {t.secret}, "response": {token}}
	if remoteIP != "" {
		form.Set("remoteip", remoteIP)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, t.endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return apperr.Internal(err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := t.client.Do(req)
	if err != nil {
		// Fail closed: without verification the request is rejected.
		return apperr.Unavailable(apperr.CodeProviderUnavailable, "The security check is temporarily unavailable. Try again shortly.").WithCause(err)
	}
	defer func() { _ = resp.Body.Close() }()
	var out struct {
		Success bool `json:"success"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 64<<10)).Decode(&out); err != nil || !out.Success {
		return apperr.FieldError("body.captcha_token", "The security check failed. Try again.")
	}
	return nil
}
