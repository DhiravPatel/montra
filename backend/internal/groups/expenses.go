package groups

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/domain/split"
	"montra/backend/internal/finance"
	"montra/backend/internal/fx"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// EventExpenseChanged asks the worker to re-sync payers' personal records.
const EventExpenseChanged = "group_expense.changed"

// ExpenseParticipantInput is one participant and their split value.
type ExpenseParticipantInput struct {
	UserID uuid.UUID `json:"user_id"`
	Value  string    `json:"value,omitempty" doc:"exact: amount; percentage: percent such as 33.33; shares: positive integer weight; equal/itemized: unused"`
}

// ExpenseItemShareInput weights one participant on an item.
type ExpenseItemShareInput struct {
	UserID uuid.UUID `json:"user_id"`
	Weight int64     `json:"weight,omitempty" minimum:"1" maximum:"1000" doc:"Default 1"`
}

// ExpenseItemInput is a line of an itemized split.
type ExpenseItemInput struct {
	Description string                  `json:"description" minLength:"1" maxLength:"200"`
	Amount      string                  `json:"amount"`
	Quantity    string                  `json:"quantity,omitempty" pattern:"^[0-9]{1,9}(\\.[0-9]{1,3})?$"`
	SharedBy    []ExpenseItemShareInput `json:"shared_by" minItems:"1" maxItems:"100"`
}

// ExpensePayerInput is who paid how much.
type ExpensePayerInput struct {
	UserID uuid.UUID `json:"user_id"`
	Amount string    `json:"amount,omitempty" doc:"In the group currency. Required when there are several payers; a single payer may leave it out and is then the whole amount (also the derived amount of a foreign-currency expense)"`
}

// GroupExpenseInput creates or replaces a group expense.
type GroupExpenseInput struct {
	Description string `json:"description" minLength:"1" maxLength:"200"`
	Amount      string `json:"amount,omitempty" doc:"In the group currency. May be left out for a foreign-currency expense: it is then original_amount × fx_rate, rounded half away from zero to the group currency's minor unit (returned in amount). When sent with them it must equal that value"`
	ExpenseDate string `json:"expense_date,omitempty" doc:"YYYY-MM-DD, default today in the group time zone"`
	CategoryKey string `json:"category_key,omitempty" pattern:"^[a-z_]{2,40}$" doc:"Starter category key, e.g. food_dining"`
	SplitMethod string `json:"split_method,omitempty" enum:"equal,exact,percentage,shares,itemized" doc:"Default: the group's default"`
	// Participants, items and payers use the amount as entered or derived.
	Participants     []ExpenseParticipantInput `json:"participants" minItems:"1" maxItems:"100"`
	Items            []ExpenseItemInput        `json:"items,omitempty" maxItems:"200" doc:"itemized: lines; tax/tip/rounding (total − items) is shared in proportion"`
	Payers           []ExpensePayerInput       `json:"payers,omitempty" maxItems:"20" doc:"Default: you paid the whole amount"`
	PayerAccountID   *uuid.UUID                `json:"payer_account_id,omitempty" doc:"Record your payment in one of your accounts (only your share counts as your spending)"`
	OriginalAmount   string                    `json:"original_amount,omitempty" doc:"Amount actually paid in another currency (with original_currency and a rate)"`
	OriginalCurrency string                    `json:"original_currency,omitempty" pattern:"^[A-Z]{3}$"`
	FXRate           string                    `json:"fx_rate,omitempty" doc:"Group-currency units per original unit (exact decimal, up to 12 places)"`
	FXRateSource     string                    `json:"fx_rate_source,omitempty" enum:"manual,lookup,ecb,provider" doc:"Where fx_rate came from. manual (default): typed by you. lookup: Montra's rate for the expense date (your saved rates first, then provider rates, as GET /fx/convert?policy=historical&date=); fx_rate may then be left out, and when sent it must equal Montra's rate. ecb and provider (the stored values) are accepted as lookup. The expense stores the rate's real source. An edit that keeps the original amount, currency, rate and date keeps the stored source"`
	Notes            string                    `json:"notes,omitempty" maxLength:"2000"`
	ReceiptFileID    *uuid.UUID                `json:"receipt_file_id,omitempty" doc:"A group_attachment file uploaded to this group"`
	Version          int32                     `json:"version,omitempty" doc:"Required for updates"`
}

// ExpenseShareDTO is one participant's share.
type ExpenseShareDTO struct {
	UserID     uuid.UUID      `json:"user_id"`
	Share      apitypes.Money `json:"share"`
	InputValue *string        `json:"input_value,omitempty"`
}

// ExpensePayerDTO is one payer.
type ExpensePayerDTO struct {
	UserID uuid.UUID      `json:"user_id"`
	Paid   apitypes.Money `json:"paid"`
}

// ExpenseItemDTO is an itemized line.
type ExpenseItemDTO struct {
	Description string            `json:"description"`
	Amount      apitypes.Money    `json:"amount"`
	Quantity    *string           `json:"quantity,omitempty"`
	Shares      []ExpenseShareDTO `json:"shares"`
}

// GroupCommentDTO is an expense comment.
type GroupCommentDTO struct {
	ID        uuid.UUID  `json:"id"`
	AuthorID  *uuid.UUID `json:"author_id,omitempty"`
	Body      string     `json:"body"`
	CreatedAt time.Time  `json:"created_at"`
}

