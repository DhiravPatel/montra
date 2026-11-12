package groups

import (
	"context"
	"encoding/json"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/outbox"
)

// Job types.
const (
	JobNotifyActivity = "groups.notify_activity" // activity → member notifications by preference
	JobJoinRequested  = "groups.join_requested"  // log + notify admins (requester is not a member)
	JobSyncExpense    = "groups.sync_expense"    // re-sync payers' linked records after an edit/delete
	JobSyncSettlement = "groups.sync_settlement" // void other parties' linked records after a void
)

// audience selects who hears about an activity.
type audience int

const (
	audNone audience = iota
	audAll
	audAdmins
	audTarget   // the member the event is about (entity_id is a user)
	audInvolved // payers and participants of the expense
	audParties  // payer and payee of the settlement
	audInvitee
)

type notice struct {
	aud       audience
	important bool
	category  string
	title     string // %g = group name, %a = actor name, %m = member the event is about
	body      string
}

var notices = map[string]notice{
	"group_updated":             {audAll, false, "group", "%g was updated", "Open the group to see what changed."},
	"group_archived":            {audAll, true, "group", "%g was archived", "Its history stays available."},
	"group_restored":            {audAll, true, "group", "%g was restored", "You can add expenses again."},
	"group_deleted":             {audAll, true, "group", "%g was deleted", "Its records were kept for your history."},
	"member_joined":             {audAll, false, "group", "%m joined %g", "Open the group to say hello."},
	"member_left":               {audAdmins, false, "group", "%m left %g", "Their past expenses stay in the balances."},
	"member_removed":            {audTarget, true, "group", "You were removed from %g", "Contact the group's admins if this is unexpected."},
	"member_role_changed":       {audTarget, true, "group", "Your role in %g changed", "Open the group to see your role."},
	"ownership_transferred":     {audTarget, true, "group", "You now own %g", "You can manage members and settings."},
	"join_requested":            {audAdmins, true, "group", "%a asked to join %g", "Approve or decline the request."},
	"invitation_created":        {audInvitee, true, "group", "You're invited to join %g", "Accept or decline in Groups."},
	"expense_added":             {audInvolved, false, "group", "New expense in %g", "Open the group to see your share."},
	"expense_updated":           {audInvolved, false, "group", "An expense in %g was edited", "Your share may have changed."},
	"expense_deleted":           {audInvolved, false, "group", "An expense in %g was deleted", "Balances were updated."},
	"expense_commented":         {audInvolved, false, "group", "New comment in %g", "Open the expense to reply."},
	"expense_disputed":          {audInvolved, true, "group", "An expense in %g was disputed", "Review it and resolve the dispute."},
	"dispute_resolved":          {audInvolved, false, "group", "A dispute in %g was resolved", "Open the expense for details."},
	"dispute_withdrawn":         {audInvolved, false, "group", "A dispute in %g was withdrawn", "Open the expense for details."},
	"settlement_proposed":       {audParties, true, "settlement", "%a proposed a settlement in %g", "Open the group to review it."},
	"settlement_reported":       {audParties, true, "settlement", "%a reported a payment in %g", "Confirm it if you received it."},
	"settlement_confirmed":      {audParties, true, "settlement", "A payment in %g was confirmed", "Balances were updated."},
	"settlement_disputed":       {audParties, true, "settlement", "A payment in %g was disputed", "Open the settlement to resolve it."},
	"settlement_voided":         {audParties, true, "settlement", "A settlement in %g was voided", "Balances were updated."},
	"settlement_corrected":      {audParties, true, "settlement", "A settlement in %g was corrected", "Review the corrected record."},
	"recurring_expense_created": {audAll, false, "group", "New recurring expense in %g", "Open the group to see the schedule."},
	"recurring_expense_updated": {audAll, false, "group", "A recurring expense in %g changed", "Your share of future expenses may have changed."},
	"recurring_expense_paused":  {audAll, false, "group", "A recurring expense in %g was paused", "No new expenses until it is resumed."},
	"recurring_expense_resumed": {audAll, false, "group", "A recurring expense in %g was resumed", "Open the group to see the schedule."},
	"recurring_expense_stopped": {audAll, false, "group", "A recurring expense in %g was stopped", "Past expenses stay in the balances."},
	"recurring_expense_skipped": {audAll, false, "group", "A recurring expense in %g was skipped", "Nothing was added this time."},
}

