// Package budgets implements budgets, allocations, shared budgets, progress,
// rollover and threshold/forecast alerts (spec §4.6, §20B.7, §18 "Budget
// alert"). Spending is computed from ledger-backed transactions with the
// canonical classification (refunds restore budget when enabled; transfers
// never count; group expenses count the member's share).
package budgets

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/budgetcalc"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/period"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
)

// Service implements budgets.
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

// AllocationDTO is a sub-limit with its current spend.
type AllocationDTO struct {
	ID           uuid.UUID      `json:"id"`
	CategoryID   *uuid.UUID     `json:"category_id,omitempty"`
	MerchantID   *uuid.UUID     `json:"merchant_id,omitempty"`
	AccountID    *uuid.UUID     `json:"account_id,omitempty"`
	MemberUserID *uuid.UUID     `json:"member_user_id,omitempty"`
	Label        *string        `json:"label,omitempty"`
	Limit        apitypes.Money `json:"limit"`
	Spent        apitypes.Money `json:"spent"`
	Remaining    apitypes.Money `json:"remaining" doc:"Never negative; see overspent"`
	Overspent    apitypes.Money `json:"overspent" doc:"Amount spent beyond this allocation's limit"`
	PercentBP    int64          `json:"percent_bp"`
}

// MemberDTO is a budget collaborator.
type MemberDTO struct {
	UserID      uuid.UUID       `json:"user_id"`
	DisplayName string          `json:"display_name"`
	Role        string          `json:"role" enum:"editor,viewer"`
	Allocation  *apitypes.Money `json:"allocation,omitempty"`
}

// ProgressDTO is a period's progress.
type ProgressDTO struct {
	PeriodStart        string         `json:"period_start"`
	PeriodEnd          string         `json:"period_end"`
	BaseLimit          apitypes.Money `json:"base_limit"`
	RolloverIn         apitypes.Money `json:"rollover_in"`
	Limit              apitypes.Money `json:"limit" doc:"Base limit plus rollover"`
	Spent              apitypes.Money `json:"spent"`
	Remaining          apitypes.Money `json:"remaining"`
	Overspent          apitypes.Money `json:"overspent"`
	PercentBP          int64          `json:"percent_bp"`
	ElapsedDays        int            `json:"elapsed_days"`
	TotalDays          int            `json:"total_days"`
	ExpectedByNow      apitypes.Money `json:"expected_by_now"`
	Projected          apitypes.Money `json:"projected" doc:"Spend extrapolated at the current pace (estimate)"`
	ProjectedOver      apitypes.Money `json:"projected_over"`
	DailyAllowance     apitypes.Money `json:"daily_allowance"`
	Pace               string         `json:"pace" enum:"under_pace,on_track,ahead_of_pace,over_budget"`
	TransactionCount   int64          `json:"transaction_count"`
	OtherCurrencyCount int64          `json:"other_currency_count" doc:"Matching transactions in other currencies (not included)"`
	AsOf               *time.Time     `json:"as_of,omitempty" doc:"For collaborators: when the owner's totals were last computed"`
	Explanation        []string       `json:"explanation" doc:"English; localize by explanation_items"`
	ExplanationItems   []ExplainItem  `json:"explanation_items" doc:"Same lines as codes with values: spent_of_limit, refunds_restore, refunds_do_not_restore, rollover_included, projection_estimate, other_currencies_excluded, owner_totals_only"`
}

// ExplainItem is one coded explanation line.
type ExplainItem struct {
	Code   string            `json:"code"`
	Params map[string]string `json:"params,omitempty"`
}

// BudgetDTO is a budget with its current progress.
type BudgetDTO struct {
	ID                  uuid.UUID       `json:"id"`
	OwnerUserID         uuid.UUID       `json:"owner_user_id"`
	OwnerDisplayName    string          `json:"owner_display_name" doc:"Shown to collaborators as who shared the budget"`
	GroupID             *uuid.UUID      `json:"group_id,omitempty"`
	Name                string          `json:"name"`
	BudgetType          string          `json:"budget_type" enum:"total,category,merchant,account,envelope,zero_based"`
	Period              string          `json:"period" enum:"weekly,monthly,annual,custom"`
	Timezone            string          `json:"timezone"`
	Currency            string          `json:"currency"`
	Limit               apitypes.Money  `json:"limit"`
	RolloverPolicy      string          `json:"rollover_policy" enum:"none,carry_unused,carry_overspend,carry_both"`
	RolloverCap         *apitypes.Money `json:"rollover_cap,omitempty"`
	IncludePending      bool            `json:"include_pending"`
	RefundsRestore      bool            `json:"refunds_restore"`
	CountGroupShares    bool            `json:"count_group_shares"`
	IncludedAccountIDs  []uuid.UUID     `json:"included_account_ids"`
	ExcludedCategoryIDs []uuid.UUID     `json:"excluded_category_ids"`
	MerchantIDs         []uuid.UUID     `json:"merchant_ids"`
	AlertThresholds     []int16         `json:"alert_thresholds" enum:"1,5,10,20,25,30,40,50,60,70,75,80,90,95,100,110,125,150" doc:"Percent of the limit that raises an alert; [] = no threshold alerts"`
	AlertForecast       bool            `json:"alert_forecast"`
	Visibility          string          `json:"visibility" enum:"private,members"`
	Status              string          `json:"status" enum:"active,paused,archived"`
	StartsOn            string          `json:"starts_on"`
	EndsOn              *string         `json:"ends_on,omitempty"`
	Notes               *string         `json:"notes,omitempty"`
	Access              string          `json:"access" enum:"owner,editor,viewer"`
	Allocations         []AllocationDTO `json:"allocations"`
	Members             []MemberDTO     `json:"members"`
	Progress            *ProgressDTO    `json:"progress,omitempty"`
	Version             int32           `json:"version"`
	CreatedAt           time.Time       `json:"created_at"`
	UpdatedAt           time.Time       `json:"updated_at"`
}

type budgetRow struct {
	BudgetDTO
	limit   int64
	capMin  *int64
	starts  time.Time
	ends    *time.Time
	loc     *time.Location
	weekSt  time.Weekday
	monthSt int
}

const budgetSelect = `select b.id, b.owner_user_id, b.group_id, b.name, b.budget_type, b.period, b.timezone, b.currency, b.limit_minor,
	b.rollover_policy, b.rollover_cap_minor, b.include_pending, b.refunds_restore, b.count_group_shares, b.included_account_ids,
	b.excluded_category_ids, b.merchant_ids, b.alert_thresholds, b.alert_forecast, b.visibility, b.status, b.starts_on, b.ends_on,
	b.notes, coalesce(montra.budget_access(b.id), 'viewer'), b.version, b.created_at, b.updated_at,
	coalesce(p.week_start, 1), coalesce(p.month_start_day, 1)
	from budgets b left join user_preferences p on p.user_id = b.owner_user_id`

