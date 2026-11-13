package notifications

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/platform/ratelimit"
)

// Service exposes the notification center and delivery jobs.
type Service struct {
	DB      *database.DB
	Cfg     *config.Config
	Keyring *crypto.Keyring
	Metrics *observability.Metrics
	// WebPush and FCM are configured from owner-provided credentials
	// (ADR-014); nil means the channel is recorded as not configured.
	WebPush *WebPush
	FCM     *FCM
	// PushHostsExtra allows extra Web Push hosts (tests only).
	PushHostsExtra []string
	// Signer signs one-click unsubscribe links.
	Signer *crypto.Signer
}

// NotificationDTO is an in-app notification.
type NotificationDTO struct {
	ID         uuid.UUID  `json:"id"`
	Category   string     `json:"category"`
	EventType  string     `json:"event_type"`
	Title      string     `json:"title"`
	Body       string     `json:"body"`
	DeepLink   *string    `json:"deep_link,omitempty" doc:"App path; the destination re-checks authorization"`
	EntityType *string    `json:"entity_type,omitempty"`
	EntityID   *uuid.UUID `json:"entity_id,omitempty"`
	GroupID    *uuid.UUID `json:"group_id,omitempty"`
	Priority   string     `json:"priority"`
	ReadAt     *time.Time `json:"read_at,omitempty"`
	ArchivedAt *time.Time `json:"archived_at,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
}

type cursor struct {
	T  time.Time `json:"t"`
	ID uuid.UUID `json:"i"`
}

// List returns notifications newest first with cursor pagination.
func (s *Service) List(ctx context.Context, unreadOnly, archived bool, category, after string, limit int) ([]NotificationDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 100 {
		limit = 30
	}
	var cur cursor
	if err := httpx.DecodeCursor(after, &cur); err != nil {
		return nil, "", err
	}
	var out []NotificationDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		// The first page and later pages use separate SQL texts, so a cached
		// generic plan can still bound the index scan by the cursor
		// (docs/QUERY_PLAN_REVIEW.md, R-F).
		q := `select id, category, event_type, title, body, deep_link, entity_type, entity_id, group_id, priority,
			read_at, archived_at, created_at from notifications
			where user_id = $1 and ($2::boolean = false or read_at is null)
			  and (case when $3::boolean then archived_at is not null else archived_at is null end)
			  and ($4 = '' or category = $4)
			  and (expires_at is null or expires_at > now())`
		args := []any{uid, unreadOnly, archived, category}
		if t := nullTime(cur.T); t != nil {
			q += ` and (created_at, id) < ($5::timestamptz, $6::uuid) order by created_at desc, id desc limit $7`
			args = append(args, *t, cur.ID, limit+1)
		} else {
			q += ` order by created_at desc, id desc limit $5`
			args = append(args, limit+1)
		}
		rows, err := tx.Query(ctx, q, args...)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var n NotificationDTO
			if err := rows.Scan(&n.ID, &n.Category, &n.EventType, &n.Title, &n.Body, &n.DeepLink, &n.EntityType, &n.EntityID, &n.GroupID,
				&n.Priority, &n.ReadAt, &n.ArchivedAt, &n.CreatedAt); err != nil {
				return err
			}
			out = append(out, n)
		}
		return rows.Err()
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	next := ""
	if len(out) > limit {
		last := out[limit-1]
		next, _ = httpx.EncodeCursor(cursor{T: last.CreatedAt, ID: last.ID})
		out = out[:limit]
	}
	return out, next, nil
}

func nullTime(t time.Time) *time.Time {
	if t.IsZero() {
		return nil
	}
	return &t
}

// UnreadCount is the notification badge count.
type UnreadCount struct {
	Unread int `json:"unread" doc:"Unread notifications that are not archived or expired"`
}

// UnreadCount returns the unread badge count.
func (s *Service) UnreadCount(ctx context.Context) (int, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return 0, err
	}
	var n int
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select count(*) from notifications where user_id = $1 and read_at is null and archived_at is null
			and (expires_at is null or expires_at > now())`, uid).Scan(&n)
	})
	return n, database.MapError(err)
}

