// Package period resolves reporting date ranges in a user's timezone with
// configurable week start and month start day (spec §4.2, §20B.3). Ranges
// are inclusive local dates [Start, End].
package period

import (
	"errors"
	"time"
)

// Range is an inclusive local-date range.
type Range struct {
	Start time.Time // midnight, location = user's timezone
	End   time.Time // midnight of the last included day
}

// Days returns the number of days in the range.
func (r Range) Days() int {
	return int(r.End.Sub(r.Start).Hours()/24+0.5) + 1
}

// Contains reports whether a local date is inside the range.
func (r Range) Contains(d time.Time) bool {
	d = Date(d.Year(), d.Month(), d.Day(), r.Start.Location())
	return !d.Before(r.Start) && !d.After(r.End)
}

// Previous returns the immediately preceding range of equal length (for
// period comparisons).
func (r Range) Previous() Range {
	n := r.Days()
	end := r.Start.AddDate(0, 0, -1)
	return Range{Start: end.AddDate(0, 0, -(n - 1)), End: end}
}

// Date builds a local midnight date.
func Date(y int, m time.Month, d int, loc *time.Location) time.Time {
	return time.Date(y, m, d, 0, 0, 0, 0, loc)
}

// Today returns the user's current local date.
func Today(now time.Time, loc *time.Location) time.Time {
	l := now.In(loc)
	return Date(l.Year(), l.Month(), l.Day(), loc)
}

// Settings are the user's calendar preferences.
type Settings struct {
	Location      *time.Location
	WeekStart     time.Weekday // 0 = Sunday
	MonthStartDay int          // 1..28
}

// ErrUnknownRange is returned for unsupported range names.
var ErrUnknownRange = errors.New("unknown date range")

// Named resolves a named range relative to now.
func Named(name string, now time.Time, s Settings) (Range, error) {
	if s.Location == nil {
		s.Location = time.UTC
	}
	if s.MonthStartDay < 1 || s.MonthStartDay > 28 {
		s.MonthStartDay = 1
	}
	today := Today(now, s.Location)
	switch name {
	case "today":
		return Range{today, today}, nil
	case "yesterday":
		y := today.AddDate(0, 0, -1)
		return Range{y, y}, nil
	case "this_week":
		start := WeekStart(today, s.WeekStart)
		return Range{start, start.AddDate(0, 0, 6)}, nil
	case "last_week":
		start := WeekStart(today, s.WeekStart).AddDate(0, 0, -7)
		return Range{start, start.AddDate(0, 0, 6)}, nil
	case "this_month":
		return MonthContaining(today, s.MonthStartDay), nil
	case "last_month":
		cur := MonthContaining(today, s.MonthStartDay)
		return MonthContaining(cur.Start.AddDate(0, 0, -1), s.MonthStartDay), nil
	case "this_year":
		return Range{Date(today.Year(), 1, 1, s.Location), Date(today.Year(), 12, 31, s.Location)}, nil
	case "last_year":
		return Range{Date(today.Year()-1, 1, 1, s.Location), Date(today.Year()-1, 12, 31, s.Location)}, nil
	case "last_7_days":
		return Range{today.AddDate(0, 0, -6), today}, nil
	case "last_30_days":
		return Range{today.AddDate(0, 0, -29), today}, nil
	case "last_90_days":
		return Range{today.AddDate(0, 0, -89), today}, nil
	}
	return Range{}, ErrUnknownRange
}

// WeekStart returns the first day of the week containing d.
func WeekStart(d time.Time, start time.Weekday) time.Time {
	diff := (int(d.Weekday()) - int(start) + 7) % 7
	return d.AddDate(0, 0, -diff)
}

// MonthContaining returns the budget month containing d when months start
// on monthStartDay (e.g. salary cycles starting on the 25th).
func MonthContaining(d time.Time, monthStartDay int) Range {
	loc := d.Location()
	y, m := d.Year(), d.Month()
	if d.Day() < monthStartDay {
		m--
		if m == 0 {
			m, y = 12, y-1
		}
	}
	start := Date(y, m, monthStartDay, loc)
	end := start.AddDate(0, 1, 0).AddDate(0, 0, -1)
	return Range{start, end}
}

// Custom builds a validated custom range (max 10 years).
func Custom(from, to time.Time, loc *time.Location) (Range, error) {
	f := Date(from.Year(), from.Month(), from.Day(), loc)
	t := Date(to.Year(), to.Month(), to.Day(), loc)
	if t.Before(f) {
		return Range{}, errors.New("end date is before start date")
	}
	if t.Sub(f) > 3660*24*time.Hour {
		return Range{}, errors.New("date range is too long (max 10 years)")
	}
	return Range{f, t}, nil
}

// Elapsed returns how many days of r have elapsed by today (clamped), for
// pace and projection calculations.
func Elapsed(r Range, today time.Time) int {
	switch {
	case today.Before(r.Start):
		return 0
	case today.After(r.End):
		return r.Days()
	}
	return int(today.Sub(r.Start).Hours()/24+0.5) + 1
}