func scanBudget(r pgx.Row) (*budgetRow, error) {
	var b budgetRow
	var ws, md int16
	if err := r.Scan(&b.ID, &b.OwnerUserID, &b.GroupID, &b.Name, &b.BudgetType, &b.Period, &b.Timezone, &b.Currency, &b.limit,
		&b.RolloverPolicy, &b.capMin, &b.IncludePending, &b.RefundsRestore, &b.CountGroupShares, &b.IncludedAccountIDs,
		&b.ExcludedCategoryIDs, &b.MerchantIDs, &b.AlertThresholds, &b.AlertForecast, &b.Visibility, &b.Status, &b.starts, &b.ends,
		&b.Notes, &b.Access, &b.Version, &b.CreatedAt, &b.UpdatedAt, &ws, &md); err != nil {
		return nil, err
	}
	b.Limit = apitypes.M(b.limit, b.Currency)
	b.RolloverCap = apitypes.MP(b.capMin, b.Currency)
	b.StartsOn = finance.LocalDateString(b.starts)
	if b.ends != nil {
		e := finance.LocalDateString(*b.ends)
		b.EndsOn = &e
	}
	loc, err := time.LoadLocation(b.Timezone)
	if err != nil {
		loc = time.UTC
	}
	b.loc, b.weekSt, b.monthSt = loc, time.Weekday(ws), int(md)
	if b.IncludedAccountIDs == nil {
		b.IncludedAccountIDs = []uuid.UUID{}
	}
	if b.ExcludedCategoryIDs == nil {
		b.ExcludedCategoryIDs = []uuid.UUID{}
	}
	if b.MerchantIDs == nil {
		b.MerchantIDs = []uuid.UUID{}
	}
	return &b, nil
}

// periodFor returns the budget period containing date d.
func (b *budgetRow) periodFor(d time.Time) period.Range {
	d = period.Date(d.Year(), d.Month(), d.Day(), b.loc)
	switch b.Period {
	case "weekly":
		st := period.WeekStart(d, b.weekSt)
		return period.Range{Start: st, End: st.AddDate(0, 0, 6)}
	case "annual":
		return period.Range{Start: period.Date(d.Year(), 1, 1, b.loc), End: period.Date(d.Year(), 12, 31, b.loc)}
	case "custom":
		st := period.Date(b.starts.Year(), b.starts.Month(), b.starts.Day(), b.loc)
		end := st
		if b.ends != nil {
			end = period.Date(b.ends.Year(), b.ends.Month(), b.ends.Day(), b.loc)
		}
		return period.Range{Start: st, End: end}
	}
	return period.MonthContaining(d, b.monthSt)
}

// spend computes the budget's live spend for a range in the budget
// currency. It must run in a context that can read the counted records:
// the owner (personal budgets), a group member (group budgets) or the worker.
func (s *Service) spend(ctx context.Context, tx pgx.Tx, b *budgetRow, r period.Range, alloc *AllocationDTO) (spent, count, other int64, err error) {
	from, to := finance.LocalDateString(r.Start), finance.LocalDateString(r.End)
	if b.GroupID != nil {
		// Group/household/trip budgets track group expenses (group currency);
		// member allocations track each member's shares.
		q := `select coalesce(sum(e.amount_minor) filter (where e.currency = $4), 0)::bigint, count(*) filter (where e.currency = $4),
			count(*) filter (where e.currency <> $4) from group_expenses e
			where e.group_id = $1 and e.status <> 'deleted' and e.expense_date between $2::date and $3::date`
		args := []any{*b.GroupID, from, to, b.Currency}
		if alloc != nil && alloc.MemberUserID != nil {
			q = `select coalesce(sum(sh.share_minor) filter (where e.currency = $4), 0)::bigint, count(*) filter (where e.currency = $4),
				count(*) filter (where e.currency <> $4) from group_expense_shares sh join group_expenses e on e.id = sh.expense_id
				where e.group_id = $1 and e.status <> 'deleted' and e.expense_date between $2::date and $3::date and sh.user_id = $5`
			args = append(args, *alloc.MemberUserID)
		}
		err = tx.QueryRow(ctx, q, args...).Scan(&spent, &count, &other)
		return spent, count, other, err
	}
	expense, refund, where, args := personalFilter(b, from, to, alloc)
	counts := "((" + expense + ") <> 0 or (" + refund + ") <> 0)" // refunds that do not restore, and unshared group records, are not counted
	err = tx.QueryRow(ctx, `select coalesce(sum(`+expense+` - `+refund+`) filter (where t.currency = $4), 0)::bigint,
		count(*) filter (where t.currency = $4 and `+counts+`), count(*) filter (where t.currency <> $4 and `+counts+`)
		from transactions t where `+strings.Join(where, " and "), args...).Scan(&spent, &count, &other)
	if spent < 0 {
		spent = 0 // refunds restore a budget fully but never beyond its limit
	}
	return spent, count, other, err
}

// personalFilter is the selection of a personal budget's counted
// transactions in [from, to] (both the spend total and the drill-down use
// it, so the list always matches the total). args[3] is the budget
// currency; the caller restricts or splits by it.
func personalFilter(b *budgetRow, from, to string, alloc *AllocationDTO) (expense, refund string, where []string, args []any) {
	refund = "0"
	if b.RefundsRestore {
		refund = `case when t.type in ('refund','reimbursement') then t.amount_minor else 0 end`
	}
	expense = `case when t.type = 'expense' then t.amount_minor else 0 end`
	if b.CountGroupShares {
		expense = `case when t.type = 'expense' then t.amount_minor when t.type = 'group_expense' then coalesce(t.personal_share_minor, t.amount_minor) else 0 end`
	}
	args = []any{b.OwnerUserID, from, to, b.Currency}
	where = []string{"t.user_id = $1", "t.deleted_at is null", "t.local_date between $2::date and $3::date",
		"t.type in ('expense','group_expense','refund','reimbursement')",
		"(t.category_id is null or not exists (select 1 from categories c where c.id = t.category_id and not c.include_in_budgets))"}
	add := func(cond string, v any) {
		args = append(args, v)
		where = append(where, strings.ReplaceAll(cond, "?", fmt.Sprintf("$%d", len(args))))
	}
	if b.IncludePending {
		where = append(where, "t.status in ('posted','pending')")
	} else {
		where = append(where, "t.status = 'posted'")
	}
	if len(b.IncludedAccountIDs) > 0 {
		add("t.account_id = any(?)", b.IncludedAccountIDs)
	}
	if len(b.ExcludedCategoryIDs) > 0 {
		add("(t.category_id is null or not (t.category_id = any(?) or t.category_id in (select id from categories where parent_id = any(?))))", b.ExcludedCategoryIDs)
	}
	if len(b.MerchantIDs) > 0 && b.BudgetType == "merchant" {
		add("t.merchant_id = any(?)", b.MerchantIDs)
	}
	switch {
	case alloc != nil && alloc.CategoryID != nil:
		add("(t.category_id = ? or t.category_id in (select id from categories where parent_id = ?))", *alloc.CategoryID)
	case alloc != nil && alloc.MerchantID != nil:
		add("t.merchant_id = ?", *alloc.MerchantID)
	case alloc != nil && alloc.AccountID != nil:
		add("t.account_id = ?", *alloc.AccountID)
	case alloc == nil && (b.BudgetType == "category" || b.BudgetType == "envelope" || b.BudgetType == "zero_based"):
		add(`exists (select 1 from budget_allocations ba where ba.budget_id = ? and ba.category_id is not null
			and (ba.category_id = t.category_id or ba.category_id = (select parent_id from categories where id = t.category_id)))`, b.ID)
	}
	return expense, refund, where, args
}

// canComputeLive reports whether the caller can see the counted records.
func canComputeLive(b *budgetRow, uid uuid.UUID) bool {
	return b.GroupID != nil || b.OwnerUserID == uid
}

