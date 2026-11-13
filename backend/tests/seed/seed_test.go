// Package seed_test runs the demo seed against the integration database in
// its own test binary, so its demo users never affect the API suites.
package seed_test

import (
	"context"
	"net/http"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/seed"
	"montra/backend/internal/testutil/apitest"
)

func count(t *testing.T, s *apitest.Server, q string, args ...any) int {
	t.Helper()
	var n int
	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error { return tx.QueryRow(ctx, q, args...).Scan(&n) }); err != nil {
		t.Fatal(err)
	}
	return n
}

// ARCH-010/ARCH-014: the seed creates the demo data through the services,
// a second run adds nothing, other people's data is untouched, and a demo
// address that belongs to someone else (another password) is left alone.
func TestSeedIsDeterministicAndIdempotent(t *testing.T) {
	s := apitest.New(t, map[string]string{"AUTH_REQUIRE_EMAIL_VERIFIED": "false"})
	// Someone else's data exists before the seed and must not change.
	other, _ := s.Login(t, s.Register(t, "bystander"))
	other.Do(t, http.MethodPost, "/accounts", map[string]any{"name": "Mine", "account_type": "bank", "currency": "INR", "opening_balance": "10"},
		"Idempotency-Key", "bystander-account-1").Expect(t, http.StatusCreated)
	before := count(t, s, `select count(*) from transactions t join users u on u.id = t.user_id where u.email not like 'demo.%@example.com'`)

	sd := &seed.Seeder{App: s.Svcs, Worker: s.WorkerSvcs, Env: "test"}
	first, err := sd.Run(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if first.Created["user"] != 3 || first.Created["transaction"] < 40 || first.Created["group expense"] != 3 || first.Created["post"] != 1 {
		t.Fatalf("first run created %v", first.Created)
	}
	demo := func(q string) int {
		return count(t, s, q+` and u.email = 'demo.asha@example.com'`)
	}
	txs := demo(`select count(*) from transactions t join users u on u.id = t.user_id where true`)
	if demo(`select count(*) from budget_alerts a join budgets b on b.id = a.budget_id join users u on u.id = b.owner_user_id where true`) == 0 {
		t.Fatal("the demo budget has no alert")
	}
	for name, q := range map[string]string{
		"bills":         `select count(*) from bills x join users u on u.id = x.user_id where true`,
		"subscriptions": `select count(*) from subscriptions x join users u on u.id = x.user_id where true`,
		"goals":         `select count(*) from goals x join users u on u.id = x.owner_user_id where true`,
	} {
		if demo(q) < 1 {
			t.Fatalf("no demo %s", name)
		}
	}
	if n := count(t, s, `select count(*) from settlements where status = 'confirmed'`); n != 1 {
		t.Fatalf("confirmed settlements = %d", n)
	}
	if n := count(t, s, `select count(*) from group_members m join groups g on g.id = m.group_id where g.name = 'Demo Flat' and m.status = 'active'`); n != 3 {
		t.Fatalf("group members = %d", n)
	}

	// The demo user's analytics see the data, payment methods included.
	login := s.NewClient("android")
	r := login.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": "demo.asha@example.com", "password": seed.DemoPassword}).Expect(t, http.StatusOK)
	login.Bearer = r.Data()["access_token"].(string)
	pm := login.Do(t, http.MethodGet, "/analytics/payment-methods?range=last_90_days", nil).Expect(t, http.StatusOK)
	if !strings.Contains(string(pm.Raw), `"key":"unspecified"`) || !strings.Contains(string(pm.Raw), "Demo Rewards Card") {
		t.Fatalf("payment-method analytics of the demo user: %s", pm.Raw)
	}

	// Second run: nothing new.
	second, err := sd.Run(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if second.CreatedTotal() != 0 {
		t.Fatalf("second run created %v", second.Created)
	}
	if n := demo(`select count(*) from transactions t join users u on u.id = t.user_id where true`); n != txs {
		t.Fatalf("transactions after second run = %d, want %d", n, txs)
	}
	if n := count(t, s, `select count(*) from transactions t join users u on u.id = t.user_id where u.email not like 'demo.%@example.com'`); n != before {
		t.Fatalf("other people's transactions changed: %d → %d", before, n)
	}

	// A demo address with another password is never touched.
	hash, err := crypto.HashPassword("Somebody-Elses-Pass-1", crypto.Argon2Params{Memory: 8 * 1024, Time: 1, Threads: 1, KeyLen: 32, SaltLen: 16})
	if err != nil {
		t.Fatal(err)
	}
	s.Env.ExecWorker(t, `update user_credentials set password_hash = $1 where user_id = (select id from users where email = 'demo.meera@example.com')`, hash)
	if _, err := sd.Run(context.Background()); err == nil || !strings.Contains(err.Error(), "left unchanged") {
		t.Fatalf("seed with a foreign demo account: %v", err)
	}
}
