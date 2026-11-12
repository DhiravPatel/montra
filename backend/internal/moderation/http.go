package moderation

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/outbox"
	"montra/backend/internal/platform/ratelimit"
)

// IDPath binds {id}.
type IDPath struct {
	ID uuid.UUID `path:"id"`
}

// PostReportInput reports a post.
type PostReportInput struct {
	Reason  string `json:"reason" enum:"spam,abuse,harassment,scam,impersonation,misinformation,privacy,other"`
	Details string `json:"details,omitempty" maxLength:"1000"`
}

// ModerationReverseInput explains a reversal.
type ModerationReverseInput struct {
	Note string `json:"note,omitempty" maxLength:"500"`
}

// ModerationAppealInput contests an action.
type ModerationAppealInput struct {
	Statement string `json:"statement" minLength:"1" maxLength:"2000"`
}

// AppealDecisionInput decides an appeal.
type AppealDecisionInput struct {
	Decision string `json:"decision" enum:"upheld,overturned"`
	Note     string `json:"note,omitempty" maxLength:"1000"`
}

// Routes mounts moderation endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Moderation"
	social := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Social.Name) }

	httpx.Protected(api, httpx.Created(social(httpx.Op("content-reports-create", http.MethodPost, "/content-reports",
		"Report a post, comment, profile, group or community", tag))),
		func(ctx context.Context, in *struct{ Body ModerationReportInput }) (*httpx.Response[ModerationReportDTO], error) {
			r, err := s.Report(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Created(social(httpx.Op("posts-report", http.MethodPost, "/posts/{id}/reports", "Report a post", tag))),
		func(ctx context.Context, in *struct {
			IDPath
			Body PostReportInput
		}) (*httpx.Response[ModerationReportDTO], error) {
			r, err := s.Report(ctx, ModerationReportInput{TargetType: "post", TargetID: in.ID, Reason: in.Body.Reason, Details: in.Body.Details})
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("content-reports-mine", http.MethodGet, "/content-reports", "Reports you filed and their outcome", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]ModerationReportDTO], error) {
			l, err := s.MyReports(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("communities-moderation-reports", http.MethodGet, "/communities/{id}/moderation/reports", "Report queue (moderators)", tag),
		func(ctx context.Context, in *struct {
			IDPath
			Status string `query:"status" enum:"open,actioned,dismissed,escalated,"`
		}) (*httpx.Response[[]ModerationReportDTO], error) {
			l, err := s.CommunityQueue(ctx, in.ID, in.Status)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, social(httpx.Op("communities-moderation-act", http.MethodPost, "/communities/{id}/moderation/actions",
		"Hide/remove/restore content, pin/lock posts, warn/restrict/ban members, dismiss or escalate reports (moderators; audited)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body ModerationActionInput
		}) (*httpx.Response[ModerationActionDTO], error) {
			id := in.ID
			a, err := s.Act(ctx, &id, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
	httpx.Protected(api, httpx.Op("communities-moderation-log", http.MethodGet, "/communities/{id}/moderation/actions", "Moderation log (moderators)", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]ModerationActionDTO], error) {
			l, err := s.ActionLog(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("communities-moderation-appeals", http.MethodGet, "/communities/{id}/moderation/appeals", "Open appeals (moderators)", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]ModerationAppealDTO], error) {
			id := in.ID
			l, err := s.Appeals(ctx, &id)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, social(httpx.Op("moderation-actions-reverse", http.MethodPost, "/moderation/actions/{id}/reverse",
		"Reverse an action (its community's moderators or staff; the record is kept)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body ModerationReverseInput
		}) (*httpx.Response[ModerationActionDTO], error) {
			a, err := s.Reverse(ctx, in.ID, in.Body.Note)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
	httpx.Protected(api, httpx.Created(social(httpx.Op("moderation-actions-appeal", http.MethodPost, "/moderation/actions/{id}/appeals",
		"Appeal an action that affected you (within 30 days)", tag))),
		func(ctx context.Context, in *struct {
			IDPath
			Body ModerationAppealInput
		}) (*httpx.Response[ModerationAppealDTO], error) {
			a, err := s.Appeal(ctx, in.ID, in.Body.Statement)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
	httpx.Protected(api, social(httpx.Op("moderation-appeals-decide", http.MethodPost, "/moderation/appeals/{id}/decide",
		"Uphold or overturn an appeal (another moderator or staff; overturning reverses the action)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body AppealDecisionInput
		}) (*httpx.Response[ModerationAppealDTO], error) {
			a, err := s.DecideAppeal(ctx, in.ID, in.Body.Decision == "overturned", in.Body.Note)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
	httpx.Protected(api, httpx.Op("me-moderation", http.MethodGet, "/me/moderation",
		"Warnings, removals and sanctions that affected you, with your appeal and its outcome", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]ModerationActionDTO], error) {
			l, err := s.MyModeration(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("me-moderation-appeals", http.MethodGet, "/me/moderation/appeals", "Your appeals and their outcome, newest first", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]ModerationAppealDTO], error) {
			l, err := s.MyAppeals(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})

	// Montra staff (platform_role support/admin).
	httpx.Protected(api, httpx.Staff(httpx.Op("moderation-platform-reports", http.MethodGet, "/moderation/reports",
		"Platform report queue: profiles, groups, communities, escalations (staff)", tag), "support"),
		func(ctx context.Context, in *struct {
			Status string `query:"status" enum:"open,actioned,dismissed,escalated,"`
		}) (*httpx.Response[[]ModerationReportDTO], error) {
			l, err := s.PlatformQueue(ctx, in.Status)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Staff(httpx.Op("moderation-platform-act", http.MethodPost, "/moderation/actions",
		"Platform action: account-wide restriction or ban from communities, community suspension, content removal (staff; audited)", tag), "support"),
		func(ctx context.Context, in *struct{ Body ModerationActionInput }) (*httpx.Response[ModerationActionDTO], error) {
			a, err := s.Act(ctx, nil, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
	httpx.Protected(api, httpx.Staff(httpx.Op("moderation-platform-actions", http.MethodGet, "/moderation/actions",
		"Platform actions, newest first (staff; filter by status, action, target; pages with meta.next_cursor / has_more)", tag), "support"),
		func(ctx context.Context, in *PlatformActionsFilter) (*httpx.Response[[]ModerationActionDTO], error) {
			l, next, err := s.PlatformActions(ctx, *in)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Staff(httpx.Op("moderation-platform-appeals", http.MethodGet, "/moderation/appeals", "All open appeals (staff)", tag), "support"),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]ModerationAppealDTO], error) {
			l, err := s.Appeals(ctx, nil)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
}

// Job types.
const (
	JobReported      = "moderation.reported"       // auto-hide threshold + moderator notice
	JobActioned      = "moderation.actioned"       // tell the affected person
	JobAppealDecided = "moderation.appeal_decided" // tell the appellant the outcome
)

// RegisterJobs registers moderation jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobReported, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ReportID uuid.UUID `json:"report_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return s.onReported(ctx, tx, p.ReportID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobActioned, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ActionID uuid.UUID `json:"action_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return notifyActioned(ctx, tx, p.ActionID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobAppealDecided, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			AppealID uuid.UUID `json:"appeal_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return notifyAppealDecided(ctx, tx, p.AppealID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
}

// OutboxRoutes maps moderation events to jobs.
func OutboxRoutes(relay *outbox.Relay) {
	relay.On(EventReported, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobReported, Payload: map[string]any{"report_id": *e.AggregateID}, DedupeKey: "moderation.reported:" + e.AggregateID.String()}}
	})
	relay.On(EventActioned, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobActioned, Payload: map[string]any{"action_id": *e.AggregateID}, DedupeKey: "moderation.actioned:" + e.AggregateID.String()}}
	})
	relay.On(EventAppealDecided, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobAppealDecided, UserID: e.UserID, Payload: map[string]any{"appeal_id": *e.AggregateID},
			DedupeKey: "moderation.appeal_decided:" + e.AggregateID.String()}}
	})
}

// notifyAppealDecided tells the appellant whether their appeal succeeded:
// overturned means the action was reversed; upheld means it stands.
func notifyAppealDecided(ctx context.Context, tx pgx.Tx, appealID uuid.UUID) error {
	var status, action, targetType string
	var appellant uuid.UUID
	var actionID uuid.UUID
	var community *uuid.UUID
	var note *string
	err := tx.QueryRow(ctx, `select ap.status, ap.appellant_id, ap.action_id, ap.community_id, ap.decision_note, a.action, a.target_type
		from moderation_appeals ap join moderation_actions a on a.id = ap.action_id where ap.id = $1`, appealID).
		Scan(&status, &appellant, &actionID, &community, &note, &action, &targetType)
	if database.IsNoRows(err) || (err == nil && status == "open") {
		return nil
	}
	if err != nil {
		return err
	}
	where := "a community"
	if community != nil {
		_ = tx.QueryRow(ctx, `select name from communities where id = $1`, *community).Scan(&where)
	}
	what := map[string]string{"hide": "hiding your " + targetType, "remove": "removing your " + targetType, "warn": "the warning",
		"restrict": "the restriction", "ban": "the ban"}[action]
	if what == "" {
		what = "the decision"
	}
	title := "Your appeal in " + where + " was accepted"
	body := "Another moderator reviewed " + what + " and reversed it."
	if status == "upheld" {
		title = "Your appeal in " + where + " was reviewed"
		body = "Another moderator reviewed " + what + " and it stands."
	}
	if note != nil && *note != "" {
		body += " Note: " + *note
	}
	aid := actionID
	_, _, err = notifications.Create(ctx, tx, notifications.Notification{UserID: appellant, Category: "community", EventType: "moderation_appeal_" + status,
		Title: title, Body: body, DeepLink: appealDecidedLink, EntityType: "moderation_action", EntityID: &aid, Priority: "high",
		DedupeKey: "moderation_appeal:" + appealID.String()})
	return err
}

// appealDecidedLink opens the person's moderation history (the same screen
// as the action notice in notifyActioned).
const appealDecidedLink = "/settings/moderation"

// onReported hides published content pending review once AutoHideReports
// different people reported it, and tells the community's moderators.
func (s *Service) onReported(ctx context.Context, tx pgx.Tx, reportID uuid.UUID) error {
	var targetType, status string
	var targetID uuid.UUID
	var community *uuid.UUID
	err := tx.QueryRow(ctx, `select target_type, target_id, community_id, status from community_reports where id = $1`, reportID).
		Scan(&targetType, &targetID, &community, &status)
	if database.IsNoRows(err) || (err == nil && status != "open") {
		return nil
	}
	if err != nil {
		return err
	}
	if community == nil {
		return nil // staff queue
	}
	var name string
	if err := tx.QueryRow(ctx, `select name from communities where id = $1`, *community).Scan(&name); err != nil {
		return err
	}
	cid := *community
	rows, err := tx.Query(ctx, `select user_id from community_members where community_id = $1 and status = 'active' and role in ('owner','moderator')`, cid)
	if err != nil {
		return err
	}
	mods, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return err
	}
	for _, m := range mods {
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: m, Category: "community", EventType: "community_report",
			Title: "New report in " + name, Body: "Review it in the moderation queue.", DeepLink: "/communities/" + cid.String() + "/moderation",
			EntityType: "community", EntityID: &cid, DedupeKey: "community_report:" + reportID.String() + ":" + m.String()}); err != nil {
			return err
		}
	}
	if targetType != "post" && targetType != "comment" {
		return nil
	}
	var reporters int
	if err := tx.QueryRow(ctx, `select count(distinct reporter_id) from community_reports where target_type = $1 and target_id = $2
		and status in ('open','under_review')`, targetType, targetID).Scan(&reporters); err != nil {
		return err
	}
	if reporters < AutoHideReports {
		return nil
	}
	table := map[string]string{"post": "community_posts", "comment": "community_comments"}[targetType]
	var author *uuid.UUID
	tag, err := tx.Exec(ctx, `update `+table+` set status = 'hidden' where id = $1 and status = 'published'`, targetID)
	if err != nil || tag.RowsAffected() == 0 {
		return err
	}
	if err := tx.QueryRow(ctx, `select author_id from `+table+` where id = $1`, targetID).Scan(&author); err != nil {
		return err
	}
	id := uuid.New()
	reason := "Hidden automatically after several reports; a moderator will review it."
	if _, err := tx.Exec(ctx, `insert into moderation_actions (id, community_id, target_type, target_id, target_user_id, action, reason, report_id)
		values ($1,$2,$3,$4,$5,'hide',$6,$7)`, id, cid, targetType, targetID, author, reason, reportID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `update community_reports set status = 'under_review' where target_type = $1 and target_id = $2 and status = 'open'`,
		targetType, targetID); err != nil {
		return err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: author, EntityType: "moderation_action", EntityID: &id, Action: "hide",
		Changes: map[string]any{"automatic": true, "reports": reporters}}); err != nil {
		return err
	}
	return outbox.Emit(ctx, tx, outbox.Event{Type: EventActioned, AggregateType: "moderation_action", AggregateID: id, UserID: author})
}

