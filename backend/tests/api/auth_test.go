package api_test

import (
	"encoding/base32"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/testutil/apitest"
)

func registerBody(addr, pw string) map[string]any {
	return map[string]any{"email": addr, "password": pw, "display_name": "Test User", "accept_terms": true, "confirm_adult": true,
		"terms_version": "2026-11-01", "privacy_version": "2026-11-01", "timezone": "Asia/Kolkata", "currency": "INR"}
}

func TestRegistrationIsEnumerationSafe(t *testing.T) {
	s := apitest.New(t, nil)
	c := s.NewClient("android")
	addr := s.Register(t, "enum")
	r1 := c.Do(t, http.MethodPost, "/auth/register", registerBody("brand.new.enum@example.com", apitest.Password)).Expect(t, http.StatusAccepted)
	r2 := c.Do(t, http.MethodPost, "/auth/register", registerBody(strings.ToUpper(addr), "Other-Pass-2026!")).Expect(t, http.StatusAccepted)
	if r1.Data()["message"] != r2.Data()["message"] || r1.Data()["status"] != r2.Data()["status"] {
		t.Fatalf("registration responses differ: %v vs %v", r1.Data(), r2.Data())
	}
	s.RunJobs(t)
	found := false
	for _, m := range s.Mail.Messages(addr) {
		if m.Category == email.TplAccountExists {
			found = true
		}
	}
	if !found {
		t.Fatal("existing account owner was not notified of the sign-up attempt")
	}
	// Unknown email and wrong password are indistinguishable.
	a := c.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": "unknown.person@example.com", "password": "Wrong-Pass-2026"})
	b := c.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": "Wrong-Pass-2026"})
	if a.Status != b.Status || a.ErrorCode() != b.ErrorCode() || a.Body["error"].(map[string]any)["message"] != b.Body["error"].(map[string]any)["message"] {
		t.Fatalf("login errors leak account existence: %s vs %s", a.Raw, b.Raw)
	}
}

func TestLoginRequiresVerifiedEmail(t *testing.T) {
	s := apitest.New(t, nil)
	c := s.NewClient("android")
	addr := "test.unverified." + strings.ToLower(time.Now().Format("150405.000000")) + "@example.com"
	c.Do(t, http.MethodPost, "/auth/register", registerBody(addr, apitest.Password)).Expect(t, http.StatusAccepted)
	r := c.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusForbidden)
	if r.ErrorCode() != "EMAIL_NOT_VERIFIED" {
		t.Fatalf("code = %s", r.ErrorCode())
	}
	s.RunJobs(t)
	tok := s.Mail.LatestToken(t, addr, email.TplVerifyEmail)
	c.Do(t, http.MethodPost, "/auth/email/verify", map[string]any{"token": tok}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/auth/email/verify", map[string]any{"token": tok}).Expect(t, http.StatusGone) // single use
	c.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusOK)
}

func TestRefreshRotationAndReuseDetection(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "rotation")
	c, rt := s.Login(t, addr)
	oldAccess := c.Bearer
	c.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusOK)

	r := c.Do(t, http.MethodPost, "/auth/refresh", map[string]any{"refresh_token": rt}).Expect(t, http.StatusOK)
	newAccess := r.Data()["access_token"].(string)
	newRefresh := r.Data()["refresh_token"].(string)
	if newAccess == oldAccess || newRefresh == rt {
		t.Fatal("tokens were not rotated")
	}
	c.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusUnauthorized) // old access token revoked by rotation
	c.Bearer = newAccess
	c.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusOK)

	// Within the grace window, replaying the old refresh token fails without revoking.
	c.Do(t, http.MethodPost, "/auth/refresh", map[string]any{"refresh_token": rt}).Expect(t, http.StatusUnauthorized)
	c.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusOK)

	// After the grace window, replay is treated as theft: the session is revoked.
	s.Env.ExecWorker(t, `update user_session_refresh_history set rotated_at = now() - interval '5 minutes'`)
	c.Do(t, http.MethodPost, "/auth/refresh", map[string]any{"refresh_token": rt}).Expect(t, http.StatusUnauthorized)
	c.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusUnauthorized)
	c.Do(t, http.MethodPost, "/auth/refresh", map[string]any{"refresh_token": newRefresh}).Expect(t, http.StatusUnauthorized)
}

