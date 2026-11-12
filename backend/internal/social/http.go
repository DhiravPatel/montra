package social

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/outbox"
	"montra/backend/internal/platform/ratelimit"
)

// JobNotifyFriendRequest notifies the addressee of a friend request.
const JobNotifyFriendRequest = "social.notify_friend_request"

// UserPath binds {userId}.
type UserPath struct {
	UserID uuid.UUID `path:"userId"`
}

// MuteInput mutes or unmutes a user.
type MuteInput struct {
	Muted bool `json:"muted" doc:"false to unmute"`
}

// Routes mounts social endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Social"
	social := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Social.Name) }

	httpx.Protected(api, social(describe(httpx.Op("users-search", http.MethodGet, "/users/search",
		"Find a person by their exact username (only discoverable profiles; blocked users never appear)", tag),
		"Matches the whole username only, ignoring case and a leading @: partial usernames find nobody. "+
			"Returns at most one person, who opted into username discovery.")),
		func(ctx context.Context, in *struct {
			Q string `query:"q" minLength:"2" maxLength:"31" doc:"The full username (a leading @ is ignored)"`
		}) (*httpx.Response[[]PublicProfile], error) {
			l, err := s.Search(ctx, in.Q)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("friends-list", http.MethodGet, "/connections", "Your friends", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]PublicProfile], error) {
			l, err := s.Friends(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("friend-requests-list", http.MethodGet, "/friend-requests", "Pending requests you sent or received", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]FriendRequestDTO], error) {
			l, err := s.Requests(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(social(describe(httpx.Op("friend-requests-send", http.MethodPost, "/friend-requests",
		"Send a friend request (accepts theirs if they already asked you)", tag),
		"If they already asked you, their request is accepted instead (201 with status accepted). "+
			"409 CONFLICT codes: already_friends, request_pending (you already asked them). "+
			"A blocked or unknown person answers 404; someone not accepting requests answers 422 requests_closed."))),
		func(ctx context.Context, in *struct{ Body SendInput }) (*httpx.Response[FriendRequestDTO], error) {
			r, err := s.SendRequest(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	for _, action := range []string{"accept", "decline", "cancel"} {
		action := action
		summary := map[string]string{"accept": "Accept a friend request", "decline": "Decline a friend request", "cancel": "Cancel a request you sent"}[action]
		httpx.Protected(api, social(httpx.Op("friend-requests-"+action, http.MethodPost, "/friend-requests/{id}/"+action, summary, tag)),
			func(ctx context.Context, in *struct {
				ID uuid.UUID `path:"id"`
			}) (*httpx.Response[FriendRequestDTO], error) {
				r, err := s.Respond(ctx, in.ID, action)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *r), nil
			})
	}
	httpx.Protected(api, social(httpx.Op("connections-remove", http.MethodDelete, "/connections/{userId}", "Remove a friend", tag)),
		func(ctx context.Context, in *UserPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.RemoveFriend(ctx, in.UserID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, social(httpx.Op("users-block", http.MethodPost, "/users/{userId}/block",
		"Block someone (removes the connection and pending requests; they can no longer find or contact you)", tag)),
		func(ctx context.Context, in *UserPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.Block(ctx, in.UserID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, social(httpx.Op("users-unblock", http.MethodDelete, "/users/{userId}/block", "Unblock someone", tag)),
		func(ctx context.Context, in *UserPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.Unblock(ctx, in.UserID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, social(httpx.Op("users-mute", http.MethodPost, "/users/{userId}/mute",
		"Mute or unmute someone (you stop getting their notifications)", tag)),
		func(ctx context.Context, in *struct {
			UserPath
			Body MuteInput
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.Mute(ctx, in.UserID, !in.Body.Muted); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	type listInput struct {
		Cursor string `query:"cursor" maxLength:"512" doc:"meta.next_cursor of the previous page"`
		Limit  int    `query:"limit" minimum:"1" maximum:"200" default:"200"`
	}
	httpx.Protected(api, describe(httpx.Op("blocks-list", http.MethodGet, "/blocks", "People you blocked, newest first", tag),
		"Your own blocks only. Each person shows their display name and username (no avatar or bio), so you can recognize whom to unblock "+
			"(DELETE /users/{userId}/block). Pages with a cursor (meta.next_cursor, meta.has_more)."),
		func(ctx context.Context, in *listInput) (*httpx.Response[[]BlockDTO], error) {
			l, next, err := s.Blocks(ctx, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, describe(httpx.Op("mutes-list", http.MethodGet, "/mutes", "People you muted, newest first", tag),
		"Your own mutes only, with the profile you may see (as in other lists). Unmute with POST /users/{userId}/mute {\"muted\": false}. "+
			"Pages with a cursor (meta.next_cursor, meta.has_more)."),
		func(ctx context.Context, in *listInput) (*httpx.Response[[]MuteDTO], error) {
			l, next, err := s.Mutes(ctx, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
}

func describe(op huma.Operation, description string) huma.Operation {
	op.Description = description
	return op
}

// RegisterJobs registers social jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobNotifyFriendRequest, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			RequestID uuid.UUID `json:"request_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return NotifyFriendRequest(ctx, tx, p.RequestID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
}

// OutboxRoutes maps social events to worker jobs.
func OutboxRoutes(relay *outbox.Relay) {
	relay.On(EventFriendRequest, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobNotifyFriendRequest, UserID: e.UserID, Payload: map[string]any{"request_id": *e.AggregateID},
			DedupeKey: "social.notify_friend_request:" + strconv.FormatInt(e.ID, 10)}}
	})
}
