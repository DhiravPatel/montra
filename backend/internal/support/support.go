// Package support handles help requests, bug reports, security and privacy
// reports and feedback (spec §4.21, §20B.21). Signed-in users file and
// track requests and exchange messages with Montra staff on them;
// signed-out people can use the contact form (rate limited, captcha when
// configured); Montra staff work the queue. Requests never need passwords,
// PINs, OTPs or card numbers, and text containing them is refused.
package support

import (
	"context"
	"errors"
	"fmt"
	"net/mail"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/textsafe"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
)

// Captcha verifies a captcha token (Turnstile when configured).
type Captcha interface {
	Verify(ctx context.Context, token, remoteIP string) error
}

// Service implements support requests.
type Service struct {
	DB      *database.DB
	Cfg     *config.Config
	Captcha Captcha
	Now     func() time.Time
}

// Daily caps (per 24 h): requests per signed-in user, messages per
// requester, and contact-form requests per contact address.
const (
	dailyCap        = 10
	dailyMessageCap = 10
	dailyWindow     = 24 * time.Hour
)

// DailyCap is the request cap published by GET /limits.
const DailyCap = dailyCap

// RequestInput files a request.
type RequestInput struct {
	Kind    string `json:"kind" enum:"support,bug,security,privacy,feedback"`
	Subject string `json:"subject" minLength:"3" maxLength:"160"`
	Body    string `json:"body" minLength:"1" maxLength:"5000" doc:"Describe the problem. Never include passwords, PINs, OTPs or card numbers."`
}

// ContactInput is the signed-out contact form.
type ContactInput struct {
	Kind         string `json:"kind" enum:"support,bug,security,privacy"`
	Subject      string `json:"subject" minLength:"3" maxLength:"160"`
	Body         string `json:"body" minLength:"1" maxLength:"5000"`
	ContactEmail string `json:"contact_email" format:"email" maxLength:"320" doc:"Where support replies"`
	CaptchaToken string `json:"captcha_token,omitempty" maxLength:"4096"`
}

