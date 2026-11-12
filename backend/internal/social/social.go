// Package social implements the private-by-default social graph (spec
// §4.15, §20B.16): exact username search (opt-in discoverability), friend
// requests, connections, blocks and mutes. Profiles never carry balances or
// transactions; blocking hides profiles and stops requests in both
// directions.
package social

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// Service implements the social graph.
type Service struct {
	DB *database.DB
}

// PublicProfile is the minimal profile other users may see.
type PublicProfile struct {
	UserID      uuid.UUID  `json:"user_id"`
	DisplayName string     `json:"display_name"`
	Username    *string    `json:"username,omitempty"`
	AvatarFile  *uuid.UUID `json:"avatar_file_id,omitempty"`
	Bio         *string    `json:"bio,omitempty" doc:"Only when the profile is visible to you"`
	Connection  string     `json:"connection" enum:"self,friend,request_sent,request_received,none"`
	Muted       bool       `json:"muted" doc:"You muted this person (only you see this)"`
	BlockedByMe bool       `json:"blocked_by_me" doc:"You blocked this person. Whether someone blocked you is never disclosed"`
}

// relate fills in the caller's relationship with the person: connection
// state, and whether the caller muted or blocked them (the caller's own
// block and mute rows only; RLS hides everyone else's).
func relate(ctx context.Context, tx pgx.Tx, me uuid.UUID, p *PublicProfile) error {
	if me == p.UserID {
		p.Connection = "self"
		return nil
	}
	var friend, sent, recv bool
	if err := tx.QueryRow(ctx, `select exists (select 1 from user_connections where user_id = $1 and friend_id = $2),
		exists (select 1 from friend_requests where requester_id = $1 and addressee_id = $2 and status = 'pending'),
		exists (select 1 from friend_requests where requester_id = $2 and addressee_id = $1 and status = 'pending'),
		exists (select 1 from user_mutes where muter_id = $1 and muted_id = $2),
		exists (select 1 from user_blocks where blocker_id = $1 and blocked_id = $2)`, me, p.UserID).
		Scan(&friend, &sent, &recv, &p.Muted, &p.BlockedByMe); err != nil {
		return err
	}
	switch {
	case friend:
		p.Connection = "friend"
	case sent:
		p.Connection = "request_sent"
	case recv:
		p.Connection = "request_received"
	default:
		p.Connection = "none"
	}
	return nil
}

// Search finds a discoverable user by their exact username (case
// insensitive, a leading @ ignored). Partial usernames match nobody, people
// who did not opt into discovery are never found and blocks hide both ways.
func (s *Service) Search(ctx context.Context, q string) ([]PublicProfile, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	q = strings.ToLower(strings.TrimPrefix(strings.TrimSpace(q), "@"))
	if len(q) < 3 {
		return nil, apperr.FieldError("query.q", "Enter the full username (at least 3 characters).")
	}
	out := []PublicProfile{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		// Discovery sees only the minimal profile of opted-in users
		// (montra.search_discoverable matches the exact username).
		rows, err := tx.Query(ctx, `select user_id, display_name, username, avatar_file_id from montra.search_discoverable($1, 20)`, q)
		if err != nil {
			return err
		}
		list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (PublicProfile, error) {
			var p PublicProfile
			err := r.Scan(&p.UserID, &p.DisplayName, &p.Username, &p.AvatarFile)
			return p, err
		})
		if err != nil {
			return err
		}
		for _, p := range list {
			if p.Username == nil || *p.Username != q {
				continue // exact matches only, whatever the helper returns
			}
			if err := relate(ctx, tx, uid, &p); err != nil {
				return err
			}
			out = append(out, p)
		}
		return nil
	})
	return out, database.MapError(err)
}

// FriendRequestDTO is a friend request.
type FriendRequestDTO struct {
	ID        uuid.UUID     `json:"id"`
	From      PublicProfile `json:"from"`
	To        PublicProfile `json:"to"`
	Message   *string       `json:"message,omitempty"`
	Status    string        `json:"status" enum:"pending,accepted,declined,cancelled"`
	CreatedAt time.Time     `json:"created_at"`
}