// RegisterJobs registers group jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	s.RegisterTripJobs(reg)
	reg.Register(JobNotifyActivity, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ActivityID int64 `json:"activity_id"`
		}
		if err := j.Decode(&p); err != nil || p.ActivityID == 0 {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return s.notifyActivity(ctx, tx, p.ActivityID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(4))
	reg.Register(JobJoinRequested, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			RequestID uuid.UUID `json:"request_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return s.logJoinRequest(ctx, tx, p.RequestID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobSyncExpense, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ExpenseID uuid.UUID `json:"expense_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return s.syncExpenseRecords(ctx, tx, p.ExpenseID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobSyncSettlement, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			SettlementID uuid.UUID `json:"settlement_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error { return s.syncSettlementRecords(ctx, tx, p.SettlementID) })
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(2))
}

// OutboxRoutes maps group events to worker jobs.
func OutboxRoutes(relay *outbox.Relay) {
	relay.On(EventActivity, func(e outbox.Stored) []jobs.Spec {
		var p struct {
			ActivityID int64 `json:"activity_id"`
		}
		if json.Unmarshal(e.Payload, &p) != nil || p.ActivityID == 0 {
			return nil
		}
		return []jobs.Spec{{Type: JobNotifyActivity, Payload: map[string]any{"activity_id": p.ActivityID},
			DedupeKey: "groups.notify_activity:" + strconv.FormatInt(p.ActivityID, 10)}}
	})
	relay.On(EventJoinRequested, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobJoinRequested, UserID: e.UserID, Payload: map[string]any{"request_id": *e.AggregateID},
			DedupeKey: "groups.join_requested:" + e.AggregateID.String()}}
	})
	relay.On(EventExpenseChanged, func(e outbox.Stored) []jobs.Spec {
		if e.AggregateID == nil {
			return nil
		}
		return []jobs.Spec{{Type: JobSyncExpense, Payload: map[string]any{"expense_id": *e.AggregateID},
			DedupeKey: "groups.sync_expense:" + strconv.FormatInt(e.ID, 10)}}
	})
	relay.On(EventSettlement, func(e outbox.Stored) []jobs.Spec {
		var p struct {
			Kind string `json:"kind"`
		}
		if e.AggregateID == nil || json.Unmarshal(e.Payload, &p) != nil || p.Kind != "settlement_voided" {
			return nil
		}
		return []jobs.Spec{{Type: JobSyncSettlement, Payload: map[string]any{"settlement_id": *e.AggregateID},
			DedupeKey: "groups.sync_settlement:" + e.AggregateID.String()}}
	})
}

func displayName(ctx context.Context, tx pgx.Tx, groupID uuid.UUID, uid *uuid.UUID) string {
	if uid == nil {
		return "Someone"
	}
	var n string
	if err := tx.QueryRow(ctx, `select coalesce(p.display_name, m.display_name_snapshot, 'Someone') from group_members m
		left join profiles p on p.user_id = m.user_id where m.group_id = $1 and m.user_id = $2`, groupID, *uid).Scan(&n); err != nil {
		if err := tx.QueryRow(ctx, `select coalesce(display_name, 'Someone') from profiles where user_id = $1`, *uid).Scan(&n); err != nil {
			return "Someone"
		}
	}
	return n
}

func fill(t, group, actor, member string) string {
	out := make([]byte, 0, len(t)+len(group)+len(actor)+len(member))
	for i := 0; i < len(t); i++ {
		if t[i] == '%' && i+1 < len(t) {
			var v string
			switch t[i+1] {
			case 'g':
				v = group
			case 'a':
				v = actor
			case 'm':
				v = member
			default:
				out = append(out, t[i])
				continue
			}
			out = append(out, v...)
			i++
			continue
		}
		out = append(out, t[i])
	}
	return string(out)
}

