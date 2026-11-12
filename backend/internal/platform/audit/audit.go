// Package audit records append-only audit and security events. Event
// payloads describe what changed; they never include secrets.
package audit

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"

	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/logging"
)

// Event is a generic audit event.
type Event struct {
	UserID      *uuid.UUID // subject/owner of the affected data
	GroupID     *uuid.UUID
	ActorUserID *uuid.UUID
	ActorKind   string // user | system | support | admin | moderator
	EntityType  string
	EntityID    *uuid.UUID
	Action      string
	Changes     any
}

// Record inserts an audit event inside the caller's transaction.
func Record(ctx context.Context, q database.Querier, e Event) error {
	if e.ActorKind == "" {
		e.ActorKind = "user"
	}
	changes := []byte("{}")
	if e.Changes != nil {
		b, err := json.Marshal(e.Changes)
		if err != nil {
			return err
		}
		changes = b
	}
	_, err := q.Exec(ctx, `insert into audit_events (user_id, group_id, actor_user_id, actor_kind, entity_type, entity_id, action, changes, request_id)
		values ($1,$2,$3,$4,$5,$6,$7,$8,nullif($9,''))`,
		e.UserID, e.GroupID, e.ActorUserID, e.ActorKind, e.EntityType, e.EntityID, e.Action, changes, logging.RequestID(ctx))
	return database.MapError(err)
}

// SecurityEvent is an authentication/authorization-relevant event.
type SecurityEvent struct {
	UserID    *uuid.UUID
	Type      string // e.g. login_succeeded, login_failed, refresh_reuse_detected
	Severity  string // info | warning | critical
	SessionID *uuid.UUID
	Details   map[string]any
}

// Security inserts a security event, capturing hashed client context.
func Security(ctx context.Context, q database.Querier, ipSalt string, e SecurityEvent) error {
	if e.Severity == "" {
		e.Severity = "info"
	}
	details := []byte("{}")
	if e.Details != nil {
		b, err := json.Marshal(e.Details)
		if err != nil {
			return err
		}
		details = b
	}
	ci := httpx.Client(ctx)
	_, err := q.Exec(ctx, `insert into security_events (user_id, event_type, severity, ip_hash, user_agent, client_kind, session_id, details, request_id)
		values ($1,$2,$3,nullif($4,''),nullif($5,''),$6,$7,$8,nullif($9,''))`,
		e.UserID, e.Type, e.Severity, httpx.HashIP(ci.IP, ipSalt), ci.UA, ci.Kind, e.SessionID, details, logging.RequestID(ctx))
	return database.MapError(err)
}

// Ptr is a helper for optional UUIDs.
func Ptr(id uuid.UUID) *uuid.UUID { return &id }
