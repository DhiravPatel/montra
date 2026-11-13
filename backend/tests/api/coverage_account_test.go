package api_test

import (
	"fmt"
	"net/http"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/platform/email"
	"montra/backend/internal/testutil/apitest"
)

// Coverage for account endpoints no other API test exercised: resending the
// verification email, preferences and consents reads, recovery-code
// regeneration and account deactivation.

func cvCountMail(s *apitest.Server, addr, category string) int {
	n := 0
	for _, m := range s.Mail.Messages(addr) {
		if m.Category == category {
			n++
		}
	}
	return n
}

func TestCoverageResendVerificationEmail(t *testing.T) {
	s := apitest.New(t, nil)
	anon := s.NewClient("android")
	addr := fmt.Sprintf("test.cvresend.%s@example.com", uuid.NewString()[:8])
	anon.Do(t, http.MethodPost, "/auth/register", map[string]any{"email": addr, "password": apitest.Password, "display_name": "Resender",
		"accept_terms": true, "confirm_adult": true, "terms_version": "2026-11-01", "privacy_version": "2026-11-01", "timezone": "Asia/Kolkata",
		"currency": "INR"}).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	first := s.Mail.LatestToken(t, addr, email.TplVerifyEmail)

	// Resends are limited to one per five-minute window (pinned clock).
	base := time.Now()
	s.Svcs.Auth.Now = func() time.Time { return base }
	t.Cleanup(func() { s.Svcs.Auth.Now = time.Now })
	// The answer never reveals whether an account exists or needs verifying.
	for _, e := range []string{addr, strings.ToUpper(addr), "nobody." + uuid.NewString()[:6] + "@example.com", "not-an-email"} {
		r := anon.Do(t, http.MethodPost, "/auth/email/resend", map[string]any{"email": e}).Expect(t, http.StatusAccepted)
		if r.Data()["message"] != "If your account needs verification, a new link is on its way." {
			t.Fatalf("resend answer for %q = %s", e, r.Raw)
		}
	}
	s.RunJobs(t)
	// One resend beyond the sign-up email, whatever the casing of the address.
	if n := cvCountMail(s, addr, email.TplVerifyEmail); n != 2 {
		t.Fatalf("verification emails after resends in one window = %d", n)
	}
	second := s.Mail.LatestToken(t, addr, email.TplVerifyEmail)
	if second == first {
		t.Fatal("the resent link reuses the sign-up token")
	}
	// The next window allows another one.
	s.Svcs.Auth.Now = func() time.Time { return base.Add(6 * time.Minute) }
	anon.Do(t, http.MethodPost, "/auth/email/resend", map[string]any{"email": addr}).Expect(t, http.StatusAccepted)
	anon.Do(t, http.MethodPost, "/auth/email/resend", map[string]any{"email": addr}).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	if n := cvCountMail(s, addr, email.TplVerifyEmail); n != 3 {
		t.Fatalf("verification emails after a later resend = %d", n)
	}
	// Each new link replaces the previous ones: only the latest verifies.
	latest := s.Mail.LatestToken(t, addr, email.TplVerifyEmail)
	s.Svcs.Auth.Now = time.Now
	for _, old := range []string{first, second} {
		if r := anon.Do(t, http.MethodPost, "/auth/email/verify", map[string]any{"token": old}); r.Status != http.StatusGone || r.ErrorCode() != "GONE" {
			t.Fatalf("superseded verification link: %d %s", r.Status, r.Raw)
		}
	}
	anon.Do(t, http.MethodPost, "/auth/email/verify", map[string]any{"token": latest}).Expect(t, http.StatusOK)
	// Verified accounts get nothing more.
	s.Svcs.Auth.Now = func() time.Time { return base.Add(20 * time.Minute) }
	anon = s.NewClient("android") // auth endpoints are rate limited per address
	anon.Do(t, http.MethodPost, "/auth/email/resend", map[string]any{"email": addr}).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	if n := cvCountMail(s, addr, email.TplVerifyEmail); n != 3 {
		t.Fatalf("verification email sent to a verified account: %d", n)
	}
	if r := anon.Do(t, http.MethodPost, "/auth/email/resend", map[string]any{"email": strings.Repeat("a", 321)}); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("oversized email: %d", r.Status)
	}
}