// cache stores current-period aggregates for collaborators.
func cache(ctx context.Context, tx pgx.Tx, b *budgetRow, r period.Range, limit, carry, spent, count, other int64, allocs map[string]int64) error {
	aj, _ := json.Marshal(allocs)
	_, err := tx.Exec(ctx, `insert into budget_period_snapshots (budget_id, period_start, period_end, limit_minor, rollover_in_minor, spent_minor,
		rollover_out_minor, allocations_spent, transaction_count, other_currency_count, computed_at)
		values ($1,$2,$3,$4,$5,$6,0,$7,$8,$9,now())
		on conflict (budget_id, period_start) do update set limit_minor = excluded.limit_minor, rollover_in_minor = excluded.rollover_in_minor,
		spent_minor = excluded.spent_minor, allocations_spent = excluded.allocations_spent, transaction_count = excluded.transaction_count,
		other_currency_count = excluded.other_currency_count, computed_at = now()`,
		b.ID, finance.LocalDateString(r.Start), finance.LocalDateString(r.End), limit, carry, spent, aj, count, other)
	if isReadOnly(err) {
		return nil
	}
	return err
}

// rolloverIn computes the amount carried into the period starting at r
// from previous closed periods (memoized in budget_period_snapshots).
func (s *Service) rolloverIn(ctx context.Context, tx pgx.Tx, b *budgetRow, r period.Range, depth int) (int64, error) {
	if b.RolloverPolicy == "none" || b.Period == "custom" || depth > 24 {
		return 0, nil
	}
	prev := b.periodFor(r.Start.AddDate(0, 0, -1))
	if prev.End.Before(period.Date(b.starts.Year(), b.starts.Month(), b.starts.Day(), b.loc)) {
		return 0, nil
	}
	var limit, carryIn, spent int64
	var computedAt time.Time
	err := tx.QueryRow(ctx, `select limit_minor, rollover_in_minor, spent_minor, computed_at from budget_period_snapshots
		where budget_id = $1 and period_start = $2`, b.ID, finance.LocalDateString(prev.Start)).Scan(&limit, &carryIn, &spent, &computedAt)
	fresh := err == nil
	if err != nil && !database.IsNoRows(err) {
		return 0, err
	}
	if fresh {
		// Invalidate when any counted record in that period changed after
		// the snapshot (backdated entries, edits, voids, restores).
		var last time.Time
		q := `select coalesce(max(updated_at), 'epoch'::timestamptz) from transactions where user_id = $1 and local_date between $2::date and $3::date`
		arg := any(b.OwnerUserID)
		if b.GroupID != nil {
			q = `select coalesce(max(updated_at), 'epoch'::timestamptz) from group_expenses where group_id = $1 and expense_date between $2::date and $3::date`
			arg = *b.GroupID
		}
		if err := tx.QueryRow(ctx, q, arg, finance.LocalDateString(prev.Start), finance.LocalDateString(prev.End)).Scan(&last); err != nil {
			return 0, err
		}
		fresh = !last.After(computedAt)
	} else {
		limit = b.limit // first computation uses the current limit (edits apply forward)
	}
	if !fresh {
		if carryIn, err = s.rolloverIn(ctx, tx, b, prev, depth+1); err != nil {
			return 0, err
		}
		if spent, _, _, err = s.spend(ctx, tx, b, prev, nil); err != nil {
			return 0, err
		}
		out := budgetcalc.Rollover(b.RolloverPolicy, limit+carryIn, spent, b.capMin)
		if _, err := tx.Exec(ctx, `insert into budget_period_snapshots (budget_id, period_start, period_end, limit_minor, rollover_in_minor,
			spent_minor, rollover_out_minor, computed_at) values ($1,$2,$3,$4,$5,$6,$7,now())
			on conflict (budget_id, period_start) do update set rollover_in_minor = excluded.rollover_in_minor, spent_minor = excluded.spent_minor,
			rollover_out_minor = excluded.rollover_out_minor, computed_at = now()`, b.ID, finance.LocalDateString(prev.Start),
			finance.LocalDateString(prev.End), limit, carryIn, spent, out); err != nil && !isReadOnly(err) {
			return 0, err
		}
	}
	return budgetcalc.Rollover(b.RolloverPolicy, limit+carryIn, spent, b.capMin), nil
}

func isReadOnly(err error) bool {
	pe, ok := database.PgError(err)
	return ok && pe.Code == "25006"
}

// progress computes a period's progress. Owners (and group members for
// group budgets) compute live figures and refresh the aggregate cache;
// collaborators on personal budgets read the cached aggregates.
func (s *Service) progress(ctx context.Context, tx pgx.Tx, b *budgetRow, r period.Range, uid uuid.UUID, allocs []AllocationDTO, allocLimits []int64) (*ProgressDTO, map[string]int64, error) {
	var carry, spent, count, other int64
	allocSpent := map[string]int64{}
	var asOf *time.Time
	if canComputeLive(b, uid) {
		var err error
		if carry, err = s.rolloverIn(ctx, tx, b, r, 0); err != nil {
			return nil, nil, err
		}
		if spent, count, other, err = s.spend(ctx, tx, b, r, nil); err != nil {
			return nil, nil, err
		}
		for i := range allocs {
			sp, _, _, err := s.spend(ctx, tx, b, r, &allocs[i])
			if err != nil {
				return nil, nil, err
			}
			allocSpent[allocs[i].ID.String()] = sp
		}
		if err := cache(ctx, tx, b, r, b.limit, carry, spent, count, other, allocSpent); err != nil {
			return nil, nil, err
		}
	} else {
		var aj []byte
		var at time.Time
		err := tx.QueryRow(ctx, `select rollover_in_minor, spent_minor, transaction_count, other_currency_count, allocations_spent, computed_at
			from budget_period_snapshots where budget_id = $1 and period_start = $2`, b.ID, finance.LocalDateString(r.Start)).
			Scan(&carry, &spent, &count, &other, &aj, &at)
		if err != nil && !database.IsNoRows(err) {
			return nil, nil, err
		}
		if err == nil {
			_ = json.Unmarshal(aj, &allocSpent)
			asOf = &at
		}
	}
	limit := b.limit + carry
	if limit < 0 {
		limit = 0
	}
	today := period.Today(s.now(), b.loc)
	p := budgetcalc.Compute(limit, spent, period.Elapsed(r, today), r.Days())
	cur := b.Currency
	out := &ProgressDTO{PeriodStart: finance.LocalDateString(r.Start), PeriodEnd: finance.LocalDateString(r.End),
		BaseLimit: apitypes.M(b.limit, cur), RolloverIn: apitypes.M(carry, cur), Limit: apitypes.M(limit, cur),
		Spent: apitypes.M(spent, cur), Remaining: apitypes.M(p.RemainingMinor, cur), Overspent: apitypes.M(p.OverspentMinor, cur),
		PercentBP: p.PercentBP, ElapsedDays: p.ElapsedDays, TotalDays: p.TotalDays, ExpectedByNow: apitypes.M(p.ExpectedByNowMinor, cur),
		Projected: apitypes.M(p.ProjectedMinor, cur), ProjectedOver: apitypes.M(p.ProjectedOverMinor, cur),
		DailyAllowance: apitypes.M(p.DailyAllowanceMinor, cur), Pace: p.Pace, TransactionCount: count, OtherCurrencyCount: other, AsOf: asOf}
	explain := func(code, text string, params map[string]string) {
		out.Explanation = append(out.Explanation, text)
		out.ExplanationItems = append(out.ExplanationItems, ExplainItem{Code: code, Params: params})
	}
	explain("spent_of_limit", fmt.Sprintf("Spent %s of %s between %s and %s.", out.Spent.Amount, out.Limit.Amount, out.PeriodStart, out.PeriodEnd),
		map[string]string{"spent": out.Spent.Amount, "limit": out.Limit.Amount, "currency": cur, "from": out.PeriodStart, "to": out.PeriodEnd})
	if b.RefundsRestore {
		explain("refunds_restore", "Transfers and balance adjustments never count; refunds restore budget.", nil)
	} else {
		explain("refunds_do_not_restore", "Transfers and balance adjustments never count; refunds do not restore budget.", nil)
	}
	if carry != 0 {
		explain("rollover_included", "Includes "+out.RolloverIn.Amount+" carried over from the previous period.",
			map[string]string{"amount": out.RolloverIn.Amount, "currency": cur})
	}
	if p.ElapsedDays > 0 && p.ElapsedDays < p.TotalDays {
		explain("projection_estimate", fmt.Sprintf("At the current pace you would spend about %s by the end of the period (an estimate, not a guarantee).",
			out.Projected.Amount), map[string]string{"projected": out.Projected.Amount, "currency": cur})
	}
	if other > 0 {
		explain("other_currencies_excluded", fmt.Sprintf("%d matching transaction(s) in other currencies are not included.", other),
			map[string]string{"count": fmt.Sprint(other)})
	}
	if !canComputeLive(b, uid) {
		explain("owner_totals_only", "You see the owner's totals only; individual transactions stay private.", nil)
	}
	return out, allocSpent, nil
}

