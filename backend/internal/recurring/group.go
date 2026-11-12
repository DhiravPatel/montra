package recurring

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
)

// GroupRuleSpec describes a recurring shared expense (household rent,
// internet, a weekly grocery run): the schedule, amount and occurrences
// live in the recurring engine; the groups package owns the split template
// and creates the group expenses (ADR-040).
type GroupRuleSpec struct {
	Name        string
	Schedule    Schedule
	Amount      string
	Currency    string // the group currency
	Description string
	AutoAdd     bool
	GroupID     uuid.UUID
	Template    []byte
}

// CreateGroupRuleInTx validates and stores a group rule owned by uid and
// materializes its first occurrences. The caller authorizes membership.
func (s *Service) CreateGroupRuleInTx(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in GroupRuleSpec) (uuid.UUID, error) {
	x, err := s.validate(ctx, tx, uid, ruleSpec{Kind: "group_expense", Name: in.Name, Schedule: in.Schedule, Amount: in.Amount,
		Currency: in.Currency, Description: in.Description})
	if err != nil {
		return uuid.Nil, err
	}
	if x.amount == nil {
		return uuid.Nil, apperr.FieldError("body.amount", "Enter the amount of each expense.")
	}
	gid := in.GroupID
	x.AutoPost, x.GroupID, x.groupSplit = in.AutoAdd, &gid, in.Template
	return s.insertRule(ctx, tx, uid, x)
}

// GroupRuleRow is a group rule with its template, as stored.
type GroupRuleRow struct {
	RecurringRuleDTO
	OwnerID  uuid.UUID
	Template []byte
}

// GroupRules lists a group's recurring expenses (caller authorizes).
func (s *Service) GroupRules(ctx context.Context, tx pgx.Tx, me, groupID uuid.UUID, ruleID *uuid.UUID) ([]GroupRuleRow, error) {
	rows, err := tx.Query(ctx, `select `+ruleCols+` from recurring_rules
		where group_id = $1 and kind = 'group_expense' and ($2::uuid is null or id = $2)
		order by case status when 'active' then 0 when 'paused' then 1 else 2 end, next_occurrence_date nulls last, name`, groupID, ruleID)
	if err != nil {
		return nil, err
	}
	var list []*ruleRow
	for rows.Next() {
		x, err := scanRule(rows)
		if err != nil {
			rows.Close()
			return nil, err
		}
		list = append(list, x)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	out := make([]GroupRuleRow, 0, len(list))
	for _, x := range list {
		var tpl []byte
		if err := tx.QueryRow(ctx, `select coalesce(group_split, '{}'::jsonb) from recurring_rules where id = $1`, x.ID).Scan(&tpl); err != nil {
			return nil, err
		}
		out = append(out, GroupRuleRow{RecurringRuleDTO: x.dto(me), OwnerID: x.userID, Template: tpl})
	}
	return out, nil
}

// GroupOccurrences lists a rule's occurrences (newest first).
func (s *Service) GroupOccurrences(ctx context.Context, tx pgx.Tx, ruleID uuid.UUID, limit int) ([]OccurrenceDTO, error) {
	return queryOccs(ctx, tx, `o.rule_id = $1 order by o.occurrence_date desc limit $2`, ruleID, limit)
}

// UpdateGroupRuleInTx changes a group rule's name, amount, template and
// auto-add flag; open occurrences take the new amount. The schedule itself
// is changed by stopping the rule and creating a new one.
func (s *Service) UpdateGroupRuleInTx(ctx context.Context, tx pgx.Tx, id uuid.UUID, version int32, name string, amount int64, desc *string,
	template []byte, autoAdd bool) error {
	tag, err := tx.Exec(ctx, `update recurring_rules set name = $3, amount_minor = $4, description = $5, group_split = $6, auto_post = $7,
		version = version + 1 where id = $1 and version = $2 and kind = 'group_expense'`, id, version, name, amount, desc, template, autoAdd)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return apperr.VersionConflict()
	}
	_, err = tx.Exec(ctx, `update recurring_occurrences set amount_minor = $2 where rule_id = $1 and status in ('scheduled','overdue')
		and group_expense_id is null`, id, amount)
	return err
}

