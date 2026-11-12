// Package caps holds Montra's fair-use record caps. They are the same for
// every user, generous for real use, shown in GET /limits, and keep
// unpaginated lists bounded (spec §0.2: no paid tiers or artificial
// restrictions; these exist only to keep the service fast and affordable).
package caps

import (
	"context"
	"fmt"
	"strconv"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
)

// Caps on records that are still open (not ended, archived or cancelled).
const (
	OpenRecurringRules = 500 // personal rules not ended (bills' schedules included)
	OpenBills          = 200 // bills not archived
	OpenSubscriptions  = 500 // subscriptions not cancelled
	OpenGoals          = 200 // goals not archived
)

// Check refuses to open another record once the user has limit open ones.
// count must be a query with one parameter (the user ID) returning the
// number of open records. Run it in the transaction that creates or
// reopens the record.
func Check(ctx context.Context, tx pgx.Tx, uid uuid.UUID, resource, count string, limit int) error {
	var n int
	if err := tx.QueryRow(ctx, count, uid).Scan(&n); err != nil {
		return err
	}
	if n >= limit {
		return apperr.Rule("record_limit_reached",
			fmt.Sprintf("You can keep up to %d of these. End, archive or delete ones you no longer need.", limit),
			map[string]string{"resource": resource, "limit": strconv.Itoa(limit)})
	}
	return nil
}
