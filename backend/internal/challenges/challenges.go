// Package challenges implements opt-in challenges (spec §4.16, §20B.17):
// no-spend days, savings streaks, grocery budgets, meal planning, travel
// savings and custom goals, for one person, a group or a community.
// Progress is self-reported in days, streaks, milestones or percent — never
// money — and is private unless the participant shares it; leaderboards
// show only people who opted in, ranked by percentage of the target.
package challenges

import (
	"context"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/textsafe"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// Service implements challenges.
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

// EventCompleted notifies a participant who reached the target.
const EventCompleted = "challenge.completed"

// EventMilestone notifies a participant who first passed halfway.
const EventMilestone = "challenge.milestone"

// ChallengeInput creates a challenge.
type ChallengeInput struct {
	Title              string     `json:"title" minLength:"3" maxLength:"120"`
	Description        string     `json:"description,omitempty" maxLength:"2000"`
	ChallengeType      string     `json:"challenge_type" enum:"no_spend,savings_streak,grocery_budget,meal_planning,travel_savings,custom"`
	Rules              string     `json:"rules,omitempty" maxLength:"2000"`
	Metric             string     `json:"metric" enum:"days,streak,milestones,percent" doc:"days: days checked in; streak: longest run of consecutive days; milestones: total check-ins; percent: your latest self-reported percentage"`
	TargetValue        int        `json:"target_value" minimum:"1" maximum:"3650" doc:"percent targets are at most 100"`
	StartsOn           string     `json:"starts_on" doc:"YYYY-MM-DD"`
	EndsOn             string     `json:"ends_on" doc:"YYYY-MM-DD; at most a year after the start"`
	Visibility         string     `json:"visibility,omitempty" enum:"private,group,community,public" doc:"public challenges are created by Montra staff"`
	GroupID            *uuid.UUID `json:"group_id,omitempty"`
	CommunityID        *uuid.UUID `json:"community_id,omitempty"`
	LeaderboardEnabled bool       `json:"leaderboard_enabled,omitempty" doc:"Only participants who opt in appear"`
}

// ChallengePatch edits a challenge (its creator). Only the fields sent
// change; description and rules are cleared with an empty string.
type ChallengePatch struct {
	Title              *string `json:"title,omitempty" minLength:"3" maxLength:"120"`
	Description        *string `json:"description,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	Rules              *string `json:"rules,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	EndsOn             *string `json:"ends_on,omitempty" doc:"YYYY-MM-DD; can only move later, within a year of the start"`
	LeaderboardEnabled *bool   `json:"leaderboard_enabled,omitempty" doc:"Private challenges have no leaderboard"`
	Version            int32   `json:"version" minimum:"1" doc:"Current version (409 VERSION_CONFLICT when stale)"`
}

// ChallengeScopeRef names the group or community a challenge belongs to.
type ChallengeScopeRef struct {
	ID   uuid.UUID `json:"id"`
	Name string    `json:"name"`
}

// ChallengeParticipationDTO is the caller's participation.
type ChallengeParticipationDTO struct {
	Status            string     `json:"status" enum:"active,completed,left"`
	ShareProgress     bool       `json:"share_progress"`
	ShowOnLeaderboard bool       `json:"show_on_leaderboard"`
	ProgressValue     int        `json:"progress_value"`
	PercentComplete   int        `json:"percent_complete" doc:"0-100"`
	CurrentStreak     int        `json:"current_streak"`
	BestStreak        int        `json:"best_streak"`
	JoinedAt          time.Time  `json:"joined_at"`
	CompletedAt       *time.Time `json:"completed_at,omitempty"`
}

// ChallengeDTO is a challenge.
type ChallengeDTO struct {
	ID                 uuid.UUID                  `json:"id"`
	Title              string                     `json:"title"`
	Description        *string                    `json:"description,omitempty"`
	ChallengeType      string                     `json:"challenge_type"`
	Rules              *string                    `json:"rules,omitempty"`
	Metric             string                     `json:"metric" enum:"days,streak,milestones,percent"`
	TargetValue        int                        `json:"target_value"`
	StartsOn           string                     `json:"starts_on"`
	EndsOn             string                     `json:"ends_on"`
	Visibility         string                     `json:"visibility" enum:"private,group,community,public"`
	GroupID            *uuid.UUID                 `json:"group_id,omitempty"`
	Group              *ChallengeScopeRef         `json:"group,omitempty" doc:"The group, shown to its members only"`
	CommunityID        *uuid.UUID                 `json:"community_id,omitempty"`
	Community          *ChallengeScopeRef         `json:"community,omitempty" doc:"The community, shown when you may see it (listed communities; invite-only ones to members)"`
	LeaderboardEnabled bool                       `json:"leaderboard_enabled"`
	Status             string                     `json:"status" enum:"draft,active,completed,cancelled"`
	Ended              bool                       `json:"ended" doc:"The end date has passed"`
	ParticipantCount   int                        `json:"participant_count"`
	Mine               bool                       `json:"mine" doc:"You created it"`
	Me                 *ChallengeParticipationDTO `json:"me,omitempty" doc:"Your participation"`
	Version            int32                      `json:"version" doc:"Send it with PATCH (409 VERSION_CONFLICT when stale)"`
	CreatedAt          time.Time                  `json:"created_at"`
}

const challengeCols = `c.id, c.title, c.description, c.challenge_type, c.rules, c.metric, c.target_value, c.starts_on, c.ends_on, c.visibility,
	c.group_id, c.community_id, c.leaderboard_enabled, c.status, montra.challenge_participant_count(c.id), c.created_by, c.created_at, c.version,
	g.name, cm.name,
	p.status, p.share_progress, p.show_on_leaderboard, p.progress_value, p.current_streak, p.best_streak, p.joined_at, p.completed_at`

// challengeFrom joins the caller's ($1) participation and, under RLS, the
// group and community: a group's name shows only to its members (and its
// creator), a community's to whoever may see that community.
const challengeFrom = ` from challenges c
	left join challenge_participants p on p.challenge_id = c.id and p.user_id = $1
	left join groups g on g.id = c.group_id
	left join communities cm on cm.id = c.community_id`

func (s *Service) scan(r pgx.Row, me uuid.UUID, today time.Time) (*ChallengeDTO, error) {
	var c ChallengeDTO
	var start, end time.Time
	var creator *uuid.UUID
	var groupName, communityName *string
	var pStatus *string
	var share, show *bool
	var progress, cur, best *int
	var joined *time.Time
	var completed *time.Time
	if err := r.Scan(&c.ID, &c.Title, &c.Description, &c.ChallengeType, &c.Rules, &c.Metric, &c.TargetValue, &start, &end, &c.Visibility, &c.GroupID,
		&c.CommunityID, &c.LeaderboardEnabled, &c.Status, &c.ParticipantCount, &creator, &c.CreatedAt, &c.Version, &groupName, &communityName,
		&pStatus, &share, &show, &progress, &cur, &best, &joined, &completed); err != nil {
		return nil, err
	}
	c.StartsOn, c.EndsOn = finance.LocalDateString(start), finance.LocalDateString(end)
	c.Ended = today.After(end)
	c.Mine = creator != nil && *creator == me
	if c.GroupID != nil && groupName != nil {
		c.Group = &ChallengeScopeRef{ID: *c.GroupID, Name: *groupName}
	}
	if c.CommunityID != nil && communityName != nil {
		c.Community = &ChallengeScopeRef{ID: *c.CommunityID, Name: *communityName}
	}
	if pStatus != nil {
		c.Me = &ChallengeParticipationDTO{Status: *pStatus, ShareProgress: *share, ShowOnLeaderboard: *show, ProgressValue: *progress, CurrentStreak: *cur,
			BestStreak: *best, JoinedAt: *joined, CompletedAt: completed, PercentComplete: percent(*progress, c.TargetValue)}
	}
	return &c, nil
}

func percent(v, target int) int {
	if target <= 0 {
		return 0
	}
	return min(100, v*100/target)
}

func (s *Service) today(ctx context.Context, tx pgx.Tx, uid uuid.UUID) (time.Time, *time.Location, error) {
	u, err := finance.LoadUser(ctx, tx, uid)
	if err != nil {
		return time.Time{}, nil, err
	}
	n := s.now().In(u.Loc)
	return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, time.UTC), u.Loc, nil
}

