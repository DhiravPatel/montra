package groups

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/finance"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/recurring"
)

// GroupRecurringTemplate is how each occurrence is split. Itemized splits
// are not offered for recurring expenses (items change every time).
type GroupRecurringTemplate struct {
	Description  string                    `json:"description,omitempty" maxLength:"200" doc:"Expense description (default: the name)"`
	CategoryKey  string                    `json:"category_key,omitempty" pattern:"^[a-z_]{2,40}$"`
	SplitMethod  string                    `json:"split_method,omitempty" enum:"equal,exact,percentage,shares" doc:"Default: the group's default (itemized falls back to equal)"`
	Participants []ExpenseParticipantInput `json:"participants" minItems:"1" maxItems:"100"`
	Payers       []ExpensePayerInput       `json:"payers,omitempty" maxItems:"20" doc:"Default: whoever adds it pays (the creator when added automatically)"`
}

// GroupRecurringInput creates a recurring shared expense (rent, internet).
type GroupRecurringInput struct {
	Name string `json:"name" minLength:"1" maxLength:"120"`
	recurring.Schedule
	Amount  string `json:"amount" doc:"Each expense's amount in the group currency"`
	AutoAdd bool   `json:"auto_add,omitempty" doc:"Add the expense automatically when due (otherwise any member adds it)"`
	GroupRecurringTemplate
}

// GroupRecurringUpdate edits a recurring shared expense; to change the
// schedule, stop it and create a new one.
type GroupRecurringUpdate struct {
	Name    string `json:"name" minLength:"1" maxLength:"120"`
	Amount  string `json:"amount"`
	AutoAdd bool   `json:"auto_add,omitempty"`
	Version int32  `json:"version"`
	GroupRecurringTemplate
}

// GroupRecurringDTO is a recurring shared expense with recent and upcoming
// occurrences.
type GroupRecurringDTO struct {
	Rule        recurring.RecurringRuleDTO `json:"rule"`
	CreatedBy   uuid.UUID                  `json:"created_by"`
	AutoAdd     bool                       `json:"auto_add"`
	Template    GroupRecurringTemplate     `json:"template"`
	Occurrences []recurring.OccurrenceDTO  `json:"occurrences" doc:"Newest first, including upcoming ones"`
}

func (s *Service) templateInput(g *GroupDTO, t GroupRecurringTemplate, name string, amount int64, date string) GroupExpenseInput {
	desc := strings.TrimSpace(t.Description)
	if desc == "" {
		desc = strings.TrimSpace(name)
	}
	return GroupExpenseInput{Description: desc, Amount: apitypes.M(amount, g.BaseCurrency).Amount, ExpenseDate: date, CategoryKey: t.CategoryKey,
		SplitMethod: t.SplitMethod, Participants: t.Participants, Payers: t.Payers}
}

func (s *Service) checkTemplate(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, t *GroupRecurringTemplate, name, amount string) (int64, []byte, error) {
	if t.SplitMethod == "" {
		t.SplitMethod = g.DefaultSplitMethod
		if t.SplitMethod == "itemized" {
			t.SplitMethod = "equal"
		}
	}
	if t.SplitMethod == "itemized" {
		return 0, nil, apperr.FieldError("body.split_method", "Recurring expenses cannot use an itemized split.")
	}
	amt, err := finance.ParseAmount("body.amount", amount, g.BaseCurrency)
	if err != nil {
		return 0, nil, err
	}
	// Validate the split exactly as a real expense today would be.
	if _, err := s.compute(ctx, tx, uid, g, s.templateInput(g, *t, name, amt, ""), nil); err != nil {
		return 0, nil, err
	}
	raw, err := json.Marshal(t)
	return amt, raw, err
}

