// Package notifications centralizes notification intent and delivery
// (spec §4.17, §20B.18): in-app records are persisted first (deduplicated
// by key), then each external channel delivery is a durable, idempotent job
// honoring preferences and quiet hours. Payloads never carry sensitive
// financial details.
package notifications

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync/atomic"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/jobs"
)

// JobDeliver delivers one notification_deliveries row.
const JobDeliver = "notifications.deliver"

// Categories (must match the notifications.category check constraint).
var Categories = []string{"budget", "bill", "subscription", "recurring", "goal", "group", "settlement", "trip", "community",
	"challenge", "security", "import", "receipt", "export", "account", "insight", "system", "social"}

// alwaysOn categories cannot be fully disabled (security-critical, spec §4.17).
var alwaysOn = map[string]bool{"security": true, "account": true}

// emailDefault lists categories emailed by default (transactional).
var emailDefault = map[string]bool{"security": true, "account": true, "export": true}

// Notification is an intent to notify a user.
type Notification struct {
	UserID     uuid.UUID
	Category   string
	EventType  string
	Title      string // safe summary; no amounts/merchants/descriptions
	Body       string
	DeepLink   string // app path, authorization re-checked on open
	EntityType string
	EntityID   *uuid.UUID
	GroupID    *uuid.UUID
	Priority   string // low | normal | high | critical
	DedupeKey  string
	ExpiresAt  *time.Time
	// InAppOnly records the notification without external deliveries (the
	// caller already sent a dedicated email, e.g. security alerts).
	InAppOnly bool
}

// Create persists an in-app notification and schedules channel deliveries.
// It returns false when the dedupe key was already used (no duplicates on
// retries).
func Create(ctx context.Context, tx pgx.Tx, n Notification) (uuid.UUID, bool, error) {
	if n.Priority == "" {
		n.Priority = "normal"
	}
	n.Title, n.Body = clipRunes(n.Title, 160), clipRunes(n.Body, 500)
	if h := createHook.Load(); h != nil {
		(*h)(n)
	}
	var dedupe, link, etype *string
	if n.DedupeKey != "" {
		dedupe = &n.DedupeKey
	}
	if n.DeepLink != "" {
		if !strings.HasPrefix(n.DeepLink, "/") {
			return uuid.Nil, false, errors.New("deep link must be an app path")
		}
		link = &n.DeepLink
	}
	if n.EntityType != "" {
		etype = &n.EntityType
	}
	prefs, err := loadPrefs(ctx, tx, n)
	if err != nil {
		return uuid.Nil, false, err
	}
	muted := prefs.mutedInApp && !alwaysOn[n.Category]
	var id uuid.UUID
	err = tx.QueryRow(ctx, `insert into notifications (user_id, category, event_type, title, body, deep_link, entity_type, entity_id,
		group_id, priority, dedupe_key, expires_at, archived_at) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,
		case when $13::boolean then now() end)
		on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing returning id`,
		n.UserID, n.Category, n.EventType, n.Title, n.Body, link, etype, n.EntityID, n.GroupID, n.Priority, dedupe, n.ExpiresAt, muted).Scan(&id)
	if database.IsNoRows(err) {
		return uuid.Nil, false, nil
	}
	if err != nil {
		return uuid.Nil, false, database.MapError(err)
	}
	channels := prefs.external(n)
	if n.InAppOnly {
		channels = nil
	}
	for _, ch := range channels {
		var did uuid.UUID
		if err := tx.QueryRow(ctx, `insert into notification_deliveries (notification_id, user_id, channel) values ($1,$2,$3)
			on conflict (notification_id, channel) do nothing returning id`, id, n.UserID, ch).Scan(&did); err != nil {
			if database.IsNoRows(err) {
				continue
			}
			return uuid.Nil, false, database.MapError(err)
		}
		uid := n.UserID
		if _, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobDeliver, UserID: &uid, Priority: priorityFor(n.Priority),
			Payload: map[string]string{"delivery_id": did.String()}, DedupeKey: "deliver:" + did.String(), MaxAttempts: 6}); err != nil {
			return uuid.Nil, false, err
		}
	}
	return id, true, nil
}

func priorityFor(p string) int {
	switch p {
	case "critical":
		return 5
	case "high":
		return 20
	case "low":
		return 150
	}
	return 80
}

type resolvedPrefs struct {
	mutedInApp bool
	email      *bool
	webPush    bool
	push       bool
}

