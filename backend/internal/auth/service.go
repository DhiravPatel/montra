// Package auth implements Montra's identity authority (ADR-002):
// registration, email verification, login with durable throttling, TOTP
// MFA, opaque access/refresh tokens with rotation and reuse detection,
// password reset/change, re-authentication and session management.
package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/currency"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/store/db"
)

// Current legal document versions; clients must display and accept these.
const (
	TermsVersion   = "2026-11-01"
	PrivacyVersion = "2026-11-01"
)

// Job types handled by this package.
const (
	JobSendVerification  = "auth.send_verification"
	JobSendPasswordReset = "auth.send_password_reset" //nolint:gosec // job type name, not a credential
	JobSendAccountExists = "auth.send_account_exists"
	JobSendSecurityEmail = "auth.send_security_email"
)

// UserInitializer seeds per-user data (e.g. starter categories) inside the
// registration transaction.
type UserInitializer func(ctx context.Context, tx pgx.Tx, userID uuid.UUID, locale string) error

// Service is the auth application service.
type Service struct {
	DB          *database.DB
	Cfg         *config.Config
	Keyring     *crypto.Keyring
	Signer      *crypto.Signer
	Metrics     *observability.Metrics
	Initializer []UserInitializer
	Argon       crypto.Argon2Params
	Captcha     CaptchaVerifier
	Now         func() time.Time

	pepper []byte
	ipSalt string
}

// NewService wires the service.
func NewService(dbx *database.DB, cfg *config.Config, kr *crypto.Keyring, metrics *observability.Metrics) *Service {
	s := &Service{DB: dbx, Cfg: cfg, Keyring: kr, Metrics: metrics, Argon: crypto.DefaultArgon2, Now: time.Now}
	s.Signer = crypto.NewSigner(cfg.Security.URLSigningKey)
	s.pepper = crypto.HashWithPepper(cfg.Security.URLSigningKey, "montra/login-throttle")
	s.ipSalt = s.Signer.Sign("montra/ip-salt")
	s.Captcha = NewTurnstile(cfg.Auth.TurnstileSecretKey)
	if cfg.Auth.DevAutoVerifyEmail {
		slog.Warn("development only: email verification is bypassed (AUTH_DEV_AUTO_VERIFY_EMAIL=true); accounts are verified at sign-up and sign-in")
	}
	return s
}

// IPSalt exposes the salt used for hashing client IPs in security events.
func (s *Service) IPSalt() string { return s.ipSalt }

func (s *Service) metric(event string) {
	if s.Metrics != nil {
		s.Metrics.AuthEvents.WithLabelValues(event).Inc()
	}
}

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

// UserDTO is the authenticated user's own account summary.
type UserDTO struct {
	ID                  uuid.UUID  `json:"id"`
	Email               string     `json:"email"`
	EmailVerified       bool       `json:"email_verified"`
	DisplayName         string     `json:"display_name"`
	Username            *string    `json:"username,omitempty"`
	AvatarFileID        *uuid.UUID `json:"avatar_file_id,omitempty"`
	Locale              string     `json:"locale"`
	Timezone            string     `json:"timezone"`
	BaseCurrency        string     `json:"base_currency"`
	MFAEnabled          bool       `json:"mfa_enabled"`
	OnboardingCompleted bool       `json:"onboarding_completed"`
	PlatformRole        string     `json:"platform_role" enum:"user,support,admin"`
	CreatedAt           time.Time  `json:"created_at"`
}

