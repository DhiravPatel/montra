// Package breaker is a small circuit breaker for outbound provider calls
// (OPS-003): SMTP, web push and FCM, the FX rate fetch, object storage, the
// AI provider and integration adapters.
//
// A breaker is closed while calls succeed. After Threshold consecutive
// failures it opens: calls fail fast with an *OpenError (no network call)
// until Cooldown has passed. It then lets one probe through (half-open):
// success closes it, failure opens it for another cool-down.
//
// The open error is retryable: background jobs that receive it are retried
// with backoff, and the job queue waits at least until the cool-down ends
// (OpenError.MinRetryDelay). Its job error code is "provider_circuit_open".
//
// Breakers are named per provider ("smtp", "fx.ecb", "webpush:<host>").
// Services create theirs once per process with New; Named shares one
// breaker per name across the process (push services, keyed by host).
// Names appear in metric labels, so they never contain user data.
package breaker

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

// State is a breaker state.
type State int

// Breaker states.
const (
	Closed State = iota
	HalfOpen
	Open
)

// String returns the state's metric label.
func (s State) String() string {
	switch s {
	case Open:
		return "open"
	case HalfOpen:
		return "half_open"
	default:
		return "closed"
	}
}

// Defaults for breakers that do not set their own options.
const (
	DefaultThreshold = 5
	DefaultCooldown  = 30 * time.Second
)

// ErrOpen is matched (errors.Is) by every *OpenError.
var ErrOpen = errors.New("circuit breaker open")

// ErrorCode is the job error code recorded for calls refused by an open
// breaker.
const ErrorCode = "provider_circuit_open"

// OpenError is returned without calling the provider while a breaker is
// open (or while its single half-open probe is in flight).
type OpenError struct {
	Name       string
	RetryAfter time.Duration // time left in the cool-down (0 while probing)
}

func (e *OpenError) Error() string {
	return fmt.Sprintf("%s: circuit breaker open (retry in %s)", e.Name, e.RetryAfter.Round(time.Second))
}

// Is makes errors.Is(err, ErrOpen) true.
func (e *OpenError) Is(target error) bool { return target == ErrOpen }

// MinRetryDelay is the earliest a retry can succeed; the job queue never
// retries sooner.
func (e *OpenError) MinRetryDelay() time.Duration { return e.RetryAfter }

// JobErrorCode is the safe code stored on a job that failed fast.
func (e *OpenError) JobErrorCode() string { return ErrorCode }

// IsOpen reports whether err (or an error it wraps) is an open-breaker
// refusal.
func IsOpen(err error) bool { return errors.Is(err, ErrOpen) }

// Observer receives state changes and refusals (metrics). Labels are the
// breaker name and state names only.
type Observer interface {
	BreakerStateChanged(name, from, to string)
	BreakerRejected(name string)
}

var (
	obsMu    sync.RWMutex
	observer Observer
)

// SetObserver installs the process-wide observer (nil removes it).
func SetObserver(o Observer) {
	obsMu.Lock()
	observer = o
	obsMu.Unlock()
	// Publish the current state of breakers that already exist.
	if o != nil {
		for _, b := range all() {
			o.BreakerStateChanged(b.name, "", b.State().String())
		}
	}
}

func currentObserver() Observer {
	obsMu.RLock()
	defer obsMu.RUnlock()
	return observer
}

// Options configure a breaker.
type Options struct {
	// Threshold is the number of consecutive failures that opens the
	// breaker (DefaultThreshold when 0).
	Threshold int
	// Cooldown is how long the breaker stays open before a probe
	// (DefaultCooldown when 0).
	Cooldown time.Duration
	// IsFailure decides whether an error counts against the provider.
	// The default counts every error except context cancellation by the
	// caller. Use it to ignore per-request rejections (a bad recipient, a
	// 4xx) that say nothing about the provider's health.
	IsFailure func(error) bool
	// Now is the clock (tests).
	Now func() time.Time
}

// Breaker is safe for concurrent use.
type Breaker struct {
	name string
	opts Options

	mu       sync.Mutex
	state    State
	failures int
	openedAt time.Time
	probing  bool
}

// New returns a closed breaker.
func New(name string, o Options) *Breaker {
	if o.Threshold <= 0 {
		o.Threshold = DefaultThreshold
	}
	if o.Cooldown <= 0 {
		o.Cooldown = DefaultCooldown
	}
	if o.IsFailure == nil {
		o.IsFailure = DefaultIsFailure
	}
	if o.Now == nil {
		o.Now = time.Now
	}
	if obs := currentObserver(); obs != nil {
		obs.BreakerStateChanged(name, "", Closed.String())
	}
	return &Breaker{name: name, opts: o}
}

