package groups

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// GroupPerson is someone's minimal public profile in group flows: display
// name and username only, never finance data. Someone the caller may not
// see (a block either way, or a person who is not discoverable and has no
// relationship with the caller; montra.minimal_profile) shows as
// "Montra user" without a username.
type GroupPerson struct {
	UserID      uuid.UUID `json:"user_id"`
	DisplayName string    `json:"display_name"`
	Username    *string   `json:"username,omitempty"`
}

// personOf builds a GroupPerson from montra.minimal_profile columns (nil
// name: not visible to the caller).
func personOf(id *uuid.UUID, name, username *string) *GroupPerson {
	if id == nil {
		return nil
	}
	p := &GroupPerson{UserID: *id, DisplayName: "Montra user"}
	if name != nil {
		p.DisplayName, p.Username = *name, username
	}
	return p
}

// personFor reads one person's minimal profile as the caller may see it.
func personFor(ctx context.Context, tx pgx.Tx, id *uuid.UUID) (*GroupPerson, error) {
	if id == nil {
		return nil, nil
	}
	var name, username *string
	err := tx.QueryRow(ctx, `select display_name, username from montra.minimal_profile($1)`, *id).Scan(&name, &username)
	if err != nil && !database.IsNoRows(err) {
		return nil, err
	}
	return personOf(id, name, username), nil
}

func gone(msg string) error { return apperr.New(apperr.CodeGone, http.StatusGone, msg) }

// invitationUsed answers an invitation that was already accepted or
// declined (409 invitation_used).
func invitationUsed(status string) error {
	params := map[string]string{"status": status}
	if status == "declined" {
		return apperr.ConflictCode("invitation_used", "This invitation was declined.", params)
	}
	return apperr.ConflictCode("invitation_used", "This invitation was already used.", params)
}

// notMember refuses a caller who is already an active member.
func notMember(ctx context.Context, tx pgx.Tx, groupID, uid uuid.UUID) error {
	var member bool
	if err := tx.QueryRow(ctx, `select exists (select 1 from group_members where group_id = $1 and user_id = $2 and status = 'active')`,
		groupID, uid).Scan(&member); err != nil {
		return err
	}
	if member {
		return apperr.ConflictCode("already_member", "You are already a member of this group.", nil)
	}
	return nil
}

// GroupInvitationInput invites one person or creates a shareable link.
type GroupInvitationInput struct {
	Kind          string     `json:"kind" enum:"link,username" doc:"link: a shareable link (the token is shown once); username: addressed to one person, by username or, for your friends, by user_id"`
	Username      string     `json:"username,omitempty" maxLength:"31" doc:"kind username: someone who opted into username discovery (a leading @ is ignored)"`
	UserID        *uuid.UUID `json:"user_id,omitempty" doc:"kind username: one of your friends, found even when they turned username discovery off (anyone else answers 404)"`
	ExpiresInDays int        `json:"expires_in_days,omitempty" minimum:"1" maximum:"30" doc:"Default 7"`
	MaxUses       *int32     `json:"max_uses,omitempty" minimum:"1" maximum:"1000" doc:"Links only (a username invitation is used once)"`
}

// GroupInvitationDTO is an invitation (the link token is returned only once).
type GroupInvitationDTO struct {
	ID        uuid.UUID    `json:"id"`
	GroupID   uuid.UUID    `json:"group_id"`
	GroupName string       `json:"group_name"`
	Kind      string       `json:"kind" enum:"link,username"`
	Token     *string      `json:"token,omitempty" doc:"Shown once when a link is created"`
	InviteeID *uuid.UUID   `json:"invitee_user_id,omitempty"`
	Invitee   *GroupPerson `json:"invitee,omitempty" doc:"Username invitations: the person invited (minimal profile as you may see it)"`
	InvitedBy *GroupPerson `json:"invited_by,omitempty" doc:"Who created the invitation (minimal profile as you may see it; absent when their account was deleted)"`
	MaxUses   *int32       `json:"max_uses,omitempty"`
	UseCount  int32        `json:"use_count"`
	Status    string       `json:"status" enum:"active,accepted,declined,revoked,expired"`
	ExpiresAt time.Time    `json:"expires_at"`
	CreatedAt time.Time    `json:"created_at"`
}

