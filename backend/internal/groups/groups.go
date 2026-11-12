// Package groups implements groups, households, trips and events (spec
// §4.15, §20B.16): explicit roles, invitations, join requests, shared
// expenses with exact splits, balances derived from immutable expense and
// settlement records, settlement suggestions that never mutate records,
// user-reported settlements with confirmation and disputes, and an activity
// log. Membership is enforced on every request (service checks plus RLS);
// personal records are never exposed to other members.
package groups

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
	"montra/backend/internal/recurring"
)

// Service implements groups.
type Service struct {
	DB        *database.DB
	Finance   *finance.Service
	Recurring *recurring.Service
	Now       func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Events emitted for worker-side notifications.
const (
	EventActivity      = "group.activity"
	EventJoinRequested = "group.join_requested"
	EventSettlement    = "settlement.changed"
)

// GroupDTO is a group as seen by a member.
type GroupDTO struct {
	ID                  uuid.UUID `json:"id"`
	Name                string    `json:"name"`
	GroupType           string    `json:"group_type" enum:"household,roommates,trip,event,friends,custom"`
	Description         *string   `json:"description,omitempty"`
	BaseCurrency        string    `json:"base_currency"`
	Timezone            string    `json:"timezone"`
	DefaultSplitMethod  string    `json:"default_split_method" enum:"equal,exact,percentage,shares,itemized"`
	SimplifyDebts       bool      `json:"simplify_debts"`
	AllowMemberInvites  bool      `json:"allow_member_invites"`
	RequireJoinApproval bool      `json:"require_join_approval"`
	Rules               *string   `json:"rules,omitempty"`
	StartDate           *string   `json:"start_date,omitempty" doc:"Trips and events"`
	EndDate             *string   `json:"end_date,omitempty"`
	Destination         *string   `json:"destination,omitempty"`
	Status              string    `json:"status" enum:"active,archived,deleted"`
	MyRole              string    `json:"my_role" enum:"owner,admin,member,none"`
	MemberCount         int       `json:"member_count"`
	// MyNet is derived like GET /groups/{id}/balances (expenses that are not
	// deleted, confirmed settlements only).
	MyNet     apitypes.Money `json:"my_net" doc:"Your balance in the group currency (positive: you are owed; negative: you owe); the same value as my_net in GET /groups/{id}/balances"`
	Version   int32          `json:"version"`
	CreatedAt time.Time      `json:"created_at"`
}

// GroupMemberDTO is a group member (no personal finance data).
type GroupMemberDTO struct {
	UserID            uuid.UUID  `json:"user_id"`
	DisplayName       string     `json:"display_name"`
	Username          *string    `json:"username,omitempty"`
	Role              string     `json:"role" enum:"owner,admin,member"`
	Status            string     `json:"status" enum:"active,left,removed"`
	NotificationLevel string     `json:"notification_level" enum:"all,important,none"`
	JoinedAt          time.Time  `json:"joined_at"`
	LeftAt            *time.Time `json:"left_at,omitempty"`
}

// GroupDetail adds members.
type GroupDetail struct {
	GroupDTO
	Members []GroupMemberDTO `json:"members" doc:"Includes former members so historical balances stay readable"`
}

// groupCols reads a group as the caller sees it. my_net is the caller's
// net position, computed like settlement.Compute in balances: paid minus
// shares of expenses that are not deleted, plus confirmed settlements sent,
// minus confirmed settlements received.
const groupCols = `g.id, g.name, g.group_type, g.description, g.base_currency, g.timezone, g.default_split_method, g.simplify_debts,
	g.allow_member_invites, g.require_join_approval, g.rules, g.start_date, g.end_date, g.destination, g.status, g.version, g.created_at,
	coalesce(montra.group_role(g.id), 'none'), (select count(*) from group_members m where m.group_id = g.id and m.status = 'active')::int,
	(select coalesce(sum(x.a), 0)::bigint from (
		select p.amount_minor a from group_expense_payers p join group_expenses e on e.id = p.expense_id
			where p.group_id = g.id and p.user_id = montra.current_user_id() and e.status <> 'deleted'
		union all
		select -sh.share_minor from group_expense_shares sh join group_expenses e on e.id = sh.expense_id
			where sh.group_id = g.id and sh.user_id = montra.current_user_id() and e.status <> 'deleted'
		union all
		select case when st.payer_user_id = montra.current_user_id() then st.amount_minor else -st.amount_minor end from settlements st
			where st.group_id = g.id and st.status = 'confirmed' and montra.current_user_id() in (st.payer_user_id, st.payee_user_id)) x)`

func scanGroup(r pgx.Row) (*GroupDTO, error) {
	var g GroupDTO
	var sd, ed *time.Time
	var myNet int64
	if err := r.Scan(&g.ID, &g.Name, &g.GroupType, &g.Description, &g.BaseCurrency, &g.Timezone, &g.DefaultSplitMethod, &g.SimplifyDebts,
		&g.AllowMemberInvites, &g.RequireJoinApproval, &g.Rules, &sd, &ed, &g.Destination, &g.Status, &g.Version, &g.CreatedAt, &g.MyRole,
		&g.MemberCount, &myNet); err != nil {
		return nil, err
	}
	g.MyNet = apitypes.M(myNet, g.BaseCurrency)
	if sd != nil {
		v := finance.LocalDateString(*sd)
		g.StartDate = &v
	}
	if ed != nil {
		v := finance.LocalDateString(*ed)
		g.EndDate = &v
	}
	return &g, nil
}

// loadGroup returns a group visible to the caller (RLS: members only).
func loadGroup(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*GroupDTO, error) {
	g, err := scanGroup(tx.QueryRow(ctx, `select `+groupCols+` from groups g where g.id = $1 and g.status <> 'deleted'`, id))
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("group")
	}
	return g, err
}

