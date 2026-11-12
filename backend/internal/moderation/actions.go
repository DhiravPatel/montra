package moderation

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/textsafe"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// ModerationActionInput is a moderation action.
type ModerationActionInput struct {
	Action        string     `json:"action" enum:"hide,remove,restore,pin,unpin,lock,unlock,warn,restrict,ban,unban,dismiss_report,escalate"`
	TargetType    string     `json:"target_type" enum:"post,comment,member,profile,group,community" doc:"group: a reported group (staff; dismiss_report with the report_id)"`
	TargetID      uuid.UUID  `json:"target_id" doc:"Post, comment, group or community ID; the user ID for member and profile"`
	Reason        string     `json:"reason,omitempty" maxLength:"500" doc:"Required for hide, remove, warn, restrict and ban; shown to the affected person"`
	ReportID      *uuid.UUID `json:"report_id,omitempty" doc:"The report this resolves (required for group targets)"`
	DurationHours int        `json:"duration_hours,omitempty" minimum:"1" maximum:"8760" doc:"restrict (required) and optionally ban"`
}

// ModerationAppealState is the appeal made against an action, as shown on
// the action (the appellant's own appeal; moderators see their
// community's, staff every one).
type ModerationAppealState struct {
	ID           uuid.UUID  `json:"id"`
	Status       string     `json:"status" enum:"open,upheld,overturned" doc:"upheld: the action stands; overturned: the action was reversed"`
	DecisionNote *string    `json:"decision_note,omitempty"`
	DecidedAt    *time.Time `json:"decided_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

// ModerationActionDTO is a recorded moderation action.
type ModerationActionDTO struct {
	ID           uuid.UUID              `json:"id"`
	CommunityID  *uuid.UUID             `json:"community_id,omitempty" doc:"Absent for platform-wide actions by Montra staff"`
	ModeratorID  *uuid.UUID             `json:"moderator_id,omitempty" doc:"Shown to moderators; absent for automatic actions"`
	TargetType   string                 `json:"target_type" enum:"post,comment,member,profile,group,community"`
	TargetID     uuid.UUID              `json:"target_id"`
	TargetUserID *uuid.UUID             `json:"target_user_id,omitempty"`
	Action       string                 `json:"action"`
	Reason       *string                `json:"reason,omitempty"`
	ReportID     *uuid.UUID             `json:"report_id,omitempty"`
	ExpiresAt    *time.Time             `json:"expires_at,omitempty"`
	ReversedAt   *time.Time             `json:"reversed_at,omitempty"`
	Appealable   bool                   `json:"appealable" doc:"The affected person may still appeal (not reversed, within appeal_until)"`
	AppealUntil  *time.Time             `json:"appeal_until,omitempty" doc:"End of the appeal window (30 days after the action); absent for actions that cannot be appealed or were reversed"`
	Appeal       *ModerationAppealState `json:"appeal,omitempty" doc:"The latest appeal against this action, when one was made"`
	CreatedAt    time.Time              `json:"created_at"`
}

var needsReason = map[string]bool{"hide": true, "remove": true, "warn": true, "restrict": true, "ban": true}

// appealable actions affect a person.
var appealable = map[string]bool{"hide": true, "remove": true, "warn": true, "restrict": true, "ban": true}

// AppealWindow is how long after an action the affected person may appeal.
const AppealWindow = 30 * 24 * time.Hour

// actionCols reads an action (alias a) with its latest appeal (alias ap,
// joined by actionFrom; RLS shows each caller the appeals they may see).
const actionCols = `a.id, a.community_id, a.moderator_id, a.target_type, a.target_id, a.target_user_id, a.action, a.reason, a.report_id, a.expires_at,
	a.reversed_at, a.created_at, ap.id, ap.status, ap.decision_note, ap.decided_at, ap.created_at`

const actionFrom = ` from moderation_actions a left join lateral (select id, status, decision_note, decided_at, created_at from moderation_appeals
	where action_id = a.id order by created_at desc limit 1) ap on true`

func (s *Service) scanAction(r pgx.CollectableRow) (ModerationActionDTO, error) {
	var a ModerationActionDTO
	var apID *uuid.UUID
	var apStatus, apNote *string
	var apDecided, apCreated *time.Time
	if err := r.Scan(&a.ID, &a.CommunityID, &a.ModeratorID, &a.TargetType, &a.TargetID, &a.TargetUserID, &a.Action, &a.Reason, &a.ReportID, &a.ExpiresAt,
		&a.ReversedAt, &a.CreatedAt, &apID, &apStatus, &apNote, &apDecided, &apCreated); err != nil {
		return a, err
	}
	if appealable[a.Action] && a.ReversedAt == nil {
		until := a.CreatedAt.Add(AppealWindow)
		a.AppealUntil = &until
		a.Appealable = !s.now().After(until)
	}
	if apID != nil {
		a.Appeal = &ModerationAppealState{ID: *apID, Status: *apStatus, DecisionNote: apNote, DecidedAt: apDecided, CreatedAt: *apCreated}
	}
	return a, nil
}

// target resolves what an action applies to and who it affects.
type target struct {
	community *uuid.UUID
	user      *uuid.UUID
	table     string // community_posts | community_comments
	status    string
}

func resolveTarget(ctx context.Context, tx pgx.Tx, communityID *uuid.UUID, in ModerationActionInput) (*target, error) {
	t := &target{community: communityID}
	switch in.TargetType {
	case "post", "comment":
		t.table = map[string]string{"post": "community_posts", "comment": "community_comments"}[in.TargetType]
		var cid uuid.UUID
		if err := tx.QueryRow(ctx, `select community_id, author_id, status from `+t.table+` where id = $1`, in.TargetID).Scan(&cid, &t.user, &t.status); err != nil {
			if database.IsNoRows(err) {
				return nil, apperr.NotFound(in.TargetType)
			}
			return nil, err
		}
		if communityID != nil && cid != *communityID {
			return nil, apperr.NotFound(in.TargetType)
		}
		t.community = &cid
	case "member":
		if communityID == nil {
			return nil, apperr.FieldError("body.target_type", "Member actions belong to a community.")
		}
		var st string
		if err := tx.QueryRow(ctx, `select status from community_members where community_id = $1 and user_id = $2`, *communityID, in.TargetID).Scan(&st); err != nil {
			if database.IsNoRows(err) {
				return nil, apperr.NotFound("member")
			}
			return nil, err
		}
		u := in.TargetID
		t.user, t.status = &u, st
	case "profile":
		if communityID != nil {
			return nil, apperr.FieldError("body.target_type", "Account-wide sanctions are applied by Montra staff.")
		}
		u := in.TargetID
		t.user = &u
	case "group":
		// Groups are private to their members (RLS hides them from staff),
		// so a group action resolves the report about it: dismissing it is
		// the only decision that applies to a group.
		if communityID != nil {
			return nil, apperr.FieldError("body.target_type", "Group reports are handled by Montra staff.")
		}
		if in.Action != "dismiss_report" {
			return nil, apperr.FieldError("body.action", "Only dismissing its report applies to a group.")
		}
		if in.ReportID == nil {
			return nil, apperr.FieldError("body.report_id", "Name the group report to dismiss.")
		}
	case "community":
		if communityID != nil {
			return nil, apperr.FieldError("body.target_type", "Communities are suspended by Montra staff.")
		}
		var st string
		if err := tx.QueryRow(ctx, `select status from communities where id = $1`, in.TargetID).Scan(&st); err != nil {
			if database.IsNoRows(err) {
				return nil, apperr.NotFound("community")
			}
			return nil, err
		}
		cid := in.TargetID
		t.community, t.status = &cid, st
	}
	return t, nil
}

// apply performs an action's effect. It is also used (with inverse
// actions) to reverse one.
func (s *Service) apply(ctx context.Context, tx pgx.Tx, in ModerationActionInput, t *target, expires *time.Time) error {
	switch in.TargetType {
	case "post", "comment":
		switch in.Action {
		case "hide", "remove":
			status := map[string]string{"hide": "hidden", "remove": "removed"}[in.Action]
			if t.status == "deleted" {
				return apperr.Rule("already_deleted", "The author already deleted this.", nil)
			}
			if t.table == "community_posts" {
				_, err := tx.Exec(ctx, `update community_posts set status = $2, removed_reason = $3 where id = $1`, in.TargetID, status, trimPtr(in.Reason, 300))
				return err
			}
			_, err := tx.Exec(ctx, `update community_comments set status = $2 where id = $1`, in.TargetID, status)
			return err
		case "restore":
			if t.status != "hidden" && t.status != "removed" {
				return apperr.Conflict("Only hidden or removed content can be restored.")
			}
			if t.table == "community_posts" {
				_, err := tx.Exec(ctx, `update community_posts set status = 'published', removed_reason = null where id = $1`, in.TargetID)
				return err
			}
			_, err := tx.Exec(ctx, `update community_comments set status = 'published' where id = $1`, in.TargetID)
			return err
		case "pin", "unpin", "lock", "unlock":
			if t.table != "community_posts" {
				return apperr.FieldError("body.action", "Only posts can be pinned or locked.")
			}
			col := map[string]string{"pin": "pinned", "unpin": "pinned", "lock": "locked", "unlock": "locked"}[in.Action]
			_, err := tx.Exec(ctx, `update community_posts set `+col+` = $2 where id = $1`, in.TargetID, in.Action == "pin" || in.Action == "lock")
			return err
		case "warn", "dismiss_report", "escalate":
			return nil
		}
	case "member":
		switch in.Action {
		case "warn", "dismiss_report", "escalate":
			return nil
		case "restrict":
			_, err := tx.Exec(ctx, `update community_members set restricted_until = $3 where community_id = $1 and user_id = $2`, *t.community, in.TargetID, expires)
			return err
		case "ban":
			var role string
			if err := tx.QueryRow(ctx, `select role from community_members where community_id = $1 and user_id = $2`, *t.community, in.TargetID).Scan(&role); err != nil {
				return err
			}
			if role == "owner" {
				return apperr.Rule("owner_protected", "The owner cannot be banned from their own community.", nil)
			}
			_, err := tx.Exec(ctx, `update community_members set status = 'banned', role = 'member' where community_id = $1 and user_id = $2`, *t.community, in.TargetID)
			return err
		case "unban":
			_, err := tx.Exec(ctx, `update community_members set status = 'left', restricted_until = null where community_id = $1 and user_id = $2 and status = 'banned'`,
				*t.community, in.TargetID)
			return err
		case "unrestrict":
			_, err := tx.Exec(ctx, `update community_members set restricted_until = null where community_id = $1 and user_id = $2`, *t.community, in.TargetID)
			return err
		}
	case "profile":
		switch in.Action {
		case "warn", "restrict", "ban", "dismiss_report", "escalate":
			return nil // recorded as the action itself (platform sanctions are moderation_actions rows)
		case "unban":
			_, err := tx.Exec(ctx, `update moderation_actions set reversed_at = now(), reversed_by = montra.current_user_id()
				where community_id is null and target_user_id = $1 and action in ('restrict','ban') and reversed_at is null`, in.TargetID)
			return err
		}
	case "group":
		if in.Action == "dismiss_report" {
			return nil
		}
	case "community":
		switch in.Action {
		case "ban":
			_, err := tx.Exec(ctx, `update communities set status = 'suspended', version = version + 1 where id = $1`, in.TargetID)
			return err
		case "unban":
			_, err := tx.Exec(ctx, `update communities set status = 'active', version = version + 1 where id = $1 and status = 'suspended'`, in.TargetID)
			return err
		case "warn", "dismiss_report", "escalate":
			return nil
		}
	}
	return apperr.FieldError("body.action", "This action does not apply to a "+in.TargetType+".")
}

func trimPtr(s string, n int) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	if r := []rune(s); len(r) > n {
		s = string(r[:n])
	}
	return &s
}

// Act records and applies a moderation action. communityID nil means a
// platform action by Montra staff (enforced by the route and RLS).
func (s *Service) Act(ctx context.Context, communityID *uuid.UUID, in ModerationActionInput) (*ModerationActionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	reason := strings.TrimSpace(in.Reason)
	if reason != "" {
		if reason, err = textsafe.Clean(reason, 1, 500); err != nil {
			code, params := textsafe.Problem(err, 1, 500)
			return nil, apperr.FieldCode("body.reason", code, "Give the reason in plain text (up to 500 characters).", params)
		}
	}
	if needsReason[in.Action] && reason == "" {
		return nil, apperr.FieldCode("body.reason", "reason_required", "Give a reason; the person affected will see it.", nil)
	}
	in.Reason = reason
	var expires *time.Time
	if in.Action == "restrict" && in.DurationHours == 0 {
		return nil, apperr.FieldError("body.duration_hours", "Choose how long the restriction lasts.")
	}
	if in.DurationHours > 0 {
		if in.Action != "restrict" && in.Action != "ban" {
			return nil, apperr.FieldError("body.duration_hours", "Only restrictions and bans have a duration.")
		}
		e := s.now().Add(time.Duration(in.DurationHours) * time.Hour)
		expires = &e
	}
	var out ModerationActionDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if communityID != nil {
			if err := requireModerator(ctx, tx, *communityID); err != nil {
				return err
			}
		}
		t, err := resolveTarget(ctx, tx, communityID, in)
		if err != nil {
			return err
		}
		if t.user != nil && *t.user == uid && in.Action != "dismiss_report" && in.Action != "pin" && in.Action != "unpin" && in.Action != "lock" && in.Action != "unlock" {
			return apperr.Rule("own_content", "Ask another moderator to act on your own content or account.", nil)
		}
		if in.ReportID != nil {
			var tt string
			var tid uuid.UUID
			var rc *uuid.UUID
			if err := tx.QueryRow(ctx, `select target_type, target_id, community_id from community_reports where id = $1 and status in ('open','under_review','escalated')
				for update`, *in.ReportID).Scan(&tt, &tid, &rc); err != nil {
				if database.IsNoRows(err) {
					return apperr.NotFound("open report")
				}
				return err
			}
			sameTarget := tid == in.TargetID && (tt == in.TargetType || (tt == "profile" && in.TargetType == "member"))
			if !sameTarget {
				return apperr.FieldError("body.report_id", "The report is about a different target.")
			}
		}
		if in.TargetType == "member" {
			// Only the owner (or staff) acts on moderators.
			var targetRole, myRole string
			var staff bool
			if err := tx.QueryRow(ctx, `select coalesce((select role from community_members where community_id = $1 and user_id = $2), 'member'),
				coalesce(montra.community_role($1), ''), montra.current_platform_role() in ('admin','support')`, *communityID, in.TargetID).
				Scan(&targetRole, &myRole, &staff); err != nil {
				return err
			}
			if targetRole != "member" && myRole != "owner" && !staff {
				return apperr.Forbidden()
			}
		}
		if err := s.apply(ctx, tx, in, t, expires); err != nil {
			return err
		}
		id := uuid.New()
		var reasonPtr *string
		if in.Reason != "" {
			reasonPtr = &in.Reason
		}
		if _, err := tx.Exec(ctx, `insert into moderation_actions (id, community_id, moderator_id, target_type, target_id, target_user_id, action, reason,
			report_id, expires_at) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`, id, communityID, uid, in.TargetType, in.TargetID, t.user, in.Action, reasonPtr,
			in.ReportID, expires); err != nil {
			return err
		}
		if in.ReportID != nil {
			// Restoring content means the report did not hold up.
			status := map[string]string{"dismiss_report": "dismissed", "restore": "dismissed", "escalate": "escalated"}[in.Action]
			if status == "" {
				status = "actioned"
			}
			if _, err := tx.Exec(ctx, `update community_reports set status = $2, resolved_by = case when $2 = 'escalated' then null else $3::uuid end,
				resolved_at = case when $2 = 'escalated' then null else now() end where id = $1`, *in.ReportID, status, uid); err != nil {
				return err
			}
			// Other open reports about the same target are resolved together.
			if status == "actioned" || status == "dismissed" {
				if _, err := tx.Exec(ctx, `update community_reports set status = $3, resolved_by = $4, resolved_at = now()
					where target_type = (select target_type from community_reports where id = $1) and target_id = $2
					and status in ('open','under_review') and id <> $1`, *in.ReportID, in.TargetID, status, uid); err != nil {
					return err
				}
			}
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: t.user, ActorUserID: &uid, EntityType: "moderation_action", EntityID: &id, Action: in.Action,
			Changes: map[string]any{"target_type": in.TargetType, "target_id": in.TargetID, "community_id": communityID, "reason": in.Reason}}); err != nil {
			return err
		}
		if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventActioned, AggregateType: "moderation_action", AggregateID: id, UserID: t.user}); err != nil {
			return err
		}
		out, err = s.loadAction(ctx, tx, id)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

var inverse = map[string]string{"hide": "restore", "remove": "restore", "pin": "unpin", "lock": "unlock", "restrict": "unrestrict", "ban": "unban"}

// Reverse undoes an action (moderators of its community, or staff),
// keeping the record with reversed_at.
func (s *Service) Reverse(ctx context.Context, id uuid.UUID, note string) (*ModerationActionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out ModerationActionDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		return s.reverse(ctx, tx, uid, id, note, &out)
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// loadAction reads one action with its latest appeal.
func (s *Service) loadAction(ctx context.Context, tx pgx.Tx, id uuid.UUID) (ModerationActionDTO, error) {
	rows, err := tx.Query(ctx, `select `+actionCols+actionFrom+` where a.id = $1`, id)
	if err != nil {
		return ModerationActionDTO{}, err
	}
	return pgx.CollectExactlyOneRow(rows, s.scanAction)
}

func (s *Service) reverse(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID, note string, out *ModerationActionDTO) error {
	if _, err := tx.Exec(ctx, `select 1 from moderation_actions where id = $1 for update`, id); err != nil {
		return err
	}
	a, err := s.loadAction(ctx, tx, id)
	if database.IsNoRows(err) {
		return apperr.NotFound("moderation action")
	}
	if err != nil {
		return err
	}
	if a.CommunityID != nil {
		if err := requireModerator(ctx, tx, *a.CommunityID); err != nil {
			return err
		}
	} else {
		var staff bool
		if err := tx.QueryRow(ctx, `select montra.current_platform_role() in ('admin','support')`).Scan(&staff); err != nil {
			return err
		}
		if !staff {
			return apperr.Forbidden()
		}
	}
	if a.ReversedAt != nil {
		return apperr.Conflict("This action was already reversed.")
	}
	if inv, ok := inverse[a.Action]; ok && a.TargetType != "profile" {
		in := ModerationActionInput{Action: inv, TargetType: a.TargetType, TargetID: a.TargetID}
		t, err := resolveTarget(ctx, tx, a.CommunityID, in)
		if err != nil {
			return err
		}
		if a.TargetType == "community" {
			t.community = &a.TargetID
		}
		if err := s.apply(ctx, tx, in, t, nil); err != nil {
			return err
		}
	}
	if _, err := tx.Exec(ctx, `update moderation_actions set reversed_at = now(), reversed_by = $2 where id = $1`, id, uid); err != nil {
		return err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: a.TargetUserID, ActorUserID: &uid, EntityType: "moderation_action", EntityID: &id, Action: "reversed",
		Changes: map[string]any{"note": strings.TrimSpace(note)}}); err != nil {
		return err
	}
	*out, err = s.loadAction(ctx, tx, id)
	return err
}

// ActionLog lists a community's moderation actions (moderators).
func (s *Service) ActionLog(ctx context.Context, communityID uuid.UUID) ([]ModerationActionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []ModerationActionDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if err := requireModerator(ctx, tx, communityID); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select `+actionCols+actionFrom+` where a.community_id = $1 order by a.created_at desc limit 500`, communityID)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, s.scanAction)
		return err
	})
	return out, database.MapError(err)
}