func profileOf(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (PublicProfile, error) {
	p := PublicProfile{UserID: id, DisplayName: "Montra user"}
	// Name, username and avatar for anyone the caller has a relationship
	// with (montra.minimal_profile); the bio only when the full profile is
	// visible (montra.can_view_profile via RLS on profiles).
	err := tx.QueryRow(ctx, `select display_name, username, avatar_file_id from montra.minimal_profile($1)`, id).
		Scan(&p.DisplayName, &p.Username, &p.AvatarFile)
	if database.IsNoRows(err) {
		// Someone the caller blocked stays recognizable in their block list
		// by name and username only (montra.blocked_user_profile); blocks
		// still hide everything else both ways.
		err = tx.QueryRow(ctx, `select display_name, username from montra.blocked_user_profile($1)`, id).Scan(&p.DisplayName, &p.Username)
	}
	if err != nil && !database.IsNoRows(err) {
		return p, err
	}
	if err := tx.QueryRow(ctx, `select bio from profiles where user_id = $1`, id).Scan(&p.Bio); err != nil && !database.IsNoRows(err) {
		return p, err
	}
	return p, relate(ctx, tx, me, &p)
}

// SendInput sends a friend request.
type SendInput struct {
	UserID   *uuid.UUID `json:"user_id,omitempty"`
	Username string     `json:"username,omitempty" maxLength:"31"`
	Message  string     `json:"message,omitempty" maxLength:"200"`
}

// SendRequest sends a friend request (or accepts the reverse request).
func (s *Service) SendRequest(ctx context.Context, in SendInput) (*FriendRequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *FriendRequestDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var target uuid.UUID
		switch {
		case in.UserID != nil:
			target = *in.UserID
		case in.Username != "":
			var found *uuid.UUID
			if err := tx.QueryRow(ctx, `select montra.discoverable_user_id($1)`, strings.ToLower(strings.TrimPrefix(strings.TrimSpace(in.Username), "@"))).
				Scan(&found); err != nil {
				return err
			}
			if found == nil {
				return apperr.NotFound("user")
			}
			target = *found
		default:
			return apperr.Validation("Choose who to send the request to.")
		}
		if target == uid {
			return apperr.FieldError("body.user_id", "You cannot add yourself.")
		}
		var exists, blocked, friends bool
		if err := tx.QueryRow(ctx, `select montra.user_is_active($1), montra.is_blocked_between($1, $2), montra.are_connected($2, $1)`, target, uid).
			Scan(&exists, &blocked, &friends); err != nil {
			return err
		}
		if !exists || blocked {
			return apperr.NotFound("user") // blocks are not disclosed
		}
		if friends {
			return apperr.ConflictCode("already_friends", "You are already friends.", nil)
		}
		// A request of yours that is still pending answers request_pending; a
		// pending request from them is accepted instead of duplicated.
		pending := func() (bool, error) {
			var rid, from uuid.UUID
			err := tx.QueryRow(ctx, `select id, requester_id from friend_requests where status = 'pending'
				and ((requester_id = $1 and addressee_id = $2) or (requester_id = $2 and addressee_id = $1))`, uid, target).Scan(&rid, &from)
			if database.IsNoRows(err) {
				return false, nil
			}
			if err != nil {
				return false, err
			}
			if from == uid {
				return true, apperr.ConflictCode("request_pending", "You already sent this person a friend request.", nil)
			}
			if err := s.accept(ctx, tx, uid, rid); err != nil {
				return true, err
			}
			out, err = s.loadRequest(ctx, tx, uid, rid)
			return true, err
		}
		if handled, err := pending(); handled || err != nil {
			return err
		}
		var allowed bool
		if err := tx.QueryRow(ctx, `select montra.friend_request_allowed($1)`, target).Scan(&allowed); err != nil {
			return err
		}
		if !allowed {
			return apperr.Rule("requests_closed", "This person is not accepting friend requests.", nil)
		}
		var recent int
		if err := tx.QueryRow(ctx, `select count(*) from friend_requests where requester_id = $1 and created_at > now() - interval '1 day'`, uid).
			Scan(&recent); err != nil {
			return err
		}
		if recent >= 50 {
			return apperr.RateLimited()
		}
		id := uuid.New()
		msg := strings.TrimSpace(in.Message)
		var mp *string
		if msg != "" {
			mp = &msg
		}
		// A savepoint keeps the transaction usable when a request between
		// the two of you became pending meanwhile (sent at the same moment).
		sp, err := tx.Begin(ctx)
		if err != nil {
			return err
		}
		if _, err := sp.Exec(ctx, `insert into friend_requests (id, requester_id, addressee_id, message) values ($1,$2,$3,$4)`, id, uid, target, mp); err != nil {
			if rbErr := sp.Rollback(ctx); rbErr != nil {
				return rbErr
			}
			if !database.IsUniqueViolation(err, "friend_requests_pending_pair") {
				return err
			}
			if handled, err := pending(); handled || err != nil {
				return err
			}
			// The other request was answered in the meantime.
			return apperr.ConflictCode("request_pending", "A friend request between you was just sent; try again.", nil)
		}
		if err := sp.Commit(ctx); err != nil {
			return err
		}
		if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventFriendRequest, AggregateType: "friend_request", AggregateID: id, UserID: &target}); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "friend_request", EntityID: &id, Action: "sent"}); err != nil {
			return err
		}
		out, err = s.loadRequest(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// EventFriendRequest notifies the addressee (worker).
const EventFriendRequest = "social.friend_request"

func (s *Service) loadRequest(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (*FriendRequestDTO, error) {
	var r FriendRequestDTO
	var from, to uuid.UUID
	if err := tx.QueryRow(ctx, `select id, requester_id, addressee_id, message, status, created_at from friend_requests where id = $1`, id).
		Scan(&r.ID, &from, &to, &r.Message, &r.Status, &r.CreatedAt); err != nil {
		if database.IsNoRows(err) {
			return nil, apperr.NotFound("friend request")
		}
		return nil, err
	}
	var err error
	if r.From, err = profileOf(ctx, tx, me, from); err != nil {
		return nil, err
	}
	r.To, err = profileOf(ctx, tx, me, to)
	return &r, err
}

func (s *Service) accept(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) error {
	var from uuid.UUID
	tag, err := tx.Exec(ctx, `update friend_requests set status = 'accepted', responded_at = now() where id = $1 and addressee_id = $2 and status = 'pending'`, id, uid)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return apperr.NotFound("pending friend request")
	}
	if err := tx.QueryRow(ctx, `select requester_id from friend_requests where id = $1`, id).Scan(&from); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `insert into user_connections (user_id, friend_id) values ($1,$2),($2,$1) on conflict do nothing`, uid, from); err != nil {
		return err
	}
	return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "friend_request", EntityID: &id, Action: "accepted"})
}