// invitationCols reads invitations with both people's minimal profiles;
// queries using it join `ip` (invitee) and `bp` (inviter) laterally on
// montra.minimal_profile.
const invitationCols = `i.id, i.group_id, i.kind, i.invitee_user_id, i.max_uses, i.use_count,
	case when i.status = 'active' and (i.expires_at <= now() or (i.max_uses is not null and i.use_count >= i.max_uses)) then 'expired' else i.status end,
	i.expires_at, i.created_at, i.invited_by, ip.display_name, ip.username, bp.display_name, bp.username`

const invitationPeople = ` left join lateral montra.minimal_profile(i.invitee_user_id) ip on true
	left join lateral montra.minimal_profile(i.invited_by) bp on true`

func scanInvitation(r pgx.CollectableRow) (GroupInvitationDTO, error) {
	var x GroupInvitationDTO
	var invitedBy *uuid.UUID
	var inviteeName, inviteeUser, inviterName, inviterUser *string
	if err := r.Scan(&x.ID, &x.GroupID, &x.Kind, &x.InviteeID, &x.MaxUses, &x.UseCount, &x.Status, &x.ExpiresAt, &x.CreatedAt, &invitedBy,
		&inviteeName, &inviteeUser, &inviterName, &inviterUser); err != nil {
		return x, err
	}
	x.Invitee, x.InvitedBy = personOf(x.InviteeID, inviteeName, inviteeUser), personOf(invitedBy, inviterName, inviterUser)
	return x, nil
}

// resolveInvitee finds the person a username invitation is for: someone
// who opted into username discovery (by username), or one of the caller's
// friends (by user_id, whatever their discovery setting). Anyone else
// stays undiscoverable (404, like an unknown user).
func resolveInvitee(ctx context.Context, tx pgx.Tx, uid uuid.UUID, username string, userID *uuid.UUID) (uuid.UUID, error) {
	username = strings.ToLower(strings.TrimPrefix(strings.TrimSpace(username), "@"))
	switch {
	case userID != nil && username != "":
		return uuid.Nil, apperr.FieldError("body.user_id", "Send a username or a friend's user ID, not both.")
	case userID != nil:
		if *userID == uid {
			return uid, nil // the membership check answers already_member
		}
		var friend bool
		if err := tx.QueryRow(ctx, `select montra.are_connected($1, $2) and montra.user_is_active($2)`, uid, *userID).Scan(&friend); err != nil {
			return uuid.Nil, err
		}
		if !friend {
			return uuid.Nil, apperr.NotFound("user")
		}
		return *userID, nil
	case username != "":
		var found *uuid.UUID
		if err := tx.QueryRow(ctx, `select montra.discoverable_user_id($1)`, username).Scan(&found); err != nil {
			return uuid.Nil, err
		}
		if found == nil {
			return uuid.Nil, apperr.NotFound("user")
		}
		return *found, nil
	default:
		return uuid.Nil, apperr.FieldError("body.username", "Choose who to invite: a username, or one of your friends (user_id).")
	}
}

