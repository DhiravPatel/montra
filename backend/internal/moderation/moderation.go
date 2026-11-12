// Package moderation implements reports, moderator queues, auditable
// moderation actions with reversal, account sanctions and appeals (spec
// §4.16, §20B.17). Community moderators act on their community's content
// and members; platform staff handle profile, group and community reports
// and platform-wide sanctions. Moderators never gain access to private
// financial records: every target is community content or membership.
package moderation

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/textsafe"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// Service implements moderation.
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

// Events.
const (
	EventReported      = "moderation.reported"
	EventActioned      = "moderation.actioned"
	EventAppealDecided = "moderation.appeal_decided"
)

// AutoHideReports hides published content pending review once this many
// different people reported it.
const AutoHideReports = 3

// MaxReportsPerDay caps how many reports one person files in a rolling
// 24 hours (429 daily_cap).
const MaxReportsPerDay = 20

// ModerationReportInput reports content, a profile, a group or a community.
type ModerationReportInput struct {
	TargetType string    `json:"target_type" enum:"post,comment,profile,group,community"`
	TargetID   uuid.UUID `json:"target_id"`
	Reason     string    `json:"reason" enum:"spam,abuse,harassment,scam,impersonation,misinformation,privacy,other"`
	Details    string    `json:"details,omitempty" maxLength:"1000"`
}

// ModerationReportDTO is a report as seen by the reporter or a moderator.
type ModerationReportDTO struct {
	ID           uuid.UUID  `json:"id"`
	TargetType   string     `json:"target_type" enum:"post,comment,profile,group,community"`
	TargetID     uuid.UUID  `json:"target_id"`
	PostID       *uuid.UUID `json:"post_id,omitempty" doc:"Moderators: the post a reported comment belongs to"`
	TargetUserID *uuid.UUID `json:"target_user_id,omitempty" doc:"Moderators: the reported person (the author of reported content)"`
	CommunityID  *uuid.UUID `json:"community_id,omitempty" doc:"Absent for reports handled by Montra staff"`
	Reason       string     `json:"reason"`
	Details      *string    `json:"details,omitempty"`
	Status       string     `json:"status" enum:"open,under_review,actioned,dismissed,escalated"`
	Preview      *string    `json:"preview,omitempty" doc:"Moderators: an excerpt of the reported content"`
	OpenReports  int        `json:"open_reports" doc:"Moderators: open reports on the same target"`
	CreatedAt    time.Time  `json:"created_at"`
	ResolvedAt   *time.Time `json:"resolved_at,omitempty"`
}

// Report files a report (deduplicated per reporter and target).
func (s *Service) Report(ctx context.Context, in ModerationReportInput) (*ModerationReportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var details *string
	if strings.TrimSpace(in.Details) != "" {
		d, err := textsafe.Clean(in.Details, 1, 1000)
		if err != nil {
			code, params := textsafe.Problem(err, 1, 1000)
			return nil, apperr.FieldCode("body.details", code, "Describe the problem in plain text (up to 1000 characters).", params)
		}
		details = &d
	}
	var out ModerationReportDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var community *uuid.UUID
		var ok bool
		switch in.TargetType {
		case "post", "comment":
			table := map[string]string{"post": "community_posts", "comment": "community_comments"}[in.TargetType]
			var cid uuid.UUID
			var authorID *uuid.UUID
			err := tx.QueryRow(ctx, `select community_id, author_id from `+table+` where id = $1`, in.TargetID).Scan(&cid, &authorID)
			if err == nil {
				ok, community = true, &cid
				if authorID != nil && *authorID == uid {
					return apperr.Rule("own_content", "You cannot report your own content.", nil)
				}
			} else if !database.IsNoRows(err) {
				return err
			}
		case "profile":
			if in.TargetID == uid {
				return apperr.Rule("own_content", "You cannot report yourself.", nil)
			}
			if err := tx.QueryRow(ctx, `select montra.user_is_active($1)`, in.TargetID).Scan(&ok); err != nil {
				return err
			}
		case "group":
			if err := tx.QueryRow(ctx, `select montra.is_group_member($1)`, in.TargetID).Scan(&ok); err != nil {
				return err
			}
		case "community":
			if err := tx.QueryRow(ctx, `select exists (select 1 from communities where id = $1)`, in.TargetID).Scan(&ok); err != nil {
				return err
			}
		}
		if !ok {
			return apperr.NotFound(in.TargetType)
		}
		if err := caps.Daily(ctx, tx, uid, "reports", `select created_at from community_reports where reporter_id = $1
			and created_at > now() - interval '1 day'`, MaxReportsPerDay); err != nil {
			return err
		}
		id := uuid.New()
		if _, err := tx.Exec(ctx, `insert into community_reports (id, reporter_id, target_type, target_id, community_id, reason, details)
			values ($1,$2,$3,$4,$5,$6,$7)`, id, uid, in.TargetType, in.TargetID, community, in.Reason, details); err != nil {
			if database.IsUniqueViolation(err, "community_reports_dedupe") {
				return apperr.Conflict("You already reported this; moderators will review it.")
			}
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "community_report", EntityID: &id, Action: "created",
			Changes: map[string]any{"target_type": in.TargetType, "reason": in.Reason}}); err != nil {
			return err
		}
		if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventReported, AggregateType: "community_report", AggregateID: id, UserID: &uid}); err != nil {
			return err
		}
		out = ModerationReportDTO{ID: id, TargetType: in.TargetType, TargetID: in.TargetID, CommunityID: community, Reason: in.Reason, Details: details,
			Status: "open", CreatedAt: s.now()}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// MyReports lists the caller's reports and their outcome.
