// Package settlement derives group balances from expense payers/shares and
// confirmed settlements, and proposes simplified transfers. Suggestions never
// mutate source records and are not payments (spec §4.15).
package settlement

import (
	"errors"
	"math/big"
	"sort"

	"github.com/google/uuid"
)

// ErrCurrency is returned when inputs mix currencies.
var ErrCurrency = errors.New("all amounts must be in the group currency")

// Expense contributes payer credits and participant debits.
type Expense struct {
	Payers map[uuid.UUID]int64
	Shares map[uuid.UUID]int64
}

// Payment is a confirmed settlement from Payer to Payee.
type Payment struct {
	Payer  uuid.UUID
	Payee  uuid.UUID
	Amount int64
}

// Balance is a member's net position: positive = is owed, negative = owes.
type Balance struct {
	UserID   uuid.UUID
	NetMinor int64
	Paid     int64
	Share    int64
	SentSet  int64
	RecvSet  int64
}

// Transfer is a suggested payment From → To.
type Transfer struct {
	From   uuid.UUID
	To     uuid.UUID
	Amount int64
}

// Compute derives net balances. Members with no activity are included if
// listed in members.
func Compute(members []uuid.UUID, expenses []Expense, payments []Payment) []Balance {
	idx := map[uuid.UUID]*Balance{}
	get := func(id uuid.UUID) *Balance {
		b, ok := idx[id]
		if !ok {
			b = &Balance{UserID: id}
			idx[id] = b
		}
		return b
	}
	for _, m := range members {
		get(m)
	}
	for _, e := range expenses {
		for u, a := range e.Payers {
			b := get(u)
			b.Paid += a
			b.NetMinor += a
		}
		for u, a := range e.Shares {
			b := get(u)
			b.Share += a
			b.NetMinor -= a
		}
	}
	for _, p := range payments {
		// Paying reduces what the payer owes (net up) and what the payee is owed (net down).
		get(p.Payer).NetMinor += p.Amount
		get(p.Payer).SentSet += p.Amount
		get(p.Payee).NetMinor -= p.Amount
		get(p.Payee).RecvSet += p.Amount
	}
	out := make([]Balance, 0, len(idx))
	for _, b := range idx {
		out = append(out, *b)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].UserID.String() < out[j].UserID.String() })
	return out
}

// PairwiseDebts returns the original (unsimplified) debts implied by each
// expense: each participant owes each payer in proportion to the payer's
// part of the expense, netted per pair. Each proportional part is rounded
// down or up so that a participant's parts add up to their share and a
// payer's parts add up to what they paid (see allocate). Every member's
// position in these debts (received minus paid) therefore equals their net
// balance exactly, as it does in Simplify: both views add up to the same
// totals. The rounding is deterministic.
func PairwiseDebts(expenses []Expense, payments []Payment) []Transfer {
	type pair struct{ a, b uuid.UUID }
	net := map[pair]int64{} // positive: a owes b
	add := func(debtor, creditor uuid.UUID, amt int64) {
		if debtor == creditor || amt == 0 {
			return
		}
		if debtor.String() < creditor.String() {
			net[pair{debtor, creditor}] += amt
		} else {
			net[pair{creditor, debtor}] -= amt
		}
	}
	for _, e := range expenses {
		payers := make([]uuid.UUID, 0, len(e.Payers))
		for u := range e.Payers {
			payers = append(payers, u)
		}
		sort.Slice(payers, func(i, j int) bool {
			if e.Payers[payers[i]] != e.Payers[payers[j]] {
				return e.Payers[payers[i]] > e.Payers[payers[j]]
			}
			return payers[i].String() < payers[j].String()
		})
		debtors := make([]uuid.UUID, 0, len(e.Shares))
		for u := range e.Shares {
			debtors = append(debtors, u)
		}
		sort.Slice(debtors, func(i, j int) bool { return debtors[i].String() < debtors[j].String() })
		paid := make([]int64, len(payers))
		for j, p := range payers {
			paid[j] = e.Payers[p]
		}
		shares := make([]int64, len(debtors))
		for i, d := range debtors {
			shares[i] = e.Shares[d]
		}
		parts := allocate(shares, paid)
		for i, d := range debtors {
			for j, p := range payers {
				add(d, p, parts[i][j])
			}
		}
	}
	for _, p := range payments {
		add(p.Payer, p.Payee, -p.Amount)
	}
	var out []Transfer
	for k, v := range net {
		switch {
		case v > 0:
			out = append(out, Transfer{From: k.a, To: k.b, Amount: v})
		case v < 0:
			out = append(out, Transfer{From: k.b, To: k.a, Amount: -v})
		}
	}
	sortTransfers(out)
	return out
}

