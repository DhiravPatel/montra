// Command migrate applies Montra's forward-only SQL migrations.
//
//	migrate up      [-dir ../supabase/migrations] [-yes]
//	migrate status  [-dir ...]
//	migrate seed    [-seeds ../supabase/seeds]        (dev/test databases only)
//	migrate reset   -confirm <database_name>          (dev/test databases only)
//
// The connection string comes from DATABASE_MIGRATION_URL (owner role). The
// target host/database is always printed before any change. Databases whose
// name does not end in _dev or _test require -yes for "up".
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/migrate"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	config.LoadDotEnv(".env.local", "backend/.env.local")
	if len(os.Args) < 2 {
		return fmt.Errorf("usage: migrate <up|status|seed|reset> [flags]")
	}
	cmd := os.Args[1]
	fs := flag.NewFlagSet(cmd, flag.ExitOnError)
	dir := fs.String("dir", defaultPath("../supabase/migrations", "supabase/migrations"), "migrations directory")
	seeds := fs.String("seeds", defaultPath("../supabase/seeds", "supabase/seeds"), "seeds directory")
	confirm := fs.String("confirm", "", "database name confirmation for reset")
	yes := fs.Bool("yes", false, "confirm running against a non-dev/test database")
	url := fs.String("url", os.Getenv("DATABASE_MIGRATION_URL"), "owner connection string")
	if err := fs.Parse(os.Args[2:]); err != nil {
		return err
	}
	if *url == "" {
		return fmt.Errorf("DATABASE_MIGRATION_URL (or -url) is required")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	r, err := migrate.Connect(ctx, *url, os.Stdout)
	if err != nil {
		return err
	}
	defer r.Close(context.Background())

	target, err := r.Target(ctx)
	if err != nil {
		return err
	}
	fmt.Printf("target: %s\n", target)
	devLike := strings.HasSuffix(target.Database, "_dev") || strings.HasSuffix(target.Database, "_test")

	switch cmd {
	case "up":
		if !devLike && !*yes {
			return fmt.Errorf("database %q is not a _dev/_test database; re-run with -yes after verifying the target and taking a backup", target.Database)
		}
		ms, err := migrate.Load(*dir)
		if err != nil {
			return err
		}
		n, err := r.Up(ctx, ms)
		if err != nil {
			return err
		}
		fmt.Printf("done: %d migration(s) applied, %d total\n", n, len(ms))
	case "status":
		ms, err := migrate.Load(*dir)
		if err != nil {
			return err
		}
		applied, err := r.AppliedMigrations(ctx)
		if err != nil {
			return err
		}
		pending := 0
		for _, m := range ms {
			state := "pending"
			if a, ok := applied[m.Version]; ok {
				state = "applied " + a.AppliedAt.Format("2006-01-02 15:04:05")
				if a.Checksum != m.Checksum {
					state = "CHECKSUM MISMATCH"
				}
			} else {
				pending++
			}
			fmt.Printf("%s_%s\t%s\n", m.Version, m.Name, state)
		}
		fmt.Printf("%d pending\n", pending)
	case "seed":
		n, err := r.Seed(ctx, *seeds)
		if err != nil {
			return err
		}
		fmt.Printf("done: %d seed file(s)\n", n)
	case "reset":
		if err := r.Reset(ctx, *confirm); err != nil {
			return err
		}
		ms, err := migrate.Load(*dir)
		if err != nil {
			return err
		}
		n, err := r.Up(ctx, ms)
		if err != nil {
			return err
		}
		fmt.Printf("reset complete: %d migration(s) applied\n", n)
	default:
		return fmt.Errorf("unknown command %q", cmd)
	}
	return nil
}

// defaultPath returns the first candidate that exists (supports running from
// backend/ or the repository root).
func defaultPath(candidates ...string) string {
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && st.IsDir() {
			return c
		}
	}
	return candidates[0]
}
