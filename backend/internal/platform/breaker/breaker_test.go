package breaker

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type clock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *clock) now() time.Time { c.mu.Lock(); defer c.mu.Unlock(); return c.t }
func (c *clock) advance(d time.Duration) {
	c.mu.Lock()
	c.t = c.t.Add(d)
	c.mu.Unlock()
}

type recorder struct {
	mu          sync.Mutex
	transitions []string
	rejected    int
}

func (r *recorder) BreakerStateChanged(name, from, to string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if from != "" {
		r.transitions = append(r.transitions, name+":"+from+"->"+to)
	}
}

func (r *recorder) BreakerRejected(string) {
	r.mu.Lock()
	r.rejected++
	r.mu.Unlock()
}

var errDown = errors.New("provider down")

func fail(context.Context) error { return errDown }
func ok(context.Context) error   { return nil }

func newTest(t *testing.T, threshold int, cooldown time.Duration) (*Breaker, *clock, *recorder) {
	t.Helper()
	c := &clock{t: time.Date(2026, 11, 13, 9, 0, 0, 0, time.UTC)}
	r := &recorder{}
	SetObserver(r)
	t.Cleanup(func() { SetObserver(nil) })
	return New("test", Options{Threshold: threshold, Cooldown: cooldown, Now: c.now}), c, r
}

func TestOpensAfterConsecutiveFailures(t *testing.T) {
	b, _, r := newTest(t, 3, time.Minute)
	ctx := context.Background()
	// Failures separated by a success do not add up.
	_ = b.Do(ctx, fail)
	_ = b.Do(ctx, fail)
	_ = b.Do(ctx, ok)
	_ = b.Do(ctx, fail)
	_ = b.Do(ctx, fail)
	if b.State() != Closed {
		t.Fatalf("state after interrupted failures = %s", b.State())
	}
	if err := b.Do(ctx, fail); !errors.Is(err, errDown) {
		t.Fatalf("third consecutive failure returned %v", err)
	}
	if b.State() != Open {
		t.Fatalf("state = %s, want open", b.State())
	}
	// Open: fail fast without calling the provider.
	var calls atomic.Int32
	err := b.Do(ctx, func(context.Context) error { calls.Add(1); return nil })
	var oe *OpenError
	if !errors.As(err, &oe) || !IsOpen(err) || calls.Load() != 0 {
		t.Fatalf("open breaker returned %v after %d calls", err, calls.Load())
	}
	if oe.Name != "test" || oe.RetryAfter != time.Minute || oe.MinRetryDelay() != time.Minute || oe.JobErrorCode() != ErrorCode {
		t.Fatalf("open error = %+v", oe)
	}
	if r.rejected != 1 || len(r.transitions) != 1 || r.transitions[0] != "test:closed->open" {
		t.Fatalf("observer saw %v transitions and %d rejections", r.transitions, r.rejected)
	}
}

func TestHalfOpenProbeClosesOrReopens(t *testing.T) {
	b, c, r := newTest(t, 1, 30*time.Second)
	ctx := context.Background()
	_ = b.Do(ctx, fail)
	c.advance(10 * time.Second)
	var oe *OpenError
	if err := b.Do(ctx, ok); !errors.As(err, &oe) || oe.RetryAfter != 20*time.Second {
		t.Fatalf("during cool-down: %v", err)
	}
	c.advance(20 * time.Second)
	if b.State() != HalfOpen {
		t.Fatalf("after cool-down state = %s", b.State())
	}
	// A failed probe reopens for a full cool-down.
	if err := b.Do(ctx, fail); !errors.Is(err, errDown) {
		t.Fatalf("probe returned %v", err)
	}
	if err := b.Do(ctx, ok); !errors.As(err, &oe) || oe.RetryAfter != 30*time.Second {
		t.Fatalf("after failed probe: %v", err)
	}
	c.advance(30 * time.Second)
	if err := b.Do(ctx, ok); err != nil {
		t.Fatalf("successful probe returned %v", err)
	}
	if b.State() != Closed {
		t.Fatalf("after successful probe state = %s", b.State())
	}
	want := []string{"test:closed->open", "test:open->half_open", "test:half_open->open", "test:open->half_open", "test:half_open->closed"}
	if len(r.transitions) != len(want) {
		t.Fatalf("transitions = %v, want %v", r.transitions, want)
	}
	for i := range want {
		if r.transitions[i] != want[i] {
			t.Fatalf("transitions = %v, want %v", r.transitions, want)
		}
	}
}