func members(ctx context.Context, tx pgx.Tx, groupID uuid.UUID) ([]GroupMemberDTO, error) {
	rows, err := tx.Query(ctx, `select m.user_id, coalesce(p.display_name, m.display_name_snapshot, 'Former member'), p.username, m.role, m.status,
		m.notification_level, m.joined_at, m.left_at from group_members m left join profiles p on p.user_id = m.user_id
		where m.group_id = $1 order by (m.status = 'active') desc, case m.role when 'owner' then 0 when 'admin' then 1 else 2 end, m.joined_at`, groupID)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(r pgx.CollectableRow) (GroupMemberDTO, error) {
		var m GroupMemberDTO
		err := r.Scan(&m.UserID, &m.DisplayName, &m.Username, &m.Role, &m.Status, &m.NotificationLevel, &m.JoinedAt, &m.LeftAt)
		return m, err
	})
}

// requireMember returns the caller's role or NotFound (non-members cannot
// learn that a group exists).
func requireMember(ctx context.Context, tx pgx.Tx, groupID uuid.UUID) (string, *GroupDTO, error) {
	g, err := loadGroup(ctx, tx, groupID)
	if err != nil {
		return "", nil, err
	}
	if g.MyRole == "none" {
		return "", nil, apperr.NotFound("group")
	}
	return g.MyRole, g, nil
}

func requireAdmin(ctx context.Context, tx pgx.Tx, groupID uuid.UUID) (*GroupDTO, error) {
	role, g, err := requireMember(ctx, tx, groupID)
	if err != nil {
		return nil, err
	}
	if role != "owner" && role != "admin" {
		return nil, apperr.Forbidden()
	}
	return g, nil
}

// requireActive refuses changes to an archived group (409 group_archived).
func requireActive(g *GroupDTO) error {
	if g.Status != "active" {
		return apperr.ConflictCode("group_archived", "This group is archived; restore it to make changes.", nil)
	}
	return nil
}