func TestCoveragePreferencesAndConsentsRead(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvprefs"))
	other, _ := s.Login(t, s.Register(t, "cvprefsother"))

	p := c.Do(t, http.MethodGet, "/me/preferences", nil).Expect(t, http.StatusOK).Data()
	if p["timezone"] != "Asia/Kolkata" || p["base_currency"] != "INR" || p["theme"] != "system" || p["ai_enabled"] != false ||
		p["week_start"] == nil || p["month_start_day"] == nil || p["updated_at"] == nil {
		t.Fatalf("preferences = %v", p)
	}
	upd := c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"theme": "dark", "week_start": 1, "high_contrast": true}).Expect(t, http.StatusOK).Data()
	got := c.Do(t, http.MethodGet, "/me/preferences", nil).Expect(t, http.StatusOK).Data()
	if got["theme"] != "dark" || got["week_start"] != float64(1) || got["high_contrast"] != true || got["timezone"] != "Asia/Kolkata" ||
		got["updated_at"] != upd["updated_at"] {
		t.Fatalf("preferences after update = %v", got)
	}
	if me := c.Do(t, http.MethodGet, "/me", nil).Expect(t, http.StatusOK).Data()["preferences"].(map[string]any); me["theme"] != "dark" {
		t.Fatalf("/me preferences = %v", me)
	}
	if o := other.Do(t, http.MethodGet, "/me/preferences", nil).Expect(t, http.StatusOK).Data(); o["theme"] != "system" {
		t.Fatalf("another user's preferences changed: %v", o)
	}
	s.NewClient("android").Do(t, http.MethodGet, "/me/preferences", nil).Expect(t, http.StatusUnauthorized)

	// Consents: sign-up records terms and privacy; grants and revocations
	// show in the active list, and history keeps revoked ones.
	types := func(l []any) []string {
		var out []string
		for _, x := range l {
			out = append(out, x.(map[string]any)["consent_type"].(string))
		}
		return out
	}
	active := c.Do(t, http.MethodGet, "/me/consents", nil).Expect(t, http.StatusOK).List()
	if got := types(active); !slices.Contains(got, "terms") || !slices.Contains(got, "privacy_policy") {
		t.Fatalf("sign-up consents = %v", active)
	}
	terms := gfFind(active, "consent_type", "terms")
	if terms["version"] != "2026-11-01" || terms["granted_at"] == nil || terms["revoked_at"] != nil {
		t.Fatalf("terms consent = %v", terms)
	}
	g := c.Do(t, http.MethodPost, "/me/consents", map[string]any{"consent_type": "marketing_email", "version": "2026-11-01"}).Expect(t, http.StatusCreated).Data()
	if l := types(c.Do(t, http.MethodGet, "/me/consents", nil).Expect(t, http.StatusOK).List()); !slices.Contains(l, "marketing_email") {
		t.Fatalf("active consents after grant = %v", l)
	}
	c.Do(t, http.MethodDelete, "/me/consents/marketing_email", nil).Expect(t, http.StatusOK)
	if l := types(c.Do(t, http.MethodGet, "/me/consents", nil).Expect(t, http.StatusOK).List()); slices.Contains(l, "marketing_email") {
		t.Fatalf("revoked consent still active: %v", l)
	}
	hist := c.Do(t, http.MethodGet, "/me/consents?history=true", nil).Expect(t, http.StatusOK).List()
	if h := gfFind(hist, "id", g["id"].(string)); h == nil || h["revoked_at"] == nil {
		t.Fatalf("consent history = %v", hist)
	}
	if l := other.Do(t, http.MethodGet, "/me/consents?history=true", nil).Expect(t, http.StatusOK).List(); gfFind(l, "id", g["id"].(string)) != nil {
		t.Fatal("another user's consents visible")
	}
	gfField(t, c.Do(t, http.MethodGet, "/me/consents?history=maybe", nil), "query.history")
}

