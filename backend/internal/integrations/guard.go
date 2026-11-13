package integrations

import (
	"context"
	"errors"

	"montra/backend/internal/platform/breaker"
)

// guarded runs an adapter's outbound HTTP calls (token exchange, refresh,
// revoke, fetch) through the provider's circuit breaker (OPS-003). While a
// provider keeps failing, calls fail fast: sync jobs are retried with
// backoff, and the OAuth callback answers PROVIDER_UNAVAILABLE.
type guarded struct {
	Adapter
	b *breaker.Breaker
}

// adapterFailure counts provider failures; an expired consent is an answer
// about one connection, not the provider's health.
func adapterFailure(err error) bool {
	return breaker.DefaultIsFailure(err) && !errors.Is(err, ErrConsentExpired)
}

func guard(a Adapter) Adapter {
	if g, ok := a.(guarded); ok {
		return g
	}
	return guarded{Adapter: a, b: breaker.New("integrations."+a.Info().ID, breaker.Options{IsFailure: adapterFailure})}
}

func (g guarded) Exchange(ctx context.Context, code, redirectURI string) (*Token, error) {
	return breaker.Call(ctx, g.b, func(ctx context.Context) (*Token, error) { return g.Adapter.Exchange(ctx, code, redirectURI) })
}

func (g guarded) Refresh(ctx context.Context, t *Token) (*Token, error) {
	return breaker.Call(ctx, g.b, func(ctx context.Context) (*Token, error) { return g.Adapter.Refresh(ctx, t) })
}

func (g guarded) Revoke(ctx context.Context, t *Token) error {
	return g.b.Do(ctx, func(ctx context.Context) error { return g.Adapter.Revoke(ctx, t) })
}

func (g guarded) Fetch(ctx context.Context, t *Token, cursor string) (*Batch, error) {
	return breaker.Call(ctx, g.b, func(ctx context.Context) (*Batch, error) { return g.Adapter.Fetch(ctx, t, cursor) })
}