func (s *Service) MyReports(ctx context.Context) ([]ModerationReportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []ModerationReportDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		out, err = queryReports(ctx, tx, false, `r.reporter_id = $1 order by r.created_at desc limit 200`, uid)
		return err
	})
	return out, database.MapError(err)
}

// queryReports lists reports. Moderators (and staff) also get an excerpt
// of the content, the number of open reports on the same target, the post
// of a reported comment and the reported person; reporters do not.
func queryReports(ctx context.Context, tx pgx.Tx, moderator bool, where string, args ...any) ([]ModerationReportDTO, error) {
	rows, err := tx.Query(ctx, `select r.id, r.target_type, r.target_id, r.community_id, r.reason, r.details, r.status, r.created_at, r.resolved_at,
		case r.target_type when 'post' then (select left(p.title || ' — ' || p.body, 280) from community_posts p where p.id = r.target_id)
			when 'comment' then (select left(c.body, 280) from community_comments c where c.id = r.target_id) end,
		(select count(*)::int from community_reports o where o.target_type = r.target_type and o.target_id = r.target_id and o.status in ('open','under_review')),
		case r.target_type when 'comment' then (select c.post_id from community_comments c where c.id = r.target_id) end,
		case r.target_type when 'post' then (select p.author_id from community_posts p where p.id = r.target_id)
			when 'comment' then (select c.author_id from community_comments c where c.id = r.target_id)
			when 'profile' then r.target_id end
		from community_reports r where `+where, args...)
	if err != nil {
		return nil, err
	}
	out, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (ModerationReportDTO, error) {
		var x ModerationReportDTO
		err := r.Scan(&x.ID, &x.TargetType, &x.TargetID, &x.CommunityID, &x.Reason, &x.Details, &x.Status, &x.CreatedAt, &x.ResolvedAt, &x.Preview, &x.OpenReports,
			&x.PostID, &x.TargetUserID)
		return x, err
	})
	if err != nil {
		return nil, err
	}
	if !moderator {
		for i := range out {
			out[i].Preview, out[i].OpenReports, out[i].PostID, out[i].TargetUserID = nil, 0, nil, nil
		}
	}
	return out, nil
}

func requireModerator(ctx context.Context, tx pgx.Tx, communityID uuid.UUID) error {
	var ok bool
	if err := tx.QueryRow(ctx, `select montra.is_community_moderator($1)`, communityID).Scan(&ok); err != nil {
		return err
	}
	if !ok {
		return apperr.Forbidden()
	}
	return nil
}

// CommunityQueue lists a community's reports (moderators).
func (s *Service) CommunityQueue(ctx context.Context, communityID uuid.UUID, status string) ([]ModerationReportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if status == "" {
		status = "open"
	}
	var out []ModerationReportDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if err := requireModerator(ctx, tx, communityID); err != nil {
			return err
		}
		out, err = queryReports(ctx, tx, true, `r.community_id = $1 and (r.status = $2 or ($2 = 'open' and r.status = 'under_review'))
			order by r.created_at limit 500`, communityID, status)
		return err
	})
	return out, database.MapError(err)
}

// PlatformQueue lists reports for Montra staff: profiles, groups,
// communities and escalations.
func (s *Service) PlatformQueue(ctx context.Context, status string) ([]ModerationReportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if status == "" {
		status = "open"
	}
	var out []ModerationReportDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if err := requireStaff(ctx, tx); err != nil {
			return err
		}
		out, err = queryReports(ctx, tx, true, `(r.community_id is null or r.status = 'escalated')
			and (r.status = $1 or ($1 = 'open' and r.status in ('under_review','escalated'))) order by r.created_at limit 500`, status)
		return err
	})
	return out, database.MapError(err)
}
