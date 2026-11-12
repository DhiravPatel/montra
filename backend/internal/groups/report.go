package groups

import (
	"bytes"
	"context"
	"encoding/csv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/reports/render"
)

// GroupCategoryTotal is spending in one category.
type GroupCategoryTotal struct {
	CategoryKey string         `json:"category_key" doc:"uncategorized when none was chosen"`
	Total       apitypes.Money `json:"total"`
	Count       int            `json:"count"`
}

// GroupMemberTotal is what one member paid and owes in total.
type GroupMemberTotal struct {
	UserID      uuid.UUID      `json:"user_id"`
	DisplayName string         `json:"display_name"`
	Paid        apitypes.Money `json:"paid"`
	Share       apitypes.Money `json:"share"`
}

// GroupMonthTotal is spending in one calendar month.
type GroupMonthTotal struct {
	Month string         `json:"month" doc:"YYYY-MM"`
	Total apitypes.Money `json:"total"`
	Count int            `json:"count"`
}

// GroupCurrencyTotal records expenses entered in another currency, with
// the manual rates disclosed on each expense.
type GroupCurrencyTotal struct {
	Currency  string         `json:"currency"`
	Original  apitypes.Money `json:"original"`
	Converted apitypes.Money `json:"converted" doc:"In the group currency, using each expense's own rate"`
	Count     int            `json:"count"`
}

// GroupSettlementSummary totals settlements.
type GroupSettlementSummary struct {
	Confirmed apitypes.Money `json:"confirmed"`
	Pending   apitypes.Money `json:"pending" doc:"Reported but not yet confirmed"`
	Disputed  int            `json:"disputed"`
	Count     int            `json:"count" doc:"Non-voided settlements"`
}

// GroupTripSummary describes a trip or event.
type GroupTripSummary struct {
	StartDate    *string        `json:"start_date,omitempty"`
	EndDate      *string        `json:"end_date,omitempty"`
	Destination  *string        `json:"destination,omitempty"`
	Days         int            `json:"days" doc:"Trip length when both dates are set, else days with expenses"`
	DailyAverage apitypes.Money `json:"daily_average"`
}

// GroupReportDTO summarises a group's shared spending (final report and
// settlement summary for trips and events; combined view for households).
type GroupReportDTO struct {
	GroupID            uuid.UUID              `json:"group_id"`
	GroupType          string                 `json:"group_type"`
	Currency           string                 `json:"currency"`
	From               *string                `json:"from,omitempty"`
	To                 *string                `json:"to,omitempty"`
	TotalSpent         apitypes.Money         `json:"total_spent"`
	ExpenseCount       int                    `json:"expense_count"`
	DisputedCount      int                    `json:"disputed_count"`
	ParticipantCount   int                    `json:"participant_count"`
	PerPersonAverage   apitypes.Money         `json:"per_person_average" doc:"Total divided by the number of people who shared at least one expense"`
	MyPaid             apitypes.Money         `json:"my_paid"`
	MyShare            apitypes.Money         `json:"my_share"`
	ByCategory         []GroupCategoryTotal   `json:"by_category"`
	ByMember           []GroupMemberTotal     `json:"by_member"`
	ByMonth            []GroupMonthTotal      `json:"by_month"`
	OriginalCurrencies []GroupCurrencyTotal   `json:"original_currencies"`
	Settlements        GroupSettlementSummary `json:"settlements"`
	Trip               *GroupTripSummary      `json:"trip,omitempty"`
	Balances           GroupBalancesDTO       `json:"balances" doc:"Current balances and the settlement plan"`
}

// Report builds the group report, optionally for a date range.
func (s *Service) Report(ctx context.Context, groupID uuid.UUID, from, to string) (*GroupReportDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupReportDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		_, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		lo, hi, err := reportRange(from, to)
		if err != nil {
			return err
		}
		out, err = s.report(ctx, tx, uid, g, lo, hi)
		return err
	})
	return out, database.MapError(err)
}

func reportRange(from, to string) (*time.Time, *time.Time, error) {
	var lo, hi *time.Time
	if from != "" {
		d, err := finance.ParseDate("query.from", from, time.UTC)
		if err != nil {
			return nil, nil, err
		}
		lo = &d
	}
	if to != "" {
		d, err := finance.ParseDate("query.to", to, time.UTC)
		if err != nil {
			return nil, nil, err
		}
		hi = &d
	}
	if lo != nil && hi != nil && hi.Before(*lo) {
		return nil, nil, apperr.FieldError("query.to", "The end date must be on or after the start date.")
	}
	return lo, hi, nil
}