// SetGroupRuleStatusInTx pauses, resumes or stops a group rule.
func (s *Service) SetGroupRuleStatusInTx(ctx context.Context, tx pgx.Tx, id uuid.UUID, action string) error {
	return s.setStatus(ctx, tx, id, action)
}

// SetGroupRuleStatusByUserInTx is a member's pause/resume/stop: like
// SetGroupRuleStatusInTx, but a move that changes nothing is 422
// invalid_status_transition {from, to}.
func (s *Service) SetGroupRuleStatusByUserInTx(ctx context.Context, tx pgx.Tx, id uuid.UUID, action string) error {
	if err := checkMove(ctx, tx, id, action); err != nil {
		return err
	}
	return s.setStatus(ctx, tx, id, action)
}

// GroupOccurrence is an occurrence locked for completion.
type GroupOccurrence struct {
	ID        uuid.UUID
	RuleID    uuid.UUID
	GroupID   uuid.UUID
	OwnerID   uuid.UUID
	Date      time.Time // effective (postponed) date
	Amount    int64
	Status    string
	ExpenseID *uuid.UUID
	RuleName  string
	Template  []byte
	AutoAdd   bool
	RuleState string
}

// LockGroupOccurrenceInTx locks an occurrence of a group rule. skipLocked
// makes the scheduler pass over rows another worker holds.
func (s *Service) LockGroupOccurrenceInTx(ctx context.Context, tx pgx.Tx, occID uuid.UUID, skipLocked bool) (*GroupOccurrence, error) {
	lock := "for update of o"
	if skipLocked {
		lock += " skip locked"
	}
	var o GroupOccurrence
	var amt *int64
	err := tx.QueryRow(ctx, `select o.id, o.rule_id, o.group_id, r.user_id, coalesce(o.postponed_to, o.occurrence_date), coalesce(o.amount_minor, r.amount_minor),
		o.status, o.group_expense_id, r.name, coalesce(r.group_split, '{}'::jsonb), r.auto_post, r.status
		from recurring_occurrences o join recurring_rules r on r.id = o.rule_id
		where o.id = $1 and r.kind = 'group_expense' and o.group_id is not null `+lock, occID).
		Scan(&o.ID, &o.RuleID, &o.GroupID, &o.OwnerID, &o.Date, &amt, &o.Status, &o.ExpenseID, &o.RuleName, &o.Template, &o.AutoAdd, &o.RuleState)
	if database.IsNoRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if amt != nil {
		o.Amount = *amt
	}
	return &o, nil
}

// CompleteGroupOccurrenceInTx records an occurrence's outcome: the group
// expense added for it, or skipped. Any active member may add a due
// occurrence (ADR-040) while RLS lets only the rule's creator and the
// group's admins lock or update the rule, so the rule is locked and its
// progress recorded through two narrow definer helpers (migration 000023)
// that act only for active members of the rule's group.
func (s *Service) CompleteGroupOccurrenceInTx(ctx context.Context, tx pgx.Tx, o *GroupOccurrence, expenseID *uuid.UUID) error {
	status := "skipped"
	if expenseID != nil {
		status = "posted"
	}
	if err := LockGroupRuleInTx(ctx, tx, o.RuleID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `update recurring_occurrences set status = $2, group_expense_id = $3 where id = $1`, o.ID, status, expenseID); err != nil {
		return err
	}
	x, err := scanRule(tx.QueryRow(ctx, `select `+ruleCols+` from recurring_rules where id = $1`, o.RuleID))
	if err != nil {
		return err
	}
	p, err := s.progressOf(ctx, tx, x)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `select montra.record_group_rule_progress($1, $2, $3)`, x.ID, p.next, p.status)
	return err
}

// LockGroupRuleInTx locks a group rule's row for an active member of its
// group (NotFound otherwise).
func LockGroupRuleInTx(ctx context.Context, tx pgx.Tx, ruleID uuid.UUID) error {
	var ok bool
	if err := tx.QueryRow(ctx, `select montra.lock_group_rule($1)`, ruleID).Scan(&ok); err != nil {
		return err
	}
	if !ok {
		return apperr.NotFound("recurring expense")
	}
	return nil
}
