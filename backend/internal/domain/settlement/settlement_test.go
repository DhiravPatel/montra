package settlement

import (
	"math/big"
	"math/rand/v2"
	"testing"

	"github.com/google/uuid"
)

var (
	a = uuid.MustParse("00000000-0000-0000-0000-00000000000a")
	b = uuid.MustParse("00000000-0000-0000-0000-00000000000b")
	c = uuid.MustParse("00000000-0000-0000-0000-00000000000c")
)

func net(bs []Balance) map[uuid.UUID]int64 {
	m := map[uuid.UUID]int64{}
	for _, x := range bs {
		m[x.UserID] = x.NetMinor
	}
	return m
}

func TestComputeAndSimplify(t *testing.T) {
	// A paid 30.00 split equally among A,B,C; B paid 15.00 split A,B.
	exps := []Expense{
		{Payers: map[uuid.UUID]int64{a: 3000}, Shares: map[uuid.UUID]int64{a: 1000, b: 1000, c: 1000}},
		{Payers: map[uuid.UUID]int64{b: 1500}, Shares: map[uuid.UUID]int64{a: 750, b: 750}},
	}
	bal := Compute([]uuid.UUID{a, b, c}, exps, nil)
	n := net(bal)
	if n[a] != 1250 || n[b] != -250 || n[c] != -1000 {
		t.Fatalf("net = %v", n)
	}
	var total int64
	for _, x := range bal {
		total += x.NetMinor
	}
	if total != 0 {
		t.Fatalf("balances must net to zero, got %d", total)
	}
	tr := Simplify(bal)
	var paid int64
	for _, x := range tr {
		paid += x.Amount
	}
	if paid != 1250 || len(tr) != 2 {
		t.Fatalf("simplified = %+v", tr)
	}
	// Partial settlement: C pays A 4.00 → C now owes 6.00.
	bal = Compute([]uuid.UUID{a, b, c}, exps, []Payment{{Payer: c, Payee: a, Amount: 400}})
	n = net(bal)
	if n[c] != -600 || n[a] != 850 {
		t.Fatalf("after partial = %v", n)
	}
}

func TestPairwiseDebts(t *testing.T) {
	exps := []Expense{
		{Payers: map[uuid.UUID]int64{a: 3000}, Shares: map[uuid.UUID]int64{a: 1000, b: 1000, c: 1000}},
		{Payers: map[uuid.UUID]int64{b: 1500}, Shares: map[uuid.UUID]int64{a: 750, b: 750}},
	}
	d := PairwiseDebts(exps, nil)
	// b owes a 1000, a owes b 750 → b owes a 250; c owes a 1000.
	if Between(d, b, a) != 250 || Between(d, c, a) != 1000 {
		t.Fatalf("pairwise = %+v", d)
	}
	// Multiple payers with remainder.
	exps = []Expense{{Payers: map[uuid.UUID]int64{a: 667, b: 333}, Shares: map[uuid.UUID]int64{c: 1000}}}
	d = PairwiseDebts(exps, nil)
	if Between(d, c, a)+Between(d, c, b) != 1000 {
		t.Fatalf("multi-payer sum mismatch: %+v", d)
	}
}

// position is what a member receives minus what they pay in transfers.
func position(ts []Transfer) map[uuid.UUID]int64 {
	m := map[uuid.UUID]int64{}
	for _, x := range ts {
		m[x.To] += x.Amount
		m[x.From] -= x.Amount
	}
	return m
}

// Every member's position in the original debts and in the simplified
// transfers equals their net balance, even when splitting shares between
// several payers leaves rounding residue (here 1 unit per participant and
// payer: floor(1×1/3) = 0 everywhere).
func TestPairwiseDebtsReconcileWithBalances(t *testing.T) {
	d, e, f := uuid.New(), uuid.New(), uuid.New()
	exps := []Expense{{Payers: map[uuid.UUID]int64{a: 1, b: 1, c: 1}, Shares: map[uuid.UUID]int64{d: 1, e: 1, f: 1}}}
	bal := Compute(nil, exps, nil)
	orig, simple := position(PairwiseDebts(exps, nil)), position(Simplify(bal))
	for id, want := range net(bal) {
		if orig[id] != want || simple[id] != want {
			t.Fatalf("%s: net %d, original debts %d, simplified %d", id, want, orig[id], simple[id])
		}
	}
	// Proportional parts stay within one unit: each payer receives exactly 1.
	for _, p := range []uuid.UUID{a, b, c} {
		if orig[p] != 1 {
			t.Fatalf("payer %s receives %d", p, orig[p])
		}
	}
}

