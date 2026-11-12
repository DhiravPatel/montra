package analytics

import (
	"context"
	"encoding/json"
	"net/http"
	"sort"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
)

// Widget keys in default order. budgets, upcoming (bills, recurring and
// renewals), goals and group_balances read GET /dashboard/planning.
var widgetRegistry = []string{"balances", "cash_flow", "budgets", "upcoming", "income_vs_expense", "cash_flow_trend",
	"category_breakdown", "top_merchants", "goals", "group_balances", "recent_transactions", "data_coverage"}

// RegisterWidget adds a widget key (called by feature modules at startup).
func RegisterWidget(key string) {
	for _, k := range widgetRegistry {
		if k == key {
			return
		}
	}
	widgetRegistry = append(widgetRegistry, key)
}

// DashboardSummary is the computed dashboard (never a stored source of truth).
type DashboardSummary struct {
	Window           Window                   `json:"window"`
	Balances         []BalanceTotals          `json:"balances" doc:"Tracked balances of overview accounts, per currency"`
	CashFlow         []CashFlowTotals         `json:"cash_flow"`
	PreviousCashFlow []CashFlowTotals         `json:"previous_cash_flow"`
	Trend            []SeriesPoint            `json:"trend" doc:"Zero-filled buckets for each currency with activity"`
	TrendBy          string                   `json:"trend_granularity" enum:"day,week,month,year" doc:"Bucket size of trend (weeks start Monday)"`
	TopCategories    []CategorySlice          `json:"top_categories" doc:"Largest net spending first, up to 8 per currency"`
	TopMerchants     []MerchantSlice          `json:"top_merchants" doc:"Largest net spending first, up to 5 per currency"`
	Recent           []finance.TransactionDTO `json:"recent_transactions"`
	Coverage         Coverage                 `json:"coverage"`
	GeneratedAt      time.Time                `json:"generated_at"`
	Notes            []string                 `json:"notes" doc:"How figures are calculated (English; localize by note_codes)"`
	NoteCodes        []string                 `json:"note_codes" enum:"excludes_transfers_adjustments,refunds_reduce_spending,currencies_separate,balances_tracked_not_verified" doc:"Stable codes for notes, same order"`
}

var dashboardNotes = []string{
	"Transfers between your accounts, balance adjustments and opening balances are excluded from income and spending.",
	"Refunds and reimbursements reduce spending; group expenses count only your share.",
	"Amounts in different currencies are shown separately and never added together.",
	"Balances are tracked from your entries and imports; they are not verified by a bank.",
}

var dashboardNoteCodes = []string{"excludes_transfers_adjustments", "refunds_reduce_spending", "currencies_separate", "balances_tracked_not_verified"}

// Summary computes the dashboard for a window.
func (s *Service) Summary(ctx context.Context, f Filter, fin *finance.Service) (*DashboardSummary, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := DashboardSummary{GeneratedAt: s.now().UTC(), Notes: dashboardNotes, NoteCodes: dashboardNoteCodes}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		f.OverviewOnly = true
		sc, err := s.newScope(ctx, tx, uid, f)
		if err != nil {
			return err
		}
		out.Window = sc.window
		if out.Balances, err = s.balances(ctx, tx, uid, true); err != nil {
			return err
		}
		if out.CashFlow, err = s.cashFlow(ctx, tx, sc); err != nil {
			return err
		}
		if out.Trend, err = s.series(ctx, tx, sc, ""); err != nil {
			return err
		}
		out.TrendBy = seriesGranularity(sc, "")
		if out.TopCategories, err = s.categories(ctx, tx, sc, true, 8, KindExpense); err != nil {
			return err
		}
		if out.TopMerchants, err = s.merchants(ctx, tx, sc, 5); err != nil {
			return err
		}
		cov, err := s.coverage(ctx, tx, sc)
		if err != nil {
			return err
		}
		out.Coverage = *cov
		prev := f
		p := sc.r.Previous()
		prev.Range, prev.From, prev.To = "", finance.LocalDateString(p.Start), finance.LocalDateString(p.End)
		psc, err := s.newScope(ctx, tx, uid, prev)
		if err != nil {
			return err
		}
		out.PreviousCashFlow, err = s.cashFlow(ctx, tx, psc)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	recent, _, err := fin.ListTransactions(ctx, finance.ListFilter{Limit: 8})
	if err != nil {
		return nil, err
	}
	out.Recent = recent
	return &out, nil
}

