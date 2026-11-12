package split

import (
	"errors"
	"testing"
)

func sum(xs []int64) int64 {
	var s int64
	for _, x := range xs {
		s += x
	}
	return s
}

func eq(a, b []int64) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestEqual(t *testing.T) {
	got, err := Equal(1000, 3) // 10.00 / 3
	if err != nil || !eq(got, []int64{334, 333, 333}) {
		t.Fatalf("Equal = %v, %v", got, err)
	}
	got, _ = Equal(1001, 3)
	if !eq(got, []int64{334, 334, 333}) {
		t.Fatalf("Equal(1001,3) = %v", got)
	}
	got, _ = Equal(1, 4)
	if !eq(got, []int64{1, 0, 0, 0}) || sum(got) != 1 {
		t.Fatalf("Equal(1,4) = %v", got)
	}
	if _, err := Equal(100, 0); !errors.Is(err, ErrNoParticipants) {
		t.Fatal("expected ErrNoParticipants")
	}
	if _, err := Equal(0, 2); !errors.Is(err, ErrNonPositive) {
		t.Fatal("expected ErrNonPositive")
	}
}

func TestByWeights(t *testing.T) {
	got, err := ByWeights(1000, []int64{1, 2, 0, 1}) // excluded participant gets 0
	if err != nil || !eq(got, []int64{250, 500, 0, 250}) {
		t.Fatalf("got %v %v", got, err)
	}
	got, _ = ByWeights(100, []int64{1, 1, 1})
	if !eq(got, []int64{34, 33, 33}) {
		t.Fatalf("got %v", got)
	}
	if _, err := ByWeights(100, []int64{0, 0}); !errors.Is(err, ErrWeights) {
		t.Fatal("expected ErrWeights")
	}
	if _, err := ByWeights(100, []int64{-1, 2}); !errors.Is(err, ErrWeights) {
		t.Fatal("expected ErrWeights")
	}
	// Large values must not overflow.
	got, err = ByWeights(1_000_000_000_000_000, []int64{1_000_000_000, 3_000_000_000})
	if err != nil || sum(got) != 1_000_000_000_000_000 || got[0] != 250_000_000_000_000 {
		t.Fatalf("large = %v %v", got, err)
	}
}

func TestPercentages(t *testing.T) {
	bp := []int64{}
	for _, s := range []string{"33.33", "33.33", "33.34"} {
		v, err := ParsePercent(s)
		if err != nil {
			t.Fatal(err)
		}
		bp = append(bp, v)
	}
	got, err := ByPercentages(10000, bp)
	if err != nil || sum(got) != 10000 || !eq(got, []int64{3333, 3333, 3334}) {
		t.Fatalf("got %v %v", got, err)
	}
	if _, err := ByPercentages(100, []int64{5000, 4000}); !errors.Is(err, ErrPercentSum) {
		t.Fatal("expected ErrPercentSum")
	}
	if _, err := ParsePercent("33.333"); !errors.Is(err, ErrPercentFormat) {
		t.Fatal("expected ErrPercentFormat")
	}
	if _, err := ParsePercent("101"); !errors.Is(err, ErrPercentSum) {
		t.Fatal("expected ErrPercentSum for >100")
	}
}

func TestExact(t *testing.T) {
	if _, err := Exact(100, []int64{50, 50}); err != nil {
		t.Fatal(err)
	}
	if _, err := Exact(100, []int64{50, 49}); !errors.Is(err, ErrSumMismatch) {
		t.Fatal("expected mismatch")
	}
	if _, err := Exact(100, []int64{150, -50}); err == nil {
		t.Fatal("negative accepted")
	}
}

func TestItemized(t *testing.T) {
	// Two items + 10.00 tax/tip distributed by item subtotals.
	items := []Item{
		{AmountMinor: 6000, Weights: []int64{1, 1, 0}}, // A,B share 60.00
		{AmountMinor: 3000, Weights: []int64{0, 0, 1}}, // C alone 30.00
	}
	got, err := Itemized(10000, 3, items)
	if err != nil || sum(got) != 10000 {
		t.Fatalf("got %v %v", got, err)
	}
	// subtotals 3000/3000/3000 → extra 1000 split 334/333/333
	if !eq(got, []int64{3334, 3333, 3333}) {
		t.Fatalf("got %v", got)
	}
	if _, err := Itemized(5000, 3, items); !errors.Is(err, ErrSumMismatch) {
		t.Fatal("items exceeding total accepted")
	}
}

// FuzzByWeights asserts the core invariant: allocations always sum exactly
// to the total, are non-negative, and zero-weight participants get zero.
func FuzzByWeights(f *testing.F) {
	f.Add(int64(1000), int64(1), int64(2), int64(3))
	f.Add(int64(1), int64(0), int64(5), int64(5))
	f.Fuzz(func(t *testing.T, total, a, b, c int64) {
		if total <= 0 || total > 1_000_000_000_000_000 || a < 0 || b < 0 || c < 0 || a > 1e12 || b > 1e12 || c > 1e12 {
			return
		}
		w := []int64{a, b, c}
		got, err := ByWeights(total, w)
		if a+b+c == 0 {
			if err == nil {
				t.Fatal("expected error for zero weights")
			}
			return
		}
		if err != nil {
			t.Fatal(err)
		}
		if sum(got) != total {
			t.Fatalf("sum %d != %d (%v)", sum(got), total, got)
		}
		for i, g := range got {
			if g < 0 || (w[i] == 0 && g != 0) {
				t.Fatalf("bad allocation %v for weights %v", got, w)
			}
		}
	})
}