func TestSessionsListRevokeAndLogoutAll(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "sessions")
	phone, _ := s.Login(t, addr)
	tablet, _ := s.Login(t, addr)
	list := phone.Do(t, http.MethodGet, "/me/sessions", nil).Expect(t, http.StatusOK).List()
	if len(list) != 2 {
		t.Fatalf("expected 2 sessions, got %d", len(list))
	}
	var tabletID string
	for _, it := range list {
		m := it.(map[string]any)
		if m["current"] != true {
			tabletID = m["id"].(string)
		}
	}
	phone.Do(t, http.MethodDelete, "/me/sessions/"+tabletID, nil).Expect(t, http.StatusOK)
	tablet.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusUnauthorized)
	// Another user cannot revoke this user's session (404, not 403).
	other, _ := s.Login(t, s.Register(t, "intruder"))
	mine := phone.Do(t, http.MethodGet, "/me/sessions", nil).List()[0].(map[string]any)["id"].(string)
	other.Do(t, http.MethodDelete, "/me/sessions/"+mine, nil).Expect(t, http.StatusNotFound)
	phone.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusOK)

	phone.Do(t, http.MethodPost, "/auth/logout-all", nil).Expect(t, http.StatusOK)
	phone.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusUnauthorized)
}

func TestLoginThrottling(t *testing.T) {
	s := apitest.New(t, map[string]string{"AUTH_LOGIN_MAX_FAILURES": "3"})
	addr := s.Register(t, "throttle")
	c := s.NewClient("android")
	for i := 0; i < 3; i++ {
		c.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": "Wrong-Pass-2026"}).Expect(t, http.StatusUnauthorized)
	}
	r := s.NewClient("android").Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password})
	if r.Status != http.StatusTooManyRequests || r.ErrorCode() != "LOGIN_THROTTLED" {
		t.Fatalf("expected LOGIN_THROTTLED, got %d %s", r.Status, r.Raw)
	}
}

func TestWebCookieSessionRequiresCSRF(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "csrf")
	web := s.NewClient("web")
	r := web.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusOK)
	if _, leaked := r.Data()["access_token"]; leaked {
		t.Fatal("web login must not expose tokens in the body")
	}
	if len(r.Headers.Values("Set-Cookie")) < 3 {
		t.Fatalf("expected session cookies, got %v", r.Headers.Values("Set-Cookie"))
	}
	for _, ck := range r.Headers.Values("Set-Cookie") {
		if (strings.HasPrefix(ck, "montra_at=") || strings.HasPrefix(ck, "montra_rt=")) && !strings.Contains(ck, "HttpOnly") {
			t.Fatalf("session cookie not HttpOnly: %s", ck)
		}
	}
	web.Do(t, http.MethodGet, "/me/sessions", nil).Expect(t, http.StatusOK)
	bad := web.Do(t, http.MethodPost, "/auth/logout", nil, "X-CSRF-Token", "forged")
	if bad.Status != http.StatusForbidden || bad.ErrorCode() != "CSRF_FAILED" {
		t.Fatalf("forged CSRF accepted: %d %s", bad.Status, bad.Raw)
	}
	web.Do(t, http.MethodPost, "/auth/logout", nil).Expect(t, http.StatusOK) // jar-provided CSRF token
	web.Do(t, http.MethodGet, "/me/sessions", nil).Expect(t, http.StatusUnauthorized)
}