func (s *Service) load(ctx context.Context, tx pgx.Tx, id uuid.UUID, withProgress bool) (*BudgetDTO, *budgetRow, error) {
	b, err := scanBudget(tx.QueryRow(ctx, budgetSelect+` where b.id = $1`, id))
	if database.IsNoRows(err) {
		return nil, nil, apperr.NotFound("budget")
	}
	if err != nil {
		return nil, nil, err
	}
	b.Allocations, b.Members = []AllocationDTO{}, []MemberDTO{}
	r := b.periodFor(s.now())
	rows, err := tx.Query(ctx, `select id, category_id, merchant_id, account_id, member_user_id, label, limit_minor from budget_allocations
		where budget_id = $1 order by created_at`, id)
	if err != nil {
		return nil, nil, err
	}
	var allocs []AllocationDTO
	var limits []int64
	for rows.Next() {
		var a AllocationDTO
		var lim int64
		if err := rows.Scan(&a.ID, &a.CategoryID, &a.MerchantID, &a.AccountID, &a.MemberUserID, &a.Label, &lim); err != nil {
			rows.Close()
			return nil, nil, err
		}
		allocs = append(allocs, a)
		limits = append(limits, lim)
	}
	rows.Close()
	var allocSpent map[string]int64
	if withProgress && b.Status == "active" {
		uid, _ := identity.UserID(ctx)
		if b.Progress, allocSpent, err = s.progress(ctx, tx, b, r, uid, allocs, limits); err != nil {
			return nil, nil, err
		}
	}
	for i := range allocs {
		a := &allocs[i]
		a.Limit = apitypes.M(limits[i], b.Currency)
		spent := allocSpent[a.ID.String()]
		a.Spent = apitypes.M(spent, b.Currency)
		rem, over := limits[i]-spent, int64(0)
		if rem < 0 {
			rem, over = 0, -rem
		}
		a.Remaining, a.Overspent = apitypes.M(rem, b.Currency), apitypes.M(over, b.Currency)
		if limits[i] > 0 {
			a.PercentBP = budgetcalc.Compute(limits[i], spent, 1, 1).PercentBP
		}
		b.Allocations = append(b.Allocations, *a)
	}
	if err := tx.QueryRow(ctx, `select coalesce((select display_name from profiles where user_id = $1), '')`, b.OwnerUserID).
		Scan(&b.OwnerDisplayName); err != nil {
		return nil, nil, err
	}
	mrows, err := tx.Query(ctx, `select m.user_id, coalesce(p.display_name, 'Member'), m.role, m.allocation_minor
		from budget_members m left join profiles p on p.user_id = m.user_id where m.budget_id = $1 order by m.created_at`, id)
	if err != nil {
		return nil, nil, err
	}
	for mrows.Next() {
		var md MemberDTO
		var alloc *int64
		if err := mrows.Scan(&md.UserID, &md.DisplayName, &md.Role, &alloc); err != nil {
			mrows.Close()
			return nil, nil, err
		}
		md.Allocation = apitypes.MP(alloc, b.Currency)
		b.Members = append(b.Members, md)
	}
	mrows.Close()
	return &b.BudgetDTO, b, nil
}

