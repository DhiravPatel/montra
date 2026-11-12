package ratelimit

import (
	"testing"
	"time"
)

// A limiter's override replaces the named policy for that limiter only.
func TestOverridesApplyPerLimiter(t *testing.T) {
	strict, relaxed := New(), New(Policy{Name: Auth.Name, Every: time.Millisecond, Burst: 100})
	p, _ := strict.policy(Auth.Name)
	if p != Auth {
		t.Fatalf("default limiter auth policy = %+v", p)
	}
	allowed := 0
	for i := 0; i < 50; i++ {
		if ok, _ := strict.Allow(p, "ip:1"); ok {
			allowed++
		}
	}
	if allowed != Auth.Burst {
		t.Fatalf("strict limiter allowed %d, want %d", allowed, Auth.Burst)
	}
	rp, _ := relaxed.policy(Auth.Name)
	for i := 0; i < 50; i++ {
		if ok, _ := relaxed.Allow(rp, "ip:1"); !ok {
			t.Fatalf("relaxed limiter refused request %d", i)
		}
	}
	if d, _ := relaxed.policy(Default.Name); d != Default {
		t.Fatalf("override leaked into another policy: %+v", d)
	}
}
