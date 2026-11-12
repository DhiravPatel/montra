package subdetect

import (
	"fmt"
	"testing"
	"time"
)

func d(y int, m time.Month, day int) time.Time { return time.Date(y, m, day, 0, 0, 0, 0, time.UTC) }

func series(start time.Time, n int, step func(time.Time, int) time.Time, amount func(int) int64) []Charge {
	var out []Charge
	for i := 0; i < n; i++ {
		out = append(out, Charge{ID: fmt.Sprintf("t%d", i), Date: step(start, i), Amount: amount(i)})
	}
	return out
}

func monthly(start time.Time, i int) time.Time { return start.AddDate(0, i, 0) }

func TestMonthlySubscriptionDetectedWithEvidence(t *testing.T) {
	cs := series(d(2026, 5, 3), 6, monthly, func(int) int64 { return 64900 })
	c, ok := Detect(cs, d(2026, 11, 1))
	if !ok || c.Cadence != "monthly" || c.Amount != 64900 || len(c.EvidenceIDs) != 6 {
		t.Fatalf("got %+v ok=%v", c, ok)
	}
	if c.ConfidenceMilli < 950 || c.NextExpected != d(2026, 11, 3) || len(c.Reasons) != 3 {
		t.Fatalf("confidence/next/reasons wrong: %+v", c)
	}
}

func TestMonthEndBillingAndPriceIncrease(t *testing.T) {
	// Charged on month ends (28-31 day intervals) with a price rise.
	dates := []time.Time{d(2026, 1, 31), d(2026, 2, 28), d(2026, 3, 31), d(2026, 4, 30), d(2026, 5, 31), d(2026, 6, 30)}
	var cs []Charge
	for i, dt := range dates {
		amt := int64(19900)
		if i >= 4 {
			amt = 20500 // +3%: still within tolerance
		}
		cs = append(cs, Charge{ID: fmt.Sprint(i), Date: dt, Amount: amt})
	}
	c, ok := Detect(cs, d(2026, 7, 10))
	if !ok || c.Cadence != "monthly" || len(c.EvidenceIDs) != 6 {
		t.Fatalf("got %+v ok=%v", c, ok)
	}
}

func TestIrregularOrVaryingChargesRejected(t *testing.T) {
	// Grocery-like: irregular intervals and amounts.
	cs := []Charge{{"a", d(2026, 1, 2), 1200}, {"b", d(2026, 1, 19), 8700}, {"c", d(2026, 3, 1), 450}, {"d", d(2026, 3, 9), 3000}}
	if c, ok := Detect(cs, d(2026, 3, 10)); ok {
		t.Fatalf("irregular series detected: %+v", c)
	}
	// Regular cadence but wildly varying amounts (utility-like) → not a subscription.
	cs = series(d(2026, 1, 5), 6, monthly, func(i int) int64 { return int64(1000 + i*900) })
	if c, ok := Detect(cs, d(2026, 6, 20)); ok {
		t.Fatalf("varying amounts detected: %+v", c)
	}
}

func TestTwoChargesOnlyForYearlyAndStaleSeries(t *testing.T) {
	cs := series(d(2026, 1, 5), 2, monthly, func(int) int64 { return 500 })
	if _, ok := Detect(cs, d(2026, 2, 10)); ok {
		t.Fatal("two monthly charges are not enough evidence")
	}
	cs = []Charge{{"y1", d(2025, 3, 1), 99900}, {"y2", d(2026, 3, 1), 99900}}
	c, ok := Detect(cs, d(2026, 6, 1))
	if !ok || c.Cadence != "yearly" || c.NextExpected != d(2027, 3, 1) {
		t.Fatalf("yearly: %+v ok=%v", c, ok)
	}
	// A monthly series that stopped three months ago is stale.
	cs = series(d(2026, 1, 5), 5, monthly, func(int) int64 { return 500 })
	if _, ok := Detect(cs, d(2026, 8, 20)); ok {
		t.Fatal("stale series must not be suggested")
	}
}

func TestWeeklyAndSameDayRetriesCollapsed(t *testing.T) {
	cs := series(d(2026, 9, 1), 5, func(s time.Time, i int) time.Time { return s.AddDate(0, 0, 7*i) }, func(int) int64 { return 9900 })
	cs = append(cs, Charge{ID: "retry", Date: d(2026, 9, 8), Amount: 9900}) // duplicate same-day charge
	c, ok := Detect(cs, d(2026, 10, 1))
	if !ok || c.Cadence != "weekly" || len(c.IntervalsDays) != 4 {
		t.Fatalf("weekly: %+v ok=%v", c, ok)
	}
}
