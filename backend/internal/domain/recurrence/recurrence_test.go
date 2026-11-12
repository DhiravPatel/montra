package recurrence

import (
	"testing"
	"time"
)

func d(y int, m time.Month, day int) time.Time { return time.Date(y, m, day, 0, 0, 0, 0, time.UTC) }

func dates(ts []time.Time) []string {
	var out []string
	for _, t := range ts {
		out = append(out, t.Format("2006-01-02"))
	}
	return out
}

func eq(t *testing.T, got []time.Time, want ...string) {
	t.Helper()
	g := dates(got)
	if len(g) != len(want) {
		t.Fatalf("got %v want %v", g, want)
	}
	for i := range want {
		if g[i] != want[i] {
			t.Fatalf("got %v want %v", g, want)
		}
	}
}

func TestMonthEndNoDriftAndLeapYear(t *testing.T) {
	r := Rule{Frequency: Monthly, Start: d(2027, 12, 31)}
	eq(t, r.Between(d(2027, 12, 1), d(2028, 4, 30), 10), "2027-12-31", "2028-01-31", "2028-02-29", "2028-03-31", "2028-04-30")
	r = Rule{Frequency: Monthly, ByMonthDay: -1, Start: d(2026, 1, 15)}
	eq(t, r.Between(d(2026, 1, 1), d(2026, 3, 31), 10), "2026-01-31", "2026-02-28", "2026-03-31")
	for _, day := range []int{28, 29, 30, 31} {
		r = Rule{Frequency: Monthly, ByMonthDay: day, Start: d(2026, 1, 1)}
		feb := r.Between(d(2026, 2, 1), d(2026, 2, 28), 2)
		if len(feb) != 1 || feb[0].Day() != 28 {
			t.Fatalf("day %d in Feb 2026 → %v", day, dates(feb))
		}
	}
	r = Rule{Frequency: Yearly, Start: d(2024, 2, 29)}
	eq(t, r.Between(d(2024, 1, 1), d(2028, 12, 31), 10), "2024-02-29", "2025-02-28", "2026-02-28", "2027-02-28", "2028-02-29")
}

func TestWeeklyBiweeklyWeekdayAndCustom(t *testing.T) {
	mon := time.Monday
	r := Rule{Frequency: Weekly, ByWeekday: &mon, Start: d(2026, 11, 4)} // Wed → first Monday after
	eq(t, r.Between(d(2026, 11, 1), d(2026, 11, 30), 10), "2026-11-09", "2026-11-16", "2026-11-23", "2026-11-30")
	r = Rule{Frequency: Biweekly, Start: d(2026, 11, 6)}
	eq(t, r.Between(d(2026, 11, 1), d(2026, 12, 31), 10), "2026-11-06", "2026-11-20", "2026-12-04", "2026-12-18")
	tue := time.Tuesday
	r = Rule{Frequency: Monthly, ByWeekday: &tue, ByWeekOfMonth: 2, Start: d(2026, 1, 1)} // 2nd Tuesday
	eq(t, r.Between(d(2026, 1, 1), d(2026, 3, 31), 10), "2026-01-13", "2026-02-10", "2026-03-10")
	fri := time.Friday
	r = Rule{Frequency: Monthly, ByWeekday: &fri, ByWeekOfMonth: -1, Start: d(2026, 1, 1)} // last Friday
	eq(t, r.Between(d(2026, 1, 1), d(2026, 2, 28), 10), "2026-01-30", "2026-02-27")
	r = Rule{Frequency: Custom, Interval: 10, Unit: "day", Start: d(2026, 1, 1)}
	eq(t, r.Between(d(2026, 1, 15), d(2026, 2, 15), 10), "2026-01-21", "2026-01-31", "2026-02-10")
	r = Rule{Frequency: Quarterly, Start: d(2026, 1, 15)}
	eq(t, r.Between(d(2026, 1, 1), d(2026, 12, 31), 10), "2026-01-15", "2026-04-15", "2026-07-15", "2026-10-15")
}

func TestEndDateCountAndNext(t *testing.T) {
	end := d(2026, 3, 31)
	r := Rule{Frequency: Monthly, Start: d(2026, 1, 10), End: &end}
	eq(t, r.Between(d(2026, 1, 1), d(2026, 12, 31), 10), "2026-01-10", "2026-02-10", "2026-03-10")
	r = Rule{Frequency: Daily, Start: d(2026, 1, 1), Count: 3}
	eq(t, r.Between(d(2026, 1, 1), d(2026, 12, 31), 10), "2026-01-01", "2026-01-02", "2026-01-03")
	if n, ok := r.Next(d(2026, 1, 2)); !ok || n.Day() != 2 {
		t.Fatalf("next = %v %v", n, ok)
	}
	if _, ok := r.Next(d(2026, 1, 4)); ok {
		t.Fatal("count exhausted but next found")
	}
	if i := (Rule{Frequency: Monthly, Start: d(2026, 1, 31)}).IndexOf(d(2026, 2, 28)); i != 1 {
		t.Fatalf("index = %d", i)
	}
	bad := Rule{Frequency: Custom, Interval: 0, Unit: "day", Start: d(2026, 1, 1)}
	if bad.Validate() == nil {
		t.Fatal("invalid rule accepted")
	}
}

func TestDueAtAcrossDST(t *testing.T) {
	ny, _ := time.LoadLocation("America/New_York")
	r := Rule{Frequency: Daily, Start: d(2026, 3, 7), Location: ny, Hour: 9}
	before := r.DueAt(d(2026, 3, 7)) // EST
	after := r.DueAt(d(2026, 3, 9))  // EDT
	if before.In(ny).Hour() != 9 || after.In(ny).Hour() != 9 {
		t.Fatalf("local due hour must stay 09:00: %v %v", before.In(ny), after.In(ny))
	}
	if before.Hour() != 14 || after.Hour() != 13 {
		t.Fatalf("UTC instants must reflect the offset change: %v %v", before, after)
	}
	// 02:30 does not exist on 2026-03-08 in New York: moved forward, same date.
	gap := Rule{Frequency: Daily, Start: d(2026, 3, 8), Location: ny, Hour: 2, Minute: 30}.DueAt(d(2026, 3, 8))
	if l := gap.In(ny); l.Day() != 8 || l.Hour() != 3 || l.Minute() != 30 {
		t.Fatalf("gap time = %v", l)
	}
	// 01:30 occurs twice on 2026-11-01: the first (EDT) instance is chosen.
	amb := Rule{Frequency: Daily, Start: d(2026, 11, 1), Location: ny, Hour: 1, Minute: 30}.DueAt(d(2026, 11, 1))
	if _, off := amb.In(ny).Zone(); off != -4*3600 {
		t.Fatalf("ambiguous time should resolve to EDT, got offset %d", off)
	}
	ist, _ := time.LoadLocation("Asia/Kolkata")
	if due := (Rule{Frequency: Monthly, Start: d(2026, 1, 1), Location: ist, Hour: 9}).DueAt(d(2026, 1, 1)); due.Format(time.RFC3339) != "2026-01-01T03:30:00Z" {
		t.Fatalf("IST due = %v", due)
	}
}