// Only one probe runs at a time; concurrent calls fail fast meanwhile.
func TestSingleProbeInHalfOpen(t *testing.T) {
	b, c, _ := newTest(t, 1, time.Second)
	ctx := context.Background()
	_ = b.Do(ctx, fail)
	c.advance(time.Second)
	started, release := make(chan struct{}), make(chan struct{})
	done := make(chan error, 1)
	go func() {
		done <- b.Do(ctx, func(context.Context) error { close(started); <-release; return nil })
	}()
	<-started
	var oe *OpenError
	if err := b.Do(ctx, ok); !errors.As(err, &oe) || oe.RetryAfter != 0 {
		t.Fatalf("second call during probe: %v", err)
	}
	close(release)
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	if err := b.Do(ctx, ok); err != nil || b.State() != Closed {
		t.Fatalf("after probe: %v, %s", err, b.State())
	}
}

// Request-specific errors and the caller's cancellation say nothing about
// the provider's health.
func TestIsFailureClassification(t *testing.T) {
	errRejected := errors.New("bad recipient")
	c := &clock{t: time.Now()}
	b := New("classify", Options{Threshold: 2, Cooldown: time.Minute, Now: c.now,
		IsFailure: func(err error) bool { return DefaultIsFailure(err) && !errors.Is(err, errRejected) }})
	ctx := context.Background()
	for i := 0; i < 5; i++ {
		_ = b.Do(ctx, func(context.Context) error { return errRejected })
		_ = b.Do(ctx, func(context.Context) error { return context.Canceled })
	}
	if b.State() != Closed {
		t.Fatalf("non-failures opened the breaker: %s", b.State())
	}
	_ = b.Do(ctx, fail)
	_ = b.Do(ctx, fail)
	if b.State() != Open {
		t.Fatal("failures did not open the breaker")
	}
	// A cancelled probe frees the slot without closing or reopening.
	c.advance(time.Minute)
	_ = b.Do(ctx, func(context.Context) error { return context.Canceled })
	if b.State() != HalfOpen {
		t.Fatalf("after cancelled probe state = %s", b.State())
	}
	// A rejection still proves the provider answers.
	_ = b.Do(ctx, func(context.Context) error { return errRejected })
	if b.State() != Closed {
		t.Fatalf("after answered probe state = %s", b.State())
	}
}

func TestPanicCountsAsFailure(t *testing.T) {
	b, _, _ := newTest(t, 1, time.Minute)
	func() {
		defer func() { _ = recover() }()
		_ = b.Do(context.Background(), func(context.Context) error { panic("boom") })
	}()
	if b.State() != Open {
		t.Fatalf("state after panic = %s", b.State())
	}
}

func TestCallReturnsValue(t *testing.T) {
	b, _, _ := newTest(t, 1, time.Minute)
	v, err := Call(context.Background(), b, func(context.Context) (int, error) { return 42, nil })
	if err != nil || v != 42 {
		t.Fatalf("Call = %d, %v", v, err)
	}
	_, _ = Call(context.Background(), b, func(context.Context) (int, error) { return 0, errDown })
	if v, err := Call(context.Background(), b, func(context.Context) (int, error) { return 7, nil }); !IsOpen(err) || v != 0 {
		t.Fatalf("open Call = %d, %v", v, err)
	}
}

func TestNamedIsSharedAndResettable(t *testing.T) {
	a := Named("shared-test", Options{Threshold: 1})
	b := Named("shared-test", Options{Threshold: 99})
	if a != b {
		t.Fatal("Named returned different breakers for one name")
	}
	_ = a.Do(context.Background(), fail)
	if b.State() != Open {
		t.Fatal("state is not shared")
	}
	b.Reset()
	if a.State() != Closed {
		t.Fatal("Reset did not close the breaker")
	}
	if Closed.String() != "closed" || HalfOpen.String() != "half_open" || Open.String() != "open" {
		t.Fatal("state labels changed")
	}
}

func TestDefaults(t *testing.T) {
	b := New("defaults", Options{})
	for i := 0; i < DefaultThreshold-1; i++ {
		_ = b.Do(context.Background(), fail)
	}
	if b.State() != Closed {
		t.Fatal("opened before the default threshold")
	}
	_ = b.Do(context.Background(), fail)
	var oe *OpenError
	if err := b.Do(context.Background(), ok); !errors.As(err, &oe) || oe.RetryAfter <= DefaultCooldown-time.Second {
		t.Fatalf("default cool-down not applied: %v", err)
	}
}
