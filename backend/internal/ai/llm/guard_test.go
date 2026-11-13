package llm

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"montra/backend/internal/platform/breaker"
)

type scripted struct {
	calls int
	errs  []error
}

func (s *scripted) Name() string     { return "scripted" }
func (s *scripted) Model() string    { return "m" }
func (s *scripted) Configured() bool { return true }
func (s *scripted) Generate(context.Context, Request, ToolExecutor) (*Result, error) {
	err := s.errs[min(s.calls, len(s.errs)-1)]
	s.calls++
	return &Result{Text: "ok"}, err
}

func TestGuardedProviderFailsFastWhenOpen(t *testing.T) {
	inner := &scripted{errs: []error{
		ErrRefused, ErrRateLimited, fmt.Errorf("%w (status 400)", ErrRejected), // healthy answers
		fmt.Errorf("%w (status 503)", ErrUnavailable), fmt.Errorf("%w (status 503)", ErrUnavailable),
	}}
	p := WithBreaker(inner, breaker.New("ai.test", breaker.Options{Threshold: 2, Cooldown: time.Hour, IsFailure: BreakerFailure}))
	if p.Name() != "scripted" || !p.Configured() {
		t.Fatal("wrapper must keep the provider's identity")
	}
	for i := 0; i < 5; i++ {
		if _, err := p.Generate(context.Background(), Request{}, nil); err == nil {
			t.Fatalf("call %d succeeded", i)
		}
	}
	if inner.calls != 5 {
		t.Fatalf("refusals and rejections must not open the breaker: %d calls", inner.calls)
	}
	res, err := p.Generate(context.Background(), Request{}, nil)
	if !errors.Is(err, ErrUnavailable) || !breaker.IsOpen(err) || res != nil || inner.calls != 5 {
		t.Fatalf("open: %v %v after %d calls", res, err, inner.calls)
	}
}