// notifyActioned tells the affected person what happened and why.
func notifyActioned(ctx context.Context, tx pgx.Tx, actionID uuid.UUID) error {
	var action, targetType string
	var user, community *uuid.UUID
	var reason *string
	var expires *time.Time
	err := tx.QueryRow(ctx, `select action, target_type, target_user_id, community_id, reason, expires_at from moderation_actions where id = $1`, actionID).
		Scan(&action, &targetType, &user, &community, &reason, &expires)
	if database.IsNoRows(err) || (err == nil && user == nil) {
		return nil
	}
	if err != nil {
		return err
	}
	where := "a community"
	link := "/settings/moderation"
	if community != nil {
		_ = tx.QueryRow(ctx, `select name from communities where id = $1`, *community).Scan(&where)
	}
	until := ""
	if expires != nil {
		until = " until " + expires.UTC().Format("2 Jan 2006 15:04 UTC")
	}
	var title string
	switch action {
	case "hide":
		title = "Your " + targetType + " in " + where + " was hidden"
	case "remove":
		title = "Your " + targetType + " in " + where + " was removed"
	case "restore":
		title = "Your " + targetType + " in " + where + " was restored"
	case "warn":
		title = "You received a warning in " + where
	case "restrict":
		title = "You cannot post in " + where + until
		if community == nil {
			title = "Your account cannot take part in communities" + until
		}
	case "ban":
		title = "You were banned from " + where
		if community == nil {
			title = "Your account was banned from communities" + until
		}
	case "unban":
		title = "Your ban in " + where + " was lifted"
		if community == nil {
			title = "You can take part in communities again"
		}
	default:
		return nil
	}
	body := "You can appeal from Settings → Moderation."
	if reason != nil {
		body = "Reason: " + *reason + ". You can appeal from Settings → Moderation."
	}
	if action == "restore" || action == "unban" {
		body = "No further action is needed."
	}
	aid := actionID
	_, _, err = notifications.Create(ctx, tx, notifications.Notification{UserID: *user, Category: "community", EventType: "moderation_" + action,
		Title: title, Body: body, DeepLink: link, EntityType: "moderation_action", EntityID: &aid, Priority: "high",
		DedupeKey: "moderation_action:" + actionID.String()})
	return err
}
