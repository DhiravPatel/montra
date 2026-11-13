// Package goals implements goals and savings plans (spec §4.14, §20B.15).
// Contributions are auditable tracking events, not money movements: a
// contribution is "verified" only when it links the ledger transaction that
// moved the money, and each transaction can back at most one active
// contribution (no double counting). Progress is exact integer arithmetic
// over the contribution events; changing a target never rewrites history.
package goals

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/finance"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// Service implements goals.
type Service struct {
	DB  *database.DB
	Now func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func localToday(now time.Time, loc *time.Location) time.Time { return dateOnly(now.In(loc)) }

// GoalMilestoneInput defines a percent milestone.
type GoalMilestoneInput struct {
	Percent int16  `json:"percent" minimum:"1" maximum:"100"`
	Label   string `json:"label,omitempty" maxLength:"80"`
}

// GoalInput creates a goal (updates use GoalPatch).
type GoalInput struct {
	Name                 string               `json:"name" minLength:"1" maxLength:"120"`
	Description          string               `json:"description,omitempty" maxLength:"2000"`
	GoalType             string               `json:"goal_type" enum:"emergency_fund,travel,education,device,vehicle,home,event,debt_payoff,large_purchase,custom"`
	TargetAmount         string               `json:"target_amount"`
	Currency             string               `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Defaults to your base currency"`
	StartingAmount       string               `json:"starting_amount,omitempty" doc:"Saved before you started tracking"`
	StartDate            string               `json:"start_date,omitempty" doc:"Default today"`
	TargetDate           string               `json:"target_date,omitempty"`
	Priority             int16                `json:"priority,omitempty" minimum:"1" maximum:"5" doc:"1 = highest; default 3"`
	LinkedAccountID      *uuid.UUID           `json:"linked_account_id,omitempty" doc:"Informational; the balance is not counted automatically"`
	ContributionSchedule string               `json:"contribution_schedule,omitempty" enum:"none,weekly,biweekly,monthly"`
	PlannedContribution  string               `json:"planned_contribution,omitempty" doc:"Planned amount per schedule period"`
	Visibility           string               `json:"visibility,omitempty" enum:"private,members"`
	RemindersEnabled     bool                 `json:"reminders_enabled,omitempty"`
	Notes                string               `json:"notes,omitempty" maxLength:"2000"`
	GroupID              *uuid.UUID           `json:"group_id,omitempty" doc:"Share with a group (members contribute when visibility is members)"`
	Milestones           []GoalMilestoneInput `json:"milestones,omitempty" maxItems:"10" doc:"Default 25, 50, 75 and 100%"`
	Version              int32                `json:"version,omitempty" doc:"Not used when creating (accepted for compatibility)"`
}

// GoalProgress summarizes saved amounts.
type GoalProgress struct {
	Saved             apitypes.Money `json:"saved" doc:"Starting amount + recorded and verified contributions − withdrawals"`
	Remaining         apitypes.Money `json:"remaining"`
	PercentBP         int64          `json:"percent_bp" doc:"Basis points of target (10000 = 100%)"`
	Verified          apitypes.Money `json:"verified" doc:"Contributions backed by a ledger transaction"`
	Planned           apitypes.Money `json:"planned" doc:"Planned contributions (not counted as saved)"`
	ContributionCount int            `json:"contribution_count"`
}

// GoalMilestone is a percent milestone.
type GoalMilestone struct {
	Percent   int16      `json:"percent"`
	Label     *string    `json:"label,omitempty"`
	ReachedAt *time.Time `json:"reached_at,omitempty"`
}

// GoalMember is a goal collaborator; the owner is listed too.
type GoalMember struct {
	UserID                 uuid.UUID `json:"user_id"`
	DisplayName            *string   `json:"display_name,omitempty" doc:"Omitted when the person's profile is not visible to you"`
	Role                   string    `json:"role" enum:"owner,contributor,viewer"`
	ContributionVisibility string    `json:"contribution_visibility" enum:"amounts,percent_only,hidden" doc:"How this person's contributions are shown to the others"`
	JoinedAt               time.Time `json:"joined_at" doc:"For the owner: when the goal was created"`
}

// GoalOwner identifies the goal's owner.
type GoalOwner struct {
	UserID      uuid.UUID `json:"user_id"`
	DisplayName *string   `json:"display_name,omitempty" doc:"Omitted when the owner's profile is not visible to you"`
}

// GoalDTO is a goal.
type GoalDTO struct {
	ID                   uuid.UUID       `json:"id"`
	Name                 string          `json:"name"`
	Description          *string         `json:"description,omitempty"`
	GoalType             string          `json:"goal_type" enum:"emergency_fund,travel,education,device,vehicle,home,event,debt_payoff,large_purchase,custom"`
	Target               apitypes.Money  `json:"target"`
	Starting             apitypes.Money  `json:"starting"`
	StartDate            string          `json:"start_date"`
	TargetDate           *string         `json:"target_date,omitempty"`
	Priority             int16           `json:"priority"`
	LinkedAccountID      *uuid.UUID      `json:"linked_account_id,omitempty"`
	ContributionSchedule string          `json:"contribution_schedule" enum:"none,weekly,biweekly,monthly"`
	PlannedContribution  *apitypes.Money `json:"planned_contribution,omitempty"`
	Visibility           string          `json:"visibility" enum:"private,members"`
	RemindersEnabled     bool            `json:"reminders_enabled"`
	Status               string          `json:"status" enum:"active,paused,achieved,cancelled,archived"`
	Notes                *string         `json:"notes,omitempty"`
	AchievedAt           *time.Time      `json:"achieved_at,omitempty"`
	GroupID              *uuid.UUID      `json:"group_id,omitempty"`
	OwnerUserID          uuid.UUID       `json:"owner_user_id"`
	Owner                GoalOwner       `json:"owner"`
	Access               string          `json:"access" enum:"owner,contributor,viewer"`
	Progress             GoalProgress    `json:"progress"`
	Milestones           []GoalMilestone `json:"milestones"`
	Members              []GoalMember    `json:"members" doc:"The owner first (role owner), then active members"`
	Version              int32           `json:"version"`
	CreatedAt            time.Time       `json:"created_at"`
}

type goalRow struct {
	GoalDTO
	owner          uuid.UUID
	ownerVis       string
	target, start  int64
	cur            string
	startDate      time.Time
	targetDate     *time.Time
	planned        *int64
	savedMinor     int64
	remainingMinor int64
}

const goalCols = `g.id, g.name, g.description, g.goal_type, g.target_amount_minor, g.currency, g.starting_amount_minor, g.start_date,
	g.target_date, g.priority, g.linked_account_id, g.contribution_schedule, g.planned_contribution_minor, g.visibility,
	g.reminders_enabled, g.status, g.notes, g.achieved_at, g.group_id, g.version, g.created_at, g.owner_user_id,
	g.owner_contribution_visibility, coalesce(montra.goal_access(g.id), 'none')`

const goalFrom = ` from goals g`

func scanGoal(r pgx.Row) (*goalRow, error) {
	var g goalRow
	if err := r.Scan(&g.ID, &g.Name, &g.Description, &g.GoalType, &g.target, &g.cur, &g.start, &g.startDate, &g.targetDate, &g.Priority,
		&g.LinkedAccountID, &g.ContributionSchedule, &g.planned, &g.Visibility, &g.RemindersEnabled, &g.Status, &g.Notes, &g.AchievedAt,
		&g.GroupID, &g.Version, &g.CreatedAt, &g.owner, &g.ownerVis, &g.Access); err != nil {
		return nil, err
	}
	g.Target, g.Starting = apitypes.M(g.target, g.cur), apitypes.M(g.start, g.cur)
	g.StartDate = finance.LocalDateString(g.startDate)
	if g.targetDate != nil {
		d := finance.LocalDateString(*g.targetDate)
		g.TargetDate = &d
	}
	g.PlannedContribution = apitypes.MP(g.planned, g.cur)
	g.OwnerUserID, g.Owner = g.owner, GoalOwner{UserID: g.owner}
	return &g, nil
}

// totals computes progress exactly from contribution events.
func totals(ctx context.Context, tx pgx.Tx, g *goalRow) error {
	var contrib, withdraw, verified, planned int64
	var n int
	if err := tx.QueryRow(ctx, `select
		coalesce(sum(amount_minor) filter (where kind = 'contribution' and status in ('recorded','verified')), 0)::bigint,
		coalesce(sum(amount_minor) filter (where kind = 'withdrawal' and status in ('recorded','verified')), 0)::bigint,
		coalesce(sum(case when kind = 'contribution' then amount_minor else -amount_minor end) filter (where status = 'verified'), 0)::bigint,
		coalesce(sum(amount_minor) filter (where kind = 'contribution' and status = 'planned'), 0)::bigint,
		count(*) filter (where status in ('recorded','verified'))::int
		from goal_contributions where goal_id = $1 and voided_at is null`, g.ID).Scan(&contrib, &withdraw, &verified, &planned, &n); err != nil {
		return err
	}
	saved, err := money.Sum(g.start, contrib, -withdraw)
	if err != nil {
		return err
	}
	g.savedMinor = saved
	g.remainingMinor = max(g.target-saved, 0)
	g.Progress = GoalProgress{Saved: apitypes.M(saved, g.cur), Remaining: apitypes.M(g.remainingMinor, g.cur),
		PercentBP: money.PercentBasisPoints(max(saved, 0), g.target), Verified: apitypes.M(verified, g.cur),
		Planned: apitypes.M(planned, g.cur), ContributionCount: n}
	return nil
}

// load reads a goal as the caller sees it (API role: it uses the
// minimal_profile helper for the owner's name).
func (s *Service) load(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*goalRow, error) {
	g, err := scanGoal(tx.QueryRow(ctx, `select `+goalCols+goalFrom+` where g.id = $1`, id))
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("goal")
	}
	if err != nil {
		return nil, err
	}
	if g.Access == "none" {
		return nil, apperr.NotFound("goal")
	}
	if err := totals(ctx, tx, g); err != nil {
		return nil, err
	}
	g.Milestones, g.Members = []GoalMilestone{}, []GoalMember{}
	rows, err := tx.Query(ctx, `select percent, label, reached_at from goal_milestones where goal_id = $1 order by percent`, id)
	if err != nil {
		return nil, err
	}
	g.Milestones, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (GoalMilestone, error) {
		var m GoalMilestone
		err := r.Scan(&m.Percent, &m.Label, &m.ReachedAt)
		return m, err
	})
	if err != nil {
		return nil, err
	}
	if err := tx.QueryRow(ctx, `select display_name from montra.minimal_profile($1)`, g.owner).Scan(&g.Owner.DisplayName); err != nil && !database.IsNoRows(err) {
		return nil, err
	}
	g.Members = append(g.Members, GoalMember{UserID: g.owner, DisplayName: g.Owner.DisplayName, Role: "owner",
		ContributionVisibility: g.ownerVis, JoinedAt: g.CreatedAt})
	mrows, err := tx.Query(ctx, `select m.user_id, p.display_name, m.role, m.contribution_visibility, m.joined_at
		from goal_members m left join profiles p on p.user_id = m.user_id where m.goal_id = $1 and m.left_at is null order by m.joined_at`, id)
	if err != nil {
		return nil, err
	}
	members, err := pgx.CollectRows(mrows, func(r pgx.CollectableRow) (GoalMember, error) {
		var m GoalMember
		err := r.Scan(&m.UserID, &m.DisplayName, &m.Role, &m.ContributionVisibility, &m.JoinedAt)
		return m, err
	})
	g.Members = append(g.Members, members...)
	return g, err
}