// WidgetDTO is one dashboard widget's layout.
type WidgetDTO struct {
	Key      string          `json:"key" enum:"balances,cash_flow,budgets,upcoming,income_vs_expense,cash_flow_trend,category_breakdown,top_merchants,goals,group_balances,recent_transactions,data_coverage" doc:"New widgets may be added; clients skip keys they do not know"`
	Position int16           `json:"position"`
	Visible  bool            `json:"visible"`
	Settings json.RawMessage `json:"settings" doc:"Widget-specific settings (e.g. default range)"`
}

// Widgets returns the layout merged with defaults (new widgets appear at
// the end, visible).
func (s *Service) Widgets(ctx context.Context) ([]WidgetDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	saved := map[string]WidgetDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select widget_key, position, visible, settings from dashboard_widgets where user_id = $1`, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var w WidgetDTO
			if err := rows.Scan(&w.Key, &w.Position, &w.Visible, &w.Settings); err != nil {
				return err
			}
			saved[w.Key] = w
		}
		return rows.Err()
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	out := make([]WidgetDTO, 0, len(widgetRegistry))
	next := int16(len(saved))
	for i, k := range widgetRegistry {
		if w, ok := saved[k]; ok {
			out = append(out, w)
			continue
		}
		pos := int16(i)
		if len(saved) > 0 {
			pos = next
			next++
		}
		out = append(out, WidgetDTO{Key: k, Position: pos, Visible: true, Settings: json.RawMessage(`{}`)})
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].Position < out[j].Position })
	return out, nil
}

// WidgetsPatch reorders/hides widgets or resets the layout.
type WidgetsPatch struct {
	Reset   bool `json:"reset,omitempty" doc:"Restore the default layout"`
	Widgets []struct {
		Key      string          `json:"key" pattern:"^[a-z_]{2,40}$"`
		Position int16           `json:"position" minimum:"0" maximum:"100"`
		Visible  bool            `json:"visible"`
		Settings json.RawMessage `json:"settings,omitempty"`
	} `json:"widgets,omitempty" maxItems:"50"`
}

// UpdateWidgets persists the layout (never touches finance records).
func (s *Service) UpdateWidgets(ctx context.Context, p WidgetsPatch) ([]WidgetDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	known := map[string]bool{}
	for _, k := range widgetRegistry {
		known[k] = true
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if p.Reset {
			_, err := tx.Exec(ctx, `delete from dashboard_widgets where user_id = $1`, uid)
			return err
		}
		for _, w := range p.Widgets {
			if !known[w.Key] {
				return apperr.FieldError("body.widgets", "Unknown widget: "+w.Key)
			}
			settings := w.Settings
			if len(settings) == 0 {
				settings = json.RawMessage(`{}`)
			}
			if len(settings) > 2048 || !json.Valid(settings) {
				return apperr.FieldError("body.widgets", "Widget settings must be a small JSON object.")
			}
			if _, err := tx.Exec(ctx, `insert into dashboard_widgets (user_id, widget_key, position, visible, settings, updated_at)
				values ($1,$2,$3,$4,$5,now()) on conflict (user_id, widget_key)
				do update set position = excluded.position, visible = excluded.visible, settings = excluded.settings, updated_at = now()`,
				uid, w.Key, w.Position, w.Visible, settings); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.Widgets(ctx)
}

// Routes mounts analytics and dashboard endpoints.
func (s *Service) Routes(api huma.API, fin *finance.Service) {
	const dt = "Dashboard"
	httpx.Protected(api, httpx.Op("dashboard-summary", http.MethodGet, "/dashboard/summary", "Computed dashboard for a date range", dt),
		func(ctx context.Context, in *Filter) (*httpx.Response[DashboardSummary], error) {
			d, err := s.Summary(ctx, *in, fin)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, httpx.Op("dashboard-widgets-get", http.MethodGet, "/dashboard/widgets", "Dashboard widget layout", dt),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]WidgetDTO], error) {
			w, err := s.Widgets(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, w), nil
		})
	httpx.Protected(api, httpx.Op("dashboard-widgets-update", http.MethodPatch, "/dashboard/widgets", "Reorder, hide or reset widgets", dt),
		func(ctx context.Context, in *struct{ Body WidgetsPatch }) (*httpx.Response[[]WidgetDTO], error) {
			w, err := s.UpdateWidgets(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, w), nil
		})

	const an = "Analytics"
	httpx.Protected(api, httpx.Op("analytics-cash-flow", http.MethodGet, "/analytics/cash-flow", "Income, spending and net cash flow with comparison", an),
		func(ctx context.Context, in *struct {
			Filter
			Granularity string `query:"granularity" enum:"day,week,month,year,"`
		}) (*httpx.Response[CashFlowReport], error) {
			r, err := s.CashFlow(ctx, in.Filter, in.Granularity)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	for _, kind := range []string{"income", "expenses"} {
		kind := kind
		httpx.Protected(api, httpx.Op("analytics-"+kind, http.MethodGet, "/analytics/"+kind, "Series of "+kind+" (same model as cash flow)", an),
			func(ctx context.Context, in *struct {
				Filter
				Granularity string `query:"granularity" enum:"day,week,month,year,"`
			}) (*httpx.Response[CashFlowReport], error) {
				f := in.Filter
				if kind == "income" {
					f.Types = IncomeTypes()
				} else {
					f.Types = ExpenseTypes()
				}
				r, err := s.CashFlow(ctx, f, in.Granularity)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *r), nil
			})
	}
	categoriesOp := httpx.Op("analytics-categories", http.MethodGet, "/analytics/categories", "Spending or income by category", an)
	categoriesOp.Description = "kind=expense (default) is net spending per category with the /analytics/expenses types (expense, group expense " +
		"share, refunds and reimbursements reducing it); kind=income is income per category with the /analytics/income types. Each " +
		"currency is ranked separately (up to 100 categories per currency); amounts in different currencies are never added together."
	httpx.Protected(api, categoriesOp,
		func(ctx context.Context, in *struct {
			Filter
			Subcategories bool   `query:"subcategories" doc:"Do not roll subcategories up to parents"`
			Kind          string `query:"kind" enum:"expense,income" default:"expense" doc:"expense: net spending per category; income: income per category"`
		}) (*httpx.Response[CategoryReport], error) {
			r, err := s.CategoryBreakdown(ctx, in.Filter, CategoryOptions{Rollup: !in.Subcategories, Kind: in.Kind})
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	merchantsOp := httpx.Op("analytics-merchants", http.MethodGet, "/analytics/merchants", "Top merchants by net spending, per currency", an)
	merchantsOp.Description = "Merchants are ranked by net spending separately in each currency and limit applies per currency, so a " +
		"currency with large nominal amounts never crowds out another. The list is grouped by currency (alphabetical), largest first."
	httpx.Protected(api, merchantsOp,
		func(ctx context.Context, in *struct {
			Filter
			Limit int `query:"limit" minimum:"1" maximum:"100" default:"10" doc:"Merchants per currency"`
		}) (*httpx.Response[MerchantReport], error) {
			r, err := s.Merchants(ctx, in.Filter, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("analytics-accounts", http.MethodGet, "/analytics/accounts", "Assets, liabilities and net worth per currency", an),
		func(ctx context.Context, in *struct {
			OverviewOnly bool `query:"overview_only"`
		}) (*httpx.Response[AccountsReport], error) {
			r, err := s.Accounts(ctx, in.OverviewOnly)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}