// RequestDTO is a request as its author sees it.
type RequestDTO struct {
	ID            uuid.UUID  `json:"id"`
	Reference     string     `json:"reference" doc:"Short reference to quote when contacting support"`
	Kind          string     `json:"kind" enum:"support,bug,security,privacy,feedback"`
	Subject       string     `json:"subject"`
	Body          string     `json:"body"`
	Status        string     `json:"status" enum:"open,in_progress,resolved,closed"`
	MessageCount  int        `json:"message_count" doc:"Messages in the thread (GET /support/requests/{id}/messages)"`
	LastMessageAt *time.Time `json:"last_message_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

// StaffRequestDTO adds what staff need to reply.
type StaffRequestDTO struct {
	RequestDTO
	ContactEmail *string `json:"contact_email,omitempty"`
	SignedIn     bool    `json:"signed_in" doc:"Filed from a signed-in account"`
	ClientKind   *string `json:"client_kind,omitempty"`
	AppVersion   *string `json:"app_version,omitempty"`
}

// ContactResult acknowledges the contact form.
type ContactResult struct {
	Reference string `json:"reference"`
}

// MessageDTO is one message in a request's thread.
type MessageDTO struct {
	ID         uuid.UUID `json:"id"`
	RequestID  uuid.UUID `json:"request_id"`
	AuthorRole string    `json:"author_role" enum:"requester,staff"`
	Mine       bool      `json:"mine" doc:"Written by you"`
	Body       string    `json:"body"`
	CreatedAt  time.Time `json:"created_at"`
}

// MessageInput adds a message to a thread.
type MessageInput struct {
	Body string `json:"body" minLength:"1" maxLength:"5000" doc:"Never include passwords, PINs, OTPs or card numbers."`
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

func reference(id uuid.UUID) string { return strings.ToUpper(id.String()[:8]) }

// secretError refuses text that carries a payment secret (coded so clients
// can explain it in the person's language).
func secretError() error {
	const msg = "Remove card numbers, PINs, OTPs or passwords. Montra support never needs them."
	return apperr.Validation(msg, apperr.Detail{Field: "body.body", Code: "contains_secret", Message: msg})
}

func clean(subject, body string) (string, string, error) {
	sub, err := textsafe.Clean(subject, 3, 160)
	if err != nil {
		return "", "", apperr.FieldError("body.subject", "Enter a subject of 3 to 160 characters.")
	}
	b, err := cleanBody(body)
	if err != nil {
		return "", "", err
	}
	if textsafe.Secret(sub) {
		return "", "", secretError()
	}
	return sub, b, nil
}

func cleanBody(body string) (string, error) {
	b, err := textsafe.Clean(body, 1, 5000)
	if err != nil {
		return "", apperr.FieldError("body.body", "Describe the problem in up to 5000 characters.")
	}
	if textsafe.Secret(b) {
		return "", secretError()
	}
	return b, nil
}

// capError is the coded 429 for a daily cap: Retry-After says when the
// oldest counted item leaves the 24 h window.
func capError(what string, limit int, oldest time.Time, now time.Time) error {
	retry := oldest.Add(dailyWindow).Sub(now)
	if retry < time.Second {
		retry = time.Second
	}
	msg := fmt.Sprintf("You can send up to %d %s a day. Please try again later.", limit, what)
	return apperr.RateLimited().WithDetails(apperr.Detail{Code: "daily_cap", Message: msg,
		Params: map[string]string{"limit": strconv.Itoa(limit), "window_hours": "24", "kind": what}}).WithRetryAfter(retry)
}

func nullable(v string) *string {
	if v == "" {
		return nil
	}
	return &v
}

const cols = `id, kind, subject, body, status, created_at, updated_at,
	(select count(*) from support_messages m where m.request_id = support_requests.id),
	(select max(m.created_at) from support_messages m where m.request_id = support_requests.id)`

func scan(r pgx.Row) (*RequestDTO, error) {
	var d RequestDTO
	if err := r.Scan(&d.ID, &d.Kind, &d.Subject, &d.Body, &d.Status, &d.CreatedAt, &d.UpdatedAt, &d.MessageCount, &d.LastMessageAt); err != nil {
		return nil, err
	}
	d.Reference = reference(d.ID)
	return &d, nil
}

// Create files a request for the signed-in user. The account email is
// recorded so staff can reply.
func (s *Service) Create(ctx context.Context, in RequestInput) (*RequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	sub, body, err := clean(in.Subject, in.Body)
	if err != nil {
		return nil, err
	}
	cl := httpx.Client(ctx)
	now := s.now()
	var out *RequestDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var recent int
		var oldest *time.Time
		if err := tx.QueryRow(ctx, `select count(*), min(created_at) from support_requests where user_id = $1 and created_at > $2`, uid,
			now.Add(-dailyWindow)).Scan(&recent, &oldest); err != nil {
			return err
		}
		if recent >= dailyCap && oldest != nil {
			return capError("support requests", dailyCap, *oldest, now)
		}
		var addr string
		if err := tx.QueryRow(ctx, `select email from users where id = $1`, uid).Scan(&addr); err != nil {
			return err
		}
		id := uuid.New()
		if _, err := tx.Exec(ctx, `insert into support_requests (id, user_id, kind, subject, body, contact_email, client_kind, app_version)
			values ($1,$2,$3,$4,$5,$6,$7,$8)`, id, uid, in.Kind, sub, body, addr, nullable(cl.Kind), nullable(clip(cl.Version, 40))); err != nil {
			return err
		}
		var err error
		out, err = scan(tx.QueryRow(ctx, `select `+cols+` from support_requests where id = $1`, id))
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return out, nil
}

func clip(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}

// Contact files a request without signing in (for example "I cannot sign
// in"). The reply goes to the given address, which gets the same daily cap
// as a signed-in account.
func (s *Service) Contact(ctx context.Context, in ContactInput) (*ContactResult, error) {
	cl := httpx.Client(ctx)
	if s.Captcha != nil {
		if err := s.Captcha.Verify(ctx, in.CaptchaToken, cl.IP); err != nil {
			return nil, err
		}
	}
	addr, err := mail.ParseAddress(strings.TrimSpace(in.ContactEmail))
	if err != nil || addr.Name != "" {
		return nil, apperr.FieldError("body.contact_email", "Enter a valid email address.")
	}
	sub, body, err := clean(in.Subject, in.Body)
	if err != nil {
		return nil, err
	}
	id := uuid.New()
	now := s.now()
	contact := strings.ToLower(addr.Address)
	err = s.DB.WithAnonTx(ctx, func(tx pgx.Tx) error {
		var recent int
		var oldest *time.Time
		if err := tx.QueryRow(ctx, `select recent, oldest from montra.support_contact_window($1, $2, $3)`, contact, now.Add(-dailyWindow), dailyCap).
			Scan(&recent, &oldest); err != nil {
			return err
		}
		if recent >= dailyCap && oldest != nil {
			return capError("support requests", dailyCap, *oldest, now)
		}
		_, err := tx.Exec(ctx, `insert into support_requests (id, user_id, kind, subject, body, contact_email, client_kind, app_version)
			values ($1,null,$2,$3,$4,$5,$6,$7)`, id, in.Kind, sub, body, contact, nullable(cl.Kind), nullable(clip(cl.Version, 40)))
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &ContactResult{Reference: reference(id)}, nil
}

// Mine lists the caller's requests, newest first.
func (s *Service) Mine(ctx context.Context) ([]RequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []RequestDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+cols+` from support_requests where user_id = $1 order by created_at desc limit 100`, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			d, err := scan(rows)
			if err != nil {
				return err
			}
			out = append(out, *d)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// Get returns one of the caller's requests.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*RequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *RequestDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out, err = scan(tx.QueryRow(ctx, `select `+cols+` from support_requests where id = $1 and user_id = $2`, id, uid))
		return err
	})
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("support request")
	}
	return out, database.MapError(err)
}

// thread is what the messages endpoints need to know about a request.
type thread struct {
	requester *uuid.UUID
	status    string
}

// loadThread returns the request when the caller may read its thread: the
// requester, or Montra staff (RLS hides every other request). role is the
// caller's role in the thread.
func loadThread(ctx context.Context, tx pgx.Tx, p identity.Principal, id uuid.UUID) (*thread, string, error) {
	var t thread
	if err := tx.QueryRow(ctx, `select user_id, status from support_requests where id = $1`, id).Scan(&t.requester, &t.status); err != nil {
		if database.IsNoRows(err) {
			return nil, "", apperr.NotFound("support request")
		}
		return nil, "", err
	}
	if t.requester != nil && *t.requester == p.UserID {
		return &t, "requester", nil
	}
	if p.IsStaff() {
		return &t, "staff", nil
	}
	return nil, "", apperr.NotFound("support request")
}

// Messages lists a request's thread, oldest first.
func (s *Service) Messages(ctx context.Context, id uuid.UUID) ([]MessageDTO, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	out := []MessageDTO{}
	err = s.DB.WithUserReadTx(ctx, p.UserID, func(tx pgx.Tx) error {
		if _, _, err := loadThread(ctx, tx, p, id); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select id, request_id, author_role, author_user_id is not distinct from $2, body, created_at from support_messages
			where request_id = $1 order by created_at, id limit 500`, id, p.UserID)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (MessageDTO, error) {
			var m MessageDTO
			err := r.Scan(&m.ID, &m.RequestID, &m.AuthorRole, &m.Mine, &m.Body, &m.CreatedAt)
			return m, err
		})
		return err
	})
	return out, database.MapError(err)
}

