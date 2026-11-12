package auth

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/store/db"
)

// RegisterJobs registers the auth email job handlers on the worker.
func (s *Service) RegisterJobs(reg *jobs.Registry, sender email.Sender) {
	reg.Register(JobSendVerification, func(ctx context.Context, j jobs.Job) error {
		return s.sendTokenEmail(ctx, sender, j, "email_verification", s.Cfg.Auth.EmailVerificationTTL, email.TplVerifyEmail, "/verify-email")
	}, jobs.WithTimeout(time.Minute))
	reg.Register(JobSendPasswordReset, func(ctx context.Context, j jobs.Job) error {
		return s.sendTokenEmail(ctx, sender, j, "password_reset", s.Cfg.Auth.PasswordResetTTL, email.TplPasswordReset, "/reset-password")
	}, jobs.WithTimeout(time.Minute))
	reg.Register(JobSendAccountExists, func(ctx context.Context, j jobs.Job) error {
		r, err := s.recipient(ctx, j)
		if err != nil || r == nil {
			return err
		}
		msg, err := email.Build(email.TplAccountExists, r.locale, r.email, email.Data{Link: s.webLink("/sign-in")})
		if err != nil {
			return jobs.Permanent(err)
		}
		return deliver(ctx, sender, msg)
	}, jobs.WithTimeout(time.Minute))
	reg.Register(JobSendSecurityEmail, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			Template string `json:"template"`
			State    string `json:"state"`
		}
		if err := j.Decode(&p); err != nil {
			return err
		}
		r, err := s.recipient(ctx, j)
		if err != nil || r == nil {
			return err
		}
		tpl := email.TplPasswordChanged
		d := email.Data{Name: r.name, Support: s.Cfg.Product.SupportEmail}
		event, title := "security.password_changed", "Your password was changed"
		if p.Template == "mfa_changed" {
			tpl = email.TplMFAChanged
			d.Body = p.State
			event, title = "security.mfa_"+p.State, "Two-step verification was turned off"
			if p.State == "enabled" {
				title = "Two-step verification was turned on"
			}
		}
		// The alert also appears in the notification center; the dedicated
		// email below is its only external delivery.
		uid := *j.UserID
		if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "security", EventType: event, Title: title,
				Body: "If this wasn't you, reset your password and review your signed-in devices.", DeepLink: "/settings/security",
				Priority: "high", DedupeKey: "security_alert:" + j.ID.String(), InAppOnly: true})
			return err
		}); err != nil {
			return err
		}
		msg, err := email.Build(tpl, r.locale, r.email, d)
		if err != nil {
			return jobs.Permanent(err)
		}
		return deliver(ctx, sender, msg)
	}, jobs.WithTimeout(time.Minute))
}

type recipient struct {
	email, name, locale string
	verified            bool
	status              string
}

func (s *Service) recipient(ctx context.Context, j jobs.Job) (*recipient, error) {
	if j.UserID == nil {
		return nil, jobs.Permanent(errors.New("job has no user"))
	}
	var r recipient
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select u.email, p.display_name, pr.locale, u.email_verified_at is not null, u.status
			from users u join profiles p on p.user_id = u.id join user_preferences pr on pr.user_id = u.id where u.id = $1`, *j.UserID).
			Scan(&r.email, &r.name, &r.locale, &r.verified, &r.status)
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil // user gone: nothing to send
	}
	if err != nil {
		return nil, err
	}
	if r.status == "deleted" || r.status == "pending_deletion" {
		return nil, nil
	}
	return &r, nil
}

func (s *Service) sendTokenEmail(ctx context.Context, sender email.Sender, j jobs.Job, purpose string, ttl time.Duration, tpl, path string) error {
	r, err := s.recipient(ctx, j)
	if err != nil || r == nil {
		return err
	}
	if purpose == "email_verification" && r.verified {
		return nil
	}
	token := crypto.MustRandomToken(32)
	err = s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		q := db.New(tx)
		// Only the newest link is valid.
		if err := q.InvalidateTokens(ctx, db.InvalidateTokensParams{UserID: *j.UserID, Purpose: purpose}); err != nil {
			return err
		}
		return q.InsertAuthToken(ctx, db.InsertAuthTokenParams{UserID: *j.UserID, Purpose: purpose, TokenHash: crypto.HashToken(token),
			Payload: json.RawMessage(`{}`), ExpiresAt: time.Now().Add(ttl)})
	})
	if err != nil {
		return err
	}
	msg, err := email.Build(tpl, r.locale, r.email, email.Data{Name: r.name, Link: s.webLink(path) + "#token=" + token,
		Expiry: humanDuration(ttl)})
	if err != nil {
		return jobs.Permanent(err)
	}
	return deliver(ctx, sender, msg)
}

func deliver(ctx context.Context, sender email.Sender, msg email.Message) error {
	if err := sender.Send(ctx, msg); err != nil {
		if errors.Is(err, email.ErrNotConfigured) {
			return jobs.Permanent(jobs.WithCode("email_not_configured", err))
		}
		return jobs.WithCode("email_send_failed", err)
	}
	return nil
}

func (s *Service) webLink(path string) string {
	return strings.TrimRight(s.Cfg.HTTP.WebAppURL, "/") + path
}

func humanDuration(d time.Duration) string {
	if d >= time.Hour && d%time.Hour == 0 {
		h := int(d / time.Hour)
		if h == 1 {
			return "1 hour"
		}
		return fmt.Sprintf("%d hours", h)
	}
	return fmt.Sprintf("%d minutes", int(d/time.Minute))
}