// notifyActivity turns one activity event into notifications for the
// relevant members, honouring each member's group notification level.
func (s *Service) notifyActivity(ctx context.Context, tx pgx.Tx, activityID int64) error {
	var groupID uuid.UUID
	var actor, entity *uuid.UUID
	var kind, entityType, groupName, groupStatus string
	err := tx.QueryRow(ctx, `select a.group_id, a.actor_id, a.kind, a.entity_type, a.entity_id, g.name, g.status
		from group_activity_events a join groups g on g.id = a.group_id where a.id = $1`, activityID).
		Scan(&groupID, &actor, &kind, &entityType, &entity, &groupName, &groupStatus)
	if database.IsNoRows(err) {
		return nil
	}
	if err != nil {
		return err
	}
	n, ok := notices[kind]
	if !ok || n.aud == audNone {
		return nil
	}
	if groupStatus == "deleted" && kind != "group_deleted" {
		return nil
	}
	recipients := map[uuid.UUID]bool{} // user → bypass level filter
	addQuery := func(q string, args ...any) error {
		rows, err := tx.Query(ctx, q, args...)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, id := range ids {
			if _, ok := recipients[id]; !ok {
				recipients[id] = false
			}
		}
		return nil
	}
	switch n.aud {
	case audAll:
		err = addQuery(`select user_id from group_members where group_id = $1 and status = 'active'`, groupID)
	case audAdmins:
		err = addQuery(`select user_id from group_members where group_id = $1 and status = 'active' and role in ('owner','admin')`, groupID)
	case audTarget:
		if entity != nil {
			recipients[*entity] = kind == "member_removed" // removal reaches the removed member regardless of level
		}
	case audInvolved:
		if entity != nil {
			err = addQuery(`select m.user_id from group_members m where m.group_id = $1 and m.status = 'active' and (
				exists (select 1 from group_expense_payers p where p.expense_id = $2 and p.user_id = m.user_id) or
				exists (select 1 from group_expense_shares sh where sh.expense_id = $2 and sh.user_id = m.user_id) or
				exists (select 1 from group_disputes d where d.id = $2 and d.raised_by = m.user_id) or
				exists (select 1 from group_disputes d join group_expense_shares sh on sh.expense_id = d.expense_id
					where d.id = $2 and sh.user_id = m.user_id) or
				exists (select 1 from group_disputes d join group_expense_payers p on p.expense_id = d.expense_id
					where d.id = $2 and p.user_id = m.user_id) or
				exists (select 1 from group_disputes d join settlements st on st.id = d.settlement_id
					where d.id = $2 and m.user_id in (st.payer_user_id, st.payee_user_id)))`, groupID, *entity)
			if err == nil && kind == "expense_disputed" {
				err = addQuery(`select user_id from group_members where group_id = $1 and status = 'active' and role in ('owner','admin')`, groupID)
			}
		}
	case audParties:
		if entity != nil {
			err = addQuery(`select m.user_id from settlements st join group_members m on m.group_id = st.group_id
				and m.user_id in (st.payer_user_id, st.payee_user_id) and m.status = 'active' where st.id = $1`, *entity)
		}
	case audInvitee:
		if entity != nil {
			err = addQuery(`select invitee_user_id from group_invitations where id = $1 and invitee_user_id is not null and status = 'active'`, *entity)
			for id := range recipients {
				recipients[id] = true // not a member yet: no group level to honour
			}
		}
	}
	if err != nil {
		return err
	}
	if actor != nil {
		delete(recipients, *actor)
	}
	actorName := displayName(ctx, tx, groupID, actor)
	memberName := actorName
	if entityType == "group_member" && entity != nil {
		memberName = displayName(ctx, tx, groupID, entity)
	}
	gid := groupID
	priority := "normal"
	if n.important {
		priority = "high"
	}
	if kind == "member_joined" && entity != nil && (actor == nil || *actor != *entity) {
		// An approved join request: tell the new member directly.
		delete(recipients, *entity)
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: *entity, Category: "group", EventType: "join_approved",
			Title: "You joined " + groupName, Body: "Your request was approved.", DeepLink: "/groups/" + groupID.String(), EntityType: "group",
			EntityID: &gid, GroupID: &gid, Priority: "high", DedupeKey: "group_activity:" + strconv.FormatInt(activityID, 10) + ":" + entity.String()}); err != nil {
			return err
		}
	}
	if len(recipients) == 0 {
		return nil
	}
	title, body := fill(n.title, groupName, actorName, memberName), n.body
	deepLink, linkType, linkID, err := activityLink(ctx, tx, groupID, kind, entityType, entity)
	if err != nil {
		return err
	}
	for uid, bypass := range recipients {
		if !bypass {
			var level string
			err := tx.QueryRow(ctx, `select notification_level from group_members where group_id = $1 and user_id = $2`, groupID, uid).Scan(&level)
			if database.IsNoRows(err) {
				continue
			}
			if err != nil {
				return err
			}
			if level == "none" || (level == "important" && !n.important) {
				continue
			}
		}
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: n.category, EventType: kind,
			Title: title, Body: body, DeepLink: deepLink, EntityType: linkType, EntityID: linkID, GroupID: &gid, Priority: priority,
			DedupeKey: "group_activity:" + strconv.FormatInt(activityID, 10) + ":" + uid.String()}); err != nil {
			return err
		}
	}
	return nil
}