func (s *Service) load(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (*ChallengeDTO, error) {
	today, _, err := s.today(ctx, tx, me)
	if err != nil {
		return nil, err
	}
	c, err := s.scan(tx.QueryRow(ctx, `select `+challengeCols+challengeFrom+` where c.id = $2`, me, id), me, today)
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("challenge")
	}
	return c, err
}

// clean cleans plain text (nil when empty and optional). Problems carry
// the textsafe detail codes (too_short / too_long with min / max,
// required, invalid_characters, contains_secret).
func clean(field, s string, minR, maxR int) (*string, error) {
	out, err := textsafe.Clean(s, minR, maxR)
	if err != nil {
		code, params := textsafe.Problem(err, minR, maxR)
		return nil, apperr.FieldCode(field, code, "Use plain text within the length limit.", params)
	}
	if textsafe.Secret(out) {
		return nil, apperr.FieldCode(field, textsafe.CodeContainsSecret, "Never share card numbers, CVVs, PINs, OTPs or passwords.", nil)
	}
	if out == "" {
		return nil, nil
	}
	return &out, nil
}

// Create creates a challenge; the creator joins it (progress private).
func (s *Service) Create(ctx context.Context, in ChallengeInput) (*ChallengeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	title, err := clean("body.title", in.Title, 3, 120)
	if err != nil {
		return nil, err
	}
	desc, err := clean("body.description", in.Description, 0, 2000)
	if err != nil {
		return nil, err
	}
	rules, err := clean("body.rules", in.Rules, 0, 2000)
	if err != nil {
		return nil, err
	}
	if in.Metric == "percent" && in.TargetValue > 100 {
		return nil, apperr.FieldError("body.target_value", "A percentage target is at most 100.")
	}
	vis := in.Visibility
	if vis == "" {
		vis = "private"
		if in.GroupID != nil {
			vis = "group"
		} else if in.CommunityID != nil {
			vis = "community"
		}
	}
	var out *ChallengeDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		today, loc, err := s.today(ctx, tx, uid)
		if err != nil {
			return err
		}
		start, err := finance.ParseDate("body.starts_on", in.StartsOn, loc)
		if err != nil {
			return err
		}
		end, err := finance.ParseDate("body.ends_on", in.EndsOn, loc)
		if err != nil {
			return err
		}
		start, end = dateOnly(start), dateOnly(end)
		if end.Before(start) || end.Sub(start) > 366*24*time.Hour {
			return apperr.FieldError("body.ends_on", "End on or after the start, within a year.")
		}
		if end.Before(today) {
			return apperr.FieldError("body.ends_on", "The challenge would already be over.")
		}
		switch vis {
		case "private":
			if in.GroupID != nil || in.CommunityID != nil {
				return apperr.FieldError("body.visibility", "Private challenges belong to no group or community.")
			}
		case "group":
			var ok bool
			if in.GroupID == nil || in.CommunityID != nil {
				return apperr.FieldError("body.group_id", "Choose the group.")
			}
			if err := tx.QueryRow(ctx, `select montra.is_group_member($1)`, *in.GroupID).Scan(&ok); err != nil {
				return err
			}
			if !ok {
				return apperr.FieldError("body.group_id", "Choose a group you belong to.")
			}
		case "community":
			var ok bool
			var sanction *string
			if in.CommunityID == nil || in.GroupID != nil {
				return apperr.FieldError("body.community_id", "Choose the community.")
			}
			if err := tx.QueryRow(ctx, `select exists (select 1 from community_members m join communities c on c.id = m.community_id
				where m.community_id = $1 and m.user_id = $2 and m.status = 'active' and c.status = 'active'
				and (m.restricted_until is null or m.restricted_until < now())), montra.my_community_sanction()`, *in.CommunityID, uid).
				Scan(&ok, &sanction); err != nil {
				return err
			}
			if !ok || sanction != nil {
				return apperr.FieldError("body.community_id", "Choose an active community you can post in.")
			}
		case "public":
			var staff bool
			if err := tx.QueryRow(ctx, `select montra.current_platform_role() in ('admin','support')`).Scan(&staff); err != nil {
				return err
			}
			if !staff {
				return apperr.FieldError("body.visibility", "Share challenges through a group or community; public challenges are curated by Montra.")
			}
		}
		if err := caps.Daily(ctx, tx, uid, "challenges", `select created_at from challenges where created_by = $1
			and created_at > now() - interval '1 day'`, MaxChallengesPerDay); err != nil {
			return err
		}
		id := uuid.New()
		if _, err := tx.Exec(ctx, `insert into challenges (id, community_id, group_id, created_by, title, description, challenge_type, rules, metric,
			target_value, starts_on, ends_on, visibility, leaderboard_enabled) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
			id, in.CommunityID, in.GroupID, uid, *title, desc, in.ChallengeType, rules, in.Metric, in.TargetValue, start, end, vis,
			in.LeaderboardEnabled && vis != "private"); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into challenge_participants (challenge_id, user_id) values ($1,$2)`, id, uid); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "challenge", EntityID: &id, Action: "created"}); err != nil {
			return err
		}
		out, err = s.load(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// MaxChallengesPerDay caps how many challenges one person creates in a
// rolling 24 hours (429 daily_cap).
const MaxChallengesPerDay = 10

// List page sizes.
const (
	defaultListPage = 50
	maxListPage     = 200
)

// challengeCursor is a position in the list order: active challenges
// first, then by end date, title and ID.
type challengeCursor struct {
	Inactive bool      `json:"i"`
	EndsOn   string    `json:"e"`
	Title    string    `json:"t"`
	ID       uuid.UUID `json:"d"`
}

// List lists challenges, a page at a time: "mine" (joined or created) or
// "discover" (visible to you and open to join), optionally for a group or
// community. It returns the next page's cursor ("" on the last page).
func (s *Service) List(ctx context.Context, scope string, groupID, communityID *uuid.UUID, cursor string, limit int) ([]ChallengeDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > maxListPage {
		limit = defaultListPage
	}
	var cur challengeCursor
	if err := httpx.DecodeCursor(cursor, &cur); err != nil {
		return nil, "", err
	}
	var after *bool
	var afterEnd *time.Time
	if cursor != "" {
		end, err := time.Parse("2006-01-02", cur.EndsOn)
		if err != nil {
			return nil, "", apperr.FieldError("query.cursor", "Invalid cursor. Start again from the first page.")
		}
		after, afterEnd = &cur.Inactive, &end
	}
	out := []ChallengeDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		today, _, err := s.today(ctx, tx, uid)
		if err != nil {
			return err
		}
		// $2 (today) is used by discover; the cast keeps it typed for "mine"
		// so the statement prepares either way.
		where := `(p.user_id is not null or c.created_by = $1) and $2::date is not null`
		if scope == "discover" {
			where = `c.status = 'active' and c.ends_on >= $2 and (p.user_id is null or p.status = 'left') and c.visibility <> 'private'`
		}
		rows, err := tx.Query(ctx, `select `+challengeCols+challengeFrom+`
			where `+where+` and ($3::uuid is null or c.group_id = $3) and ($4::uuid is null or c.community_id = $4)
			and ($5::boolean is null or (c.status <> 'active', c.ends_on, c.title, c.id) > ($5, $6::date, $7::text, $8::uuid))
			order by c.status <> 'active', c.ends_on, c.title, c.id limit $9`,
			uid, today, groupID, communityID, after, afterEnd, cur.Title, cur.ID, limit+1)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			c, err := s.scan(rows, uid, today)
			if err != nil {
				return err
			}
			out = append(out, *c)
		}
		if err := rows.Err(); err != nil {
			return err
		}
		if len(out) > limit {
			last := out[limit-1]
			if next, err = httpx.EncodeCursor(challengeCursor{Inactive: last.Status != "active", EndsOn: last.EndsOn, Title: last.Title, ID: last.ID}); err != nil {
				return err
			}
			out = out[:limit]
		}
		return nil
	})
	return out, next, database.MapError(err)
}

