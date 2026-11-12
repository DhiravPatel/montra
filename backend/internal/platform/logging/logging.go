// Package logging configures structured logging (log/slog) with
// privacy-preserving redaction. Attribute keys that may carry secrets or
// financial payloads are replaced with "[REDACTED]" regardless of the caller,
// so accidental logging of tokens, descriptions or receipt contents is
// neutralized centrally (spec §8, §13).
package logging

import (
	"context"
	"io"
	"log/slog"
	"os"
	"strings"
)

type ctxKey int

const (
	keyRequestID ctxKey = iota
	keyJobID
	keyUserID
)

// sensitiveKeys are attribute keys (lower-cased) that are always redacted.
var sensitiveKeys = map[string]struct{}{
	"password": {}, "new_password": {}, "current_password": {}, "token": {},
	"access_token": {}, "refresh_token": {}, "authorization": {}, "cookie": {},
	"set-cookie": {}, "secret": {}, "api_key": {}, "apikey": {}, "otp": {},
	"code": {}, "totp": {}, "recovery_code": {}, "description": {}, "notes": {},
	"note": {}, "merchant": {}, "merchant_name": {}, "receipt_text": {},
	"raw_row": {}, "row": {}, "body": {}, "payload": {}, "email": {},
	"account_number": {}, "iban": {}, "card_number": {}, "cvv": {}, "pin": {},
	"upi_pin": {}, "amount": {}, "amount_minor": {}, "balance": {},
	"content": {}, "prompt": {}, "completion": {}, "ip": {},
}

// IsSensitiveKey reports whether a log attribute key must be redacted.
func IsSensitiveKey(k string) bool {
	_, ok := sensitiveKeys[strings.ToLower(k)]
	return ok
}

// New builds the process logger.
func New(w io.Writer, level, format string) *slog.Logger {
	if w == nil {
		w = os.Stdout
	}
	opts := &slog.HandlerOptions{
		Level: parseLevel(level),
		ReplaceAttr: func(_ []string, a slog.Attr) slog.Attr {
			if IsSensitiveKey(a.Key) {
				return slog.String(a.Key, "[REDACTED]")
			}
			return a
		},
	}
	var h slog.Handler
	if format == "text" {
		h = slog.NewTextHandler(w, opts)
	} else {
		h = slog.NewJSONHandler(w, opts)
	}
	return slog.New(&contextHandler{Handler: h})
}

func parseLevel(s string) slog.Level {
	switch strings.ToLower(s) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

// contextHandler adds correlation identifiers from the context to every
// record.
type contextHandler struct {
	slog.Handler
}

func (h *contextHandler) Handle(ctx context.Context, r slog.Record) error {
	if v, ok := ctx.Value(keyRequestID).(string); ok && v != "" {
		r.AddAttrs(slog.String("request_id", v))
	}
	if v, ok := ctx.Value(keyJobID).(string); ok && v != "" {
		r.AddAttrs(slog.String("job_id", v))
	}
	if v, ok := ctx.Value(keyUserID).(string); ok && v != "" {
		r.AddAttrs(slog.String("user_id", v))
	}
	return h.Handler.Handle(ctx, r)
}

func (h *contextHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &contextHandler{Handler: h.Handler.WithAttrs(attrs)}
}

func (h *contextHandler) WithGroup(name string) slog.Handler {
	return &contextHandler{Handler: h.Handler.WithGroup(name)}
}

// WithRequestID stores the request correlation ID in the context.
func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, keyRequestID, id)
}

// RequestID returns the request correlation ID from the context, if any.
func RequestID(ctx context.Context) string {
	v, _ := ctx.Value(keyRequestID).(string)
	return v
}

// WithJobID stores the job correlation ID in the context.
func WithJobID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, keyJobID, id)
}

// WithUserID stores the authenticated user ID (an opaque UUID, not PII) for
// log correlation.
func WithUserID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, keyUserID, id)
}