// GroupDisputeDTO is an open or resolved dispute.
type GroupDisputeDTO struct {
	ID         uuid.UUID  `json:"id"`
	RaisedBy   *uuid.UUID `json:"raised_by,omitempty"`
	Reason     string     `json:"reason"`
	Status     string     `json:"status" enum:"open,resolved,withdrawn"`
	Resolution *string    `json:"resolution,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
}

// GroupExpenseDTO is a group expense.
type GroupExpenseDTO struct {
	ID              uuid.UUID         `json:"id"`
	GroupID         uuid.UUID         `json:"group_id"`
	Description     string            `json:"description"`
	CategoryKey     *string           `json:"category_key,omitempty"`
	Amount          apitypes.Money    `json:"amount"`
	OriginalAmount  *apitypes.Money   `json:"original_amount,omitempty"`
	FXRate          *string           `json:"fx_rate,omitempty" doc:"Exact rate (group-currency units per original unit) without padding zeros"`
	FXRateSource    *string           `json:"fx_rate_source,omitempty" enum:"manual,ecb,provider" doc:"manual: typed by a member (or their saved rate); ecb / provider: Montra's rate for the expense date"`
	FXRateAt        *time.Time        `json:"fx_rate_at,omitempty" doc:"manual: when the rate was entered; ecb / provider: the rate's own time"`
	ExpenseDate     string            `json:"expense_date"`
	SplitMethod     string            `json:"split_method"`
	Payers          []ExpensePayerDTO `json:"payers"`
	Shares          []ExpenseShareDTO `json:"shares"`
	MyShare         apitypes.Money    `json:"my_share"`
	MyPaid          apitypes.Money    `json:"my_paid"`
	Status          string            `json:"status" enum:"active,disputed,deleted"`
	Notes           *string           `json:"notes,omitempty"`
	ReceiptFileID   *uuid.UUID        `json:"receipt_file_id,omitempty"`
	CreatedBy       *uuid.UUID        `json:"created_by,omitempty"`
	MyTransactionID *uuid.UUID        `json:"my_transaction_id,omitempty" doc:"Your own linked account record, if you paid and recorded it (other members' records are never shown)"`
	Version         int32             `json:"version"`
	CreatedAt       time.Time         `json:"created_at"`
}

// GroupExpenseDetail adds items, comments, disputes and revisions count.
type GroupExpenseDetail struct {
	GroupExpenseDTO
	Items     []ExpenseItemDTO  `json:"items"`
	Comments  []GroupCommentDTO `json:"comments"`
	Disputes  []GroupDisputeDTO `json:"disputes"`
	Revisions int               `json:"revisions" doc:"Edit history kept (original split inputs preserved)"`
}

type computed struct {
	amount     int64
	date       time.Time
	method     string
	payers     map[uuid.UUID]int64
	payerOrder []uuid.UUID
	shares     []int64
	inputs     []*string
	partIDs    []uuid.UUID
	items      []computedItem
	fx         *fxInput
	rawInput   []byte
}

// fxInput is a foreign-currency expense's resolved rate.
type fxInput struct {
	orig      int64
	cur       string
	rate      string     // exact, formatted
	source    string     // manual | ecb | provider
	at        *time.Time // the rate's own time (Montra's rates or a kept rate); nil: now
	converted int64      // original × rate in the group currency, half away from zero
}

// fxColumns are the group_expenses columns for the rate (all nil without one).
func (c *computed) fxColumns() (orig *int64, cur, rate, source *string, at *time.Time) {
	if c.fx == nil {
		return nil, nil, nil, nil, nil
	}
	return &c.fx.orig, &c.fx.cur, &c.fx.rate, &c.fx.source, c.fx.at
}

// storedFX is an expense's current rate: an edit that keeps the original
// amount, currency, rate and date keeps its provenance.
type storedFX struct {
	orig   *int64
	cur    *string
	rate   *string
	source *string
	at     *time.Time
	date   time.Time
}

// resolveFX checks a foreign-currency expense's original amount and rate
// (see GroupExpenseInput.FXRateSource) and converts the original amount
// exactly like money.Convert (half away from zero).
func resolveFX(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, in GroupExpenseInput, date time.Time, prev *storedFX) (*fxInput, error) {
	if in.OriginalAmount == "" && in.OriginalCurrency == "" {
		if in.FXRate != "" || in.FXRateSource != "" {
			return nil, apperr.FieldError("body.original_currency", "Give the original currency, amount and the rate you used.")
		}
		return nil, nil
	}
	if !currency.Valid(in.OriginalCurrency) || in.OriginalCurrency == g.BaseCurrency {
		return nil, apperr.FieldError("body.original_currency", "Give the currency you paid in (not "+g.BaseCurrency+"), the amount and the rate you used.")
	}
	oa, err := finance.ParseAmount("body.original_amount", in.OriginalAmount, in.OriginalCurrency)
	if err != nil {
		return nil, err
	}
	var rate *big.Rat
	if in.FXRate != "" {
		if rate, err = money.ParseRate(in.FXRate); err != nil {
			return nil, apperr.FieldError("body.fx_rate", "Enter a positive exact rate.")
		}
	}
	out := &fxInput{orig: oa, cur: in.OriginalCurrency, source: "manual"}
	src := in.FXRateSource
	lookup := src == "lookup" || src == "ecb" || src == "provider"
	if prev != nil && prev.orig != nil && *prev.orig == oa && prev.cur != nil && *prev.cur == in.OriginalCurrency && prev.rate != nil &&
		rate != nil && prev.date.Equal(date) && prev.source != nil && (src == "" || src == *prev.source || (lookup && *prev.source != "manual")) {
		if r, err := money.ParseRate(*prev.rate); err == nil && r.Cmp(rate) == 0 {
			out.source, out.at = *prev.source, prev.at // unchanged: keeps its provenance
			lookup = false
		}
	}
	switch {
	case lookup:
		loc, err := time.LoadLocation(g.Timezone)
		if err != nil {
			loc = time.UTC
		}
		at := fx.EndOfDay(time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, loc))
		r, ok, err := fx.Lookup(ctx, tx, uid, in.OriginalCurrency, g.BaseCurrency, at)
		if err != nil {
			return nil, err
		}
		if !ok {
			return nil, apperr.Rule("fx_rate_unavailable", "Montra has no "+in.OriginalCurrency+"→"+g.BaseCurrency+" rate for this date; enter the rate you used.",
				map[string]string{"from": in.OriginalCurrency, "to": g.BaseCurrency, "date": finance.LocalDateString(date)})
		}
		if rate != nil && rate.Cmp(r.Value()) != 0 {
			return nil, apperr.FieldError("body.fx_rate", "Montra's rate for the expense date is "+r.Rate+"; leave fx_rate out, or send fx_rate_source manual for your own rate.")
		}
		asOf := r.AsOf
		rate, out.source, out.at = r.Value(), r.Source, &asOf
	case rate == nil:
		return nil, apperr.FieldError("body.fx_rate", "Enter the rate you used, or set fx_rate_source to lookup to use Montra's rate.")
	}
	conv, err := money.Convert(oa, in.OriginalCurrency, g.BaseCurrency, rate)
	if err != nil {
		return nil, apperr.FieldError("body.original_amount", "The converted amount is out of range.")
	}
	if conv.ToMinor <= 0 {
		return nil, apperr.FieldCode("body.original_amount", "converted_too_small",
			"The converted amount is less than the smallest unit of "+g.BaseCurrency+".", map[string]string{"currency": g.BaseCurrency})
	}
	out.rate, out.converted = money.FormatRate(rate), conv.ToMinor
	return out, nil
}

// computedItem is an itemized line with per-participant weights (by
// participant position) and the item-level allocation.
type computedItem struct {
	desc    string
	amount  int64
	qty     *string
	weights []int64
	shares  []int64
}

// runIdem runs fn once per Idempotency-Key, binding the key to the group.
func runIdem[T any](ctx context.Context, tx pgx.Tx, uid uuid.UUID, key, op string, groupID uuid.UUID, in any, fn func() (T, error)) (T, bool, error) {
	return idempotency.Run(ctx, tx, uid, key, op, struct {
		Group uuid.UUID
		In    any
	}{groupID, in}, fn)
}

// compute validates an expense and derives exact allocations. prev is the
// stored rate when an expense is edited (nil when creating).
func (s *Service) compute(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, in GroupExpenseInput, prev *storedFX) (*computed, error) {
	c := &computed{method: in.SplitMethod, payers: map[uuid.UUID]int64{}}
	if c.method == "" {
		c.method = g.DefaultSplitMethod
	}
	loc, err := time.LoadLocation(g.Timezone)
	if err != nil {
		loc = time.UTC
	}
	c.date = time.Date(s.now().In(loc).Year(), s.now().In(loc).Month(), s.now().In(loc).Day(), 0, 0, 0, 0, time.UTC)
	if in.ExpenseDate != "" {
		d, err := finance.ParseDate("body.expense_date", in.ExpenseDate, loc)
		if err != nil {
			return nil, err
		}
		c.date = time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, time.UTC)
	}
	if c.fx, err = resolveFX(ctx, tx, uid, g, in, c.date, prev); err != nil {
		return nil, err
	}
	switch {
	case in.Amount != "":
		if c.amount, err = finance.ParseAmount("body.amount", in.Amount, g.BaseCurrency); err != nil {
			return nil, err
		}
		if c.fx != nil && c.fx.converted != c.amount {
			return nil, apperr.FieldError("body.fx_rate", "Original amount × rate is "+apitypes.M(c.fx.converted, g.BaseCurrency).Amount+" "+g.BaseCurrency+
				", not the amount sent; leave the amount out to use it.")
		}
	case c.fx != nil:
		c.amount = c.fx.converted
	default:
		return nil, apperr.FieldError("body.amount", "Enter the amount, or the original amount with its currency and rate.")
	}
	active := map[uuid.UUID]bool{}
	rows, err := tx.Query(ctx, `select user_id from group_members where group_id = $1 and status = 'active'`, g.ID)
	if err != nil {
		return nil, err
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return nil, err
	}
	for _, id := range ids {
		active[id] = true
	}
	seen := map[uuid.UUID]int{}
	for i, p := range in.Participants {
		if !active[p.UserID] {
			return nil, apperr.FieldError(fmt.Sprintf("body.participants[%d].user_id", i), "Participants must be active members.")
		}
		if _, dup := seen[p.UserID]; dup {
			return nil, apperr.FieldError(fmt.Sprintf("body.participants[%d].user_id", i), "Each participant can appear once.")
		}
		seen[p.UserID] = i
		c.partIDs = append(c.partIDs, p.UserID)
		v := strings.TrimSpace(p.Value)
		if v != "" {
			c.inputs = append(c.inputs, &v)
		} else {
			c.inputs = append(c.inputs, nil)
		}
	}
	n := len(c.partIDs)
	switch c.method {
	case "equal":
		c.shares, err = split.Equal(c.amount, n)
	case "exact":
		amts := make([]int64, n)
		for i, p := range in.Participants {
			if amts[i], err = money.Parse(strings.TrimSpace(p.Value), g.BaseCurrency, money.ParseOptions{AllowZero: true}); err != nil {
				return nil, apperr.FieldError(fmt.Sprintf("body.participants[%d].value", i), "Enter each person's amount in "+g.BaseCurrency+".")
			}
		}
		c.shares, err = split.Exact(c.amount, amts)
	case "percentage":
		bps := make([]int64, n)
		for i, p := range in.Participants {
			if bps[i], err = split.ParsePercent(strings.TrimSpace(p.Value)); err != nil {
				return nil, apperr.FieldError(fmt.Sprintf("body.participants[%d].value", i), "Enter a percentage with up to 2 decimals.")
			}
		}
		c.shares, err = split.ByPercentages(c.amount, bps)
	case "shares":
		ws := make([]int64, n)
		for i, p := range in.Participants {
			w, perr := strconv.ParseInt(strings.TrimSpace(p.Value), 10, 64)
			if perr != nil || w < 0 || w > 1_000_000 {
				return nil, apperr.FieldError(fmt.Sprintf("body.participants[%d].value", i), "Enter a whole-number share.")
			}
			ws[i] = w
		}
		c.shares, err = split.ByWeights(c.amount, ws)
	case "itemized":
		if len(in.Items) == 0 {
			return nil, apperr.FieldError("body.items", "Add the items for an itemized split.")
		}
		items := make([]split.Item, len(in.Items))
		var itemSum int64
		for i, it := range in.Items {
			a, perr := money.Parse(it.Amount, g.BaseCurrency, money.ParseOptions{AllowZero: true})
			if perr != nil {
				return nil, apperr.FieldError(fmt.Sprintf("body.items[%d].amount", i), "Enter the item amount in "+g.BaseCurrency+".")
			}
			if itemSum, err = money.Add(itemSum, a); err != nil {
				return nil, err
			}
			w := make([]int64, n)
			for _, sb := range it.SharedBy {
				pos, ok := seen[sb.UserID]
				if !ok {
					return nil, apperr.FieldError(fmt.Sprintf("body.items[%d].shared_by", i), "Item shares must use listed participants.")
				}
				if w[pos] != 0 {
					return nil, apperr.FieldError(fmt.Sprintf("body.items[%d].shared_by", i), "List each person once per item.")
				}
				weight := sb.Weight
				if weight == 0 {
					weight = 1
				}
				w[pos] = weight
			}
			items[i] = split.Item{AmountMinor: a, Weights: w}
			var qty *string
			if q := strings.TrimSpace(it.Quantity); q != "" {
				qty = &q
			}
			c.items = append(c.items, computedItem{desc: strings.TrimSpace(it.Description), amount: a, qty: qty, weights: w})
		}
		if itemSum > c.amount {
			return nil, apperr.Rule("items_exceed_total", "Items add up to more than the total.", nil)
		}
		if itemSum == 0 {
			return nil, apperr.Rule("items_need_amount", "At least one item needs an amount.", nil)
		}
		c.shares, err = split.Itemized(c.amount, n, items)
		if err == nil {
			for i := range c.items {
				c.items[i].shares = make([]int64, n)
				if c.items[i].amount > 0 {
					if c.items[i].shares, err = split.ByWeights(c.items[i].amount, c.items[i].weights); err != nil {
						break
					}
				}
			}
		}
	default:
		return nil, apperr.FieldError("body.split_method", "Unknown split method.")
	}
	if err != nil {
		return nil, apperr.Rule("split_mismatch", "The split does not add up: "+err.Error()+".", nil)
	}
	payers := in.Payers
	if len(payers) == 0 {
		payers = []ExpensePayerInput{{UserID: uid}}
	}
	if len(payers) == 1 && payers[0].Amount == "" {
		// One payer paid everything; the server derives the amount so the
		// client never converts money itself.
		payers = []ExpensePayerInput{{UserID: payers[0].UserID, Amount: apitypes.M(c.amount, g.BaseCurrency).Amount}}
	}
	var paid int64
	for i, p := range payers {
		if !active[p.UserID] {
			return nil, apperr.FieldError(fmt.Sprintf("body.payers[%d].user_id", i), "Payers must be active members.")
		}
		if _, dup := c.payers[p.UserID]; dup {
			return nil, apperr.FieldError(fmt.Sprintf("body.payers[%d].user_id", i), "Each payer can appear once.")
		}
		a, perr := finance.ParseAmount(fmt.Sprintf("body.payers[%d].amount", i), p.Amount, g.BaseCurrency)
		if perr != nil {
			return nil, perr
		}
		c.payers[p.UserID] = a
		c.payerOrder = append(c.payerOrder, p.UserID)
		if paid, err = money.Add(paid, a); err != nil {
			return nil, err
		}
	}
	if paid != c.amount {
		return nil, apperr.Rule("payers_total_mismatch", "The payers' amounts must add up to the total.", nil)
	}
	if in.ReceiptFileID != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from files where id = $1 and group_id = $2 and purpose = 'group_attachment' and status = 'ready')`,
			*in.ReceiptFileID, g.ID).Scan(&ok); err != nil {
			return nil, err
		}
		if !ok {
			return nil, apperr.FieldError("body.receipt_file_id", "Upload the receipt to this group first (purpose group_attachment).")
		}
	}
	c.rawInput, err = json.Marshal(map[string]any{"method": c.method, "participants": in.Participants, "items": in.Items, "payers": payers})
	return c, err
}