// Get returns a challenge visible to the caller.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*ChallengeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ChallengeDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		out, err = s.load(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Update edits a challenge (its creator): only the fields sent change, and
// the version sent must be current.
func (s *Service) Update(ctx context.Context, id uuid.UUID, in ChallengePatch) (*ChallengeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var title, desc, rules *string
	if in.Title != nil {
		if title, err = clean("body.title", *in.Title, 3, 120); err != nil {
			return nil, err
		}
	}
	if in.Description != nil {
		if desc, err = clean("body.description", *in.Description, 0, 2000); err != nil {
			return nil, err
		}
	}
	if in.Rules != nil {
		if rules, err = clean("body.rules", *in.Rules, 0, 2000); err != nil {
			return nil, err
		}
	}
	var out *ChallengeDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := s.load(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if !c.Mine {
			return apperr.Forbidden()
		}
		var version int32
		if err := tx.QueryRow(ctx, `select version from challenges where id = $1 for update`, id).Scan(&version); err != nil {
			return err
		}
		if version != in.Version {
			return apperr.VersionConflict()
		}
		if c.Status != "active" {
			return apperr.Rule("challenge_inactive", "This challenge is no longer active.", nil)
		}
		if in.Title != nil {
			c.Title = *title
		}
		if in.Description != nil {
			c.Description = desc
		}
		if in.Rules != nil {
			c.Rules = rules
		}
		if in.LeaderboardEnabled != nil {
			c.LeaderboardEnabled = *in.LeaderboardEnabled && c.Visibility != "private"
		}
		end, _ := time.Parse("2006-01-02", c.EndsOn)
		if in.EndsOn != nil {
			e, err := finance.ParseDate("body.ends_on", *in.EndsOn, time.UTC)
			if err != nil {
				return err
			}
			start, _ := time.Parse("2006-01-02", c.StartsOn)
			if dateOnly(e).Before(end) || dateOnly(e).Sub(start) > 366*24*time.Hour {
				return apperr.FieldError("body.ends_on", "The end can only move later, within a year of the start.")
			}
			end = dateOnly(e)
		}
		if _, err := tx.Exec(ctx, `update challenges set title = $2, description = $3, rules = $4, ends_on = $5, leaderboard_enabled = $6,
			version = version + 1 where id = $1`, id, c.Title, c.Description, c.Rules, end, c.LeaderboardEnabled); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "challenge", EntityID: &id, Action: "updated"}); err != nil {
			return err
		}
		out, err = s.load(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Cancel cancels a challenge (its creator, or the community's moderators).
func (s *Service) Cancel(ctx context.Context, id uuid.UUID) (*ChallengeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ChallengeDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := s.load(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		allowed := c.Mine
		if !allowed && c.CommunityID != nil {
			if err := tx.QueryRow(ctx, `select montra.is_community_moderator($1)`, *c.CommunityID).Scan(&allowed); err != nil {
				return err
			}
		}
		if !allowed {
			return apperr.Forbidden()
		}
		if _, err := tx.Exec(ctx, `update challenges set status = 'cancelled', version = version + 1 where id = $1 and status in ('draft','active')`, id); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{ActorUserID: &uid, EntityType: "challenge", EntityID: &id, Action: "cancelled"}); err != nil {
			return err
		}
		out, err = s.load(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// ChallengeJoinInput sets sharing when joining.
type ChallengeJoinInput struct {
	ShareProgress     bool `json:"share_progress,omitempty" doc:"Let others in the challenge see your progress percentage (off by default)"`
	ShowOnLeaderboard bool `json:"show_on_leaderboard,omitempty" doc:"Appear on the leaderboard (needs share_progress)"`
}

// Join joins (or rejoins) a challenge.
func (s *Service) Join(ctx context.Context, id uuid.UUID, in ChallengeJoinInput) (*ChallengeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if in.ShowOnLeaderboard && !in.ShareProgress {
		return nil, apperr.FieldCode("body.show_on_leaderboard", "share_required", "Share your progress to appear on the leaderboard.", nil)
	}
	var out *ChallengeDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := s.load(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if c.Status != "active" || c.Ended {
			return apperr.Rule("challenge_not_open", "This challenge is not open.", nil)
		}
		if c.Me != nil && c.Me.Status != "left" {
			return apperr.Conflict("You already joined.")
		}
		if c.CommunityID != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select montra.is_community_member($1)`, *c.CommunityID).Scan(&ok); err != nil {
				return err
			}
			if !ok {
				return apperr.Rule("join_community_first", "Join the community to take part.", nil)
			}
		}
		if c.Me != nil {
			_, err = tx.Exec(ctx, `update challenge_participants set status = 'active', share_progress = $3, show_on_leaderboard = $4
				where challenge_id = $1 and user_id = $2`, id, uid, in.ShareProgress, in.ShowOnLeaderboard)
		} else {
			_, err = tx.Exec(ctx, `insert into challenge_participants (challenge_id, user_id, share_progress, show_on_leaderboard) values ($1,$2,$3,$4)`,
				id, uid, in.ShareProgress, in.ShowOnLeaderboard)
		}
		if err != nil {
			return err
		}
		out, err = s.load(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// UpdateParticipation changes the caller's sharing choices.
func (s *Service) UpdateParticipation(ctx context.Context, id uuid.UUID, in ChallengeJoinInput) (*ChallengeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if in.ShowOnLeaderboard && !in.ShareProgress {
		return nil, apperr.FieldCode("body.show_on_leaderboard", "share_required", "Share your progress to appear on the leaderboard.", nil)
	}
	var out *ChallengeDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update challenge_participants set share_progress = $3, show_on_leaderboard = $4 where challenge_id = $1 and user_id = $2`,
			id, uid, in.ShareProgress, in.ShowOnLeaderboard)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("participation")
		}
		out, err = s.load(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Leave leaves a challenge (progress is kept privately).
func (s *Service) Leave(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update challenge_participants set status = 'left', show_on_leaderboard = false where challenge_id = $1 and user_id = $2
			and status <> 'left'`, id, uid)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("participation")
		}
		return nil
	}))
}

// ChallengeProgressInput records one day's check-in.
type ChallengeProgressInput struct {
	Date  string `json:"date,omitempty" doc:"YYYY-MM-DD, default today; within the challenge dates and not in the future"`
	Value *int   `json:"value,omitempty" minimum:"0" maximum:"3650" doc:"days/streak: 1 = done, 0 = missed; milestones: count; percent: 0-100. Default 1"`
	Note  string `json:"note,omitempty" maxLength:"300" doc:"Private to you"`
}

// RecordProgress records (or corrects) a day's check-in and recomputes
// progress and streaks from all check-ins.
func (s *Service) RecordProgress(ctx context.Context, id uuid.UUID, in ChallengeProgressInput) (*ChallengeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	note, err := clean("body.note", in.Note, 0, 300)
	if err != nil {
		return nil, err
	}
	value := 1
	if in.Value != nil {
		value = *in.Value
	}
	var out *ChallengeDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := s.load(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if c.Me == nil || c.Me.Status == "left" {
			return apperr.Rule("join_challenge_first", "Join the challenge first.", nil)
		}
		if c.Status == "cancelled" {
			return apperr.Rule("challenge_cancelled", "This challenge was cancelled.", nil)
		}
		if c.Metric == "percent" && value > 100 {
			return apperr.FieldError("body.value", "A percentage is at most 100.")
		}
		today, loc, err := s.today(ctx, tx, uid)
		if err != nil {
			return err
		}
		day := today
		if in.Date != "" {
			d, err := finance.ParseDate("body.date", in.Date, loc)
			if err != nil {
				return err
			}
			day = dateOnly(d)
		}
		start, _ := time.Parse("2006-01-02", c.StartsOn)
		end, _ := time.Parse("2006-01-02", c.EndsOn)
		if day.Before(start) || day.After(end) || day.After(today) {
			return apperr.FieldError("body.date", "Check in for a day within the challenge, up to today.")
		}
		if _, err := tx.Exec(ctx, `insert into challenge_progress_events (challenge_id, user_id, recorded_on, value, note) values ($1,$2,$3,$4,$5)
			on conflict (challenge_id, user_id, recorded_on) do update set value = excluded.value, note = excluded.note`, id, uid, day, value, note); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select recorded_on, value from challenge_progress_events where challenge_id = $1 and user_id = $2 order by recorded_on`, id, uid)
		if err != nil {
			return err
		}
		type ev struct {
			day   time.Time
			value int
		}
		evs, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (ev, error) {
			var e ev
			err := r.Scan(&e.day, &e.value)
			return e, err
		})
		if err != nil {
			return err
		}
		days := make([]time.Time, 0, len(evs))
		total, latest := 0, 0
		for _, e := range evs {
			if e.value > 0 {
				days = append(days, dateOnly(e.day))
			}
			total += e.value
			latest = e.value
		}
		cur, best := Streaks(days, today)
		progress := map[string]int{"days": len(days), "streak": best, "milestones": total, "percent": latest}[c.Metric]
		completed := progress >= c.TargetValue && c.Me.Status != "completed"
		if _, err := tx.Exec(ctx, `update challenge_participants set progress_value = $3, current_streak = $4, best_streak = $5,
			status = case when $6 then 'completed' else status end, completed_at = case when $6 then now() else completed_at end
			where challenge_id = $1 and user_id = $2`, id, uid, min(progress, 1_000_000), cur, best, completed); err != nil {
			return err
		}
		if completed {
			if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventCompleted, AggregateType: "challenge", AggregateID: id, UserID: &uid}); err != nil {
				return err
			}
		} else if before, after := c.Me.PercentComplete, percent(progress, c.TargetValue); before < 50 && after >= 50 && after < 100 {
			if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventMilestone, AggregateType: "challenge", AggregateID: id, UserID: &uid,
				Payload: map[string]any{"percent": 50}}); err != nil {
				return err
			}
		}
		out, err = s.load(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Streaks returns the current streak (consecutive check-in days ending
// today or yesterday) and the best streak from sorted, distinct days.
func Streaks(days []time.Time, today time.Time) (current, best int) {
	sort.Slice(days, func(i, j int) bool { return days[i].Before(days[j]) })
	run := 0
	var prev time.Time
	for i, d := range days {
		if i > 0 && d.Equal(prev) {
			continue
		}
		if i > 0 && d.Sub(prev) == 24*time.Hour {
			run++
		} else {
			run = 1
		}
		best = max(best, run)
		prev = d
	}
	if len(days) > 0 && (prev.Equal(today) || prev.Equal(today.AddDate(0, 0, -1))) {
		current = run
	}
	return current, best
}

// ChallengeLeaderboardEntry is one opted-in participant.
type ChallengeLeaderboardEntry struct {
	Rank            int    `json:"rank"`
	DisplayName     string `json:"display_name"`
	Username        string `json:"username,omitempty"`
	PercentComplete int    `json:"percent_complete" doc:"Normalized progress; raw values are never shown"`
	CurrentStreak   int    `json:"current_streak"`
	Completed       bool   `json:"completed"`
	IsMe            bool   `json:"is_me"`
}

// Leaderboard lists participants who chose to appear, by percentage.
func (s *Service) Leaderboard(ctx context.Context, id uuid.UUID) ([]ChallengeLeaderboardEntry, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []ChallengeLeaderboardEntry{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := s.load(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if !c.LeaderboardEnabled {
			return apperr.Rule("no_leaderboard", "This challenge has no leaderboard.", nil)
		}
		// Seeing the leaderboard is mutual: only participants who chose to
		// appear on it can look at it (never the client's choice alone).
		if c.Me == nil || c.Me.Status == "left" || !c.Me.ShareProgress || !c.Me.ShowOnLeaderboard {
			return apperr.Rule("leaderboard_opt_in_required", "Join the challenge and choose to appear on the leaderboard to see it.", nil)
		}
		rows, err := tx.Query(ctx, `select p.user_id, p.progress_value, p.current_streak, p.status = 'completed', coalesce(mp.display_name, 'Montra user'),
			coalesce(mp.username, '')
			from challenge_participants p left join lateral montra.challenge_participant_profile(p.challenge_id, p.user_id) mp on true
			where p.challenge_id = $1 and p.status <> 'left' and p.share_progress and p.show_on_leaderboard
			and not montra.is_blocked_between($2, p.user_id)`, id, uid)
		if err != nil {
			return err
		}
		type row struct {
			user           uuid.UUID
			progress, cur  int
			done           bool
			name, username string
		}
		list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (row, error) {
			var x row
			err := r.Scan(&x.user, &x.progress, &x.cur, &x.done, &x.name, &x.username)
			return x, err
		})
		if err != nil {
			return err
		}
		sort.SliceStable(list, func(i, j int) bool {
			pi, pj := percent(list[i].progress, c.TargetValue), percent(list[j].progress, c.TargetValue)
			if pi != pj {
				return pi > pj
			}
			if list[i].cur != list[j].cur {
				return list[i].cur > list[j].cur
			}
			return strings.ToLower(list[i].name) < strings.ToLower(list[j].name)
		})
		for i, x := range list {
			out = append(out, ChallengeLeaderboardEntry{Rank: i + 1, DisplayName: x.name, Username: x.username, PercentComplete: percent(x.progress, c.TargetValue),
				CurrentStreak: x.cur, Completed: x.done, IsMe: x.user == uid})
		}
		return nil
	})
	return out, database.MapError(err)
}
