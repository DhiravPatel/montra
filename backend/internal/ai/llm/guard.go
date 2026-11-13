package llm

import (
	"context"
	"errors"
	"fmt"

	"montra/backend/internal/platform/breaker"
)

// Guarded runs a provider's calls through a circuit breaker (OPS-003).
// While the provider keeps failing, Generate fails fast with ErrUnavailable
// (PROVIDER_UNAVAILABLE for API callers; jobs retry with backoff) and every
// feature falls back to its deterministic path.
type Guarded struct {
	Provider
	Breaker *breaker.Breaker
}

// WithBreaker wraps p with a new breaker named "ai.<provider>" unless b is
// given.
func WithBreaker(p Provider, b *breaker.Breaker) Provider {
	if b == nil {
		b = breaker.New("ai."+p.Name(), breaker.Options{IsFailure: BreakerFailure})
	}
	return Guarded{Provider: p, Breaker: b}
}

// BreakerFailure counts only provider unavailability (network errors,
// timeouts, 5xx, auth failures) against the breaker. Refusals, truncation,
// rejected requests and rate limiting are answers from a healthy provider.
func BreakerFailure(err error) bool {
	return breaker.DefaultIsFailure(err) && errors.Is(err, ErrUnavailable)
}

// Generate implements Provider.
func (g Guarded) Generate(ctx context.Context, req Request, exec ToolExecutor) (*Result, error) {
	var res *Result
	err := g.Breaker.Do(ctx, func(ctx context.Context) error {
		var err error
		res, err = g.Provider.Generate(ctx, req, exec)
		return err
	})
	if breaker.IsOpen(err) {
		return nil, fmt.Errorf("%w: %w", ErrUnavailable, err)
	}
	return res, err
}