// setMilestones replaces milestone definitions, keeping reached history for
// percentages that remain.
func setMilestones(ctx context.Context, tx pgx.Tx, goalID uuid.UUID, ms []GoalMilestoneInput) error {
	keep := make([]int16, 0, len(ms))
	for _, m := range ms {
		keep = append(keep, m.Percent)
		if _, err := tx.Exec(ctx, `insert into goal_milestones (goal_id, percent, label) values ($1,$2,$3)
			on conflict (goal_id, percent) do update set label = excluded.label`, goalID, m.Percent, trim(m.Label, 80)); err != nil {
			return err
		}
	}
	_, err := tx.Exec(ctx, `delete from goal_milestones where goal_id = $1 and not (percent = any($2))`, goalID, keep)
	return err
}

// Create creates a goal (idempotent per key: a retry with the same key
// returns the original result).
func (s *Service) Create(ctx context.Context, key string, in GoalInput) (*GoalDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out GoalDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "goal.create", in, func() (GoalDTO, error) {
			if err := caps.Check(ctx, tx, uid, "goals", openGoalsQ, caps.OpenGoals); err != nil {
				return GoalDTO{}, err
			}
			u, err := finance.LoadUser(ctx, tx, uid)
			if err != nil {
				return GoalDTO{}, err
			}
			n, p := newDefinition(localToday(s.now(), u.Loc)), in.patch()
			if err := s.apply(ctx, tx, u, n, &p, true); err != nil {
				return GoalDTO{}, err
			}
			id := uuid.New()
			if _, err := tx.Exec(ctx, `insert into goals (id, owner_user_id, group_id, name, description, goal_type, target_amount_minor, currency,
				starting_amount_minor, start_date, target_date, priority, linked_account_id, contribution_schedule, planned_contribution_minor,
				visibility, reminders_enabled, notes) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`,
				id, uid, n.group, n.name, n.description, n.goalType, n.target, n.cur, n.starting, n.start, n.targetDate, n.priority, n.account,
				n.schedule, n.planned, n.visibility, n.reminders, n.notes); err != nil {
				return GoalDTO{}, err
			}
			if err := setMilestones(ctx, tx, id, n.milestones); err != nil {
				return GoalDTO{}, err
			}
			if err := s.evaluate(ctx, tx, id); err != nil {
				return GoalDTO{}, err
			}
			if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "goal", EntityID: &id, Action: "created"}); err != nil {
				return GoalDTO{}, err
			}
			g, err := s.load(ctx, tx, id)
			if err != nil {
				return GoalDTO{}, err
			}
			return g.GoalDTO, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// List returns goals the caller owns or shares (archived excluded by
