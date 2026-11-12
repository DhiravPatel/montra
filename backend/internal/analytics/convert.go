package analytics

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/fx"
	"montra/backend/internal/platform/apperr"
)

// ConvertedTotals expresses per-currency totals in one display currency.
// Unlike currencies are only combined through disclosed rates (spec §4.11).
type ConvertedTotals struct {
	Currency     string         `json:"currency"`
	Income       apitypes.Money `json:"income"`
	GrossExpense apitypes.Money `json:"gross_expense"`
	Refunds      apitypes.Money `json:"refunds"`
	NetExpense   apitypes.Money `json:"net_expense"`
	NetCashFlow  apitypes.Money `json:"net_cash_flow"`
	Rates        []fx.Rate      `json:"rates" doc:"Rates used (source and timestamp disclosed)"`
	Unconverted  []string       `json:"unconverted" doc:"Currencies left out because no rate was available"`
	RatePolicy   string         `json:"rate_policy" doc:"Which rates were used (English; localize by rate_policy_code and rate_policy_params)"`
	// The rate policy as data, so clients can show it in the user's language.
	RatePolicyCode   string            `json:"rate_policy_code" enum:"latest_on_or_before" doc:"latest_on_or_before: the latest rate on or before the end of params.date in your time zone; your manual rates first, then provider rates, then the inverse pair"`
	RatePolicyParams map[string]string `json:"rate_policy_params" doc:"Values the code refers to: date (YYYY-MM-DD, the last day of the window)"`
}

// Rate policy codes.
const ratePolicyLatestOnOrBefore = "latest_on_or_before"

// convertTotals converts cash-flow totals into display at the window end.
// Components are converted separately (each rounded half away from zero)
// and the net figures are derived from the converted components, so the
// converted report stays internally consistent.
func convertTotals(ctx context.Context, tx pgx.Tx, sc *scope, totals []CashFlowTotals, display string) (*ConvertedTotals, error) {
	if !currency.Valid(display) {
		return nil, apperr.FieldError("query.display_currency", "Unsupported currency.")
	}
	end, err := time.ParseInLocation(time.DateOnly, sc.window.To, sc.u.Loc)
	if err != nil {
		return nil, err
	}
	at := fx.EndOfDay(end)
	out := &ConvertedTotals{Currency: display, Rates: []fx.Rate{}, Unconverted: []string{},
		RatePolicy:       "Latest rate on or before " + sc.window.To + " (your manual rates first, then provider rates)",
		RatePolicyCode:   ratePolicyLatestOnOrBefore,
		RatePolicyParams: map[string]string{"date": sc.window.To}}
	var inc, exp, ref int64
	for _, t := range totals {
		conv := func(v int64) (int64, error) { return v, nil }
		if t.Currency != display {
			r, ok, err := fx.Lookup(ctx, tx, sc.uid, t.Currency, display, at)
			if err != nil {
				return nil, err
			}
			if !ok {
				out.Unconverted = append(out.Unconverted, t.Currency)
				continue
			}
			out.Rates = append(out.Rates, *r)
			conv = func(v int64) (int64, error) {
				c, err := money.Convert(v, t.Currency, display, r.Value())
				return c.ToMinor, err
			}
		}
		ci, err := conv(t.Income.AmountMinor)
		if err != nil {
			return nil, err
		}
		ce, err := conv(t.GrossExpense.AmountMinor)
		if err != nil {
			return nil, err
		}
		cr, err := conv(t.Refunds.AmountMinor)
		if err != nil {
			return nil, err
		}
		if inc, err = money.Add(inc, ci); err != nil {
			return nil, err
		}
		if exp, err = money.Add(exp, ce); err != nil {
			return nil, err
		}
		if ref, err = money.Add(ref, cr); err != nil {
			return nil, err
		}
	}
	net := exp - ref
	out.Income, out.GrossExpense, out.Refunds = apitypes.M(inc, display), apitypes.M(exp, display), apitypes.M(ref, display)
	out.NetExpense, out.NetCashFlow = apitypes.M(net, display), apitypes.M(inc-net, display)
	return out, nil
}
