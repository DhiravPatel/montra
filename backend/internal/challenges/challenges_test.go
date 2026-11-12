package challenges

import (
	"testing"
	"time"
)

func TestStreaks(t *testing.T) {
	d := func(s string) time.Time { v, _ := time.Parse("2006-01-02", s); return v }
	today := d("2026-11-10")
	cases := []struct {
		days      []string
		cur, best int
	}{
		{nil, 0, 0},
		{[]string{"2026-11-10"}, 1, 1},
		{[]string{"2026-11-08", "2026-11-09", "2026-11-10"}, 3, 3},
		{[]string{"2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-09"}, 1, 4}, // yesterday keeps it alive
		{[]string{"2026-11-01", "2026-11-02", "2026-11-05"}, 0, 2},                             // broken
		{[]string{"2026-11-09", "2026-11-09", "2026-11-08"}, 2, 2},                             // duplicates and unsorted
		{[]string{"2026-10-31", "2026-11-01"}, 0, 2},                                           // across a month end
	}
	for _, c := range cases {
		var days []time.Time
		for _, s := range c.days {
			days = append(days, d(s))
		}
		cur, best := Streaks(days, today)
		if cur != c.cur || best != c.best {
			t.Fatalf("Streaks(%v) = %d, %d; want %d, %d", c.days, cur, best, c.cur, c.best)
		}
	}
	// DST does not matter: dates are UTC-midnight calendar days.
	if cur, best := Streaks([]time.Time{d("2026-03-28"), d("2026-03-29"), d("2026-03-30")}, d("2026-03-30")); cur != 3 || best != 3 {
		t.Fatalf("DST week = %d, %d", cur, best)
	}
}

func TestPercent(t *testing.T) {
	if percent(15, 30) != 50 || percent(45, 30) != 100 || percent(0, 30) != 0 || percent(1, 3) != 33 || percent(5, 0) != 0 {
		t.Fatal("percent")
	}
}