func (s *Service) recurringDTO(ctx context.Context, tx pgx.Tx, me uuid.UUID, groupID uuid.UUID, ruleID *uuid.UUID) ([]GroupRecurringDTO, error) {
	rows, err := s.Recurring.GroupRules(ctx, tx, me, groupID, ruleID)
	if err != nil {
		return nil, err
	}
	out := make([]GroupRecurringDTO, 0, len(rows))
	for _, r := range rows {
		d := GroupRecurringDTO{Rule: r.RecurringRuleDTO, CreatedBy: r.OwnerID, AutoAdd: r.AutoPost}
		if err := json.Unmarshal(r.Template, &d.Template); err != nil {
			return nil, err
		}
		if d.Template.Participants == nil {
			d.Template.Participants = []ExpenseParticipantInput{}
		}
		if d.Occurrences, err = s.Recurring.GroupOccurrences(ctx, tx, r.ID, 12); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, nil
}

// CreateRecurring creates a recurring shared expense (any active member;
// the creator receives reminders). A retry with the same Idempotency-Key
// returns the rule created first.
func (s *Service) CreateRecurring(ctx context.Context, key string, groupID uuid.UUID, in GroupRecurringInput) (*GroupRecurringDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out GroupRecurringDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = runIdem(ctx, tx, uid, key, "group_recurring.create", groupID, in, func() (GroupRecurringDTO, error) {
			_, g, err := requireMember(ctx, tx, groupID)
			if err != nil {
				return GroupRecurringDTO{}, err
			}
			if err := requireActive(g); err != nil {
				return GroupRecurringDTO{}, err
			}
			_, tpl, err := s.checkTemplate(ctx, tx, uid, g, &in.GroupRecurringTemplate, in.Name, in.Amount)
			if err != nil {
				return GroupRecurringDTO{}, err
			}
			sch := in.Schedule
			if sch.Timezone == "" {
				sch.Timezone = g.Timezone
			}
			id, err := s.Recurring.CreateGroupRuleInTx(ctx, tx, uid, recurring.GroupRuleSpec{Name: in.Name, Schedule: sch, Amount: in.Amount,
				Currency: g.BaseCurrency, Description: in.Description, AutoAdd: in.AutoAdd, GroupID: groupID, Template: tpl})
			if err != nil {
				return GroupRecurringDTO{}, err
			}
			if err := activity(ctx, tx, groupID, &uid, "recurring_expense_created", "group_recurring_expense", &id,
				map[string]any{"name": strings.TrimSpace(in.Name)}); err != nil {
				return GroupRecurringDTO{}, err
			}
			list, err := s.recurringDTO(ctx, tx, uid, groupID, &id)
			if err != nil {
				return GroupRecurringDTO{}, err
			}
			return list[0], nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// ListRecurring lists a group's recurring shared expenses.
func (s *Service) ListRecurring(ctx context.Context, groupID uuid.UUID) ([]GroupRecurringDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []GroupRecurringDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		out, err = s.recurringDTO(ctx, tx, uid, groupID, nil)
		return err
	})
	return out, database.MapError(err)
}

// GetRecurring returns one recurring shared expense.
func (s *Service) GetRecurring(ctx context.Context, groupID, ruleID uuid.UUID) (*GroupRecurringDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupRecurringDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		list, err := s.recurringDTO(ctx, tx, uid, groupID, &ruleID)
		if err != nil {
			return err
		}
		if len(list) == 0 {
			return apperr.NotFound("recurring expense")
		}
		out = &list[0]
		return nil
	})
	return out, database.MapError(err)
}

// manageRule authorizes changes to a rule: its creator or a group admin.
func manageRule(ctx context.Context, tx pgx.Tx, uid, groupID, ruleID uuid.UUID) (*GroupDTO, error) {
	role, g, err := requireMember(ctx, tx, groupID)
	if err != nil {
		return nil, err
	}
	var owner uuid.UUID
	if err := tx.QueryRow(ctx, `select user_id from recurring_rules where id = $1 and group_id = $2 and kind = 'group_expense'`, ruleID, groupID).
		Scan(&owner); err != nil {
		if database.IsNoRows(err) {
			return nil, apperr.NotFound("recurring expense")
		}
		return nil, err
	}
	if owner != uid && role == "member" {
		return nil, apperr.Forbidden()
	}
	// Locked only after authorization: RLS limits row locks to its managers.
	if _, err := tx.Exec(ctx, `select 1 from recurring_rules where id = $1 for update`, ruleID); err != nil {
		return nil, err
	}
	return g, nil
}

// UpdateRecurring edits the name, amount, split or auto-add setting.
func (s *Service) UpdateRecurring(ctx context.Context, groupID, ruleID uuid.UUID, in GroupRecurringUpdate) (*GroupRecurringDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupRecurringDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		g, err := manageRule(ctx, tx, uid, groupID, ruleID)
		if err != nil {
			return err
		}
		if err := requireActive(g); err != nil {
			return err
		}
		amt, tpl, err := s.checkTemplate(ctx, tx, uid, g, &in.GroupRecurringTemplate, in.Name, in.Amount)
		if err != nil {
			return err
		}
		if err := s.Recurring.UpdateGroupRuleInTx(ctx, tx, ruleID, in.Version, strings.TrimSpace(in.Name), amt, trim(in.Description, 500), tpl,
			in.AutoAdd); err != nil {
			return err
		}
		if err := activity(ctx, tx, groupID, &uid, "recurring_expense_updated", "group_recurring_expense", &ruleID, nil); err != nil {
			return err
		}
		list, err := s.recurringDTO(ctx, tx, uid, groupID, &ruleID)
		if err != nil {
			return err
		}
		out = &list[0]
		return nil
	})
	return out, database.MapError(err)
}

