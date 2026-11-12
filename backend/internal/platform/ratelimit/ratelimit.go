// Package ratelimit provides per-key token-bucket limiting for abuse and
// cost control (fair use, never paid tiers). Buckets are per process;
// durable brute-force defenses (login throttling) live in PostgreSQL.
package ratelimit

import (
	"net/http"
	"sync"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"golang.org/x/time/rate"
)

// Policy defines a refill rate and burst.
type Policy struct {
	Name  string
	Every time.Duration // one token per Every
	Burst int
}

// Policies used by operations via Operation.Metadata["rate_policy"].
var (
	Default = Policy{Name: "default", Every: 100 * time.Millisecond, Burst: 60} // ~600/min
	Auth    = Policy{Name: "auth", Every: 6 * time.Second, Burst: 10}           // ~10/min
	Write   = Policy{Name: "write", Every: 250 * time.Millisecond, Burst: 40}   // ~240/min
	Upload  = Policy{Name: "upload", Every: 3 * time.Second, Burst: 10}         // ~20/min
	AI      = Policy{Name: "ai", Every: 3 * time.Second, Burst: 10}             // ~20/min
	Export  = Policy{Name: "export", Every: 30 * time.Second, Burst: 5}         // ~2/min
	Social  = Policy{Name: "social", Every: 2 * time.Second, Burst: 15}         // ~30/min
)

var byName = map[string]Policy{}

func init() {
	for _, p := range []Policy{Default, Auth, Write, Upload, AI, Export, Social} {
		byName[p.Name] = p
	}
}

type entry struct {
	lim  *rate.Limiter
	seen time.Time
}

// Limiter holds buckets keyed by policy+subject.
type Limiter struct {
	mu      sync.Mutex
	buckets map[string]*entry
	now     func() time.Time
}

// New creates a limiter and starts janitor cleanup of idle buckets.
func New() *Limiter {
	l := &Limiter{buckets: map[string]*entry{}, now: time.Now}
	go l.janitor()
	return l
}

func (l *Limiter) janitor() {
	t := time.NewTicker(5 * time.Minute)
	defer t.Stop()
	for range t.C {
		cutoff := l.now().Add(-15 * time.Minute)
		l.mu.Lock()
		for k, e := range l.buckets {
			if e.seen.Before(cutoff) {
				delete(l.buckets, k)
			}
		}
		l.mu.Unlock()
	}
}

// Allow consumes a token; it returns the suggested retry delay when denied.
func (l *Limiter) Allow(p Policy, subject string) (bool, time.Duration) {
	key := p.Name + "|" + subject
	l.mu.Lock()
	e, ok := l.buckets[key]
	if !ok {
		e = &entry{lim: rate.NewLimiter(rate.Every(p.Every), p.Burst)}
		l.buckets[key] = e
	}
	e.seen = l.now()
	l.mu.Unlock()
	r := e.lim.Reserve()
	if !r.OK() {
		return false, p.Every
	}
	if d := r.Delay(); d > 0 {
		r.Cancel()
		return false, d
	}
	return true, 0
}

// SubjectFunc returns the limiter subject for a request (user ID when
// authenticated, otherwise client IP).
type SubjectFunc func(ctx huma.Context) string

// Middleware enforces the operation's rate policy.
func Middleware(api huma.API, l *Limiter, subject SubjectFunc, onDenied func(ctx huma.Context, retry time.Duration)) func(huma.Context, func(huma.Context)) {
	return func(ctx huma.Context, next func(huma.Context)) {
		p := Default
		if op := ctx.Operation(); op != nil && op.Metadata != nil {
			if name, ok := op.Metadata["rate_policy"].(string); ok {
				if pp, ok := byName[name]; ok {
					p = pp
				}
			}
		}
		if ok, retry := l.Allow(p, subject(ctx)); !ok {
			onDenied(ctx, retry)
			return
		}
		next(ctx)
	}
}

// StatusTooManyRequests is re-exported for callers.
const StatusTooManyRequests = http.StatusTooManyRequests
