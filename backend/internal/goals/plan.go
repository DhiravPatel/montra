package goals

import (
	"bytes"
	"context"
	"encoding/csv"
	"encoding/json"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/finance"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/outbox"
)

// GoalMemberInput adds a member.
type GoalMemberInput struct {
	UserID uuid.UUID `json:"user_id"`
	Role   string    `json:"role,omitempty" enum:"contributor,viewer"`
}

// AddMember shares a goal with a friend or group co-member (owner only).
// version, when not 0, must be the goal's current version.
func (s *Service) AddMember(ctx context.Context, goalID uuid.UUID, version int32, in GoalMemberInput) (*GoalDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if in.Role == "" {
		in.Role = "contributor"
	}
	var out *GoalDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, current, err := lockOwned(ctx, tx, uid, goalID)
		if err != nil {
			return err
		}
		if err := checkVersion(version, current); err != nil {
			return err
		}
		if in.UserID == uid {
			return apperr.FieldError("body.user_id", "You already own this goal.")
		}
		var ok bool
		if err := tx.QueryRow(ctx, `select montra.are_connected($1, $2) or montra.share_active_group($1, $2)`, uid, in.UserID).Scan(&ok); err != nil {
			return err
		}
		if !ok {
			return apperr.FieldError("body.user_id", "You can only share goals with friends or group members.")
		}
		if _, err := tx.Exec(ctx, `insert into goal_members (goal_id, user_id, role) values ($1,$2,$3)
			on conflict (goal_id, user_id) do update set role = excluded.role, left_at = null, joined_at = case when goal_members.left_at is null
			then goal_members.joined_at else now() end`, goalID, in.UserID, in.Role); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update goals set visibility = 'members' where id = $1`, goalID); err != nil {
			return err
		}
		if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventMemberAdded, AggregateType: "goal", AggregateID: goalID, UserID: &uid,
			Payload: map[string]any{"user_id": in.UserID}}); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "goal", EntityID: &goalID, Action: "member_added",
			Changes: map[string]any{"user_id": in.UserID, "role": in.Role}}); err != nil {
			return err
		}
		g, err := s.load(ctx, tx, goalID)
		if err != nil {
			return err
		}
		out = &g.GoalDTO
		return nil
	})
	return out, database.MapError(err)
}

// GoalMemberUpdate changes a role (owner) or the caller's own contribution
// visibility (the owner sets theirs on their own entry, userId = owner).
type GoalMemberUpdate struct {
	Role                   string `json:"role,omitempty" enum:"contributor,viewer" doc:"Owner only; the owner's own role cannot change (owner_role_fixed)"`
	ContributionVisibility string `json:"contribution_visibility,omitempty" enum:"amounts,percent_only,hidden" doc:"Only for yourself (member_controls_visibility otherwise), the owner included"`
}

// UpdateMember applies a member change. The owner has no member row: their
// own contribution visibility is stored on the goal. version, when not 0,
// must be the goal's current version.
func (s *Service) UpdateMember(ctx context.Context, goalID, userID uuid.UUID, version int32, in GoalMemberUpdate) (*GoalDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GoalDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var access *string
		if err := tx.QueryRow(ctx, `select montra.goal_access($1)`, goalID).Scan(&access); err != nil {
			return err
		}
		if access == nil {
			return apperr.NotFound("goal")
		}
		isOwner := *access == "owner"
		if in.Role != "" && !isOwner {
			return apperr.Forbidden()
		}
		if in.ContributionVisibility != "" && userID != uid {
			return apperr.Rule("member_controls_visibility", "Members choose their own contribution visibility.", nil)
		}
		var owner uuid.UUID
		var current int32
		if err := tx.QueryRow(ctx, `select owner_user_id, version from goals where id = $1`, goalID).Scan(&owner, &current); err != nil {
			return err
		}
		if err := checkVersion(version, current); err != nil {
			return err
		}
		if userID == owner {
			if in.Role != "" {
				return apperr.Rule("owner_role_fixed", "The owner's role cannot change.", nil)
			}
			if in.ContributionVisibility != "" {
				if _, err := tx.Exec(ctx, `update goals set owner_contribution_visibility = $2 where id = $1`, goalID, in.ContributionVisibility); err != nil {
					return err
				}
				if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "goal", EntityID: &goalID, Action: "member_updated",
					Changes: map[string]any{"user_id": userID, "contribution_visibility": in.ContributionVisibility}}); err != nil {
					return err
				}
			}
			g, err := s.load(ctx, tx, goalID)
			if err != nil {
				return err
			}
			out = &g.GoalDTO
			return nil
		}
		tag, err := tx.Exec(ctx, `update goal_members set role = coalesce(nullif($3, ''), role),
			contribution_visibility = coalesce(nullif($4, ''), contribution_visibility) where goal_id = $1 and user_id = $2 and left_at is null`,
			goalID, userID, in.Role, in.ContributionVisibility)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("member")
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "goal", EntityID: &goalID, Action: "member_updated",
			Changes: map[string]any{"user_id": userID, "role": in.Role, "contribution_visibility": in.ContributionVisibility}}); err != nil {
			return err
		}
		g, err := s.load(ctx, tx, goalID)
		if err != nil {
			return err
		}
		out = &g.GoalDTO
		return nil
	})
	return out, database.MapError(err)
}

// RemoveMember removes a member (owner) or leaves the goal (self). Past
// contributions stay in the goal's history and totals; the member can void
// their own contributions before leaving. The owner cannot leave. version,
// when not 0, must be the goal's current version.
func (s *Service) RemoveMember(ctx context.Context, goalID, userID uuid.UUID, version int32) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var access *string
		if err := tx.QueryRow(ctx, `select montra.goal_access($1)`, goalID).Scan(&access); err != nil {
			return err
		}
		if access == nil {
			return apperr.NotFound("goal")
		}
		if *access != "owner" && userID != uid {
			return apperr.Forbidden()
		}
		var owner uuid.UUID
		var current int32
		if err := tx.QueryRow(ctx, `select owner_user_id, version from goals where id = $1`, goalID).Scan(&owner, &current); err != nil {
			return err
		}
		if err := checkVersion(version, current); err != nil {
			return err
		}
		if userID == owner {
			return apperr.Rule("owner_cannot_leave", "The owner cannot leave or be removed; archive the goal instead.", nil)
		}
		tag, err := tx.Exec(ctx, `update goal_members set left_at = now() where goal_id = $1 and user_id = $2 and left_at is null`, goalID, userID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("member")
		}
		action := "member_removed"
		if userID == uid {
			action = "member_left"
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &owner, ActorUserID: &uid, EntityType: "goal", EntityID: &goalID, Action: action,
			Changes: map[string]any{"user_id": userID}})
	}))
}

// GoalForecast projects goal completion with explicit assumptions.
type GoalForecast struct {
	Saved               apitypes.Money    `json:"saved"`
	Remaining           apitypes.Money    `json:"remaining"`
	Target              apitypes.Money    `json:"target"`
	TargetDate          *string           `json:"target_date,omitempty"`
	DaysLeft            *int              `json:"days_left,omitempty"`
	RequiredPerMonth    *apitypes.Money   `json:"required_per_month,omitempty" doc:"To reach the target by the target date (rounded up)"`
	RequiredPerWeek     *apitypes.Money   `json:"required_per_week,omitempty"`
	RecentMonthlyPace   apitypes.Money    `json:"recent_monthly_pace" doc:"Net counted contributions in the last 90 days ÷ 3"`
	ProjectedCompletion *string           `json:"projected_completion,omitempty" doc:"At the recent pace; omitted when the pace is zero or negative"`
	PlannedCompletion   *string           `json:"planned_completion,omitempty" doc:"At the planned contribution schedule"`
	OnTrack             *bool             `json:"on_track,omitempty" doc:"Projected (or planned) completion on or before the target date"`
	Achieved            bool              `json:"achieved"`
	Assumptions         []string          `json:"assumptions" doc:"English; localize by assumption_codes"`
	AssumptionCodes     []string          `json:"assumption_codes" enum:"exact_amounts_no_growth,recent_pace_window,planned_not_counted" doc:"Stable codes in the order of assumptions; their values are in assumption_params"`
	AssumptionParams    map[string]string `json:"assumption_params" doc:"Values the codes refer to: currency (exact_amounts_no_growth); window_days and months (recent_pace_window)"`
}

// forecastAssumptionCodes are the codes of the forecast assumptions, in order.
var forecastAssumptionCodes = []string{"exact_amounts_no_growth", "recent_pace_window", "planned_not_counted"}

func ceilDiv(a, b int64) int64 {
	if b <= 0 {
		return 0
	}
	return (a + b - 1) / b
}

// monthsBetween counts whole calendar months from a to b (at least 1).
func monthsBetween(a, b time.Time) int64 {
	m := int64((b.Year()-a.Year())*12 + int(b.Month()) - int(a.Month()))
	if b.Day() < a.Day() {
		m--
	}
	return max(m, 1)
}

// GetForecast computes the forecast for a goal.
func (s *Service) GetForecast(ctx context.Context, goalID uuid.UUID) (*GoalForecast, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out GoalForecast
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		g, err := s.load(ctx, tx, goalID)
		if err != nil {
			return err
		}
		u, err := finance.LoadUser(ctx, tx, uid) // "today" in the viewer's time zone
		if err != nil {
			return err
		}
		today := localToday(s.now(), u.Loc)
		out = GoalForecast{Saved: g.Progress.Saved, Remaining: g.Progress.Remaining, Target: g.Target, TargetDate: g.TargetDate,
			Achieved: g.remainingMinor == 0, Assumptions: []string{
				"Amounts are exact in " + g.cur + "; no interest, returns or inflation are assumed.",
				"Recent pace is the net of recorded and verified contributions in the last 90 days divided by 3.",
				"Planned contributions are intentions, not money movements, and are not counted as saved.",
			}, AssumptionCodes: append([]string{}, forecastAssumptionCodes...),
			AssumptionParams: map[string]string{"currency": g.cur, "window_days": "90", "months": "3"}}
		var net int64
		if err := tx.QueryRow(ctx, `select coalesce(sum(case when kind = 'contribution' then amount_minor else -amount_minor end), 0)::bigint
			from goal_contributions where goal_id = $1 and voided_at is null and status in ('recorded','verified') and contributed_on > $2::date - 90`,
			goalID, today).Scan(&net); err != nil {
			return err
		}
		pace, err := money.MulRatio(net, 1, 3)
		if err != nil {
			return err
		}
		out.RecentMonthlyPace = apitypes.M(pace, g.cur)
		if out.Achieved {
			return nil
		}
		rem := g.remainingMinor
		var projected, planned *time.Time
		if pace > 0 {
			d := today.AddDate(0, int(ceilDiv(rem, pace)), 0)
			projected = &d
			ds := finance.LocalDateString(d)
			out.ProjectedCompletion = &ds
		}
		if g.planned != nil && *g.planned > 0 && g.ContributionSchedule != "none" {
			periods := int(ceilDiv(rem, *g.planned))
			var d time.Time
			switch g.ContributionSchedule {
			case "weekly":
				d = today.AddDate(0, 0, 7*periods)
			case "biweekly":
				d = today.AddDate(0, 0, 14*periods)
			default:
				d = today.AddDate(0, periods, 0)
			}
			planned = &d
			ds := finance.LocalDateString(d)
			out.PlannedCompletion = &ds
		}
		if g.targetDate != nil {
			days := int(g.targetDate.Sub(today).Hours() / 24)
			out.DaysLeft = &days
			months := monthsBetween(today, *g.targetDate)
			weeks := max(ceilDiv(int64(max(days, 0)), 7), 1)
			pm, pw := apitypes.M(ceilDiv(rem, months), g.cur), apitypes.M(ceilDiv(rem, weeks), g.cur)
			out.RequiredPerMonth, out.RequiredPerWeek = &pm, &pw
			best := projected
			if planned != nil && (best == nil || planned.Before(*best)) {
				best = planned
			}
			onTrack := best != nil && !best.After(*g.targetDate)
			out.OnTrack = &onTrack
		}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// csvCell neutralizes spreadsheet formula injection.
func csvCell(s string) string {
	if s != "" && strings.ContainsRune("=+-@\t\r", rune(s[0])) {
		return "'" + s
	}
	return s
}

// ExportCSV exports the visible contribution history as CSV. It returns the
// file name: goal-contributions-YYYY-MM-DD.csv (the caller's local date; the
// goal's name is never part of it).
func (s *Service) ExportCSV(ctx context.Context, goalID uuid.UUID) ([]byte, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	var buf bytes.Buffer
	var name string
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		g, err := s.load(ctx, tx, goalID)
		if err != nil {
			return err
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		name = "goal-contributions-" + finance.LocalDateString(localToday(s.now(), u.Loc)) + ".csv"
		list, err := s.contributions(ctx, tx, uid, goalID, nil, nil) // the export is complete
		if err != nil {
			return err
		}
		w := csv.NewWriter(&buf)
		if err := w.Write([]string{"date", "contributor", "kind", "status", "amount", "currency", "share_of_target_percent", "voided", "note"}); err != nil {
			return err
		}
		for _, c := range list {
			amount, pct := "", ""
			if c.Amount != nil {
				amount = c.Amount.Amount
			}
			if c.PercentBP != nil {
				pct = money.FormatExp(*c.PercentBP, 2)
			}
			note := ""
			if c.Note != nil {
				note = *c.Note
			}
			voided := "no"
			if c.Voided {
				voided = "yes"
			}
			contributor := "" // hidden profiles stay unnamed in the file too
			if c.DisplayName != nil {
				contributor = *c.DisplayName
			}
			if err := w.Write([]string{c.ContributedOn, csvCell(contributor), c.Kind, c.Status, amount, g.cur, pct, voided, csvCell(note)}); err != nil {
				return err
			}
		}
		w.Flush()
		return w.Error()
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	return buf.Bytes(), name, nil
}

// Job types.
const (
	JobReminders    = "goals.reminders"     // periodic contribution reminders
	JobEvaluate     = "goals.evaluate"      // milestone/achievement notifications
	JobNotifyMember = "goals.notify_member" // "a goal was shared with you"
)

// RegisterJobs registers goal jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobReminders, func(ctx context.Context, _ jobs.Job) error { return s.Reminders(ctx) },
		jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(1))
	reg.Register(JobEvaluate, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			GoalID uuid.UUID `json:"goal_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			err := s.notifyMilestones(ctx, tx, p.GoalID)
			if database.IsNoRows(err) {
				return nil // goal deleted with its owner
			}
			return err
		})
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(4))
	reg.Register(JobNotifyMember, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			GoalID uuid.UUID `json:"goal_id"`
			UserID uuid.UUID `json:"user_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			var active bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from goal_members where goal_id = $1 and user_id = $2 and left_at is null)`,
				p.GoalID, p.UserID).Scan(&active); err != nil || !active {
				return err
			}
			gid := p.GoalID
			_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: p.UserID, Category: "goal", EventType: "goal_shared",
				Title: "A goal was shared with you", Body: "Open Goals to see it.", DeepLink: "/goals/" + gid.String(), EntityType: "goal",
				EntityID: &gid, DedupeKey: "goal_shared:" + gid.String() + ":" + p.UserID.String()})
			return err
		})
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
}

