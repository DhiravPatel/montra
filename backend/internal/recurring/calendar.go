package recurring

import (
	"context"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/subscriptions"
)

// CalendarItem is one dated planning entry.
type CalendarItem struct {
	Date         string          `json:"date"`
	Kind         string          `json:"kind" enum:"recurring,bill,group_expense,subscription_renewal,trial_end,goal_target"`
	Title        string          `json:"title"`
	Amount       *apitypes.Money `json:"amount,omitempty"`
	Status       string          `json:"status" enum:"scheduled,posted,paid,skipped,overdue,projected,expected,target" doc:"Occurrence status; projected = beyond the generated horizon; expected = subscription renewal or trial end; target = goal target date"`
	EntityType   string          `json:"entity_type" enum:"recurring_rule,bill,group_recurring_expense,subscription,goal"`
	EntityID     uuid.UUID       `json:"entity_id"`
	OccurrenceID *uuid.UUID      `json:"occurrence_id,omitempty"`
	PostponedTo  *string         `json:"postponed_to,omitempty" doc:"Set when the occurrence was moved; date is then the new date"`
	ScheduledOn  *string         `json:"scheduled_on,omitempty" doc:"The originally scheduled date of a moved occurrence"`
	GroupID      *uuid.UUID      `json:"group_id,omitempty" doc:"Shared expenses of one of your groups"`
}

const maxCalendarDays = 93

// Calendar merges recurring occurrences, bills, subscription renewals,
// trial ends and goal target dates for a date range (renewal calendar).
func (s *Service) Calendar(ctx context.Context, fromS, toS string) ([]CalendarItem, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []CalendarItem{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		today := localToday(s.now(), u.Loc)
		from, to := today, today.AddDate(0, 0, 30)
		if fromS != "" {
			d, err := finance.ParseDate("query.from", fromS, u.Loc)
			if err != nil {
				return err
			}
			from = dateOnly(d)
		}
		if toS != "" {
			d, err := finance.ParseDate("query.to", toS, u.Loc)
			if err != nil {
				return err
			}
			to = dateOnly(d)
		}
		if to.Before(from) || to.Sub(from) > maxCalendarDays*24*time.Hour {
			return apperr.Validation("Choose a range of at most 93 days.")
		}
		// Materialized occurrences.
		occ, err := queryOccs(ctx, tx, `coalesce(o.postponed_to, o.occurrence_date) between $1 and $2 and o.status <> 'cancelled'
			order by coalesce(o.postponed_to, o.occurrence_date)`, from, to)
		if err != nil {
			return err
		}
		for i := range occ {
			o := occ[i]
			item := CalendarItem{Date: o.EffectiveDate, Kind: "recurring", Title: o.RuleName, Amount: o.Amount, Status: o.Status,
				EntityType: "recurring_rule", EntityID: o.RuleID, OccurrenceID: &occ[i].ID}
			if o.PostponedTo != nil {
				scheduled := o.OccurrenceDate
				item.PostponedTo, item.ScheduledOn = o.PostponedTo, &scheduled
			}
			if o.BillID != nil {
				item.Kind, item.EntityType, item.EntityID = "bill", "bill", *o.BillID
			}
			if o.GroupID != nil {
				item.Kind, item.EntityType, item.GroupID = "group_expense", "group_recurring_expense", o.GroupID
			}
			out = append(out, item)
		}
		// Projected occurrences beyond each active rule's generated horizon.
		rows, err := tx.Query(ctx, `select `+ruleCols+` from recurring_rules where status = 'active' and (generated_through is null or generated_through < $1)`, to)
		if err != nil {
			return err
		}
		var rules []*ruleRow
		for rows.Next() {
			x, err := scanRule(rows)
			if err != nil {
				rows.Close()
				return err
			}
			rules = append(rules, x)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		for _, x := range rules {
			spec, err := x.spec()
			if err != nil {
				continue
			}
			start := from
			if x.generated != nil && !x.generated.Before(start) {
				start = x.generated.AddDate(0, 0, 1)
			}
			var bill *uuid.UUID
			if x.Kind == "bill" {
				var b uuid.UUID
				if err := tx.QueryRow(ctx, `select id from bills where recurring_rule_id = $1`, x.ID).Scan(&b); err == nil {
					bill = &b
				}
			}
			for _, d := range spec.Between(start, to, 200) {
				item := CalendarItem{Date: finance.LocalDateString(d), Kind: "recurring", Title: x.Name, Amount: x.Amount, Status: "projected",
					EntityType: "recurring_rule", EntityID: x.ID}
				if bill != nil {
					item.Kind, item.EntityType, item.EntityID = "bill", "bill", *bill
				}
				if x.GroupID != nil {
					item.Kind, item.EntityType, item.GroupID = "group_expense", "group_recurring_expense", x.GroupID
				}
				out = append(out, item)
			}
		}
		// Subscription renewals and trial ends.
		srows, err := tx.Query(ctx, `select id, name, amount_minor, currency, billing_frequency, interval_count, interval_unit, start_date,
			next_renewal_date, trial_ends_on, status from subscriptions where status in ('trial','active')`)
		if err != nil {
			return err
		}
		type sub struct {
			id          uuid.UUID
			name, cur   string
			amount      int64
			freq        string
			interval    int16
			unit        *string
			start       time.Time
			next, trial *time.Time
			status      string
		}
		subs, err := pgx.CollectRows(srows, func(r pgx.CollectableRow) (sub, error) {
			var x sub
			err := r.Scan(&x.id, &x.name, &x.amount, &x.cur, &x.freq, &x.interval, &x.unit, &x.start, &x.next, &x.trial, &x.status)
			return x, err
		})
		if err != nil {
			return err
		}
		for _, x := range subs {
			if x.next != nil {
				r := subscriptions.RenewalSchedule(x.freq, x.interval, x.unit, x.start, *x.next)
				for _, d := range r.Between(from, to, 100) {
					out = append(out, CalendarItem{Date: finance.LocalDateString(d), Kind: "subscription_renewal", Title: x.name,
						Amount: apitypes.MP(&x.amount, x.cur), Status: "expected", EntityType: "subscription", EntityID: x.id})
				}
			}
			if x.status == "trial" && x.trial != nil && !x.trial.Before(from) && !x.trial.After(to) {
				out = append(out, CalendarItem{Date: finance.LocalDateString(*x.trial), Kind: "trial_end", Title: x.name, Status: "expected",
					EntityType: "subscription", EntityID: x.id})
			}
		}
		// Goal target dates.
		grows, err := tx.Query(ctx, `select id, name, target_date from goals where status = 'active' and target_date between $1 and $2`, from, to)
		if err != nil {
			return err
		}
		defer grows.Close()
		for grows.Next() {
			var id uuid.UUID
			var name string
			var d time.Time
			if err := grows.Scan(&id, &name, &d); err != nil {
				return err
			}
			out = append(out, CalendarItem{Date: finance.LocalDateString(d), Kind: "goal_target", Title: name, Status: "target",
				EntityType: "goal", EntityID: id})
		}
		return grows.Err()
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Date != out[j].Date {
			return out[i].Date < out[j].Date
		}
		return out[i].Kind < out[j].Kind
	})
	return out, nil
}
