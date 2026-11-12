package communities

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"net/http"
	"net/url"
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

// CommunityInvitationInput creates an invitation (moderators).
type CommunityInvitationInput struct {
	Username      string `json:"username,omitempty" maxLength:"31" doc:"Invite a person; omit to create a shareable link"`
	ExpiresInDays int    `json:"expires_in_days,omitempty" minimum:"1" maximum:"30" doc:"Default 7"`
}

// CommunityPersonDTO is the minimal profile of a person on an invitation,
// as the caller may see it (display name, and username only when the
// person is discoverable or connected to the caller).
type CommunityPersonDTO struct {
	UserID      uuid.UUID `json:"user_id"`
	DisplayName string    `json:"display_name"`
	Username    *string   `json:"username,omitempty"`
}

// CommunityInvitationDTO is an invitation (the link token is shown once).
type CommunityInvitationDTO struct {
	ID            uuid.UUID           `json:"id"`
	CommunityID   uuid.UUID           `json:"community_id"`
	CommunityName string              `json:"community_name,omitempty"`
	Kind          string              `json:"kind" enum:"link,username"`
	Token         *string             `json:"token,omitempty" doc:"Shown once; send it in request bodies, never in URLs"`
	ShareURL      *string             `json:"share_url,omitempty" doc:"Shown once with token: the web join link (token in the URL fragment, never sent to servers)"`
	InviteeID     *uuid.UUID          `json:"invitee_user_id,omitempty"`
	Invitee       *CommunityPersonDTO `json:"invitee,omitempty" doc:"Username invitations: the person invited"`
	InvitedBy     *CommunityPersonDTO `json:"invited_by,omitempty" doc:"Who created it (absent when their account was deleted)"`
	Status        string              `json:"status" enum:"active,used,declined,revoked,expired"`
	ExpiresAt     time.Time           `json:"expires_at"`
	CreatedAt     time.Time           `json:"created_at"`
}

// invitationCols reads an invitation (alias i) with both people's minimal
// profiles (ip: invitee, bp: creator; joined by invitationFrom).
const invitationCols = `i.id, i.community_id, i.token_hash is not null, i.invitee_user_id, i.created_by, i.expires_at, i.created_at,
	case when i.used_at is not null then 'used' when i.declined_at is not null then 'declined' when i.revoked_at is not null then 'revoked'
		when i.expires_at <= now() then 'expired' else 'active' end,
	ip.display_name, ip.username, bp.display_name, bp.username`

const invitationFrom = ` from community_invitations i
	left join lateral montra.minimal_profile(i.invitee_user_id) ip on true
	left join lateral montra.minimal_profile(i.created_by) bp on true`

func scanInvitation(r pgx.CollectableRow) (CommunityInvitationDTO, error) {
	var x CommunityInvitationDTO
	var link bool
	var createdBy *uuid.UUID
	var inviteeName, inviteeUser, creatorName, creatorUser *string
	if err := r.Scan(&x.ID, &x.CommunityID, &link, &x.InviteeID, &createdBy, &x.ExpiresAt, &x.CreatedAt, &x.Status,
		&inviteeName, &inviteeUser, &creatorName, &creatorUser); err != nil {
		return x, err
	}
	x.Kind = map[bool]string{true: "link", false: "username"}[link]
	x.Invitee, x.InvitedBy = personOf(x.InviteeID, inviteeName, inviteeUser), personOf(createdBy, creatorName, creatorUser)
	return x, nil
}

// personOf builds a person from minimal_profile columns (nil name: the
// caller may not see their profile, so only a generic name is shown).
func personOf(id *uuid.UUID, name, username *string) *CommunityPersonDTO {
	if id == nil {
		return nil
	}
	p := &CommunityPersonDTO{UserID: *id, DisplayName: "Montra user", Username: username}
	if name != nil {
		p.DisplayName = *name
	}
	return p
}

func gone(msg string) error { return apperr.New(apperr.CodeGone, http.StatusGone, msg) }

