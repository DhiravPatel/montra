package groups

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// GroupJoinRequestDTO is a request to join a group.
type GroupJoinRequestDTO struct {
	ID           uuid.UUID  `json:"id"`
	GroupID      uuid.UUID  `json:"group_id"`
	UserID       uuid.UUID  `json:"user_id"`
	DisplayName  string     `json:"display_name"`
	Message      *string    `json:"message,omitempty"`
	InvitationID *uuid.UUID `json:"invitation_id,omitempty" doc:"The invitation link this request came from (groups that require approval)"`
	Status       string     `json:"status" enum:"pending,approved,declined,cancelled"`
	CreatedAt    time.Time  `json:"created_at"`
}

func joinRequestPending() error {
	return apperr.ConflictCode("join_request_pending", "Your request to join is already waiting for the admins.", nil)
}

// RequestToJoin asks to join a group whose ID the caller knows (e.g. from
// an expired invitation). Admins approve or decline.
func (s *Service) RequestToJoin(ctx context.Context, groupID uuid.UUID, message string) (*GroupJoinRequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out GroupJoinRequestDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var exists, wasRemoved bool
		if err := tx.QueryRow(ctx, `select montra.group_exists_for_join($1),
			exists (select 1 from group_members where group_id = $1 and user_id = $2 and status = 'removed')`, groupID, uid).Scan(&exists, &wasRemoved); err != nil {
			return err
		}
		if !exists || wasRemoved {
			return apperr.NotFound("group")
		}
		if err := notMember(ctx, tx, groupID, uid); err != nil {
			return err
		}
		id := uuid.New()
		var msg *string
		if m := strings.TrimSpace(message); m != "" {
			msg = &m
		}
		out = GroupJoinRequestDTO{ID: id, GroupID: groupID, UserID: uid, Message: msg, Status: "pending"}
		if err := tx.QueryRow(ctx, `insert into group_join_requests (id, group_id, user_id, message) values ($1,$2,$3,$4) returning created_at`,
			id, groupID, uid, msg).Scan(&out.CreatedAt); err != nil {
			if database.IsUniqueViolation(err, "group_join_requests_pending") {
				return joinRequestPending()
			}
			return err
		}
		_ = tx.QueryRow(ctx, `select display_name from profiles where user_id = $1`, uid).Scan(&out.DisplayName)
		// The requester is not a member and cannot write the group's log; the
		// worker records the activity and notifies the admins.
		gid := groupID
		return outbox.Emit(ctx, tx, outbox.Event{Type: EventJoinRequested, AggregateType: "group_join_request", AggregateID: id, UserID: &uid, GroupID: &gid})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// JoinRequests lists pending requests (admins).
func (s *Service) JoinRequests(ctx context.Context, groupID uuid.UUID) ([]GroupJoinRequestDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []GroupJoinRequestDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := requireAdmin(ctx, tx, groupID); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select r.id, r.group_id, r.user_id, coalesce((select mp.display_name from montra.minimal_profile(r.user_id) mp), 'Montra user'),
			r.message, r.invitation_id, r.status, r.created_at from group_join_requests r where r.group_id = $1 and r.status = 'pending' order by r.created_at`,
			groupID)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (GroupJoinRequestDTO, error) {
			var x GroupJoinRequestDTO
			err := r.Scan(&x.ID, &x.GroupID, &x.UserID, &x.DisplayName, &x.Message, &x.InvitationID, &x.Status, &x.CreatedAt)
			return x, err
		})
		return err
	})
	return out, database.MapError(err)
}

// DecideJoinRequest approves or declines a request (admins).
func (s *Service) DecideJoinRequest(ctx context.Context, groupID, reqID uuid.UUID, approve bool) (*GroupDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		g, err := requireAdmin(ctx, tx, groupID)
		if err != nil {
			return err
		}
		if err := requireActive(g); err != nil {
			return err
		}
		var user uuid.UUID
		status := map[bool]string{true: "approved", false: "declined"}[approve]
		if err := tx.QueryRow(ctx, `update group_join_requests set status = $3, decided_by = $4, decided_at = now()
			where id = $1 and group_id = $2 and status = 'pending' returning user_id`, reqID, groupID, status, uid).Scan(&user); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("join request")
			}
			return err
		}
		if approve {
			var name string
			_ = tx.QueryRow(ctx, `select display_name from profiles where user_id = $1`, user).Scan(&name)
			if _, err := tx.Exec(ctx, `insert into group_members (group_id, user_id, role, display_name_snapshot) values ($1,$2,'member',$3)
				on conflict (group_id, user_id) do update set status = 'active', role = 'member', left_at = null, removed_by = null, joined_at = now()`,
				groupID, user, trim(name, 80)); err != nil {
				return err
			}
			if err := activity(ctx, tx, groupID, &uid, "member_joined", "group_member", &user, map[string]any{"via": "join_request"}); err != nil {
				return err
			}
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &user, ActorUserID: &uid, GroupID: &groupID, EntityType: "group_join_request",
			EntityID: &reqID, Action: status}); err != nil {
			return err
		}
		out, err = detail(ctx, tx, groupID)
		return err
	})
	return out, database.MapError(err)
}

// GroupMemberUpdate changes a member's role (owner/admin) or the caller's own
// notification level.
type GroupMemberUpdate struct {
	Role              string `json:"role,omitempty" enum:"admin,member"`
	NotificationLevel string `json:"notification_level,omitempty" enum:"all,important,none"`
}

// UpdateMember applies a member change.
func (s *Service) UpdateMember(ctx context.Context, groupID, userID uuid.UUID, in GroupMemberUpdate) (*GroupDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		if err := requireActive(g); err != nil {
			return err
		}
		var targetRole string
		if err := tx.QueryRow(ctx, `select role from group_members where group_id = $1 and user_id = $2 and status = 'active'`, groupID, userID).
			Scan(&targetRole); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("member")
			}
			return err
		}
		if in.Role != "" {
			if role == "member" || targetRole == "owner" || (role == "admin" && targetRole == "admin" && userID != uid) {
				return apperr.Forbidden()
			}
			if _, err := tx.Exec(ctx, `update group_members set role = $3 where group_id = $1 and user_id = $2`, groupID, userID, in.Role); err != nil {
				return err
			}
			if err := activity(ctx, tx, groupID, &uid, "member_role_changed", "group_member", &userID, map[string]any{"role": in.Role}); err != nil {
				return err
			}
		}
		if in.NotificationLevel != "" {
			if userID != uid {
				return apperr.Forbidden() // members choose their own notification level
			}
			if _, err := tx.Exec(ctx, `update group_members set notification_level = $3 where group_id = $1 and user_id = $2`, groupID, userID,
				in.NotificationLevel); err != nil {
				return err
			}
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &userID, ActorUserID: &uid, GroupID: &groupID, EntityType: "group_member", EntityID: &userID,
			Action: "updated", Changes: map[string]any{"role": in.Role, "notification_level": in.NotificationLevel}}); err != nil {
			return err
		}
		out, err = detail(ctx, tx, groupID)
		return err
	})
	return out, database.MapError(err)
}

// RemoveMember removes a member (admins) or leaves (self). A member who
// leaves must have a zero balance (balance_open). An admin may remove a
// member whose balance is open: their expenses, shares and settlements stay
// in the records, so their balance stays in balances, original debts and
// suggestions (member_status removed, under the name they had), and any
// member can record a settlement with them; a payment to them is confirmed
// by an admin on their behalf, since they no longer have access. The owner
// must transfer ownership before leaving.
func (s *Service) RemoveMember(ctx context.Context, groupID, userID uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		var targetRole string
		if err := tx.QueryRow(ctx, `select role from group_members where group_id = $1 and user_id = $2 and status = 'active'`, groupID, userID).
			Scan(&targetRole); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("member")
			}
			return err
		}
		if targetRole == "owner" {
			return apperr.Rule("transfer_ownership_first", "Transfer ownership before the owner leaves.", nil)
		}
		self := userID == uid
		if !self && (role == "member" || (role == "admin" && targetRole == "admin")) {
			return apperr.Forbidden()
		}
		if self {
			bal, err := s.balances(ctx, tx, g)
			if err != nil {
				return err
			}
			for _, b := range bal.Balances {
				if b.UserID == uid && b.Net.AmountMinor != 0 {
					return apperr.Rule("balance_open", "Settle your balance before leaving the group.", nil)
				}
			}
		}
		status, kind := "removed", "member_removed"
		if self {
			status, kind = "left", "member_left"
		}
		var by *uuid.UUID
		if !self {
			by = &uid
		}
		// Logged first: after leaving, the caller can no longer write the log.
		if err := activity(ctx, tx, groupID, &uid, kind, "group_member", &userID, nil); err != nil {
			return err
		}
		// Their recurring bills would fail without them: pause for the admins.
		if err := s.haltRules(ctx, tx, groupID, &userID, "pause"); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update group_members set status = $3, left_at = now(), removed_by = $4,
			display_name_snapshot = coalesce((select display_name from profiles where user_id = $2), display_name_snapshot)
			where group_id = $1 and user_id = $2`, groupID, userID, status, by); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &userID, ActorUserID: &uid, GroupID: &groupID, EntityType: "group_member", EntityID: &userID, Action: status})
	}))
}

