package budgets

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/budgetcalc"
	"montra/backend/internal/finance"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/outbox"
)

// JobEvaluate re-evaluates a user's (or group's) budgets after changes.
const JobEvaluate = "budgets.evaluate"

// RegisterJobs registers the evaluation handler (worker, system scope).
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobEvaluate, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			UserID  *uuid.UUID `json:"user_id"`
			GroupID *uuid.UUID `json:"group_id"`
		}
		if err := j.Decode(&p); err != nil {
			return err
		}
		return s.Evaluate(ctx, p.UserID, p.GroupID)
	}, jobs.WithTimeout(2*time.Minute), jobs.WithConcurrency(4))
}

// Routes maps finance events to debounced budget evaluation: changes that
// arrive while an evaluation is still queued share it; changes after it
// started get a fresh one, so alerts never wait for an unrelated later
// change.
func Routes(relay *outbox.Relay) {
	route := func(e outbox.Stored) []jobs.Spec {
		if e.GroupID != nil {
			return []jobs.Spec{{Type: JobEvaluate, Payload: map[string]any{"group_id": e.GroupID}, RunAfter: time.Now().Add(5 * time.Second),
				CoalesceQueued: true}}
		}
		if e.UserID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobEvaluate, UserID: e.UserID, Payload: map[string]any{"user_id": e.UserID}, RunAfter: time.Now().Add(5 * time.Second),
			CoalesceQueued: true}}
	}
	for _, ev := range []string{"transaction.created", "transaction.updated", "transaction.voided", "transaction.restored",
		"transfer.created", "transactions.bulk_updated", "group_expense.created", "group_expense.updated", "group_expense.deleted"} {
		relay.On(ev, route)
	}
}

