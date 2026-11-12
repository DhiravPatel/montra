package analytics

import (
	"context"
	"net/http"
	"sort"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
)

// CompareInput selects two periods to compare (spec §4.13 "compare
// user-selected periods"). Filters apply to both periods.
type CompareInput struct {
	Filter
	CompareFrom string `query:"compare_from" doc:"YYYY-MM-DD start of the comparison period"`
	CompareTo   string `query:"compare_to" doc:"YYYY-MM-DD end of the comparison period"`
}

// CategoryDelta compares one category's net spending.
type CategoryDelta struct {
	CategoryID *uuid.UUID     `json:"category_id,omitempty" doc:"Absent for uncategorized"`
	Name       string         `json:"name"`
	SystemKey  *string        `json:"system_key,omitempty"`
	Current    apitypes.Money `json:"current"`
	Comparison apitypes.Money `json:"comparison"`
	Change     apitypes.Money `json:"change" doc:"current - comparison"`
	ChangeBP   *int64         `json:"change_bp,omitempty" doc:"Change as basis points of the comparison amount's magnitude (positive = increase, also from a negative base); absent when the comparison amount is zero"`
}

// MetricChange is how one total changed between the two periods.
type MetricChange struct {
	Change   apitypes.Money `json:"change" doc:"current - comparison"`
	ChangeBP *int64         `json:"change_bp,omitempty" doc:"Change as basis points of the comparison amount's magnitude (positive = increase, also from a negative base); absent when the comparison amount is zero"`
}

// TotalsChange is the per-metric change of one currency's cash-flow totals
// (current - comparison, the same rules as category changes).
type TotalsChange struct {
	Income           MetricChange `json:"income"`
	GrossExpense     MetricChange `json:"gross_expense"`
	Refunds          MetricChange `json:"refunds"`
	NetExpense       MetricChange `json:"net_expense"`
	NetCashFlow      MetricChange `json:"net_cash_flow"`
	TransactionCount int64        `json:"transaction_count" doc:"current - comparison"`
}

// CurrencyComparison compares the two periods in one currency.
type CurrencyComparison struct {
	Currency   string          `json:"currency"`
	Current    CashFlowTotals  `json:"current"`
	Comparison CashFlowTotals  `json:"comparison"`
	Change     TotalsChange    `json:"change" doc:"Change of each total between the periods, in this currency only"`
	Categories []CategoryDelta `json:"categories" doc:"Largest changes first"`
}

// Comparison is the /analytics/compare payload.
type Comparison struct {
	Window           Window               `json:"window"`
	ComparisonWindow Window               `json:"comparison_window"`
	Currencies       []CurrencyComparison `json:"currencies" doc:"Currencies are never added together"`
	Notes            []string             `json:"notes" doc:"How the periods are compared (English; localize by note_codes)"`
	NoteCodes        []string             `json:"note_codes" enum:"same_filters_and_rules,compared_as_totals,currencies_separate" doc:"Stable codes for notes, same order"`
}

var compareNotes = []string{
	"Both periods use the same filters and rules: transfers excluded, refunds reduce spending.",
	"Different period lengths are compared as totals, not per day.",
	"Amounts in different currencies are compared separately and never added together.",
}

var compareNoteCodes = []string{"same_filters_and_rules", "compared_as_totals", "currencies_separate"}

// changeOf returns current - comparison in cur, and the change in basis
// points of the comparison's magnitude (nil when the comparison is zero),
// so the sign always says up or down, even from a negative base such as a
// net cash flow below zero.
func changeOf(current, comparison int64, cur string) (MetricChange, error) {
	change, err := money.Sub(current, comparison)
	if err != nil {
		return MetricChange{}, err
	}
	out := MetricChange{Change: apitypes.M(change, cur)}
	if comparison != 0 {
		bp := money.PercentBasisPoints(change, abs64(comparison))
		out.ChangeBP = &bp
	}
	return out, nil
}

// totalsChange compares two periods' totals of one currency.
func totalsChange(cur string, a, b CashFlowTotals) (TotalsChange, error) {
	out := TotalsChange{TransactionCount: a.TransactionCount - b.TransactionCount}
	for _, m := range []struct {
		dst        *MetricChange
		curr, comp apitypes.Money
	}{
		{&out.Income, a.Income, b.Income}, {&out.GrossExpense, a.GrossExpense, b.GrossExpense}, {&out.Refunds, a.Refunds, b.Refunds},
		{&out.NetExpense, a.NetExpense, b.NetExpense}, {&out.NetCashFlow, a.NetCashFlow, b.NetCashFlow},
	} {
		c, err := changeOf(m.curr.AmountMinor, m.comp.AmountMinor, cur)
		if err != nil {
			return TotalsChange{}, err
		}
		*m.dst = c
	}
	return out, nil
}