// SessionDTO describes a session.
type SessionDTO struct {
	ID          uuid.UUID `json:"id"`
	ClientKind  string    `json:"client_kind" enum:"web,android,ios,unknown"`
	DeviceName  *string   `json:"device_name,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	LastSeenAt  time.Time `json:"last_seen_at"`
	MFAVerified bool      `json:"mfa_verified"`
	Current     bool      `json:"current"`
}

// AuthResult is returned by login, MFA verification and refresh.
type AuthResult struct {
	Status           string      `json:"status" enum:"authenticated,mfa_required" doc:"mfa_required means call /auth/mfa/verify with mfa_token"`
	User             *UserDTO    `json:"user,omitempty"`
	Session          *SessionDTO `json:"session,omitempty"`
	AccessToken      string      `json:"access_token,omitempty" doc:"Mobile clients only; web receives HttpOnly cookies"`
	RefreshToken     string      `json:"refresh_token,omitempty" doc:"Mobile clients only; store in secure storage"`
	AccessExpiresAt  *time.Time  `json:"access_expires_at,omitempty"`
	RefreshExpiresAt *time.Time  `json:"refresh_expires_at,omitempty"`
	CSRFToken        string      `json:"csrf_token,omitempty" doc:"Web clients: send as X-CSRF-Token on unsafe requests"`
	MFAToken         string      `json:"mfa_token,omitempty"`
}

// issued is a freshly created/rotated session with raw tokens.
type issued struct {
	SessionID  uuid.UUID
	Access     string
	Refresh    string
	AccessExp  time.Time
	RefreshExp time.Time
	ClientKind string
}

// ---------------------------------------------------------------------------
// Registration (enumeration-safe: identical response for new/existing email)
// ---------------------------------------------------------------------------

// RegisterInput is validated registration data.
type RegisterInput struct {
	Email          string
	Password       string
	DisplayName    string
	AcceptTerms    bool
	ConfirmAdult   bool
	TermsVersion   string
	PrivacyVersion string
	Locale         string
	Timezone       string
	Currency       string
	Country        string
	CaptchaToken   string
}

// RegisterUser creates an unverified account and queues a verification email.
// If the email is already registered, a notice is emailed to the owner and
// the caller receives the same response.
func (s *Service) RegisterUser(ctx context.Context, in RegisterInput) error {
	if !s.Cfg.Auth.AllowRegistration {
		return apperr.Forbidden()
	}
	if err := s.Captcha.Verify(ctx, in.CaptchaToken, httpx.Client(ctx).IP); err != nil {
		return err
	}
	display, normalized, err := NormalizeEmail(in.Email)
	if err != nil {
		return err
	}
	if !in.AcceptTerms {
		return apperr.FieldError("body.accept_terms", "You must accept the terms and privacy policy.")
	}
	if in.TermsVersion != TermsVersion || in.PrivacyVersion != PrivacyVersion {
		return apperr.FieldError("body.terms_version", "The terms have been updated. Reload and review them before continuing.")
	}
	if !in.ConfirmAdult {
		return apperr.FieldError("body.confirm_adult", fmt.Sprintf("You must be at least %d years old to use Montra.", s.Cfg.Auth.MinimumAgeYears))
	}
	name := strings.TrimSpace(in.DisplayName)
	if name == "" || len([]rune(name)) > 80 {
		return apperr.FieldError("body.display_name", "Enter a display name of 1 to 80 characters.")
	}
	if err := ValidatePassword(in.Password, normalized, s.Cfg.Auth.PasswordMinLength, "body.password"); err != nil {
		return err
	}
	locale, tz, cur, country, err := s.validateLocaleSettings(in.Locale, in.Timezone, in.Currency, in.Country)
	if err != nil {
		return err
	}

	existing, err := lookupLogin(ctx, s.DB.Pool, normalized)
	if err != nil {
		return err
	}
	if existing != nil {
		// Same response as a new registration; notify the real owner.
		crypto.BurnPasswordCheck(in.Password)
		s.metric("register_existing_email")
		return s.DB.WithUserTx(ctx, existing.UserID, func(tx pgx.Tx) error {
			_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSendAccountExists, UserID: &existing.UserID,
				DedupeKey: fmt.Sprintf("account_exists:%s:%d", existing.UserID, s.Now().Unix()/3600)})
			return err
		})
	}

	hash, err := crypto.HashPassword(in.Password, s.Argon)
	if err != nil {
		return apperr.Internal(err)
	}
	userID := uuid.New()
	clientKind := httpx.Client(ctx).Kind
	err = s.DB.WithUserTx(ctx, userID, func(tx pgx.Tx) error {
		q := db.New(tx)
		if err := q.InsertUser(ctx, db.InsertUserParams{ID: userID, Email: display, EmailNormalized: normalized, ConfirmedAdult: in.ConfirmAdult}); err != nil {
			return err
		}
		if err := q.InsertCredential(ctx, db.InsertCredentialParams{UserID: userID, PasswordHash: hash}); err != nil {
			return err
		}
		if err := q.InsertProfile(ctx, db.InsertProfileParams{UserID: userID, DisplayName: name}); err != nil {
			return err
		}
		if err := q.InsertPreferences(ctx, db.InsertPreferencesParams{UserID: userID, Locale: locale, Timezone: tz, BaseCurrency: cur, Country: country}); err != nil {
			return err
		}
		for _, c := range []struct{ t, v string }{{"terms", in.TermsVersion}, {"privacy_policy", in.PrivacyVersion}} {
			if err := q.InsertConsent(ctx, db.InsertConsentParams{UserID: userID, ConsentType: c.t, Version: c.v, ClientKind: &clientKind}); err != nil {
				return err
			}
		}
		for _, init := range s.Initializer {
			if err := init(ctx, tx, userID, locale); err != nil {
				return err
			}
		}
		if err := audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &userID, Type: "account_registered"}); err != nil {
			return err
		}
		if s.Cfg.Auth.DevAutoVerifyEmail {
			// Development only (config refuses it elsewhere): no email is sent.
			return s.devVerify(ctx, tx, userID)
		}
		_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSendVerification, UserID: &userID, Priority: 10,
			DedupeKey: "verify:" + userID.String() + ":initial"})
		return err
	})
	if database.IsUniqueViolation(err, "users_email_normalized_key") {
		// Raced with a concurrent registration of the same email: same response.
		return nil
	}
	if err != nil {
		return database.MapError(err)
	}
	s.metric("registered")
	return nil
}

func (s *Service) validateLocaleSettings(locale, tz, cur, country string) (string, string, string, *string, error) {
	if locale == "" {
		locale = s.Cfg.Product.DefaultLocale
	}
	if !validLocale(locale) {
		return "", "", "", nil, apperr.FieldError("body.locale", "Unsupported locale.")
	}
	if tz == "" {
		tz = s.Cfg.Product.DefaultTimezone
	}
	if _, err := time.LoadLocation(tz); err != nil || tz == "Local" {
		return "", "", "", nil, apperr.FieldError("body.timezone", "Unknown time zone.")
	}
	if cur == "" {
		cur = s.Cfg.Product.DefaultCurrency
	}
	if !currency.Selectable(cur) {
		return "", "", "", nil, apperr.FieldError("body.currency", "Unsupported currency.")
	}
	var c *string
	if country != "" {
		if len(country) != 2 || strings.ToUpper(country) != country {
			return "", "", "", nil, apperr.FieldError("body.country", "Use an ISO 3166-1 alpha-2 country code.")
		}
		c = &country
	}
	return locale, tz, cur, c, nil
}

func validLocale(l string) bool {
	if len(l) < 2 || len(l) > 10 {
		return false
	}
	lang, region, hasRegion := strings.Cut(l, "-")
	if len(lang) < 2 || len(lang) > 3 || strings.ToLower(lang) != lang {
		return false
	}
	if hasRegion && (len(region) != 2 || strings.ToUpper(region) != region) {
		return false
	}
	return true
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

// LoginInput is a login request.
type LoginInput struct {
	Email        string
	Password     string
	DeviceName   string
	CaptchaToken string
}

var errInvalidCredentials = apperr.New(apperr.CodeUnauthenticated, http.StatusUnauthorized, "Invalid email or password.")

// Login authenticates credentials and returns a session (or MFA challenge).
func (s *Service) Login(ctx context.Context, in LoginInput) (*AuthResult, *issued, error) {
	if err := s.Captcha.Verify(ctx, in.CaptchaToken, httpx.Client(ctx).IP); err != nil {
		return nil, nil, err
	}
	_, normalized, err := NormalizeEmail(in.Email)
	if err != nil {
		crypto.BurnPasswordCheck(in.Password)
		return nil, nil, errInvalidCredentials
	}
	emailHash := crypto.HashWithPepper(s.pepper, normalized)
	ipHash := httpx.HashIP(httpx.Client(ctx).IP, s.ipSalt)
	if err := s.checkThrottle(ctx, emailHash, ipHash); err != nil {
		return nil, nil, err
	}
	u, err := lookupLogin(ctx, s.DB.Pool, normalized)
	if err != nil {
		return nil, nil, err
	}
	valid := false
	if u != nil && u.PasswordHash != nil {
		ok, rehash, verr := crypto.VerifyPassword(in.Password, *u.PasswordHash, s.Argon)
		valid = verr == nil && ok
		if valid && rehash {
			defer s.rehashPassword(context.WithoutCancel(ctx), u.UserID, in.Password)
		}
	} else {
		crypto.BurnPasswordCheck(in.Password)
	}
	if !valid || u == nil || u.Status == "deleted" || u.Status == "pending_deletion" {
		s.recordAttempt(ctx, emailHash, ipHash, false)
		s.metric("login_failed")
		var uid *uuid.UUID
		if u != nil {
			uid = &u.UserID
		}
		_ = s.DB.WithAnonTx(ctx, func(tx pgx.Tx) error {
			return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: uid, Type: "login_failed", Severity: "warning"})
		})
		return nil, nil, errInvalidCredentials
	}
	if u.Status == "locked" || (u.LockedUntil != nil && u.LockedUntil.After(s.Now())) {
		return nil, nil, apperr.New(apperr.CodeAccountLocked, http.StatusForbidden,
			"This account is locked. Contact support to restore access.")
	}
	if s.Cfg.Auth.DevAutoVerifyEmail && u.EmailVerifiedAt == nil {
		// Development only: accounts created before the bypass was enabled.
		uid := u.UserID
		if err := s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error { return s.devVerify(ctx, tx, uid) }); err != nil {
			return nil, nil, database.MapError(err)
		}
		now := s.Now()
		u.EmailVerifiedAt = &now
	}
	if s.Cfg.Auth.RequireEmailVerified && u.EmailVerifiedAt == nil {
		s.recordAttempt(ctx, emailHash, ipHash, true)
		_ = s.queueVerification(ctx, u.UserID, false)
		return nil, nil, apperr.New(apperr.CodeEmailNotVerified, http.StatusForbidden,
			"Verify your email address to sign in. We've sent you a new verification link.")
	}
	s.recordAttempt(ctx, emailHash, ipHash, true)

	if u.MFAEnabled {
		token := crypto.MustRandomToken(32)
		payload, _ := json.Marshal(map[string]string{"device_name": truncate(in.DeviceName, 120)})
		err := s.DB.WithUserTx(ctx, u.UserID, func(tx pgx.Tx) error {
			return db.New(tx).InsertAuthToken(ctx, db.InsertAuthTokenParams{UserID: u.UserID, Purpose: "mfa_challenge",
				TokenHash: crypto.HashToken(token), Payload: payload, ExpiresAt: s.Now().Add(5 * time.Minute)})
		})
		if err != nil {
			return nil, nil, database.MapError(err)
		}
		s.metric("mfa_challenge_issued")
		return &AuthResult{Status: "mfa_required", MFAToken: token}, nil, nil
	}
	return s.completeLogin(ctx, u.UserID, in.DeviceName, false)
}

func (s *Service) completeLogin(ctx context.Context, userID uuid.UUID, deviceName string, mfaVerified bool) (*AuthResult, *issued, error) {
	var res *AuthResult
	var iss *issued
	err := s.DB.WithUserTx(ctx, userID, func(tx pgx.Tx) error {
		q := db.New(tx)
		var err error
		iss, err = s.createSession(ctx, tx, userID, deviceName, mfaVerified)
		if err != nil {
			return err
		}
		if err := q.TouchLogin(ctx, userID); err != nil {
			return err
		}
		if err := audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &userID, Type: "login_succeeded", SessionID: &iss.SessionID,
			Details: map[string]any{"mfa": mfaVerified}}); err != nil {
			return err
		}
		res, err = s.buildResult(ctx, q, userID, iss)
		return err
	})
	if err != nil {
		return nil, nil, database.MapError(err)
	}
	s.metric("login_succeeded")
	return res, iss, nil
}

const maxSessionsPerUser = 20

func (s *Service) createSession(ctx context.Context, tx pgx.Tx, userID uuid.UUID, deviceName string, mfaVerified bool) (*issued, error) {
	now := s.Now()
	ci := httpx.Client(ctx)
	iss := &issued{
		SessionID:  uuid.New(),
		Access:     crypto.MustRandomToken(32),
		Refresh:    crypto.MustRandomToken(32),
		AccessExp:  now.Add(s.Cfg.Auth.AccessTokenTTL),
		RefreshExp: now.Add(s.Cfg.Auth.RefreshTokenTTL),
		ClientKind: ci.Kind,
	}
	absolute := now.Add(s.Cfg.Auth.RefreshAbsoluteTTL)
	if iss.RefreshExp.After(absolute) {
		iss.RefreshExp = absolute
	}
	dn := strings.TrimSpace(deviceName)
	if dn == "" {
		dn = describeUA(ci.UA)
	}
	dnp := ptrOrNil(truncate(dn, 120))
	ua := ptrOrNil(ci.UA)
	ip := ptrOrNil(httpx.HashIP(ci.IP, s.ipSalt))
	q := db.New(tx)
	if err := q.InsertSession(ctx, db.InsertSessionParams{
		ID: iss.SessionID, UserID: userID,
		AccessTokenHash: crypto.HashToken(iss.Access), AccessExpiresAt: iss.AccessExp,
		RefreshTokenHash: crypto.HashToken(iss.Refresh), RefreshExpiresAt: iss.RefreshExp, AbsoluteExpiresAt: absolute,
		ClientKind: ci.Kind, DeviceName: dnp, UserAgent: ua, IpHash: ip, MfaVerified: mfaVerified,
	}); err != nil {
		return nil, err
	}
	// Bound concurrent sessions: revoke the oldest beyond the limit.
	if _, err := tx.Exec(ctx, `update user_sessions set revoked_at = now(), revoked_reason = 'expired'
		where id in (select id from user_sessions where user_id = $1 and revoked_at is null
		             order by last_seen_at desc offset $2)`, userID, maxSessionsPerUser); err != nil {
		return nil, err
	}
	return iss, nil
}

func (s *Service) buildResult(ctx context.Context, q *db.Queries, userID uuid.UUID, iss *issued) (*AuthResult, error) {
	u, err := s.accountSummary(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	res := &AuthResult{Status: "authenticated", User: u, Session: &SessionDTO{ID: iss.SessionID, ClientKind: iss.ClientKind,
		CreatedAt: s.Now(), LastSeenAt: s.Now(), Current: true}}
	aexp, rexp := iss.AccessExp, iss.RefreshExp
	res.AccessExpiresAt = &aexp
	res.RefreshExpiresAt = &rexp
	if iss.ClientKind == "web" {
		res.CSRFToken = s.CSRFToken(iss.SessionID)
	} else {
		res.AccessToken = iss.Access
		res.RefreshToken = iss.Refresh
	}
	return res, nil
}

func (s *Service) accountSummary(ctx context.Context, q *db.Queries, userID uuid.UUID) (*UserDTO, error) {
	r, err := q.GetAccountSummary(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &UserDTO{ID: r.ID, Email: r.Email, EmailVerified: r.EmailVerifiedAt != nil, DisplayName: r.DisplayName,
		Username: r.Username, AvatarFileID: r.AvatarFileID, Locale: r.Locale, Timezone: r.Timezone,
		BaseCurrency: r.BaseCurrency, MFAEnabled: r.MfaEnabled, OnboardingCompleted: r.OnboardingCompletedAt != nil,
		PlatformRole: r.PlatformRole, CreatedAt: r.CreatedAt}, nil
}

// AccountSummary returns the current user's summary.
func (s *Service) AccountSummary(ctx context.Context) (*UserDTO, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	var u *UserDTO
	err = s.DB.WithUserReadTx(ctx, p.UserID, func(tx pgx.Tx) error {
		var err error
		u, err = s.accountSummary(ctx, db.New(tx), p.UserID)
		return err
	})
	return u, database.MapError(err)
}

// CSRFToken derives the CSRF token bound to a session.
func (s *Service) CSRFToken(sessionID uuid.UUID) string {
	return s.Signer.Sign("csrf", sessionID.String())
}

func (s *Service) checkThrottle(ctx context.Context, emailHash []byte, ipHash string) error {
	window := s.Cfg.Auth.LoginFailureWindow.Seconds()
	q := db.New(s.DB.Pool)
	byEmail, err := q.CountRecentFailuresByEmail(ctx, db.CountRecentFailuresByEmailParams{EmailHash: emailHash, WindowSeconds: window})
	if err != nil {
		return database.MapError(err)
	}
	if byEmail >= int64(s.Cfg.Auth.LoginMaxFailures) {
		s.metric("login_throttled_email")
		return apperr.New(apperr.CodeLoginThrottled, http.StatusTooManyRequests,
			"Too many failed sign-in attempts. Try again later or reset your password.").
			WithRetryAfter(s.throttleRemaining(ctx, `email_hash = $1`, emailHash))
	}
	if ipHash != "" {
		byIP, err := q.CountRecentFailuresByIP(ctx, db.CountRecentFailuresByIPParams{IpHash: &ipHash, WindowSeconds: window})
		if err != nil {
			return database.MapError(err)
		}
		if byIP >= int64(s.Cfg.Auth.LoginMaxFailures*5) {
			s.metric("login_throttled_ip")
			return apperr.New(apperr.CodeLoginThrottled, http.StatusTooManyRequests,
				"Too many failed sign-in attempts from this network. Try again later.").
				WithRetryAfter(s.throttleRemaining(ctx, `ip_hash = $1`, ipHash))
		}
	}
	return nil
}

// throttleRemaining is the time until enough failures leave the window for
// sign-in to be allowed again: with n failures and a limit of max, that is
// when the (n-max+1)-th oldest failure expires. Falls back to the window.
func (s *Service) throttleRemaining(ctx context.Context, where string, key any) time.Duration {
	window := s.Cfg.Auth.LoginFailureWindow
	limit := s.Cfg.Auth.LoginMaxFailures
	if where != `email_hash = $1` {
		limit *= 5
	}
	var at time.Time
	err := s.DB.Pool.QueryRow(ctx, `select attempted_at from login_attempts where `+where+` and not succeeded
		and attempted_at > now() - make_interval(secs => $2) order by attempted_at desc offset $3 limit 1`,
		key, window.Seconds(), max(limit-1, 0)).Scan(&at)
	if err != nil {
		return window
	}
	if d := time.Until(at.Add(window)); d > 0 {
		return d
	}
	return time.Second
}

func (s *Service) recordAttempt(ctx context.Context, emailHash []byte, ipHash string, ok bool) {
	q := db.New(s.DB.Pool)
	if err := q.InsertLoginAttempt(ctx, db.InsertLoginAttemptParams{EmailHash: emailHash, IpHash: ptrOrNil(ipHash), Succeeded: ok}); err != nil {
		slog.ErrorContext(ctx, "record login attempt failed", slog.Any("error", err))
	}
	if ok {
		_ = q.ClearLoginFailures(ctx, emailHash)
	}
}

func (s *Service) rehashPassword(ctx context.Context, userID uuid.UUID, pw string) {
	h, err := crypto.HashPassword(pw, s.Argon)
	if err != nil {
		return
	}
	_ = s.DB.WithUserTx(ctx, userID, func(tx pgx.Tx) error {
		return db.New(tx).UpdatePassword(ctx, db.UpdatePasswordParams{PasswordHash: h, UserID: userID})
	})
}

// ---------------------------------------------------------------------------
// MFA login verification
// ---------------------------------------------------------------------------

// VerifyMFALogin completes a login that required TOTP or a recovery code.
func (s *Service) VerifyMFALogin(ctx context.Context, mfaToken, code, recoveryCode, deviceName string) (*AuthResult, *issued, error) {
	t, err := lookupToken(ctx, s.DB.Pool, crypto.HashToken(mfaToken), "mfa_challenge")
	if err != nil {
		return nil, nil, err
	}
	if t == nil || t.ConsumedAt != nil || t.ExpiresAt.Before(s.Now()) || t.Attempts >= 5 {
		return nil, nil, apperr.New(apperr.CodeMFAChallengeExpired, http.StatusUnauthorized, "This sign-in attempt has expired. Sign in again.")
	}
	var payload struct {
		DeviceName string `json:"device_name"`
	}
	_ = json.Unmarshal(t.Payload, &payload)
	if deviceName == "" {
		deviceName = payload.DeviceName
	}
	verified := false
	err = s.DB.WithUserTx(ctx, t.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		if err := q.IncrementTokenAttempts(ctx, t.TokenID); err != nil {
			return err
		}
		ok, err := s.checkSecondFactor(ctx, q, t.UserID, code, recoveryCode)
		if err != nil {
			return err
		}
		if !ok {
			return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &t.UserID, Type: "mfa_failed", Severity: "warning"})
		}
		n, err := q.ConsumeAuthToken(ctx, t.TokenID)
		if err != nil {
			return err
		}
		verified = n == 1
		return nil
	})
	if err != nil {
		return nil, nil, database.MapError(err)
	}
	if !verified {
		s.metric("mfa_failed")
		return nil, nil, apperr.New(apperr.CodeMFACodeInvalid, http.StatusUnauthorized, "The verification code is incorrect.")
	}
	return s.completeLogin(ctx, t.UserID, deviceName, true)
}

// checkSecondFactor validates a TOTP code (with replay protection) or a
// single-use recovery code.
func (s *Service) checkSecondFactor(ctx context.Context, q *db.Queries, userID uuid.UUID, code, recovery string) (bool, error) {
	if recovery = normalizeRecovery(recovery); recovery != "" {
		n, err := q.UseRecoveryCode(ctx, db.UseRecoveryCodeParams{UserID: userID, CodeHash: crypto.HashWithPepper(s.pepper, recovery)})
		if err != nil {
			return false, err
		}
		return n == 1, nil
	}
	f, err := q.GetActiveMFAFactor(ctx, userID)
	if database.IsNoRows(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	secret, err := s.Keyring.Decrypt(f.SecretCiphertext, f.KeyID, []byte(f.ID.String()))
	if err != nil {
		return false, apperr.Internal(err)
	}
	step, ok := crypto.VerifyTOTP(secret, code, s.Now())
	if !ok {
		return false, nil
	}
	st := int64(step)
	n, err := q.SetMFALastStep(ctx, db.SetMFALastStepParams{Step: &st, ID: f.ID})
	if err != nil {
		return false, err
	}
	return n == 1, nil // 0 rows → code already used (replay)
}

func normalizeRecovery(s string) string {
	return strings.ToLower(strings.ReplaceAll(strings.TrimSpace(s), "-", ""))
}

// ---------------------------------------------------------------------------
// Refresh rotation with reuse detection
// ---------------------------------------------------------------------------

// refreshGrace tolerates concurrent refreshes (two tabs) without treating
// them as token theft.
const refreshGrace = 30 * time.Second

var errSessionExpired = apperr.New(apperr.CodeUnauthenticated, http.StatusUnauthorized, "Your session has expired. Sign in again.")

// Refresh rotates the session tokens.
func (s *Service) Refresh(ctx context.Context, refreshToken string) (*AuthResult, *issued, error) {
	if refreshToken == "" {
		return nil, nil, errSessionExpired
	}
	hash := crypto.HashToken(refreshToken)
	r, err := lookupRefresh(ctx, s.DB.Pool, hash)
	if err != nil {
		return nil, nil, err
	}
	if r == nil {
		return nil, nil, errSessionExpired
	}
	now := s.Now()
	if r.Reused {
		var rotatedAt time.Time
		err := s.DB.WithUserTx(ctx, r.UserID, func(tx pgx.Tx) error {
			var err error
			rotatedAt, err = db.New(tx).GetRefreshRotatedAt(ctx, hash)
			if err != nil {
				return err
			}
			if now.Sub(rotatedAt) <= refreshGrace {
				return nil
			}
			reason := "refresh_reuse"
			if _, err := db.New(tx).RevokeSession(ctx, db.RevokeSessionParams{Reason: &reason, ID: r.SessionID, UserID: r.UserID}); err != nil {
				return err
			}
			return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &r.UserID, Type: "refresh_token_reuse_detected",
				Severity: "critical", SessionID: &r.SessionID})
		})
		if err != nil {
			return nil, nil, database.MapError(err)
		}
		if now.Sub(rotatedAt) > refreshGrace {
			s.metric("refresh_reuse_detected")
		}
		return nil, nil, errSessionExpired
	}
	if r.RevokedAt != nil || !r.RefreshExpiresAt.After(now) || !r.AbsoluteExpiresAt.After(now) || r.UserStatus != "active" {
		return nil, nil, errSessionExpired
	}
	iss := &issued{
		SessionID: r.SessionID, Access: crypto.MustRandomToken(32), Refresh: crypto.MustRandomToken(32),
		AccessExp: now.Add(s.Cfg.Auth.AccessTokenTTL), RefreshExp: now.Add(s.Cfg.Auth.RefreshTokenTTL),
		ClientKind: httpx.Client(ctx).Kind,
	}
	if iss.RefreshExp.After(r.AbsoluteExpiresAt) {
		iss.RefreshExp = r.AbsoluteExpiresAt
	}
	var res *AuthResult
	err = s.DB.WithUserTx(ctx, r.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		n, err := q.RotateSession(ctx, db.RotateSessionParams{
			AccessTokenHash: crypto.HashToken(iss.Access), AccessExpiresAt: iss.AccessExp,
			RefreshTokenHash: crypto.HashToken(iss.Refresh), RefreshExpiresAt: iss.RefreshExp,
			ID: r.SessionID, OldRefreshHash: hash,
		})
		if err != nil {
			return err
		}
		if n == 0 {
			return errSessionExpired // lost a concurrent rotation; client retries with the new cookie
		}
		if err := q.InsertRefreshHistory(ctx, db.InsertRefreshHistoryParams{TokenHash: hash, SessionID: r.SessionID, UserID: r.UserID}); err != nil {
			return err
		}
		res, err = s.buildResult(ctx, q, r.UserID, iss)
		return err
	})
	if err != nil {
		return nil, nil, database.MapError(err)
	}
	s.metric("refreshed")
	return res, iss, nil
}

// ---------------------------------------------------------------------------
// Logout and sessions
// ---------------------------------------------------------------------------

// Logout revokes the current session.
func (s *Service) Logout(ctx context.Context) error {
	p, err := identity.Require(ctx)
	if err != nil {
		return err
	}
	return s.revoke(ctx, p, p.SessionID, "logout")
}

// LogoutAll revokes every session of the current user.
func (s *Service) LogoutAll(ctx context.Context) error {
	p, err := identity.Require(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		reason := "logout_all"
		if _, err := db.New(tx).RevokeAllSessions(ctx, db.RevokeAllSessionsParams{Reason: &reason, UserID: p.UserID}); err != nil {
			return err
		}
		return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &p.UserID, Type: "logout_all", SessionID: &p.SessionID})
	}))
}

// RevokeSession revokes one of the current user's sessions.
func (s *Service) RevokeSession(ctx context.Context, sessionID uuid.UUID) error {
	p, err := identity.Require(ctx)
	if err != nil {
		return err
	}
	return s.revoke(ctx, p, sessionID, "user_revoked")
}

func (s *Service) revoke(ctx context.Context, p identity.Principal, sessionID uuid.UUID, reason string) error {
	var n int64
	err := s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		var err error
		n, err = db.New(tx).RevokeSession(ctx, db.RevokeSessionParams{Reason: &reason, ID: sessionID, UserID: p.UserID})
		if err != nil || n == 0 {
			return err
		}
		return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &p.UserID, Type: "session_revoked", SessionID: &sessionID,
			Details: map[string]any{"reason": reason}})
	})
	if err != nil {
		return database.MapError(err)
	}
	if n == 0 && reason == "user_revoked" {
		return apperr.NotFound("session")
	}
	return nil
}

// ListSessions lists active sessions.
func (s *Service) ListSessions(ctx context.Context) ([]SessionDTO, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	var out []SessionDTO
	err = s.DB.WithUserReadTx(ctx, p.UserID, func(tx pgx.Tx) error {
		rows, err := db.New(tx).ListActiveSessions(ctx, p.UserID)
		if err != nil {
			return err
		}
		for _, r := range rows {
			out = append(out, SessionDTO{ID: r.ID, ClientKind: r.ClientKind, DeviceName: r.DeviceName, CreatedAt: r.CreatedAt,
				LastSeenAt: r.LastSeenAt, MFAVerified: r.MfaVerified, Current: r.ID == p.SessionID})
		}
		return nil
	})
	return out, database.MapError(err)
}

// CurrentSession returns the caller's session as stored.
func (s *Service) CurrentSession(ctx context.Context) (*SessionDTO, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	out := SessionDTO{ID: p.SessionID, Current: true}
	err = s.DB.WithUserReadTx(ctx, p.UserID, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select client_kind, device_name, created_at, coalesce(last_seen_at, created_at), mfa_verified
			from user_sessions where id = $1 and user_id = $2`, p.SessionID, p.UserID).
			Scan(&out.ClientKind, &out.DeviceName, &out.CreatedAt, &out.LastSeenAt, &out.MFAVerified)
	})
	if database.IsNoRows(err) {
		return nil, apperr.Unauthenticated()
	}
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// ---------------------------------------------------------------------------
// Email verification and password reset
// ---------------------------------------------------------------------------

