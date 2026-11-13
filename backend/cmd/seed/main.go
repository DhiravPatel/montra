// Command seed loads deterministic demo data (demo.*@example.com users with
// accounts, 90 days of transactions, a budget with an alert, bills,
// subscriptions, a goal, a group with expenses and a settlement, and a
// community post) through the real services.
//
//	go run ./cmd/seed        (or: make seed)
//
// It refuses to run unless APP_ENV is development or test and the database
// name ends in _dev or _test. Running it again adds nothing. It never
// changes or deletes other users' data.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
	_ "time/tzdata"

	"montra/backend/internal/app"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/logging"
	"montra/backend/internal/seed"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "seed:", err)
		os.Exit(1)
	}
}

func run() error {
	time.Local = time.UTC
	config.LoadDotEnv(".env.local", "backend/.env.local")
	// Refuse before touching anything when the environment is wrong.
	if err := seed.CheckEnv(os.Getenv("APP_ENV")); err != nil {
		return err
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	if err := seed.CheckEnv(cfg.Env); err != nil {
		return err
	}
	// Demo accounts must be usable right away: development verifies them
	// at sign-up (as AUTH_DEV_AUTO_VERIFY_EMAIL does); test does not
	// require verification. Both settings are allowed only there.
	if cfg.Env == config.EnvDevelopment {
		cfg.Auth.DevAutoVerifyEmail = true
	} else {
		cfg.Auth.RequireEmailVerified = false
	}
	cfg.ServiceName = "montra-seed"
	slog.SetDefault(logging.New(os.Stderr, "warn", cfg.LogFormat))

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	appDB, err := database.Open(ctx, database.Options{URL: cfg.Database.URL, AppName: "montra-seed", MaxConns: 4, StatementTimeout: time.Minute})
	if err != nil {
		return err
	}
	defer appDB.Close()
	var name string
	if err := appDB.Pool.QueryRow(ctx, `select current_database()`).Scan(&name); err != nil {
		return err
	}
	if !strings.HasSuffix(name, "_dev") && !strings.HasSuffix(name, "_test") {
		return fmt.Errorf("refusing to seed database %q: its name must end in _dev or _test", name)
	}
	fmt.Printf("target: database %s (APP_ENV=%s)\n", name, cfg.Env)

	svcs, err := app.NewServices(app.Deps{Cfg: cfg, DB: appDB})
	if err != nil {
		return err
	}
	sd := &seed.Seeder{App: svcs, Env: cfg.Env, Log: os.Stdout}
	// With the worker role the budget alert is raised now; otherwise the
	// running worker raises it from the outbox events.
	if u := os.Getenv("WORKER_DATABASE_URL"); u != "" {
		workerDB, err := database.Open(ctx, database.Options{URL: u, AppName: "montra-seed-worker", MaxConns: 2, StatementTimeout: time.Minute})
		if err != nil {
			return err
		}
		defer workerDB.Close()
		var wname string
		if err := workerDB.Pool.QueryRow(ctx, `select current_database()`).Scan(&wname); err != nil {
			return err
		}
		if wname != name {
			return fmt.Errorf("WORKER_DATABASE_URL points at %q, not %q", wname, name)
		}
		wcfg := *cfg
		if sd.Worker, err = app.NewServices(app.Deps{Cfg: &wcfg, DB: workerDB, AppDB: appDB, Worker: true}); err != nil {
			return err
		}
	}
	sum, err := sd.Run(ctx)
	if sum != nil {
		fmt.Printf("done: %d created, %d already present (password for demo.*@example.com: %s)\n", sum.CreatedTotal(),
			total(sum.Existing), seed.DemoPassword)
	}
	return err
}

func total(m map[string]int) int {
	n := 0
	for _, v := range m {
		n += v
	}
	return n
}
