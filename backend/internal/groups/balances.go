package groups

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/settlement"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
)

// GroupMemberBalance is one member's derived position in the group
// currency. Balances are recomputed from expense payers/shares and
// confirmed settlements on every read (no cached source of truth).
type GroupMemberBalance struct {
	UserID       uuid.UUID      `json:"user_id"`
	DisplayName  string         `json:"display_name"`
	MemberStatus string         `json:"member_status" enum:"active,left,removed"`
	Paid         apitypes.Money `json:"paid" doc:"Total this member paid for shared expenses"`
	Share        apitypes.Money `json:"share" doc:"Total of this member's shares"`
	Sent         apitypes.Money `json:"settlements_sent" doc:"Confirmed settlements this member paid"`
	Received     apitypes.Money `json:"settlements_received" doc:"Confirmed settlements this member received"`
	Net          apitypes.Money `json:"net" doc:"Positive: is owed; negative: owes"`
	PendingOut   apitypes.Money `json:"pending_out" doc:"Reported payments awaiting the payee's confirmation (not counted yet)"`
	PendingIn    apitypes.Money `json:"pending_in" doc:"Reported payments to this member awaiting their confirmation"`
}

// GroupTransferDTO is a debt or a suggested payment between two members.
type GroupTransferDTO struct {
	FromUserID uuid.UUID      `json:"from_user_id"`
	FromName   string         `json:"from_name"`
	ToUserID   uuid.UUID      `json:"to_user_id"`
	ToName     string         `json:"to_name"`
	Amount     apitypes.Money `json:"amount"`
	InvolvesMe bool           `json:"involves_me"`
}

// GroupBalancesDTO is the group's derived balance sheet.
type GroupBalancesDTO struct {
	GroupID          uuid.UUID            `json:"group_id"`
	Currency         string               `json:"currency"`
	Balances         []GroupMemberBalance `json:"balances"`
	MyNet            apitypes.Money       `json:"my_net" doc:"Positive: you are owed; negative: you owe"`
	OriginalDebts    []GroupTransferDTO   `json:"original_debts" doc:"Who owes whom from each expense, netted per pair"`
	Simplified       []GroupTransferDTO   `json:"simplified" doc:"Fewest transfers that settle every balance (a suggestion, not a payment)"`
	SimplifyEnabled  bool                 `json:"simplify_enabled"`
	DisputedExpenses int                  `json:"disputed_expenses" doc:"Disputed expenses still count until they are resolved, edited or deleted"`
	ComputedAt       time.Time            `json:"computed_at"`
}