// VerifyEmail consumes a verification token.
func (s *Service) VerifyEmail(ctx context.Context, token string) error {
	t, err := lookupToken(ctx, s.DB.Pool, crypto.HashToken(token), "email_verification")
	if err != nil {
		return err
	}
	if t == nil || t.ConsumedAt != nil || t.ExpiresAt.Before(s.Now()) {
		return apperr.New(apperr.CodeGone, http.StatusGone, "This verification link is invalid or has expired. Request a new one.")
	}
	err = s.DB.WithUserTx(ctx, t.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		n, err := q.ConsumeAuthToken(ctx, t.TokenID)
		if err != nil {
			return err
		}
		if n == 0 {
			return apperr.New(apperr.CodeGone, http.StatusGone, "This verification link is invalid or has expired. Request a new one.")
		}
		if err := q.MarkEmailVerified(ctx, t.UserID); err != nil {
			return err
		}
		return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &t.UserID, Type: "email_verified"})
	})
	if err != nil {
		return database.MapError(err)
	}
	s.metric("email_verified")
	return nil
}

// ResendVerification queues a new verification email (always succeeds).
func (s *Service) ResendVerification(ctx context.Context, email string) error {
	_, normalized, err := NormalizeEmail(email)
	if err != nil {
		return nil // generic response
	}
	u, err := lookupLogin(ctx, s.DB.Pool, normalized)
	if err != nil || u == nil || u.EmailVerifiedAt != nil || u.Status != "active" {
		return err
	}
	return s.queueVerification(ctx, u.UserID, true)
}