// Update marks a notification read/unread or archived.
func (s *Service) Update(ctx context.Context, id uuid.UUID, read, archived *bool) (*NotificationDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var n NotificationDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx, `update notifications set
			read_at = case when $3::boolean is null then read_at when $3 then coalesce(read_at, now()) else null end,
			archived_at = case when $4::boolean is null then archived_at when $4 then coalesce(archived_at, now()) else null end
			where id = $1 and user_id = $2
			returning id, category, event_type, title, body, deep_link, entity_type, entity_id, group_id, priority, read_at, archived_at, created_at`,
			id, uid, read, archived).Scan(&n.ID, &n.Category, &n.EventType, &n.Title, &n.Body, &n.DeepLink, &n.EntityType, &n.EntityID,
			&n.GroupID, &n.Priority, &n.ReadAt, &n.ArchivedAt, &n.CreatedAt)
		if database.IsNoRows(err) {
			return apperr.NotFound("notification")
		}
		return err
	})
	return &n, database.MapError(err)
}

// ReadAll marks all notifications read.
func (s *Service) ReadAll(ctx context.Context) (int64, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return 0, err
	}
	var n int64
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update notifications set read_at = now() where user_id = $1 and read_at is null`, uid)
		n = tag.RowsAffected()
		return err
	})
	return n, database.MapError(err)
}

// PreferenceDTO is one channel preference.
type PreferenceDTO struct {
	Category string     `json:"category"`
	GroupID  *uuid.UUID `json:"group_id,omitempty"`
	Channel  string     `json:"channel" enum:"in_app,email,web_push,push"`
	Enabled  bool       `json:"enabled"`
	Digest   string     `json:"digest" enum:"immediate,daily,weekly" doc:"Email only; see PATCH /notifications/preferences"`
	Locked   bool       `json:"locked" doc:"Security-critical categories cannot be disabled"`
}

// Preferences returns explicit preferences merged with defaults for every
// category and channel.
func (s *Service) Preferences(ctx context.Context) ([]PreferenceDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	explicit := map[string]PreferenceDTO{}
	var groupRows []PreferenceDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select category, group_id, channel, enabled, digest from notification_preferences where user_id = $1`, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var p PreferenceDTO
			if err := rows.Scan(&p.Category, &p.GroupID, &p.Channel, &p.Enabled, &p.Digest); err != nil {
				return err
			}
			if p.GroupID != nil {
				groupRows = append(groupRows, p)
			} else {
				explicit[p.Category+"|"+p.Channel] = p
			}
		}
		return rows.Err()
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	var out []PreferenceDTO
	for _, c := range Categories {
		for _, ch := range []string{"in_app", "email", "web_push", "push"} {
			p, ok := explicit[c+"|"+ch]
			if !ok {
				p = PreferenceDTO{Category: c, Channel: ch, Enabled: defaultEnabled(c, ch), Digest: "immediate"}
			}
			p.Locked = alwaysOn[c] && (ch == "in_app" || ch == "email")
			if p.Locked {
				p.Enabled = true
			}
			out = append(out, p)
		}
	}
	return append(out, groupRows...), nil
}

// PreferencePatch changes one preference. Fields left out keep their
// current value (a new preference starts from the default).
type PreferencePatch struct {
	Category string     `json:"category"`
	GroupID  *uuid.UUID `json:"group_id,omitempty"`
	Channel  string     `json:"channel" enum:"in_app,email,web_push,push"`
	Enabled  *bool      `json:"enabled,omitempty" doc:"Omit to keep the current value"`
	Digest   *string    `json:"digest,omitempty" enum:"immediate,daily,weekly" doc:"Omit to keep the current value. Email only: daily or weekly holds this category's optional emails for the digest sent at 08:00 local time (weekly: on Mondays) and overrides the account email_digest for this category; immediate follows the account email_digest. High-priority, security and account emails are never held."`
}

// defaultEnabled is a channel's state when no preference was saved.
func defaultEnabled(category, channel string) bool {
	return channel != "email" || emailDefault[category]
}