// PlatformActionsFilter narrows the staff list of platform actions.
type PlatformActionsFilter struct {
	Status       string `query:"status" enum:"active,reversed,expired," doc:"active: in force (not reversed, not expired)"`
	Action       string `query:"action" enum:"hide,remove,restore,pin,unpin,lock,unlock,warn,restrict,ban,unban,dismiss_report,escalate,"`
	TargetType   string `query:"target_type" enum:"post,comment,profile,group,community,"`
	TargetID     string `query:"target_id" format:"uuid"`
	TargetUserID string `query:"target_user_id" format:"uuid" doc:"Actions that affected this person"`
	Cursor       string `query:"cursor" maxLength:"512" doc:"meta.next_cursor of the previous page"`
	Limit        int    `query:"limit" minimum:"1" maximum:"200" default:"50"`
}

// optionalUUID parses a validated optional uuid query value.
func optionalUUID(s string) *uuid.UUID {
	if s == "" {
		return nil
	}
	v, err := uuid.Parse(s)
	if err != nil {
		return nil
	}
	return &v
}

// actionCursor is a position in a newest-first action list.
type actionCursor struct {
	At time.Time `json:"a"`
	ID uuid.UUID `json:"i"`
}

// PlatformActions lists platform-wide actions (those with no community:
// account sanctions, community suspensions, staff content decisions and
// report dismissals), newest first, a page at a time (staff).
func (s *Service) PlatformActions(ctx context.Context, f PlatformActionsFilter) ([]ModerationActionDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	limit := f.Limit
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	var cur actionCursor
	if err := httpx.DecodeCursor(f.Cursor, &cur); err != nil {
		return nil, "", err
	}
	var after *time.Time
	if f.Cursor != "" {
		after = &cur.At
	}
	out := []ModerationActionDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if err := requireStaff(ctx, tx); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select `+actionCols+actionFrom+` where a.community_id is null
			and ($1 = '' or a.action = $1) and ($2 = '' or a.target_type = $2) and ($3::uuid is null or a.target_id = $3)
			and ($4::uuid is null or a.target_user_id = $4)
			and case $5 when 'reversed' then a.reversed_at is not null
				when 'expired' then a.reversed_at is null and a.expires_at is not null and a.expires_at <= now()
				when 'active' then a.reversed_at is null and (a.expires_at is null or a.expires_at > now()) else true end
			and ($6::timestamptz is null or (a.created_at, a.id) < ($6, $7::uuid))
			order by a.created_at desc, a.id desc limit $8`, f.Action, f.TargetType, optionalUUID(f.TargetID), optionalUUID(f.TargetUserID), f.Status, after,
			cur.ID, limit+1)
		if err != nil {
			return err
		}
		if out, err = pgx.CollectRows(rows, s.scanAction); err != nil {
			return err
		}
		if len(out) > limit {
			last := out[limit-1]
			if next, err = httpx.EncodeCursor(actionCursor{At: last.CreatedAt, ID: last.ID}); err != nil {
				return err
			}
			out = out[:limit]
		}
		return nil
	})
	return out, next, database.MapError(err)
}

// MyModeration lists actions taken about the caller (warnings, removals,
// restrictions, bans) with whether they can be appealed and the appeal
// they made. Moderator identities are not disclosed to the affected
// person.
func (s *Service) MyModeration(ctx context.Context) ([]ModerationActionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []ModerationActionDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+actionCols+actionFrom+` where a.target_user_id = $1
			and a.action in ('hide','remove','warn','restrict','ban','unban') order by a.created_at desc limit 200`, uid)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, s.scanAction)
		return err
	})
	for i := range out {
		out[i].ModeratorID, out[i].ReportID = nil, nil
	}
	return out, database.MapError(err)
}

// ModerationActionSummary is the action an appeal contests, as the
// decider (or the appellant) needs it in context.
type ModerationActionSummary struct {
	ID           uuid.UUID  `json:"id"`
	Action       string     `json:"action"`
	TargetType   string     `json:"target_type" enum:"post,comment,member,profile,group,community"`
	TargetID     uuid.UUID  `json:"target_id"`
	TargetUserID *uuid.UUID `json:"target_user_id,omitempty"`
	ModeratorID  *uuid.UUID `json:"moderator_id,omitempty" doc:"Shown to moderators and staff deciding the appeal; never to the appellant"`
	Reason       *string    `json:"reason,omitempty"`
	ExpiresAt    *time.Time `json:"expires_at,omitempty"`
	ReversedAt   *time.Time `json:"reversed_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

// ModerationAppealDTO is an appeal against a moderation action.
type ModerationAppealDTO struct {
	ID           uuid.UUID               `json:"id"`
	ActionID     uuid.UUID               `json:"action_id"`
	Action       ModerationActionSummary `json:"action" doc:"The action appealed against"`
	CommunityID  *uuid.UUID              `json:"community_id,omitempty"`
	Statement    string                  `json:"statement"`
	Status       string                  `json:"status" enum:"open,upheld,overturned" doc:"upheld: the action stands; overturned: the action was reversed"`
	DecisionNote *string                 `json:"decision_note,omitempty"`
	DecidedAt    *time.Time              `json:"decided_at,omitempty"`
	CreatedAt    time.Time               `json:"created_at"`
}

// appealCols reads an appeal (alias ap) with its action (alias a, joined
// by appealFrom).
const appealCols = `ap.id, ap.action_id, ap.community_id, ap.statement, ap.status, ap.decision_note, ap.decided_at, ap.created_at,
	a.action, a.target_type, a.target_id, a.target_user_id, a.moderator_id, a.reason, a.expires_at, a.reversed_at, a.created_at`

const appealFrom = ` from moderation_appeals ap join moderation_actions a on a.id = ap.action_id`

func scanAppeal(r pgx.CollectableRow) (ModerationAppealDTO, error) {
	var x ModerationAppealDTO
	err := r.Scan(&x.ID, &x.ActionID, &x.CommunityID, &x.Statement, &x.Status, &x.DecisionNote, &x.DecidedAt, &x.CreatedAt,
		&x.Action.Action, &x.Action.TargetType, &x.Action.TargetID, &x.Action.TargetUserID, &x.Action.ModeratorID, &x.Action.Reason, &x.Action.ExpiresAt, &x.Action.ReversedAt,
		&x.Action.CreatedAt)
	x.Action.ID = x.ActionID
	return x, err
}

// loadAppeal reads one appeal with its action.
func loadAppeal(ctx context.Context, tx pgx.Tx, id uuid.UUID) (ModerationAppealDTO, error) {
	rows, err := tx.Query(ctx, `select `+appealCols+appealFrom+` where ap.id = $1`, id)
	if err != nil {
		return ModerationAppealDTO{}, err
	}
	return pgx.CollectExactlyOneRow(rows, scanAppeal)
}

// Appeal contests an action that affected the caller (one open appeal per
// action; within 30 days).
func (s *Service) Appeal(ctx context.Context, actionID uuid.UUID, statement string) (*ModerationAppealDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	st, err := textsafe.Clean(statement, 1, 2000)
	if err != nil {
		code, params := textsafe.Problem(err, 1, 2000)
		return nil, apperr.FieldCode("body.statement", code, "Explain why in plain text (up to 2000 characters).", params)
	}
	var out ModerationAppealDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var action string
		var community *uuid.UUID
		var reversed *time.Time
		var created time.Time
		if err := tx.QueryRow(ctx, `select action, community_id, reversed_at, created_at from moderation_actions where id = $1 and target_user_id = $2`,
			actionID, uid).Scan(&action, &community, &reversed, &created); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("moderation action")
			}
			return err
		}
		if !appealable[action] || reversed != nil {
			return apperr.Rule("not_appealable", "This action cannot be appealed.", nil)
		}
		if s.now().Sub(created) > AppealWindow {
			return apperr.Rule("appeal_window_passed", "Appeals must be made within 30 days.", nil)
		}
		var id uuid.UUID
		err := tx.QueryRow(ctx, `insert into moderation_appeals (action_id, community_id, appellant_id, statement) values ($1,$2,$3,$4) returning id`,
			actionID, community, uid, st).Scan(&id)
		if database.IsUniqueViolation(err, "moderation_appeals_one_open") {
			return apperr.ConflictCode("appeal_pending", "You already appealed this action.", nil)
		}
		if err != nil {
			return err
		}
		out, err = loadAppeal(ctx, tx, id)
		out.Action.ModeratorID = nil // the appellant does not learn who acted
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// MyAppeals lists the caller's appeals, newest first, with their outcome.
func (s *Service) MyAppeals(ctx context.Context) ([]ModerationAppealDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []ModerationAppealDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+appealCols+appealFrom+` where ap.appellant_id = $1 order by ap.created_at desc limit 200`, uid)
		if err != nil {
			return err
		}
		if out, err = pgx.CollectRows(rows, scanAppeal); err != nil {
			return err
		}
		for i := range out {
			out[i].Action.ModeratorID = nil // the appellant does not learn who acted
		}
		return nil
	})
	return out, database.MapError(err)
}