func (s *Service) queueVerification(ctx context.Context, userID uuid.UUID, explicit bool) error {
	bucket := s.Now().Unix() / 300 // at most one email per 5 minutes
	return database.MapError(s.DB.WithUserTx(ctx, userID, func(tx pgx.Tx) error {
		_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSendVerification, UserID: &userID, Priority: 10,
			DedupeKey: fmt.Sprintf("verify:%s:%d", userID, bucket)})
		return err
	}))
}

// ForgotPassword queues a reset email when the account exists (always
// returns success to avoid account enumeration).
func (s *Service) ForgotPassword(ctx context.Context, email, captcha string) error {
	if err := s.Captcha.Verify(ctx, captcha, httpx.Client(ctx).IP); err != nil {
		return err
	}
	_, normalized, err := NormalizeEmail(email)
	if err != nil {
		return nil
	}
	u, err := lookupLogin(ctx, s.DB.Pool, normalized)
	if err != nil || u == nil || u.Status == "deleted" || u.Status == "pending_deletion" {
		return err
	}
	bucket := s.Now().Unix() / 120
	return database.MapError(s.DB.WithUserTx(ctx, u.UserID, func(tx pgx.Tx) error {
		_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSendPasswordReset, UserID: &u.UserID, Priority: 10,
			DedupeKey: fmt.Sprintf("reset:%s:%d", u.UserID, bucket)})
		if err != nil {
			return err
		}
		return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &u.UserID, Type: "password_reset_requested"})
	}))
}

