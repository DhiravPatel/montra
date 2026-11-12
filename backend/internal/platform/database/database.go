// Package database provides the PostgreSQL pool and transaction helpers that
// propagate the authenticated identity to row-level security (ADR-003).
//
// Every API query runs inside WithUserTx, which sets the transaction-local
// setting montra.user_id used by RLS policies. Queries never rely on a
// session-level setting, so the helpers are safe behind transaction-mode
// connection poolers.
package database

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"montra/backend/internal/platform/apperr"
)

// SearchPath is applied to every transaction.
const SearchPath = "montra, extensions"

// Options configures the pool.
type Options struct {
	URL              string
	AppName          string
	MaxConns         int32
	MinConns         int32
	MaxConnLifetime  time.Duration
	MaxConnIdleTime  time.Duration
	StatementTimeout time.Duration
	SimpleProtocol   bool
}

// DB wraps a pgx pool.
type DB struct {
	Pool *pgxpool.Pool
}

// Querier is satisfied by pgx.Tx and *pgxpool.Pool.
type Querier interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults
}

// Open creates and verifies a connection pool.
func Open(ctx context.Context, o Options) (*DB, error) {
	cfg, err := pgxpool.ParseConfig(o.URL)
	if err != nil {
		return nil, fmt.Errorf("parse database url: %w", err)
	}
	if o.MaxConns > 0 {
		cfg.MaxConns = o.MaxConns
	}
	if o.MinConns > 0 {
		cfg.MinConns = o.MinConns
	}
	if o.MaxConnLifetime > 0 {
		cfg.MaxConnLifetime = o.MaxConnLifetime
	}
	if o.MaxConnIdleTime > 0 {
		cfg.MaxConnIdleTime = o.MaxConnIdleTime
	}
	if cfg.ConnConfig.RuntimeParams == nil {
		cfg.ConnConfig.RuntimeParams = map[string]string{}
	}
	if o.AppName != "" {
		cfg.ConnConfig.RuntimeParams["application_name"] = o.AppName
	}
	cfg.ConnConfig.RuntimeParams["search_path"] = SearchPath
	cfg.ConnConfig.RuntimeParams["timezone"] = "UTC"
	if o.StatementTimeout > 0 {
		cfg.ConnConfig.RuntimeParams["statement_timeout"] = strconv.FormatInt(o.StatementTimeout.Milliseconds(), 10)
	}
	cfg.ConnConfig.RuntimeParams["idle_in_transaction_session_timeout"] = "60000"
	if o.SimpleProtocol {
		cfg.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
	}
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}
	return &DB{Pool: pool}, nil
}

// Close releases the pool.
func (db *DB) Close() {
	if db != nil && db.Pool != nil {
		db.Pool.Close()
	}
}

// Ping checks connectivity (readiness probe).
func (db *DB) Ping(ctx context.Context) error {
	return db.Pool.Ping(ctx)
}

// TxOptions selects isolation and access mode.
type TxOptions struct {
	ReadOnly  bool
	Isolation pgx.TxIsoLevel
}

const setContextSQL = `select set_config('montra.user_id', $1, true), set_config('search_path', $2, true)`

// WithUserTx runs fn in a transaction scoped to userID for RLS.
func (db *DB) WithUserTx(ctx context.Context, userID uuid.UUID, fn func(tx pgx.Tx) error) error {
	return db.withTx(ctx, userID.String(), TxOptions{}, fn)
}

// WithUserReadTx runs fn in a read-only transaction scoped to userID.
func (db *DB) WithUserReadTx(ctx context.Context, userID uuid.UUID, fn func(tx pgx.Tx) error) error {
	return db.withTx(ctx, userID.String(), TxOptions{ReadOnly: true}, fn)
}

// WithUserTxOpts runs fn with explicit options (e.g. serializable).
func (db *DB) WithUserTxOpts(ctx context.Context, userID uuid.UUID, o TxOptions, fn func(tx pgx.Tx) error) error {
	return db.withTx(ctx, userID.String(), o, fn)
}

// WithAnonTx runs fn without an authenticated identity (pre-auth flows such
// as login). RLS then only permits access through SECURITY DEFINER helper
// functions designed for those flows.
func (db *DB) WithAnonTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	return db.withTx(ctx, "", TxOptions{}, fn)
}

// WithSystemTx runs fn as the connection's role without a user identity.
// Used by the worker (montra_worker policies grant system scope); callers
// must authorize explicitly.
func (db *DB) WithSystemTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	return db.withTx(ctx, "", TxOptions{}, fn)
}

