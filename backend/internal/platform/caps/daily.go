package caps

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
)

// CodeDailyCap is the detail code of a 429 answered when a daily cap is
// reached (error.details[0].code).
const CodeDailyCap = "daily_cap"

// Daily refuses another action once the user did limit of them in the last
// 24 hours (a rolling window). The answer is 429 RATE_LIMITED with
// Retry-After set to when the oldest counted action leaves the window, and
// details[0] carries code daily_cap with params resource, limit and
// retry_at (RFC 3339, UTC).
//
// times must be a query with one parameter (the user ID) selecting the
// created_at of the user's actions in the last 24 hours, for example
// `select created_at from community_posts where author_id = $1 and
// created_at > now() - interval '1 day'`. Run it in the transaction that
// performs the action. resource names what is capped in the message
// ("posts", "comments", ...).
func Daily(ctx context.Context, tx pgx.Tx, uid uuid.UUID, resource, times string, limit int) error {
	var n int
	var oldest *time.Time
	var now time.Time
	// Sorted newest first, the limit-th action is the one whose expiry
	// brings the count below the cap.
	if err := tx.QueryRow(ctx, `select count(*)::int, (array_agg(t order by t desc))[$2::int], now() from (`+times+`) q(t)`, uid, limit).
		Scan(&n, &oldest, &now); err != nil {
		return err
	}
	if n < limit || oldest == nil {
		return nil
	}
	retryAt := oldest.Add(24 * time.Hour)
	wait := retryAt.Sub(now)
	if wait < time.Second {
		wait = time.Second
	}
	msg := fmt.Sprintf("You reached the daily limit of %d %s. Try again later.", limit, resource)
	return apperr.RateLimited().WithRetryAfter(wait).WithDetails(apperr.Detail{Code: CodeDailyCap, Message: msg,
		Params: map[string]string{"resource": resource, "limit": strconv.Itoa(limit), "retry_at": retryAt.UTC().Format(time.RFC3339)}})
}
