// Command api runs the Montra HTTP API (/api/v1).
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
	_ "time/tzdata" // embed IANA zone data for container images

	"montra/backend/internal/app"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/logging"
	"montra/backend/internal/platform/observability"
)

func main() {
	if err := run(); err != nil {
		slog.Error("api exited with error", slog.Any("error", err))
		os.Exit(1)
	}
}

func run() error {
	time.Local = time.UTC // all timestamps are handled and serialized in UTC
	if f := config.LoadDotEnv(".env.local"); f != "" {
		slog.Info("loaded local env file (development convenience)", slog.String("file", f))
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	logger := logging.New(os.Stdout, cfg.LogLevel, cfg.LogFormat)
	slog.SetDefault(logger)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	dbx, err := database.Open(ctx, database.Options{
		URL: cfg.Database.URL, AppName: "montra-api", MaxConns: cfg.Database.MaxConns, MinConns: cfg.Database.MinConns,
		MaxConnLifetime: cfg.Database.MaxConnLifetime, MaxConnIdleTime: cfg.Database.MaxConnIdleTime,
		StatementTimeout: cfg.Database.StatementTimeout, SimpleProtocol: cfg.Database.SimpleProtocol,
	})
	if err != nil {
		return err
	}
	defer dbx.Close()

	metrics := observability.New("montra-api")
	deps := app.Deps{Cfg: cfg, DB: dbx, Metrics: metrics}
	svcs, err := app.NewServices(deps)
	if err != nil {
		return err
	}
	handler, _ := app.NewRouter(deps, svcs)

	srv := &http.Server{
		Addr:              cfg.HTTP.Addr,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       cfg.HTTP.ReadTimeout,
		WriteTimeout:      cfg.HTTP.WriteTimeout,
		IdleTimeout:       cfg.HTTP.IdleTimeout,
		MaxHeaderBytes:    64 << 10,
	}
	errCh := make(chan error, 1)
	go func() {
		slog.Info("api listening", slog.String("addr", cfg.HTTP.Addr), slog.String("env", cfg.Env),
			slog.String("storage", cfg.Storage.Provider), slog.String("email_provider", cfg.Email.Provider))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()
	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
	}
	slog.Info("api shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.HTTP.ShutdownTimeout)
	defer cancel()
	return srv.Shutdown(shutdownCtx)
}
