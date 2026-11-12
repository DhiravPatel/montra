// Package idempotency makes retryable writes safe (spec §6, §18).
//
// The key row is inserted in the SAME transaction as the business write and
// completed before commit. A concurrent duplicate blocks on the unique index
// until the first transaction finishes, then replays the stored response.
// A crash before commit rolls back both, so a retry simply executes again.
package idempotency

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"regexp"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
)

var keyRe = regexp.MustCompile(`^[A-Za-z0-9_\-:.]{8,128}$`)

// ValidateKey checks the Idempotency-Key header format.
func ValidateKey(key string) error {
	if !keyRe.MatchString(key) {
		return apperr.FieldError("header.Idempotency-Key", "Idempotency-Key must be 8-128 characters of letters, digits, '-', '_', ':' or '.'.")
	}
	return nil
}

// RequestHash fingerprints the request so a key reused with a different
// payload is rejected.
func RequestHash(operation string, req any) string {
	b, _ := json.Marshal(req)
	h := sha256.Sum256(append([]byte(operation+"|"), b...))
	return hex.EncodeToString(h[:])
}

// Run executes fn exactly once per (user, key). On replay it returns the
// stored result and replayed=true. fn runs inside tx.
func Run[T any](ctx context.Context, tx pgx.Tx, userID uuid.UUID, key, operation string, req any, fn func() (T, error)) (result T, replayed bool, err error) {
	if err = ValidateKey(key); err != nil {
		return result, false, err
	}
	hash := RequestHash(operation, req)
	var inserted bool
	err = tx.QueryRow(ctx, `insert into idempotency_keys (user_id, key, operation, request_hash)
		values ($1,$2,$3,$4) on conflict (user_id, key) do nothing returning true`, userID, key, operation, hash).Scan(&inserted)
	if err != nil && !database.IsNoRows(err) {
		return result, false, database.MapError(err)
	}
	if !inserted {
		var storedOp, storedHash, status string
		var body []byte
		if err = tx.QueryRow(ctx, `select operation, request_hash, status, coalesce(response_body, 'null'::jsonb)
			from idempotency_keys where user_id = $1 and key = $2`, userID, key).Scan(&storedOp, &storedHash, &status, &body); err != nil {
			return result, false, database.MapError(err)
		}
		if storedOp != operation || storedHash != hash {
			return result, false, apperr.New(apperr.CodeIdempotencyConflict, http.StatusConflict,
				"This Idempotency-Key was already used for a different request.")
		}
		if status != "completed" {
			return result, false, apperr.New(apperr.CodeIdempotencyInFlight, http.StatusConflict,
				"A request with this Idempotency-Key is still being processed.")
		}
		if err = json.Unmarshal(body, &result); err != nil {
			return result, false, apperr.Internal(err)
		}
		return result, true, nil
	}
	result, err = fn()
	if err != nil {
		return result, false, err
	}
	body, mErr := json.Marshal(result)
	if mErr != nil {
		return result, false, apperr.Internal(mErr)
	}
	if _, err = tx.Exec(ctx, `update idempotency_keys set status = 'completed', response_status = 200, response_body = $3, completed_at = now()
		where user_id = $1 and key = $2`, userID, key, body); err != nil {
		return result, false, database.MapError(err)
	}
	return result, false, nil
}