// OutboxRoutes maps goal events to worker jobs.
func OutboxRoutes(relay *outbox.Relay) {
	relay.On(EventChanged, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobEvaluate, UserID: e.UserID, Payload: map[string]any{"goal_id": *e.AggregateID},
			DedupeKey: "goals.evaluate:" + strconv.FormatInt(e.ID, 10)}}
	})
	relay.On(EventMemberAdded, func(e outbox.Stored) []jobs.Spec {
		var p struct {
			UserID uuid.UUID `json:"user_id"`
		}
		if e.AggregateID == nil || json.Unmarshal(e.Payload, &p) != nil {
			return nil
		}
		return []jobs.Spec{{Type: JobNotifyMember, UserID: &p.UserID, Payload: map[string]any{"goal_id": *e.AggregateID, "user_id": p.UserID},
			DedupeKey: "goals.notify_member:" + strconv.FormatInt(e.ID, 10)}}
	})
}

// periodKey identifies the current contribution period.
func periodKey(schedule string, start, today time.Time) (key string, from time.Time) {
	switch schedule {
	case "weekly":
		off := (int(today.Weekday()) + 6) % 7 // Monday-based weeks
		from = today.AddDate(0, 0, -off)
	case "biweekly":
		days := int(today.Sub(start).Hours() / 24)
		if days < 0 {
			days = 0
		}
		from = start.AddDate(0, 0, days/14*14)
	default:
		from = time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
	}
	return schedule + ":" + finance.LocalDateString(from), from
}