// Invite creates an invitation (admins, or members when allowed).
func (s *Service) Invite(ctx context.Context, groupID uuid.UUID, in GroupInvitationInput) (*GroupInvitationDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out GroupInvitationDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		if err := requireActive(g); err != nil {
			return err
		}
		if role == "member" && !g.AllowMemberInvites {
			return apperr.Forbidden()
		}
		days := in.ExpiresInDays
		if days == 0 {
			days = 7
		}
		exp := s.now().Add(time.Duration(days) * 24 * time.Hour)
		id := uuid.New()
		out = GroupInvitationDTO{ID: id, GroupID: groupID, GroupName: g.Name, Kind: in.Kind, MaxUses: in.MaxUses, Status: "active", ExpiresAt: exp, CreatedAt: s.now()}
		switch in.Kind {
		case "link":
			if in.UserID != nil {
				return apperr.FieldError("body.user_id", "A link is not addressed to anyone; use kind username to invite one person.")
			}
			raw := make([]byte, 24)
			if _, err := rand.Read(raw); err != nil {
				return err
			}
			tok := base64.RawURLEncoding.EncodeToString(raw)
			out.Token = &tok
			if _, err := tx.Exec(ctx, `insert into group_invitations (id, group_id, invited_by, kind, token_hash, max_uses, expires_at)
				values ($1,$2,$3,'link',$4,$5,$6)`, id, groupID, uid, crypto.HashToken(tok), in.MaxUses, exp); err != nil {
				return err
			}
		case "username":
			invitee, err := resolveInvitee(ctx, tx, uid, in.Username, in.UserID)
			if err != nil {
				return err
			}
			var blocked, member bool
			if err := tx.QueryRow(ctx, `select montra.is_blocked_between($1, $2),
				exists (select 1 from group_members where group_id = $3 and user_id = $2 and status = 'active')`, uid, invitee, groupID).
				Scan(&blocked, &member); err != nil {
				return err
			}
			if blocked {
				return apperr.NotFound("user")
			}
			if member {
				return apperr.ConflictCode("already_member", "This person is already a member.", nil)
			}
			one := int32(1)
			out.InviteeID, out.MaxUses = &invitee, &one
			if _, err := tx.Exec(ctx, `insert into group_invitations (id, group_id, invited_by, kind, invitee_user_id, max_uses, expires_at)
				values ($1,$2,$3,'username',$4,1,$5)`, id, groupID, uid, invitee, exp); err != nil {
				return err
			}
		}
		if out.Invitee, err = personFor(ctx, tx, out.InviteeID); err != nil {
			return err
		}
		if out.InvitedBy, err = personFor(ctx, tx, &uid); err != nil {
			return err
		}
		if err := activity(ctx, tx, groupID, &uid, "invitation_created", "group_invitation", &id, map[string]any{"kind": in.Kind}); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, GroupID: &groupID, EntityType: "group_invitation", EntityID: &id, Action: "created"})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// RevokeInvitation revokes an invitation (admins, or its creator).
// Revoking twice is harmless; an accepted or declined invitation answers
// 409 invitation_used.
func (s *Service) RevokeInvitation(ctx context.Context, groupID, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, _, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		var status string
		var invitedBy *uuid.UUID
		if err := tx.QueryRow(ctx, `select status, invited_by from group_invitations where id = $1 and group_id = $2 for update`, id, groupID).
			Scan(&status, &invitedBy); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("invitation")
			}
			return err
		}
		if role == "member" && (invitedBy == nil || *invitedBy != uid) {
			return apperr.NotFound("invitation") // members manage only their own invitations
		}
		switch status {
		case "revoked":
			return nil
		case "accepted", "declined":
			return invitationUsed(status)
		}
		if _, err := tx.Exec(ctx, `update group_invitations set status = 'revoked', revoked_at = now() where id = $1`, id); err != nil {
			return err
		}
		return activity(ctx, tx, groupID, &uid, "invitation_revoked", "group_invitation", &id, nil)
	}))
}

// MyInvitations lists invitations addressed to the caller that can still be
// accepted (the group is active and nobody blocked anybody).
func (s *Service) MyInvitations(ctx context.Context) ([]GroupInvitationDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []GroupInvitationDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		// The invitee is not a member yet, so the group's name and status
		// come from a helper limited to the invitee.
		rows, err := tx.Query(ctx, `select `+invitationCols+`, f.group_name from group_invitations i
			join lateral montra.group_for_invitee(i.id) f on true`+invitationPeople+`
			where i.invitee_user_id = $1 and i.status = 'active' and i.expires_at > now() and f.group_status = 'active'
			and not montra.is_blocked_between($1, i.invited_by) order by i.created_at desc`, uid)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (GroupInvitationDTO, error) {
			var x GroupInvitationDTO
			var invitedBy *uuid.UUID
			var inviteeName, inviteeUser, inviterName, inviterUser *string
			err := r.Scan(&x.ID, &x.GroupID, &x.Kind, &x.InviteeID, &x.MaxUses, &x.UseCount, &x.Status, &x.ExpiresAt, &x.CreatedAt, &invitedBy,
				&inviteeName, &inviteeUser, &inviterName, &inviterUser, &x.GroupName)
			x.Invitee, x.InvitedBy = personOf(x.InviteeID, inviteeName, inviteeUser), personOf(invitedBy, inviterName, inviterUser)
			return x, err
		})
		return err
	})
	return out, database.MapError(err)
}