// activity appends a group activity event and an outbox event so the
// worker can notify members.
func activity(ctx context.Context, tx pgx.Tx, groupID uuid.UUID, actor *uuid.UUID, kind, entityType string, entityID *uuid.UUID, summary map[string]any) error {
	if summary == nil {
		summary = map[string]any{}
	}
	raw, err := json.Marshal(summary)
	if err != nil {
		return err
	}
	var activityID int64
	if err := tx.QueryRow(ctx, `insert into group_activity_events (group_id, actor_id, kind, entity_type, entity_id, summary) values ($1,$2,$3,$4,$5,$6)
		returning id`, groupID, actor, kind, entityType, entityID, raw).Scan(&activityID); err != nil {
		return err
	}
	gid := groupID
	var agg uuid.UUID
	if entityID != nil {
		agg = *entityID
	}
	return outbox.Emit(ctx, tx, outbox.Event{Type: EventActivity, AggregateType: entityType, AggregateID: agg, UserID: actor, GroupID: &gid,
		Payload: map[string]any{"kind": kind, "activity_id": activityID}})
}

// GroupInput creates a group.
type GroupInput struct {
	Name                string `json:"name" minLength:"1" maxLength:"80"`
	GroupType           string `json:"group_type" enum:"household,roommates,trip,event,friends,custom"`
	Description         string `json:"description,omitempty" maxLength:"1000"`
	BaseCurrency        string `json:"base_currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Default: your base currency"`
	Timezone            string `json:"timezone,omitempty" maxLength:"64" doc:"IANA zone; default: your time zone"`
	DefaultSplitMethod  string `json:"default_split_method,omitempty" enum:"equal,exact,percentage,shares,itemized" doc:"Default: equal"`
	SimplifyDebts       *bool  `json:"simplify_debts,omitempty" doc:"Default: true"`
	AllowMemberInvites  *bool  `json:"allow_member_invites,omitempty" doc:"Default: true"`
	RequireJoinApproval *bool  `json:"require_join_approval,omitempty" doc:"Default: false. When true, accepting an invitation link creates a join request for the admins (username invitations still join directly)"`
	Rules               string `json:"rules,omitempty" maxLength:"2000"`
	StartDate           string `json:"start_date,omitempty" doc:"YYYY-MM-DD (trips and events)"`
	EndDate             string `json:"end_date,omitempty" doc:"YYYY-MM-DD"`
	Destination         string `json:"destination,omitempty" maxLength:"120"`
	Version             int32  `json:"version,omitempty" doc:"Unused when creating"`
}