func (s *Service) writeExpense(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, id uuid.UUID, c *computed, in GroupExpenseInput, version int32) error {
	for _, q := range []string{`delete from group_expense_item_shares where expense_id = $1`, `delete from group_expense_items where expense_id = $1`,
		`delete from group_expense_shares where expense_id = $1`, `delete from group_expense_payers where expense_id = $1`} {
		if _, err := tx.Exec(ctx, q, id); err != nil {
			return err
		}
	}
	for _, p := range c.payerOrder {
		if _, err := tx.Exec(ctx, `insert into group_expense_payers (expense_id, group_id, user_id, amount_minor) values ($1,$2,$3,$4)`, id, g.ID, p, c.payers[p]); err != nil {
			return err
		}
	}
	for i, p := range c.partIDs {
		if _, err := tx.Exec(ctx, `insert into group_expense_shares (expense_id, group_id, user_id, share_minor, input_value, position) values ($1,$2,$3,$4,$5,$6)`,
			id, g.ID, p, c.shares[i], c.inputs[i], i+1); err != nil {
			return err
		}
	}
	for i, it := range c.items {
		iid := uuid.New()
		if _, err := tx.Exec(ctx, `insert into group_expense_items (id, expense_id, group_id, position, description, amount_minor, quantity)
			values ($1,$2,$3,$4,$5,$6,$7::numeric)`, iid, id, g.ID, i+1, it.desc, it.amount, it.qty); err != nil {
			return err
		}
		for pos, w := range it.weights {
			if w == 0 {
				continue
			}
			if _, err := tx.Exec(ctx, `insert into group_expense_item_shares (item_id, expense_id, group_id, user_id, weight, share_minor) values ($1,$2,$3,$4,$5,$6)`,
				iid, id, g.ID, c.partIDs[pos], w, it.shares[pos]); err != nil {
				return err
			}
		}
	}
	snapshot, err := json.Marshal(map[string]any{"amount_minor": c.amount, "currency": g.BaseCurrency, "date": finance.LocalDateString(c.date),
		"description": in.Description, "input": json.RawMessage(c.rawInput), "shares": c.shares, "participants": c.partIDs})
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `insert into group_expense_revisions (expense_id, group_id, version, editor_id, snapshot) values ($1,$2,$3,$4,$5)`,
		id, g.ID, version, uid, snapshot)
	return err
}