func (db *DB) withTx(ctx context.Context, userID string, o TxOptions, fn func(tx pgx.Tx) error) (err error) {
	opts := pgx.TxOptions{IsoLevel: o.Isolation}
	if o.ReadOnly {
		opts.AccessMode = pgx.ReadOnly
	}
	tx, err := db.Pool.BeginTx(ctx, opts)
	if err != nil {
		return MapError(err)
	}
	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback(context.WithoutCancel(ctx))
			panic(p)
		}
		if err != nil {
			_ = tx.Rollback(context.WithoutCancel(ctx))
		}
	}()
	if _, err = tx.Exec(ctx, setContextSQL, userID, SearchPath); err != nil {
		return MapError(err)
	}
	if err = fn(tx); err != nil {
		return err
	}
	if err = tx.Commit(ctx); err != nil {
		return MapError(err)
	}
	return nil
}

// PostgreSQL SQLSTATE codes used for classification.
const (
	SQLStateUniqueViolation      = "23505"
	SQLStateForeignKeyViolation  = "23503"
	SQLStateCheckViolation       = "23514"
	SQLStateNotNullViolation     = "23502"
	SQLStateExclusionViolation   = "23P01"
	SQLStateSerializationFailure = "40001"
	SQLStateDeadlock             = "40P01"
	SQLStateInsufficientPriv     = "42501"
	SQLStateQueryCanceled        = "57014"
	SQLStateRaiseException       = "P0001"
)

// PgError extracts a PostgreSQL error, if any.
func PgError(err error) (*pgconn.PgError, bool) {
	var pe *pgconn.PgError
	if errors.As(err, &pe) {
		return pe, true
	}
	return nil, false
}

// IsUniqueViolation reports a unique violation, optionally on a specific
// constraint.
func IsUniqueViolation(err error, constraint string) bool {
	pe, ok := PgError(err)
	return ok && pe.Code == SQLStateUniqueViolation && (constraint == "" || pe.ConstraintName == constraint)
}

// IsForeignKeyViolation reports a foreign-key violation.
func IsForeignKeyViolation(err error) bool {
	pe, ok := PgError(err)
	return ok && pe.Code == SQLStateForeignKeyViolation
}

// IsCheckViolation reports a check-constraint violation.
func IsCheckViolation(err error, constraint string) bool {
	pe, ok := PgError(err)
	return ok && pe.Code == SQLStateCheckViolation && (constraint == "" || pe.ConstraintName == constraint)
}

// IsRetryable reports serialization failures and deadlocks.
func IsRetryable(err error) bool {
	pe, ok := PgError(err)
	return ok && (pe.Code == SQLStateSerializationFailure || pe.Code == SQLStateDeadlock)
}

// IsNoRows reports pgx.ErrNoRows.
func IsNoRows(err error) bool { return errors.Is(err, pgx.ErrNoRows) }

// MapError converts infrastructure errors into safe application errors.
// Unknown errors become INTERNAL_ERROR with the cause retained for logging.
func MapError(err error) error {
	if err == nil {
		return nil
	}
	var ae *apperr.Error
	if errors.As(err, &ae) {
		return err
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return apperr.New(apperr.CodeTimeout, 504, "The request timed out.").WithCause(err)
	}
	if errors.Is(err, context.Canceled) {
		return apperr.New(apperr.CodeTimeout, 499, "The request was cancelled.").WithCause(err)
	}
	if pe, ok := PgError(err); ok {
		switch pe.Code {
		case SQLStateInsufficientPriv:
			// RLS WITH CHECK failures and privilege errors surface as 42501.
			if f := onDenied.Load(); f != nil {
				(*f)()
			}
			return apperr.Forbidden().WithCause(err)
		case SQLStateQueryCanceled:
			return apperr.New(apperr.CodeTimeout, 504, "The request timed out.").WithCause(err)
		case SQLStateSerializationFailure, SQLStateDeadlock:
			return apperr.Conflict("The request conflicted with a concurrent change. Please retry.").WithCause(err)
		}
	}
	return apperr.Internal(err)
}

// Retry runs fn up to attempts times while it returns a retryable
// PostgreSQL error (serialization failure/deadlock).
func Retry(ctx context.Context, attempts int, fn func() error) error {
	var err error
	for i := 0; i < attempts; i++ {
		err = fn()
		if err == nil || !IsRetryable(err) {
			return err
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(time.Duration(10*(i+1)) * time.Millisecond):
		}
	}
	return err
}

var onDenied atomic.Pointer[func()]

// OnPermissionDenied registers a callback for PostgreSQL permission and RLS
// denials (SQLSTATE 42501) seen by MapError, e.g. to count them in metrics.
func OnPermissionDenied(f func()) { onDenied.Store(&f) }
