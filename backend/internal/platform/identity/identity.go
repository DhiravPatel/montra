// Package identity carries the authenticated principal through the request
// context. Services must derive the acting user from here, never from
// client-supplied identifiers (spec §3).
package identity

import (
	"context"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/platform/apperr"
)

type ctxKey struct{}

// Principal is the authenticated caller.
type Principal struct {
	UserID        uuid.UUID
	SessionID     uuid.UUID
	ClientKind    string
	PlatformRole  string // user | support | admin
	EmailVerified bool
	MFAVerified   bool
	LastReauthAt  *time.Time
	ViaCookie     bool
}

// With stores the principal.
func With(ctx context.Context, p Principal) context.Context {
	return context.WithValue(ctx, ctxKey{}, p)
}

// From returns the principal if present.
func From(ctx context.Context) (Principal, bool) {
	p, ok := ctx.Value(ctxKey{}).(Principal)
	return p, ok
}

// Require returns the principal or an UNAUTHENTICATED error.
func Require(ctx context.Context) (Principal, error) {
	p, ok := From(ctx)
	if !ok || p.UserID == uuid.Nil {
		return Principal{}, apperr.Unauthenticated()
	}
	return p, nil
}

// MustUserID returns the authenticated user ID (handlers run behind
// RequireAuth, so absence is a programming error surfaced as 401).
func UserID(ctx context.Context) (uuid.UUID, error) {
	p, err := Require(ctx)
	if err != nil {
		return uuid.Nil, err
	}
	return p.UserID, nil
}

// IsStaff reports platform staff roles.
func (p Principal) IsStaff() bool { return p.PlatformRole == "admin" || p.PlatformRole == "support" }

// RecentlyReauthenticated reports re-authentication within window.
func (p Principal) RecentlyReauthenticated(window time.Duration, now time.Time) bool {
	return p.LastReauthAt != nil && now.Sub(*p.LastReauthAt) <= window
}