// InviterName is the minimal profile of whoever created a link, as the
// link holder may see it before joining: display name, and username only
// when the person is discoverable or connected to the holder.
type InviterName struct {
	DisplayName string  `json:"display_name"`
	Username    *string `json:"username,omitempty"`
}

// GroupInvitationPreview shows a link invitation before joining.
type GroupInvitationPreview struct {
	GroupID          uuid.UUID    `json:"group_id"`
	GroupName        string       `json:"group_name"`
	GroupType        string       `json:"group_type" enum:"household,roommates,trip,event,friends,custom"`
	MemberCount      int          `json:"member_count" doc:"Active members"`
	InvitedBy        *InviterName `json:"invited_by,omitempty" doc:"Who created the link (absent when their account was deleted)"`
	AlreadyMember    bool         `json:"already_member" doc:"You are already an active member (accepting answers 409 already_member)"`
	RequiresApproval bool         `json:"requires_approval" doc:"Accepting creates a join request for the group's admins (202) instead of joining"`
	Status           string       `json:"status" enum:"active,accepted,declined,revoked,expired"`
	ExpiresAt        time.Time    `json:"expires_at"`
}

// linkInvitation is a link invitation as its token holder may see it
// (montra.group_invitation_preview).
type linkInvitation struct {
	id, groupID                  uuid.UUID
	groupName, groupType         string
	status, groupStatus          string
	expiresAt                    time.Time
	maxUses                      *int32
	uses                         int32
	approval                     bool
	memberCount                  int
	invitedBy                    *uuid.UUID
	inviterName, inviterUsername *string
}

// loadLink reads the invitation behind a link token. Unknown tokens, and
// links whose creator and holder blocked each other, are not valid (410).
func loadLink(ctx context.Context, tx pgx.Tx, token string) (*linkInvitation, error) {
	var l linkInvitation
	var blocked bool
	err := tx.QueryRow(ctx, `select invitation_id, group_id, group_name, group_type, status, expires_at, max_uses, use_count, group_status,
		require_join_approval, member_count, invited_by, inviter_display_name, inviter_username, inviter_blocked
		from montra.group_invitation_preview($1)`, crypto.HashToken(token)).Scan(&l.id, &l.groupID, &l.groupName, &l.groupType, &l.status,
		&l.expiresAt, &l.maxUses, &l.uses, &l.groupStatus, &l.approval, &l.memberCount, &l.invitedBy, &l.inviterName, &l.inviterUsername, &blocked)
	if database.IsNoRows(err) || (err == nil && blocked) {
		return nil, gone("This invitation link is not valid.")
	}
	if err != nil {
		return nil, err
	}
	return &l, nil
}

// usable reports whether the link can still be redeemed.
func (l *linkInvitation) usable(now time.Time) bool {
	return l.status == "active" && l.expiresAt.After(now) && (l.maxUses == nil || l.uses < *l.maxUses) && l.groupStatus == "active"
}