func TestCoverageRegenerateRecoveryCodes(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "cvrecovery")
	c, _ := s.Login(t, addr)
	// Without two-step verification there is nothing to regenerate.
	if r := c.Do(t, http.MethodPost, "/me/mfa/recovery-codes", nil); r.Status != http.StatusConflict || r.ErrorCode() != "CONFLICT" {
		t.Fatalf("regenerate without MFA: %d %s", r.Status, r.Raw)
	}
	setup := c.Do(t, http.MethodPost, "/me/mfa/totp/setup", nil).Expect(t, http.StatusOK).Data()
	secret := setup["secret"].(string)
	old := c.Do(t, http.MethodPost, "/me/mfa/totp/activate", map[string]any{"code": totpCode(t, secret, time.Now())}).Expect(t, http.StatusOK).
		Data()["recovery_codes"].([]any)

	// Re-authentication is required once the window has passed.
	ageReauth(s, t)
	if r := c.Do(t, http.MethodPost, "/me/mfa/recovery-codes", nil); r.Status != http.StatusUnauthorized || r.ErrorCode() != "REAUTH_REQUIRED" {
		t.Fatalf("regenerate without re-auth: %d %s", r.Status, r.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password}); r.ErrorCode() != "MFA_REQUIRED" {
		t.Fatalf("re-auth without a code when MFA is on: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password, "recovery_code": old[0]}).Expect(t, http.StatusOK)
	fresh := c.Do(t, http.MethodPost, "/me/mfa/recovery-codes", nil).Expect(t, http.StatusOK).Data()["recovery_codes"].([]any)
	if len(fresh) != 10 {
		t.Fatalf("regenerated codes = %v", fresh)
	}
	seen := map[string]bool{}
	for _, x := range fresh {
		code := x.(string)
		if seen[code] || len(code) != 11 || code[5] != '-' {
			t.Fatalf("bad recovery code %q in %v", code, fresh)
		}
		seen[code] = true
		for _, o := range old {
			if o == code {
				t.Fatal("a regenerated code equals an old one")
			}
		}
	}
	if n := workerCount(t, s, `select count(*) from security_events where user_id = (select id from users where email_normalized = $1)
		and event_type = 'mfa_recovery_regenerated'`, strings.ToLower(addr)); n != 1 {
		t.Fatalf("regeneration security events = %d", n)
	}
	// Old codes stop working; new ones work once.
	login := func() string {
		return s.NewClient("android").Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).
			Expect(t, http.StatusOK).Data()["mfa_token"].(string)
	}
	verify := func(code any) *apitest.Response {
		return s.NewClient("android").Do(t, http.MethodPost, "/auth/mfa/verify", map[string]any{"mfa_token": login(), "recovery_code": code})
	}
	if r := verify(old[1]); r.Status != http.StatusUnauthorized {
		t.Fatalf("an old recovery code still signs in: %d", r.Status)
	}
	verify(fresh[0]).Expect(t, http.StatusOK)
	if r := verify(fresh[0]); r.Status != http.StatusUnauthorized {
		t.Fatalf("a recovery code worked twice: %d", r.Status)
	}
}

func TestCoverageDeactivateAccount(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "cvdeactivate")
	c, refresh := s.Login(t, addr)
	second, _ := s.Login(t, addr)
	acct := createAccount(t, c, map[string]any{"name": "Kept", "account_type": "cash", "currency": "INR", "opening_balance": "42"})["id"].(string)

	ageReauth(s, t)
	if r := c.Do(t, http.MethodPost, "/me/deactivate", nil); r.Status != http.StatusUnauthorized || r.ErrorCode() != "REAUTH_REQUIRED" {
		t.Fatalf("deactivate without re-auth: %d %s", r.Status, r.Raw)
	}
	c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/me/deactivate", nil).Expect(t, http.StatusOK)

	// Every session ends at once, including refresh.
	for _, cl := range []*apitest.Client{c, second} {
		if r := cl.Do(t, http.MethodGet, "/me", nil); r.Status != http.StatusUnauthorized {
			t.Fatalf("session after deactivation: %d", r.Status)
		}
	}
	if r := s.NewClient("android").Do(t, http.MethodPost, "/auth/refresh", map[string]any{"refresh_token": refresh}); r.Status != http.StatusUnauthorized {
		t.Fatalf("refresh after deactivation: %d %s", r.Status, r.Raw)
	}
	if n := workerCount(t, s, `select count(*) from users where email_normalized = $1 and status = 'deactivated' and deactivated_at is not null`,
		strings.ToLower(addr)); n != 1 {
		t.Fatal("account not marked deactivated")
	}
	if n := workerCount(t, s, `select count(*) from security_events e join users u on u.id = e.user_id where u.email_normalized = $1
		and e.event_type = 'account_deactivated'`, strings.ToLower(addr)); n != 1 {
		t.Fatalf("deactivation security events = %d", n)
	}
	// Signing in again reactivates it with the data intact.
	back, _ := s.Login(t, addr)
	if balance(t, back, acct) != "42.00" {
		t.Fatalf("data after reactivation: %s", balance(t, back, acct))
	}
	if n := workerCount(t, s, `select count(*) from users where email_normalized = $1 and status = 'active' and deactivated_at is null`,
		strings.ToLower(addr)); n != 1 {
		t.Fatal("signing in did not reactivate the account")
	}
	s.NewClient("android").Do(t, http.MethodPost, "/me/deactivate", nil).Expect(t, http.StatusUnauthorized)
}
