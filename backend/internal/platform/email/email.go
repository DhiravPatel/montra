// Package email sends transactional email through a provider adapter
// (ADR-014): generic SMTP with mandatory TLS for hosted environments, or the
// development-only dev mailbox that writes .eml files to disk. Message
// bodies are never logged.
package email

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"fmt"
	"mime"
	"mime/quotedprintable"
	"net"
	"net/mail"
	"net/smtp"
	"net/textproto"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"montra/backend/internal/platform/breaker"
	"montra/backend/internal/platform/config"
)

// ErrNotConfigured is returned when email delivery is disabled.
var ErrNotConfigured = errors.New("email delivery is not configured")

// Message is a transactional email.
type Message struct {
	To       string
	Subject  string
	Text     string
	HTML     string
	Category string // for metrics only
}

// Sender delivers messages.
type Sender interface {
	Send(ctx context.Context, m Message) error
	Provider() string
	Configured() bool
}

// New builds the configured sender.
func New(cfg config.EmailConfig) (Sender, error) {
	from, err := mail.ParseAddress(cfg.From)
	if err != nil {
		return nil, fmt.Errorf("EMAIL_FROM invalid: %w", err)
	}
	switch cfg.Provider {
	case config.EmailSMTP:
		return &smtpSender{cfg: cfg, from: from, breaker: breaker.New("smtp", breaker.Options{IsFailure: smtpFailure})}, nil
	case config.EmailDevMailbox:
		if err := os.MkdirAll(cfg.DevMailDir, 0o700); err != nil {
			return nil, fmt.Errorf("create dev mail dir: %w", err)
		}
		return &devMailbox{dir: cfg.DevMailDir, from: from}, nil
	default:
		return disabled{}, nil
	}
}

type disabled struct{}

func (disabled) Send(context.Context, Message) error { return ErrNotConfigured }
func (disabled) Provider() string                    { return "disabled" }
func (disabled) Configured() bool                    { return false }

// Render builds the RFC 5322 message bytes.
func Render(from *mail.Address, m Message, now time.Time) ([]byte, error) {
	to, err := mail.ParseAddress(m.To)
	if err != nil {
		return nil, fmt.Errorf("invalid recipient: %w", err)
	}
	if strings.ContainsAny(m.Subject, "\r\n") {
		return nil, errors.New("invalid subject")
	}
	boundary := randomHex(12)
	var b bytes.Buffer
	host := "montra.local"
	if at := strings.LastIndex(from.Address, "@"); at >= 0 {
		host = from.Address[at+1:]
	}
	fmt.Fprintf(&b, "From: %s\r\n", from.String())
	fmt.Fprintf(&b, "To: %s\r\n", to.String())
	fmt.Fprintf(&b, "Subject: %s\r\n", mime.QEncoding.Encode("utf-8", m.Subject))
	fmt.Fprintf(&b, "Date: %s\r\n", now.UTC().Format(time.RFC1123Z))
	fmt.Fprintf(&b, "Message-ID: <%s@%s>\r\n", randomHex(16), host)
	b.WriteString("MIME-Version: 1.0\r\n")
	b.WriteString("Auto-Submitted: auto-generated\r\n")
	fmt.Fprintf(&b, "Content-Type: multipart/alternative; boundary=%q\r\n\r\n", boundary)
	writePart := func(ctype, body string) error {
		fmt.Fprintf(&b, "--%s\r\nContent-Type: %s; charset=utf-8\r\nContent-Transfer-Encoding: quoted-printable\r\n\r\n", boundary, ctype)
		w := quotedprintable.NewWriter(&b)
		if _, err := w.Write([]byte(body)); err != nil {
			return err
		}
		if err := w.Close(); err != nil {
			return err
		}
		b.WriteString("\r\n")
		return nil
	}
	if err := writePart("text/plain", m.Text); err != nil {
		return nil, err
	}
	if m.HTML != "" {
		if err := writePart("text/html", m.HTML); err != nil {
			return nil, err
		}
	}
	fmt.Fprintf(&b, "--%s--\r\n", boundary)
	return b.Bytes(), nil
}

func randomHex(n int) string {
	buf := make([]byte, n)
	_, _ = rand.Read(buf)
	return hex.EncodeToString(buf)
}

// devMailbox writes messages to disk (APP_ENV development/test only; enforced
// by config validation).
type devMailbox struct {
	dir  string
	from *mail.Address
}

