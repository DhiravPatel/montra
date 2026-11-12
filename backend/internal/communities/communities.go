// Package communities implements public communities (spec §4.16,
// §20B.17): discovery, public/private/invite-only membership with approval,
// owner/moderator/member roles, posts (discussion, question, resource,
// poll), threaded comments, reactions and polls. Content is plain text,
// cleaned by domain/textsafe, never carries finance data, and is rate
// limited with spam controls. Moderation lives in internal/moderation.
package communities

import (
	"context"
	"errors"
	"net/http"
	"regexp"
	"strconv"
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

// Service implements communities.
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

// Events for worker-side notifications.
const (
	EventCommentCreated = "community.comment_created"
	EventPostCreated    = "community.post_created"
	EventMemberPending  = "community.member_pending"
	EventMemberDecided  = "community.member_decided"
)

// CommunityDTO is a community as seen by the caller.
type CommunityDTO struct {
	ID              uuid.UUID  `json:"id"`
	Slug            string     `json:"slug"`
	Name            string     `json:"name"`
	Description     *string    `json:"description,omitempty"`
	Rules           *string    `json:"rules,omitempty"`
	Topics          []string   `json:"topics"`
	Visibility      string     `json:"visibility" enum:"public,private,invite_only"`
	Status          string     `json:"status" enum:"active,archived,suspended"`
	MemberCount     int        `json:"member_count"`
	MyRole          string     `json:"my_role" enum:"owner,moderator,member,none" doc:"Your membership role (platform staff moderate everywhere without one: see can_moderate)"`
	MyStatus        string     `json:"my_status" enum:"active,pending,banned,left,none"`
	CanModerate     bool       `json:"can_moderate" doc:"You may use the moderation endpoints here: the owner, moderators and Montra staff"`
	RestrictedUntil *time.Time `json:"restricted_until,omitempty" doc:"You cannot post or comment before this time"`
	Version         int32      `json:"version" doc:"Send it with PATCH (409 VERSION_CONFLICT when stale)"`
	CreatedAt       time.Time  `json:"created_at"`
}

// CommunityInput creates a community.
type CommunityInput struct {
	Name        string   `json:"name" minLength:"3" maxLength:"80"`
	Slug        string   `json:"slug,omitempty" pattern:"^[a-z0-9-]{3,60}$" doc:"URL name; default derived from the name; fixed after creation"`
	Description string   `json:"description,omitempty" maxLength:"2000"`
	Rules       string   `json:"rules,omitempty" maxLength:"4000"`
	Topics      []string `json:"topics,omitempty" maxItems:"10"`
	Visibility  string   `json:"visibility,omitempty" enum:"public,private,invite_only" doc:"public: anyone joins; private: listed, moderators approve; invite_only: unlisted, invitation needed"`
}

// CommunityPatch changes parts of a community (moderators; visibility by
// the owner). Only the fields sent change; description and rules are
// cleared with an empty string, topics replaced as a whole ([] empties
// them).
type CommunityPatch struct {
	Name        *string   `json:"name,omitempty" minLength:"3" maxLength:"80"`
	Description *string   `json:"description,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	Rules       *string   `json:"rules,omitempty" maxLength:"4000" doc:"Empty string clears it"`
	Topics      *[]string `json:"topics,omitempty" maxItems:"10" doc:"Replaces the list; [] empties it"`
	Visibility  *string   `json:"visibility,omitempty" enum:"public,private,invite_only" doc:"Owner only"`
	Version     int32     `json:"version" minimum:"1" doc:"Current version (409 VERSION_CONFLICT when stale)"`
}

const communityCols = `c.id, c.slug, c.name, c.description, c.rules, c.topics, c.visibility, c.status, montra.community_member_count(c.id), c.created_at,
	coalesce(m.role, 'none'), coalesce(m.status, 'none'), m.restricted_until, c.version, montra.is_community_moderator(c.id)`

func scanCommunity(r pgx.Row) (*CommunityDTO, error) {
	var c CommunityDTO
	if err := r.Scan(&c.ID, &c.Slug, &c.Name, &c.Description, &c.Rules, &c.Topics, &c.Visibility, &c.Status, &c.MemberCount, &c.CreatedAt,
		&c.MyRole, &c.MyStatus, &c.RestrictedUntil, &c.Version, &c.CanModerate); err != nil {
		return nil, err
	}
	if c.MyStatus != "active" {
		c.MyRole = "none"
	}
	if c.Topics == nil {
		c.Topics = []string{}
	}
	return &c, nil
}

func loadCommunity(ctx context.Context, tx pgx.Tx, me uuid.UUID, id uuid.UUID) (*CommunityDTO, error) {
	c, err := scanCommunity(tx.QueryRow(ctx, `select `+communityCols+` from communities c
		left join community_members m on m.community_id = c.id and m.user_id = $2 where c.id = $1`, id, me))
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("community")
	}
	return c, err
}

// isModerator reports community moderators/owners and platform staff.
func isModerator(ctx context.Context, tx pgx.Tx, id uuid.UUID) (bool, error) {
	var ok bool
	err := tx.QueryRow(ctx, `select montra.is_community_moderator($1)`, id).Scan(&ok)
	return ok, err
}

func requireModerator(ctx context.Context, tx pgx.Tx, id uuid.UUID) error {
	ok, err := isModerator(ctx, tx, id)
	if err != nil {
		return err
	}
	if !ok {
		return apperr.Forbidden()
	}
	return nil
}

// requireParticipant checks the caller may post, comment or vote: an
// active, unrestricted member of an active community, without a
// platform-wide sanction.
func (s *Service) requireParticipant(ctx context.Context, tx pgx.Tx, c *CommunityDTO) error {
	if c.Status != "active" {
		return apperr.Rule("not_accepting_posts", "This community is not accepting new posts.", nil)
	}
	if c.MyStatus == "banned" {
		return apperr.Forbidden()
	}
	if c.MyStatus != "active" {
		return apperr.Rule("join_community_first", "Join the community first.", nil)
	}
	if c.RestrictedUntil != nil && c.RestrictedUntil.After(s.now()) {
		return apperr.Rule("posting_restricted", "A moderator limited your posting here until "+c.RestrictedUntil.UTC().Format("2 Jan 2006 15:04 UTC")+".",
			map[string]string{"until": c.RestrictedUntil.UTC().Format(time.RFC3339)})
	}
	var sanction *string
	if err := tx.QueryRow(ctx, `select montra.my_community_sanction()`).Scan(&sanction); err != nil {
		return err
	}
	if sanction != nil {
		return apperr.Rule("account_restricted", "Your account cannot take part in communities right now.", nil)
	}
	return nil
}

var (
	nonSlug = regexp.MustCompile(`[^a-z0-9]+`)
	topicRe = regexp.MustCompile(`^[a-z0-9][a-z0-9 -]*$`)
)

func slugify(name string) string {
	s := strings.Trim(nonSlug.ReplaceAllString(strings.ToLower(name), "-"), "-")
	if len(s) > 50 {
		s = strings.Trim(s[:50], "-")
	}
	for len(s) < 3 {
		s += "-x"
	}
	return s
}

func normalizeTopics(in []string) ([]string, error) {
	out := []string{}
	seen := map[string]bool{}
	for i, t := range in {
		t = strings.ToLower(strings.TrimSpace(t))
		if t == "" || seen[t] {
			continue
		}
		if len(t) > 30 || !topicRe.MatchString(t) {
			return nil, apperr.FieldCode("body.topics", "invalid_topic", "Topics are short words (letters, digits, spaces, hyphens); topic "+strconv.Itoa(i+1)+" is not.",
				map[string]string{"index": strconv.Itoa(i + 1)})
		}
		seen[t] = true
		out = append(out, t)
	}
	return out, nil
}

// MaxCommunitiesPerDay caps how many communities one person creates in a
// rolling 24 hours (429 daily_cap).
const MaxCommunitiesPerDay = 3

// cleanField cleans plain text (nil when empty and optional). Problems
// carry stable detail codes: required, too_short (min), too_long (max),
// invalid_characters and contains_secret.
func cleanField(field, s string, minRunes, maxRunes int) (*string, error) {
	out, err := textsafe.Clean(s, minRunes, maxRunes)
	code, params := textsafe.Problem(err, minRunes, maxRunes)
	switch {
	case err == nil:
	case errors.Is(err, textsafe.ErrEmpty):
		if minRunes == 0 {
			return nil, nil
		}
		if code == textsafe.CodeTooShort {
			return nil, apperr.FieldCode(field, code, "This is too short.", params)
		}
		return nil, apperr.FieldCode(field, code, "This cannot be empty.", nil)
	case errors.Is(err, textsafe.ErrTooLong):
		return nil, apperr.FieldCode(field, code, "This is too long.", params)
	default:
		return nil, apperr.FieldCode(field, code, "This text contains characters that are not allowed.", nil)
	}
	if out == "" {
		return nil, nil
	}
	if textsafe.Secret(out) {
		return nil, apperr.FieldCode(field, textsafe.CodeContainsSecret, "Never share card numbers, CVVs, PINs, OTPs or passwords.", nil)
	}
	return &out, nil
}

// Create creates a community; the creator becomes its owner.
func (s *Service) Create(ctx context.Context, in CommunityInput) (*CommunityDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	name, err := cleanField("body.name", in.Name, 3, 80)
	if err != nil {
		return nil, err
	}
	desc, err := cleanField("body.description", in.Description, 0, 2000)
	if err != nil {
		return nil, err
	}
	rules, err := cleanField("body.rules", in.Rules, 0, 4000)
	if err != nil {
		return nil, err
	}
	topics, err := normalizeTopics(in.Topics)
	if err != nil {
		return nil, err
	}
	vis := in.Visibility
	if vis == "" {
		vis = "public"
	}
	slug := in.Slug
	if slug == "" {
		slug = slugify(*name)
	}
	var out *CommunityDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var sanction *string
		if err := tx.QueryRow(ctx, `select montra.my_community_sanction()`).Scan(&sanction); err != nil {
			return err
		}
		if sanction != nil {
			return apperr.Rule("account_restricted", "Your account cannot create communities right now.", nil)
		}
		if err := caps.Daily(ctx, tx, uid, "communities", `select created_at from communities where created_by = $1
			and created_at > now() - interval '1 day'`, MaxCommunitiesPerDay); err != nil {
			return err
		}
		id := uuid.New()
		if _, err := tx.Exec(ctx, `insert into communities (id, slug, name, description, rules, topics, visibility, created_by) values ($1,$2,$3,$4,$5,$6,$7,$8)`,
			id, slug, *name, desc, rules, topics, vis, uid); err != nil {
			if database.IsUniqueViolation(err, "communities_slug_key") {
				return apperr.New(apperr.CodeConflict, http.StatusConflict, "That community URL is taken.").
					WithDetails(apperr.Detail{Field: "body.slug", Code: "slug_taken", Message: "Choose another URL name."})
			}
			return err
		}
		if _, err := tx.Exec(ctx, `insert into community_members (community_id, user_id, role) values ($1,$2,'owner')`, id, uid); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "community", EntityID: &id, Action: "created"}); err != nil {
			return err
		}
		out, err = loadCommunity(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Discover lists communities the caller can see (public and private ones,
// plus invite-only ones they belong to), optionally filtered.
func (s *Service) Discover(ctx context.Context, q, topic string, mine bool) ([]CommunityDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	q = strings.TrimSpace(q)
	out := []CommunityDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+communityCols+` from communities c
			left join community_members m on m.community_id = c.id and m.user_id = $1
			where (c.status = 'active' or m.status = 'active')
			and ($2 = '' or c.name ilike '%' || $2 || '%' or c.slug ilike '%' || $2 || '%' or c.description ilike '%' || $2 || '%')
			and ($3 = '' or $3 = any(c.topics)) and (not $4 or m.status in ('active','pending'))
			order by (m.status = 'active') desc nulls last, montra.community_member_count(c.id) desc, c.name limit 100`,
			uid, likeEscape(q), strings.ToLower(strings.TrimSpace(topic)), mine)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			c, err := scanCommunity(rows)
			if err != nil {
				return err
			}
			out = append(out, *c)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

func likeEscape(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

// Get returns a community by ID or slug.
func (s *Service) Get(ctx context.Context, ref string) (*CommunityDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		id, perr := uuid.Parse(ref)
		if perr != nil {
			if err := tx.QueryRow(ctx, `select id from communities where slug = $1`, strings.ToLower(ref)).Scan(&id); err != nil {
				if database.IsNoRows(err) {
					return apperr.NotFound("community")
				}
				return err
			}
		}
		out, err = loadCommunity(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Update changes parts of a community (moderators; visibility by the
// owner): only the fields sent change, and the version sent must be
// current so two moderators never overwrite each other.
func (s *Service) Update(ctx context.Context, id uuid.UUID, in CommunityPatch) (*CommunityDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var name, desc, rules *string
	var topics []string
	if in.Name != nil {
		if name, err = cleanField("body.name", *in.Name, 3, 80); err != nil {
			return nil, err
		}
	}
	if in.Description != nil {
		if desc, err = cleanField("body.description", *in.Description, 0, 2000); err != nil {
			return nil, err
		}
	}
	if in.Rules != nil {
		if rules, err = cleanField("body.rules", *in.Rules, 0, 4000); err != nil {
			return nil, err
		}
	}
	if in.Topics != nil {
		if topics, err = normalizeTopics(*in.Topics); err != nil {
			return nil, err
		}
	}
	var out *CommunityDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if err := requireModerator(ctx, tx, id); err != nil {
			return err
		}
		var version int32
		if err := tx.QueryRow(ctx, `select version from communities where id = $1 for update`, id).Scan(&version); err != nil {
			return err
		}
		if version != in.Version {
			return apperr.VersionConflict()
		}
		if in.Name != nil {
			c.Name = *name
		}
		if in.Description != nil {
			c.Description = desc
		}
		if in.Rules != nil {
			c.Rules = rules
		}
		if in.Topics != nil {
			c.Topics = topics
		}
		if in.Visibility != nil && *in.Visibility != c.Visibility {
			if c.MyRole != "owner" {
				return apperr.Forbidden()
			}
			c.Visibility = *in.Visibility
		}
		if _, err := tx.Exec(ctx, `update communities set name = $2, description = $3, rules = $4, topics = $5, visibility = $6, version = version + 1
			where id = $1`, id, c.Name, c.Description, c.Rules, c.Topics, c.Visibility); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "community", EntityID: &id, Action: "updated"}); err != nil {
			return err
		}
		out, err = loadCommunity(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// SetArchived archives or restores a community (owner).
func (s *Service) SetArchived(ctx context.Context, id uuid.UUID, archived bool) (*CommunityDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if c.MyRole != "owner" {
			return apperr.Forbidden()
		}
		if c.Status == "suspended" {
			return apperr.Rule("community_suspended", "A suspended community can only be restored by Montra staff.", nil)
		}
		status := map[bool]string{true: "archived", false: "active"}[archived]
		if _, err := tx.Exec(ctx, `update communities set status = $2, version = version + 1 where id = $1`, id, status); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "community", EntityID: &id, Action: status}); err != nil {
			return err
		}
		out, err = loadCommunity(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Join joins a public community or asks to join a private one.
func (s *Service) Join(ctx context.Context, id uuid.UUID) (*CommunityDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if c.Status != "active" {
			return apperr.Rule("not_accepting_members", "This community is not accepting members.", nil)
		}
		switch c.MyStatus {
		case "active", "pending":
			return apperr.Conflict("You already joined or asked to join.")
		case "banned":
			return apperr.Forbidden()
		}
		var sanction *string
		if err := tx.QueryRow(ctx, `select montra.my_community_sanction()`).Scan(&sanction); err != nil {
			return err
		}
		if sanction != nil && *sanction == "ban" {
			return apperr.Rule("account_restricted", "Your account cannot join communities right now.", nil)
		}
		status := "active"
		switch c.Visibility {
		case "private":
			status = "pending"
		case "invite_only":
			return apperr.Rule("invitation_only", "This community is invitation only.", nil)
		}
		if c.MyStatus == "left" {
			_, err = tx.Exec(ctx, `update community_members set status = $3, role = 'member', joined_at = now() where community_id = $1 and user_id = $2`,
				id, uid, status)
		} else {
			_, err = tx.Exec(ctx, `insert into community_members (community_id, user_id, role, status) values ($1,$2,'member',$3)`, id, uid, status)
		}
		if err != nil {
			return err
		}
		if status == "pending" {
			cid := id
			if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventMemberPending, AggregateType: "community", AggregateID: cid, UserID: &uid}); err != nil {
				return err
			}
		}
		out, err = loadCommunity(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// Leave leaves a community (the owner transfers ownership first).
func (s *Service) Leave(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if c.MyStatus != "active" && c.MyStatus != "pending" {
			return apperr.NotFound("membership")
		}
		if c.MyRole == "owner" {
			return apperr.Rule("transfer_ownership_first", "Transfer ownership before leaving.", nil)
		}
		_, err = tx.Exec(ctx, `update community_members set status = 'left', role = 'member' where community_id = $1 and user_id = $2`, id, uid)
		return err
	}))
}

// CommunityMemberDTO is a member as listed to moderators.
type CommunityMemberDTO struct {
	UserID          uuid.UUID  `json:"user_id"`
	DisplayName     string     `json:"display_name"`
	Username        *string    `json:"username,omitempty"`
	Role            string     `json:"role" enum:"owner,moderator,member"`
	Status          string     `json:"status" enum:"active,pending,banned,left"`
	RestrictedUntil *time.Time `json:"restricted_until,omitempty"`
	JoinedAt        time.Time  `json:"joined_at"`
}

// Members lists members: moderators see everyone (including pending and
// banned); other members see only the owner and moderators.
func (s *Service) Members(ctx context.Context, id uuid.UUID, status string) ([]CommunityMemberDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []CommunityMemberDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := loadCommunity(ctx, tx, uid, id); err != nil {
			return err
		}
		mod, err := isModerator(ctx, tx, id)
		if err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select m.user_id, coalesce(mp.display_name, 'Montra user'), mp.username, m.role, m.status, m.restricted_until, m.joined_at
			from community_members m left join lateral montra.community_member_profile(m.community_id, m.user_id) mp on true
			where m.community_id = $1 and ($2 or (m.role in ('owner','moderator') and m.status = 'active')) and ($3 = '' or m.status = $3)
			order by case m.role when 'owner' then 0 when 'moderator' then 1 else 2 end, m.joined_at limit 500`, id, mod, status)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (CommunityMemberDTO, error) {
			var m CommunityMemberDTO
			err := r.Scan(&m.UserID, &m.DisplayName, &m.Username, &m.Role, &m.Status, &m.RestrictedUntil, &m.JoinedAt)
			return m, err
		})
		return err
	})
	return out, database.MapError(err)
}

