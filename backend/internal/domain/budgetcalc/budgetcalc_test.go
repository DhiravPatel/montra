package budgetcalc

import "testing"

func TestComputePaceAndProjection(t *testing.T) {
	p := Compute(30000, 15000, 10, 30) // ₹300 budget, ₹150 spent after 10/30 days
	if p.Pace != PaceAhead || p.ProjectedMinor != 45000 || p.ProjectedOverMinor != 15000 || p.PercentBP != 5000 {
		t.Fatalf("progress = %+v", p)
	}
	if p.RemainingMinor != 15000 || p.DailyAllowanceMinor != 750 {
		t.Fatalf("remaining/allowance = %+v", p)
	}
	if p = Compute(30000, 10000, 10, 30); p.Pace != PaceOnTrack {
		t.Fatalf("even pace = %s", p.Pace)
	}
	if p = Compute(30000, 5000, 10, 30); p.Pace != PaceUnder {
		t.Fatalf("slow pace = %s", p.Pace)
	}
	if p = Compute(30000, 31000, 10, 30); p.Pace != PaceOver || p.OverspentMinor != 1000 || p.RemainingMinor != 0 {
		t.Fatalf("over = %+v", p)
	}
	if p = Compute(0, 500, 1, 30); p.PercentBP != 0 || p.Pace != PaceOver {
		t.Fatalf("zero limit = %+v", p)
	}
}

func TestRolloverPolicies(t *testing.T) {
	cap := int64(5000)
	cases := []struct {
		policy       string
		limit, spent int64
		cap          *int64
		want         int64
	}{
		{"none", 100, 50, nil, 0},
		{"carry_unused", 10000, 7000, nil, 3000},
		{"carry_unused", 10000, 12000, nil, 0},
		{"carry_overspend", 10000, 12000, nil, -2000},
		{"carry_both", 10000, 2000, &cap, 5000},
		{"carry_both", 10000, 20000, &cap, -5000},
	}
	for _, c := range cases {
		if got := Rollover(c.policy, c.limit, c.spent, c.cap); got != c.want {
			t.Errorf("%s(%d,%d) = %d want %d", c.policy, c.limit, c.spent, got, c.want)
		}
	}
}

func TestThresholdCrossingIsSingleShot(t *testing.T) {
	th := []int16{50, 75, 90, 100}
	if got := CrossedThresholds(4000, 7600, 10000, th); len(got) != 2 || got[0] != 50 || got[1] != 75 {
		t.Fatalf("crossed = %v", got)
	}
	if got := CrossedThresholds(7600, 7700, 10000, th); len(got) != 0 {
		t.Fatalf("no new crossing expected, got %v", got)
	}
	// A refund lowering spend never "re-crosses"; reached lists everything at or below spend.
	if got := ReachedThresholds(9000, 10000, th); len(got) != 3 {
		t.Fatalf("reached = %v", got)
	}
}