// activityLink is where an activity notification leads: a web route with
// IDs only (/groups, /groups/{id}, /groups/{id}/settings,
// /groups/{id}/recurring, /groups/{id}/expenses/{expenseId},
// /groups/{id}/settlements/{settlementId}), with the entity the link names.
// A dispute leads to the disputed expense or settlement; people who can no
// longer open the group (it was deleted, or they were removed) go to the
// group list.
func activityLink(ctx context.Context, tx pgx.Tx, groupID uuid.UUID, kind, entityType string, entity *uuid.UUID) (string, string, *uuid.UUID, error) {
	group := "/groups/" + groupID.String()
	if kind == "group_deleted" || kind == "member_removed" {
		return "/groups", "group", nil, nil
	}
	switch entityType {
	case "group_expense":
		if entity != nil {
			return group + "/expenses/" + entity.String(), entityType, entity, nil
		}
	case "settlement":
		if entity != nil {
			return group + "/settlements/" + entity.String(), entityType, entity, nil
		}
	case "group_dispute":
		if entity != nil {
			var expense, settlement *uuid.UUID
			err := tx.QueryRow(ctx, `select expense_id, settlement_id from group_disputes where id = $1`, *entity).Scan(&expense, &settlement)
			if err != nil && !database.IsNoRows(err) {
				return "", "", nil, err
			}
			switch {
			case expense != nil:
				return group + "/expenses/" + expense.String(), "group_expense", expense, nil
			case settlement != nil:
				return group + "/settlements/" + settlement.String(), "settlement", settlement, nil
			}
		}
	case "group_invitation":
		return "/groups", entityType, entity, nil // invitations are listed with your groups
	case "group_join_request":
		return group + "/settings", entityType, entity, nil // admins decide requests in the group's settings
	case "group_recurring_expense":
		return group + "/recurring", entityType, entity, nil
	}
	return group, entityType, entity, nil
}

