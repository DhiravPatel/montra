package challenges

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
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

// Routes mounts challenge endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Challenges"
	social := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Social.Name) }

	httpx.Protected(api, httpx.Op("challenges-list", http.MethodGet, "/challenges",
		"Your challenges, or ones you can join (active first, then by end date; pages with meta.next_cursor / has_more)", tag),
		func(ctx context.Context, in *struct {
			Scope       string `query:"scope" enum:"mine,discover,"`
			GroupID     string `query:"group_id" format:"uuid"`
			CommunityID string `query:"community_id" format:"uuid"`
			Cursor      string `query:"cursor" maxLength:"512" doc:"meta.next_cursor of the previous page"`
			Limit       int    `query:"limit" minimum:"1" maximum:"200" default:"50"`
		}) (*httpx.Response[[]ChallengeDTO], error) {
			var g, c *uuid.UUID
			if in.GroupID != "" {
				v, _ := uuid.Parse(in.GroupID)
				g = &v
			}
			if in.CommunityID != "" {
				v, _ := uuid.Parse(in.CommunityID)
				c = &v
			}
			l, next, err := s.List(ctx, in.Scope, g, c, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Created(social(httpx.Op("challenges-create", http.MethodPost, "/challenges",
		"Create a challenge for yourself, a group or a community", tag))),
		func(ctx context.Context, in *struct{ Body ChallengeInput }) (*httpx.Response[ChallengeDTO], error) {
			c, err := s.Create(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Op("challenges-get", http.MethodGet, "/challenges/{id}", "A challenge with your progress", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[ChallengeDTO], error) {
			c, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("challenges-update", http.MethodPatch, "/challenges/{id}",
		"Edit a challenge you created (only the fields sent change; send the current version)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body ChallengePatch
		}) (*httpx.Response[ChallengeDTO], error) {
			c, err := s.Update(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("challenges-cancel", http.MethodPost, "/challenges/{id}/cancel",
		"Cancel a challenge (its creator or the community's moderators)", tag)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[ChallengeDTO], error) {
			c, err := s.Cancel(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("challenges-join", http.MethodPost, "/challenges/{id}/join",
		"Join (progress stays private unless you share it)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body ChallengeJoinInput
		}) (*httpx.Response[ChallengeDTO], error) {
			c, err := s.Join(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("challenges-participation", http.MethodPatch, "/challenges/{id}/participation",
		"Change what you share", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body ChallengeJoinInput
		}) (*httpx.Response[ChallengeDTO], error) {
			c, err := s.UpdateParticipation(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("challenges-leave", http.MethodPost, "/challenges/{id}/leave", "Leave a challenge", tag)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.Leave(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, social(httpx.Op("challenges-progress", http.MethodPost, "/challenges/{id}/progress",
		"Check in for a day (re-sending a day corrects it)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body ChallengeProgressInput
		}) (*httpx.Response[ChallengeDTO], error) {
			c, err := s.RecordProgress(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Op("challenges-leaderboard", http.MethodGet, "/challenges/{id}/leaderboard",
		"Participants who chose to appear, ranked by percentage of the target", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]ChallengeLeaderboardEntry], error) {
			l, err := s.Leaderboard(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
}

// JobNotifyCompleted congratulates a participant.
const JobNotifyCompleted = "challenges.notify_completed"

// JobNotifyMilestone encourages a participant halfway through.
const JobNotifyMilestone = "challenges.notify_milestone"

// RegisterJobs registers challenge jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobNotifyCompleted, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ChallengeID uuid.UUID `json:"challenge_id"`
			UserID      uuid.UUID `json:"user_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			var title string
			if err := tx.QueryRow(ctx, `select title from challenges where id = $1`, p.ChallengeID).Scan(&title); err != nil {
				if database.IsNoRows(err) {
					return nil
				}
				return err
			}
			cid := p.ChallengeID
			_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: p.UserID, Category: "challenge", EventType: "challenge_completed",
				Title: "You completed " + title, Body: "Nice work. Your progress stays private unless you shared it.", DeepLink: "/challenges/" + cid.String(),
				EntityType: "challenge", EntityID: &cid, DedupeKey: "challenge_completed:" + cid.String() + ":" + p.UserID.String()})
			return err
		})
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobNotifyMilestone, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ChallengeID uuid.UUID `json:"challenge_id"`
			UserID      uuid.UUID `json:"user_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			var title, status string
			if err := tx.QueryRow(ctx, `select c.title, p.status from challenges c join challenge_participants p on p.challenge_id = c.id and p.user_id = $2
				where c.id = $1`, p.ChallengeID, p.UserID).Scan(&title, &status); err != nil {
				if database.IsNoRows(err) {
					return nil
				}
				return err
			}
			if status != "active" {
				return nil // completed or left since; the completion notice says enough
			}
			cid := p.ChallengeID
			_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: p.UserID, Category: "challenge", EventType: "challenge_milestone",
				Title: "Halfway through " + title, Body: "You're halfway to your target. Keep going at your own pace.", DeepLink: "/challenges/" + cid.String(),
				EntityType: "challenge", EntityID: &cid, DedupeKey: "challenge_milestone:50:" + cid.String() + ":" + p.UserID.String()})
			return err
		})
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
}

// OutboxRoutes maps challenge events to jobs.
func OutboxRoutes(relay *outbox.Relay) {
	relay.On(EventCompleted, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil || e.UserID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobNotifyCompleted, UserID: e.UserID, Payload: map[string]any{"challenge_id": *e.AggregateID, "user_id": *e.UserID},
			DedupeKey: "challenges.notify_completed:" + e.AggregateID.String() + ":" + e.UserID.String()}}
	})
	relay.On(EventMilestone, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil || e.UserID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobNotifyMilestone, UserID: e.UserID, Payload: map[string]any{"challenge_id": *e.AggregateID, "user_id": *e.UserID},
			DedupeKey: "challenges.notify_milestone:50:" + e.AggregateID.String() + ":" + e.UserID.String()}}
	})
}