// CreateExpense records a shared expense.
func (s *Service) CreateExpense(ctx context.Context, key string, groupID uuid.UUID, in GroupExpenseInput) (*GroupExpenseDetail, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out GroupExpenseDetail
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = runIdem(ctx, tx, uid, key, "group_expense.create", groupID, in, func() (GroupExpenseDetail, error) {
			_, g, err := requireMember(ctx, tx, groupID)
			if err != nil {
				return GroupExpenseDetail{}, err
			}
			if err := requireActive(g); err != nil {
				return GroupExpenseDetail{}, err
			}
			id, err := s.createExpenseInTx(ctx, tx, uid, g, in, nil)
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

// createExpenseInTx validates and stores an expense created by uid (an
// active member of the active group g), with its splits, revision, optional
// payer record, activity, audit and outbox event.
func (s *Service) createExpenseInTx(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, in GroupExpenseInput, rule *uuid.UUID) (uuid.UUID, error) {
	c, err := s.compute(ctx, tx, uid, g, in, nil)
	if err != nil {
		return uuid.Nil, err
	}
	id := uuid.New()
	origAmt, origCur, rate, source, at := c.fxColumns()
	if _, err := tx.Exec(ctx, `insert into group_expenses (id, group_id, created_by, description, category_key, amount_minor, currency,
		original_amount_minor, original_currency, fx_rate, fx_rate_source, fx_rate_at, expense_date, split_method, split_input, receipt_file_id, notes,
		recurring_rule_id)
		values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::numeric,$11,case when $10::text is null then null else coalesce($12::timestamptz, now()) end,
		$13,$14,$15,$16,$17,$18)`, id, g.ID, uid, strings.TrimSpace(in.Description),
		trim(in.CategoryKey, 40), c.amount, g.BaseCurrency, origAmt, origCur, rate, source, at, c.date, c.method, c.rawInput, in.ReceiptFileID,
		trim(in.Notes, 2000), rule); err != nil {
		return uuid.Nil, err
	}
	if err := s.writeExpense(ctx, tx, uid, g, id, c, in, 1); err != nil {
		return uuid.Nil, err
	}
	if in.PayerAccountID != nil {
		if _, ok := c.payers[uid]; !ok {
			return uuid.Nil, apperr.FieldError("body.payer_account_id", "Only a payer can record the payment in an account.")
		}
		if err := s.linkPayer(ctx, tx, uid, g, id, *in.PayerAccountID, c, strings.TrimSpace(in.Description)); err != nil {
			// The shared account helper names its field account_id.
			return uuid.Nil, renameField(err, "body.account_id", "body.payer_account_id")
		}
	}
	summary := map[string]any{"description": strings.TrimSpace(in.Description)}
	if rule != nil {
		summary["recurring_rule_id"] = *rule
	}
	if err := activity(ctx, tx, g.ID, &uid, "expense_added", "group_expense", &id, summary); err != nil {
		return uuid.Nil, err
	}
	gid := g.ID
	if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, GroupID: &gid, EntityType: "group_expense", EntityID: &id,
		Action: "created"}); err != nil {
		return uuid.Nil, err
	}
	if err := outbox.Emit(ctx, tx, outbox.Event{Type: "group_expense.created", AggregateType: "group_expense", AggregateID: id, UserID: &uid,
		GroupID: &gid}); err != nil {
		return uuid.Nil, err
	}
	return id, nil
}

// renameField reports validation details under the request's own field
// name when a shared helper names the field differently.
func renameField(err error, from, to string) error {
	var ae *apperr.Error
	if !errors.As(err, &ae) || len(ae.Details) == 0 {
		return err
	}
	cp := *ae
	cp.Details = append([]apperr.Detail(nil), ae.Details...)
	for i := range cp.Details {
		if cp.Details[i].Field == from {
			cp.Details[i].Field = to
		}
	}
	return &cp
}

// linkPayer records the payer's personal group_expense transaction: the
// amount they paid leaves their account; only their share counts as their
// spending (ADR-023).
func (s *Service) linkPayer(ctx context.Context, tx pgx.Tx, uid uuid.UUID, g *GroupDTO, expenseID, account uuid.UUID, c *computed, desc string) error {
	share := int64(0)
	for i, p := range c.partIDs {
		if p == uid {
			share = c.shares[i]
		}
	}
	paid := c.payers[uid]
	share = min(share, paid)
	eid := expenseID
	_, err := s.Finance.CreateGroupLinkedInTx(ctx, tx, uid, finance.GroupLink{AccountID: account, Type: "group_expense", Direction: "outflow",
		AmountMinor: paid, PersonalShare: &share, LocalDate: c.date, Description: desc, GroupID: g.ID, GroupExpenseID: &eid}, g.BaseCurrency)
	return err
}

// UpdateExpense replaces an expense (any member; history is kept). Payers'
// personal records are re-synced by the worker.
func (s *Service) UpdateExpense(ctx context.Context, groupID, id uuid.UUID, in GroupExpenseInput) (*GroupExpenseDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupExpenseDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		if err := requireActive(g); err != nil {
			return err
		}
		var version int32
		var status string
		var prev storedFX
		if err := tx.QueryRow(ctx, `select version, status, original_amount_minor, original_currency, fx_rate::text, fx_rate_source, fx_rate_at,
			expense_date from group_expenses where id = $1 and group_id = $2 for update`, id, groupID).Scan(&version, &status, &prev.orig, &prev.cur,
			&prev.rate, &prev.source, &prev.at, &prev.date); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("expense")
			}
			return err
		}
		if status == "deleted" {
			return expenseDeleted()
		}
		if version != in.Version {
			return apperr.VersionConflict()
		}
		c, err := s.compute(ctx, tx, uid, g, in, &prev)
		if err != nil {
			return err
		}
		origAmt, origCur, rate, source, at := c.fxColumns()
		if _, err := tx.Exec(ctx, `update group_expenses set description = $3, category_key = $4, amount_minor = $5, original_amount_minor = $6,
			original_currency = $7, fx_rate = $8::numeric, fx_rate_source = $9,
			fx_rate_at = case when $8::text is null then null else coalesce($10::timestamptz, now()) end, expense_date = $11, split_method = $12,
			split_input = $13, receipt_file_id = $14, notes = $15, version = version + 1 where id = $1 and group_id = $2`, id, groupID,
			strings.TrimSpace(in.Description), trim(in.CategoryKey, 40), c.amount, origAmt, origCur, rate, source, at, c.date, c.method, c.rawInput,
			in.ReceiptFileID, trim(in.Notes, 2000)); err != nil {
			return err
		}
		if err := s.writeExpense(ctx, tx, uid, g, id, c, in, version+1); err != nil {
			return err
		}
		if err := s.changed(ctx, tx, uid, groupID, id, "expense_updated"); err != nil {
			return err
		}
		out, err = s.expenseDetail(ctx, tx, uid, groupID, id)
		return err
	})
	return out, database.MapError(err)
}

