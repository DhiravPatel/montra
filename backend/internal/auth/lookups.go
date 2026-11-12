package auth

import (
	"context"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/platform/database"
)

// These calls use SECURITY DEFINER functions (migration 20261104000002):
// the only way the API role can read identity rows before a user identity
// is established. They are executed without an RLS user context.

type loginLookup struct {
	UserID          uuid.UUID
	Status          string
	EmailVerifiedAt *time.Time
	LockedUntil     *time.Time
	PasswordHash    *string
	MFAEnabled      bool
}

func lookupLogin(ctx context.Context, q database.Querier, emailNormalized string) (*loginLookup, error) {
	var r loginLookup
	err := q.QueryRow(ctx, `select user_id, status, email_verified_at, locked_until, password_hash, mfa_enabled
		from montra.auth_lookup_user($1)`, emailNormalized).
		Scan(&r.UserID, &r.Status, &r.EmailVerifiedAt, &r.LockedUntil, &r.PasswordHash, &r.MFAEnabled)
	if database.IsNoRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, database.MapError(err)
	}
	return &r, nil
}

type accessLookup struct {
	SessionID       uuid.UUID
	UserID          uuid.UUID
	AccessExpiresAt time.Time
	RevokedAt       *time.Time
	MFAVerified     bool
	LastReauthAt    *time.Time
	ClientKind      string
	UserStatus      string
	PlatformRole    string
	EmailVerified   bool
}

func lookupAccess(ctx context.Context, q database.Querier, hash []byte) (*accessLookup, error) {
	var r accessLookup
	err := q.QueryRow(ctx, `select session_id, user_id, access_expires_at, revoked_at, mfa_verified, last_reauth_at,
		client_kind, user_status, platform_role, email_verified from montra.auth_resolve_access($1)`, hash).
		Scan(&r.SessionID, &r.UserID, &r.AccessExpiresAt, &r.RevokedAt, &r.MFAVerified, &r.LastReauthAt,
			&r.ClientKind, &r.UserStatus, &r.PlatformRole, &r.EmailVerified)
	if database.IsNoRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, database.MapError(err)
	}
	return &r, nil
}

type refreshLookup struct {
	SessionID         uuid.UUID
	UserID            uuid.UUID
	RefreshExpiresAt  time.Time
	AbsoluteExpiresAt time.Time
	RevokedAt         *time.Time
	UserStatus        string
	Reused            bool
}

func lookupRefresh(ctx context.Context, q database.Querier, hash []byte) (*refreshLookup, error) {
	rows, err := q.Query(ctx, `select session_id, user_id, refresh_expires_at, absolute_expires_at, revoked_at, user_status, reused
		from montra.auth_resolve_refresh($1)`, hash)
	if err != nil {
		return nil, database.MapError(err)
	}
	defer rows.Close()
	var found *refreshLookup
	for rows.Next() {
		var r refreshLookup
		if err := rows.Scan(&r.SessionID, &r.UserID, &r.RefreshExpiresAt, &r.AbsoluteExpiresAt, &r.RevokedAt, &r.UserStatus, &r.Reused); err != nil {
			return nil, database.MapError(err)
		}
		// Prefer the current-token row over a history row.
		if found == nil || (found.Reused && !r.Reused) {
			rr := r
			found = &rr
		}
	}
	return found, database.MapError(rows.Err())
}

type tokenLookup struct {
	TokenID    uuid.UUID
	UserID     uuid.UUID
	ExpiresAt  time.Time
	ConsumedAt *time.Time
	Attempts   int32
	Payload    []byte
}

func lookupToken(ctx context.Context, q database.Querier, hash []byte, purpose string) (*tokenLookup, error) {
	var r tokenLookup
	err := q.QueryRow(ctx, `select token_id, user_id, expires_at, consumed_at, attempts, payload
		from montra.auth_lookup_token($1, $2)`, hash, purpose).
		Scan(&r.TokenID, &r.UserID, &r.ExpiresAt, &r.ConsumedAt, &r.Attempts, &r.Payload)
	if database.IsNoRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, database.MapError(err)
	}
	return &r, nil
}