// GroupPatch changes only the fields sent (admins). Text fields and dates
// are cleared with an empty string; version is required.
type GroupPatch struct {
	Name                *string `json:"name,omitempty" minLength:"1" maxLength:"80"`
	GroupType           *string `json:"group_type,omitempty" enum:"household,roommates,trip,event,friends,custom"`
	Description         *string `json:"description,omitempty" maxLength:"1000" doc:"Empty string clears it"`
	BaseCurrency        *string `json:"base_currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Fixed once expenses, settlements or recurring bills exist (422 currency_locked)"`
	Timezone            *string `json:"timezone,omitempty" minLength:"1" maxLength:"64" doc:"IANA zone"`
	DefaultSplitMethod  *string `json:"default_split_method,omitempty" enum:"equal,exact,percentage,shares,itemized"`
	SimplifyDebts       *bool   `json:"simplify_debts,omitempty"`
	AllowMemberInvites  *bool   `json:"allow_member_invites,omitempty"`
	RequireJoinApproval *bool   `json:"require_join_approval,omitempty" doc:"Invitation links create join requests for the admins (username invitations still join directly)"`
	Rules               *string `json:"rules,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	StartDate           *string `json:"start_date,omitempty" doc:"YYYY-MM-DD; empty string clears it"`
	EndDate             *string `json:"end_date,omitempty" doc:"YYYY-MM-DD; empty string clears it"`
	Destination         *string `json:"destination,omitempty" maxLength:"120" doc:"Empty string clears it"`
	Version             int32   `json:"version" minimum:"1" doc:"Current version (409 VERSION_CONFLICT when stale)"`
}

// fields names the fields sent (for the audit record).
func (p GroupPatch) fields() []string {
	var out []string
	for _, f := range []struct {
		name string
		sent bool
	}{{"name", p.Name != nil}, {"group_type", p.GroupType != nil}, {"description", p.Description != nil},
		{"base_currency", p.BaseCurrency != nil}, {"timezone", p.Timezone != nil}, {"default_split_method", p.DefaultSplitMethod != nil},
		{"simplify_debts", p.SimplifyDebts != nil}, {"allow_member_invites", p.AllowMemberInvites != nil},
		{"require_join_approval", p.RequireJoinApproval != nil}, {"rules", p.Rules != nil}, {"start_date", p.StartDate != nil},
		{"end_date", p.EndDate != nil}, {"destination", p.Destination != nil}} {
		if f.sent {
			out = append(out, f.name)
		}
	}
	return out
}

// apply merges the patch into the group's current settings, expressed as a
// full input so the create validation (normalize) applies unchanged.
func (p GroupPatch) apply(g *GroupDTO) GroupInput {
	deref := func(s *string) string {
		if s == nil {
			return ""
		}
		return *s
	}
	simplify, invites, approve := g.SimplifyDebts, g.AllowMemberInvites, g.RequireJoinApproval
	in := GroupInput{Name: g.Name, GroupType: g.GroupType, Description: deref(g.Description), BaseCurrency: g.BaseCurrency, Timezone: g.Timezone,
		DefaultSplitMethod: g.DefaultSplitMethod, SimplifyDebts: &simplify, AllowMemberInvites: &invites, RequireJoinApproval: &approve,
		Rules: deref(g.Rules), StartDate: deref(g.StartDate), EndDate: deref(g.EndDate), Destination: deref(g.Destination), Version: p.Version}
	for _, f := range []struct {
		dst *string
		v   *string
	}{{&in.Name, p.Name}, {&in.GroupType, p.GroupType}, {&in.Description, p.Description}, {&in.BaseCurrency, p.BaseCurrency},
		{&in.Timezone, p.Timezone}, {&in.DefaultSplitMethod, p.DefaultSplitMethod}, {&in.Rules, p.Rules}, {&in.StartDate, p.StartDate},
		{&in.EndDate, p.EndDate}, {&in.Destination, p.Destination}} {
		if f.v != nil {
			*f.dst = *f.v
		}
	}
	for _, f := range []struct {
		dst **bool
		v   *bool
	}{{&in.SimplifyDebts, p.SimplifyDebts}, {&in.AllowMemberInvites, p.AllowMemberInvites}, {&in.RequireJoinApproval, p.RequireJoinApproval}} {
		if f.v != nil {
			*f.dst = f.v
		}
	}
	return in
}

func boolOr(p *bool, def bool) bool {
	if p == nil {
		return def
	}
	return *p
}

func trim(s string, n int) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	if r := []rune(s); len(r) > n {
		s = string(r[:n])
	}
	return &s
}

type groupFields struct {
	name, typ, cur, tz, split  string
	desc, rules, dest          *string
	simplify, invites, approve bool
	start, end                 *time.Time
}

func normalize(u finance.UserContext, in GroupInput) (*groupFields, error) {
	f := &groupFields{name: strings.TrimSpace(in.Name), typ: in.GroupType, cur: in.BaseCurrency, tz: in.Timezone, split: in.DefaultSplitMethod,
		desc: trim(in.Description, 1000), rules: trim(in.Rules, 2000), dest: trim(in.Destination, 120),
		simplify: boolOr(in.SimplifyDebts, true), invites: boolOr(in.AllowMemberInvites, true), approve: boolOr(in.RequireJoinApproval, false)}
	if f.name == "" {
		return nil, apperr.FieldError("body.name", "Enter a group name.")
	}
	if f.cur == "" {
		f.cur = u.BaseCurrency
	}
	if !currency.Selectable(f.cur) {
		return nil, apperr.FieldError("body.base_currency", "Unsupported currency.")
	}
	if f.tz == "" {
		f.tz = u.Timezone
	}
	if _, err := time.LoadLocation(f.tz); err != nil || f.tz == "Local" {
		return nil, apperr.FieldError("body.timezone", "Unknown time zone.")
	}
	if f.split == "" {
		f.split = "equal"
	}
	for _, d := range []struct {
		field string
		v     string
		dst   **time.Time
	}{{"body.start_date", in.StartDate, &f.start}, {"body.end_date", in.EndDate, &f.end}} {
		if d.v == "" {
			continue
		}
		t, err := finance.ParseDate(d.field, d.v, u.Loc)
		if err != nil {
			return nil, err
		}
		*d.dst = &t
	}
	if f.start != nil && f.end != nil && f.end.Before(*f.start) {
		return nil, apperr.FieldError("body.end_date", "The end date must be on or after the start date.")
	}
	return f, nil
}

// Create creates a group; the creator becomes its owner.
func (s *Service) Create(ctx context.Context, in GroupInput) (*GroupDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		f, err := normalize(u, in)
		if err != nil {
			return err
		}
		var n int
		if err := tx.QueryRow(ctx, `select count(*) from groups where created_by = $1 and created_at > now() - interval '1 day'`, uid).Scan(&n); err != nil {
			return err
		}
		if n >= 20 {
			return apperr.RateLimited()
		}
		id := uuid.New()
		if _, err := tx.Exec(ctx, `insert into groups (id, created_by, name, group_type, description, base_currency, timezone, default_split_method,
			simplify_debts, allow_member_invites, require_join_approval, rules, start_date, end_date, destination)
			values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`, id, uid, f.name, f.typ, f.desc, f.cur, f.tz, f.split, f.simplify,
			f.invites, f.approve, f.rules, f.start, f.end, f.dest); err != nil {
			return err
		}
		var name string
		_ = tx.QueryRow(ctx, `select display_name from profiles where user_id = $1`, uid).Scan(&name)
		if _, err := tx.Exec(ctx, `insert into group_members (group_id, user_id, role, display_name_snapshot) values ($1,$2,'owner',$3)`,
			id, uid, trim(name, 80)); err != nil {
			return err
		}
		if err := activity(ctx, tx, id, &uid, "group_created", "group", &id, map[string]any{"type": f.typ}); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, GroupID: &id, EntityType: "group", EntityID: &id, Action: "created"}); err != nil {
			return err
		}
		out, err = detail(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}

func detail(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*GroupDetail, error) {
	g, err := loadGroup(ctx, tx, id)
	if err != nil {
		return nil, err
	}
	ms, err := members(ctx, tx, id)
	if err != nil {
		return nil, err
	}
	return &GroupDetail{GroupDTO: *g, Members: ms}, nil
}

// List returns the caller's groups.
func (s *Service) List(ctx context.Context, includeArchived bool) ([]GroupDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []GroupDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+groupCols+` from groups g join group_members me on me.group_id = g.id and me.user_id = $1 and me.status = 'active'
			where g.status = 'active' or ($2 and g.status = 'archived') order by g.updated_at desc limit 200`, uid, includeArchived)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			g, err := scanGroup(rows)
			if err != nil {
				return err
			}
			out = append(out, *g)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// Get returns a group with members.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*GroupDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, id); err != nil {
			return err
		}
		var err error
		out, err = detail(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}

// Update changes the settings sent (owner/admin); everything else keeps its
// value. The base currency cannot change once expenses exist.
func (s *Service) Update(ctx context.Context, id uuid.UUID, p GroupPatch) (*GroupDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		g, err := requireAdmin(ctx, tx, id)
		if err != nil {
			return err
		}
		if err := requireActive(g); err != nil {
			return err
		}
		if g.Version != p.Version {
			return apperr.VersionConflict()
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		f, err := normalize(u, p.apply(g))
		if err != nil {
			return err
		}
		if f.cur != g.BaseCurrency {
			var n int
			// Deleted expenses, settlements and recurring bills keep amounts in the
			// original currency, so any of them locks it.
			if err := tx.QueryRow(ctx, `select (select count(*) from group_expenses where group_id = $1)
				+ (select count(*) from settlements where group_id = $1)
				+ (select count(*) from recurring_rules where group_id = $1)`, id).Scan(&n); err != nil {
				return err
			}
			if n > 0 {
				return apperr.Rule("currency_locked", "The group currency cannot change after expenses, settlements or recurring bills were added.", nil)
			}
		}
		if _, err := tx.Exec(ctx, `update groups set name = $2, group_type = $3, description = $4, base_currency = $5, timezone = $6,
			default_split_method = $7, simplify_debts = $8, allow_member_invites = $9, require_join_approval = $10, rules = $11, start_date = $12,
			end_date = $13, destination = $14, version = version + 1 where id = $1`, id, f.name, f.typ, f.desc, f.cur, f.tz, f.split, f.simplify,
			f.invites, f.approve, f.rules, f.start, f.end, f.dest); err != nil {
			return err
		}
		if err := activity(ctx, tx, id, &uid, "group_updated", "group", &id, nil); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, GroupID: &id, EntityType: "group", EntityID: &id, Action: "updated",
			Changes: map[string]any{"fields": p.fields()}}); err != nil {
			return err
		}
		out, err = detail(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}

// SetStatus archives, restores or deletes a group (owner). Deleting needs
// settled balances; records are kept for members' history (ADR-022).
func (s *Service) SetStatus(ctx context.Context, id uuid.UUID, action string) (*GroupDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, g, err := requireMember(ctx, tx, id)
		if err != nil {
			return err
		}
		if role != "owner" {
			return apperr.Forbidden()
		}
		switch action {
		case "archive":
			if g.Status == "archived" {
				return apperr.ConflictCode("group_archived", "This group is already archived.", nil)
			}
			if err = s.haltRules(ctx, tx, id, nil, "pause"); err == nil {
				_, err = tx.Exec(ctx, `update groups set status = 'archived', archived_at = now(), version = version + 1 where id = $1`, id)
			}
		case "restore":
			if g.Status != "archived" {
				return apperr.ConflictCode("group_not_archived", "The group is not archived.", nil)
			}
			_, err = tx.Exec(ctx, `update groups set status = 'active', archived_at = null, version = version + 1 where id = $1`, id)
		case "delete":
			bal, err := s.balances(ctx, tx, g)
			if err != nil {
				return err
			}
			for _, b := range bal.Balances {
				if b.Net.AmountMinor != 0 {
					return apperr.Rule("balances_open", "Settle all balances before deleting the group.", nil)
				}
			}
			if err := s.haltRules(ctx, tx, id, nil, "stop"); err != nil {
				return err
			}
			// Nobody can join a deleted group: its open invitations end too.
			if _, err := tx.Exec(ctx, `update group_invitations set status = 'revoked', revoked_at = now() where group_id = $1 and status = 'active'`,
				id); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `update groups set status = 'deleted', deleted_at = now(), version = version + 1 where id = $1`, id); err != nil {
				return err
			}
		default:
			return apperr.BadRequest("Unknown action.")
		}
		if err != nil {
			return err
		}
		if err := activity(ctx, tx, id, &uid, "group_"+action+"d", "group", &id, nil); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, GroupID: &id, EntityType: "group", EntityID: &id, Action: action}); err != nil {
			return err
		}
		if action == "delete" {
			out = g
			out.Status = "deleted"
			return nil
		}
		out, err = loadGroup(ctx, tx, id)
		return err
	})
	return out, database.MapError(err)
}
