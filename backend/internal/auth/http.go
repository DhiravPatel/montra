package auth

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/ratelimit"
)

// ---------------------------------------------------------------------------
// Request bodies (validated by Huma from these schemas, then by the service)
// ---------------------------------------------------------------------------

type registerBody struct {
	Email          string `json:"email" maxLength:"320" doc:"Account email address"`
	Password       string `json:"password" minLength:"10" maxLength:"128"`
	DisplayName    string `json:"display_name" minLength:"1" maxLength:"80"`
	AcceptTerms    bool   `json:"accept_terms" doc:"Must be true"`
	ConfirmAdult   bool   `json:"confirm_adult" doc:"Confirms the minimum age policy"`
	TermsVersion   string `json:"terms_version" maxLength:"40"`
	PrivacyVersion string `json:"privacy_version" maxLength:"40"`
	Locale         string `json:"locale,omitempty" maxLength:"10" example:"en-IN"`
	Timezone       string `json:"timezone,omitempty" maxLength:"64" example:"Asia/Kolkata"`
	Currency       string `json:"currency,omitempty" pattern:"^[A-Z]{3}$" example:"INR"`
	Country        string `json:"country,omitempty" pattern:"^[A-Z]{2}$" example:"IN"`
	CaptchaToken   string `json:"captcha_token,omitempty" maxLength:"4096"`
}

type loginBody struct {
	Email        string `json:"email" maxLength:"320"`
	Password     string `json:"password" maxLength:"128"`
	DeviceName   string `json:"device_name,omitempty" maxLength:"120"`
	CaptchaToken string `json:"captcha_token,omitempty" maxLength:"4096"`
}

type mfaVerifyBody struct {
	MFAToken     string `json:"mfa_token" maxLength:"128"`
	Code         string `json:"code,omitempty" maxLength:"6"`
	RecoveryCode string `json:"recovery_code,omitempty" maxLength:"20"`
	DeviceName   string `json:"device_name,omitempty" maxLength:"120"`
}

type refreshBody struct {
	RefreshToken string `json:"refresh_token,omitempty" maxLength:"128" doc:"Mobile clients; web uses the HttpOnly cookie"`
}

type emailBody struct {
	Email        string `json:"email" maxLength:"320"`
	CaptchaToken string `json:"captcha_token,omitempty" maxLength:"4096"`
}

type tokenBody struct {
	Token string `json:"token" maxLength:"128"`
}

type resetBody struct {
	Token       string `json:"token" maxLength:"128"`
	NewPassword string `json:"new_password" minLength:"10" maxLength:"128"`
}

type reauthBody struct {
	Password     string `json:"password" maxLength:"128"`
	Code         string `json:"code,omitempty" maxLength:"6" doc:"Authenticator code when two-step verification is on"`
	RecoveryCode string `json:"recovery_code,omitempty" maxLength:"20" doc:"Single-use recovery code instead of an authenticator code"`
}

type changePasswordBody struct {
	CurrentPassword string `json:"current_password" maxLength:"128"`
	NewPassword     string `json:"new_password" minLength:"10" maxLength:"128"`
}

type codeBody struct {
	Code string `json:"code" minLength:"6" maxLength:"6"`
}

type disableMFABody struct {
	Code         string `json:"code,omitempty" maxLength:"6"`
	RecoveryCode string `json:"recovery_code,omitempty" maxLength:"20"`
}

// AcceptedMessage is returned for enumeration-safe asynchronous requests.
type AcceptedMessage struct {
	Status  string `json:"status" enum:"accepted"`
	Message string `json:"message"`
}

// ---------------------------------------------------------------------------
// Outputs carrying cookies
// ---------------------------------------------------------------------------

type authOutput struct {
	SetCookie []http.Cookie `header:"Set-Cookie"`
	Body      httpx.Envelope[AuthResult]
}

type cookieDoneOutput struct {
	SetCookie []http.Cookie `header:"Set-Cookie"`
	Body      httpx.Envelope[httpx.Empty]
}