// Compare contrasts two periods with the same filters.
func (s *Service) Compare(ctx context.Context, in CompareInput) (*Comparison, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if in.CompareFrom == "" || in.CompareTo == "" {
		return nil, apperr.FieldError("query.compare_from", "Choose the period to compare with.")
	}
	other := in.Filter
	other.Range, other.From, other.To = "", in.CompareFrom, in.CompareTo
	out := &Comparison{Currencies: []CurrencyComparison{}, Notes: compareNotes, NoteCodes: compareNoteCodes}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		a, err := s.newScope(ctx, tx, uid, in.Filter)
		if err != nil {
			return err
		}
		b, err := s.newScope(ctx, tx, uid, other)
		if err != nil {
			return err
		}
		out.Window, out.ComparisonWindow = a.window, b.window
		ta, err := s.cashFlow(ctx, tx, a)
		if err != nil {
			return err
		}
		tb, err := s.cashFlow(ctx, tx, b)
		if err != nil {
			return err
		}
		ca, err := s.categories(ctx, tx, a, true, 200, KindExpense)
		if err != nil {
			return err
		}
		cb, err := s.categories(ctx, tx, b, true, 200, KindExpense)
		if err != nil {
			return err
		}
		byCur := map[string]*CurrencyComparison{}
		get := func(cur string) *CurrencyComparison {
			c := byCur[cur]
			if c == nil {
				c = &CurrencyComparison{Currency: cur, Current: totalsFrom(cur, 0, 0, 0, 0), Comparison: totalsFrom(cur, 0, 0, 0, 0)}
				byCur[cur] = c
			}
			return c
		}
		for _, t := range ta {
			get(t.Currency).Current = t
		}
		for _, t := range tb {
			get(t.Currency).Comparison = t
		}
		type key struct {
			cur string
			id  string
		}
		deltas := map[key]*CategoryDelta{}
		add := func(sl CategorySlice, current bool) {
			id := ""
			if sl.CategoryID != nil {
				id = sl.CategoryID.String()
			}
			k := key{sl.Currency, id}
			d := deltas[k]
			if d == nil {
				d = &CategoryDelta{CategoryID: sl.CategoryID, Name: sl.Name, SystemKey: sl.SystemKey,
					Current: apitypes.M(0, sl.Currency), Comparison: apitypes.M(0, sl.Currency)}
				deltas[k] = d
				get(sl.Currency)
			}
			if current {
				d.Current = sl.NetExpense
			} else {
				d.Comparison = sl.NetExpense
			}
		}
		for _, sl := range ca {
			add(sl, true)
		}
		for _, sl := range cb {
			add(sl, false)
		}
		for k, d := range deltas {
			mc, err := changeOf(d.Current.AmountMinor, d.Comparison.AmountMinor, k.cur)
			if err != nil {
				return err
			}
			d.Change, d.ChangeBP = mc.Change, mc.ChangeBP
			c := get(k.cur)
			c.Categories = append(c.Categories, *d)
		}
		curs := make([]string, 0, len(byCur))
		for cur := range byCur {
			curs = append(curs, cur)
		}
		sort.Strings(curs)
		for _, cur := range curs {
			c := byCur[cur]
			if c.Change, err = totalsChange(cur, c.Current, c.Comparison); err != nil {
				return err
			}
			if c.Categories == nil {
				c.Categories = []CategoryDelta{}
			}
			sort.SliceStable(c.Categories, func(i, j int) bool {
				ai, aj := abs64(c.Categories[i].Change.AmountMinor), abs64(c.Categories[j].Change.AmountMinor)
				if ai != aj {
					return ai > aj
				}
				return c.Categories[i].Name < c.Categories[j].Name
			})
			out.Currencies = append(out.Currencies, *c)
		}
		return nil
	})
	return out, database.MapError(err)
}

func abs64(v int64) int64 {
	if v < 0 {
		return -v
	}
	return v
}

// CompareRoutes mounts the comparison endpoint.
func (s *Service) CompareRoutes(api huma.API) {
	op := httpx.Op("analytics-compare", http.MethodGet, "/analytics/compare",
		"Compare income, spending and categories between two periods you choose", "Analytics")
	op.Description = "Per currency (never across currencies): both periods' totals, the change of each total (change = current - " +
		"comparison, change_bp relative to the comparison amount's magnitude) and category changes, largest first. notes are English; " +
		"localize by note_codes."
	httpx.Protected(api, op,
		func(ctx context.Context, in *CompareInput) (*httpx.Response[Comparison], error) {
			c, err := s.Compare(ctx, *in)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
}