// TransferOwnership makes another active member the owner (current owner
// becomes an admin).
func (s *Service) TransferOwnership(ctx context.Context, groupID, newOwner uuid.UUID) (*GroupDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, _, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		if role != "owner" {
			return apperr.Forbidden()
		}
		if newOwner == uid {
			return apperr.FieldError("body.user_id", "You are already the owner.")
		}
		var active bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from group_members where group_id = $1 and user_id = $2 and status = 'active')`,
			groupID, newOwner).Scan(&active); err != nil {
			return err
		}
		if !active {
			return apperr.FieldError("body.user_id", "Choose an active member.")
		}
		if _, err := tx.Exec(ctx, `update group_members set role = 'admin' where group_id = $1 and user_id = $2`, groupID, uid); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update group_members set role = 'owner' where group_id = $1 and user_id = $2`, groupID, newOwner); err != nil {
			return err
		}
		if err := activity(ctx, tx, groupID, &uid, "ownership_transferred", "group_member", &newOwner, nil); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &newOwner, ActorUserID: &uid, GroupID: &groupID, EntityType: "group", EntityID: &groupID,
			Action: "ownership_transferred"}); err != nil {
			return err
		}
		out, err = detail(ctx, tx, groupID)
		return err
	})
	return out, database.MapError(err)
}

