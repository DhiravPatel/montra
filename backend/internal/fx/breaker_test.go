package fx

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"montra/backend/internal/platform/breaker"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/jobs"
)

// The ECB fetch runs through a circuit breaker: after consecutive failures
// refreshes fail fast (no request) with a retryable error that asks the job
// queue to wait out the cool-down; after the cool-down one probe goes
// through and a healthy answer closes the breaker.
func TestRefreshECBCircuitBreaker(t *testing.T) {
	var hits atomic.Int32
	var healthy atomic.Bool
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		hits.Add(1)
		if !healthy.Load() {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("not xml")) // reachable again; the payload is a separate, permanent problem
	}))
	defer srv.Close()
	now := time.Date(2026, 11, 13, 6, 0, 0, 0, time.UTC)
	clock := func() time.Time { return now }
	s := &Service{Cfg: config.FXConfig{Provider: "ecb", ECBURL: srv.URL},
		Breaker: breaker.New("fx.ecb.test", breaker.Options{Threshold: 3, Cooldown: time.Minute, Now: clock})}
	ctx := context.Background()

	for i := 1; i <= 3; i++ {
		_, err := s.RefreshECB(ctx)
		if err == nil || breaker.IsOpen(err) || jobs.IsPermanent(err) {
			t.Fatalf("failure %d: %v", i, err)
		}
	}
	if s.Breaker.State() != breaker.Open || hits.Load() != 3 {
		t.Fatalf("after 3 failures: state %s, %d requests", s.Breaker.State(), hits.Load())
	}

	// Open: no request, retryable, and the job waits for the cool-down.
	_, err := s.RefreshECB(ctx)
	var oe *breaker.OpenError
	if !errors.As(err, &oe) || jobs.IsPermanent(err) || hits.Load() != 3 {
		t.Fatalf("open breaker: %v after %d requests", err, hits.Load())
	}
	if oe.MinRetryDelay() != time.Minute || oe.JobErrorCode() != "provider_circuit_open" {
		t.Fatalf("open error = %+v", oe)
	}

	// After the cool-down a probe reaches the (recovered) provider and the
	// breaker closes; the bad payload is reported as a permanent failure.
	now = now.Add(time.Minute)
	healthy.Store(true)
	_, err = s.RefreshECB(ctx)
	if !jobs.IsPermanent(err) || hits.Load() != 4 || s.Breaker.State() != breaker.Closed {
		t.Fatalf("probe: %v, %d requests, state %s", err, hits.Load(), s.Breaker.State())
	}
}