// Reminders notifies goal owners once per schedule period when no
// contribution has been counted in that period.
func (s *Service) Reminders(ctx context.Context) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select g.id, g.owner_user_id, g.name, g.contribution_schedule, g.start_date, p.timezone
			from goals g join users u on u.id = g.owner_user_id join user_preferences p on p.user_id = g.owner_user_id
			where g.status = 'active' and g.reminders_enabled and g.contribution_schedule <> 'none' and u.status = 'active' limit 5000`)
		if err != nil {
			return err
		}
		type rem struct {
			id, owner      uuid.UUID
			name, schedule string
			start          time.Time
			tz             string
		}
		list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (rem, error) {
			var x rem
			err := r.Scan(&x.id, &x.owner, &x.name, &x.schedule, &x.start, &x.tz)
			return x, err
		})
		if err != nil {
			return err
		}
		for _, x := range list {
			loc, err := time.LoadLocation(x.tz)
			if err != nil {
				loc = time.UTC
			}
			today := localToday(s.now(), loc)
			if today.Before(x.start) {
				continue
			}
			key, from := periodKey(x.schedule, dateOnly(x.start), today)
			var done bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from goal_contributions where goal_id = $1 and voided_at is null
				and kind = 'contribution' and status in ('recorded','verified') and contributed_on >= $2)`, x.id, from).Scan(&done); err != nil {
				return err
			}
			if done {
				continue
			}
			id := x.id
			if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: x.owner, Category: "goal", EventType: "goal_contribution_due",
				Title: "Time to add to " + x.name, Body: "Record this period's contribution when you set the money aside.",
				DeepLink: "/goals/" + id.String(), EntityType: "goal", EntityID: &id, DedupeKey: "goal_reminder:" + id.String() + ":" + key}); err != nil {
				return err
			}
		}
		return nil
	})
}
