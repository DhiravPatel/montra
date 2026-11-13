package seed

import (
	"context"
	"regexp"
	"strings"
	"testing"
)

func TestCheckEnvAllowsOnlyDevelopmentAndTest(t *testing.T) {
	for _, env := range []string{"development", "test"} {
		if err := CheckEnv(env); err != nil {
			t.Errorf("%s: %v", env, err)
		}
	}
	for _, env := range []string{"", "staging", "production", "Development", "prod"} {
		if err := CheckEnv(env); err == nil || !strings.Contains(err.Error(), "refusing to seed") {
			t.Errorf("%q was not refused: %v", env, err)
		}
	}
	// Run refuses before touching any service.
	if _, err := (&Seeder{Env: "production"}).Run(context.Background()); err == nil {
		t.Fatal("Run accepted production")
	}
}

func TestDemoDataIsFixedAndUnique(t *testing.T) {
	for name, p := range map[string]plan{"asha": ashaPlan, "ravi": raviPlan, "meera": meeraPlan} {
		seen := map[string]bool{}
		for _, d := range append(append(txDescs(p.Txs), refundDescs(p.Refunds)...), transferDescs(p.Transfers)...) {
			if seen[d] {
				t.Errorf("%s: description %q repeats (it identifies the record on later runs)", name, d)
			}
			seen[d] = true
		}
		for _, tx := range p.Txs {
			if tx.Offset < 0 || tx.Offset > 89 {
				t.Errorf("%s: %q is outside the last 90 days", name, tx.Desc)
			}
		}
	}
	if len(ashaPlan.Txs) < 40 {
		t.Fatalf("expected a realistic history, got %d transactions", len(ashaPlan.Txs))
	}
	k := idemKey("asha", "tx", "Refund: online order 2")
	if k != idemKey("asha", "tx", "Refund: online order 2") || k == idemKey("ravi", "tx", "Refund: online order 2") ||
		!regexp.MustCompile(`^[A-Za-z0-9_\-:.]{8,128}$`).MatchString(k) {
		t.Fatalf("idempotency key %q must be fixed, per person and valid", k)
	}
	for _, p := range []Person{Asha, Ravi, Meera} {
		if !strings.HasPrefix(p.Email, "demo.") || !strings.HasSuffix(p.Email, "@example.com") {
			t.Errorf("demo email %s must be demo.*@example.com", p.Email)
		}
	}
}

func txDescs(l []txSpec) []string {
	out := make([]string, len(l))
	for i, x := range l {
		out[i] = x.Desc
	}
	return out
}

func refundDescs(l []refundSpec) []string {
	out := make([]string, len(l))
	for i, x := range l {
		out[i] = x.Desc
	}
	return out
}

func transferDescs(l []transferSpec) []string {
	out := make([]string, len(l))
	for i, x := range l {
		out[i] = x.Desc
	}
	return out
}