// logJoinRequest records a join request in the group's log (the requester
// cannot write it) and notifies the admins through the usual activity path.
func (s *Service) logJoinRequest(ctx context.Context, tx pgx.Tx, requestID uuid.UUID) error {
	var groupID, requester uuid.UUID
	var status string
	err := tx.QueryRow(ctx, `select group_id, user_id, status from group_join_requests where id = $1`, requestID).Scan(&groupID, &requester, &status)
	if database.IsNoRows(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var logged bool
	if err := tx.QueryRow(ctx, `select exists (select 1 from group_activity_events where group_id = $1 and kind = 'join_requested' and entity_id = $2)`,
		groupID, requestID).Scan(&logged); err != nil || logged {
		return err
	}
	if status != "pending" {
		return nil
	}
	rid := requestID
	return activity(ctx, tx, groupID, &requester, "join_requested", "group_join_request", &rid, nil)
}

// syncExpenseRecords keeps each payer's linked record in step with the
// group expense (or voids it when the expense was deleted or they no
// longer paid), and tells them.
func (s *Service) syncExpenseRecords(ctx context.Context, tx pgx.Tx, expenseID uuid.UUID) error {
	var groupID uuid.UUID
	var status, groupName string
	var date time.Time
	err := tx.QueryRow(ctx, `select e.group_id, e.status, e.expense_date, g.name from group_expenses e join groups g on g.id = e.group_id
		where e.id = $1 for update of e`, expenseID).Scan(&groupID, &status, &date, &groupName)
	if database.IsNoRows(err) {
		return nil
	}
	if err != nil {
		return err
	}
	rows, err := tx.Query(ctx, `select t.id, t.user_id,
		coalesce((select p.amount_minor from group_expense_payers p where p.expense_id = $1 and p.user_id = t.user_id), 0),
		coalesce((select sh.share_minor from group_expense_shares sh where sh.expense_id = $1 and sh.user_id = t.user_id), 0)
		from transactions t where t.group_expense_id = $1 and t.status <> 'voided' order by t.id`, expenseID)
	if err != nil {
		return err
	}
	type link struct {
		id, user    uuid.UUID
		paid, share int64
	}
	links, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (link, error) {
		var l link
		err := r.Scan(&l.id, &l.user, &l.paid, &l.share)
		return l, err
	})
	if err != nil {
		return err
	}
	gid := groupID
	for _, l := range links {
		paid := l.paid
		if status == "deleted" {
			paid = 0
		}
		result, err := s.Finance.SyncGroupExpenseInTx(ctx, tx, l.user, l.id, paid, l.share, date)
		if err != nil {
			return err
		}
		if result == "unchanged" {
			continue
		}
		title, body := "Your record of an expense in "+groupName+" was updated", "The group expense changed, so your account record was adjusted."
		if result == "voided" {
			title, body = "Your record of an expense in "+groupName+" was removed", "The group expense was deleted or you are no longer a payer."
		}
		tid := l.id
		var version int32
		if err := tx.QueryRow(ctx, `select version from transactions where id = $1`, tid).Scan(&version); err != nil {
			return err
		}
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: l.user, Category: "group", EventType: "group_record_synced",
			Title: title, Body: body, DeepLink: "/transactions/" + tid.String(), EntityType: "transaction", EntityID: &tid, GroupID: &gid,
			DedupeKey: "group_record_synced:" + tid.String() + ":" + strconv.Itoa(int(version))}); err != nil {
			return err
		}
	}
	return nil
}

// syncSettlementRecords voids every party's linked record of a voided
// settlement (the voider's own was voided in the request).
func (s *Service) syncSettlementRecords(ctx context.Context, tx pgx.Tx, settlementID uuid.UUID) error {
	var groupID uuid.UUID
	var status, groupName string
	err := tx.QueryRow(ctx, `select st.group_id, st.status, g.name from settlements st join groups g on g.id = st.group_id where st.id = $1`, settlementID).
		Scan(&groupID, &status, &groupName)
	if database.IsNoRows(err) || (err == nil && status != "voided") {
		return nil
	}
	if err != nil {
		return err
	}
	rows, err := tx.Query(ctx, `select id, user_id from transactions where settlement_id = $1 and status <> 'voided' order by id`, settlementID)
	if err != nil {
		return err
	}
	type link struct{ id, user uuid.UUID }
	links, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (link, error) {
		var l link
		err := r.Scan(&l.id, &l.user)
		return l, err
	})
	if err != nil {
		return err
	}
	gid := groupID
	for _, l := range links {
		changed, err := s.Finance.SystemVoidGroupLinkedInTx(ctx, tx, l.user, l.id, "settlement_voided")
		if err != nil {
			return err
		}
		if !changed {
			continue
		}
		tid := l.id
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: l.user, Category: "settlement", EventType: "group_record_synced",
			Title: "Your record of a settlement in " + groupName + " was removed", Body: "The settlement was voided, so your account record was voided too.",
			DeepLink: "/transactions/" + tid.String(), EntityType: "transaction", EntityID: &tid, GroupID: &gid,
			DedupeKey: "settlement_record_voided:" + tid.String()}); err != nil {
			return err
		}
	}
	return nil
}