func expenseDeleted() error {
	return apperr.ConflictCode("expense_deleted", "This expense was deleted.", nil)
}

func (s *Service) changed(ctx context.Context, tx pgx.Tx, uid, groupID, id uuid.UUID, kind string) error {
	if err := activity(ctx, tx, groupID, &uid, kind, "group_expense", &id, nil); err != nil {
		return err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, GroupID: &groupID, EntityType: "group_expense", EntityID: &id,
		Action: kind}); err != nil {
		return err
	}
	return outbox.Emit(ctx, tx, outbox.Event{Type: EventExpenseChanged, AggregateType: "group_expense", AggregateID: id, UserID: &uid, GroupID: &groupID})
}

// DeleteExpense deletes an expense (creator or admins); history is kept.
func (s *Service) DeleteExpense(ctx context.Context, groupID, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		if err := requireActive(g); err != nil {
			return err
		}
		var creator *uuid.UUID
		var status string
		if err := tx.QueryRow(ctx, `select created_by, status from group_expenses where id = $1 and group_id = $2 for update`, id, groupID).Scan(&creator, &status); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("expense")
			}
			return err
		}
		if status == "deleted" {
			return nil
		}
		if role == "member" && (creator == nil || *creator != uid) {
			return apperr.Forbidden()
		}
		if _, err := tx.Exec(ctx, `update group_expenses set status = 'deleted', deleted_at = now(), version = version + 1 where id = $1`, id); err != nil {
			return err
		}
		return s.changed(ctx, tx, uid, groupID, id, "expense_deleted")
	}))
}