func (s *Service) report(ctx context.Context, tx pgx.Tx, me uuid.UUID, g *GroupDTO, lo, hi *time.Time) (*GroupReportDTO, error) {
	cur := g.BaseCurrency
	out := &GroupReportDTO{GroupID: g.ID, GroupType: g.GroupType, Currency: cur, ByCategory: []GroupCategoryTotal{}, ByMember: []GroupMemberTotal{},
		ByMonth: []GroupMonthTotal{}, OriginalCurrencies: []GroupCurrencyTotal{}}
	if lo != nil {
		v := finance.LocalDateString(*lo)
		out.From = &v
	}
	if hi != nil {
		v := finance.LocalDateString(*hi)
		out.To = &v
	}
	where := `e.group_id = $1 and e.status <> 'deleted' and ($2::date is null or e.expense_date >= $2) and ($3::date is null or e.expense_date <= $3)`
	args := []any{g.ID, lo, hi}
	var total int64
	var days int
	if err := tx.QueryRow(ctx, `select coalesce(sum(e.amount_minor), 0)::bigint, count(*)::int, count(*) filter (where e.status = 'disputed')::int,
		count(distinct e.expense_date)::int from group_expenses e where `+where, args...).Scan(&total, &out.ExpenseCount, &out.DisputedCount, &days); err != nil {
		return nil, err
	}
	out.TotalSpent = apitypes.M(total, cur)
	rows, err := tx.Query(ctx, `select coalesce(e.category_key, 'uncategorized'), sum(e.amount_minor)::bigint, count(*)::int from group_expenses e
		where `+where+` group by 1 order by 2 desc, 1`, args...)
	if err != nil {
		return nil, err
	}
	if out.ByCategory, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (GroupCategoryTotal, error) {
		var c GroupCategoryTotal
		var amt int64
		err := r.Scan(&c.CategoryKey, &amt, &c.Count)
		c.Total = apitypes.M(amt, cur)
		return c, err
	}); err != nil {
		return nil, err
	}
	rows, err = tx.Query(ctx, `select to_char(e.expense_date, 'YYYY-MM'), sum(e.amount_minor)::bigint, count(*)::int from group_expenses e
		where `+where+` group by 1 order by 1`, args...)
	if err != nil {
		return nil, err
	}
	if out.ByMonth, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (GroupMonthTotal, error) {
		var m GroupMonthTotal
		var amt int64
		err := r.Scan(&m.Month, &amt, &m.Count)
		m.Total = apitypes.M(amt, cur)
		return m, err
	}); err != nil {
		return nil, err
	}
	rows, err = tx.Query(ctx, `select e.original_currency, sum(e.original_amount_minor)::bigint, sum(e.amount_minor)::bigint, count(*)::int
		from group_expenses e where `+where+` and e.original_currency is not null group by 1 order by 1`, args...)
	if err != nil {
		return nil, err
	}
	if out.OriginalCurrencies, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (GroupCurrencyTotal, error) {
		var c GroupCurrencyTotal
		var orig, conv int64
		err := r.Scan(&c.Currency, &orig, &conv, &c.Count)
		c.Original, c.Converted = apitypes.M(orig, c.Currency), apitypes.M(conv, cur)
		return c, err
	}); err != nil {
		return nil, err
	}
	ms, err := members(ctx, tx, g.ID)
	if err != nil {
		return nil, err
	}
	names := map[uuid.UUID]string{}
	for _, m := range ms {
		names[m.UserID] = m.DisplayName
	}
	rows, err = tx.Query(ctx, `select u, sum(paid)::bigint, sum(share)::bigint from (
		select p.user_id u, p.amount_minor paid, 0::bigint share from group_expense_payers p join group_expenses e on e.id = p.expense_id where `+where+`
		union all
		select sh.user_id, 0, sh.share_minor from group_expense_shares sh join group_expenses e on e.id = sh.expense_id where `+where+`) x
		group by u order by 3 desc, 1`, args...)
	if err != nil {
		return nil, err
	}
	var participants int
	if out.ByMember, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (GroupMemberTotal, error) {
		var m GroupMemberTotal
		var paid, share int64
		err := r.Scan(&m.UserID, &paid, &share)
		m.DisplayName, m.Paid, m.Share = nameOr(names, m.UserID), apitypes.M(paid, cur), apitypes.M(share, cur)
		if share > 0 {
			participants++
		}
		if m.UserID == me {
			out.MyPaid, out.MyShare = m.Paid, m.Share
		}
		return m, err
	}); err != nil {
		return nil, err
	}
	if out.MyPaid.Currency == "" {
		out.MyPaid, out.MyShare = apitypes.M(0, cur), apitypes.M(0, cur)
	}
	out.ParticipantCount = participants
	out.PerPersonAverage = apitypes.M(0, cur)
	if participants > 0 {
		out.PerPersonAverage = apitypes.M(divRound(total, int64(participants)), cur)
	}
	var confirmed, pending int64
	if err := tx.QueryRow(ctx, `select coalesce(sum(amount_minor) filter (where status = 'confirmed'), 0)::bigint,
		coalesce(sum(amount_minor) filter (where status = 'user_reported_paid'), 0)::bigint,
		count(*) filter (where status = 'disputed')::int, count(*) filter (where status <> 'voided')::int
		from settlements where group_id = $1 and ($2::date is null or settled_on >= $2) and ($3::date is null or settled_on <= $3)`, args...).
		Scan(&confirmed, &pending, &out.Settlements.Disputed, &out.Settlements.Count); err != nil {
		return nil, err
	}
	out.Settlements.Confirmed, out.Settlements.Pending = apitypes.M(confirmed, cur), apitypes.M(pending, cur)
	if g.GroupType == "trip" || g.GroupType == "event" {
		t := &GroupTripSummary{StartDate: g.StartDate, EndDate: g.EndDate, Destination: g.Destination, Days: days}
		if g.StartDate != nil && g.EndDate != nil {
			sd, _ := time.Parse("2006-01-02", *g.StartDate)
			ed, _ := time.Parse("2006-01-02", *g.EndDate)
			if n := int(ed.Sub(sd).Hours()/24) + 1; n > 0 {
				t.Days = n
			}
		}
		t.DailyAverage = apitypes.M(0, cur)
		if t.Days > 0 {
			t.DailyAverage = apitypes.M(divRound(total, int64(t.Days)), cur)
		}
		out.Trip = t
	}
	b, err := s.balances(ctx, tx, g)
	if err != nil {
		return nil, err
	}
	out.Balances = *b
	return out, nil
}