// loadPrefs resolves channel preferences (group-specific rows override
// category rows) and which push endpoints exist.
func loadPrefs(ctx context.Context, tx pgx.Tx, n Notification) (resolvedPrefs, error) {
	var rp resolvedPrefs
	explicit := map[string]bool{}
	rows, err := tx.Query(ctx, `select channel, enabled from notification_preferences
		where user_id = $1 and category = $2 and (group_id is null or group_id = $3)
		order by (group_id is null) desc`, n.UserID, n.Category, n.GroupID)
	if err != nil {
		return rp, database.MapError(err)
	}
	for rows.Next() {
		var ch string
		var en bool
		if err := rows.Scan(&ch, &en); err != nil {
			rows.Close()
			return rp, err
		}
		explicit[ch] = en
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return rp, err
	}
	if v, ok := explicit["in_app"]; ok && !v {
		rp.mutedInApp = true
	}
	if v, ok := explicit["email"]; ok {
		rp.email = &v
	}
	var hasWeb, hasFCM bool
	if err := tx.QueryRow(ctx, `select
		exists (select 1 from push_endpoints e where e.user_id = $1 and e.kind = 'webpush' and e.disabled_at is null and `+liveEndpoint+`),
		exists (select 1 from push_endpoints e where e.user_id = $1 and e.kind = 'fcm' and e.disabled_at is null and `+liveEndpoint+`)`,
		n.UserID).Scan(&hasWeb, &hasFCM); err != nil {
		return rp, err
	}
	rp.webPush = hasWeb && (explicit["web_push"] || !hasKey(explicit, "web_push"))
	rp.push = hasFCM && (explicit["push"] || !hasKey(explicit, "push"))
	return rp, nil
}

func hasKey(m map[string]bool, k string) bool { _, ok := m[k]; return ok }

// liveEndpoint keeps push endpoints (alias e) whose registering session is
// still signed in: not revoked and neither refresh- nor absolute-expired.
// Ending a session deletes its endpoints (migration 000026); this also
// covers sessions that simply expired. Endpoints without a session predate
// session tracking and stay eligible until the user's next session end
// removes them.
const liveEndpoint = `(e.session_id is null or exists (select 1 from user_sessions us where us.id = e.session_id
	and us.revoked_at is null and us.refresh_expires_at > now() and us.absolute_expires_at > now()))`

// external lists the external channels to deliver on.
func (rp resolvedPrefs) external(n Notification) []string {
	var out []string
	email := emailDefault[n.Category]
	if rp.email != nil {
		email = *rp.email
	}
	if email || (alwaysOn[n.Category] && n.Priority == "critical") {
		out = append(out, "email")
	}
	if rp.webPush {
		out = append(out, "web_push")
	}
	if rp.push {
		out = append(out, "push")
	}
	return out
}

// QuietHoursEnd returns when quiet hours end if now falls inside them.
func QuietHoursEnd(now time.Time, tz string, start, end time.Duration) (time.Time, bool) {
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return time.Time{}, false
	}
	local := now.In(loc)
	midnight := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, loc)
	since := local.Sub(midnight)
	if start == end {
		return time.Time{}, false
	}
	inside := false
	var endAt time.Time
	if start < end { // e.g. 13:00–15:00
		inside = since >= start && since < end
		endAt = midnight.Add(end)
	} else { // spans midnight, e.g. 22:00–07:00
		switch {
		case since >= start:
			inside = true
			endAt = midnight.AddDate(0, 0, 1).Add(end)
		case since < end:
			inside = true
			endAt = midnight.Add(end)
		}
	}
	if !inside {
		return time.Time{}, false
	}
	return endAt.UTC(), true
}

// ErrNotConfigured indicates a channel has no configured provider.
var ErrNotConfigured = fmt.Errorf("channel not configured")

// clipRunes keeps at most n characters without splitting one.
func clipRunes(s string, n int) string {
	s = strings.ToValidUTF8(s, "")
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

var createHook atomic.Pointer[func(Notification)]

// SetCreateHook observes every notification passed to Create. Tests use
// it to check that titles and bodies never carry amounts or user text
// beyond names (spec §4.17); nil removes the hook.
func SetCreateHook(f func(Notification)) {
	if f == nil {
		createHook.Store(nil)
		return
	}
	createHook.Store(&f)
}