func (s *Service) expenseDetail(ctx context.Context, tx pgx.Tx, me, groupID, id uuid.UUID) (*GroupExpenseDetail, error) {
	list, err := s.expenses(ctx, tx, me, groupID, `e.id = $2`, id)
	if err != nil {
		return nil, err
	}
	if len(list) == 0 {
		return nil, apperr.NotFound("expense")
	}
	d := &GroupExpenseDetail{GroupExpenseDTO: list[0], Items: []ExpenseItemDTO{}, Comments: []GroupCommentDTO{}, Disputes: []GroupDisputeDTO{}}
	cur := d.Amount.Currency
	rows, err := tx.Query(ctx, `select i.id, i.description, i.amount_minor, i.quantity::text from group_expense_items i where i.expense_id = $1 order by i.position`, id)
	if err != nil {
		return nil, err
	}
	type it struct {
		id   uuid.UUID
		item ExpenseItemDTO
	}
	items, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (it, error) {
		var x it
		var amt int64
		err := r.Scan(&x.id, &x.item.Description, &amt, &x.item.Quantity)
		x.item.Amount = apitypes.M(amt, cur)
		return x, err
	})
	if err != nil {
		return nil, err
	}
	for _, x := range items {
		srows, err := tx.Query(ctx, `select user_id, share_minor, weight::text from group_expense_item_shares where item_id = $1 order by user_id`, x.id)
		if err != nil {
			return nil, err
		}
		x.item.Shares, err = pgx.CollectRows(srows, func(r pgx.CollectableRow) (ExpenseShareDTO, error) {
			var sh ExpenseShareDTO
			var amt int64
			err := r.Scan(&sh.UserID, &amt, &sh.InputValue)
			sh.Share = apitypes.M(amt, cur)
			return sh, err
		})
		if err != nil {
			return nil, err
		}
		d.Items = append(d.Items, x.item)
	}
	crows, err := tx.Query(ctx, `select id, author_id, body, created_at from group_expense_comments where expense_id = $1 and deleted_at is null order by created_at`, id)
	if err != nil {
		return nil, err
	}
	if d.Comments, err = pgx.CollectRows(crows, func(r pgx.CollectableRow) (GroupCommentDTO, error) {
		var c GroupCommentDTO
		err := r.Scan(&c.ID, &c.AuthorID, &c.Body, &c.CreatedAt)
		return c, err
	}); err != nil {
		return nil, err
	}
	drows, err := tx.Query(ctx, `select id, raised_by, reason, status, resolution, created_at from group_disputes where expense_id = $1 order by created_at`, id)
	if err != nil {
		return nil, err
	}
	if d.Disputes, err = pgx.CollectRows(drows, func(r pgx.CollectableRow) (GroupDisputeDTO, error) {
		var x GroupDisputeDTO
		err := r.Scan(&x.ID, &x.RaisedBy, &x.Reason, &x.Status, &x.Resolution, &x.CreatedAt)
		return x, err
	}); err != nil {
		return nil, err
	}
	err = tx.QueryRow(ctx, `select count(*) from group_expense_revisions where expense_id = $1`, id).Scan(&d.Revisions)
	return d, err
}