// Preview returns what a link invitation is for.
func (s *Service) Preview(ctx context.Context, token string) (*GroupInvitationPreview, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out GroupInvitationPreview
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		l, err := loadLink(ctx, tx, token)
		if err != nil {
			return err
		}
		out = GroupInvitationPreview{GroupID: l.groupID, GroupName: l.groupName, GroupType: l.groupType, MemberCount: l.memberCount,
			RequiresApproval: l.approval, Status: l.status, ExpiresAt: l.expiresAt}
		if l.invitedBy != nil {
			out.InvitedBy = &InviterName{DisplayName: "Montra user", Username: l.inviterUsername}
			if l.inviterName != nil {
				out.InvitedBy.DisplayName = *l.inviterName
			}
		}
		if out.Status == "active" && !l.usable(s.now()) {
			out.Status = "expired"
		}
		return tx.QueryRow(ctx, `select exists (select 1 from group_members where group_id = $1 and user_id = $2 and status = 'active')`,
			l.groupID, uid).Scan(&out.AlreadyMember)
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// redemption is one use of a validated invitation.
type redemption struct {
	id, groupID uuid.UUID
	maxUses     *int32
	uses        int32
}

// redeemUse counts one use of the invitation; it is used up at max_uses.
// The validated invitation authorizes the caller's update (RLS policy).
func redeemUse(ctx context.Context, tx pgx.Tx, r redemption) error {
	next := "active"
	if r.maxUses != nil && r.uses+1 >= *r.maxUses {
		next = "accepted"
	}
	if _, err := tx.Exec(ctx, `select set_config('montra.redeem_invitation_id', $1, true)`, r.id.String()); err != nil {
		return err
	}
	tag, err := tx.Exec(ctx, `update group_invitations set use_count = use_count + 1, status = $2 where id = $1`, r.id, next)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		// RLS skips rows silently; a use that is not counted must never pass.
		return apperr.Internal(errors.New("invitation use was not counted"))
	}
	_, err = tx.Exec(ctx, `select set_config('montra.redeem_invitation_id', '', true)`)
	return err
}

// join makes the caller a member through a validated invitation.
func (s *Service) join(ctx context.Context, tx pgx.Tx, uid uuid.UUID, r redemption) (*GroupDetail, error) {
	// The validated invitation authorizes this self-join (RLS policies).
	if _, err := tx.Exec(ctx, `select set_config('montra.join_group_id', $1, true)`, r.groupID.String()); err != nil {
		return nil, err
	}
	var name string
	_ = tx.QueryRow(ctx, `select display_name from profiles where user_id = $1`, uid).Scan(&name)
	if _, err := tx.Exec(ctx, `insert into group_members (group_id, user_id, role, status, display_name_snapshot) values ($1,$2,'member','active',$3)
		on conflict (group_id, user_id) do update set status = 'active', role = 'member', left_at = null, removed_by = null, joined_at = now()`,
		r.groupID, uid, trim(name, 80)); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `select set_config('montra.join_group_id', '', true)`); err != nil {
		return nil, err
	}
	if err := redeemUse(ctx, tx, r); err != nil {
		return nil, err
	}
	gid := r.groupID
	if err := activity(ctx, tx, gid, &uid, "member_joined", "group_member", &uid, map[string]any{"via": "invitation"}); err != nil {
		return nil, err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, GroupID: &gid, EntityType: "group_member", EntityID: &uid, Action: "joined"}); err != nil {
		return nil, err
	}
	return detail(ctx, tx, gid)
}

// requestFromLink turns an accepted link into a join request when the group
// requires approval. The use is counted now, so a link never raises more
// requests than its max_uses.
func (s *Service) requestFromLink(ctx context.Context, tx pgx.Tx, uid uuid.UUID, r redemption) (*GroupJoinRequestDTO, error) {
	out := &GroupJoinRequestDTO{ID: uuid.New(), GroupID: r.groupID, UserID: uid, Status: "pending", InvitationID: &r.id}
	if err := tx.QueryRow(ctx, `insert into group_join_requests (id, group_id, user_id, invitation_id) values ($1,$2,$3,$4) returning created_at`,
		out.ID, r.groupID, uid, r.id).Scan(&out.CreatedAt); err != nil {
		if database.IsUniqueViolation(err, "group_join_requests_pending") {
			return nil, joinRequestPending()
		}
		return nil, err
	}
	if err := redeemUse(ctx, tx, r); err != nil {
		return nil, err
	}
	_ = tx.QueryRow(ctx, `select display_name from profiles where user_id = $1`, uid).Scan(&out.DisplayName)
	// The requester is not a member and cannot write the group's log; the
	// worker records the activity and notifies the admins.
	gid := r.groupID
	return out, outbox.Emit(ctx, tx, outbox.Event{Type: EventJoinRequested, AggregateType: "group_join_request", AggregateID: out.ID, UserID: &uid, GroupID: &gid})
}