// divRound divides rounding half away from zero (display averages only;
// never used to allocate money).
func divRound(a, b int64) int64 {
	if b == 0 {
		return 0
	}
	q, r := a/b, a%b
	if 2*abs(r) >= abs(b) {
		if (a < 0) != (b < 0) {
			q--
		} else {
			q++
		}
	}
	return q
}

func abs(v int64) int64 {
	if v < 0 {
		return -v
	}
	return v
}

// ExportCSV exports the group's expenses and settlements (members only;
// no personal account data). It returns the CSV and a safe file name,
// <group>-expenses-YYYY-MM-DD.csv (the group's local date).
func (s *Service) ExportCSV(ctx context.Context, groupID uuid.UUID) ([]byte, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	var buf bytes.Buffer
	var name string
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		_, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		loc, err := time.LoadLocation(g.Timezone)
		if err != nil {
			loc = time.UTC
		}
		name = csvName(g.Name) + "-expenses-" + s.now().In(loc).Format("2006-01-02") + ".csv"
		ms, err := members(ctx, tx, groupID)
		if err != nil {
			return err
		}
		names := map[uuid.UUID]string{}
		for _, m := range ms {
			names[m.UserID] = m.DisplayName
		}
		list, err := s.expenses(ctx, tx, uid, groupID, `true order by e.expense_date, e.created_at`)
		if err != nil {
			return err
		}
		buf.WriteString("\ufeff")
		w := csv.NewWriter(&buf)
		if err := w.Write([]string{"record", "date", "description", "category", "amount", "currency", "original_amount", "original_currency",
			"fx_rate", "split_method", "paid_by", "shares", "status"}); err != nil {
			return err
		}
		join := func(parts []string) string { return strings.Join(parts, "; ") }
		for _, e := range list {
			var paid, shares []string
			for _, p := range e.Payers {
				paid = append(paid, nameOr(names, p.UserID)+": "+p.Paid.Amount)
			}
			for _, sh := range e.Shares {
				shares = append(shares, nameOr(names, sh.UserID)+": "+sh.Share.Amount)
			}
			origAmt, origCur, rate, cat := "", "", "", ""
			if e.OriginalAmount != nil {
				origAmt, origCur = e.OriginalAmount.Amount, e.OriginalAmount.Currency
			}
			if e.FXRate != nil {
				rate = *e.FXRate
			}
			if e.CategoryKey != nil {
				cat = *e.CategoryKey
			}
			if err := w.Write([]string{"expense", e.ExpenseDate, render.SafeCell(e.Description), cat, e.Amount.Amount, e.Amount.Currency, origAmt, origCur,
				rate, e.SplitMethod, render.SafeCell(join(paid)), render.SafeCell(join(shares)), e.Status}); err != nil {
				return err
			}
		}
		sets, err := s.loadSettlements(ctx, tx, groupID, `true order by s.settled_on, s.created_at`)
		if err != nil {
			return err
		}
		for _, st := range sets {
			if err := w.Write([]string{"settlement", st.SettledOn, render.SafeCell(st.PayerName + " paid " + st.PayeeName), "", st.Amount.Amount,
				st.Amount.Currency, "", "", "", st.Method, render.SafeCell(st.PayerName), "", st.Status + " (" + st.Verification + ")"}); err != nil {
				return err
			}
		}
		w.Flush()
		return w.Error()
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	return buf.Bytes(), name, nil
}
