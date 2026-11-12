package period

import (
	"testing"
	"time"
)

func mustLoc(t *testing.T, name string) *time.Location {
	l, err := time.LoadLocation(name)
	if err != nil {
		t.Fatal(err)
	}
	return l
}

func TestNamedRanges(t *testing.T) {
	ist := mustLoc(t, "Asia/Kolkata")
	// 2026-11-04 20:00 UTC is 2026-11-05 01:30 IST: "today" follows the user's zone.
	now := time.Date(2026, 11, 4, 20, 0, 0, 0, time.UTC)
	s := Settings{Location: ist, WeekStart: time.Monday, MonthStartDay: 1}
	r, _ := Named("today", now, s)
	if r.Start.Day() != 5 {
		t.Fatalf("today in IST should be the 5th, got %v", r.Start)
	}
	r, _ = Named("this_week", now, s) // Thu 5 Nov → Mon 2 .. Sun 8
	if r.Start.Day() != 2 || r.End.Day() != 8 {
		t.Fatalf("this_week = %v..%v", r.Start, r.End)
	}
	r, _ = Named("this_month", now, Settings{Location: ist, MonthStartDay: 25}) // salary cycle: 25 Oct .. 24 Nov
	if r.Start.Month() != time.October || r.Start.Day() != 25 || r.End.Day() != 24 {
		t.Fatalf("salary month = %v..%v", r.Start, r.End)
	}
	r, _ = Named("last_30_days", now, s)
	if r.Days() != 30 {
		t.Fatalf("last_30_days has %d days", r.Days())
	}
	if _, err := Named("bogus", now, s); err == nil {
		t.Fatal("unknown range accepted")
	}
}

func TestMonthBoundariesLeapYearAndDST(t *testing.T) {
	ny := mustLoc(t, "America/New_York")
	r := MonthContaining(Date(2028, 2, 15, ny), 1)
	if r.End.Day() != 29 {
		t.Fatalf("leap February should end on the 29th, got %v", r.End)
	}
	// March 2026 contains the US DST change; day counting must still be exact.
	r = MonthContaining(Date(2026, 3, 20, ny), 1)
	if r.Days() != 31 {
		t.Fatalf("March has 31 days, got %d", r.Days())
	}
	if p := r.Previous(); p.Days() != 31 || p.End.Day() != 28 {
		t.Fatalf("previous range = %v..%v (%d days)", p.Start, p.End, p.Days())
	}
	// Month start day 28 across a short February.
	r = MonthContaining(Date(2026, 2, 27, ny), 28)
	if r.Start.Month() != time.January || r.Start.Day() != 28 || r.End.Month() != time.February || r.End.Day() != 27 {
		t.Fatalf("cycle = %v..%v", r.Start, r.End)
	}
}

func TestElapsedAndCustom(t *testing.T) {
	loc := time.UTC
	r := Range{Date(2026, 11, 1, loc), Date(2026, 11, 30, loc)}
	if e := Elapsed(r, Date(2026, 11, 10, loc)); e != 10 {
		t.Fatalf("elapsed = %d", e)
	}
	if e := Elapsed(r, Date(2026, 12, 5, loc)); e != 30 {
		t.Fatalf("elapsed after end = %d", e)
	}
	if _, err := Custom(Date(2026, 5, 1, loc), Date(2026, 4, 1, loc), loc); err == nil {
		t.Fatal("inverted range accepted")
	}
}