// AcceptLink redeems an invitation link: the caller joins the group, or,
// when the group requires approval, a join request waits for its admins
// (the detail is then nil and the request is returned).
func (s *Service) AcceptLink(ctx context.Context, token string) (*GroupDetail, *GroupJoinRequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, nil, err
	}
	var out *GroupDetail
	var req *GroupJoinRequestDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		l, err := loadLink(ctx, tx, token)
		if err != nil {
			return err
		}
		if !l.usable(s.now()) {
			return gone("This invitation has expired or was already used.")
		}
		if err := notMember(ctx, tx, l.groupID, uid); err != nil {
			return err
		}
		r := redemption{id: l.id, groupID: l.groupID, maxUses: l.maxUses, uses: l.uses}
		if l.approval {
			req, err = s.requestFromLink(ctx, tx, uid, r)
			return err
		}
		out, err = s.join(ctx, tx, uid, r)
		return err
	})
	if err != nil {
		return nil, nil, database.MapError(err)
	}
	return out, req, nil
}

// AcceptInvitation accepts a username invitation addressed to the caller.
// It always joins directly: the invitation names the person, so a group's
// join approval (which applies to link holders) does not apply.
func (s *Service) AcceptInvitation(ctx context.Context, id uuid.UUID) (*GroupDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		r := redemption{id: id}
		var status string
		var exp time.Time
		var invitedBy *uuid.UUID
		if err := tx.QueryRow(ctx, `select group_id, status, expires_at, max_uses, use_count, invited_by from group_invitations
			where id = $1 and kind = 'username' and invitee_user_id = $2 for update`, id, uid).Scan(&r.groupID, &status, &exp, &r.maxUses, &r.uses,
			&invitedBy); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("invitation")
			}
			return err
		}
		if status == "accepted" || status == "declined" {
			return invitationUsed(status)
		}
		var groupStatus string
		if err := tx.QueryRow(ctx, `select group_status from montra.group_for_invitee($1)`, id).Scan(&groupStatus); err != nil && !database.IsNoRows(err) {
			return err
		}
		if status != "active" || !exp.After(s.now()) || groupStatus != "active" {
			return gone("This invitation has expired or is no longer valid.")
		}
		if err := notMember(ctx, tx, r.groupID, uid); err != nil {
			return err
		}
		if invitedBy != nil {
			var blocked bool
			if err := tx.QueryRow(ctx, `select montra.is_blocked_between($1, $2)`, uid, *invitedBy).Scan(&blocked); err != nil {
				return err
			}
			if blocked {
				return gone("This invitation is not valid.")
			}
		}
		var err error
		out, err = s.join(ctx, tx, uid, r)
		return err
	})
	return out, database.MapError(err)
}

// DeclineInvitation declines a username invitation addressed to the caller.
func (s *Service) DeclineInvitation(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var status string
		var exp time.Time
		if err := tx.QueryRow(ctx, `select status, expires_at from group_invitations where id = $1 and invitee_user_id = $2 for update`, id, uid).
			Scan(&status, &exp); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("invitation")
			}
			return err
		}
		if status == "accepted" || status == "declined" {
			return invitationUsed(status)
		}
		if status != "active" || !exp.After(s.now()) {
			return gone("This invitation has expired or was revoked.")
		}
		_, err := tx.Exec(ctx, `update group_invitations set status = 'declined' where id = $1`, id)
		return err
	}))
}

// Invitations lists a group's invitations (admins see all; members see the
// ones they created). Link tokens are never shown again.
func (s *Service) Invitations(ctx context.Context, groupID uuid.UUID, includeInactive bool) ([]GroupInvitationDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []GroupInvitationDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		role, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select `+invitationCols+` from group_invitations i`+invitationPeople+`
			where i.group_id = $1 and ($2 or i.invited_by = $3) and ($4 or (i.status = 'active' and i.expires_at > now()))
			order by i.created_at desc limit 200`, groupID, role != "member", uid, includeInactive)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, scanInvitation)
		for i := range out {
			out[i].GroupName = g.Name
		}
		return err
	})
	return out, database.MapError(err)
}