// UpdatePreferences upserts preferences; fields an item leaves out keep
// their current value.
func (s *Service) UpdatePreferences(ctx context.Context, items []PreferencePatch) ([]PreferenceDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	valid := map[string]bool{}
	for _, c := range Categories {
		valid[c] = true
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		for i, it := range items {
			if !valid[it.Category] {
				return apperr.FieldError(fmt.Sprintf("body.items[%d].category", i), "Unknown category.")
			}
			if it.Enabled == nil && it.Digest == nil {
				return apperr.Validation("", apperr.Detail{Field: fmt.Sprintf("body.items[%d]", i), Code: "required",
					Message: "Send enabled, digest or both."})
			}
			if alwaysOn[it.Category] && it.Enabled != nil && !*it.Enabled && (it.Channel == "in_app" || it.Channel == "email") {
				return apperr.FieldError(fmt.Sprintf("body.items[%d].enabled", i), "Security and account notifications cannot be turned off.")
			}
			if it.GroupID != nil {
				var member bool
				if err := tx.QueryRow(ctx, `select montra.is_group_member($1)`, *it.GroupID).Scan(&member); err != nil {
					return err
				}
				if !member {
					return apperr.NotFound("group")
				}
			}
			// A new row starts from the effective value: a group override
			// inherits the category's saved preference, otherwise the default.
			if _, err := tx.Exec(ctx, `insert into notification_preferences (user_id, category, group_id, channel, enabled, digest)
				values ($1, $2, $3, $4,
					coalesce($5, (select p.enabled from notification_preferences p where $3::uuid is not null and p.user_id = $1 and p.category = $2
						and p.group_id is null and p.channel = $4), $7),
					coalesce($6, 'immediate'))
				on conflict (user_id, category, coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid), channel)
				do update set enabled = coalesce($5, notification_preferences.enabled), digest = coalesce($6, notification_preferences.digest)`,
				uid, it.Category, it.GroupID, it.Channel, it.Enabled, it.Digest, defaultEnabled(it.Category, it.Channel)); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.Preferences(ctx)
}

// PushEndpointInput registers a device or browser for push.
type PushEndpointInput struct {
	Kind         string          `json:"kind" enum:"webpush,fcm"`
	Subscription json.RawMessage `json:"subscription,omitempty" doc:"Web Push subscription JSON (endpoint + keys)"`
	Token        string          `json:"token,omitempty" maxLength:"4096" doc:"FCM registration token"`
	DeviceLabel  string          `json:"device_label,omitempty" maxLength:"120"`
}

// RegisterPushEndpoint stores an encrypted push subscription bound to the
// calling session: ending that session (sign-out, sign-out everywhere,
// revoking it) removes the endpoint.
func (s *Service) RegisterPushEndpoint(ctx context.Context, in PushEndpointInput) (uuid.UUID, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return uuid.Nil, err
	}
	uid := p.UserID
	var secret []byte
	var endpoint string
	switch in.Kind {
	case "webpush":
		var sub struct {
			Endpoint string `json:"endpoint"`
			Keys     struct {
				P256dh string `json:"p256dh"`
				Auth   string `json:"auth"`
			} `json:"keys"`
		}
		if err := json.Unmarshal(in.Subscription, &sub); err != nil || !strings.HasPrefix(sub.Endpoint, "https://") || sub.Keys.P256dh == "" || sub.Keys.Auth == "" {
			return uuid.Nil, apperr.FieldError("body.subscription", "Provide a valid Web Push subscription.")
		}
		// Only known browser push services: Montra never posts to arbitrary URLs.
		u, perr := url.Parse(sub.Endpoint)
		if perr != nil || !AllowedPushHost(u.Hostname(), s.PushHostsExtra) || len(sub.Endpoint) > 1000 {
			return uuid.Nil, apperr.FieldError("body.subscription", "This push service is not supported.")
		}
		if k, err := b64(sub.Keys.P256dh); err != nil || len(k) != 65 {
			return uuid.Nil, apperr.FieldError("body.subscription", "The subscription key is invalid.")
		}
		if a, err := b64(sub.Keys.Auth); err != nil || len(a) != 16 {
			return uuid.Nil, apperr.FieldError("body.subscription", "The subscription auth secret is invalid.")
		}
		secret, endpoint = in.Subscription, sub.Endpoint
	case "fcm":
		if len(in.Token) < 20 {
			return uuid.Nil, apperr.FieldError("body.token", "Provide a valid push token.")
		}
		secret, endpoint = []byte(in.Token), "fcm:"+in.Token
	default:
		return uuid.Nil, apperr.FieldError("body.kind", "Unsupported push kind.")
	}
	h := sha256.Sum256([]byte(endpoint))
	id := uuid.New()
	ct, kid, err := s.Keyring.Encrypt(secret, []byte(id.String()))
	if err != nil {
		return uuid.Nil, apperr.Internal(err)
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		// Re-registering the same endpoint replaces the old row.
		if _, err := tx.Exec(ctx, `delete from push_endpoints where endpoint_hash = $1 and user_id = $2`, h[:], uid); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `insert into push_endpoints (id, user_id, kind, endpoint_hash, subscription_ciphertext, key_id, device_label, session_id)
			values ($1,$2,$3,$4,$5,$6,nullif($7,''),$8)`, id, uid, in.Kind, h[:], ct, kid, in.DeviceLabel, p.SessionID)
		return err
	})
	if database.IsUniqueViolation(err, "push_endpoints_hash_key") {
		return uuid.Nil, apperr.Conflict("This device is registered to another account.")
	}
	return id, database.MapError(err)
}