// Respond accepts or declines a received request, or cancels a sent one.
func (s *Service) Respond(ctx context.Context, id uuid.UUID, action string) (*FriendRequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *FriendRequestDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		switch action {
		case "accept":
			if err := s.accept(ctx, tx, uid, id); err != nil {
				return err
			}
		case "decline", "cancel":
			col := map[string]string{"decline": "addressee_id", "cancel": "requester_id"}[action]
			status := map[string]string{"decline": "declined", "cancel": "cancelled"}[action]
			tag, err := tx.Exec(ctx, `update friend_requests set status = $3, responded_at = now() where id = $1 and `+col+` = $2 and status = 'pending'`,
				id, uid, status)
			if err != nil {
				return err
			}
			if tag.RowsAffected() == 0 {
				return apperr.NotFound("pending friend request")
			}
		default:
			return apperr.BadRequest("Unknown action.")
		}
		var err error
		out, err = s.loadRequest(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Requests lists pending requests sent and received.
func (s *Service) Requests(ctx context.Context) ([]FriendRequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []FriendRequestDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id from friend_requests where status = 'pending' and (requester_id = $1 or addressee_id = $1)
			order by created_at desc limit 200`, uid)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, id := range ids {
			r, err := s.loadRequest(ctx, tx, uid, id)
			if err != nil {
				return err
			}
			out = append(out, *r)
		}
		return nil
	})
	return out, database.MapError(err)
}

// Friends lists connections.
func (s *Service) Friends(ctx context.Context) ([]PublicProfile, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []PublicProfile{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select friend_id from user_connections where user_id = $1 order by created_at desc limit 1000`, uid)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, id := range ids {
			p, err := profileOf(ctx, tx, uid, id)
			if err != nil {
				return err
			}
			out = append(out, p)
		}
		return nil
	})
	return out, database.MapError(err)
}