func (s *Service) cookies(iss *issued) []http.Cookie {
	if iss == nil || iss.ClientKind != "web" {
		return nil
	}
	secure := s.Cfg.Auth.CookieSecure
	domain := s.Cfg.Auth.CookieDomain
	now := s.Now()
	return []http.Cookie{
		//nolint:gosec // Secure comes from config; validation forces it true outside development
		{Name: httpx.CookieAccess, Value: iss.Access, Path: "/api", Domain: domain, HttpOnly: true, Secure: secure,
			SameSite: http.SameSiteLaxMode, MaxAge: int(iss.AccessExp.Sub(now).Seconds())},
		//nolint:gosec // Secure comes from config; validation forces it true outside development
		{Name: httpx.CookieRefresh, Value: iss.Refresh, Path: "/api/v1/auth", Domain: domain, HttpOnly: true, Secure: secure,
			SameSite: http.SameSiteStrictMode, MaxAge: int(iss.RefreshExp.Sub(now).Seconds())},
		//nolint:gosec // CSRF cookie must be readable by the web client (double-submit); Secure from config
		{Name: httpx.CookieCSRF, Value: s.CSRFToken(iss.SessionID), Path: "/", Domain: domain, Secure: secure,
			SameSite: http.SameSiteLaxMode, MaxAge: int(iss.RefreshExp.Sub(now).Seconds())},
	}
}

//nolint:gosec // expiring cookies; Secure comes from config (forced true outside development)
func (s *Service) clearCookies() []http.Cookie {
	d := s.Cfg.Auth.CookieDomain
	sec := s.Cfg.Auth.CookieSecure
	return []http.Cookie{
		{Name: httpx.CookieAccess, Value: "", Path: "/api", Domain: d, HttpOnly: true, Secure: sec, SameSite: http.SameSiteLaxMode, MaxAge: -1},
		{Name: httpx.CookieRefresh, Value: "", Path: "/api/v1/auth", Domain: d, HttpOnly: true, Secure: sec, SameSite: http.SameSiteStrictMode, MaxAge: -1},
		{Name: httpx.CookieCSRF, Value: "", Path: "/", Domain: d, Secure: sec, SameSite: http.SameSiteLaxMode, MaxAge: -1},
	}
}

func (s *Service) authResponse(ctx context.Context, res *AuthResult, iss *issued) *authOutput {
	return &authOutput{SetCookie: s.cookies(iss), Body: httpx.Envelope[AuthResult]{Data: *res, Meta: httpx.NewMeta(ctx)}}
}

func accepted(ctx context.Context, msg string) *httpx.Response[AcceptedMessage] {
	return httpx.OK(ctx, AcceptedMessage{Status: "accepted", Message: msg})
}