// Invite creates a username invitation or a single-use link.
func (s *Service) Invite(ctx context.Context, id uuid.UUID, in CommunityInvitationInput) (*CommunityInvitationDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	days := in.ExpiresInDays
	if days == 0 {
		days = 7
	}
	invID := uuid.New()
	expires := s.now().Add(time.Duration(days) * 24 * time.Hour)
	var out CommunityInvitationDTO
	var token *string
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if c.Status != "active" {
			return apperr.Rule("not_accepting_members", "This community is not accepting members.", nil)
		}
		if err := requireModerator(ctx, tx, id); err != nil {
			return err
		}
		var hash []byte
		var invitee *uuid.UUID
		if u := strings.TrimSpace(in.Username); u != "" {
			if err := tx.QueryRow(ctx, `select montra.discoverable_user_id($1)`, strings.ToLower(strings.TrimPrefix(u, "@"))).Scan(&invitee); err != nil {
				return err
			}
			if invitee == nil {
				return apperr.NotFound("user")
			}
			var member bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from community_members where community_id = $1 and user_id = $2 and status = 'active')`,
				id, *invitee).Scan(&member); err != nil {
				return err
			}
			if member {
				return apperr.ConflictCode("already_member", "This person is already a member.", nil)
			}
		} else {
			raw := make([]byte, 24)
			if _, err := rand.Read(raw); err != nil {
				return err
			}
			tok := base64.RawURLEncoding.EncodeToString(raw)
			token, hash = &tok, crypto.HashToken(tok)
		}
		if _, err := tx.Exec(ctx, `insert into community_invitations (id, community_id, created_by, invitee_user_id, token_hash, expires_at)
			values ($1,$2,$3,$4,$5,$6)`, invID, id, uid, invitee, hash, expires); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "community_invitation", EntityID: &invID, Action: "created"}); err != nil {
			return err
		}
		if invitee != nil {
			if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventInvitationCreated, AggregateType: "community_invitation", AggregateID: invID,
				UserID: &uid}); err != nil {
				return err
			}
		}
		if out, err = loadInvitation(ctx, tx, invID); err != nil {
			return err
		}
		out.CommunityName = c.Name
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	out.Token = token
	if token != nil && s.WebAppURL != "" {
		link := strings.TrimRight(s.WebAppURL, "/") + "/communities/join#token=" + url.QueryEscape(*token)
		out.ShareURL = &link
	}
	return &out, nil
}

func loadInvitation(ctx context.Context, tx pgx.Tx, id uuid.UUID) (CommunityInvitationDTO, error) {
	rows, err := tx.Query(ctx, `select `+invitationCols+invitationFrom+` where i.id = $1`, id)
	if err != nil {
		return CommunityInvitationDTO{}, err
	}
	return pgx.CollectExactlyOneRow(rows, scanInvitation)
}

// Invitations lists a community's invitations (moderators), newest
// first; active ones unless include_inactive. Link tokens are never shown
// again.
func (s *Service) Invitations(ctx context.Context, id uuid.UUID, includeInactive bool) ([]CommunityInvitationDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []CommunityInvitationDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if err := requireModerator(ctx, tx, id); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select `+invitationCols+invitationFrom+` where i.community_id = $1
			and ($2 or (i.used_at is null and i.declined_at is null and i.revoked_at is null and i.expires_at > now()))
			order by i.created_at desc limit 200`, id, includeInactive)
		if err != nil {
			return err
		}
		if out, err = pgx.CollectRows(rows, scanInvitation); err != nil {
			return err
		}
		for i := range out {
			out[i].CommunityName = c.Name
		}
		return nil
	})
	return out, database.MapError(err)
}

// RevokeInvitation revokes an active invitation (moderators).
func (s *Service) RevokeInvitation(ctx context.Context, communityID, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := loadCommunity(ctx, tx, uid, communityID); err != nil {
			return err
		}
		if err := requireModerator(ctx, tx, communityID); err != nil {
			return err
		}
		inv, err := loadInvitation(ctx, tx, id)
		if database.IsNoRows(err) || (err == nil && inv.CommunityID != communityID) {
			return apperr.NotFound("invitation")
		}
		if err != nil {
			return err
		}
		if inv.Status != "active" {
			return apperr.ConflictCode("invitation_inactive", "This invitation is no longer active.", map[string]string{"status": inv.Status})
		}
		if _, err := tx.Exec(ctx, `update community_invitations set revoked_at = now() where id = $1 and revoked_at is null`, id); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "community_invitation", EntityID: &id, Action: "revoked"})
	}))
}