func TestPairwiseDebtsReconcileRandomized(t *testing.T) {
	rng := rand.New(rand.NewPCG(7, 11))
	people := make([]uuid.UUID, 7)
	for i := range people {
		people[i] = uuid.New()
	}
	for round := 0; round < 400; round++ {
		var exps []Expense
		for n := 1 + rng.IntN(5); n > 0; n-- {
			total := int64(1 + rng.IntN(100000))
			e := Expense{Payers: map[uuid.UUID]int64{}, Shares: map[uuid.UUID]int64{}}
			// Up to 4 payers (each paid something) and any participants
			// (zero shares allowed), both adding up to the total.
			payers := rng.Perm(len(people))[:1+rng.IntN(4)]
			for k, amt := range split(rng, total, len(payers)) {
				if amt > 0 {
					e.Payers[people[payers[k]]] = amt
				}
			}
			sharers := rng.Perm(len(people))[:1+rng.IntN(len(people))]
			for k, amt := range split(rng, total, len(sharers)) {
				e.Shares[people[sharers[k]]] = amt
			}
			exps = append(exps, e)
		}
		var pays []Payment
		for n := rng.IntN(3); n > 0; n-- {
			i, j := rng.IntN(len(people)), rng.IntN(len(people))
			if i != j {
				pays = append(pays, Payment{Payer: people[i], Payee: people[j], Amount: int64(1 + rng.IntN(5000))})
			}
		}
		bal := Compute(people, exps, pays)
		first := PairwiseDebts(exps, pays)
		orig, simple := position(first), position(Simplify(bal))
		for id, want := range net(bal) {
			if orig[id] != want || simple[id] != want {
				t.Fatalf("round %d, %s: net %d, original debts %d, simplified %d", round, id, want, orig[id], simple[id])
			}
		}
		// Deterministic whatever the map iteration order.
		for k := 0; k < 3; k++ {
			again := PairwiseDebts(exps, pays)
			if len(again) != len(first) {
				t.Fatalf("round %d: non-deterministic debts", round)
			}
			for x := range again {
				if again[x] != first[x] {
					t.Fatalf("round %d: non-deterministic debts %+v vs %+v", round, again[x], first[x])
				}
			}
		}
	}
}

// allocate rounds each proportional part down or up, never further, while
// rows add up to the shares and columns to what each payer paid.
func TestAllocateControlledRounding(t *testing.T) {
	rng := rand.New(rand.NewPCG(3, 5))
	for round := 0; round < 500; round++ {
		total := int64(1 + rng.IntN(1_000_000))
		paid := split(rng, total, 1+rng.IntN(5))
		shares := split(rng, total, 1+rng.IntN(9))
		out := allocate(shares, paid)
		for i, s := range shares {
			var sum int64
			for j, p := range paid {
				exact := new(big.Rat).SetFrac(new(big.Int).Mul(big.NewInt(s), big.NewInt(p)), big.NewInt(total))
				lo := new(big.Int).Quo(exact.Num(), exact.Denom()).Int64()
				hi := lo
				if !exact.IsInt() {
					hi++
				}
				if out[i][j] < lo || out[i][j] > hi {
					t.Fatalf("round %d cell (%d,%d) = %d, exact %s", round, i, j, out[i][j], exact.FloatString(3))
				}
				sum += out[i][j]
			}
			if sum != s {
				t.Fatalf("round %d row %d adds up to %d, share %d", round, i, sum, s)
			}
		}
		for j, p := range paid {
			var sum int64
			for i := range shares {
				sum += out[i][j]
			}
			if sum != p {
				t.Fatalf("round %d column %d adds up to %d, paid %d", round, j, sum, p)
			}
		}
	}
	// Records that do not reconcile still split every share exactly.
	out := allocate([]int64{5, 6}, []int64{4, 4})
	if out[0][0]+out[0][1] != 5 || out[1][0]+out[1][1] != 6 {
		t.Fatalf("unreconciled allocation = %v", out)
	}
}

// split divides total into n positive-or-zero parts.
func split(rng *rand.Rand, total int64, n int) []int64 {
	parts := make([]int64, n)
	left := total
	for i := 0; i < n-1; i++ {
		parts[i] = rng.Int64N(left + 1)
		left -= parts[i]
	}
	parts[n-1] = left
	return parts
}

func TestSimplifyDeterministic(t *testing.T) {
	bal := []Balance{{UserID: a, NetMinor: 500}, {UserID: b, NetMinor: 500}, {UserID: c, NetMinor: -1000}}
	first := Simplify(bal)
	for i := 0; i < 20; i++ {
		again := Simplify(bal)
		if len(again) != len(first) {
			t.Fatal("non-deterministic")
		}
		for j := range again {
			if again[j] != first[j] {
				t.Fatal("non-deterministic order")
			}
		}
	}
}