// default; at most 200).
func (s *Service) List(ctx context.Context, status string) ([]GoalDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []GoalDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select g.id from goals g where ($1 = 'all' or ($1 = '' and g.status <> 'archived') or g.status = $1)
			order by case g.status when 'active' then 0 when 'paused' then 1 when 'achieved' then 2 else 3 end, g.priority, g.target_date nulls last, g.name
			limit 200`, status)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, id := range ids {
			g, err := s.load(ctx, tx, id)
			if err != nil {
				return err
			}
			out = append(out, g.GoalDTO)
		}
		return nil
	})
	return out, database.MapError(err)
}

// Get returns a goal.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*GoalDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GoalDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		g, err := s.load(ctx, tx, id)
		if err != nil {
			return err
		}
		out = &g.GoalDTO
		return nil
	})
	return out, database.MapError(err)
}

// lockOwned locks a goal the caller owns.
func lockOwned(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (status string, version int32, err error) {
	var owner uuid.UUID
	if err := tx.QueryRow(ctx, `select owner_user_id, status, version from goals where id = $1`, id).Scan(&owner, &status, &version); err != nil {
		if database.IsNoRows(err) {
			return "", 0, apperr.NotFound("goal")
		}
		return "", 0, err
	}
	if owner != uid {
		return "", 0, apperr.Forbidden()
	}
	if _, err := tx.Exec(ctx, `select 1 from goals where id = $1 for update`, id); err != nil {
		return "", 0, err
	}
	return status, version, nil
}

// checkVersion compares an optional client version with the current one.
func checkVersion(sent, current int32) error {
	if sent != 0 && sent != current {
		return apperr.VersionConflict()
	}
	return nil
}

// Update applies a partial update (GoalPatch): fields that are not sent
// keep their values. Past contributions are unchanged.
func (s *Service) Update(ctx context.Context, id uuid.UUID, p GoalPatch) (*GoalDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GoalDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, version, err := lockOwned(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if err := checkVersion(p.Version, version); err != nil {
			return err
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		n, err := loadDefinition(ctx, tx, id)
		if err != nil {
			return err
		}
		if err := s.apply(ctx, tx, u, n, &p, false); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update goals set name = $2, description = $3, goal_type = $4, target_amount_minor = $5, starting_amount_minor = $6,
			start_date = $7, target_date = $8, priority = $9, linked_account_id = $10, contribution_schedule = $11, planned_contribution_minor = $12,
			visibility = $13, reminders_enabled = $14, notes = $15, group_id = $16, version = version + 1 where id = $1`,
			id, n.name, n.description, n.goalType, n.target, n.starting, n.start, n.targetDate, n.priority, n.account, n.schedule, n.planned,
			n.visibility, n.reminders, n.notes, n.group); err != nil {
			return err
		}
		if n.milestones != nil {
			if err := setMilestones(ctx, tx, id, n.milestones); err != nil {
				return err
			}
		}
		if err := s.evaluate(ctx, tx, id); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "goal", EntityID: &id, Action: "updated",
			Changes: map[string]any{"fields": sentFields(p)}}); err != nil {
			return err
		}
		g, err := s.load(ctx, tx, id)
		if err != nil {
			return err
		}
		out = &g.GoalDTO
		return nil
	})
	return out, database.MapError(err)
}

