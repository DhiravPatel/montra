package budgets

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// PeriodOutcome is one closed budget period's result, computed with the
// canonical budget calculation (rollover, refunds, allocations).
type PeriodOutcome struct {
	BudgetID uuid.UUID
	Name     string
	Currency string
	Start    time.Time
	End      time.Time
	Limit    int64
	Spent    int64
}

// RecentOutcomes returns up to n closed periods (newest first) for each
// active, non-custom personal budget the user owns. Periods before the
// budget started are skipped. It works in the caller's transaction and is
// used by insights (repeated overspend).
func (s *Service) RecentOutcomes(ctx context.Context, tx pgx.Tx, uid uuid.UUID, n int) ([]PeriodOutcome, error) {
	rows, err := tx.Query(ctx, budgetSelect+` where b.owner_user_id = $1 and b.group_id is null and b.status = 'active' and b.period <> 'custom'
		order by b.created_at`, uid)
	if err != nil {
		return nil, err
	}
	var list []*budgetRow
	for rows.Next() {
		b, err := scanBudget(rows)
		if err != nil {
			rows.Close()
			return nil, err
		}
		list = append(list, b)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	var out []PeriodOutcome
	for _, b := range list {
		r := b.periodFor(s.now())
		for i := 0; i < n; i++ {
			r = b.periodFor(r.Start.AddDate(0, 0, -1))
			if r.End.Before(b.starts) {
				break
			}
			prog, _, err := s.progress(ctx, tx, b, r, uid, nil, nil)
			if err != nil {
				return nil, err
			}
			out = append(out, PeriodOutcome{BudgetID: b.ID, Name: b.Name, Currency: b.Currency, Start: r.Start, End: r.End,
				Limit: prog.Limit.AmountMinor, Spent: prog.Spent.AmountMinor})
		}
	}
	return out, nil
}