// List returns budgets the caller owns, collaborates on, or can see via a group.
func (s *Service) List(ctx context.Context, includeArchived bool) ([]BudgetDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []BudgetDTO{}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id from budgets where ($1 or status <> 'archived') order by status, created_at`, includeArchived)
		if err != nil {
			return err
		}
		var ids []uuid.UUID
		for rows.Next() {
			var id uuid.UUID
			if err := rows.Scan(&id); err != nil {
				rows.Close()
				return err
			}
			ids = append(ids, id)
		}
		rows.Close()
		for _, id := range ids {
			b, _, err := s.load(ctx, tx, id, true)
			if err != nil {
				return err
			}
			out = append(out, *b)
		}
		return nil
	})
	return out, database.MapError(err)
}

// Get returns one budget with progress.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (*BudgetDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *BudgetDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out, _, err = s.load(ctx, tx, id, true)
		return err
	})
	return out, database.MapError(err)
}

// ProgressHistory returns progress for the period containing date (or the
// current one) plus the previous period for comparison.
func (s *Service) ProgressHistory(ctx context.Context, id uuid.UUID, date string) ([]ProgressDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []ProgressDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, b, err := s.load(ctx, tx, id, false)
		if err != nil {
			return err
		}
		at := s.now()
		if date != "" {
			if at, err = finance.ParseDate("query.date", date, b.loc); err != nil {
				return err
			}
		}
		r := b.periodFor(at)
		cur, _, err := s.progress(ctx, tx, b, r, uid, nil, nil)
		if err != nil {
			return err
		}
		out = append(out, *cur)
		if b.Period != "custom" {
			prev, _, err := s.progress(ctx, tx, b, b.periodFor(r.Start.AddDate(0, 0, -1)), uid, nil, nil)
			if err != nil {
				return err
			}
			out = append(out, *prev)
		}
		return nil
	})
	return out, database.MapError(err)
}

// BudgetInput creates or replaces a budget.
type BudgetInput struct {
	Name                string        `json:"name" minLength:"1" maxLength:"80"`
	BudgetType          string        `json:"budget_type" enum:"total,category,merchant,account,envelope,zero_based"`
	Period              string        `json:"period" enum:"weekly,monthly,annual,custom"`
	Currency            string        `json:"currency" pattern:"^[A-Z]{3}$"`
	Limit               string        `json:"limit" doc:"Total limit (envelope/zero-based: sum of allocations is used when larger)"`
	Timezone            string        `json:"timezone,omitempty" maxLength:"64"`
	StartsOn            string        `json:"starts_on,omitempty"`
	EndsOn              string        `json:"ends_on,omitempty" doc:"Required for custom periods"`
	RolloverPolicy      string        `json:"rollover_policy,omitempty" enum:"none,carry_unused,carry_overspend,carry_both"`
	RolloverCap         string        `json:"rollover_cap,omitempty"`
	IncludePending      bool          `json:"include_pending,omitempty"`
	RefundsRestore      *bool         `json:"refunds_restore,omitempty"`
	CountGroupShares    *bool         `json:"count_group_shares,omitempty"`
	IncludedAccountIDs  []uuid.UUID   `json:"included_account_ids,omitempty" maxItems:"50"`
	ExcludedCategoryIDs []uuid.UUID   `json:"excluded_category_ids,omitempty" maxItems:"50"`
	MerchantIDs         []uuid.UUID   `json:"merchant_ids,omitempty" maxItems:"50"`
	AlertThresholds     []int16       `json:"alert_thresholds,omitempty" maxItems:"10" enum:"1,5,10,20,25,30,40,50,60,70,75,80,90,95,100,110,125,150" doc:"Omit for the defaults; [] turns threshold alerts off"`
	AlertForecast       *bool         `json:"alert_forecast,omitempty"`
	Visibility          string        `json:"visibility,omitempty" enum:"private,members" doc:"private: only you and the collaborators you add; members: every member of the budget's group can view it (group budgets)"`
	Notes               string        `json:"notes,omitempty" maxLength:"1000"`
	GroupID             *uuid.UUID    `json:"group_id,omitempty" doc:"Household/group/trip budget tracking group expenses"`
	Allocations         []AllocInput  `json:"allocations,omitempty" maxItems:"100"`
	Version             int32         `json:"version,omitempty" doc:"Required when updating"`
	Members             []MemberInput `json:"members,omitempty" maxItems:"20"`
}

// AllocInput is a sub-limit.
type AllocInput struct {
	CategoryID   *uuid.UUID `json:"category_id,omitempty"`
	MerchantID   *uuid.UUID `json:"merchant_id,omitempty"`
	AccountID    *uuid.UUID `json:"account_id,omitempty"`
	MemberUserID *uuid.UUID `json:"member_user_id,omitempty"`
	Label        string     `json:"label,omitempty" maxLength:"80"`
	Limit        string     `json:"limit"`
}

// MemberInput adds a collaborator.
type MemberInput struct {
	UserID     uuid.UUID `json:"user_id"`
	Role       string    `json:"role" enum:"editor,viewer"`
	Allocation string    `json:"allocation,omitempty"`
}

var allowedThresholds = map[int16]bool{1: true, 5: true, 10: true, 20: true, 25: true, 30: true, 40: true, 50: true, 60: true, 70: true,
	75: true, 80: true, 90: true, 95: true, 100: true, 110: true, 125: true, 150: true}

// Save creates (id nil) or replaces a budget. Edits apply to the current
// and future periods; closed-period snapshots are never rewritten.
func (s *Service) Save(ctx context.Context, id *uuid.UUID, in BudgetInput) (*BudgetDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if !currency.Selectable(in.Currency) {
		return nil, apperr.FieldError("body.currency", "Unsupported currency.")
	}
	limit, err := finance.ParseAmount("body.limit", in.Limit, in.Currency)
	if err != nil {
		return nil, err
	}
	var capMinor *int64
	if in.RolloverCap != "" {
		v, err := finance.ParseAmount("body.rollover_cap", in.RolloverCap, in.Currency)
		if err != nil {
			return nil, err
		}
		capMinor = &v
	}
	if in.RolloverPolicy == "" {
		in.RolloverPolicy = "none"
	}
	if in.Visibility == "" {
		in.Visibility = "private"
		if in.GroupID != nil {
			in.Visibility = "members"
		}
	}
	thresholds := in.AlertThresholds
	if thresholds == nil {
		thresholds = []int16{50, 75, 90, 100} // absent: defaults; an explicit empty list means no threshold alerts
	}
	for _, t := range thresholds {
		if !allowedThresholds[t] {
			return nil, apperr.FieldError("body.alert_thresholds", "Use thresholds like 50, 75, 90 or 100.")
		}
	}
	refunds, shares, forecast := true, true, true
	if in.RefundsRestore != nil {
		refunds = *in.RefundsRestore
	}
	if in.CountGroupShares != nil {
		shares = *in.CountGroupShares
	}
	if in.AlertForecast != nil {
		forecast = *in.AlertForecast
	}
	var out *BudgetDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		tz := in.Timezone
		if tz == "" {
			tz = u.Timezone
		}
		loc, err := time.LoadLocation(tz)
		if err != nil || tz == "Local" {
			return apperr.FieldError("body.timezone", "Unknown time zone.")
		}
		starts := period.Today(s.now(), loc)
		if in.StartsOn != "" {
			if starts, err = finance.ParseDate("body.starts_on", in.StartsOn, loc); err != nil {
				return err
			}
		}
		var ends *time.Time
		if in.EndsOn != "" {
			e, err := finance.ParseDate("body.ends_on", in.EndsOn, loc)
			if err != nil {
				return err
			}
			if e.Before(starts) {
				return apperr.FieldError("body.ends_on", "End date must be on or after the start date.")
			}
			ends = &e
		}
		if in.Period == "custom" && ends == nil {
			return apperr.FieldError("body.ends_on", "Custom budgets need an end date.")
		}
		if in.GroupID != nil {
			var member bool
			var gcur string
			if err := tx.QueryRow(ctx, `select montra.is_group_member(id), base_currency from groups where id = $1 and status = 'active'`, *in.GroupID).Scan(&member, &gcur); err != nil || !member {
				return apperr.NotFound("group")
			}
			if gcur != in.Currency {
				return apperr.FieldError("body.currency", "Group budgets use the group's currency ("+gcur+").")
			}
		}
		if err := validateShape(ctx, tx, in); err != nil {
			return err
		}
		if err := validateRefs(ctx, tx, uid, id, in); err != nil {
			return err
		}
		var allocSum int64
		allocLimits := make([]int64, len(in.Allocations))
		for i, a := range in.Allocations {
			v, err := finance.ParseAmount(fmt.Sprintf("body.allocations[%d].limit", i), a.Limit, in.Currency)
			if err != nil {
				return err
			}
			allocLimits[i] = v
			allocSum += v
		}
		if (in.BudgetType == "envelope" || in.BudgetType == "zero_based") && len(in.Allocations) == 0 {
			return apperr.FieldError("body.allocations", "Envelope and zero-based budgets need allocations.")
		}
		if in.BudgetType == "zero_based" && allocSum != limit {
			return apperr.Rule("zero_based_unallocated", "Zero-based budgets must allocate exactly the full limit.", nil)
		}
		if in.BudgetType == "category" && len(in.Allocations) == 0 {
			return apperr.FieldError("body.allocations", "Category budgets need at least one category allocation.")
		}
		var bid uuid.UUID
		if id == nil {
			bid = uuid.New()
			if _, err := tx.Exec(ctx, `insert into budgets (id, owner_user_id, group_id, name, budget_type, period, timezone, currency, limit_minor,
				rollover_policy, rollover_cap_minor, include_pending, refunds_restore, count_group_shares, included_account_ids, excluded_category_ids,
				merchant_ids, alert_thresholds, alert_forecast, visibility, starts_on, ends_on, notes)
				values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,nullif($23,''))`,
				bid, uid, in.GroupID, strings.TrimSpace(in.Name), in.BudgetType, in.Period, tz, in.Currency, limit, in.RolloverPolicy, capMinor,
				in.IncludePending, refunds, shares, ids(in.IncludedAccountIDs), ids(in.ExcludedCategoryIDs), ids(in.MerchantIDs), thresholds,
				forecast, in.Visibility, starts, ends, in.Notes); err != nil {
				return err
			}
		} else {
			bid = *id
			var access *string
			if err := tx.QueryRow(ctx, `select montra.budget_access(id) from budgets where id = $1`, bid).Scan(&access); err != nil {
				if database.IsNoRows(err) {
					return apperr.NotFound("budget")
				}
				return err
			}
			if access == nil || (*access != "owner" && *access != "editor") {
				return apperr.Forbidden()
			}
			var version int32
			if err := tx.QueryRow(ctx, `select version from budgets where id = $1 for update`, bid).Scan(&version); err != nil {
				return err
			}
			if version != in.Version {
				return apperr.VersionConflict()
			}
			if _, err := tx.Exec(ctx, `update budgets set name = $2, budget_type = $3, period = $4, timezone = $5, limit_minor = $6,
				rollover_policy = $7, rollover_cap_minor = $8, include_pending = $9, refunds_restore = $10, count_group_shares = $11,
				included_account_ids = $12, excluded_category_ids = $13, merchant_ids = $14, alert_thresholds = $15, alert_forecast = $16,
				visibility = $17, starts_on = $18, ends_on = $19, notes = nullif($20,''), version = version + 1 where id = $1`,
				bid, strings.TrimSpace(in.Name), in.BudgetType, in.Period, tz, limit, in.RolloverPolicy, capMinor, in.IncludePending, refunds, shares,
				ids(in.IncludedAccountIDs), ids(in.ExcludedCategoryIDs), ids(in.MerchantIDs), thresholds, forecast, in.Visibility, starts, ends, in.Notes); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `delete from budget_allocations where budget_id = $1`, bid); err != nil {
				return err
			}
		}
		for i, a := range in.Allocations {
			if _, err := tx.Exec(ctx, `insert into budget_allocations (budget_id, category_id, merchant_id, account_id, member_user_id, label, limit_minor)
				values ($1,$2,$3,$4,$5,nullif($6,''),$7)`, bid, a.CategoryID, a.MerchantID, a.AccountID, a.MemberUserID, a.Label, allocLimits[i]); err != nil {
				return err
			}
		}
		for i, mem := range in.Members {
			if err := s.addMember(ctx, tx, uid, bid, in.Currency, mem, fmt.Sprintf("body.members[%d].", i)); err != nil {
				return err
			}
		}
		action := map[bool]string{true: "created", false: "updated"}[id == nil]
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, GroupID: in.GroupID, ActorUserID: &uid, EntityType: "budget", EntityID: &bid, Action: action}); err != nil {
			return err
		}
		out, _, err = s.load(ctx, tx, bid, true)
		return err
	})
	return out, database.MapError(err)
}

func ids(v []uuid.UUID) []uuid.UUID {
	if v == nil {
		return []uuid.UUID{}
	}
	return v
}

// validateRefs ensures referenced accounts/categories/merchants belong to
// the budget's owner: the caller when creating, the owner when an editor
// updates someone else's budget (through a definer helper, since RLS hides
// the owner's records from editors).
func validateRefs(ctx context.Context, tx pgx.Tx, uid uuid.UUID, budgetID *uuid.UUID, in BudgetInput) error {
	kinds := map[string]string{"financial_accounts": "account", "categories": "category", "merchants": "merchant"}
	check := func(table, field string, list []uuid.UUID) error {
		if len(list) == 0 {
			return nil
		}
		var n int
		var err error
		if budgetID != nil {
			err = tx.QueryRow(ctx, `select montra.budget_owner_ref_count($1, $2, $3)`, *budgetID, kinds[table], list).Scan(&n)
		} else {
			err = tx.QueryRow(ctx, `select count(*) from `+table+` where user_id = $1 and id = any($2)`, uid, list).Scan(&n)
		}
		if err != nil {
			return err
		}
		if n != len(dedupe(list)) {
			return apperr.FieldError("body."+field, "One or more referenced records were not found.")
		}
		return nil
	}
	var cats, mers, accts []uuid.UUID
	for _, a := range in.Allocations {
		if a.CategoryID != nil {
			cats = append(cats, *a.CategoryID)
		}
		if a.MerchantID != nil {
			mers = append(mers, *a.MerchantID)
		}
		if a.AccountID != nil {
			accts = append(accts, *a.AccountID)
		}
		n := 0
		for _, p := range []*uuid.UUID{a.CategoryID, a.MerchantID, a.AccountID, a.MemberUserID} {
			if p != nil {
				n++
			}
		}
		if n > 1 {
			return apperr.FieldError("body.allocations", "Each allocation targets one category, merchant, account or member.")
		}
	}
	for _, c := range []struct {
		t, f string
		l    []uuid.UUID
	}{{"financial_accounts", "included_account_ids", in.IncludedAccountIDs}, {"categories", "excluded_category_ids", in.ExcludedCategoryIDs},
		{"merchants", "merchant_ids", in.MerchantIDs}, {"categories", "allocations", cats}, {"merchants", "allocations", mers},
		{"financial_accounts", "allocations", accts}} {
		if err := check(c.t, c.f, c.l); err != nil {
			return err
		}
	}
	return nil
}

// validateShape rejects settings this kind of budget would silently
// ignore. Group budgets count all of the group's expenses (in the group
// currency) and can be split between members; personal budgets filter the
// owner's own transactions.
func validateShape(ctx context.Context, tx pgx.Tx, in BudgetInput) error {
	if in.GroupID != nil {
		switch in.BudgetType {
		case "total", "envelope", "zero_based":
		default:
			return apperr.Rule("group_budget_type_unsupported",
				"Group budgets track all of the group's expenses: use a total budget, or split it between members.",
				map[string]string{"budget_type": in.BudgetType})
		}
		for _, f := range []struct {
			name string
			ids  []uuid.UUID
		}{{"included_account_ids", in.IncludedAccountIDs}, {"excluded_category_ids", in.ExcludedCategoryIDs}, {"merchant_ids", in.MerchantIDs}} {
			if len(f.ids) > 0 {
				return apperr.Rule("group_budget_filter_unsupported",
					"Group budgets count all of the group's expenses; account, category and merchant filters do not apply.",
					map[string]string{"field": f.name})
			}
		}
		for i, a := range in.Allocations {
			if a.MemberUserID == nil {
				return apperr.Rule("group_budget_allocation_unsupported",
					"Group budgets are split between members, not categories, merchants or accounts.",
					map[string]string{"index": strconv.Itoa(i)})
			}
			var member bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from group_members where group_id = $1 and user_id = $2 and status = 'active')`,
				*in.GroupID, *a.MemberUserID).Scan(&member); err != nil {
				return err
			}
			if !member {
				return apperr.FieldError(fmt.Sprintf("body.allocations[%d].member_user_id", i), "Choose a member of this group.")
			}
		}
		return nil
	}
	var merchantAllocs, accountAllocs bool
	for i, a := range in.Allocations {
		if a.MemberUserID != nil {
			return apperr.FieldError(fmt.Sprintf("body.allocations[%d].member_user_id", i), "Member allocations are for group budgets.")
		}
		merchantAllocs = merchantAllocs || a.MerchantID != nil
		accountAllocs = accountAllocs || a.AccountID != nil
	}
	switch {
	case in.BudgetType == "merchant" && len(in.MerchantIDs) == 0:
		return apperr.FieldError("body.merchant_ids", "Choose the merchants this budget tracks.")
	case in.BudgetType != "merchant" && (len(in.MerchantIDs) > 0 || merchantAllocs):
		return apperr.FieldError("body.merchant_ids", "Merchant limits apply to merchant budgets.")
	case in.BudgetType == "account" && len(in.IncludedAccountIDs) == 0:
		return apperr.FieldError("body.included_account_ids", "Choose the accounts this budget tracks.")
	case in.BudgetType != "account" && accountAllocs:
		return apperr.FieldError("body.allocations", "Account limits apply to account budgets.")
	}
	return nil
}