// expenses lists expenses with payers and shares.
func (s *Service) expenses(ctx context.Context, tx pgx.Tx, me, groupID uuid.UUID, where string, args ...any) ([]GroupExpenseDTO, error) {
	q := `select e.id, e.group_id, e.description, e.category_key, e.amount_minor, e.currency, e.original_amount_minor, e.original_currency,
		e.fx_rate::text, e.fx_rate_source, e.fx_rate_at, e.expense_date, e.split_method, e.status, e.notes, e.receipt_file_id, e.created_by, e.version,
		e.created_at,
		(select t.id from transactions t where t.group_expense_id = e.id and t.user_id = montra.current_user_id() and t.status <> 'voided' limit 1),
		coalesce((select jsonb_agg(jsonb_build_object('u', p.user_id, 'a', p.amount_minor)) from group_expense_payers p where p.expense_id = e.id), '[]'),
		coalesce((select jsonb_agg(jsonb_build_object('u', sh.user_id, 'a', sh.share_minor, 'v', sh.input_value) order by sh.position)
			from group_expense_shares sh where sh.expense_id = e.id), '[]')
		from group_expenses e where e.group_id = $1`
	if where != "" {
		q += ` and ` + where
	}
	rows, err := tx.Query(ctx, q, append([]any{groupID}, args...)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []GroupExpenseDTO{}
	for rows.Next() {
		var e GroupExpenseDTO
		var amt int64
		var cur string
		var origAmt *int64
		var origCur *string
		var d time.Time
		var payersRaw, sharesRaw []byte
		if err := rows.Scan(&e.ID, &e.GroupID, &e.Description, &e.CategoryKey, &amt, &cur, &origAmt, &origCur, &e.FXRate, &e.FXRateSource,
			&e.FXRateAt, &d, &e.SplitMethod, &e.Status, &e.Notes, &e.ReceiptFileID, &e.CreatedBy, &e.Version, &e.CreatedAt, &e.MyTransactionID,
			&payersRaw, &sharesRaw); err != nil {
			return nil, err
		}
		e.Amount, e.ExpenseDate = apitypes.M(amt, cur), finance.LocalDateString(d)
		if e.FXRate != nil {
			if r, err := money.ParseRate(*e.FXRate); err == nil {
				v := money.FormatRate(r) // numeric(30,12) text without padding zeros
				e.FXRate = &v
			}
		}
		if origAmt != nil && origCur != nil {
			om := apitypes.M(*origAmt, *origCur)
			e.OriginalAmount = &om
		}
		var ps []struct {
			U uuid.UUID `json:"u"`
			A int64     `json:"a"`
		}
		if err := json.Unmarshal(payersRaw, &ps); err != nil {
			return nil, err
		}
		var ss []struct {
			U uuid.UUID `json:"u"`
			A int64     `json:"a"`
			V *string   `json:"v"`
		}
		if err := json.Unmarshal(sharesRaw, &ss); err != nil {
			return nil, err
		}
		var myPaid, myShare int64
		e.Payers, e.Shares = []ExpensePayerDTO{}, []ExpenseShareDTO{}
		for _, p := range ps {
			e.Payers = append(e.Payers, ExpensePayerDTO{UserID: p.U, Paid: apitypes.M(p.A, cur)})
			if p.U == me {
				myPaid = p.A
			}
		}
		for _, sh := range ss {
			e.Shares = append(e.Shares, ExpenseShareDTO{UserID: sh.U, Share: apitypes.M(sh.A, cur), InputValue: sh.V})
			if sh.U == me {
				myShare = sh.A
			}
		}
		e.MyPaid, e.MyShare = apitypes.M(myPaid, cur), apitypes.M(myShare, cur)
		out = append(out, e)
	}
	return out, rows.Err()
}

// ExpenseFilter narrows the expense list. Empty fields do not filter.
type ExpenseFilter struct {
	Status         string     // active, disputed or deleted
	IncludeDeleted bool       // without Status: also deleted expenses
	From, To       *time.Time // expense date range, inclusive
	PayerUserID    *uuid.UUID // expenses this member paid (in full or in part)
	CategoryKey    string     // "uncategorized": expenses without a category
}

type expenseCursor struct {
	Date    time.Time `json:"d"`
	Created time.Time `json:"c"`
	ID      uuid.UUID `json:"i"`
}

// ListExpenses lists a group's expenses newest first (by expense date, then
// creation), one page at a time.
func (s *Service) ListExpenses(ctx context.Context, groupID uuid.UUID, f ExpenseFilter, cursor string, limit int) ([]GroupExpenseDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	var cur *expenseCursor
	if cursor != "" {
		cur = &expenseCursor{}
		if err := httpx.DecodeCursor(cursor, cur); err != nil {
			return nil, "", err
		}
	}
	conds, args := []string{}, []any{}
	add := func(cond string, vals ...any) {
		for _, v := range vals {
			args = append(args, v)
			cond = strings.Replace(cond, "?", "$"+strconv.Itoa(len(args)+1), 1) // $1 is the group
		}
		conds = append(conds, cond)
	}
	switch {
	case f.Status != "":
		add(`e.status = ?`, f.Status)
	case !f.IncludeDeleted:
		conds = append(conds, `e.status <> 'deleted'`)
	}
	if f.From != nil {
		add(`e.expense_date >= ?::date`, *f.From)
	}
	if f.To != nil {
		add(`e.expense_date <= ?::date`, *f.To)
	}
	if f.PayerUserID != nil {
		add(`exists (select 1 from group_expense_payers p where p.expense_id = e.id and p.user_id = ?)`, *f.PayerUserID)
	}
	if f.CategoryKey != "" {
		add(`(e.category_key = ? or (?::text = 'uncategorized' and e.category_key is null))`, f.CategoryKey, f.CategoryKey)
	}
	if cur != nil {
		add(`(e.expense_date, e.created_at, e.id) < (?::date, ?::timestamptz, ?::uuid)`, cur.Date, cur.Created, cur.ID)
	}
	where := "true"
	if len(conds) > 0 {
		where = strings.Join(conds, " and ")
	}
	where += ` order by e.expense_date desc, e.created_at desc, e.id desc limit ` + strconv.Itoa(limit+1)
	var out []GroupExpenseDTO
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		if out, err = s.expenses(ctx, tx, uid, groupID, where, args...); err != nil {
			return err
		}
		if len(out) > limit {
			last := out[limit-1]
			d, err := time.Parse("2006-01-02", last.ExpenseDate)
			if err != nil {
				return err
			}
			if next, err = httpx.EncodeCursor(expenseCursor{Date: d, Created: last.CreatedAt, ID: last.ID}); err != nil {
				return err
			}
			out = out[:limit]
		}
		return nil
	})
	return out, next, database.MapError(err)
}

// GetExpense returns one expense with items, comments and disputes.
func (s *Service) GetExpense(ctx context.Context, groupID, id uuid.UUID) (*GroupExpenseDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupExpenseDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		out, err = s.expenseDetail(ctx, tx, uid, groupID, id)
		return err
	})
	return out, database.MapError(err)
}

