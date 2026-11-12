package database

import (
	"errors"
	"fmt"
	"net/http"
	"sync/atomic"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"

	"montra/backend/internal/platform/apperr"
)

func TestMapErrorReportsPermissionDenials(t *testing.T) {
	var n atomic.Int32
	OnPermissionDenied(func() { n.Add(1) })
	t.Cleanup(func() { OnPermissionDenied(func() {}) })

	rls := fmt.Errorf("insert: %w", &pgconn.PgError{Code: SQLStateInsufficientPriv, Message: "new row violates row-level security policy"})
	var ae *apperr.Error
	if !errors.As(MapError(rls), &ae) || ae.Status != http.StatusForbidden {
		t.Fatalf("RLS denial must map to 403, got %v", MapError(rls))
	}
	if n.Load() != 1 {
		t.Fatalf("denial callback calls = %d", n.Load())
	}
	_ = MapError(&pgconn.PgError{Code: "23505"})
	if n.Load() != 1 {
		t.Fatal("other errors must not count as denials")
	}
}