// goalTransitions lists the lifecycle actions: from-states → to-state.
// resume also reopens cancelled and archived goals; a goal whose saved
// amount already reaches the target becomes achieved again right away.
var goalTransitions = map[string]struct {
	from []string
	to   string
}{
	"pause":   {[]string{"active"}, "paused"},
	"resume":  {[]string{"paused", "cancelled", "archived"}, "active"},
	"achieve": {[]string{"active", "paused"}, "achieved"},
	"cancel":  {[]string{"active", "paused", "achieved"}, "cancelled"},
	"archive": {[]string{"active", "paused", "achieved", "cancelled"}, "archived"},
}

// SetStatus applies a lifecycle action (history is kept). version, when
// not 0, must be the current version.
// openGoalsQ counts a user's goals for the fair-use cap.
const openGoalsQ = `select count(*) from goals where owner_user_id = $1 and status <> 'archived'`

func (s *Service) SetStatus(ctx context.Context, id uuid.UUID, action string, version int32) (*GoalDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	t, ok := goalTransitions[action]
	if !ok {
		return nil, apperr.BadRequest("Unknown action.")
	}
	var out *GoalDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		status, current, err := lockOwned(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if err := checkVersion(version, current); err != nil {
			return err
		}
		allowed := false
		for _, f := range t.from {
			allowed = allowed || f == status
		}
		if !allowed {
			return apperr.Rule("invalid_status_transition", "A goal cannot move from "+status+" to "+t.to+".",
				map[string]string{"from": status, "to": t.to})
		}
		if status == "archived" && t.to != "archived" {
			if err := caps.Check(ctx, tx, uid, "goals", openGoalsQ, caps.OpenGoals); err != nil {
				return err
			}
		}
		// Marking a goal achieved by hand is the person's decision: it stays
		// achieved even if a withdrawal later takes saved below target.
		if _, err := tx.Exec(ctx, `update goals set status = $2, achieved_at = case when $2 = 'achieved' then coalesce(achieved_at, now())
			when $2 = 'active' then null else achieved_at end,
			achieved_by = case when $2 = 'achieved' then 'manual' when $2 = 'active' then null else achieved_by end,
			version = version + 1 where id = $1`, id, t.to); err != nil {
			return err
		}
		if t.to == "active" {
			if err := s.evaluate(ctx, tx, id); err != nil {
				return err
			}
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "goal", EntityID: &id, Action: action,
			Changes: map[string]any{"from": status, "to": t.to}}); err != nil {
			return err
		}
		g, err := s.load(ctx, tx, id)
		if err != nil {
			return err
		}
		out = &g.GoalDTO
		return nil
	})
	return out, database.MapError(err)
}

// evaluate marks reached milestones and moves the goal between active and
// achieved as saved crosses the target, then emits goal.changed so the
// worker notifies the owner and members (notifications to other users are
// written by the worker; the API role can only notify the caller). For
// non-owners RLS turns the state updates into no-ops and the worker job
// applies them.
func (s *Service) evaluate(ctx context.Context, tx pgx.Tx, id uuid.UUID) error {
	g, err := s.applyState(ctx, tx, id)
	if err != nil {
		return err
	}
	return outbox.Emit(ctx, tx, outbox.Event{Type: EventChanged, AggregateType: "goal", AggregateID: id, UserID: &g.owner})
}

// EventChanged is emitted whenever a goal's progress or definition changes.
const EventChanged = "goal.changed"

