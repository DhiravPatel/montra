package communities

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
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

// CommunityMemberRoleInput changes a member's role.
type CommunityMemberRoleInput struct {
	Role string `json:"role" enum:"moderator,member"`
}

// CommunityOwnerInput names the new owner.
type CommunityOwnerInput struct {
	UserID uuid.UUID `json:"user_id"`
}

// CommunityTokenInput carries an invitation token in the body (never in URLs).
type CommunityTokenInput struct {
	Token string `json:"token" minLength:"16" maxLength:"128"`
}

// CommunityVoteInput votes in a poll.
type CommunityVoteInput struct {
	OptionIDs []uuid.UUID `json:"option_ids" minItems:"1" maxItems:"10"`
}

// CommunityReactionInput adds a reaction.
type CommunityReactionInput struct {
	Kind string `json:"kind" enum:"like,helpful,insightful,support"`
}

// Routes mounts community endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Communities"
	social := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Social.Name) }

	httpx.Protected(api, httpx.Op("communities-list", http.MethodGet, "/communities", "Discover communities, or list yours", tag),
		func(ctx context.Context, in *struct {
			Q     string `query:"q" maxLength:"80"`
			Topic string `query:"topic" maxLength:"30"`
			Mine  bool   `query:"mine"`
		}) (*httpx.Response[[]CommunityDTO], error) {
			l, err := s.Discover(ctx, in.Q, in.Topic, in.Mine)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(social(httpx.Op("communities-create", http.MethodPost, "/communities", "Create a community (you become its owner)", tag))),
		func(ctx context.Context, in *struct{ Body CommunityInput }) (*httpx.Response[CommunityDTO], error) {
			c, err := s.Create(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Op("communities-get", http.MethodGet, "/communities/{ref}", "A community by ID or URL name", tag),
		func(ctx context.Context, in *struct {
			Ref string `path:"ref" maxLength:"60"`
		}) (*httpx.Response[CommunityDTO], error) {
			c, err := s.Get(ctx, in.Ref)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("communities-update", http.MethodPatch, "/communities/{id}",
		"Update name, description, rules and topics (moderators) or visibility (owner); only the fields sent change; send the current version", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body CommunityPatch
		}) (*httpx.Response[CommunityDTO], error) {
			c, err := s.Update(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	for _, a := range []struct {
		path     string
		archived bool
	}{{"archive", true}, {"restore", false}} {
		a := a
		httpx.Protected(api, social(httpx.Op("communities-"+a.path, http.MethodPost, "/communities/{id}/"+a.path,
			map[bool]string{true: "Archive a community (owner; read-only)", false: "Restore an archived community (owner)"}[a.archived], tag)),
			func(ctx context.Context, in *IDPath) (*httpx.Response[CommunityDTO], error) {
				c, err := s.SetArchived(ctx, in.ID, a.archived)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *c), nil
			})
	}
	httpx.Protected(api, social(httpx.Op("communities-join", http.MethodPost, "/communities/{id}/join",
		"Join a public community or ask to join a private one", tag)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[CommunityDTO], error) {
			c, err := s.Join(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("communities-leave", http.MethodPost, "/communities/{id}/leave", "Leave a community", tag)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.Leave(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Op("communities-members", http.MethodGet, "/communities/{id}/members",
		"Members (moderators see everyone; others see the moderators)", tag),
		func(ctx context.Context, in *struct {
			IDPath
			Status string `query:"status" enum:"active,pending,banned,left,"`
		}) (*httpx.Response[[]CommunityMemberDTO], error) {
			l, err := s.Members(ctx, in.ID, in.Status)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, social(httpx.Op("communities-members-role", http.MethodPatch, "/communities/{id}/members/{userId}",
		"Make a member a moderator or back (owner)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			UserID uuid.UUID `path:"userId"`
			Body   CommunityMemberRoleInput
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.SetRole(ctx, in.ID, in.UserID, in.Body.Role); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	for _, a := range []struct {
		path    string
		approve bool
	}{{"approve", true}, {"reject", false}} {
		a := a
		httpx.Protected(api, social(httpx.Op("communities-members-"+a.path, http.MethodPost, "/communities/{id}/members/{userId}/"+a.path,
			map[bool]string{true: "Approve a join request (moderators)", false: "Reject a join request (moderators)"}[a.approve], tag)),
			func(ctx context.Context, in *struct {
				IDPath
				UserID uuid.UUID `path:"userId"`
			}) (*httpx.Response[httpx.Empty], error) {
				if err := s.DecideMember(ctx, in.ID, in.UserID, a.approve); err != nil {
					return nil, err
				}
				return httpx.Done(ctx), nil
			})
	}
	httpx.Protected(api, social(httpx.Op("communities-transfer-ownership", http.MethodPost, "/communities/{id}/transfer-ownership",
		"Hand the community to another member (you become a moderator)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body CommunityOwnerInput
		}) (*httpx.Response[CommunityDTO], error) {
			c, err := s.TransferOwnership(ctx, in.ID, in.Body.UserID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Created(social(httpx.Op("communities-invitations-create", http.MethodPost, "/communities/{id}/invitations",
		"Invite someone by username or create a link (moderators; the token is shown once)", tag))),
		func(ctx context.Context, in *struct {
			IDPath
			Body CommunityInvitationInput
		}) (*httpx.Response[CommunityInvitationDTO], error) {
			inv, err := s.Invite(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *inv), nil
		})
	httpx.Protected(api, httpx.Op("communities-invitations-list", http.MethodGet, "/communities/{id}/invitations",
		"Invitations (moderators); active ones unless include_inactive", tag),
		func(ctx context.Context, in *struct {
			IDPath
			IncludeInactive bool `query:"include_inactive"`
		}) (*httpx.Response[[]CommunityInvitationDTO], error) {
			l, err := s.Invitations(ctx, in.ID, in.IncludeInactive)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, social(httpx.Op("communities-invitations-revoke", http.MethodDelete, "/communities/{id}/invitations/{invitationId}",
		"Revoke an invitation (moderators)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			InvitationID uuid.UUID `path:"invitationId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.RevokeInvitation(ctx, in.ID, in.InvitationID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Op("community-invitations-mine", http.MethodGet, "/community-invitations", "Community invitations addressed to you", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]CommunityInvitationDTO], error) {
			l, err := s.MyCommunityInvitations(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Errs(social(httpx.Op("community-invitations-preview", http.MethodPost, "/community-invitations/preview",
		"See which community an invitation link is for", tag)), http.StatusGone),
		func(ctx context.Context, in *struct{ Body CommunityTokenInput }) (*httpx.Response[CommunityInvitationPreview], error) {
			p, err := s.PreviewInvitation(ctx, in.Body.Token)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, httpx.Errs(social(httpx.Op("community-invitations-accept-link", http.MethodPost, "/community-invitations/accept",
		"Join with an invitation link token", tag)), http.StatusGone),
		func(ctx context.Context, in *struct{ Body CommunityTokenInput }) (*httpx.Response[CommunityDTO], error) {
			c, err := s.AcceptInvitation(ctx, in.Body.Token, nil)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Errs(social(httpx.Op("community-invitations-accept", http.MethodPost, "/community-invitations/{id}/accept",
		"Accept an invitation addressed to you", tag)), http.StatusGone),
		func(ctx context.Context, in *IDPath) (*httpx.Response[CommunityDTO], error) {
			id := in.ID
			c, err := s.AcceptInvitation(ctx, "", &id)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Errs(social(httpx.Op("community-invitations-decline", http.MethodPost, "/community-invitations/{id}/decline",
		"Decline an invitation addressed to you", tag)), http.StatusGone),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeclineInvitation(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	// Posts.
	httpx.Protected(api, httpx.Op("communities-posts-list", http.MethodGet, "/communities/{id}/posts",
		"Posts, pinned first (sort new, top or active; search with q; pages with meta.next_cursor / has_more)", tag),
		func(ctx context.Context, in *struct {
			IDPath
			Sort   string `query:"sort" enum:"new,top,active,"`
			Q      string `query:"q" maxLength:"100"`
			Cursor string `query:"cursor" maxLength:"512" doc:"meta.next_cursor of the previous page (same sort and q)"`
			Limit  int    `query:"limit" minimum:"0" maximum:"50" doc:"Default 20"`
			Offset int    `query:"offset" minimum:"0" maximum:"1000" doc:"Older clients; ignored with a cursor"`
		}) (*httpx.Response[[]CommunityPostDTO], error) {
			l, next, err := s.Feed(ctx, in.ID, in.Sort, in.Q, in.Cursor, in.Limit, in.Offset)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Created(social(httpx.Op("communities-posts-create", http.MethodPost, "/communities/{id}/posts",
		"Post a discussion, question, resource link or poll (members; plain text)", tag))),
		func(ctx context.Context, in *struct {
			IDPath
			Body CommunityPostInput
		}) (*httpx.Response[CommunityPostDTO], error) {
			p, err := s.CreatePost(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, httpx.Op("posts-get", http.MethodGet, "/posts/{id}", "A post with its comments", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[CommunityPostDetail], error) {
			p, err := s.GetPost(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, social(httpx.Op("posts-update", http.MethodPatch, "/posts/{id}", "Edit your post", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body CommunityPostInput
		}) (*httpx.Response[CommunityPostDTO], error) {
			p, err := s.UpdatePost(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, social(httpx.Op("posts-delete", http.MethodDelete, "/posts/{id}", "Delete your post", tag)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeletePost(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Created(social(httpx.Op("posts-comments-create", http.MethodPost, "/posts/{id}/comments", "Comment or reply", tag))),
		func(ctx context.Context, in *struct {
			IDPath
			Body CommunityCommentInput
		}) (*httpx.Response[CommunityCommentDTO], error) {
			c, err := s.AddComment(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("comments-update", http.MethodPatch, "/comments/{id}", "Edit your comment", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body CommunityCommentInput
		}) (*httpx.Response[CommunityCommentDTO], error) {
			c, err := s.UpdateComment(ctx, in.ID, in.Body.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, social(httpx.Op("comments-delete", http.MethodDelete, "/comments/{id}", "Delete your comment", tag)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeleteComment(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	for _, target := range []string{"posts", "comments"} {
		target := target
		httpx.Protected(api, social(httpx.Op(target+"-reactions-add", http.MethodPost, "/"+target+"/{id}/reactions",
			"React (like, helpful, insightful, support); answers the counts and your reactions", tag)),
			func(ctx context.Context, in *struct {
				IDPath
				Body CommunityReactionInput
			}) (*httpx.Response[CommunityReactionsDTO], error) {
				return s.reactRoute(ctx, target, in.ID, in.Body.Kind, true)
			})
		httpx.Protected(api, social(httpx.Op(target+"-reactions-remove", http.MethodDelete, "/"+target+"/{id}/reactions/{kind}", "Remove your reaction", tag)),
			func(ctx context.Context, in *struct {
				IDPath
				Kind string `path:"kind" enum:"like,helpful,insightful,support"`
			}) (*httpx.Response[CommunityReactionsDTO], error) {
				return s.reactRoute(ctx, target, in.ID, in.Kind, false)
			})
	}
	httpx.Protected(api, social(httpx.Op("posts-poll-vote", http.MethodPost, "/posts/{id}/poll/votes",
		"Vote (replaces your earlier vote; results are aggregate only)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body CommunityVoteInput
		}) (*httpx.Response[CommunityPollDTO], error) {
			p, err := s.Vote(ctx, in.ID, in.Body.OptionIDs)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
}

func (s *Service) reactRoute(ctx context.Context, target string, id uuid.UUID, kind string, on bool) (*httpx.Response[CommunityReactionsDTO], error) {
	var post, comment *uuid.UUID
	if target == "posts" {
		post = &id
	} else {
		comment = &id
	}
	rc, err := s.React(ctx, post, comment, kind, on)
	if err != nil {
		return nil, err
	}
	return httpx.OK(ctx, *rc), nil
}

// Job types.
const (
	JobNotifyComment  = "communities.notify_comment"
	JobNotifyMembers  = "communities.notify_membership"
	JobNotifyMentions = "communities.notify_mentions"
	JobNotifyInvite   = "communities.notify_invitation"
)

// RegisterJobs registers community notification jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobNotifyComment, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			CommentID uuid.UUID `json:"comment_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return notifyComment(ctx, tx, p.CommentID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(4))
	reg.Register(JobNotifyMentions, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			Kind string    `json:"kind"`
			ID   uuid.UUID `json:"id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return notifyMentions(ctx, tx, p.Kind, p.ID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(4))
	reg.Register(JobNotifyInvite, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			InvitationID uuid.UUID `json:"invitation_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return notifyInvitation(ctx, tx, p.InvitationID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobNotifyMembers, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			CommunityID uuid.UUID `json:"community_id"`
			UserID      uuid.UUID `json:"user_id"`
			Kind        string    `json:"kind"`
			Approved    bool      `json:"approved"`
			EventID     int64     `json:"event_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			return notifyMembership(ctx, tx, p.CommunityID, p.UserID, p.Kind, p.Approved, strconv.FormatInt(p.EventID, 10))
		})
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
}

// OutboxRoutes maps community events to jobs.
func OutboxRoutes(relay *outbox.Relay) {
	relay.On(EventCommentCreated, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobNotifyComment, Payload: map[string]any{"comment_id": *e.AggregateID},
			DedupeKey: "communities.notify_comment:" + e.AggregateID.String()}}
	})
	mentions := func(kind string) func(e outbox.Stored) []jobs.Spec {
		return func(e outbox.Stored) []jobs.Spec {
			if e.AggregateID == nil {
				return nil
			}
			return []jobs.Spec{{Type: JobNotifyMentions, Payload: map[string]any{"kind": kind, "id": *e.AggregateID},
				DedupeKey: "communities.notify_mentions:" + kind + ":" + e.AggregateID.String()}}
		}
	}
	relay.On(EventInvitationCreated, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobNotifyInvite, Payload: map[string]any{"invitation_id": *e.AggregateID},
			DedupeKey: "communities.notify_invitation:" + e.AggregateID.String()}}
	})
	relay.On(EventPostCreated, mentions("post"))
	relay.On(EventCommentCreated, mentions("comment"))
	for _, ev := range []string{EventMemberPending, EventMemberDecided} {
		ev := ev
		relay.On(ev, func(e outbox.Stored) []jobs.Spec {
			var p struct {
				Approved bool `json:"approved"`
			}
			if e.AggregateID == nil || e.UserID == nil {
				return nil
			}
			_ = json.Unmarshal(e.Payload, &p)
			return []jobs.Spec{{Type: JobNotifyMembers, Payload: map[string]any{"community_id": *e.AggregateID, "user_id": *e.UserID, "kind": ev,
				"approved": p.Approved, "event_id": e.ID}, DedupeKey: "communities.notify_membership:" + strconv.FormatInt(e.ID, 10)}}
		})
	}
}

// notifyComment tells the post author (and the parent comment's author for
// replies) about a new comment, unless they blocked or muted the commenter.
func notifyComment(ctx context.Context, tx pgx.Tx, commentID uuid.UUID) error {
	var postID, commID uuid.UUID
	var commenter, parent, postAuthor *uuid.UUID
	var title, status string
	err := tx.QueryRow(ctx, `select c.post_id, c.community_id, c.author_id, pc.author_id, p.author_id, p.title, c.status
		from community_comments c join community_posts p on p.id = c.post_id left join community_comments pc on pc.id = c.parent_comment_id
		where c.id = $1`, commentID).Scan(&postID, &commID, &commenter, &parent, &postAuthor, &title, &status)
	if database.IsNoRows(err) || (err == nil && (status != "published" || commenter == nil)) {
		return nil
	}
	if err != nil {
		return err
	}
	targets := map[uuid.UUID]string{}
	if postAuthor != nil {
		targets[*postAuthor] = "comment_on_post"
	}
	if parent != nil {
		targets[*parent] = "reply_to_comment"
	}
	delete(targets, *commenter)
	for uid, kind := range targets {
		var skip bool
		if err := tx.QueryRow(ctx, `select montra.is_blocked_between($1, $2) or exists (select 1 from user_mutes where muter_id = $1 and muted_id = $2)
			or not exists (select 1 from community_members where community_id = $3 and user_id = $1 and status = 'active')`, uid, *commenter, commID).
			Scan(&skip); err != nil {
			return err
		}
		if skip {
			continue
		}
		t := "New comment on your post"
		if kind == "reply_to_comment" {
			t = "New reply to your comment"
		}
		pid := postID
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "community", EventType: kind,
			Title: t, Body: "Open the community to read it.", DeepLink: "/posts/" + pid.String(), EntityType: "community_post", EntityID: &pid,
			DedupeKey: "community_comment:" + commentID.String() + ":" + uid.String()}); err != nil {
			return err
		}
	}
	return nil
}

func notifyMembership(ctx context.Context, tx pgx.Tx, commID, user uuid.UUID, kind string, approved bool, eventID string) error {
	var name string
	if err := tx.QueryRow(ctx, `select name from communities where id = $1`, commID).Scan(&name); err != nil {
		if database.IsNoRows(err) {
			return nil
		}
		return err
	}
	cid := commID
	if kind == EventMemberDecided {
		t, b := "You joined "+name, "Your request was approved."
		if !approved {
			t, b = "Your request to join "+name+" was declined", "You can ask again later."
		}
		_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: user, Category: "community", EventType: "community_membership",
			Title: t, Body: b, DeepLink: "/communities/" + cid.String(), EntityType: "community", EntityID: &cid,
			DedupeKey: "community_decided:" + eventID})
		return err
	}
	rows, err := tx.Query(ctx, `select user_id from community_members where community_id = $1 and status = 'active' and role in ('owner','moderator')`, commID)
	if err != nil {
		return err
	}
	mods, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return err
	}
	for _, m := range mods {
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: m, Category: "community", EventType: "community_join_request",
			Title: "Someone asked to join " + name, Body: "Approve or reject the request.", DeepLink: "/communities/" + cid.String() + "/settings",
			EntityType: "community", EntityID: &cid, DedupeKey: "community_pending:" + eventID + ":" + m.String()}); err != nil {
			return err
		}
	}
	return nil
}

// notifyInvitation tells the invitee about an invitation addressed to them
// while it is still open, unless they blocked or muted the inviter.
func notifyInvitation(ctx context.Context, tx pgx.Tx, invID uuid.UUID) error {
	var invitee, inviter *uuid.UUID
	var commID uuid.UUID
	var name string
	var open bool
	err := tx.QueryRow(ctx, `select i.invitee_user_id, i.created_by, i.community_id, c.name,
		i.used_at is null and i.revoked_at is null and i.declined_at is null and i.expires_at > now()
		from community_invitations i join communities c on c.id = i.community_id where i.id = $1`, invID).
		Scan(&invitee, &inviter, &commID, &name, &open)
	if database.IsNoRows(err) || (err == nil && (invitee == nil || !open)) {
		return nil
	}
	if err != nil {
		return err
	}
	if inviter != nil {
		var quiet bool
		if err := tx.QueryRow(ctx, `select montra.is_blocked_between($1, $2)
			or exists (select 1 from user_mutes where muter_id = $1 and muted_id = $2)`, *invitee, *inviter).Scan(&quiet); err != nil || quiet {
			return err
		}
	}
	id := invID
	_, _, err = notifications.Create(ctx, tx, notifications.Notification{UserID: *invitee, Category: "community", EventType: "community_invitation",
		Title: "You're invited to join " + name, Body: "Accept or decline in Communities.", DeepLink: "/communities",
		EntityType: "community_invitation", EntityID: &id, DedupeKey: "community_invitation:" + invID.String()})
	return err
}
