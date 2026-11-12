// Package migrate applies forward-only SQL migrations (ADR-004).
//
// Files live in supabase/migrations and are named
// YYYYMMDDHHMMSS_description.sql. Each file runs in its own transaction
// (unless it starts with the marker "-- montra:no-transaction") and is
// recorded with its SHA-256 checksum. An applied file whose checksum changes
// aborts the run: applied migrations must never be edited.
package migrate

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// advisoryLockKey serializes concurrent migration runs.
const advisoryLockKey int64 = 7_210_391_004_511

var fileRe = regexp.MustCompile(`^(\d{14})_([a-z0-9_]+)\.sql$`)

// Migration is a single SQL file.
type Migration struct {
	Version  string
	Name     string
	Path     string
	SQL      string
	Checksum string
	NoTx     bool
}

// Applied is a row in montra.schema_migrations.
type Applied struct {
	Version   string
	Name      string
	Checksum  string
	AppliedAt time.Time
}

// Target describes the database a command will act on.
type Target struct {
	Host     string
	Port     uint16
	Database string
	User     string
}

func (t Target) String() string {
	return fmt.Sprintf("host=%s port=%d database=%s user=%s", t.Host, t.Port, t.Database, t.User)
}

// Load reads and validates migration files from dir.
func Load(dir string) ([]Migration, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read migrations dir: %w", err)
	}
	var out []Migration
	seen := map[string]string{}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		m := fileRe.FindStringSubmatch(e.Name())
		if m == nil {
			return nil, fmt.Errorf("invalid migration file name %q (want YYYYMMDDHHMMSS_name.sql)", e.Name())
		}
		if prev, dup := seen[m[1]]; dup {
			return nil, fmt.Errorf("duplicate migration version %s (%s, %s)", m[1], prev, e.Name())
		}
		seen[m[1]] = e.Name()
		path := filepath.Join(dir, e.Name())
		b, err := os.ReadFile(path) //nolint:gosec // migration files come from the operator-configured directory
		if err != nil {
			return nil, err
		}
		sum := sha256.Sum256(b)
		sql := string(b)
		out = append(out, Migration{
			Version:  m[1],
			Name:     m[2],
			Path:     path,
			SQL:      sql,
			Checksum: hex.EncodeToString(sum[:]),
			NoTx:     strings.HasPrefix(strings.TrimSpace(sql), "-- montra:no-transaction"),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Version < out[j].Version })
	return out, nil
}

// Runner applies migrations over a single connection.
type Runner struct {
	conn *pgx.Conn
	out  io.Writer
}

// Connect opens a dedicated connection for migrations.
func Connect(ctx context.Context, url string, out io.Writer) (*Runner, error) {
	conn, err := pgx.Connect(ctx, url)
	if err != nil {
		return nil, fmt.Errorf("connect: %w", err)
	}
	if out == nil {
		out = os.Stdout
	}
	return &Runner{conn: conn, out: out}, nil
}

// Close closes the connection.
func (r *Runner) Close(ctx context.Context) { _ = r.conn.Close(ctx) }

// Target reports the connected server/database (without credentials).
func (r *Runner) Target(ctx context.Context) (Target, error) {
	cfg := r.conn.Config()
	t := Target{Host: cfg.Host, Port: cfg.Port, User: cfg.User}
	if err := r.conn.QueryRow(ctx, `select current_database()`).Scan(&t.Database); err != nil {
		return t, err
	}
	return t, nil
}

func (r *Runner) ensureTable(ctx context.Context) error {
	_, err := r.conn.Exec(ctx, `
create schema if not exists montra;
create table if not exists montra.schema_migrations (
  version     text primary key,
  name        text not null,
  checksum    text not null,
  applied_at  timestamptz not null default now(),
  duration_ms integer not null default 0,
  applied_by  text not null default current_user
);`)
	return err
}

// AppliedMigrations lists recorded migrations.
func (r *Runner) AppliedMigrations(ctx context.Context) (map[string]Applied, error) {
	if err := r.ensureTable(ctx); err != nil {
		return nil, err
	}
	rows, err := r.conn.Query(ctx, `select version, name, checksum, applied_at from montra.schema_migrations order by version`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]Applied{}
	for rows.Next() {
		var a Applied
		if err := rows.Scan(&a.Version, &a.Name, &a.Checksum, &a.AppliedAt); err != nil {
			return nil, err
		}
		out[a.Version] = a
	}
	return out, rows.Err()
}

