package notifications

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/jobs"
)

// Digest jobs.
const (
	JobDigestScan = "notifications.digest_scan" // hourly: users whose local digest time has come
	JobDigestSend = "notifications.digest_send" // one user
)

// digestHour is the local hour digests go out.
const digestHour = 8

// usesDigest reports whether an email for this notification waits for the
// digest: optional (not security/account), not urgent, and the user chose
// a digest for email in general or for this category.
func usesDigest(category, priority, userDigest, categoryDigest string) bool {
	if alwaysOn[category] || priority == "critical" || priority == "high" {
		return false
	}
	return userDigest != "off" || (categoryDigest != "" && categoryDigest != "immediate")
}

// weeklyHeld is SQL (aliases p = user_preferences, np = the category's
// email preference row, possibly null) that is true when a held email waits
// for the weekly digest: a category digest of daily or weekly decides for
// that category, otherwise the account email_digest does.
const weeklyHeld = `(case when np.digest in ('daily','weekly') then np.digest = 'weekly' else p.email_digest = 'weekly' end)`

// heldEmails joins a held email delivery d (notification n) with what
// decides its digest cadence.
const heldEmails = `notification_deliveries d join notifications n on n.id = d.notification_id
	join user_preferences p on p.user_id = d.user_id
	left join notification_preferences np on np.user_id = n.user_id and np.category = n.category and np.channel = 'email' and np.group_id is null`

// unsubscribeToken signs (user, category, expiry) for one-click unsubscribe.
func (s *Service) unsubscribeToken(uid uuid.UUID, category string, now time.Time) string {
	if s.Signer == nil {
		return ""
	}
	exp := strconv.FormatInt(now.Add(60*24*time.Hour).Unix(), 10)
	payload := uid.String() + "|" + category + "|" + exp
	return base64.RawURLEncoding.EncodeToString([]byte(payload)) + "." + s.Signer.Sign("unsubscribe", payload)
}

func (s *Service) unsubscribeURL(uid uuid.UUID, category string) string {
	t := s.unsubscribeToken(uid, category, time.Now())
	if t == "" || alwaysOn[category] {
		return ""
	}
	// The token travels in the URL fragment, which browsers never send to servers.
	return strings.TrimRight(s.Cfg.HTTP.WebAppURL, "/") + "/unsubscribe#token=" + t
}

// UnsubscribeInput carries the signed token from an email link.
type UnsubscribeInput struct {
	Token string `json:"token" minLength:"20" maxLength:"500"`
}

// UnsubscribeResult reports what was turned off.
type UnsubscribeResult struct {
	Category string `json:"category"`
	Channel  string `json:"channel" enum:"email"`
}

// Unsubscribe turns off email for one category from a signed link (no
// sign-in needed). Security and account emails cannot be turned off.
func (s *Service) Unsubscribe(ctx context.Context, token string) (*UnsubscribeResult, error) {
	payloadB64, sig, ok := strings.Cut(token, ".")
	bad := apperr.New(apperr.CodeGone, http.StatusGone, "This unsubscribe link is invalid or has expired. Change email settings in Montra.")
	if !ok || s.Signer == nil {
		return nil, bad
	}
	raw, err := base64.RawURLEncoding.DecodeString(payloadB64)
	if err != nil || !s.Signer.Verify(sig, "unsubscribe", string(raw)) {
		return nil, bad
	}
	parts := strings.Split(string(raw), "|")
	if len(parts) != 3 {
		return nil, bad
	}
	uid, err := uuid.Parse(parts[0])
	exp, perr := strconv.ParseInt(parts[2], 10, 64)
	if err != nil || perr != nil || time.Now().Unix() > exp {
		return nil, bad
	}
	category := parts[1]
	if alwaysOn[category] {
		return nil, apperr.Rule("always_on_category", "Security and account emails cannot be turned off.", nil)
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `insert into notification_preferences (user_id, category, group_id, channel, enabled) values ($1,$2,null,'email',false)
			on conflict (user_id, category, coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid), channel) do update set enabled = false`,
			uid, category)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &UnsubscribeResult{Category: category, Channel: "email"}, nil
}