// Appeals lists open appeals for a community (moderators) or, with
// communityID nil, platform appeals (staff).
func (s *Service) Appeals(ctx context.Context, communityID *uuid.UUID) ([]ModerationAppealDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []ModerationAppealDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if communityID != nil {
			if err := requireModerator(ctx, tx, *communityID); err != nil {
				return err
			}
		} else if err := requireStaff(ctx, tx); err != nil {
			return err
		}
		// Staff see every open appeal (escalation path when a community has
		// no other moderator to review one).
		rows, err := tx.Query(ctx, `select `+appealCols+appealFrom+` where ap.status = 'open'
			and ($1::uuid is null or ap.community_id = $1) order by ap.created_at limit 500`, communityID)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, scanAppeal)
		return err
	})
	return out, database.MapError(err)
}

// DecideAppeal upholds or overturns an action (another moderator than the
// one who acted, or staff). Overturning reverses the action.
func (s *Service) DecideAppeal(ctx context.Context, appealID uuid.UUID, overturn bool, note string) (*ModerationAppealDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out ModerationAppealDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var actionID uuid.UUID
		var community, moderator *uuid.UUID
		var status string
		if err := tx.QueryRow(ctx, `select ap.action_id, ap.community_id, ap.status, a.moderator_id from moderation_appeals ap
			join moderation_actions a on a.id = ap.action_id where ap.id = $1 for update of ap`, appealID).Scan(&actionID, &community, &status, &moderator); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("appeal")
			}
			return err
		}
		var staff bool
		if err := tx.QueryRow(ctx, `select montra.current_platform_role() in ('admin','support')`).Scan(&staff); err != nil {
			return err
		}
		if community != nil {
			if err := requireModerator(ctx, tx, *community); err != nil {
				return err
			}
		} else if !staff {
			return apperr.Forbidden()
		}
		if moderator != nil && *moderator == uid && !staff {
			return apperr.Rule("appeal_needs_other_moderator", "Another moderator must review an appeal against your action.", nil)
		}
		if status != "open" {
			return apperr.ConflictCode("appeal_already_decided", "This appeal was already decided.", nil)
		}
		decision := map[bool]string{true: "overturned", false: "upheld"}[overturn]
		if overturn {
			var a ModerationActionDTO
			if err := s.reverse(ctx, tx, uid, actionID, "Appeal overturned", &a); err != nil {
				return err
			}
		}
		var appellant uuid.UUID
		if err := tx.QueryRow(ctx, `update moderation_appeals set status = $2, decided_by = $3, decided_at = now(), decision_note = $4 where id = $1
			returning appellant_id`, appealID, decision, uid, trimPtr(note, 1000)).Scan(&appellant); err != nil {
			return err
		}
		if out, err = loadAppeal(ctx, tx, appealID); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &appellant, ActorUserID: &uid, EntityType: "moderation_appeal", EntityID: &appealID,
			Action: decision}); err != nil {
			return err
		}
		// The appellant is told the outcome (by the worker: notifications
		// are the recipient's own rows).
		return outbox.Emit(ctx, tx, outbox.Event{Type: EventAppealDecided, AggregateType: "moderation_appeal", AggregateID: appealID, UserID: &appellant})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

func requireStaff(ctx context.Context, tx pgx.Tx) error {
	var staff bool
	if err := tx.QueryRow(ctx, `select montra.current_platform_role() in ('admin','support')`).Scan(&staff); err != nil {
		return err
	}
	if !staff {
		return apperr.Forbidden()
	}
	return nil
}