// ResetPassword sets a new password using a reset token and revokes all
// sessions.
func (s *Service) ResetPassword(ctx context.Context, token, newPassword string) error {
	t, err := lookupToken(ctx, s.DB.Pool, crypto.HashToken(token), "password_reset")
	if err != nil {
		return err
	}
	if t == nil || t.ConsumedAt != nil || t.ExpiresAt.Before(s.Now()) {
		return apperr.New(apperr.CodeGone, http.StatusGone, "This reset link is invalid or has expired. Request a new one.")
	}
	var email string
	err = s.DB.WithUserReadTx(ctx, t.UserID, func(tx pgx.Tx) error {
		u, err := db.New(tx).GetUser(ctx, t.UserID)
		email = u.EmailNormalized
		return err
	})
	if err != nil {
		return database.MapError(err)
	}
	if err := ValidatePassword(newPassword, email, s.Cfg.Auth.PasswordMinLength, "body.new_password"); err != nil {
		return err
	}
	hash, err := crypto.HashPassword(newPassword, s.Argon)
	if err != nil {
		return apperr.Internal(err)
	}
	err = s.DB.WithUserTx(ctx, t.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		n, err := q.ConsumeAuthToken(ctx, t.TokenID)
		if err != nil {
			return err
		}
		if n == 0 {
			return apperr.New(apperr.CodeGone, http.StatusGone, "This reset link is invalid or has expired. Request a new one.")
		}
		if err := q.UpdatePassword(ctx, db.UpdatePasswordParams{PasswordHash: hash, UserID: t.UserID}); err != nil {
			return err
		}
		if err := q.InvalidateTokens(ctx, db.InvalidateTokensParams{UserID: t.UserID, Purpose: "password_reset"}); err != nil {
			return err
		}
		if err := q.MarkEmailVerified(ctx, t.UserID); err != nil { // proved inbox control
			return err
		}
		reason := "password_changed"
		if _, err := q.RevokeAllSessions(ctx, db.RevokeAllSessionsParams{Reason: &reason, UserID: t.UserID}); err != nil {
			return err
		}
		if err := audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &t.UserID, Type: "password_reset_completed", Severity: "warning"}); err != nil {
			return err
		}
		_, _, err = jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSendSecurityEmail, UserID: &t.UserID,
			Payload: map[string]string{"template": "password_changed"}})
		return err
	})
	if err != nil {
		return database.MapError(err)
	}
	s.metric("password_reset")
	return nil
}