// PostMessage adds a message to a thread. The requester and staff can
// post while the request is not closed; staff replies notify a signed-in
// requester (the notification never carries the text). Every post is
// audited without its text.
func (s *Service) PostMessage(ctx context.Context, id uuid.UUID, in MessageInput) (*MessageDTO, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	body, err := cleanBody(in.Body)
	if err != nil {
		return nil, err
	}
	now := s.now()
	var out MessageDTO
	err = s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		t, role, err := loadThread(ctx, tx, p, id)
		if err != nil {
			return err
		}
		if t.status == "closed" {
			return apperr.Rule("request_closed", "This request is closed.", nil)
		}
		if role == "requester" {
			var recent int
			var oldest *time.Time
			if err := tx.QueryRow(ctx, `select count(*), min(created_at) from support_messages where author_user_id = $1 and created_at > $2`,
				p.UserID, now.Add(-dailyWindow)).Scan(&recent, &oldest); err != nil {
				return err
			}
			if recent >= dailyMessageCap && oldest != nil {
				return capError("support messages", dailyMessageCap, *oldest, now)
			}
		}
		mid := uuid.New()
		if err := tx.QueryRow(ctx, `insert into support_messages (id, request_id, author_user_id, author_role, body) values ($1,$2,$3,$4,$5)
			returning id, request_id, author_role, true, body, created_at`, mid, id, p.UserID, role, body).
			Scan(&out.ID, &out.RequestID, &out.AuthorRole, &out.Mine, &out.Body, &out.CreatedAt); err != nil {
			return err
		}
		actorKind := "user"
		if role == "staff" {
			actorKind = "support"
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: t.requester, ActorUserID: &p.UserID, ActorKind: actorKind, EntityType: "support_request",
			EntityID: &id, Action: "message_posted", Changes: map[string]any{"message_id": mid, "author_role": role}}); err != nil {
			return err
		}
		if role == "staff" && t.requester != nil {
			// The requester's notification is created with system scope by
			// the worker (the API role writes only its own notifications).
			uid := p.UserID
			_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobNotifyReply, UserID: &uid, Payload: map[string]any{"message_id": mid},
				DedupeKey: "support.notify_reply:" + mid.String(), Priority: 90})
			return err
		}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// notifyReply tells a signed-in requester that staff replied (title and