// DeclineInvitation declines an invitation addressed to the caller.
func (s *Service) DeclineInvitation(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var exp time.Time
		var used, revoked, declined *time.Time
		if err := tx.QueryRow(ctx, `select expires_at, used_at, revoked_at, declined_at from community_invitations
			where id = $1 and invitee_user_id = $2 for update`, id, uid).Scan(&exp, &used, &revoked, &declined); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("invitation")
			}
			return err
		}
		if used != nil || declined != nil {
			status := map[bool]string{true: "used", false: "declined"}[used != nil]
			return apperr.ConflictCode("invitation_used", "This invitation was already "+status+".", map[string]string{"status": status})
		}
		if revoked != nil || !exp.After(s.now()) {
			return gone("This invitation has expired or was revoked.")
		}
		_, err := tx.Exec(ctx, `update community_invitations set declined_at = now() where id = $1`, id)
		return err
	}))
}

// AcceptInvitation joins through a link token or a username invitation ID.
func (s *Service) AcceptInvitation(ctx context.Context, token string, invitationID *uuid.UUID) (*CommunityDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var invID, commID uuid.UUID
		var exp time.Time
		var used, revoked, declined *time.Time
		if invitationID != nil {
			var invitee *uuid.UUID
			if err := tx.QueryRow(ctx, `select id, community_id, invitee_user_id, expires_at, used_at, revoked_at, declined_at from community_invitations
				where id = $1 and invitee_user_id = $2`, *invitationID, uid).Scan(&invID, &commID, &invitee, &exp, &used, &revoked, &declined); err != nil {
				if database.IsNoRows(err) {
					return apperr.NotFound("invitation")
				}
				return err
			}
		} else {
			l, err := loadLink(ctx, tx, token)
			if err != nil {
				return err
			}
			invID, commID, exp, used, revoked, declined = l.id, l.communityID, l.expiresAt, l.usedAt, l.revokedAt, l.declinedAt
		}
		if used != nil || revoked != nil || declined != nil || exp.Before(s.now()) {
			// A member reopening a spent link should hear "already a member", not "expired".
			var member bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from community_members where community_id = $1 and user_id = $2 and status = 'active')`,
				commID, uid).Scan(&member); err != nil {
				return err
			}
			if member {
				return apperr.ConflictCode("already_member", "You are already a member.", nil)
			}
			return gone("This invitation has expired or was already used.")
		}
		if _, err := tx.Exec(ctx, `select set_config('montra.join_community_id', $1, true), set_config('montra.redeem_invitation_id', $2, true)`,
			commID.String(), invID.String()); err != nil {
			return err
		}
		c, err := loadCommunity(ctx, tx, uid, commID)
		if err != nil {
			return err
		}
		if c.Status != "active" {
			return apperr.Rule("not_accepting_members", "This community is not accepting members.", nil)
		}
		switch c.MyStatus {
		case "active":
			return apperr.ConflictCode("already_member", "You are already a member.", nil)
		case "banned":
			return apperr.Forbidden()
		case "left", "pending":
			_, err = tx.Exec(ctx, `update community_members set status = 'active', role = 'member', joined_at = now() where community_id = $1 and user_id = $2`,
				commID, uid)
		default:
			_, err = tx.Exec(ctx, `insert into community_members (community_id, user_id, role, status) values ($1,$2,'member','active')`, commID, uid)
		}
		if err != nil {
			return err
		}
		tag, err := tx.Exec(ctx, `update community_invitations set used_at = now() where id = $1 and used_at is null`, invID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() != 1 {
			return gone("This invitation has expired or was already used.")
		}
		out, err = loadCommunity(ctx, tx, uid, commID)
		return err
	})
	return out, database.MapError(err)
}

// MyCommunityInvitations lists open invitations addressed to the caller.
func (s *Service) MyCommunityInvitations(ctx context.Context) ([]CommunityInvitationDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []CommunityInvitationDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+invitationCols+invitationFrom+` where i.invitee_user_id = $1 and i.used_at is null
			and i.revoked_at is null and i.declined_at is null and i.expires_at > now() order by i.created_at desc`, uid)
		if err != nil {
			return err
		}
		if out, err = pgx.CollectRows(rows, scanInvitation); err != nil {
			return err
		}
		for i := range out {
			// The invitee is not a member yet: invite-only communities are
			// hidden from them, so the name comes from a helper.
			_ = tx.QueryRow(ctx, `select coalesce(montra.community_name_for_invitee($1), '')`, out[i].ID).Scan(&out[i].CommunityName)
		}
		return nil
	})
	return out, database.MapError(err)
}

// CommunityInvitationPreview shows what a link invitation is for, before
// joining.
type CommunityInvitationPreview struct {
	CommunityID      uuid.UUID           `json:"community_id"`
	CommunityName    string              `json:"community_name"`
	Slug             string              `json:"slug"`
	MemberCount      int                 `json:"member_count" doc:"Active members"`
	InvitedBy        *CommunityPersonDTO `json:"invited_by,omitempty" doc:"Who created the link (absent when their account was deleted)"`
	Status           string              `json:"status" enum:"active,used,declined,revoked,expired"`
	ExpiresAt        time.Time           `json:"expires_at"`
	AlreadyMember    bool                `json:"already_member" doc:"You are already an active member (accepting answers 409 already_member)"`
	RequiresApproval bool                `json:"requires_approval" doc:"Always false: an invitation admits you directly, even to a private community"`
}

// linkInvitation is a link invitation as its token holder may see it
// (montra.community_invitation_preview).
type linkInvitation struct {
	id, communityID               uuid.UUID
	name, slug, communityStatus   string
	memberCount                   int
	expiresAt                     time.Time
	usedAt, revokedAt, declinedAt *time.Time
	createdBy                     *uuid.UUID
	creatorName, creatorUsername  *string
	myStatus                      *string
}

// loadLink reads the invitation behind a link token. Unknown tokens, and
// links whose creator and holder blocked each other, are not valid (410).
func loadLink(ctx context.Context, tx pgx.Tx, token string) (*linkInvitation, error) {
	var l linkInvitation
	var blocked bool
	err := tx.QueryRow(ctx, `select invitation_id, community_id, community_name, community_slug, community_status, member_count, expires_at, used_at,
		revoked_at, declined_at, invited_by, inviter_display_name, inviter_username, inviter_blocked, my_status
		from montra.community_invitation_preview($1)`, crypto.HashToken(token)).Scan(&l.id, &l.communityID, &l.name, &l.slug, &l.communityStatus,
		&l.memberCount, &l.expiresAt, &l.usedAt, &l.revokedAt, &l.declinedAt, &l.createdBy, &l.creatorName, &l.creatorUsername, &blocked, &l.myStatus)
	if database.IsNoRows(err) || (err == nil && blocked) {
		return nil, gone("This invitation is not valid.")
	}
	if err != nil {
		return nil, err
	}
	return &l, nil
}

// PreviewInvitation returns what a link invitation is for.
func (s *Service) PreviewInvitation(ctx context.Context, token string) (*CommunityInvitationPreview, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out CommunityInvitationPreview
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		l, err := loadLink(ctx, tx, token)
		if err != nil {
			return err
		}
		out = CommunityInvitationPreview{CommunityID: l.communityID, CommunityName: l.name, Slug: l.slug, MemberCount: l.memberCount, ExpiresAt: l.expiresAt,
			InvitedBy: personOf(l.createdBy, l.creatorName, l.creatorUsername), AlreadyMember: l.myStatus != nil && *l.myStatus == "active"}
		switch {
		case l.usedAt != nil:
			out.Status = "used"
		case l.declinedAt != nil:
			out.Status = "declined"
		case l.revokedAt != nil:
			out.Status = "revoked"
		case !l.expiresAt.After(s.now()) || l.communityStatus != "active":
			out.Status = "expired"
		default:
			out.Status = "active"
		}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}