// RemoveFriend removes a connection in both directions.
func (s *Service) RemoveFriend(ctx context.Context, other uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from user_connections where (user_id = $1 and friend_id = $2) or (user_id = $2 and friend_id = $1)`, uid, other)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("connection")
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "connection", EntityID: &other, Action: "removed"})
	}))
}

// Block blocks a user: connections and pending requests are removed, and
// profiles and requests are hidden both ways. Shared group records stay
// (history), but blocked users cannot invite each other.
func (s *Service) Block(ctx context.Context, other uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	if other == uid {
		return apperr.FieldError("path.id", "You cannot block yourself.")
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var exists bool
		if err := tx.QueryRow(ctx, `select montra.user_is_active($1)`, other).Scan(&exists); err != nil || !exists {
			if err == nil {
				return apperr.NotFound("user")
			}
			return err
		}
		if _, err := tx.Exec(ctx, `insert into user_blocks (blocker_id, blocked_id) values ($1,$2) on conflict do nothing`, uid, other); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `delete from user_connections where (user_id = $1 and friend_id = $2) or (user_id = $2 and friend_id = $1)`, uid, other); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update friend_requests set status = 'cancelled', responded_at = now() where status = 'pending'
			and ((requester_id = $1 and addressee_id = $2) or (requester_id = $2 and addressee_id = $1))`, uid, other); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "user_block", EntityID: &other, Action: "blocked"})
	}))
}