func totpCode(t *testing.T, secret string, at time.Time) string {
	key, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(secret)
	if err != nil {
		t.Fatal(err)
	}
	return crypto.HOTP(key, crypto.TOTPStep(at))
}

func TestMFAEnrollmentLoginReplayAndRecovery(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "mfa")
	c, _ := s.Login(t, addr)
	// Signing in counts as a fresh authentication; age it beyond the
	// re-authentication window to exercise the gate.
	s.Env.ExecWorker(t, `update user_sessions set last_reauth_at = now() - interval '1 hour'`)
	r := c.Do(t, http.MethodPost, "/me/mfa/totp/setup", nil)
	if r.Status != http.StatusUnauthorized || r.ErrorCode() != "REAUTH_REQUIRED" {
		t.Fatalf("MFA setup must require re-authentication, got %d %s", r.Status, r.Raw)
	}
	c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password}).Expect(t, http.StatusOK)
	setup := c.Do(t, http.MethodPost, "/me/mfa/totp/setup", nil).Expect(t, http.StatusOK).Data()
	secret := setup["secret"].(string)
	if !strings.HasPrefix(setup["otpauth_uri"].(string), "otpauth://totp/") {
		t.Fatal("bad otpauth uri")
	}
	c.Do(t, http.MethodPost, "/me/mfa/totp/activate", map[string]any{"code": "000000"}).Expect(t, http.StatusUnprocessableEntity)
	// Activation consumes the current step; use the next step's code for login.
	act := c.Do(t, http.MethodPost, "/me/mfa/totp/activate", map[string]any{"code": totpCode(t, secret, time.Now())}).Expect(t, http.StatusOK).Data()
	codes := act["recovery_codes"].([]any)
	if len(codes) != 10 {
		t.Fatalf("expected 10 recovery codes, got %d", len(codes))
	}
	// The security alert is emailed once (its dedicated template) and also
	// listed in the notification center.
	s.RunJobs(t)
	if n := notificationsOf(t, c, "security", "security.mfa_enabled"); n != 1 {
		t.Fatalf("security alerts in the notification center: %d", n)
	}
	alerts, generic := 0, 0
	for _, m := range s.Mail.Messages(addr) {
		switch m.Category {
		case email.TplMFAChanged:
			alerts++
		case email.TplNotification:
			generic++
		}
	}
	if alerts != 1 || generic != 0 {
		t.Fatalf("security emails: %d dedicated, %d generic", alerts, generic)
	}

	login := s.NewClient("android").Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusOK).Data()
	if login["status"] != "mfa_required" || login["access_token"] != nil {
		t.Fatalf("expected MFA challenge without tokens: %v", login)
	}
	mfaTok := login["mfa_token"].(string)
	next := totpCode(t, secret, time.Now().Add(30*time.Second))
	ok := s.NewClient("android").Do(t, http.MethodPost, "/auth/mfa/verify", map[string]any{"mfa_token": mfaTok, "code": next}).Expect(t, http.StatusOK).Data()
	if ok["access_token"] == nil {
		t.Fatal("MFA verification did not issue a session")
	}
	// Replay of the same code (or an older step) is rejected.
	login2 := s.NewClient("android").Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Data()
	s.NewClient("android").Do(t, http.MethodPost, "/auth/mfa/verify", map[string]any{"mfa_token": login2["mfa_token"], "code": next}).Expect(t, http.StatusUnauthorized)
	// A recovery code works exactly once.
	rc := codes[0].(string)
	s.NewClient("android").Do(t, http.MethodPost, "/auth/mfa/verify", map[string]any{"mfa_token": login2["mfa_token"], "recovery_code": rc}).Expect(t, http.StatusOK)
	login3 := s.NewClient("android").Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Data()
	s.NewClient("android").Do(t, http.MethodPost, "/auth/mfa/verify", map[string]any{"mfa_token": login3["mfa_token"], "recovery_code": rc}).Expect(t, http.StatusUnauthorized)
}

