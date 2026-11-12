// Package dbtest provides integration-test databases on the developer's
// local PostgreSQL (spec §1.3A, §14).
//
// Safety: it only ever touches a database whose name ends in "_test"
// (TEST_DATABASE_MIGRATION_URL). Per test binary it drops and recreates
// schema montra and applies every migration from empty, proving migrations
// are repeatable. Run integration packages with `go test -p 1` so packages
// do not reset the shared schema concurrently.
package dbtest

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/migrate"
)

// Env holds connections for each database role.
type Env struct {
	App      *database.DB // montra_app (RLS enforced)
	Worker   *database.DB // montra_worker (system scope)
	OwnerURL string
}

var (
	once   sync.Once
	env    *Env
	envErr error
)

// RepoRoot locates the repository root (directory containing supabase/).
func RepoRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for i := 0; i < 8; i++ {
		if st, err := os.Stat(filepath.Join(dir, "supabase", "migrations")); err == nil && st.IsDir() {
			return dir, nil
		}
		dir = filepath.Dir(dir)
	}
	return "", fmt.Errorf("repository root not found")
}

// Setup returns the shared test environment, skipping when the test
// database is not configured.
func Setup(t testing.TB) *Env {
	t.Helper()
	once.Do(func() { env, envErr = setup() })
	if envErr != nil {
		if strings.Contains(envErr.Error(), "not configured") {
			t.Skip(envErr.Error())
		}
		t.Fatalf("test database setup failed: %v", envErr)
	}
	return env
}

// suiteLock keeps the advisory lock's session open for the process lifetime:
// without a live reference the connection's socket could be closed by the
// garbage collector, releasing the lock while tests still run.
var suiteLock *pgx.Conn //nolint:unused // written once, held (never read) to keep the lock session alive

func setup() (*Env, error) {
	root, err := RepoRoot()
	if err != nil {
		return nil, err
	}
	config.LoadDotEnv(filepath.Join(root, "backend", ".env.local"))
	ownerURL := os.Getenv("TEST_DATABASE_MIGRATION_URL")
	appURL := os.Getenv("TEST_DATABASE_APP_URL")
	workerURL := os.Getenv("TEST_DATABASE_WORKER_URL")
	if ownerURL == "" || appURL == "" || workerURL == "" {
		return nil, fmt.Errorf("integration database not configured (TEST_DATABASE_* env vars); run scripts/db/bootstrap.sh")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	r, err := migrate.Connect(ctx, ownerURL, os.Stderr)
	if err != nil {
		return nil, err
	}
	defer r.Close(context.Background())
	target, err := r.Target(ctx)
	if err != nil {
		return nil, err
	}
	if !strings.HasSuffix(target.Database, "_test") {
		return nil, fmt.Errorf("refusing to use database %q for tests: name must end in _test", target.Database)
	}
	// Test processes share one database and reset it at start-up, so they
	// take turns: the session-level advisory lock is held until this process
	// exits (parallel `go test` packages or concurrent runs queue up).
	lockCtx, lockCancel := context.WithTimeout(context.Background(), 20*time.Minute)
	defer lockCancel()
	lockConn, err := pgx.Connect(lockCtx, ownerURL)
	if err != nil {
		return nil, err
	}
	if _, err := lockConn.Exec(lockCtx, `select pg_advisory_lock(hashtext('montra_test_suite'))`); err != nil {
		return nil, fmt.Errorf("waiting for the test database: %w", err)
	}
	suiteLock = lockConn
	if err := r.Reset(ctx, target.Database); err != nil {
		return nil, err
	}
	ms, err := migrate.Load(filepath.Join(root, "supabase", "migrations"))
	if err != nil {
		return nil, err
	}
	if _, err := r.Up(ctx, ms); err != nil {
		return nil, fmt.Errorf("migrations from empty failed: %w", err)
	}
	// Re-running must be a no-op (repeatability).
	if n, err := r.Up(ctx, ms); err != nil || n != 0 {
		return nil, fmt.Errorf("re-running migrations was not a no-op: applied=%d err=%w", n, err)
	}
	app, err := database.Open(ctx, database.Options{URL: appURL, AppName: "montra-test-app", MaxConns: 8})
	if err != nil {
		return nil, err
	}
	worker, err := database.Open(ctx, database.Options{URL: workerURL, AppName: "montra-test-worker", MaxConns: 4})
	if err != nil {
		return nil, err
	}
	return &Env{App: app, Worker: worker, OwnerURL: ownerURL}, nil
}

// User is a synthetic test user.
type User struct {
	ID    uuid.UUID
	Email string
}

// CreateUser inserts a verified synthetic user directly (worker scope).
func (e *Env) CreateUser(t testing.TB, name string) User {
	t.Helper()
	id := uuid.New()
	email := fmt.Sprintf("test.%s.%s@example.com", strings.ToLower(strings.ReplaceAll(name, " ", "")), id.String()[:8])
	ctx := context.Background()
	err := e.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `insert into users (id, email, email_normalized, email_verified_at, date_of_birth_confirmed_adult)
			values ($1,$2,$2,now(),true)`, id, email); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into profiles (user_id, display_name) values ($1,$2)`, id, "Test "+name); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `insert into user_preferences (user_id, base_currency) values ($1,'INR')`, id)
		return err
	})
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	return User{ID: id, Email: email}
}

// ExecWorker runs SQL with system scope (test setup/assertions only).
func (e *Env) ExecWorker(t testing.TB, sql string, args ...any) {
	t.Helper()
	ctx := context.Background()
	if err := e.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, sql, args...)
		return err
	}); err != nil {
		t.Fatalf("exec: %v", err)
	}
}
