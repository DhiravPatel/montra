package reconcile

import (
	"slices"
	"testing"
	"time"
)

func d(day int) time.Time { return time.Date(2025, 10, day, 0, 0, 0, 0, time.UTC) }

func TestScoreRequiresAmountAndDirection(t *testing.T) {
	a := Item{ID: "r1", Date: d(5), AmountMinor: 49900, Direction: "outflow", Description: "STREAMING CO MONTHLY", Reference: "UPI-77"}
	if s, _ := Score(a, Item{ID: "t", Date: d(5), AmountMinor: 49901, Direction: "outflow"}); s != 0 {
		t.Fatal("different amounts must not match")
	}
	if s, _ := Score(a, Item{ID: "t", Date: d(5), AmountMinor: 49900, Direction: "inflow"}); s != 0 {
		t.Fatal("different directions must not match")
	}
	if s, _ := Score(a, Item{ID: "t", Date: d(20), AmountMinor: 49900, Direction: "outflow"}); s != 0 {
		t.Fatal("dates more than a week apart must not match")
	}
	full, why := Score(a, Item{ID: "t", Date: d(5), AmountMinor: 49900, Direction: "outflow", Description: "Streaming Co", Reference: "upi 77"})
	near, _ := Score(a, Item{ID: "t", Date: d(7), AmountMinor: 49900, Direction: "outflow", Description: "Groceries"})
	far, _ := Score(a, Item{ID: "t", Date: d(9), AmountMinor: 49900, Direction: "outflow", Description: "Groceries"})
	if full != 1000 || len(why) != 4 || near >= full || near < MinConfidenceMilli || far >= MinConfidenceMilli || far == 0 {
		t.Fatalf("full=%d (%v) near=%d far=%d", full, why, near, far)
	}
}

func TestBestOneToOneUsesEachItemOnce(t *testing.T) {
	left := []Item{{ID: "a", Date: d(1), AmountMinor: 100, Direction: "outflow"}, {ID: "b", Date: d(2), AmountMinor: 100, Direction: "outflow"}}
	right := []Item{{ID: "x", Date: d(2), AmountMinor: 100, Direction: "outflow"}, {ID: "y", Date: d(1), AmountMinor: 100, Direction: "outflow"}}
	got := BestOneToOne(left, right, MinConfidenceMilli)
	if len(got) != 2 || got[0].Left.ID == got[1].Left.ID || got[0].Right[0].ID == got[1].Right[0].ID {
		t.Fatalf("assignment = %+v", got)
	}
	for _, c := range got {
		if (c.Left.ID == "a" && c.Right[0].ID != "y") || (c.Left.ID == "b" && c.Right[0].ID != "x") {
			t.Fatalf("closest dates should pair: %+v", got)
		}
	}
}

func TestOneToManyExactSum(t *testing.T) {
	left := Item{ID: "s", Date: d(10), AmountMinor: 3500, Direction: "outflow"}
	right := []Item{{ID: "1", Date: d(8), AmountMinor: 1000, Direction: "outflow"}, {ID: "2", Date: d(9), AmountMinor: 2500, Direction: "outflow"},
		{ID: "3", Date: d(9), AmountMinor: 700, Direction: "outflow"}, {ID: "4", Date: d(9), AmountMinor: 2500, Direction: "inflow"}}
	c, ok := OneToMany(left, right, 3)
	if !ok || len(c.Right) != 2 || c.Right[0].AmountMinor+c.Right[1].AmountMinor != 3500 {
		t.Fatalf("one-to-many = %+v %v", c, ok)
	}
	if _, ok := OneToMany(Item{ID: "s", Date: d(10), AmountMinor: 9999, Direction: "outflow"}, right, 3); ok {
		t.Fatal("no exact subset should be found")
	}
}

func TestReasonsCarryStableCodesAndDateDistance(t *testing.T) {
	a := Item{ID: "r", Date: d(5), AmountMinor: 100, Direction: "outflow", Description: "Coffee House Central", Reference: "R-1"}
	_, why := Score(a, Item{ID: "t", Date: d(7), AmountMinor: 100, Direction: "outflow", Description: "coffee house", Reference: "r1"})
	want := []string{ReasonSameAmountDirection, ReasonWithin3Days, ReasonSameReference, ReasonSimilarDescription}
	if !slices.Equal(Codes(why), want) || !slices.Equal(Texts(why), []string{"Same amount and direction", "Within 3 days", "Same reference",
		"Similar description"}) {
		t.Fatalf("reasons = %+v", why)
	}
	got := BestOneToOne([]Item{a}, []Item{{ID: "x", Date: d(1), AmountMinor: 100, Direction: "outflow", Description: "coffee house central"}},
		MinConfidenceMilli)
	if len(got) != 1 || got[0].DaysApart != 4 || got[0].Reasons[1].Code != ReasonWithinWeek {
		t.Fatalf("one-to-one = %+v", got)
	}
	c, ok := OneToMany(Item{ID: "s", Date: d(10), AmountMinor: 300, Direction: "outflow"},
		[]Item{{ID: "1", Date: d(4), AmountMinor: 100, Direction: "outflow"}, {ID: "2", Date: d(9), AmountMinor: 200, Direction: "outflow"}}, 3)
	if !ok || c.DaysApart != 6 || !slices.Equal(Codes(c.Reasons), []string{ReasonAmountsAddUp, ReasonAllWithinWeek}) {
		t.Fatalf("one-to-many = %+v %v", c, ok)
	}
	if Codes(nil) == nil || Texts(nil) == nil {
		t.Fatal("empty reason lists must not be nil (they are serialized)")
	}
}