func (d *devMailbox) Provider() string { return "dev_mailbox" }
func (d *devMailbox) Configured() bool { return true }

func (d *devMailbox) Send(_ context.Context, m Message) error {
	raw, err := Render(d.from, m, time.Now())
	if err != nil {
		return err
	}
	name := fmt.Sprintf("%s-%s.eml", time.Now().UTC().Format("20060102T150405.000000000"), randomHex(4))
	return os.WriteFile(filepath.Join(d.dir, name), raw, 0o600)
}

// smtpSender delivers via SMTP. Port 465 uses implicit TLS; other ports
// require STARTTLS (plaintext delivery is refused).
type smtpSender struct {
	cfg     config.EmailConfig
	from    *mail.Address
	breaker *breaker.Breaker
}

func (s *smtpSender) Provider() string { return "smtp" }
func (s *smtpSender) Configured() bool { return true }

// errRecipient marks a permanent refusal of one recipient (5xx at RCPT): a
// problem with that address, not with the SMTP server.
var errRecipient = errors.New("smtp recipient rejected")

// smtpFailure counts failures against the SMTP breaker, except refusals of
// a single recipient.
func smtpFailure(err error) bool {
	return breaker.DefaultIsFailure(err) && !errors.Is(err, errRecipient)
}

// Send delivers one message through the SMTP circuit breaker: while the
// server keeps failing, sends fail fast with a retryable error and the
// job queue backs off.
func (s *smtpSender) Send(ctx context.Context, m Message) error {
	return s.breaker.Do(ctx, func(ctx context.Context) error { return s.send(ctx, m) })
}

func (s *smtpSender) send(ctx context.Context, m Message) error {
	raw, err := Render(s.from, m, time.Now())
	if err != nil {
		return err
	}
	to, _ := mail.ParseAddress(m.To)
	addr := net.JoinHostPort(s.cfg.SMTPHost, strconv.Itoa(s.cfg.SMTPPort))
	deadline := time.Now().Add(30 * time.Second)
	if d, ok := ctx.Deadline(); ok && d.Before(deadline) {
		deadline = d
	}
	dialer := &net.Dialer{Timeout: 10 * time.Second}
	tlsCfg := &tls.Config{ServerName: s.cfg.SMTPHost, MinVersion: tls.VersionTLS12}
	var conn net.Conn
	if s.cfg.SMTPPort == 465 {
		td := &tls.Dialer{NetDialer: dialer, Config: tlsCfg}
		conn, err = td.DialContext(ctx, "tcp", addr)
	} else {
		conn, err = dialer.DialContext(ctx, "tcp", addr)
	}
	if err != nil {
		return fmt.Errorf("smtp dial: %w", err)
	}
	_ = conn.SetDeadline(deadline)
	c, err := smtp.NewClient(conn, s.cfg.SMTPHost)
	if err != nil {
		_ = conn.Close()
		return fmt.Errorf("smtp client: %w", err)
	}
	defer func() { _ = c.Close() }()
	if s.cfg.SMTPPort != 465 {
		if ok, _ := c.Extension("STARTTLS"); !ok {
			return errors.New("smtp server does not support STARTTLS; refusing plaintext delivery")
		}
		if err := c.StartTLS(tlsCfg); err != nil {
			return fmt.Errorf("smtp starttls: %w", err)
		}
	}
	if s.cfg.SMTPUsername != "" {
		if err := c.Auth(smtp.PlainAuth("", s.cfg.SMTPUsername, s.cfg.SMTPPassword, s.cfg.SMTPHost)); err != nil {
			return fmt.Errorf("smtp auth: %w", err)
		}
	}
	if err := c.Mail(s.from.Address); err != nil {
		return fmt.Errorf("smtp mail from: %w", err)
	}
	if err := c.Rcpt(to.Address); err != nil {
		var te *textproto.Error
		if errors.As(err, &te) && te.Code >= 500 && te.Code < 600 {
			return fmt.Errorf("%w: %w", errRecipient, err)
		}
		return fmt.Errorf("smtp rcpt: %w", err)
	}
	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("smtp data: %w", err)
	}
	if _, err := w.Write(raw); err != nil {
		return fmt.Errorf("smtp write: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("smtp close data: %w", err)
	}
	return c.Quit()
}