// Routes mounts the auth and session endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Auth"
	authRate := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Auth.Name) }

	httpx.Public(api, httpx.Errs(httpx.Accepted(authRate(httpx.Op("auth-register", http.MethodPost, "/auth/register",
		"Register a new account (always responds 202; a verification email follows)", tag))), http.StatusForbidden),
		func(ctx context.Context, in *struct{ Body registerBody }) (*httpx.Response[AcceptedMessage], error) {
			b := in.Body
			err := s.RegisterUser(ctx, RegisterInput(b))
			if err != nil {
				return nil, err
			}
			return accepted(ctx, "Check your email to verify your account."), nil
		})

	httpx.Public(api, httpx.Errs(authRate(httpx.Op("auth-login", http.MethodPost, "/auth/login", "Sign in with email and password", tag)),
		http.StatusUnauthorized, http.StatusForbidden),
		func(ctx context.Context, in *struct{ Body loginBody }) (*authOutput, error) {
			res, iss, err := s.Login(ctx, LoginInput{Email: in.Body.Email, Password: in.Body.Password, DeviceName: in.Body.DeviceName, CaptchaToken: in.Body.CaptchaToken})
			if err != nil {
				return nil, err
			}
			return s.authResponse(ctx, res, iss), nil
		})

	httpx.Public(api, httpx.Errs(authRate(httpx.Op("auth-mfa-verify", http.MethodPost, "/auth/mfa/verify", "Complete sign-in with a TOTP or recovery code", tag)),
		http.StatusUnauthorized),
		func(ctx context.Context, in *struct{ Body mfaVerifyBody }) (*authOutput, error) {
			res, iss, err := s.VerifyMFALogin(ctx, in.Body.MFAToken, in.Body.Code, in.Body.RecoveryCode, in.Body.DeviceName)
			if err != nil {
				return nil, err
			}
			return s.authResponse(ctx, res, iss), nil
		})

	httpx.Public(api, httpx.Errs(authRate(httpx.Op("auth-refresh", http.MethodPost, "/auth/refresh", "Rotate session tokens (body optional for web cookie sessions)", tag)),
		http.StatusUnauthorized),
		func(ctx context.Context, in *struct {
			Cookie string `cookie:"montra_rt"`
			Body   *refreshBody
		}) (*authOutput, error) {
			token := ""
			if in.Body != nil {
				token = in.Body.RefreshToken
			}
			if token == "" {
				token = in.Cookie
			}
			res, iss, err := s.Refresh(ctx, token)
			if err != nil {
				return nil, err
			}
			return s.authResponse(ctx, res, iss), nil
		})

	httpx.Protected(api, httpx.Op("auth-logout", http.MethodPost, "/auth/logout", "Sign out the current session", tag),
		func(ctx context.Context, _ *struct{}) (*cookieDoneOutput, error) {
			if err := s.Logout(ctx); err != nil {
				return nil, err
			}
			return &cookieDoneOutput{SetCookie: s.clearCookies(), Body: httpx.Envelope[httpx.Empty]{Data: httpx.Empty{OK: true}, Meta: httpx.NewMeta(ctx)}}, nil
		})

	httpx.Protected(api, httpx.Op("auth-logout-all", http.MethodPost, "/auth/logout-all", "Sign out all sessions", tag),
		func(ctx context.Context, _ *struct{}) (*cookieDoneOutput, error) {
			if err := s.LogoutAll(ctx); err != nil {
				return nil, err
			}
			return &cookieDoneOutput{SetCookie: s.clearCookies(), Body: httpx.Envelope[httpx.Empty]{Data: httpx.Empty{OK: true}, Meta: httpx.NewMeta(ctx)}}, nil
		})

	httpx.Public(api, httpx.Accepted(authRate(httpx.Op("auth-password-forgot", http.MethodPost, "/auth/password/forgot", "Request a password reset email", tag))),
		func(ctx context.Context, in *struct{ Body emailBody }) (*httpx.Response[AcceptedMessage], error) {
			if err := s.ForgotPassword(ctx, in.Body.Email, in.Body.CaptchaToken); err != nil {
				return nil, err
			}
			return accepted(ctx, "If an account exists for that email, a reset link is on its way."), nil
		})

	httpx.Public(api, httpx.Errs(authRate(httpx.Op("auth-password-reset", http.MethodPost, "/auth/password/reset", "Set a new password with a reset token", tag)),
		http.StatusGone),
		func(ctx context.Context, in *struct{ Body resetBody }) (*httpx.Response[httpx.Empty], error) {
			if err := s.ResetPassword(ctx, in.Body.Token, in.Body.NewPassword); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	httpx.Public(api, httpx.Errs(authRate(httpx.Op("auth-email-verify", http.MethodPost, "/auth/email/verify", "Verify an email address", tag)),
		http.StatusGone),
		func(ctx context.Context, in *struct{ Body tokenBody }) (*httpx.Response[httpx.Empty], error) {
			if err := s.VerifyEmail(ctx, in.Body.Token); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	httpx.Public(api, httpx.Accepted(authRate(httpx.Op("auth-email-resend", http.MethodPost, "/auth/email/resend", "Resend the verification email", tag))),
		func(ctx context.Context, in *struct{ Body emailBody }) (*httpx.Response[AcceptedMessage], error) {
			if err := s.ResendVerification(ctx, in.Body.Email); err != nil {
				return nil, err
			}
			return accepted(ctx, "If your account needs verification, a new link is on its way."), nil
		})

	httpx.Protected(api, authRate(httpx.Op("auth-reauthenticate", http.MethodPost, "/auth/reauthenticate", "Confirm password (and code) before sensitive actions", tag)),
		func(ctx context.Context, in *struct{ Body reauthBody }) (*httpx.Response[httpx.Empty], error) {
			if err := s.Reauthenticate(ctx, in.Body.Password, in.Body.Code, in.Body.RecoveryCode); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	httpx.Protected(api, httpx.Op("auth-session", http.MethodGet, "/auth/session", "Current session and account summary", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[AuthResult], error) {
			p, err := identity.Require(ctx)
			if err != nil {
				return nil, err
			}
			u, err := s.AccountSummary(ctx)
			if err != nil {
				return nil, err
			}
			sess, err := s.CurrentSession(ctx)
			if err != nil {
				return nil, err
			}
			res := AuthResult{Status: "authenticated", User: u, Session: sess}
			if p.ViaCookie {
				res.CSRFToken = s.CSRFToken(p.SessionID)
			}
			return httpx.OK(ctx, res), nil
		})

	const meTag = "Account security"
	httpx.Protected(api, authRate(httpx.Op("me-password-change", http.MethodPost, "/me/password", "Change password (signs out other sessions)", meTag)),
		func(ctx context.Context, in *struct{ Body changePasswordBody }) (*httpx.Response[httpx.Empty], error) {
			if err := s.ChangePassword(ctx, in.Body.CurrentPassword, in.Body.NewPassword); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	httpx.Protected(api, httpx.Op("me-sessions-list", http.MethodGet, "/me/sessions", "List active sessions and devices", meTag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]SessionDTO], error) {
			list, err := s.ListSessions(ctx)
			if err != nil {
				return nil, err
			}
			if list == nil {
				list = []SessionDTO{}
			}
			return httpx.OK(ctx, list), nil
		})

	httpx.Protected(api, httpx.Op("me-sessions-revoke", http.MethodDelete, "/me/sessions/{sessionId}", "Revoke a session", meTag),
		func(ctx context.Context, in *struct {
			SessionID uuid.UUID `path:"sessionId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.RevokeSession(ctx, in.SessionID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	httpx.Protected(api, httpx.Reauth(httpx.Op("me-mfa-totp-setup", http.MethodPost, "/me/mfa/totp/setup", "Start TOTP enrollment", meTag)),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[MFASetup], error) {
			out, err := s.StartTOTP(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *out), nil
		})

	httpx.Protected(api, authRate(httpx.Op("me-mfa-totp-activate", http.MethodPost, "/me/mfa/totp/activate", "Activate TOTP with the first code", meTag)),
		func(ctx context.Context, in *struct{ Body codeBody }) (*httpx.Response[MFAActivation], error) {
			out, err := s.ActivateTOTP(ctx, in.Body.Code)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *out), nil
		})

	httpx.Protected(api, httpx.Reauth(authRate(httpx.Op("me-mfa-totp-disable", http.MethodPost, "/me/mfa/totp/disable", "Disable TOTP", meTag))),
		func(ctx context.Context, in *struct{ Body disableMFABody }) (*httpx.Response[httpx.Empty], error) {
			if err := s.DisableTOTP(ctx, in.Body.Code, in.Body.RecoveryCode); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	httpx.Protected(api, httpx.Reauth(httpx.Op("me-mfa-recovery-codes", http.MethodPost, "/me/mfa/recovery-codes", "Regenerate recovery codes", meTag)),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[MFAActivation], error) {
			out, err := s.RegenerateRecoveryCodes(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *out), nil
		})
}