// Unblock removes a block.
func (s *Service) Unblock(ctx context.Context, other uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from user_blocks where blocker_id = $1 and blocked_id = $2`, uid, other)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("block")
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "user_block", EntityID: &other, Action: "unblocked"})
	}))
}

// Mute hides a user's activity from your notifications/feeds (they are not
// told). Muting again unmutes when unmute is true.
func (s *Service) Mute(ctx context.Context, other uuid.UUID, unmute bool) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if unmute {
			_, err := tx.Exec(ctx, `delete from user_mutes where muter_id = $1 and muted_id = $2`, uid, other)
			return err
		}
		if other == uid {
			return apperr.FieldError("path.id", "You cannot mute yourself.")
		}
		var exists bool
		if err := tx.QueryRow(ctx, `select montra.user_is_active($1)`, other).Scan(&exists); err != nil {
			return err
		}
		if !exists {
			return apperr.NotFound("user")
		}
		_, err := tx.Exec(ctx, `insert into user_mutes (muter_id, muted_id) values ($1,$2) on conflict do nothing`, uid, other)
		return err
	}))
}

// BlockDTO is someone you blocked.
type BlockDTO struct {
	PublicProfile
	CreatedAt time.Time `json:"created_at" doc:"When you blocked them"`
}

// MuteDTO is someone you muted.
type MuteDTO struct {
	PublicProfile
	CreatedAt time.Time `json:"created_at" doc:"When you muted them"`
}

// maxListPage is the largest (and default) page of blocks or mutes.
const maxListPage = 200

type listCursor struct {
	At *time.Time `json:"t"`
	ID uuid.UUID  `json:"i"`
}

// ownList pages through the caller's own block or mute rows (RLS shows no
// one else's), newest first, with the person's profile as the API shows it
// elsewhere. query selects (user id, created_at) for $1 = the caller, with
// $2/$3 the cursor and $4 the row limit.
func (s *Service) ownList(ctx context.Context, query, cursor string, limit int) ([]PublicProfile, []time.Time, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, nil, "", err
	}
	if limit <= 0 || limit > maxListPage {
		limit = maxListPage
	}
	var cur listCursor
	if err := httpx.DecodeCursor(cursor, &cur); err != nil {
		return nil, nil, "", err
	}
	var profiles []PublicProfile
	var times []time.Time
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		type row struct {
			id uuid.UUID
			at time.Time
		}
		rows, err := tx.Query(ctx, query, uid, cur.At, cur.ID, limit+1)
		if err != nil {
			return err
		}
		list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (row, error) {
			var x row
			err := r.Scan(&x.id, &x.at)
			return x, err
		})
		if err != nil {
			return err
		}
		if len(list) > limit {
			last := list[limit-1]
			if next, err = httpx.EncodeCursor(listCursor{At: &last.at, ID: last.id}); err != nil {
				return err
			}
			list = list[:limit]
		}
		for _, x := range list {
			p, err := profileOf(ctx, tx, uid, x.id)
			if err != nil {
				return err
			}
			profiles, times = append(profiles, p), append(times, x.at)
		}
		return nil
	})
	return profiles, times, next, database.MapError(err)
}

// Blocks lists the people the caller blocked, newest first. Their name and
// username stay visible to the caller (never their avatar, bio or anything
// else), so the caller can recognize whom to unblock.
func (s *Service) Blocks(ctx context.Context, cursor string, limit int) ([]BlockDTO, string, error) {
	profiles, times, next, err := s.ownList(ctx, `select blocked_id, created_at from user_blocks where blocker_id = $1
		and ($2::timestamptz is null or (created_at, blocked_id) < ($2, $3)) order by created_at desc, blocked_id desc limit $4`, cursor, limit)
	if err != nil {
		return nil, "", err
	}
	out := make([]BlockDTO, 0, len(profiles))
	for i, p := range profiles {
		out = append(out, BlockDTO{PublicProfile: p, CreatedAt: times[i]})
	}
	return out, next, nil
}

// Mutes lists the people the caller muted, newest first, with the profile
// the caller may see (the minimal profile when they are related).
func (s *Service) Mutes(ctx context.Context, cursor string, limit int) ([]MuteDTO, string, error) {
	profiles, times, next, err := s.ownList(ctx, `select muted_id, created_at from user_mutes where muter_id = $1
		and ($2::timestamptz is null or (created_at, muted_id) < ($2, $3)) order by created_at desc, muted_id desc limit $4`, cursor, limit)
	if err != nil {
		return nil, "", err
	}
	out := make([]MuteDTO, 0, len(profiles))
	for i, p := range profiles {
		out = append(out, MuteDTO{PublicProfile: p, CreatedAt: times[i]})
	}
	return out, next, nil
}

// NotifyFriendRequest is the worker side of EventFriendRequest.
func NotifyFriendRequest(ctx context.Context, tx pgx.Tx, requestID uuid.UUID) error {
	var to, from uuid.UUID
	var status string
	if err := tx.QueryRow(ctx, `select addressee_id, requester_id, status from friend_requests where id = $1`, requestID).Scan(&to, &from, &status); err != nil {
		if database.IsNoRows(err) {
			return nil
		}
		return err
	}
	if status != "pending" {
		return nil
	}
	var muted bool
	if err := tx.QueryRow(ctx, `select exists (select 1 from user_mutes where muter_id = $1 and muted_id = $2)`, to, from).Scan(&muted); err != nil || muted {
		return err
	}
	// The link opens the requests tab (an app path with an enum value only).
	_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: to, Category: "social", EventType: "friend_request",
		Title: "New friend request", Body: "Open Friends to accept or decline.", DeepLink: "/friends?tab=requests", EntityType: "friend_request",
		EntityID: &requestID, DedupeKey: "friend_request:" + requestID.String()})
	return err
}