// PushEndpointDTO is a registered browser or device. The endpoint URL and
// keys are secrets of that browser or device and are never returned.
type PushEndpointDTO struct {
	ID             uuid.UUID  `json:"id"`
	Kind           string     `json:"kind" enum:"webpush,fcm"`
	DeviceLabel    *string    `json:"device_label,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	LastUsedAt     *time.Time `json:"last_used_at,omitempty" doc:"Last successful delivery"`
	DisabledAt     *time.Time `json:"disabled_at,omitempty" doc:"Set when the push service reported the subscription gone or it kept failing; register again to resume"`
	CurrentSession bool       `json:"current_session" doc:"Registered by the session making this request (this browser or device)"`
}

// ListPushEndpoints lists the caller's browsers and devices that can
// receive pushes (registered by a session that is still signed in), newest
// first.
func (s *Service) ListPushEndpoints(ctx context.Context) ([]PushEndpointDTO, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	out := []PushEndpointDTO{}
	err = s.DB.WithUserReadTx(ctx, p.UserID, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select e.id, e.kind, e.device_label, e.created_at, e.last_used_at, e.disabled_at, coalesce(e.session_id = $2, false)
			from push_endpoints e where e.user_id = $1 and `+liveEndpoint+` order by e.created_at desc, e.id desc limit 100`, p.UserID, p.SessionID)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (PushEndpointDTO, error) {
			var d PushEndpointDTO
			err := r.Scan(&d.ID, &d.Kind, &d.DeviceLabel, &d.CreatedAt, &d.LastUsedAt, &d.DisabledAt, &d.CurrentSession)
			return d, err
		})
		return err
	})
	return out, database.MapError(err)
}

// PushConfigDTO tells clients which push channels this server can deliver.
type PushConfigDTO struct {
	WebPush WebPushConfig `json:"web_push"`
}

// WebPushConfig is the browser (Web Push) set-up. The VAPID public key is a
// public value; the private key never leaves the server.
type WebPushConfig struct {
	Available      bool   `json:"available" doc:"false when this server has no VAPID keys: browser notifications cannot be turned on"`
	VAPIDPublicKey string `json:"vapid_public_key,omitempty" doc:"VAPID public key (base64url, uncompressed P-256 point) to subscribe with as applicationServerKey; only when available"`
}

// PushSettings returns the push configuration clients subscribe with.
func (s *Service) PushSettings() PushConfigDTO {
	if s.WebPush == nil {
		return PushConfigDTO{}
	}
	return PushConfigDTO{WebPush: WebPushConfig{Available: true, VAPIDPublicKey: s.WebPush.PublicKey()}}
}

