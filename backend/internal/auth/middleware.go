package auth

import (
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/logging"
	"montra/backend/internal/store/db"
)

type tokenSource int

const (
	sourceNone tokenSource = iota
	sourceBearer
	sourceCookie
)

func extractToken(r *http.Request) (string, tokenSource) {
	if h := r.Header.Get("Authorization"); h != "" {
		if after, ok := strings.CutPrefix(h, "Bearer "); ok && after != "" {
			return strings.TrimSpace(after), sourceBearer
		}
		return "", sourceNone
	}
	if c, err := r.Cookie(httpx.CookieAccess); err == nil && c.Value != "" {
		return c.Value, sourceCookie
	}
	return "", sourceNone
}

// Authenticate resolves the session for every request (chi middleware). It
// never rejects: operations decide via RequireAuth whether a principal is
// needed. Invalid or expired tokens simply produce no principal.
func (s *Service) Authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, src := extractToken(r)
		if src == sourceNone || len(token) > 128 {
			next.ServeHTTP(w, r)
			return
		}
		ctx := r.Context()
		a, err := lookupAccess(ctx, s.DB.Pool, crypto.HashToken(token))
		if err != nil {
			slog.ErrorContext(ctx, "session lookup failed", slog.Any("error", err))
			httpx.WriteError(w, r, apperr.Unavailable(apperr.CodeUnavailable, "The service is temporarily unavailable."))
			return
		}
		now := s.Now()
		if a == nil || a.RevokedAt != nil || !a.AccessExpiresAt.After(now) || a.UserStatus != "active" {
			next.ServeHTTP(w, r)
			return
		}
		p := identity.Principal{UserID: a.UserID, SessionID: a.SessionID, ClientKind: a.ClientKind,
			PlatformRole: a.PlatformRole, EmailVerified: a.EmailVerified, MFAVerified: a.MFAVerified,
			LastReauthAt: a.LastReauthAt, ViaCookie: src == sourceCookie}
		ctx = identity.With(ctx, p)
		ctx = logging.WithUserID(ctx, a.UserID.String())
		// Throttled last-seen update (at most every 5 minutes per session).
		_ = s.DB.WithUserTx(ctx, a.UserID, func(tx pgx.Tx) error { return db.New(tx).TouchSession(ctx, a.SessionID) })
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func isSafeMethod(m string) bool {
	return m == http.MethodGet || m == http.MethodHead || m == http.MethodOptions
}

// RequireAuth enforces per-operation authentication metadata (Huma
// middleware): authentication, CSRF for cookie sessions, recent
// re-authentication and platform staff roles.
func (s *Service) RequireAuth(api huma.API) func(huma.Context, func(huma.Context)) {
	return func(ctx huma.Context, next func(huma.Context)) {
		op := ctx.Operation()
		if op == nil || op.Metadata[httpx.MetaAuth] != "required" {
			next(ctx)
			return
		}
		p, ok := identity.From(ctx.Context())
		if !ok {
			writeErr(api, ctx, apperr.Unauthenticated())
			return
		}
		if p.ViaCookie && !isSafeMethod(ctx.Method()) {
			if !crypto.ConstantTimeEqual(ctx.Header("X-CSRF-Token"), s.CSRFToken(p.SessionID)) {
				writeErr(api, ctx, apperr.New(apperr.CodeCSRF, http.StatusForbidden, "The request could not be verified. Reload the page and try again."))
				return
			}
		}
		if op.Metadata[httpx.MetaReauth] == true && !p.RecentlyReauthenticated(s.Cfg.Auth.ReauthWindow, time.Now()) {
			writeErr(api, ctx, apperr.New(apperr.CodeReauthRequired, http.StatusUnauthorized, "Confirm your password to continue."))
			return
		}
		if role, ok := op.Metadata[httpx.MetaRole].(string); ok && role != "" {
			if p.PlatformRole != "admin" && (role != "support" || p.PlatformRole != "support") {
				writeErr(api, ctx, apperr.Forbidden())
				return
			}
		}
		next(ctx)
	}
}

func writeErr(api huma.API, ctx huma.Context, e *apperr.Error) {
	_ = huma.WriteErr(api, ctx, e.Status, e.Message, e)
}