// EventMemberAdded is emitted when a goal is shared with a user.
const EventMemberAdded = "goal.member_added"

func (s *Service) applyState(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*goalRow, error) {
	g, err := scanGoal(tx.QueryRow(ctx, `select `+goalCols+goalFrom+` where g.id = $1`, id))
	if err != nil {
		return nil, err
	}
	if err := totals(ctx, tx, g); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `update goal_milestones set reached_at = now() where goal_id = $1 and reached_at is null
		and percent::bigint * 100 <= $2`, id, g.Progress.PercentBP); err != nil {
		return nil, err
	}
	switch {
	case g.Status == "active" && g.savedMinor >= g.target:
		_, err = tx.Exec(ctx, `update goals set status = 'achieved', achieved_at = now(), achieved_by = 'progress' where id = $1`, id)
	case g.Status == "achieved" && g.savedMinor < g.target:
		// Only goals that reached their target reopen automatically.
		_, err = tx.Exec(ctx, `update goals set status = 'active', achieved_at = null, achieved_by = null
			where id = $1 and achieved_by is distinct from 'manual'`, id)
	}
	return g, err
}

// notifyMilestones (worker scope) applies state and notifies the owner and
// active members once per reached milestone.
func (s *Service) notifyMilestones(ctx context.Context, tx pgx.Tx, id uuid.UUID) error {
	g, err := s.applyState(ctx, tx, id)
	if err != nil {
		return err
	}
	rows, err := tx.Query(ctx, `update goal_milestones set notified_at = now() where goal_id = $1 and reached_at is not null
		and notified_at is null returning percent`, id)
	if err != nil {
		return err
	}
	reached, err := pgx.CollectRows(rows, pgx.RowTo[int16])
	if err != nil || len(reached) == 0 {
		return err
	}
	mrows, err := tx.Query(ctx, `select user_id from goal_members where goal_id = $1 and left_at is null`, id)
	if err != nil {
		return err
	}
	members, err := pgx.CollectRows(mrows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return err
	}
	for _, p := range reached {
		for _, r := range append([]uuid.UUID{g.owner}, members...) {
			if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: r, Category: "goal", EventType: "goal_milestone",
				Title: g.Name + " reached " + strconv.Itoa(int(p)) + "%", Body: "Open the goal to see progress.", DeepLink: "/goals/" + id.String(),
				EntityType: "goal", EntityID: &id, DedupeKey: "goal_milestone:" + id.String() + ":" + strconv.Itoa(int(p))}); err != nil {
				return err
			}
		}
	}
	return nil
}

// GoalContributionInput records a contribution or withdrawal.
type GoalContributionInput struct {
	Kind          string     `json:"kind,omitempty" enum:"contribution,withdrawal"`
	Amount        string     `json:"amount"`
	ContributedOn string     `json:"contributed_on,omitempty" doc:"YYYY-MM-DD, default today"`
	Status        string     `json:"status,omitempty" enum:"planned,recorded" doc:"planned = intention (not counted; record it later with POST /goals/{id}/contributions/{contributionId}/record); recorded = you set the money aside. Linking a transaction makes it verified."`
	TransactionID *uuid.UUID `json:"transaction_id,omitempty" doc:"Your ledger transaction that moved the money; each transaction counts once"`
	Note          string     `json:"note,omitempty" maxLength:"500"`
}

// GoalContributionDTO is a contribution as visible to the caller.
type GoalContributionDTO struct {
	ID            uuid.UUID       `json:"id"`
	UserID        uuid.UUID       `json:"user_id"`
	DisplayName   *string         `json:"display_name,omitempty" doc:"Omitted when the contributor's profile is not visible to you"`
	Kind          string          `json:"kind" enum:"contribution,withdrawal"`
	Amount        *apitypes.Money `json:"amount,omitempty" doc:"Omitted when the contributor shares percentages only"`
	PercentBP     *int64          `json:"percent_bp,omitempty" doc:"Share of the target, when amounts are hidden"`
	Status        string          `json:"status" enum:"planned,recorded,verified"`
	TransactionID *uuid.UUID      `json:"transaction_id,omitempty"`
	ContributedOn string          `json:"contributed_on"`
	Note          *string         `json:"note,omitempty"`
	Voided        bool            `json:"voided"`
	Mine          bool            `json:"mine"`
	CreatedAt     time.Time       `json:"created_at"`
}

func duplicate(code, msg string) *apperr.Error {
	return apperr.New(apperr.CodeDuplicate, http.StatusConflict, msg).WithDetails(apperr.Detail{Code: code, Message: msg})
}

// errAlreadyCounted is the answer when a transaction already backs a goal
// contribution.
func errAlreadyCounted() *apperr.Error {
	return duplicate("transaction_already_counted", "This transaction is already counted toward a goal.")
}