// ---------------------------------------------------------------------------
// Re-authentication and password change
// ---------------------------------------------------------------------------

// Reauthenticate confirms the password (and TOTP when enabled) for
// sensitive operations.
func (s *Service) Reauthenticate(ctx context.Context, password, code, recoveryCode string) error {
	p, err := identity.Require(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		hash, err := q.GetCredential(ctx, p.UserID)
		if err != nil {
			return err
		}
		ok, _, _ := crypto.VerifyPassword(password, hash, s.Argon)
		if !ok {
			_ = audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &p.UserID, Type: "reauth_failed", Severity: "warning"})
			return apperr.New(apperr.CodeReauthRequired, http.StatusUnauthorized, "The password is incorrect.")
		}
		if _, err := q.GetActiveMFAFactor(ctx, p.UserID); err == nil {
			if strings.TrimSpace(code) == "" && strings.TrimSpace(recoveryCode) == "" {
				return apperr.New(apperr.CodeMFARequired, http.StatusUnauthorized, "Enter a verification code or a recovery code.")
			}
			ok, err := s.checkSecondFactor(ctx, q, p.UserID, code, recoveryCode)
			if err != nil {
				return err
			}
			if !ok {
				return apperr.New(apperr.CodeMFACodeInvalid, http.StatusUnauthorized, "The verification or recovery code is incorrect or already used.")
			}
			// The session has now proved the second factor.
			if _, err := tx.Exec(ctx, `update user_sessions set mfa_verified = true where id = $1`, p.SessionID); err != nil {
				return err
			}
		} else if !database.IsNoRows(err) {
			return err
		}
		if err := q.SetSessionReauth(ctx, p.SessionID); err != nil {
			return err
		}
		return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &p.UserID, Type: "reauthenticated", SessionID: &p.SessionID})
	}))
}