// SetRole makes a member a moderator or back (owner).
func (s *Service) SetRole(ctx context.Context, id, user uuid.UUID, role string) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	if role != "moderator" && role != "member" {
		return apperr.FieldCode("body.role", "invalid_choice", "Choose moderator or member.", map[string]string{"allowed": "moderator, member"})
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if c.MyRole != "owner" {
			return apperr.Forbidden()
		}
		tag, err := tx.Exec(ctx, `update community_members set role = $3 where community_id = $1 and user_id = $2 and status = 'active' and role <> 'owner'`,
			id, user, role)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("member")
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &user, ActorUserID: &uid, EntityType: "community_member", EntityID: &id, Action: "role_" + role})
	}))
}

// TransferOwnership hands the community to an active member.
func (s *Service) TransferOwnership(ctx context.Context, id, user uuid.UUID) (*CommunityDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if c.MyRole != "owner" {
			return apperr.Forbidden()
		}
		if user == uid {
			return apperr.FieldCode("body.user_id", "self_not_allowed", "Choose another member.", nil)
		}
		tag, err := tx.Exec(ctx, `update community_members set role = 'owner' where community_id = $1 and user_id = $2 and status = 'active'`, id, user)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("member")
		}
		if _, err := tx.Exec(ctx, `update community_members set role = 'moderator' where community_id = $1 and user_id = $2`, id, uid); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &user, ActorUserID: &uid, EntityType: "community", EntityID: &id, Action: "ownership_transferred"}); err != nil {
			return err
		}
		out, err = loadCommunity(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// DecideMember approves or rejects a pending join request (moderators).
func (s *Service) DecideMember(ctx context.Context, id, user uuid.UUID, approve bool) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := loadCommunity(ctx, tx, uid, id); err != nil {
			return err
		}
		if err := requireModerator(ctx, tx, id); err != nil {
			return err
		}
		status, action := "active", "approve_member"
		if !approve {
			status, action = "left", "reject_member"
		}
		tag, err := tx.Exec(ctx, `update community_members set status = $3, joined_at = now() where community_id = $1 and user_id = $2 and status = 'pending'`,
			id, user, status)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("pending request")
		}
		cid := id
		var actID uuid.UUID
		if err := tx.QueryRow(ctx, `insert into moderation_actions (community_id, moderator_id, target_type, target_id, target_user_id, action)
			values ($1,$2,'member',$3,$3,$4) returning id`, cid, uid, user, action).Scan(&actID); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &user, ActorUserID: &uid, EntityType: "community_member", EntityID: &cid, Action: action}); err != nil {
			return err
		}
		return outbox.Emit(ctx, tx, outbox.Event{Type: EventMemberDecided, AggregateType: "community", AggregateID: cid, UserID: &user,
			Payload: map[string]any{"approved": approve}})
	}))
}