// AddContribution records a contribution event (idempotent per key).
func (s *Service) AddContribution(ctx context.Context, key string, goalID uuid.UUID, in GoalContributionInput) (*GoalContributionDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out GoalContributionDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "goal.contribution", struct {
			Goal uuid.UUID
			In   GoalContributionInput
		}{goalID, in}, func() (GoalContributionDTO, error) {
			id, err := s.addContribution(ctx, tx, uid, goalID, in)
			if err != nil {
				return GoalContributionDTO{}, err
			}
			list, err := s.contributions(ctx, tx, uid, goalID, &id, nil)
			if err != nil {
				return GoalContributionDTO{}, err
			}
			return list[0], nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// lockForContribution checks that the caller may contribute and serializes
// contributions per goal (withdrawal limits stay exact).
func lockForContribution(ctx context.Context, tx pgx.Tx, goalID uuid.UUID) (*goalRow, error) {
	var access *string
	if err := tx.QueryRow(ctx, `select montra.goal_access($1)`, goalID).Scan(&access); err != nil {
		return nil, err
	}
	if access == nil {
		return nil, apperr.NotFound("goal")
	}
	if *access != "owner" && *access != "contributor" {
		return nil, apperr.Forbidden()
	}
	if _, err := tx.Exec(ctx, `select pg_advisory_xact_lock(hashtextextended('goal:' || $1::text, 0))`, goalID); err != nil {
		return nil, err
	}
	return scanGoal(tx.QueryRow(ctx, `select `+goalCols+goalFrom+` where g.id = $1`, goalID))
}

// acceptsContributions applies the goal status rule: active goals take
// contributions; achieved goals also take withdrawals.
func acceptsContributions(g *goalRow, kind string) error {
	if g.Status != "active" && (kind != "withdrawal" || g.Status != "achieved") {
		return apperr.Rule("goal_inactive", "Contributions can be added to active goals only.", map[string]string{"status": g.Status})
	}
	return nil
}

// backingTransaction validates the caller's transaction that backs a
// contribution of amount and returns its date.
func backingTransaction(ctx context.Context, tx pgx.Tx, uid, txID uuid.UUID, cur string, amount int64) (time.Time, error) {
	var txAmt int64
	var txCur, txStatus string
	var txDate time.Time
	err := tx.QueryRow(ctx, `select amount_minor, currency, status, local_date from transactions where id = $1 and user_id = $2 and deleted_at is null`,
		txID, uid).Scan(&txAmt, &txCur, &txStatus, &txDate)
	if database.IsNoRows(err) {
		return time.Time{}, apperr.FieldError("body.transaction_id", "Choose one of your transactions.")
	}
	if err != nil {
		return time.Time{}, err
	}
	if txStatus == "voided" {
		return time.Time{}, apperr.Rule("transaction_voided", "A voided transaction cannot back a contribution.", nil)
	}
	if txCur != cur {
		return time.Time{}, apperr.FieldError("body.transaction_id", "The transaction must be in the goal currency ("+cur+").")
	}
	if amount > txAmt {
		return time.Time{}, apperr.FieldError("body.amount", "The contribution cannot exceed the linked transaction.")
	}
	return dateOnly(txDate), nil
}

// withinSaved rejects a withdrawal above the amount saved.
func withinSaved(ctx context.Context, tx pgx.Tx, g *goalRow, amount int64) error {
	if err := totals(ctx, tx, g); err != nil {
		return err
	}
	if amount > g.savedMinor {
		return apperr.Rule("withdrawal_exceeds_saved", "A withdrawal cannot exceed the amount saved ("+money.Format(g.savedMinor, g.cur)+").",
			map[string]string{"saved": money.Format(g.savedMinor, g.cur), "currency": g.cur})
	}
	return nil
}

func (s *Service) addContribution(ctx context.Context, tx pgx.Tx, uid, goalID uuid.UUID, in GoalContributionInput) (uuid.UUID, error) {
	g, err := lockForContribution(ctx, tx, goalID)
	if err != nil {
		return uuid.Nil, err
	}
	kind := in.Kind
	if kind == "" {
		kind = "contribution"
	}
	if err := acceptsContributions(g, kind); err != nil {
		return uuid.Nil, err
	}
	amount, err := finance.ParseAmount("body.amount", in.Amount, g.cur)
	if err != nil {
		return uuid.Nil, err
	}
	u, err := finance.LoadUser(ctx, tx, uid)
	if err != nil {
		return uuid.Nil, err
	}
	on := localToday(s.now(), u.Loc)
	if in.ContributedOn != "" {
		d, err := finance.ParseDate("body.contributed_on", in.ContributedOn, u.Loc)
		if err != nil {
			return uuid.Nil, err
		}
		on = dateOnly(d)
	}
	status := in.Status
	if status == "" {
		status = "recorded"
	}
	if status != "planned" && on.After(localToday(s.now(), u.Loc)) {
		return uuid.Nil, apperr.FieldError("body.contributed_on", "A recorded contribution cannot be in the future; mark it as planned instead.")
	}
	if in.TransactionID != nil {
		if status == "planned" {
			return uuid.Nil, apperr.FieldError("body.status", "A linked transaction is an actual movement, not a plan.")
		}
		txDate, err := backingTransaction(ctx, tx, uid, *in.TransactionID, g.cur, amount)
		if err != nil {
			return uuid.Nil, err
		}
		status = "verified"
		if in.ContributedOn == "" {
			on = txDate
		}
	}
	if kind == "withdrawal" && status != "planned" {
		if err := withinSaved(ctx, tx, g, amount); err != nil {
			return uuid.Nil, err
		}
	}
	id := uuid.New()
	if _, err := tx.Exec(ctx, `insert into goal_contributions (id, goal_id, user_id, kind, amount_minor, currency, status, transaction_id,
		contributed_on, note) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`, id, goalID, uid, kind, amount, g.cur, status, in.TransactionID,
		on, trim(in.Note, 500)); err != nil {
		if database.IsUniqueViolation(err, "goal_contributions_tx_key") {
			return uuid.Nil, errAlreadyCounted()
		}
		return uuid.Nil, err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &g.owner, ActorUserID: &uid, EntityType: "goal_contribution", EntityID: &id, Action: "created",
		Changes: map[string]any{"goal_id": goalID, "kind": kind, "status": status}}); err != nil {
		return uuid.Nil, err
	}
	return id, s.evaluate(ctx, tx, goalID)
}

// GoalContributionRecordInput turns a planned contribution into a recorded
// one.
type GoalContributionRecordInput struct {
	TransactionID *uuid.UUID `json:"transaction_id,omitempty" doc:"Your ledger transaction that moved the money: the contribution becomes verified (each transaction counts once)"`
	Amount        string     `json:"amount,omitempty" doc:"The amount actually set aside, when it differs from the plan (decimal); default the planned amount"`
	ContributedOn string     `json:"contributed_on,omitempty" doc:"YYYY-MM-DD; default the linked transaction's date, otherwise today. Never in the future"`
}

// RecordContribution turns the caller's planned contribution (or planned
// withdrawal) into a recorded one, or a verified one with a transaction.
// The same row changes status, so it is counted exactly once (idempotent
// per key).
func (s *Service) RecordContribution(ctx context.Context, key string, goalID, id uuid.UUID, in GoalContributionRecordInput) (*GoalContributionDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out GoalContributionDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "goal.contribution_record", struct {
			Goal, ID uuid.UUID
			In       GoalContributionRecordInput
		}{goalID, id, in}, func() (GoalContributionDTO, error) {
			if err := s.recordContribution(ctx, tx, uid, goalID, id, in); err != nil {
				return GoalContributionDTO{}, err
			}
			list, err := s.contributions(ctx, tx, uid, goalID, &id, nil)
			if err != nil {
				return GoalContributionDTO{}, err
			}
			return list[0], nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

func (s *Service) recordContribution(ctx context.Context, tx pgx.Tx, uid, goalID, id uuid.UUID, in GoalContributionRecordInput) error {
	g, err := lockForContribution(ctx, tx, goalID)
	if err != nil {
		return err
	}
	var kind, status string
	var amount int64
	var voided bool
	if err := tx.QueryRow(ctx, `select kind, status, amount_minor, voided_at is not null from goal_contributions
		where id = $1 and goal_id = $2 and user_id = $3 for update`, id, goalID, uid).Scan(&kind, &status, &amount, &voided); err != nil {
		if database.IsNoRows(err) {
			return apperr.NotFound("contribution")
		}
		return err
	}
	if voided {
		return apperr.ConflictCode("contribution_voided", "This contribution was voided.", nil)
	}
	if status != "planned" {
		return apperr.ConflictCode("contribution_not_planned", "This contribution is already "+status+".", map[string]string{"status": status})
	}
	if err := acceptsContributions(g, kind); err != nil {
		return err
	}
	if in.Amount != "" {
		if amount, err = finance.ParseAmount("body.amount", in.Amount, g.cur); err != nil {
			return err
		}
	}
	u, err := finance.LoadUser(ctx, tx, uid)
	if err != nil {
		return err
	}
	today := localToday(s.now(), u.Loc)
	on := today
	if in.ContributedOn != "" {
		d, err := finance.ParseDate("body.contributed_on", in.ContributedOn, u.Loc)
		if err != nil {
			return err
		}
		if on = dateOnly(d); on.After(today) {
			return apperr.FieldError("body.contributed_on", "A recorded contribution cannot be in the future.")
		}
	}
	status = "recorded"
	if in.TransactionID != nil {
		txDate, err := backingTransaction(ctx, tx, uid, *in.TransactionID, g.cur, amount)
		if err != nil {
			return err
		}
		status = "verified"
		if in.ContributedOn == "" {
			on = txDate
		}
	}
	if kind == "withdrawal" {
		if err := withinSaved(ctx, tx, g, amount); err != nil {
			return err
		}
	}
	if _, err := tx.Exec(ctx, `update goal_contributions set status = $2, amount_minor = $3, contributed_on = $4, transaction_id = $5
		where id = $1`, id, status, amount, on, in.TransactionID); err != nil {
		if database.IsUniqueViolation(err, "goal_contributions_tx_key") {
			return errAlreadyCounted()
		}
		return err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &g.owner, ActorUserID: &uid, EntityType: "goal_contribution", EntityID: &id, Action: "recorded",
		Changes: map[string]any{"goal_id": goalID, "kind": kind, "from": "planned", "to": status}}); err != nil {
		return err
	}
	return s.evaluate(ctx, tx, goalID)
}

// contributions lists contributions honoring each contributor's visibility
// choice (amounts, percent only, or hidden from others); the owner's choice
// is stored on the goal.
// contribPage selects one page of a goal's contributions (newest first).
// A nil page means every contribution (exports, single lookups).
type contribPage struct {
	cursor string
	limit  int
	next   string // set when more contributions follow
}

type contribCursor struct {
	D  string    `json:"d"`
	C  time.Time `json:"c"`
	ID uuid.UUID `json:"i"`
}

func (s *Service) contributions(ctx context.Context, tx pgx.Tx, me, goalID uuid.UUID, only *uuid.UUID, page *contribPage) ([]GoalContributionDTO, error) {
	var after *contribCursor
	limit := -1
	if page != nil {
		limit = page.limit
		if limit <= 0 || limit > 500 {
			limit = 500
		}
		if page.cursor != "" {
			after = &contribCursor{}
			if err := httpx.DecodeCursor(page.cursor, after); err != nil {
				return nil, err
			}
		}
	}
	var target int64
	var cur, ownerVis string
	var owner uuid.UUID
	if err := tx.QueryRow(ctx, `select target_amount_minor, currency, owner_user_id, owner_contribution_visibility from goals where id = $1`, goalID).
		Scan(&target, &cur, &owner, &ownerVis); err != nil {
		if database.IsNoRows(err) {
			return nil, apperr.NotFound("goal")
		}
		return nil, err
	}
	rows, err := tx.Query(ctx, `select c.id, c.user_id, p.display_name, c.kind, c.amount_minor, c.status, c.transaction_id,
		c.contributed_on, c.note, c.voided_at is not null, c.created_at, coalesce(m.contribution_visibility, 'amounts')
		from goal_contributions c left join profiles p on p.user_id = c.user_id
		left join goal_members m on m.goal_id = c.goal_id and m.user_id = c.user_id
		where c.goal_id = $1 and ($2::uuid is null or c.id = $2)
		and ($3::date is null or (c.contributed_on, c.created_at, c.id) < ($3::date, $4, $5))
		order by c.contributed_on desc, c.created_at desc, c.id desc limit nullif($6, -1)`,
		goalID, only, cursorDate(after), cursorTime(after), cursorID(after), limitPlusOne(limit))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []GoalContributionDTO{}
	scanned := 0
	for rows.Next() {
		var c GoalContributionDTO
		var amt int64
		var d time.Time
		var vis string
		if err := rows.Scan(&c.ID, &c.UserID, &c.DisplayName, &c.Kind, &amt, &c.Status, &c.TransactionID, &d, &c.Note, &c.Voided, &c.CreatedAt, &vis); err != nil {
			return nil, err
		}
		scanned++
		if limit > 0 && scanned > limit {
			break // the extra row only tells that another page exists
		}
		if page != nil && limit > 0 && scanned == limit {
			// The cursor follows the last row read (hidden rows included),
			// so pages never skip or repeat rows.
			page.next, _ = httpx.EncodeCursor(contribCursor{D: finance.LocalDateString(d), C: c.CreatedAt, ID: c.ID})
		}
		c.ContributedOn, c.Mine = finance.LocalDateString(d), c.UserID == me
		if c.UserID == owner {
			vis = ownerVis
		}
		switch {
		case c.Mine || vis == "amounts":
			a := apitypes.M(amt, cur)
			c.Amount = &a
		case vis == "percent_only":
			p := money.PercentBasisPoints(amt, target)
			c.PercentBP, c.TransactionID, c.Note = &p, nil, nil
		default:
			continue // hidden from others (still counted in totals)
		}
		if !c.Mine {
			c.TransactionID = nil // never expose other users' ledger references
		}
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if page != nil && scanned <= limit {
		page.next = "" // no row beyond this page
	}
	return out, nil
}

func cursorDate(c *contribCursor) *string {
	if c == nil {
		return nil
	}
	return &c.D
}

func cursorTime(c *contribCursor) *time.Time {
	if c == nil {
		return nil
	}
	return &c.C
}

func cursorID(c *contribCursor) *uuid.UUID {
	if c == nil {
		return nil
	}
	return &c.ID
}

// limitPlusOne asks for one extra row to learn whether another page exists
// (-1 = no limit).
func limitPlusOne(limit int) int {
	if limit < 0 {
		return -1
	}
	return limit + 1
}

// ListContributions returns the contribution history.
func (s *Service) ListContributions(ctx context.Context, goalID uuid.UUID, cursor string, limit int) ([]GoalContributionDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	page := &contribPage{cursor: cursor, limit: limit}
	var out []GoalContributionDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var access *string
		if err := tx.QueryRow(ctx, `select montra.goal_access($1)`, goalID).Scan(&access); err != nil {
			return err
		}
		if access == nil {
			return apperr.NotFound("goal")
		}
		out, err = s.contributions(ctx, tx, uid, goalID, nil, page)
		return err
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	return out, page.next, nil
}

// VoidContribution voids the caller's own contribution (kept for audit).
func (s *Service) VoidContribution(ctx context.Context, goalID, id uuid.UUID) (*GoalDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GoalDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update goal_contributions set voided_at = now() where id = $1 and goal_id = $2 and user_id = $3 and voided_at is null`,
			id, goalID, uid)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("contribution")
		}
		var owner uuid.UUID
		if err := tx.QueryRow(ctx, `select owner_user_id from goals where id = $1`, goalID).Scan(&owner); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &owner, ActorUserID: &uid, EntityType: "goal_contribution", EntityID: &id, Action: "voided"}); err != nil {
			return err
		}
		if err := s.evaluate(ctx, tx, goalID); err != nil {
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