// GroupActivitySummary holds an event's parameters: codes, IDs and the
// names members typed. It never holds English text written by Montra or
// amounts; clients build the sentence from kind and these values. Which
// keys appear depends on the kind (absent keys are omitted).
type GroupActivitySummary struct {
	GroupType       string     `json:"type,omitempty" enum:"household,roommates,trip,event,friends,custom" doc:"group_created: the group type"`
	InvitationKind  string     `json:"kind,omitempty" enum:"link,username" doc:"invitation_created: the invitation kind"`
	Via             string     `json:"via,omitempty" enum:"invitation,join_request" doc:"member_joined: accepted an invitation (also when absent, on older events) or approved join request"`
	Role            string     `json:"role,omitempty" enum:"admin,member" doc:"member_role_changed: the new role"`
	Description     string     `json:"description,omitempty" doc:"expense_added: the expense description as entered (user text)"`
	Name            string     `json:"name,omitempty" doc:"recurring_expense_created: the name as entered (user text)"`
	RecurringRuleID *uuid.UUID `json:"recurring_rule_id,omitempty" doc:"expense_added: the recurring expense it was added for"`
	Target          *uuid.UUID `json:"target,omitempty" doc:"dispute_resolved / dispute_withdrawn: the disputed expense or settlement"`
	TargetType      string     `json:"target_type,omitempty" enum:"expense,settlement" doc:"dispute_resolved / dispute_withdrawn: what target is (absent on older events, which were always expenses)"`
	Date            string     `json:"date,omitempty" doc:"recurring_expense_skipped: the skipped occurrence date (YYYY-MM-DD)"`
}

// GroupActivityDTO is one activity event (no amounts beyond what members
// see). kind lists every kind this package writes (activity_test.go keeps
// the enum in step with the code).
type GroupActivityDTO struct {
	ID         int64                `json:"id"`
	ActorID    *uuid.UUID           `json:"actor_id,omitempty"`
	Kind       string               `json:"kind" enum:"group_created,group_updated,group_archived,group_restored,group_deleted,invitation_created,invitation_revoked,join_requested,member_joined,member_left,member_removed,member_role_changed,ownership_transferred,expense_added,expense_updated,expense_deleted,expense_commented,expense_disputed,dispute_resolved,dispute_withdrawn,settlement_proposed,settlement_reported,settlement_confirmed,settlement_disputed,settlement_voided,settlement_corrected,recurring_expense_created,recurring_expense_updated,recurring_expense_paused,recurring_expense_resumed,recurring_expense_stopped,recurring_expense_skipped"`
	EntityType string               `json:"entity_type" enum:"group,group_invitation,group_join_request,group_member,group_expense,group_dispute,settlement,group_recurring_expense" doc:"What entity_id refers to (group_member: a user ID)"`
	EntityID   *uuid.UUID           `json:"entity_id,omitempty"`
	Summary    GroupActivitySummary `json:"summary"`
	CreatedAt  time.Time            `json:"created_at"`
}

// GroupActivityPage is a page of activity.
type GroupActivityPage struct {
	Events     []GroupActivityDTO `json:"events"`
	NextBefore *int64             `json:"next_before,omitempty" doc:"Pass as before for older events"`
}

// Activity lists group activity, newest first.
func (s *Service) Activity(ctx context.Context, groupID uuid.UUID, before int64) (*GroupActivityPage, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &GroupActivityPage{Events: []GroupActivityDTO{}}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select id, actor_id, kind, entity_type, entity_id, summary, created_at from group_activity_events
			where group_id = $1 and ($2 = 0 or id < $2) order by id desc limit 51`, groupID, before)
		if err != nil {
			return err
		}
		out.Events, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (GroupActivityDTO, error) {
			var a GroupActivityDTO
			err := r.Scan(&a.ID, &a.ActorID, &a.Kind, &a.EntityType, &a.EntityID, &a.Summary, &a.CreatedAt)
			return a, err
		})
		if err != nil {
			return err
		}
		if len(out.Events) > 50 {
			out.Events = out.Events[:50]
			n := out.Events[49].ID
			out.NextBefore = &n
		}
		return nil
	})
	return out, database.MapError(err)
}
