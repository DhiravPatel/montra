// Command worker runs Montra's durable background processing: the job
// worker, the leader-elected scheduler and the outbox relay (ADR-008).
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
	_ "time/tzdata"

	"montra/backend/internal/app"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/logging"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/platform/outbox"
)

func main() {
	if err := run(); err != nil {
		slog.Error("worker exited with error", slog.Any("error", err))
		os.Exit(1)
	}
}

func run() error {
	time.Local = time.UTC // all timestamps are handled and serialized in UTC
	config.LoadDotEnv(".env.local")
	appURL := os.Getenv("DATABASE_URL") // montra_app: user-scoped reads under RLS
	if u := os.Getenv("WORKER_DATABASE_URL"); u != "" {
		_ = os.Setenv("DATABASE_URL", u) // the worker's own work runs as montra_worker
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	cfg.ServiceName = "montra-worker"
	slog.SetDefault(logging.New(os.Stdout, cfg.LogLevel, cfg.LogFormat))

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	dbx, err := database.Open(ctx, database.Options{
		URL: cfg.Database.URL, AppName: "montra-worker", MaxConns: cfg.Database.MaxConns, MinConns: 1,
		MaxConnLifetime: cfg.Database.MaxConnLifetime, MaxConnIdleTime: cfg.Database.MaxConnIdleTime,
		StatementTimeout: 5 * time.Minute, SimpleProtocol: cfg.Database.SimpleProtocol,
	})
	if err != nil {
		return err
	}
	defer dbx.Close()

	// A small RLS-enforcing pool for work done on behalf of one user
	// (report generation reads as the report owner).
	var appDB *database.DB
	if appURL != "" && appURL != cfg.Database.URL {
		if appDB, err = database.Open(ctx, database.Options{URL: appURL, AppName: "montra-worker-userscope", MaxConns: 4, MinConns: 0,
			MaxConnLifetime: cfg.Database.MaxConnLifetime, MaxConnIdleTime: cfg.Database.MaxConnIdleTime,
			StatementTimeout: 2 * time.Minute, SimpleProtocol: cfg.Database.SimpleProtocol}); err != nil {
			return err
		}
		defer appDB.Close()
	} else {
		slog.Warn("DATABASE_URL (application role) is not set separately from WORKER_DATABASE_URL; report generation is disabled")
	}
	metrics := observability.New("montra-worker")
	deps := app.Deps{Cfg: cfg, DB: dbx, Metrics: metrics, AppDB: appDB, Worker: true}
	svcs, err := app.NewServices(deps)
	if err != nil {
		return err
	}
	sender, err := email.New(cfg.Email)
	if err != nil {
		return err
	}
	reg := jobs.NewRegistry()
	app.RegisterJobs(reg, svcs, sender)
	app.RegisterPlatformJobs(reg, deps)

	worker := jobs.NewWorker(dbx, reg, jobs.WorkerOptions{Concurrency: cfg.Jobs.Concurrency, PollInterval: cfg.Jobs.PollInterval,
		Lease: cfg.Jobs.LeaseDuration, Metrics: metrics})
	relay := outbox.NewRelay(dbx)
	app.RegisterOutboxRoutes(relay)

	var wg sync.WaitGroup
	run := func(name string, fn func(context.Context) error) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := fn(ctx); err != nil && !errors.Is(err, context.Canceled) {
				slog.Error("component stopped", slog.String("component", name), slog.Any("error", err))
			}
		}()
	}
	run("worker", worker.Run)
	run("outbox", relay.Run)
	if cfg.Jobs.SchedulerEnable {
		run("scheduler", jobs.NewScheduler(dbx, app.Periodic()).Run)
	}
	run("metrics", func(ctx context.Context) error {
		addr := os.Getenv("WORKER_METRICS_ADDR")
		if addr == "" {
			addr = "127.0.0.1:9091"
		}
		srv := &http.Server{Addr: addr, Handler: metrics.Handler(cfg.HTTP.MetricsToken), ReadHeaderTimeout: 5 * time.Second}
		go func() {
			<-ctx.Done()
			sctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
			defer cancel()
			_ = srv.Shutdown(sctx)
		}()
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			return err
		}
		return nil
	})
	run("queue-metrics", func(ctx context.Context) error {
		t := time.NewTicker(30 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return nil
			case <-t.C:
				if depth, err := jobs.QueueDepth(ctx, dbx); err == nil {
					for _, st := range []string{"queued", "running", "dead", "failed"} {
						metrics.JobQueueDepth.WithLabelValues(st).Set(float64(depth[st]))
					}
				}
			}
		}
	})
	slog.Info("worker running", slog.String("worker_id", worker.ID()), slog.Bool("scheduler", cfg.Jobs.SchedulerEnable))
	wg.Wait()
	slog.Info("worker stopped")
	return nil
}