// SetRecurringStatus pauses, resumes or stops a recurring shared expense.
func (s *Service) SetRecurringStatus(ctx context.Context, groupID, ruleID uuid.UUID, action string) (*GroupRecurringDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupRecurringDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := manageRule(ctx, tx, uid, groupID, ruleID); err != nil {
			return err
		}
		if err := s.Recurring.SetGroupRuleStatusByUserInTx(ctx, tx, ruleID, action); err != nil {
			return err
		}
		kind := map[string]string{"pause": "recurring_expense_paused", "resume": "recurring_expense_resumed", "stop": "recurring_expense_stopped"}[action]
		if err := activity(ctx, tx, groupID, &uid, kind, "group_recurring_expense", &ruleID, nil); err != nil {
			return err
		}
		list, err := s.recurringDTO(ctx, tx, uid, groupID, &ruleID)
		if err != nil {
			return err
		}
		out = &list[0]
		return nil
	})
	return out, database.MapError(err)
}

// occurrenceOpen refuses an occurrence that was already added or skipped.
func occurrenceOpen(o *recurring.GroupOccurrence) error {
	if o.ExpenseID != nil || (o.Status != "scheduled" && o.Status != "overdue") {
		return apperr.ConflictCode("occurrence_already_handled", "This occurrence was already added or skipped.",
			map[string]string{"status": o.Status})
	}
	return nil
}

// addOccurrence creates the expense for an occurrence as uid. The request
// has no body, so problems with the stored split template are reported as
// coded rules rather than as body fields.
func (s *Service) addOccurrence(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, o *recurring.GroupOccurrence) (uuid.UUID, error) {
	if err := occurrenceOpen(o); err != nil {
		return uuid.Nil, err
	}
	var t GroupRecurringTemplate
	if err := json.Unmarshal(o.Template, &t); err != nil {
		return uuid.Nil, err
	}
	people := make([]uuid.UUID, 0, len(t.Participants)+len(t.Payers))
	for _, p := range t.Participants {
		people = append(people, p.UserID)
	}
	for _, p := range t.Payers {
		people = append(people, p.UserID)
	}
	var inactive *uuid.UUID
	if err := tx.QueryRow(ctx, `select u from unnest($2::uuid[]) with ordinality x(u, n)
		where not exists (select 1 from group_members m where m.group_id = $1 and m.user_id = x.u and m.status = 'active') order by n limit 1`,
		g.ID, people).Scan(&inactive); err != nil && !database.IsNoRows(err) {
		return uuid.Nil, err
	}
	if inactive != nil {
		return uuid.Nil, apperr.Rule("recurring_member_inactive",
			"Someone who shares or pays this recurring expense is no longer a member. Edit who shares it, then add it.",
			map[string]string{"user_id": inactive.String()})
	}
	rule := o.RuleID
	id, err := s.createExpenseInTx(ctx, tx, uid, g, s.templateInput(g, t, o.RuleName, o.Amount, finance.LocalDateString(o.Date)), &rule)
	var ae *apperr.Error
	if errors.As(err, &ae) && ae.Code == apperr.CodeValidation && len(ae.Details) > 0 {
		return uuid.Nil, apperr.Rule("recurring_template_invalid", "This recurring expense cannot be added as it is set up: "+ae.Details[0].Message,
			map[string]string{"field": strings.TrimPrefix(ae.Details[0].Field, "body.")})
	}
	if err != nil {
		return uuid.Nil, err
	}
	return id, s.Recurring.CompleteGroupOccurrenceInTx(ctx, tx, o, &id)
}