// ChangePassword updates the password and revokes all other sessions.
func (s *Service) ChangePassword(ctx context.Context, current, next string) error {
	p, err := identity.Require(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		hash, err := q.GetCredential(ctx, p.UserID)
		if err != nil {
			return err
		}
		if ok, _, _ := crypto.VerifyPassword(current, hash, s.Argon); !ok {
			return apperr.FieldError("body.current_password", "The current password is incorrect.")
		}
		u, err := q.GetUser(ctx, p.UserID)
		if err != nil {
			return err
		}
		if err := ValidatePassword(next, u.EmailNormalized, s.Cfg.Auth.PasswordMinLength, "body.new_password"); err != nil {
			return err
		}
		newHash, err := crypto.HashPassword(next, s.Argon)
		if err != nil {
			return apperr.Internal(err)
		}
		if err := q.UpdatePassword(ctx, db.UpdatePasswordParams{PasswordHash: newHash, UserID: p.UserID}); err != nil {
			return err
		}
		reason := "password_changed"
		if _, err := q.RevokeAllSessions(ctx, db.RevokeAllSessionsParams{Reason: &reason, UserID: p.UserID, ExceptID: &p.SessionID}); err != nil {
			return err
		}
		if err := audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &p.UserID, Type: "password_changed", Severity: "warning", SessionID: &p.SessionID}); err != nil {
			return err
		}
		_, _, err = jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSendSecurityEmail, UserID: &p.UserID, Payload: map[string]string{"template": "password_changed"}})
		return err
	}))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func ptrOrNil(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func truncate(s string, n int) string {
	r := []rune(s)
	if len(r) > n {
		return string(r[:n])
	}
	return s
}

// describeUA derives a coarse device label from a user agent (no
// fingerprinting detail is stored).
func describeUA(ua string) string {
	l := strings.ToLower(ua)
	browser := "Browser"
	switch {
	case strings.Contains(l, "edg/"):
		browser = "Edge"
	case strings.Contains(l, "chrome/"):
		browser = "Chrome"
	case strings.Contains(l, "firefox/"):
		browser = "Firefox"
	case strings.Contains(l, "safari/"):
		browser = "Safari"
	case strings.Contains(l, "dart/") || strings.Contains(l, "montra-mobile"):
		browser = "Montra app"
	}
	osName := ""
	switch {
	case strings.Contains(l, "android"):
		osName = "Android"
	case strings.Contains(l, "iphone") || strings.Contains(l, "ipad") || strings.Contains(l, "ios"):
		osName = "iOS"
	case strings.Contains(l, "mac os"):
		osName = "macOS"
	case strings.Contains(l, "windows"):
		osName = "Windows"
	case strings.Contains(l, "linux"):
		osName = "Linux"
	}
	if osName == "" {
		return browser
	}
	return browser + " on " + osName
}

// devVerify marks an email verified without a token (development bypass,
// AUTH_DEV_AUTO_VERIFY_EMAIL). The security event records how.
func (s *Service) devVerify(ctx context.Context, tx pgx.Tx, uid uuid.UUID) error {
	if err := db.New(tx).MarkEmailVerified(ctx, uid); err != nil {
		return err
	}
	s.metric("email_verified")
	return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &uid, Type: "email_verified",
		Details: map[string]any{"method": "development_bypass"}})
}