// allocate splits each participant's share between the payers in
// proportion to what they paid: cell (i, j) is shares[i]×paid[j]/total
// rounded down or up (a controlled rounding), chosen so that row i adds up
// to shares[i] and column j adds up to paid[j]. Such a rounding exists for
// any matrix whose rows and columns add up to whole numbers (the
// transportation polytope is integral), and augmenting paths find one. The
// leftover units go to the largest remainders first, then by position, so
// the result is deterministic. When the shares do not add up to what was
// paid (records that do not reconcile), each share is still split exactly
// and the last payer absorbs the rounding.
func allocate(shares, paid []int64) [][]int64 {
	out := make([][]int64, len(shares))
	for i := range out {
		out[i] = make([]int64, len(paid))
	}
	var total, shareTotal int64
	for _, p := range paid {
		total += p
	}
	for _, s := range shares {
		shareTotal += s
	}
	if total <= 0 || len(paid) == 0 {
		return out
	}
	bigTotal := big.NewInt(total)
	type cell struct {
		i, j int
		rem  *big.Int
	}
	var cells []cell
	rowNeed, colNeed := make([]int64, len(shares)), make([]int64, len(paid))
	copy(colNeed, paid)
	for i, s := range shares {
		rowNeed[i] = s
		for j, p := range paid {
			q, r := new(big.Int).QuoRem(new(big.Int).Mul(big.NewInt(s), big.NewInt(p)), bigTotal, new(big.Int))
			out[i][j] = q.Int64()
			rowNeed[i] -= out[i][j]
			colNeed[j] -= out[i][j]
			if r.Sign() > 0 {
				cells = append(cells, cell{i, j, r})
			}
		}
	}
	if shareTotal != total {
		return loose(out, rowNeed)
	}
	sort.SliceStable(cells, func(a, b int) bool {
		if c := cells[a].rem.Cmp(cells[b].rem); c != 0 {
			return c > 0
		}
		if cells[a].i != cells[b].i {
			return cells[a].i < cells[b].i
		}
		return cells[a].j < cells[b].j
	})
	// Each cell takes at most one extra unit. Greedy first (largest
	// remainders), then augmenting paths place whatever is left.
	extra := make([][]bool, len(shares))
	for i := range extra {
		extra[i] = make([]bool, len(paid))
	}
	adj := make([][]int, len(shares))
	for _, c := range cells {
		adj[c.i] = append(adj[c.i], c.j)
		if rowNeed[c.i] > 0 && colNeed[c.j] > 0 {
			extra[c.i][c.j] = true
			rowNeed[c.i]--
			colNeed[c.j]--
		}
	}
	// augment finds a path row i → column (via a cell without an extra
	// unit) → row holding that column's unit → … → a column that still
	// needs a unit, and moves the units along it.
	var augment func(i int, seen []bool) bool
	augment = func(i int, seen []bool) bool {
		for _, j := range adj[i] {
			if extra[i][j] || seen[j] {
				continue
			}
			seen[j] = true
			if colNeed[j] > 0 {
				extra[i][j] = true
				colNeed[j]--
				return true
			}
			for k := range extra {
				if extra[k][j] && augment(k, seen) {
					extra[k][j], extra[i][j] = false, true
					return true
				}
			}
		}
		return false
	}
	for progress := true; progress; {
		progress = false
		for i := range rowNeed {
			for rowNeed[i] > 0 && augment(i, make([]bool, len(paid))) {
				rowNeed[i]--
				progress = true
			}
		}
	}
	for i := range rowNeed {
		if rowNeed[i] != 0 {
			return loose(out, firstNeeds(shares, out))
		}
	}
	for i := range extra {
		for j, x := range extra[i] {
			if x {
				out[i][j]++
			}
		}
	}
	return out
}

// firstNeeds is what each row of the floored allocation still lacks.
func firstNeeds(shares []int64, floored [][]int64) []int64 {
	need := make([]int64, len(shares))
	for i, s := range shares {
		need[i] = s
		for _, v := range floored[i] {
			need[i] -= v
		}
	}
	return need
}

// loose completes each row of a floored allocation by giving its residue to
// the last payer (rows exact, columns approximate).
func loose(floored [][]int64, need []int64) [][]int64 {
	for i, row := range floored {
		if len(row) > 0 {
			row[len(row)-1] += need[i]
		}
	}
	return floored
}

// Simplify proposes a minimal-ish set of transfers that settles all net
// balances (greedy largest debtor ↔ largest creditor, deterministic order).
// The sum of transfers equals the sum of positive balances exactly.
func Simplify(balances []Balance) []Transfer {
	type entry struct {
		id  uuid.UUID
		amt int64
	}
	var debtors, creditors []entry
	for _, b := range balances {
		switch {
		case b.NetMinor < 0:
			debtors = append(debtors, entry{b.UserID, -b.NetMinor})
		case b.NetMinor > 0:
			creditors = append(creditors, entry{b.UserID, b.NetMinor})
		}
	}
	order := func(s []entry) {
		sort.Slice(s, func(i, j int) bool {
			if s[i].amt != s[j].amt {
				return s[i].amt > s[j].amt
			}
			return s[i].id.String() < s[j].id.String()
		})
	}
	var out []Transfer
	for len(debtors) > 0 && len(creditors) > 0 {
		order(debtors)
		order(creditors)
		d, c := &debtors[0], &creditors[0]
		amt := d.amt
		if c.amt < amt {
			amt = c.amt
		}
		out = append(out, Transfer{From: d.id, To: c.id, Amount: amt})
		d.amt -= amt
		c.amt -= amt
		if d.amt == 0 {
			debtors = debtors[1:]
		}
		if c.amt == 0 {
			creditors = creditors[1:]
		}
	}
	return out
}

// Between returns the net amount `a` owes `b` from balances' pairwise debts.
func Between(transfers []Transfer, a, b uuid.UUID) int64 {
	var n int64
	for _, t := range transfers {
		if t.From == a && t.To == b {
			n += t.Amount
		} else if t.From == b && t.To == a {
			n -= t.Amount
		}
	}
	return n
}

func sortTransfers(ts []Transfer) {
	sort.Slice(ts, func(i, j int) bool {
		if ts[i].From != ts[j].From {
			return ts[i].From.String() < ts[j].From.String()
		}
		return ts[i].To.String() < ts[j].To.String()
	})
}