// Evaluate recomputes active budgets and raises deduplicated alerts.
func (s *Service) Evaluate(ctx context.Context, userID, groupID *uuid.UUID) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		q := budgetSelect + ` where b.status = 'active' and `
		var arg any
		if groupID != nil {
			q += `b.group_id = $1`
			arg = *groupID
		} else if userID != nil {
			q += `b.owner_user_id = $1 and b.group_id is null`
			arg = *userID
		} else {
			return nil
		}
		rows, err := tx.Query(ctx, q, arg)
		if err != nil {
			return err
		}
		var list []*budgetRow
		for rows.Next() {
			b, err := scanBudget(rows)
			if err != nil {
				rows.Close()
				return err
			}
			list = append(list, b)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		for _, b := range list {
			if err := s.evaluateOne(ctx, tx, b); err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Service) evaluateOne(ctx context.Context, tx pgx.Tx, b *budgetRow) error {
	r := b.periodFor(s.now())
	if b.ends != nil && r.Start.After(*b.ends) {
		return nil
	}
	// Allocations are evaluated for cache freshness (collaborator view).
	arows, err := tx.Query(ctx, `select id, category_id, merchant_id, account_id, member_user_id, limit_minor from budget_allocations where budget_id = $1`, b.ID)
	if err != nil {
		return err
	}
	var allocs []AllocationDTO
	var limits []int64
	for arows.Next() {
		var a AllocationDTO
		var l int64
		if err := arows.Scan(&a.ID, &a.CategoryID, &a.MerchantID, &a.AccountID, &a.MemberUserID, &l); err != nil {
			arows.Close()
			return err
		}
		allocs, limits = append(allocs, a), append(limits, l)
	}
	arows.Close()
	prog, _, err := s.progress(ctx, tx, b, r, b.OwnerUserID, allocs, limits)
	if err != nil {
		return err
	}
	recipients := []uuid.UUID{b.OwnerUserID}
	mrows, err := tx.Query(ctx, `select user_id from budget_members where budget_id = $1`, b.ID)
	if err != nil {
		return err
	}
	for mrows.Next() {
		var u uuid.UUID
		if err := mrows.Scan(&u); err != nil {
			mrows.Close()
			return err
		}
		recipients = append(recipients, u)
	}
	mrows.Close()
	limit, spent := prog.Limit.AmountMinor, prog.Spent.AmountMinor
	type alert struct {
		kind      string
		threshold int16
		title     string
		body      string
	}
	var alerts []alert
	for _, t := range budgetcalc.ReachedThresholds(spent, limit, b.AlertThresholds) {
		title := fmt.Sprintf("%s budget at %d%%", b.Name, t)
		body := fmt.Sprintf("You've used %d%% of this period's budget.", t)
		if t >= 100 {
			body = "This period's budget is fully used."
		}
		alerts = append(alerts, alert{"threshold", t, title, body})
	}
	minElapsed := prog.TotalDays / 5
	if minElapsed < 3 {
		minElapsed = 3
	}
	if b.AlertForecast && prog.ProjectedOver.AmountMinor > 0 && spent < limit && prog.ElapsedDays >= minElapsed {
		alerts = append(alerts, alert{"forecast_overspend", 0, b.Name + " may go over budget",
			"At the current pace this budget may be exceeded before the period ends. This is an estimate."})
	}
	for _, a := range alerts {
		for _, uid := range recipients {
			var alertID uuid.UUID
			err := tx.QueryRow(ctx, `insert into budget_alerts (budget_id, user_id, period_start, kind, threshold, spent_minor, limit_minor)
				values ($1,$2,$3,$4,$5,$6,$7) on conflict (budget_id, user_id, period_start, kind, threshold) do nothing returning id`,
				b.ID, uid, prog.PeriodStart, a.kind, a.threshold, spent, limit).Scan(&alertID)
			if database.IsNoRows(err) {
				continue // already raised this period (dedupe)
			}
			if err != nil {
				return err
			}
			var snoozed bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from budget_alerts where budget_id = $1 and user_id = $2 and status = 'snoozed'
				and snoozed_until > now())`, b.ID, uid).Scan(&snoozed); err != nil {
				return err
			}
			if snoozed {
				continue
			}
			bid := b.ID
			if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "budget", EventType: "budget_" + a.kind,
				Title: a.title, Body: a.body, DeepLink: "/budgets/" + b.ID.String(), EntityType: "budget", EntityID: &bid, GroupID: b.GroupID,
				Priority: map[bool]string{true: "high", false: "normal"}[a.threshold >= 100], DedupeKey: "budget_alert:" + alertID.String()}); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `update budget_alerts set notified_at = now() where id = $1`, alertID); err != nil {
				return err
			}
		}
	}
	return nil
}

// AlertDTO is a raised budget alert.
type AlertDTO struct {
	ID           uuid.UUID  `json:"id"`
	BudgetID     uuid.UUID  `json:"budget_id"`
	BudgetName   string     `json:"budget_name"`
	PeriodStart  string     `json:"period_start"`
	Kind         string     `json:"kind" enum:"threshold,forecast_overspend,unusual_spend" doc:"unusual_spend is reserved and not raised today (unusual transactions appear as insights)"`
	Threshold    int16      `json:"threshold"`
	Status       string     `json:"status" enum:"active,dismissed,snoozed"`
	SnoozedUntil *time.Time `json:"snoozed_until,omitempty"`
	TriggeredAt  time.Time  `json:"triggered_at"`
}

// ListAlerts lists the caller's budget alerts.
func (s *Service) ListAlerts(ctx context.Context, status string, budgetID *uuid.UUID, cursor string, limit int) ([]AlertDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	var cur alertCursor
	if err := httpx.DecodeCursor(cursor, &cur); err != nil {
		return nil, "", err
	}
	out := []AlertDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		// The first page and later pages use separate SQL texts, so a cached
		// generic plan can still bound the index scan by the cursor
		// (docs/QUERY_PLAN_REVIEW.md, R-F).
		q := `select a.id, a.budget_id, b.name, a.period_start, a.kind, a.threshold, a.status, a.snoozed_until, a.triggered_at
			from budget_alerts a join budgets b on b.id = a.budget_id where a.user_id = $1 and ($2 = '' or a.status = $2)
			and ($3::uuid is null or a.budget_id = $3)`
		args := []any{uid, status, budgetID}
		if cur.At != nil {
			q += ` and (a.triggered_at, a.id) < ($4::timestamptz, $5::uuid) order by a.triggered_at desc, a.id desc limit $6`
			args = append(args, *cur.At, cur.ID, limit+1)
		} else {
			q += ` order by a.triggered_at desc, a.id desc limit $4`
			args = append(args, limit+1)
		}
		rows, err := tx.Query(ctx, q, args...)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var a AlertDTO
			var ps time.Time
			if err := rows.Scan(&a.ID, &a.BudgetID, &a.BudgetName, &ps, &a.Kind, &a.Threshold, &a.Status, &a.SnoozedUntil, &a.TriggeredAt); err != nil {
				return err
			}
			a.PeriodStart = finance.LocalDateString(ps)
			out = append(out, a)
		}
		if err := rows.Err(); err != nil {
			return err
		}
		if len(out) > limit {
			last := out[limit-1]
			next, _ = httpx.EncodeCursor(alertCursor{At: &last.TriggeredAt, ID: last.ID})
			out = out[:limit]
		}
		return nil
	})
	return out, next, database.MapError(err)
}

type alertCursor struct {
	At *time.Time `json:"t"`
	ID uuid.UUID  `json:"i"`
}

// UpdateAlert dismisses, snoozes or reactivates an alert.
func (s *Service) UpdateAlert(ctx context.Context, id uuid.UUID, status string, until *time.Time) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	if status == "snoozed" && (until == nil || until.Before(s.now())) {
		return apperr.FieldError("body.snoozed_until", "Choose a future time to snooze until.")
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update budget_alerts set status = $3, snoozed_until = $4 where id = $1 and user_id = $2`, id, uid, status, until)
		if err == nil && tag.RowsAffected() == 0 {
			return apperr.NotFound("alert")
		}
		return err
	}))
}