func dedupe(v []uuid.UUID) []uuid.UUID {
	seen := map[uuid.UUID]bool{}
	var out []uuid.UUID
	for _, x := range v {
		if !seen[x] {
			seen[x] = true
			out = append(out, x)
		}
	}
	return out
}

// addMember adds a collaborator who is a connection or group co-member
// (privacy: arbitrary users cannot be added).
// field is the request location of the member ("body." for the member
// endpoints, "body.members[i]." inside a budget).
func (s *Service) addMember(ctx context.Context, tx pgx.Tx, uid, budgetID uuid.UUID, cur string, m MemberInput, field string) error {
	if m.UserID == uid {
		return apperr.FieldError(field+"user_id", "You already own this budget.")
	}
	var ok bool
	if err := tx.QueryRow(ctx, `select montra.are_connected($1, $2) or montra.share_active_group($1, $2)`, uid, m.UserID).Scan(&ok); err != nil {
		return err
	}
	if !ok {
		return apperr.FieldError(field+"user_id", "You can only share budgets with friends or group members.")
	}
	var alloc *int64
	if m.Allocation != "" {
		v, err := finance.ParseAmount(field+"allocation", m.Allocation, cur)
		if err != nil {
			return err
		}
		alloc = &v
	}
	_, err := tx.Exec(ctx, `insert into budget_members (budget_id, user_id, role, allocation_minor) values ($1,$2,$3,$4)
		on conflict (budget_id, user_id) do update set role = excluded.role, allocation_minor = excluded.allocation_minor`, budgetID, m.UserID, m.Role, alloc)
	return err
}