// AddOccurrence adds the expense for a due or upcoming occurrence (any
// active member; idempotent).
func (s *Service) AddOccurrence(ctx context.Context, key string, groupID, ruleID, occID uuid.UUID) (*GroupExpenseDetail, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out GroupExpenseDetail
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = runIdem(ctx, tx, uid, key, "group_recurring.add", groupID, occID, func() (GroupExpenseDetail, error) {
			_, g, err := requireMember(ctx, tx, groupID)
			if err != nil {
				return GroupExpenseDetail{}, err
			}
			if err := requireActive(g); err != nil {
				return GroupExpenseDetail{}, err
			}
			o, err := s.Recurring.LockGroupOccurrenceInTx(ctx, tx, occID, false)
			if err != nil {
				return GroupExpenseDetail{}, err
			}
			if o == nil || o.GroupID != groupID || o.RuleID != ruleID {
				return GroupExpenseDetail{}, apperr.NotFound("occurrence")
			}
			id, err := s.addOccurrence(ctx, tx, uid, g, o)
			if err != nil {
				return GroupExpenseDetail{}, err
			}
			d, err := s.expenseDetail(ctx, tx, uid, groupID, id)
			if err != nil {
				return GroupExpenseDetail{}, err
			}
			return *d, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// SkipOccurrence skips one occurrence (its creator or an admin).
func (s *Service) SkipOccurrence(ctx context.Context, groupID, ruleID, occID uuid.UUID) (*GroupRecurringDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupRecurringDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := manageRule(ctx, tx, uid, groupID, ruleID); err != nil {
			return err
		}
		o, err := s.Recurring.LockGroupOccurrenceInTx(ctx, tx, occID, false)
		if err != nil {
			return err
		}
		if o == nil || o.GroupID != groupID || o.RuleID != ruleID {
			return apperr.NotFound("occurrence")
		}
		if err := occurrenceOpen(o); err != nil {
			return err
		}
		if err := s.Recurring.CompleteGroupOccurrenceInTx(ctx, tx, o, nil); err != nil {
			return err
		}
		if err := activity(ctx, tx, groupID, &uid, "recurring_expense_skipped", "group_recurring_expense", &ruleID,
			map[string]any{"date": finance.LocalDateString(o.Date)}); err != nil {
			return err
		}
		list, err := s.recurringDTO(ctx, tx, uid, groupID, &ruleID)
		if err != nil {
			return err
		}
		out = &list[0]
		return nil
	})
	return out, database.MapError(err)
}

// PostDueRecurring is the scheduler hook (recurring.Service.GroupPoster):
// it adds one due occurrence of an auto-add rule as the rule's creator.
// Domain failures (for example a participant left the group) are recorded
// once and the creator is told; the occurrence then waits for a member.
func (s *Service) PostDueRecurring(ctx context.Context, occID uuid.UUID) error {
	var owner, groupID uuid.UUID
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select r.user_id, o.group_id from recurring_occurrences o join recurring_rules r on r.id = o.rule_id
			where o.id = $1 and o.group_id is not null`, occID).Scan(&owner, &groupID)
	})
	if database.IsNoRows(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var domainErr *apperr.Error
	var o *recurring.GroupOccurrence
	err = s.DB.WithUserTx(ctx, owner, func(tx pgx.Tx) error {
		if o, err = s.Recurring.LockGroupOccurrenceInTx(ctx, tx, occID, true); err != nil || o == nil {
			return err
		}
		if o.Status != "scheduled" || o.ExpenseID != nil || !o.AutoAdd || o.RuleState != "active" {
			return nil
		}
		_, g, err := requireMember(ctx, tx, groupID)
		if err == nil {
			err = requireActive(g)
		}
		if err == nil {
			_, err = s.addOccurrence(ctx, tx, owner, g, o)
		}
		var ae *apperr.Error
		if errors.As(err, &ae) && ae.Status < 500 {
			domainErr = ae
			return ae // roll back the attempt; recorded below
		}
		return err
	})
	if domainErr == nil {
		return err
	}
	slog.WarnContext(ctx, "recurring group expense not added", slog.String("occurrence_id", occID.String()), slog.String("code", string(domainErr.Code)))
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update recurring_occurrences set auto_post_attempts = least(auto_post_attempts + 1, 32000),
			first_failed_at = coalesce(first_failed_at, now()), last_failure_code = $2 where id = $1 and first_failed_at is null`, occID, string(domainErr.Code))
		if err != nil || tag.RowsAffected() == 0 {
			return err
		}
		gid, rid := groupID, o.RuleID
		_, _, err = notifications.Create(ctx, tx, notifications.Notification{UserID: owner, Category: "group", EventType: "group_recurring_failed",
			Title: o.RuleName + " could not be added automatically", Body: "Check who shares it, then add it from the group.",
			DeepLink: "/groups/" + gid.String() + "/recurring", EntityType: "group_recurring_expense", EntityID: &rid,
			GroupID: &gid, Priority: "high", DedupeKey: "group_recurring_failed:" + occID.String()})
		return err
	})
}

// haltRules pauses (or stops) a group's active recurring bills, optionally
// only those created by one member, so they never fire into a group or for
// a person who can no longer act in it.
func (s *Service) haltRules(ctx context.Context, tx pgx.Tx, groupID uuid.UUID, owner *uuid.UUID, action string) error {
	if s.Recurring == nil {
		return nil
	}
	rows, err := tx.Query(ctx, `select id from recurring_rules where group_id = $1 and kind = 'group_expense' and status in ('active','paused')
		and ($2::uuid is null or user_id = $2) and ($3 = 'stop' or status = 'active')`, groupID, owner, action)
	if err != nil {
		return err
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return err
	}
	for _, id := range ids {
		if err := s.Recurring.SetGroupRuleStatusInTx(ctx, tx, id, action); err != nil {
			return err
		}
	}
	return nil
}