// Up applies all pending migrations and returns how many were applied.
func (r *Runner) Up(ctx context.Context, migrations []Migration) (int, error) {
	if _, err := r.conn.Exec(ctx, `select pg_advisory_lock($1)`, advisoryLockKey); err != nil {
		return 0, fmt.Errorf("acquire migration lock: %w", err)
	}
	defer func() {
		_, _ = r.conn.Exec(context.WithoutCancel(ctx), `select pg_advisory_unlock($1)`, advisoryLockKey)
	}()

	applied, err := r.AppliedMigrations(ctx)
	if err != nil {
		return 0, err
	}
	// Verify integrity of already-applied migrations first.
	known := map[string]bool{}
	for _, m := range migrations {
		known[m.Version] = true
		if a, ok := applied[m.Version]; ok && a.Checksum != m.Checksum {
			return 0, fmt.Errorf("migration %s_%s was modified after being applied (checksum mismatch); add a new migration instead", m.Version, m.Name)
		}
	}
	for v := range applied {
		if !known[v] {
			return 0, fmt.Errorf("database has migration %s that is missing from the migrations directory", v)
		}
	}
	count := 0
	for _, m := range migrations {
		if _, ok := applied[m.Version]; ok {
			continue
		}
		start := time.Now()
		if err := r.apply(ctx, m); err != nil {
			return count, fmt.Errorf("apply %s_%s: %w", m.Version, m.Name, err)
		}
		count++
		_, _ = fmt.Fprintf(r.out, "applied %s_%s (%d ms)\n", m.Version, m.Name, time.Since(start).Milliseconds())
	}
	return count, nil
}

func (r *Runner) apply(ctx context.Context, m Migration) error {
	start := time.Now()
	if m.NoTx {
		if _, err := r.conn.Exec(ctx, m.SQL); err != nil {
			return err
		}
		_, err := r.conn.Exec(ctx, `insert into montra.schema_migrations(version, name, checksum, duration_ms) values ($1,$2,$3,$4)`,
			m.Version, m.Name, m.Checksum, time.Since(start).Milliseconds())
		return err
	}
	tx, err := r.conn.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(context.WithoutCancel(ctx)) }()
	if _, err := tx.Exec(ctx, m.SQL); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `insert into montra.schema_migrations(version, name, checksum, duration_ms) values ($1,$2,$3,$4)`,
		m.Version, m.Name, m.Checksum, time.Since(start).Milliseconds()); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// ErrUnsafeReset is returned when a reset target is not a dev/test database.
var ErrUnsafeReset = errors.New("refusing to reset: database name must end in _dev or _test and --confirm must equal the database name")

// SafeToReset validates a reset request.
func SafeToReset(dbName, confirm string) error {
	if (!strings.HasSuffix(dbName, "_dev") && !strings.HasSuffix(dbName, "_test")) || confirm != dbName {
		return ErrUnsafeReset
	}
	return nil
}

// Reset drops the montra schema in a verified dev/test database.
func (r *Runner) Reset(ctx context.Context, confirm string) error {
	t, err := r.Target(ctx)
	if err != nil {
		return err
	}
	if err := SafeToReset(t.Database, confirm); err != nil {
		return err
	}
	_, _ = fmt.Fprintf(r.out, "resetting schema montra on %s\n", t)
	_, err = r.conn.Exec(ctx, `drop schema if exists montra cascade`)
	return err
}

// Seed runs seed files (development/test databases only).
func (r *Runner) Seed(ctx context.Context, dir string) (int, error) {
	t, err := r.Target(ctx)
	if err != nil {
		return 0, err
	}
	if !strings.HasSuffix(t.Database, "_dev") && !strings.HasSuffix(t.Database, "_test") {
		return 0, fmt.Errorf("refusing to seed %s: seeds are only for _dev/_test databases", t.Database)
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0, err
	}
	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			files = append(files, filepath.Join(dir, e.Name()))
		}
	}
	sort.Strings(files)
	for _, f := range files {
		b, err := os.ReadFile(f) //nolint:gosec // seed files come from the operator-configured directory
		if err != nil {
			return 0, err
		}
		tx, err := r.conn.Begin(ctx)
		if err != nil {
			return 0, err
		}
		if _, err := tx.Exec(ctx, string(b)); err != nil {
			_ = tx.Rollback(ctx)
			return 0, fmt.Errorf("seed %s: %w", filepath.Base(f), err)
		}
		if err := tx.Commit(ctx); err != nil {
			return 0, err
		}
		_, _ = fmt.Fprintf(r.out, "seeded %s\n", filepath.Base(f))
	}
	return len(files), nil
}