func TestPasswordResetRevokesSessions(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "reset")
	c, _ := s.Login(t, addr)
	anon := s.NewClient("android")
	anon.Do(t, http.MethodPost, "/auth/password/forgot", map[string]any{"email": addr}).Expect(t, http.StatusAccepted)
	anon.Do(t, http.MethodPost, "/auth/password/forgot", map[string]any{"email": "no.such.user@example.com"}).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	tok := s.Mail.LatestToken(t, addr, email.TplPasswordReset)
	weak := anon.Do(t, http.MethodPost, "/auth/password/reset", map[string]any{"token": tok, "new_password": "password123"})
	if weak.Status != http.StatusUnprocessableEntity {
		t.Fatalf("weak reset password accepted: %s", weak.Raw)
	}
	anon.Do(t, http.MethodPost, "/auth/password/reset", map[string]any{"token": tok, "new_password": "Brand-New-Pass-2026"}).Expect(t, http.StatusOK)
	anon.Do(t, http.MethodPost, "/auth/password/reset", map[string]any{"token": tok, "new_password": "Another-New-Pass-2026"}).Expect(t, http.StatusGone)
	c.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusUnauthorized)
	anon.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusUnauthorized)
	anon.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": "Brand-New-Pass-2026"}).Expect(t, http.StatusOK)
}

func TestAuthRateLimit(t *testing.T) {
	s := apitest.New(t, nil)
	c := s.NewClient("android")
	limited := false
	for i := 0; i < 25; i++ {
		r := c.Do(t, http.MethodPost, "/auth/password/forgot", map[string]any{"email": "rate.limit@example.com"})
		if r.Status == http.StatusTooManyRequests {
			limited = true
			if r.Headers.Get("Retry-After") == "" || r.ErrorCode() != "RATE_LIMITED" {
				t.Fatalf("429 without Retry-After/RATE_LIMITED: %v %s", r.Headers, r.Raw)
			}
			break
		}
	}
	if !limited {
		t.Fatal("auth endpoint was never rate limited")
	}
}

// Local development can bypass email verification (AUTH_DEV_AUTO_VERIFY_EMAIL,
// refused outside APP_ENV=development by config): sign-up needs no email
// and existing unverified accounts are verified at their next sign-in.
func TestDevelopmentEmailVerificationBypass(t *testing.T) {
	s := apitest.New(t, map[string]string{"APP_ENV": "development", "AUTH_DEV_AUTO_VERIFY_EMAIL": "true"})
	addr := fmt.Sprintf("dev.bypass.%s@example.com", uuid.NewString()[:8])
	c := s.NewClient("android")
	c.Do(t, http.MethodPost, "/auth/register", map[string]any{
		"email": addr, "password": apitest.Password, "display_name": "Dev bypass", "accept_terms": true, "confirm_adult": true,
		"terms_version": "2026-11-01", "privacy_version": "2026-11-01", "timezone": "Asia/Kolkata", "currency": "INR",
	}).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	if n := len(s.Mail.Messages(addr)); n != 0 {
		t.Fatalf("verification email sent despite the bypass: %d", n)
	}
	login := c.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusOK).Data()
	if login["access_token"] == nil {
		t.Fatalf("sign-in without verification failed: %v", login)
	}
	c.Bearer = login["access_token"].(string)
	if me := c.Do(t, http.MethodGet, "/me", nil).Expect(t, http.StatusOK).Data()["account"].(map[string]any); me["email_verified"] != true {
		t.Fatalf("account not marked verified: %v", me)
	}
	// An account left unverified (created before the bypass) is verified at sign-in.
	uid := userID(t, s, addr)
	s.Env.ExecWorker(t, `update users set email_verified_at = null where id = $1`, uid)
	c.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from security_events where user_id = $1 and event_type = 'email_verified'
		and details->>'method' = 'development_bypass'`, uid); n != 2 {
		t.Fatalf("bypass security events: %d", n)
	}
}