// Comment adds a comment to an expense.
func (s *Service) Comment(ctx context.Context, groupID, id uuid.UUID, body string) (*GroupCommentDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	body = strings.TrimSpace(body)
	if body == "" {
		return nil, apperr.FieldError("body.body", "Write a comment.")
	}
	var out GroupCommentDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from group_expenses where id = $1 and group_id = $2)`, id, groupID).Scan(&ok); err != nil || !ok {
			if err == nil {
				return apperr.NotFound("expense")
			}
			return err
		}
		if err := tx.QueryRow(ctx, `insert into group_expense_comments (expense_id, group_id, author_id, body) values ($1,$2,$3,$4)
			returning id, author_id, body, created_at`, id, groupID, uid, body).Scan(&out.ID, &out.AuthorID, &out.Body, &out.CreatedAt); err != nil {
			return err
		}
		return activity(ctx, tx, groupID, &uid, "expense_commented", "group_expense", &id, nil)
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// Dispute opens a dispute on an expense; it stays counted until resolved.
func (s *Service) Dispute(ctx context.Context, groupID, id uuid.UUID, reason string) (*GroupDisputeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return nil, apperr.FieldError("body.reason", "Explain what is wrong.")
	}
	var out GroupDisputeDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := requireMember(ctx, tx, groupID); err != nil {
			return err
		}
		var status string
		if err := tx.QueryRow(ctx, `select status from group_expenses where id = $1 and group_id = $2 for update`, id, groupID).Scan(&status); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("expense")
			}
			return err
		}
		if status == "deleted" {
			return expenseDeleted()
		}
		if _, err := tx.Exec(ctx, `update group_expenses set status = 'disputed' where id = $1`, id); err != nil {
			return err
		}
		if err := tx.QueryRow(ctx, `insert into group_disputes (group_id, expense_id, raised_by, reason) values ($1,$2,$3,$4)
			returning id, raised_by, reason, status, resolution, created_at`, groupID, id, uid, reason).Scan(&out.ID, &out.RaisedBy, &out.Reason, &out.Status,
			&out.Resolution, &out.CreatedAt); err != nil {
			return err
		}
		return activity(ctx, tx, groupID, &uid, "expense_disputed", "group_expense", &id, nil)
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// ResolveDispute resolves or withdraws a dispute (raiser or admins).
func (s *Service) ResolveDispute(ctx context.Context, groupID, disputeID uuid.UUID, resolution string, withdraw bool) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		role, _, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		var raisedBy *uuid.UUID
		var expenseID, settlementID *uuid.UUID
		if err := tx.QueryRow(ctx, `select raised_by, expense_id, settlement_id from group_disputes where id = $1 and group_id = $2 and status = 'open' for update`,
			disputeID, groupID).Scan(&raisedBy, &expenseID, &settlementID); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("open dispute")
			}
			return err
		}
		if settlementID != nil {
			return apperr.Rule("settlement_dispute", "Settlement disputes end when the payee confirms the payment or someone voids it.", nil)
		}
		if role == "member" && (raisedBy == nil || *raisedBy != uid) {
			return apperr.Forbidden()
		}
		status := map[bool]string{true: "withdrawn", false: "resolved"}[withdraw]
		if _, err := tx.Exec(ctx, `update group_disputes set status = $2, resolution = $3, resolved_by = $4, resolved_at = now() where id = $1`,
			disputeID, status, trim(resolution, 1000), uid); err != nil {
			return err
		}
		if expenseID != nil {
			if _, err := tx.Exec(ctx, `update group_expenses set status = 'active' where id = $1 and status = 'disputed'
				and not exists (select 1 from group_disputes where expense_id = $1 and status = 'open')`, *expenseID); err != nil {
				return err
			}
		}
		target, targetType := expenseID, "expense"
		if target == nil {
			target, targetType = settlementID, "settlement"
		}
		return activity(ctx, tx, groupID, &uid, "dispute_"+status, "group_dispute", &disputeID,
			map[string]any{"target": target, "target_type": targetType})
	}))
}

// ExpenseRecordInput links or unlinks the caller's own account record for
// an expense they paid.
type ExpenseRecordInput struct {
	Action    string     `json:"action" enum:"link,unlink"`
	AccountID *uuid.UUID `json:"account_id,omitempty" doc:"link: one of your accounts in the group currency"`
}

// ExpensePersonalRecord records (or removes) the caller's payment for an
// expense in their own account. Only the caller's own share counts as
// their spending; the rest is money the group owes them.
func (s *Service) ExpensePersonalRecord(ctx context.Context, groupID, id uuid.UUID, in ExpenseRecordInput) (*GroupExpenseDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupExpenseDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		var status, desc string
		var date time.Time
		if err := tx.QueryRow(ctx, `select status, description, expense_date from group_expenses where id = $1 and group_id = $2 for update`, id, groupID).
			Scan(&status, &desc, &date); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("expense")
			}
			return err
		}
		rows, err := tx.Query(ctx, `select id from transactions where group_expense_id = $1 and user_id = $2 and status <> 'voided'`, id, uid)
		if err != nil {
			return err
		}
		linked, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		switch in.Action {
		case "unlink":
			if len(linked) == 0 {
				return apperr.NotFound("linked account record")
			}
			for _, t := range linked {
				if err := s.Finance.VoidGroupLinkedInTx(ctx, tx, uid, t); err != nil {
					return err
				}
			}
		case "link":
			if status == "deleted" {
				return expenseDeleted()
			}
			if in.AccountID == nil {
				return apperr.FieldError("body.account_id", "Choose one of your accounts.")
			}
			if len(linked) > 0 {
				return apperr.ConflictCode("expense_already_recorded", "This expense is already recorded in your account.", nil)
			}
			c := &computed{payers: map[uuid.UUID]int64{}, date: date}
			var paid, share int64
			if err := tx.QueryRow(ctx, `select coalesce((select amount_minor from group_expense_payers where expense_id = $1 and user_id = $2), 0),
				coalesce((select share_minor from group_expense_shares where expense_id = $1 and user_id = $2), 0)`, id, uid).Scan(&paid, &share); err != nil {
				return err
			}
			if paid == 0 {
				return apperr.Rule("payer_only", "Only a payer can record this expense in an account.", nil)
			}
			c.payers[uid] = paid
			c.partIDs, c.shares = []uuid.UUID{uid}, []int64{share}
			if err := s.linkPayer(ctx, tx, uid, g, id, *in.AccountID, c, desc); err != nil {
				return err
			}
		default:
			return apperr.FieldError("body.action", "Unknown action.")
		}
		out, err = s.expenseDetail(ctx, tx, uid, groupID, id)
		return err
	})
	return out, database.MapError(err)
}