// balances derives balances for a group the caller belongs to.
func (s *Service) balances(ctx context.Context, tx pgx.Tx, g *GroupDTO) (*GroupBalancesDTO, error) {
	me, _ := identity.UserID(ctx)
	ms, err := members(ctx, tx, g.ID)
	if err != nil {
		return nil, err
	}
	names := map[uuid.UUID]string{}
	statuses := map[uuid.UUID]string{}
	ids := make([]uuid.UUID, 0, len(ms))
	for _, m := range ms {
		names[m.UserID], statuses[m.UserID] = m.DisplayName, m.Status
		ids = append(ids, m.UserID)
	}
	byExpense := map[uuid.UUID]*settlement.Expense{}
	var order []uuid.UUID
	get := func(id uuid.UUID) *settlement.Expense {
		e, ok := byExpense[id]
		if !ok {
			e = &settlement.Expense{Payers: map[uuid.UUID]int64{}, Shares: map[uuid.UUID]int64{}}
			byExpense[id] = e
			order = append(order, id)
		}
		return e
	}
	rows, err := tx.Query(ctx, `select p.expense_id, p.user_id, p.amount_minor, true from group_expense_payers p
		join group_expenses e on e.id = p.expense_id where e.group_id = $1 and e.status <> 'deleted'
		union all
		select sh.expense_id, sh.user_id, sh.share_minor, false from group_expense_shares sh
		join group_expenses e on e.id = sh.expense_id where e.group_id = $1 and e.status <> 'deleted'
		order by 1, 4 desc, 2`, g.ID)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var eid, uid uuid.UUID
		var amt int64
		var payer bool
		if err := rows.Scan(&eid, &uid, &amt, &payer); err != nil {
			rows.Close()
			return nil, err
		}
		e := get(eid)
		if payer {
			e.Payers[uid] += amt
		} else {
			e.Shares[uid] += amt
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	expenses := make([]settlement.Expense, 0, len(order))
	for _, id := range order {
		expenses = append(expenses, *byExpense[id])
	}
	var payments []settlement.Payment
	pendingOut, pendingIn := map[uuid.UUID]int64{}, map[uuid.UUID]int64{}
	srows, err := tx.Query(ctx, `select payer_user_id, payee_user_id, amount_minor, status from settlements
		where group_id = $1 and status in ('confirmed','user_reported_paid') order by created_at, id`, g.ID)
	if err != nil {
		return nil, err
	}
	for srows.Next() {
		var from, to uuid.UUID
		var amt int64
		var status string
		if err := srows.Scan(&from, &to, &amt, &status); err != nil {
			srows.Close()
			return nil, err
		}
		if status == "confirmed" {
			payments = append(payments, settlement.Payment{Payer: from, Payee: to, Amount: amt})
		} else {
			pendingOut[from] += amt
			pendingIn[to] += amt
		}
	}
	srows.Close()
	if err := srows.Err(); err != nil {
		return nil, err
	}
	out := &GroupBalancesDTO{GroupID: g.ID, Currency: g.BaseCurrency, SimplifyEnabled: g.SimplifyDebts, ComputedAt: s.now().UTC(),
		Balances: []GroupMemberBalance{}, OriginalDebts: []GroupTransferDTO{}, Simplified: []GroupTransferDTO{}}
	if err := tx.QueryRow(ctx, `select count(*) from group_expenses where group_id = $1 and status = 'disputed'`, g.ID).Scan(&out.DisputedExpenses); err != nil {
		return nil, err
	}
	cur := g.BaseCurrency
	name := func(id uuid.UUID) string {
		if n, ok := names[id]; ok {
			return n
		}
		return "Former member"
	}
	bals := settlement.Compute(ids, expenses, payments)
	var myNet int64
	for _, b := range bals {
		st := statuses[b.UserID]
		if st == "" {
			st = "removed"
		}
		// Former members with nothing outstanding are omitted.
		if st != "active" && b.NetMinor == 0 && b.Paid == 0 && b.Share == 0 && pendingIn[b.UserID] == 0 && pendingOut[b.UserID] == 0 {
			continue
		}
		out.Balances = append(out.Balances, GroupMemberBalance{UserID: b.UserID, DisplayName: name(b.UserID), MemberStatus: st,
			Paid: apitypes.M(b.Paid, cur), Share: apitypes.M(b.Share, cur), Sent: apitypes.M(b.SentSet, cur), Received: apitypes.M(b.RecvSet, cur),
			Net: apitypes.M(b.NetMinor, cur), PendingOut: apitypes.M(pendingOut[b.UserID], cur), PendingIn: apitypes.M(pendingIn[b.UserID], cur)})
		if b.UserID == me {
			myNet = b.NetMinor
		}
	}
	out.MyNet = apitypes.M(myNet, cur)
	conv := func(ts []settlement.Transfer) []GroupTransferDTO {
		res := make([]GroupTransferDTO, 0, len(ts))
		for _, t := range ts {
			res = append(res, GroupTransferDTO{FromUserID: t.From, FromName: name(t.From), ToUserID: t.To, ToName: name(t.To),
				Amount: apitypes.M(t.Amount, cur), InvolvesMe: t.From == me || t.To == me})
		}
		return res
	}
	out.OriginalDebts = conv(settlement.PairwiseDebts(expenses, payments))
	out.Simplified = conv(settlement.Simplify(bals))
	return out, nil
}

// Balances returns the group's derived balances.
func (s *Service) Balances(ctx context.Context, groupID uuid.UUID) (*GroupBalancesDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *GroupBalancesDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		_, g, err := requireMember(ctx, tx, groupID)
		if err != nil {
			return err
		}
		out, err = s.balances(ctx, tx, g)
		return err
	})
	return out, database.MapError(err)
}

// GroupSuggestionsDTO lists suggested payments; they never change records
// and are not payments.
type GroupSuggestionsDTO struct {
	Mode        string             `json:"mode" enum:"simplified,original" doc:"simplified when the group simplifies debts"`
	Currency    string             `json:"currency"`
	Suggestions []GroupTransferDTO `json:"suggestions"`
	Note        string             `json:"note"`
}

// Suggestions returns settlement suggestions (simplified when enabled).
func (s *Service) Suggestions(ctx context.Context, groupID uuid.UUID, onlyMine bool) (*GroupSuggestionsDTO, error) {
	b, err := s.Balances(ctx, groupID)
	if err != nil {
		return nil, err
	}
	out := &GroupSuggestionsDTO{Mode: "original", Currency: b.Currency, Suggestions: b.OriginalDebts,
		Note: "Suggestions only. Montra does not move money; record a settlement after you pay off-app."}
	if b.SimplifyEnabled {
		out.Mode, out.Suggestions = "simplified", b.Simplified
	}
	if onlyMine {
		mine := []GroupTransferDTO{}
		for _, t := range out.Suggestions {
			if t.InvolvesMe {
				mine = append(mine, t)
			}
		}
		out.Suggestions = mine
	}
	return out, nil
}