// DigestScan enqueues digests for users whose local digest time is now
// (the hourly job; exported for operations and tests). Every day at 08:00
// local time the emails held for a daily digest go out; on Mondays the
// digest also carries the emails held for the weekly one.
func (s *Service) DigestScan(ctx context.Context, now time.Time) error {
	day := now.UTC().Format("2006010215")
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select d.user_id, extract(isodow from ($1::timestamptz at time zone p.timezone)) = 1
			from `+heldEmails+` join users u on u.id = d.user_id
			where d.channel = 'email' and d.status = 'skipped' and d.skip_reason = 'digest' and u.status = 'active'
			and extract(hour from ($1::timestamptz at time zone p.timezone)) = $2
			and (extract(isodow from ($1::timestamptz at time zone p.timezone)) = 1 or not `+weeklyHeld+`)
			group by 1, 2 limit 10000`, now, digestHour)
		if err != nil {
			return err
		}
		type due struct {
			uid    uuid.UUID
			weekly bool
		}
		list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (due, error) {
			var d due
			err := r.Scan(&d.uid, &d.weekly)
			return d, err
		})
		if err != nil {
			return err
		}
		for _, d := range list {
			uid := d.uid
			if _, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobDigestSend, UserID: &uid, Payload: map[string]any{"user_id": uid, "weekly": d.weekly},
				DedupeKey: "digest:" + uid.String() + ":" + day, Priority: 170}); err != nil {
				return err
			}
		}
		return nil
	})
}

// digestSend sends one digest email listing the waiting notifications
// (titles only) and marks them digested. weekly includes the emails held
// for the weekly digest (nil: decide from the user's local day now).
func (s *Service) digestSend(ctx context.Context, uid uuid.UUID, weekly *bool, sender email.Sender) error {
	var addr, name, locale string
	var ids []uuid.UUID
	var titles []string
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `select u.email, p.display_name, pr.locale from users u join profiles p on p.user_id = u.id
			join user_preferences pr on pr.user_id = u.id where u.id = $1 and u.status = 'active'`, uid).Scan(&addr, &name, &locale); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select d.id, n.title from `+heldEmails+`
			where d.user_id = $1 and d.channel = 'email' and d.status = 'skipped' and d.skip_reason = 'digest'
			and n.created_at > now() - interval '8 days'
			and (coalesce($2::boolean, extract(isodow from (now() at time zone p.timezone)) = 1) or not `+weeklyHeld+`)
			order by n.created_at desc limit 100`, uid, weekly)
		if err != nil {
			return err
		}
		for rows.Next() {
			var id uuid.UUID
			var t string
			if err := rows.Scan(&id, &t); err != nil {
				rows.Close()
				return err
			}
			ids, titles = append(ids, id), append(titles, t)
		}
		rows.Close()
		return rows.Err()
	})
	if database.IsNoRows(err) || (err == nil && len(ids) == 0) {
		return nil
	}
	if err != nil {
		return err
	}
	shown := titles
	if len(shown) > 15 {
		shown = shown[:15]
	}
	updates := fmt.Sprintf("%d updates", len(titles))
	if len(titles) == 1 {
		updates = "1 update"
	}
	body := fmt.Sprintf("You have %s in Montra:\n\n- %s", updates, strings.Join(shown, "\n- "))
	if len(titles) > len(shown) {
		body += fmt.Sprintf("\n- and %d more", len(titles)-len(shown))
	}
	link := strings.TrimRight(s.Cfg.HTTP.WebAppURL, "/") + "/notifications"
	msg, err := email.Build(email.TplDigest, locale, addr, email.Data{Name: name, Subject: "Your Montra digest: " + updates,
		Body: body, Link: link, Unsubscribe: strings.TrimRight(s.Cfg.HTTP.WebAppURL, "/") + "/settings/notifications"})
	if err != nil {
		return jobs.Permanent(err)
	}
	if err := sender.Send(ctx, msg); err != nil {
		if errors.Is(err, email.ErrNotConfigured) {
			return nil
		}
		return jobs.WithCode("digest_send_failed", err)
	}
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `update notification_deliveries set skip_reason = 'digested', sent_at = now() where id = any($1)`, ids)
		return err
	})
}

// RegisterDigestJobs registers the digest jobs.
func (s *Service) RegisterDigestJobs(reg *jobs.Registry, sender email.Sender) {
	reg.Register(JobDigestScan, func(ctx context.Context, _ jobs.Job) error { return s.DigestScan(ctx, time.Now()) },
		jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(1))
	reg.Register(JobDigestSend, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			UserID uuid.UUID `json:"user_id"`
			Weekly *bool     `json:"weekly"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.digestSend(ctx, p.UserID, p.Weekly, sender)
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(4))
}