// DeletePushEndpoint removes a push registration.
func (s *Service) DeletePushEndpoint(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from push_endpoints where id = $1 and user_id = $2`, id, uid)
		if err == nil && tag.RowsAffected() == 0 {
			return apperr.NotFound("push endpoint")
		}
		return err
	}))
}

// RegisterJobs registers the delivery handler.
func (s *Service) RegisterJobs(reg *jobs.Registry, sender email.Sender) {
	reg.Register(JobDeliver, func(ctx context.Context, j jobs.Job) error { return s.deliver(ctx, j, sender) },
		jobs.WithTimeout(time.Minute), jobs.WithConcurrency(8))
	s.RegisterDigestJobs(reg, sender)
}

func (s *Service) deliver(ctx context.Context, j jobs.Job, sender email.Sender) error {
	var p struct {
		DeliveryID uuid.UUID `json:"delivery_id"`
	}
	if err := j.Decode(&p); err != nil {
		return err
	}
	var (
		channel, status, title, body, priority, category string
		link                                             *string
		uid                                              uuid.UUID
		addr, name, locale, tz                           string
		userDigest, catDigest                            string
		quietOn                                          bool
		qs, qe                                           int64
		userStatus                                       string
	)
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select d.channel, d.status, n.title, n.body, n.priority, n.category, n.deep_link, n.user_id,
			u.email, p.display_name, pr.locale, pr.timezone, pr.quiet_hours_enabled,
			extract(epoch from pr.quiet_hours_start)::bigint, extract(epoch from pr.quiet_hours_end)::bigint, u.status, pr.email_digest,
			coalesce((select np.digest from notification_preferences np where np.user_id = n.user_id and np.category = n.category
				and np.channel = 'email' and np.group_id is null), 'immediate')
			from notification_deliveries d join notifications n on n.id = d.notification_id
			join users u on u.id = n.user_id join profiles p on p.user_id = u.id join user_preferences pr on pr.user_id = u.id
			where d.id = $1`, p.DeliveryID).Scan(&channel, &status, &title, &body, &priority, &category, &link, &uid,
			&addr, &name, &locale, &tz, &quietOn, &qs, &qe, &userStatus, &userDigest, &catDigest)
	})
	if database.IsNoRows(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if status != "pending" {
		return nil // idempotent: already handled
	}
	mark := func(st, reason, code string) error {
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			_, err := tx.Exec(ctx, `update notification_deliveries set status = $2, skip_reason = nullif($3,''), last_error_code = nullif($4,''),
				attempts = attempts + 1, sent_at = case when $2 = 'sent' then now() else sent_at end where id = $1`, p.DeliveryID, st, reason, code)
			return err
		})
	}
	if userStatus != "active" {
		return mark("skipped", "account_inactive", "")
	}
	if quietOn && priority != "critical" && category != "security" {
		if until, inside := QuietHoursEnd(time.Now(), tz, time.Duration(qs)*time.Second, time.Duration(qe)*time.Second); inside {
			return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
				if _, err := tx.Exec(ctx, `update notification_deliveries set scheduled_for = $2 where id = $1`, p.DeliveryID, until); err != nil {
					return err
				}
				_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobDeliver, UserID: &uid, RunAfter: until,
					Payload: map[string]string{"delivery_id": p.DeliveryID.String()}, DedupeKey: fmt.Sprintf("deliver:%s:%d", p.DeliveryID, until.Unix())})
				return err
			})
		}
	}
	outcome := func(o string) {
		if s.Metrics != nil {
			s.Metrics.NotificationOut.WithLabelValues(channel, o).Inc()
		}
	}
	switch channel {
	case "email":
		if usesDigest(category, priority, userDigest, catDigest) {
			outcome("skipped")
			return mark("skipped", "digest", "") // sent later in the digest
		}
		target := strings.TrimRight(s.Cfg.HTTP.WebAppURL, "/")
		if link != nil {
			target += *link
		}
		msg, err := email.Build(email.TplNotification, locale, addr, email.Data{Name: name, Subject: title, Body: body, Link: target,
			Unsubscribe: s.unsubscribeURL(uid, category)})
		if err != nil {
			return jobs.Permanent(err)
		}
		start := time.Now()
		err = sender.Send(ctx, msg)
		if !errors.Is(err, email.ErrNotConfigured) {
			s.providerCall(sender.Provider(), err, time.Since(start))
		}
		if err != nil {
			if errors.Is(err, email.ErrNotConfigured) {
				outcome("skipped")
				return mark("skipped", "not_configured", "")
			}
			outcome("failed")
			_ = mark("pending", "", "send_failed")
			return jobs.WithCode("email_send_failed", err)
		}
		outcome("sent")
		return mark("sent", "", "")
	default:
		// Web push (VAPID) and FCM need owner-provided credentials (ADR-014).
		if (channel == "web_push" && s.WebPush == nil) || (channel == "push" && s.FCM == nil) {
			outcome("skipped")
			return mark("skipped", "not_configured", "")
		}
		var nid uuid.UUID
		if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			return tx.QueryRow(ctx, `select notification_id from notification_deliveries where id = $1`, p.DeliveryID).Scan(&nid)
		}); err != nil {
			return err
		}
		res, err := s.push(ctx, uid, channel, nid, title, body, link, category, priority)
		if err != nil {
			return err
		}
		switch {
		case res.sent > 0:
			outcome("sent")
			return mark("sent", "", "")
		case res.retry > 0:
			outcome("failed")
			_ = mark("pending", "", "push_retry")
			return jobs.WithCode("push_retry", ErrPushRetry)
		case res.endpoints == 0:
			outcome("skipped")
			return mark("skipped", "no_endpoints", "")
		case res.gone == res.endpoints:
			outcome("skipped")
			return mark("skipped", "endpoint_gone", "") // the browser or device unsubscribed
		default:
			outcome("failed")
			return mark("failed", "", "push_rejected")
		}
	}
}