// SetMember adds/updates a member (owner only, enforced by RLS policy).
func (s *Service) SetMember(ctx context.Context, budgetID uuid.UUID, m MemberInput) (*BudgetDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *BudgetDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var owner uuid.UUID
		var cur string
		if err := tx.QueryRow(ctx, `select owner_user_id, currency from budgets where id = $1`, budgetID).Scan(&owner, &cur); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("budget")
			}
			return err
		}
		if owner != uid {
			return apperr.Forbidden()
		}
		if err := s.addMember(ctx, tx, uid, budgetID, cur, m, "body."); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "budget", EntityID: &budgetID, Action: "member_set",
			Changes: map[string]any{"member": m.UserID, "role": m.Role}}); err != nil {
			return err
		}
		out, _, err = s.load(ctx, tx, budgetID, true)
		return err
	})
	return out, database.MapError(err)
}

// RemoveMember removes a collaborator (owner, or the member leaving).
func (s *Service) RemoveMember(ctx context.Context, budgetID, memberID uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var owner uuid.UUID
		if err := tx.QueryRow(ctx, `select owner_user_id from budgets where id = $1`, budgetID).Scan(&owner); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("budget")
			}
			return err
		}
		if owner != uid && memberID != uid {
			return apperr.Forbidden()
		}
		// Members leaving use system-level removal because RLS restricts writes to the owner.
		tag, err := tx.Exec(ctx, `delete from budget_members where budget_id = $1 and user_id = $2`, budgetID, memberID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("member")
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &owner, ActorUserID: &uid, EntityType: "budget", EntityID: &budgetID, Action: "member_removed"})
	}))
}

// statusActions maps lifecycle actions to the status they set and the
// statuses they apply to (archiving twice is a no-op).
var statusActions = map[string]struct {
	to   string
	from []string
}{
	"pause":   {"paused", []string{"active"}},
	"resume":  {"active", []string{"paused"}},
	"restore": {"active", []string{"archived"}},
	"archive": {"archived", []string{"active", "paused", "archived"}},
}

// SetStatus pauses, resumes, archives or restores a budget (owner or
// editor). Invalid transitions (pausing an archived budget) are refused
// with invalid_status_transition.
//
// version, when not 0, must match the budget's current version.
func (s *Service) SetStatus(ctx context.Context, id uuid.UUID, action string, version int32) (*BudgetDTO, error) {
	a, ok := statusActions[action]
	if !ok {
		return nil, apperr.BadRequest("Unknown action.")
	}
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *BudgetDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var status string
		var access *string
		var current int32
		if err := tx.QueryRow(ctx, `select status, montra.budget_access(id), version from budgets where id = $1`, id).Scan(&status, &access, &current); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("budget")
			}
			return err
		}
		switch {
		case access == nil:
			return apperr.NotFound("budget")
		case *access != "owner" && *access != "editor":
			return apperr.Forbidden() // visible (viewer) but not editable
		case version != 0 && version != current:
			return apperr.VersionConflict()
		case !slices.Contains(a.from, status):
			return apperr.Rule("invalid_status_transition", "A budget cannot move from "+status+" to "+a.to+".",
				map[string]string{"from": status, "to": a.to})
		}
		if status != a.to {
			tag, err := tx.Exec(ctx, `update budgets set status = $2, archived_at = case when $2 = 'archived' then now() else null end,
				version = version + 1 where id = $1 and status = $3`, id, a.to, status)
			if err != nil {
				return err
			}
			if tag.RowsAffected() == 0 {
				return apperr.VersionConflict() // changed by a concurrent request
			}
			if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "budget", EntityID: &id, Action: a.to}); err != nil {
				return err
			}
		}
		out, _, err = s.load(ctx, tx, id, true)
		return err
	})
	return out, database.MapError(err)
}

// Transactions lists, newest first, exactly the personal transactions a
// budget counts in a period (the same selection as its total), a page at a
// time. Owner only: collaborators see totals, never the owner's private
// transactions.
func (s *Service) Transactions(ctx context.Context, fin *finance.Service, id uuid.UUID, date, cursor string, limit int) ([]finance.TransactionDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	var ids []uuid.UUID
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, b, err := s.load(ctx, tx, id, false)
		if err != nil {
			return err
		}
		if b.OwnerUserID != uid {
			return apperr.New(apperr.CodeForbidden, 403, "Only the budget owner can see the individual transactions; collaborators see totals.")
		}
		if b.GroupID != nil {
			return apperr.Rule("group_budget", "Group budgets track group expenses; open the group to see them.", nil)
		}
		at := s.now()
		if date != "" {
			if at, err = finance.ParseDate("query.date", date, b.loc); err != nil {
				return err
			}
		}
		r := b.periodFor(at)
		expense, refund, where, args := personalFilter(b, finance.LocalDateString(r.Start), finance.LocalDateString(r.End), nil)
		rows, err := tx.Query(ctx, `select t.id from transactions t where `+strings.Join(where, " and ")+
			` and t.currency = $4 and ((`+expense+`) <> 0 or (`+refund+`) <> 0)`, args...)
		if err != nil {
			return err
		}
		ids, err = pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		return err
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	if ids == nil {
		ids = []uuid.UUID{}
	}
	return fin.ListTransactions(ctx, finance.ListFilter{OnlyIDs: ids, Cursor: cursor, Limit: limit})
}