// DefaultIsFailure counts every error except the caller's own
// cancellation.
func DefaultIsFailure(err error) bool {
	return err != nil && !errors.Is(err, context.Canceled)
}

// Name returns the breaker's name.
func (b *Breaker) Name() string { return b.name }

// State returns the current state; an open breaker whose cool-down has
// passed reports half-open (the next call is the probe).
func (b *Breaker) State() State {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.state == Open && !b.opts.Now().Before(b.openedAt.Add(b.opts.Cooldown)) {
		return HalfOpen
	}
	return b.state
}

// Do runs fn unless the breaker is open, and records its outcome. A
// refused call returns an *OpenError without running fn.
func (b *Breaker) Do(ctx context.Context, fn func(context.Context) error) (err error) {
	if err := b.allow(); err != nil {
		return err
	}
	finished := false
	defer func() {
		if !finished { // fn panicked: count it and release the probe slot
			b.record(errPanicked)
		}
	}()
	err = fn(ctx)
	finished = true
	b.record(err)
	return err
}

var errPanicked = errors.New("provider call panicked")

// Call is Do for functions that return a value.
func Call[T any](ctx context.Context, b *Breaker, fn func(context.Context) (T, error)) (T, error) {
	var out T
	err := b.Do(ctx, func(ctx context.Context) error {
		var err error
		out, err = fn(ctx)
		return err
	})
	return out, err
}

// allow admits a call or returns the refusal.
func (b *Breaker) allow() error {
	b.mu.Lock()
	var change [2]State
	changed := false
	switch b.state {
	case Open:
		left := b.openedAt.Add(b.opts.Cooldown).Sub(b.opts.Now())
		if left > 0 {
			b.mu.Unlock()
			b.rejected()
			return &OpenError{Name: b.name, RetryAfter: left}
		}
		change, changed = [2]State{Open, HalfOpen}, true
		b.state, b.probing = HalfOpen, true
	case HalfOpen:
		if b.probing {
			b.mu.Unlock()
			b.rejected()
			return &OpenError{Name: b.name}
		}
		b.probing = true
	}
	b.mu.Unlock()
	if changed {
		b.notify(change[0], change[1])
	}
	return nil
}

// record applies a call's outcome.
func (b *Breaker) record(err error) {
	failed := err != nil && b.opts.IsFailure(err)
	b.mu.Lock()
	from := b.state
	switch {
	case b.state == HalfOpen && !failed && err != nil && errors.Is(err, context.Canceled):
		// The caller gave up: nothing was learned, so another call may probe.
		b.probing = false
	case b.state == HalfOpen && failed:
		b.state, b.openedAt, b.probing = Open, b.opts.Now(), false
	case b.state == HalfOpen:
		// A non-failure (success or a request-specific rejection) shows the
		// provider answers again.
		b.state, b.failures, b.probing = Closed, 0, false
	case failed:
		b.failures++
		if b.failures >= b.opts.Threshold {
			b.state, b.openedAt = Open, b.opts.Now()
		}
	default:
		b.failures = 0
	}
	to := b.state
	b.mu.Unlock()
	if from != to {
		b.notify(from, to)
	}
}

// Reset closes the breaker (tests and operator tooling).
func (b *Breaker) Reset() {
	b.mu.Lock()
	from := b.state
	b.state, b.failures, b.probing = Closed, 0, false
	b.mu.Unlock()
	if from != Closed {
		b.notify(from, Closed)
	}
}

func (b *Breaker) notify(from, to State) {
	if o := currentObserver(); o != nil {
		o.BreakerStateChanged(b.name, from.String(), to.String())
	}
}

func (b *Breaker) rejected() {
	if o := currentObserver(); o != nil {
		o.BreakerRejected(b.name)
	}
}

var (
	regMu    sync.Mutex
	registry = map[string]*Breaker{}
)

// Named returns the process-wide breaker for a provider, creating it with
// o the first time (later calls ignore o). Every caller of the same
// provider shares its state.
func Named(name string, o Options) *Breaker {
	regMu.Lock()
	b, ok := registry[name]
	if !ok {
		b = New(name, o)
		registry[name] = b
	}
	regMu.Unlock()
	return b
}

func all() []*Breaker {
	regMu.Lock()
	defer regMu.Unlock()
	out := make([]*Breaker, 0, len(registry))
	for _, b := range registry {
		out = append(out, b)
	}
	return out
}
