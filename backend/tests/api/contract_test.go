package api_test

import (
	"net/http"
	"strconv"
	"testing"
	"time"

	"montra/backend/internal/testutil/apitest"
)

func firstDetailField(r *apitest.Response) string {
	if e, ok := r.Body["error"].(map[string]any); ok {
		if d, ok := e["details"].([]any); ok && len(d) > 0 {
			f, _ := d[0].(map[string]any)["field"].(string)
			return f
		}
	}
	return ""
}

// Regression tests for contract issues reported by the client foundations
// (docs/IMPLEMENTATION_STATUS.md, C-1…C-10).
func TestAuthContractBehaviors(t *testing.T) {
	s := apitest.New(t, map[string]string{"AUTH_LOGIN_MAX_FAILURES": "3"})
	addr := s.Register(t, "contract")
	c, _ := s.Login(t, addr)

	// C-7: the current session reports its real creation time.
	sess := c.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusOK).Data()["session"].(map[string]any)
	created, err := time.Parse(time.RFC3339Nano, sess["created_at"].(string))
	if err != nil || time.Since(created) > time.Minute || created.After(time.Now().Add(time.Minute)) {
		t.Fatalf("session created_at = %v", sess["created_at"])
	}

	// C-4: password-policy errors name the submitted field.
	r := c.Do(t, http.MethodPost, "/me/password", map[string]any{"current_password": apitest.Password, "new_password": "password123"})
	if r.Status != http.StatusUnprocessableEntity || firstDetailField(r) != "body.new_password" {
		t.Fatalf("policy error field = %q (%s)", firstDetailField(r), r.Raw)
	}

	// C-5: web sessions refresh with an empty body.
	web := s.NewClient("web")
	web.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusOK)
	web.Do(t, http.MethodPost, "/auth/refresh", nil).Expect(t, http.StatusOK)

	// C-6: throttled sign-ins say when to retry.
	other := s.Register(t, "contract-throttle")
	anon := s.NewClient("android")
	for i := 0; i < 3; i++ {
		anon.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": other, "password": "Wrong-Pass-2026"}).Expect(t, http.StatusUnauthorized)
	}
	th := s.NewClient("android").Do(t, http.MethodPost, "/auth/login", map[string]any{"email": other, "password": apitest.Password})
	if secs, err := strconv.Atoi(th.Headers.Get("Retry-After")); th.ErrorCode() != "LOGIN_THROTTLED" || err != nil || secs <= 0 || secs > 15*60 {
		t.Fatalf("throttle Retry-After = %q (%s)", th.Headers.Get("Retry-After"), th.Raw)
	}

	// C-8 / C-9: distinct MFA failure codes; recovery codes re-authenticate once.
	setup := c.Do(t, http.MethodPost, "/me/mfa/totp/setup", nil).Expect(t, http.StatusOK).Data()
	secret := setup["secret"].(string)
	act := c.Do(t, http.MethodPost, "/me/mfa/totp/activate", map[string]any{"code": totpCode(t, secret, time.Now())}).Expect(t, http.StatusOK).Data()
	rc := act["recovery_codes"].([]any)[0].(string)
	login := s.NewClient("android").Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Data()
	wrong := s.NewClient("android").Do(t, http.MethodPost, "/auth/mfa/verify", map[string]any{"mfa_token": login["mfa_token"], "code": "000000"})
	if wrong.Status != http.StatusUnauthorized || wrong.ErrorCode() != "MFA_CODE_INVALID" {
		t.Fatalf("wrong MFA code: %d %s", wrong.Status, wrong.Raw)
	}
	s.Env.ExecWorker(t, `update auth_tokens set expires_at = now() - interval '1 minute' where purpose = 'mfa_challenge'`)
	expired := s.NewClient("android").Do(t, http.MethodPost, "/auth/mfa/verify", map[string]any{"mfa_token": login["mfa_token"], "code": "000000"})
	if expired.ErrorCode() != "MFA_CHALLENGE_EXPIRED" {
		t.Fatalf("expired MFA attempt: %s", expired.Raw)
	}
	s.Env.ExecWorker(t, `update user_sessions set last_reauth_at = now() - interval '1 hour'`)
	c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password, "recovery_code": rc}).Expect(t, http.StatusOK)
	if again := c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password, "recovery_code": rc}); again.ErrorCode() != "MFA_CODE_INVALID" {
		t.Fatalf("recovery code reused: %s", again.Raw)
	}
	if missing := c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password}); missing.ErrorCode() != "MFA_REQUIRED" {
		t.Fatalf("missing second factor: %s", missing.Raw)
	}
	// This session proved the second factor at re-authentication, so turning
	// two-step off needs no second code.
	c.Do(t, http.MethodPost, "/me/mfa/totp/disable", map[string]any{}).Expect(t, http.StatusOK)
	legal := s.NewClient("web").Do(t, http.MethodGet, "/legal", nil).Expect(t, http.StatusOK).Data()
	if legal["terms_version"] == "" || legal["privacy_version"] == "" {
		t.Fatalf("legal versions = %v", legal)
	}
}

func TestCurrenciesAndRetiredCurrencies(t *testing.T) {
	s := apitest.New(t, nil)
	list := s.NewClient("web").Do(t, http.MethodGet, "/currencies", nil).Expect(t, http.StatusOK).List()
	byCode := map[string]map[string]any{}
	for _, x := range list {
		m := x.(map[string]any)
		byCode[m["code"].(string)] = m
	}
	if inr := byCode["INR"]; inr == nil || inr["exponent"] != float64(2) || inr["selectable"] != true {
		t.Fatalf("INR = %v", inr)
	}
	if jpy := byCode["JPY"]; jpy["exponent"] != float64(0) {
		t.Fatalf("JPY = %v", jpy)
	}
	if bgn := byCode["BGN"]; bgn == nil || bgn["selectable"] != false || bgn["replaced_by"] != "EUR" {
		t.Fatalf("BGN = %v", bgn)
	}
	c, _ := s.Login(t, s.Register(t, "currencies"))
	r := c.Do(t, http.MethodPost, "/accounts", map[string]any{"name": "Old lev", "account_type": "bank", "currency": "BGN"}, "Idempotency-Key", key())
	if r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("new BGN account accepted: %s", r.Raw)
	}
	createAccount(t, c, map[string]any{"name": "Euro", "account_type": "bank", "currency": "EUR"})
}
