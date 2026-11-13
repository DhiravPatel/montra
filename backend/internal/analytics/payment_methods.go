package analytics

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
)

// UnspecifiedPaymentMethod is the key and kind of the bucket for spending
// recorded without a payment method (ANL-002).
const UnspecifiedPaymentMethod = "unspecified"

// maxPaymentMethodsPerCurrency bounds the breakdown (people keep a short
// list of payment methods; the cap only guards the response size).
const maxPaymentMethodsPerCurrency = 100

// PaymentMethodSlice is net spending with one payment method in one
// currency, or the unspecified bucket.
type PaymentMethodSlice struct {
	PaymentMethodID *uuid.UUID     `json:"payment_method_id,omitempty" doc:"Absent for the unspecified bucket"`
	Key             string         `json:"key" doc:"The payment method ID, or unspecified for spending recorded without one"`
	Label           string         `json:"label" doc:"Your label for the payment method; Unspecified for the bucket (localize by key)"`
	Kind            string         `json:"kind" enum:"cash,upi,debit_card,credit_card,bank_transfer,wallet,cheque,other,unspecified"`
	Network         *string        `json:"network,omitempty"`
	MaskedHint      *string        `json:"masked_hint,omitempty" doc:"Last digits only, as stored on the payment method"`
	Archived        bool           `json:"archived" doc:"The payment method is archived (its past spending still counts)"`
	Currency        string         `json:"currency"`
	NetExpense      apitypes.Money `json:"net_expense" doc:"Spending net of refunds and reimbursements (the /analytics/expenses types), exact minor units"`
	Count           int64          `json:"count" doc:"Transactions counted"`
	ShareBP         int64          `json:"share_bp" doc:"Share of this currency's total net spending, in basis points; 0 when that total is not positive"`
	DrillDownPath   string         `json:"drill_down_path" doc:"App path to the underlying transactions"`
}

// PaymentMethodReport is the /analytics/payment-methods payload.
type PaymentMethodReport struct {
	Window         Window               `json:"window"`
	PaymentMethods []PaymentMethodSlice `json:"payment_methods" doc:"Grouped by currency (alphabetical), largest net spending first; each currency is ranked separately"`
}

// paymentMethods ranks net spending per payment method separately in each
// currency, with spending recorded without a payment method (or with one
// the caller cannot see) in the unspecified bucket. A refund or
// reimbursement without its own payment method reduces the payment method
// of the purchase it refunds. Slices whose net is zero are left out;
// share_bp is relative to the currency's full total.
func (s *Service) paymentMethods(ctx context.Context, tx pgx.Tx, sc *scope) ([]PaymentMethodSlice, error) {
	args, ph := sc.argsWith(ExpenseTypes(), maxPaymentMethodsPerCurrency)
	rows, err := tx.Query(ctx, `with base as (
		select pm.id as pmid, t.currency, sum(`+sqlExpense+` - `+sqlRefund+`)::bigint as amt, count(*) as n
		from transactions t join financial_accounts a on a.id = t.account_id
		left join transactions o on o.id = t.original_transaction_id and t.type in ('refund','reimbursement')
		left join payment_methods pm on pm.id = coalesce(t.payment_method_id, o.payment_method_id)
		where `+sc.clause()+` and t.type = any(`+ph[0]+`::text[]) group by 1, 2),
		ranked as (
		select b.pmid, pm.label, pm.kind, pm.network, pm.masked_hint, pm.archived_at is not null as archived, b.currency, b.amt, b.n,
		       sum(b.amt) over (partition by b.currency)::bigint as total,
		       row_number() over (partition by b.currency order by b.amt desc, b.pmid is null, pm.label, b.pmid) as rn
		from base b left join payment_methods pm on pm.id = b.pmid where b.amt <> 0)
		select pmid, label, kind, network, masked_hint, coalesce(archived, false), currency, amt, n, total from ranked
		where rn <= `+ph[1]+` order by currency, rn`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []PaymentMethodSlice{}
	for rows.Next() {
		var p PaymentMethodSlice
		var label, kind *string
		var amt, total int64
		if err := rows.Scan(&p.PaymentMethodID, &label, &kind, &p.Network, &p.MaskedHint, &p.Archived, &p.Currency, &amt, &p.Count, &total); err != nil {
			return nil, err
		}
		p.NetExpense = apitypes.M(amt, p.Currency)
		if total > 0 {
			p.ShareBP = money.PercentBasisPoints(amt, total)
		}
		path := "/transactions?from=" + sc.window.From + "&to=" + sc.window.To + "&currency=" + p.Currency + "&payment_method_id="
		if p.PaymentMethodID != nil && label != nil && kind != nil {
			p.Key, p.Label, p.Kind = p.PaymentMethodID.String(), *label, *kind
			path += p.PaymentMethodID.String()
		} else {
			p.PaymentMethodID = nil
			p.Key, p.Label, p.Kind = UnspecifiedPaymentMethod, "Unspecified", UnspecifiedPaymentMethod
			path += PaymentMethodNone
		}
		p.DrillDownPath = path + "&type=" + spendingTypes
		out = append(out, p)
	}
	return out, rows.Err()
}

// PaymentMethodNone is the transaction-list filter value for transactions
// without a payment method (GET /transactions?payment_method_id=none).
const PaymentMethodNone = "none"

// PaymentMethods returns net spending per payment method in each currency
// (ANL-002), with the same window, filters and classification as
// /analytics/merchants and /analytics/categories.
func (s *Service) PaymentMethods(ctx context.Context, f Filter) (*PaymentMethodReport, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out PaymentMethodReport
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		sc, err := s.newScope(ctx, tx, uid, f)
		if err != nil {
			return err
		}
		out.Window = sc.window
		out.PaymentMethods, err = s.paymentMethods(ctx, tx, sc)
		return err
	})
	return &out, database.MapError(err)
}

// paymentMethodRoutes mounts GET /analytics/payment-methods.
func (s *Service) paymentMethodRoutes(api huma.API, tag string) {
	op := httpx.Op("analytics-payment-methods", http.MethodGet, "/analytics/payment-methods", "Net spending by payment method, per currency", tag)
	op.Description = "Net spending (the /analytics/expenses types: expenses and your group expense shares, reduced by refunds and " +
		"reimbursements) per payment method, with the same range, from/to and filters as /analytics/categories. Spending recorded without " +
		"a payment method is the bucket with key and kind unspecified; a refund without its own payment method counts against the " +
		"payment method of the purchase it refunds. Each currency is ranked separately (up to 100 per currency); " +
		"amounts in different currencies are never added together. Archived payment methods keep their past spending."
	httpx.Protected(api, op,
		func(ctx context.Context, in *struct{ Filter }) (*httpx.Response[PaymentMethodReport], error) {
			r, err := s.PaymentMethods(ctx, in.Filter)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}