type pushResult struct{ endpoints, sent, retry, gone int }

// push sends to every active endpoint of the channel. Payloads carry only
// the (non-sensitive) title, body and deep link; gone endpoints are
// disabled.
func (s *Service) push(ctx context.Context, uid uuid.UUID, channel string, nid uuid.UUID, title, body string, link *string, category, priority string) (pushResult, error) {
	kind := map[string]string{"web_push": "webpush", "push": "fcm"}[channel]
	type ep struct {
		id  uuid.UUID
		ct  []byte
		kid string
	}
	var eps []ep
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select e.id, e.subscription_ciphertext, e.key_id from push_endpoints e where e.user_id = $1 and e.kind = $2
			and e.disabled_at is null and `+liveEndpoint+` order by e.created_at desc limit 10`, uid, kind)
		if err != nil {
			return err
		}
		eps, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (ep, error) {
			var e ep
			err := r.Scan(&e.id, &e.ct, &e.kid)
			return e, err
		})
		return err
	}); err != nil {
		return pushResult{}, err
	}
	res := pushResult{endpoints: len(eps)}
	deep := ""
	if link != nil {
		deep = *link
	}
	high := priority == "high" || priority == "critical"
	for _, e := range eps {
		secret, err := s.Keyring.Decrypt(e.ct, e.kid, []byte(e.id.String()))
		if err != nil {
			continue
		}
		var serr error
		if kind == "webpush" {
			var sub WebPushSubscription
			if json.Unmarshal(secret, &sub) != nil {
				continue
			}
			payload, _ := json.Marshal(map[string]string{"title": title, "body": body, "url": deep, "id": nid.String(), "tag": category})
			urgency := "normal"
			if high {
				urgency = "high"
			}
			start := time.Now()
			serr = s.WebPush.Send(ctx, sub, payload, 86400, urgency)
			s.providerCall("webpush", serr, time.Since(start))
		} else {
			start := time.Now()
			serr = s.FCM.Send(ctx, string(secret), title, body, map[string]string{"url": deep, "id": nid.String(), "category": category}, high)
			s.providerCall("fcm", serr, time.Since(start))
		}
		switch {
		case serr == nil:
			res.sent++
			_ = s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
				_, err := tx.Exec(ctx, `update push_endpoints set last_used_at = now(), failure_count = 0 where id = $1`, e.id)
				return err
			})
		case errors.Is(serr, ErrEndpointGone):
			res.gone++
			_ = s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
				_, err := tx.Exec(ctx, `update push_endpoints set disabled_at = now() where id = $1`, e.id)
				return err
			})
		case errors.Is(serr, ErrPushRetry):
			res.retry++
		default:
			_ = s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
				_, err := tx.Exec(ctx, `update push_endpoints set failure_count = failure_count + 1,
					disabled_at = case when failure_count + 1 >= 5 then now() else disabled_at end where id = $1`, e.id)
				return err
			})
		}
	}
	return res, nil
}

// Routes mounts the notification center endpoints.
func (s *Service) Routes(api huma.API) {
	httpx.Public(api, httpx.Errs(httpx.Rate(httpx.Op("notifications-unsubscribe", http.MethodPost, "/notifications/unsubscribe",
		"Turn off one kind of optional email from a signed link (no sign-in needed)", "Notifications"), ratelimit.Auth.Name), http.StatusGone),
		func(ctx context.Context, in *struct{ Body UnsubscribeInput }) (*httpx.Response[UnsubscribeResult], error) {
			r, err := s.Unsubscribe(ctx, in.Body.Token)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	const tag = "Notifications"
	httpx.Protected(api, httpx.Op("notifications-list", http.MethodGet, "/notifications", "List notifications", tag),
		func(ctx context.Context, in *struct {
			Unread   bool   `query:"unread"`
			Archived bool   `query:"archived"`
			Category string `query:"category" maxLength:"20"`
			Cursor   string `query:"cursor" maxLength:"512"`
			Limit    int    `query:"limit" minimum:"1" maximum:"100" default:"30"`
		}) (*httpx.Response[[]NotificationDTO], error) {
			list, next, err := s.List(ctx, in.Unread, in.Archived, in.Category, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, list, next), nil
		})
	httpx.Protected(api, httpx.Op("notifications-unread-count", http.MethodGet, "/notifications/unread-count", "Unread badge count", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[UnreadCount], error) {
			n, err := s.UnreadCount(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, UnreadCount{Unread: n}), nil
		})
	httpx.Protected(api, httpx.Op("notifications-push-config", http.MethodGet, "/notifications/push-config",
		"Which push channels this server can deliver, with the Web Push (VAPID) public key", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[PushConfigDTO], error) {
			return httpx.OK(ctx, s.PushSettings()), nil
		})
	httpx.Protected(api, httpx.Op("notifications-update", http.MethodPatch, "/notifications/{notificationId}", "Mark read/unread or archive", tag),
		func(ctx context.Context, in *struct {
			ID   uuid.UUID `path:"notificationId"`
			Body struct {
				Read     *bool `json:"read,omitempty"`
				Archived *bool `json:"archived,omitempty"`
			}
		}) (*httpx.Response[NotificationDTO], error) {
			n, err := s.Update(ctx, in.ID, in.Body.Read, in.Body.Archived)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *n), nil
		})
	httpx.Protected(api, httpx.Op("notifications-read-all", http.MethodPost, "/notifications/read-all", "Mark all notifications read", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[map[string]int64], error) {
			n, err := s.ReadAll(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, map[string]int64{"updated": n}), nil
		})
	httpx.Protected(api, httpx.Op("notifications-preferences-get", http.MethodGet, "/notifications/preferences", "Notification preferences", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]PreferenceDTO], error) {
			p, err := s.Preferences(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, p), nil
		})
	httpx.Protected(api, httpx.Op("notifications-preferences-update", http.MethodPatch, "/notifications/preferences", "Update notification preferences", tag),
		func(ctx context.Context, in *struct {
			Body struct {
				Items []PreferencePatch `json:"items" minItems:"1" maxItems:"100"`
			}
		}) (*httpx.Response[[]PreferenceDTO], error) {
			p, err := s.UpdatePreferences(ctx, in.Body.Items)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, p), nil
		})
	httpx.Protected(api, httpx.Op("push-endpoints-list", http.MethodGet, "/me/push-endpoints",
		"Your browsers and devices that receive push notifications (never their endpoint URLs or keys)", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]PushEndpointDTO], error) {
			l, err := s.ListPushEndpoints(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(httpx.Op("push-endpoints-register", http.MethodPost, "/me/push-endpoints",
		"Register a push endpoint for this session (removed when the session ends)", tag)),
		func(ctx context.Context, in *struct{ Body PushEndpointInput }) (*httpx.Response[map[string]uuid.UUID], error) {
			id, err := s.RegisterPushEndpoint(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, map[string]uuid.UUID{"id": id}), nil
		})
	httpx.Protected(api, httpx.Op("push-endpoints-delete", http.MethodDelete, "/me/push-endpoints/{endpointId}", "Remove a push endpoint", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"endpointId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeletePushEndpoint(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
}

// providerCall records one outbound channel call (provider, outcome, latency).
func (s *Service) providerCall(provider string, err error, d time.Duration) {
	if s.Metrics == nil {
		return
	}
	outcome := "ok"
	switch {
	case err == nil:
	case errors.Is(err, ErrEndpointGone):
		outcome = "gone"
	case errors.Is(err, ErrPushRetry):
		outcome = "retry"
	default:
		outcome = "error"
	}
	s.Metrics.ProviderCalls.WithLabelValues(provider, "send", outcome).Inc()
	s.Metrics.ProviderLatency.WithLabelValues(provider, "send").Observe(d.Seconds())
}