// body carry the reference only, never the message).
func (s *Service) notifyReply(ctx context.Context, messageID uuid.UUID) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var rid uuid.UUID
		var requester *uuid.UUID
		var role string
		err := tx.QueryRow(ctx, `select m.request_id, r.user_id, m.author_role from support_messages m join support_requests r on r.id = m.request_id
			where m.id = $1`, messageID).Scan(&rid, &requester, &role)
		if database.IsNoRows(err) || (err == nil && (requester == nil || role != "staff")) {
			return nil
		}
		if err != nil {
			return err
		}
		_, _, err = notifications.Create(ctx, tx, notifications.Notification{UserID: *requester, Category: "account", EventType: "support_reply",
			Title: "Support replied to request " + reference(rid), Body: "Open the request to read the reply.", DeepLink: "/help/requests/" + rid.String(),
			EntityType: "support_request", EntityID: &rid, DedupeKey: "support_reply:" + messageID.String()})
		return err
	})
}

// Queue lists requests for staff (RLS allows support/admin roles).
func (s *Service) Queue(ctx context.Context, status, kind string) ([]StaffRequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []StaffRequestDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+cols+`, contact_email, user_id is not null, client_kind, app_version from support_requests
			where ($1 = '' or status = $1) and ($2 = '' or kind = $2)
			order by case kind when 'security' then 0 when 'privacy' then 1 else 2 end, created_at limit 200`, status, kind)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var d StaffRequestDTO
			if err := rows.Scan(&d.ID, &d.Kind, &d.Subject, &d.Body, &d.Status, &d.CreatedAt, &d.UpdatedAt, &d.MessageCount, &d.LastMessageAt,
				&d.ContactEmail, &d.SignedIn, &d.ClientKind, &d.AppVersion); err != nil {
				return err
			}
			d.Reference = reference(d.ID)
			out = append(out, d)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// StatusInput changes a request's status (staff).
