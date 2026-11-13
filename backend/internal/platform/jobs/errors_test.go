package jobs

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"montra/backend/internal/platform/breaker"
)

func TestErrorCodeAndRetryHints(t *testing.T) {
	open := &breaker.OpenError{Name: "smtp", RetryAfter: 42 * time.Second}
	cases := []struct {
		err   error
		code  string
		delay time.Duration
	}{
		{errors.New("x"), "error", 0},
		{WithCode("email_send_failed", errors.New("x")), "email_send_failed", 0},
		{Permanent(errors.New("x")), "permanent", 0},
		{fmt.Errorf("wrapped: %w", context.DeadlineExceeded), "timeout", 0},
		// An open breaker names the real cause even under a handler's code,
		// and asks for at least its remaining cool-down.
		{WithCode("email_send_failed", fmt.Errorf("send: %w", open)), breaker.ErrorCode, 42 * time.Second},
	}
	for _, c := range cases {
		if got := errorCode(c.err); got != c.code {
			t.Errorf("errorCode(%v) = %q, want %q", c.err, got, c.code)
		}
		if got := minRetryDelay(c.err); got != c.delay {
			t.Errorf("minRetryDelay(%v) = %s, want %s", c.err, got, c.delay)
		}
	}
	if IsPermanent(open) {
		t.Error("an open breaker must be retryable")
	}
}