// BudgetPatch changes only the fields sent. A list sent replaces the whole
// list ([] clears it; for alert_thresholds [] means no threshold alerts).
type BudgetPatch struct {
	Name                *string        `json:"name,omitempty" minLength:"1" maxLength:"80"`
	BudgetType          *string        `json:"budget_type,omitempty" enum:"total,category,merchant,account,envelope,zero_based"`
	Period              *string        `json:"period,omitempty" enum:"weekly,monthly,annual,custom"`
	Currency            *string        `json:"currency,omitempty" pattern:"^[A-Z]{3}$"`
	Limit               *string        `json:"limit,omitempty"`
	Timezone            *string        `json:"timezone,omitempty" maxLength:"64"`
	StartsOn            *string        `json:"starts_on,omitempty"`
	EndsOn              *string        `json:"ends_on,omitempty" doc:"Empty string clears it (not for custom periods)"`
	RolloverPolicy      *string        `json:"rollover_policy,omitempty" enum:"none,carry_unused,carry_overspend,carry_both"`
	RolloverCap         *string        `json:"rollover_cap,omitempty" doc:"Empty string clears it"`
	IncludePending      *bool          `json:"include_pending,omitempty"`
	RefundsRestore      *bool          `json:"refunds_restore,omitempty"`
	CountGroupShares    *bool          `json:"count_group_shares,omitempty"`
	IncludedAccountIDs  *[]uuid.UUID   `json:"included_account_ids,omitempty" maxItems:"50"`
	ExcludedCategoryIDs *[]uuid.UUID   `json:"excluded_category_ids,omitempty" maxItems:"50"`
	MerchantIDs         *[]uuid.UUID   `json:"merchant_ids,omitempty" maxItems:"50"`
	AlertThresholds     *[]int16       `json:"alert_thresholds,omitempty" maxItems:"10" enum:"1,5,10,20,25,30,40,50,60,70,75,80,90,95,100,110,125,150" doc:"Replaces the list; [] turns threshold alerts off"`
	AlertForecast       *bool          `json:"alert_forecast,omitempty"`
	Visibility          *string        `json:"visibility,omitempty" enum:"private,members"`
	Notes               *string        `json:"notes,omitempty" maxLength:"1000" doc:"Empty string clears it"`
	Allocations         *[]AllocInput  `json:"allocations,omitempty" maxItems:"100"`
	GroupID             *uuid.UUID     `json:"group_id,omitempty" doc:"Accepted for compatibility; must match the budget's group (a budget cannot move between groups)"`
	Members             *[]MemberInput `json:"members,omitempty" maxItems:"20" doc:"Adds collaborators; change or remove them with the member endpoints"`
	Version             int32          `json:"version" minimum:"1" doc:"Current version (409 VERSION_CONFLICT when stale)"`
}

// Patch applies a partial update: the current budget is merged with the
// fields sent and saved through the same validation as a full update.
func (s *Service) Patch(ctx context.Context, id uuid.UUID, p BudgetPatch) (*BudgetDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var in BudgetInput
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		cur, _, err := s.load(ctx, tx, id, false)
		if err != nil {
			return err
		}
		if cur.Access != "owner" && cur.Access != "editor" {
			return apperr.Forbidden()
		}
		in = BudgetInput{Name: cur.Name, BudgetType: cur.BudgetType, Period: cur.Period, Currency: cur.Currency, Limit: cur.Limit.Amount,
			Timezone: cur.Timezone, StartsOn: cur.StartsOn, RolloverPolicy: cur.RolloverPolicy, IncludePending: cur.IncludePending,
			RefundsRestore: &cur.RefundsRestore, CountGroupShares: &cur.CountGroupShares, IncludedAccountIDs: cur.IncludedAccountIDs,
			ExcludedCategoryIDs: cur.ExcludedCategoryIDs, MerchantIDs: cur.MerchantIDs, AlertThresholds: cur.AlertThresholds,
			AlertForecast: &cur.AlertForecast, Visibility: cur.Visibility, GroupID: cur.GroupID}
		if in.AlertThresholds == nil {
			in.AlertThresholds = []int16{}
		}
		if cur.EndsOn != nil {
			in.EndsOn = *cur.EndsOn
		}
		if cur.Notes != nil {
			in.Notes = *cur.Notes
		}
		if cur.RolloverCap != nil {
			in.RolloverCap = cur.RolloverCap.Amount
		}
		for _, a := range cur.Allocations {
			label := ""
			if a.Label != nil {
				label = *a.Label
			}
			in.Allocations = append(in.Allocations, AllocInput{CategoryID: a.CategoryID, MerchantID: a.MerchantID, AccountID: a.AccountID,
				MemberUserID: a.MemberUserID, Label: label, Limit: a.Limit.Amount})
		}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	str := func(dst *string, v *string) {
		if v != nil {
			*dst = *v
		}
	}
	str(&in.Name, p.Name)
	str(&in.BudgetType, p.BudgetType)
	str(&in.Period, p.Period)
	str(&in.Currency, p.Currency)
	str(&in.Limit, p.Limit)
	str(&in.Timezone, p.Timezone)
	str(&in.StartsOn, p.StartsOn)
	str(&in.EndsOn, p.EndsOn)
	str(&in.RolloverPolicy, p.RolloverPolicy)
	str(&in.RolloverCap, p.RolloverCap)
	str(&in.Visibility, p.Visibility)
	str(&in.Notes, p.Notes)
	if p.IncludePending != nil {
		in.IncludePending = *p.IncludePending
	}
	if p.RefundsRestore != nil {
		in.RefundsRestore = p.RefundsRestore
	}
	if p.CountGroupShares != nil {
		in.CountGroupShares = p.CountGroupShares
	}
	if p.AlertForecast != nil {
		in.AlertForecast = p.AlertForecast
	}
	if p.IncludedAccountIDs != nil {
		in.IncludedAccountIDs = *p.IncludedAccountIDs
	}
	if p.ExcludedCategoryIDs != nil {
		in.ExcludedCategoryIDs = *p.ExcludedCategoryIDs
	}
	if p.MerchantIDs != nil {
		in.MerchantIDs = *p.MerchantIDs
	}
	if p.AlertThresholds != nil {
		in.AlertThresholds = *p.AlertThresholds
		if in.AlertThresholds == nil {
			in.AlertThresholds = []int16{}
		}
	}
	if p.Allocations != nil {
		in.Allocations = *p.Allocations
	}
	if p.GroupID != nil && (in.GroupID == nil || *p.GroupID != *in.GroupID) {
		return nil, apperr.FieldError("body.group_id", "A budget cannot move to another group.")
	}
	if p.Members != nil {
		in.Members = *p.Members
	}
	in.Version = p.Version
	return s.Save(ctx, &id, in)
}