type StatusInput struct {
	Status string `json:"status" enum:"in_progress,resolved,closed"`
}

// SetStatus moves a request through open → in_progress → resolved/closed.
func (s *Service) SetStatus(ctx context.Context, id uuid.UUID, in StatusInput) (*StaffRequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var cur string
		if err := tx.QueryRow(ctx, `select status from support_requests where id = $1 for update`, id).Scan(&cur); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("support request")
			}
			return err
		}
		if cur == "closed" {
			return apperr.Rule("request_closed", "This request is closed.", nil)
		}
		if _, err := tx.Exec(ctx, `update support_requests set status = $2 where id = $1`, id, in.Status); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{ActorUserID: &uid, EntityType: "support_request", EntityID: &id, Action: "status_changed",
			Changes: map[string]any{"from": cur, "to": in.Status}})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	l, err := s.Queue(ctx, "", "")
	if err != nil {
		return nil, err
	}
	for i := range l {
		if l[i].ID == id {
			return &l[i], nil
		}
	}
	return nil, apperr.NotFound("support request")
}

// Job types.
const (
	// JobNotifyStaff emails the support (and, for security reports, the
	// security) inbox a count of the previous hour's new requests. Message
	// bodies stay in Montra; the email carries counts only.
	JobNotifyStaff = "support.notify_staff"
	// JobNotifyReply notifies a requester of a staff reply (one message).
	JobNotifyReply = "support.notify_reply"
)

// RegisterJobs registers the staff notification job.
func (s *Service) RegisterJobs(reg *jobs.Registry, sender email.Sender) {
	reg.Register(JobNotifyStaff, func(ctx context.Context, _ jobs.Job) error { return s.notifyStaff(ctx, sender) },
		jobs.WithTimeout(time.Minute), jobs.WithConcurrency(1))
	reg.Register(JobNotifyReply, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			MessageID uuid.UUID `json:"message_id"`
		}
		if err := j.Decode(&p); err != nil {
			return err
		}
		return s.notifyReply(ctx, p.MessageID)
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
}

func (s *Service) notifyStaff(ctx context.Context, sender email.Sender) error {
	if sender == nil {
		return nil
	}
	counts := map[string]int{}
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select kind, count(*) from support_requests where status = 'open'
			and created_at >= date_trunc('hour', $1::timestamptz) - interval '1 hour' and created_at < date_trunc('hour', $1::timestamptz)
			group by kind`, s.now())
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var k string
			var n int
			if err := rows.Scan(&k, &n); err != nil {
				return err
			}
			counts[k] = n
		}
		return rows.Err()
	})
	if err != nil || len(counts) == 0 {
		return err
	}
	total := 0
	var parts []string
	for _, k := range []string{"security", "privacy", "bug", "support", "feedback"} {
		if counts[k] > 0 {
			total += counts[k]
			parts = append(parts, fmt.Sprintf("%s: %d", k, counts[k]))
		}
	}
	link := strings.TrimRight(s.Cfg.HTTP.WebAppURL, "/") + "/staff/support"
	send := func(to string) error {
		msg, err := email.Build(email.TplNotification, "en-IN", to, email.Data{Name: "Montra support team",
			Subject: fmt.Sprintf("Montra: %d new support requests", total), Body: "New in the last hour: " + strings.Join(parts, ", ") + ".", Link: link})
		if err != nil {
			return jobs.Permanent(err)
		}
		if err := sender.Send(ctx, msg); err != nil && !errors.Is(err, email.ErrNotConfigured) {
			return jobs.WithCode("support_notify_failed", err)
		}
		return nil
	}
	if err := send(s.Cfg.Product.SupportEmail); err != nil {
		return err
	}
	if counts["security"] > 0 && s.Cfg.Product.SecurityEmail != s.Cfg.Product.SupportEmail {
		return send(s.Cfg.Product.SecurityEmail)
	}
	return nil
}
