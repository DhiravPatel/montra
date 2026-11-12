// Package recurrence computes occurrence dates for recurring rules (spec
// §4.7, §20B.8). Each occurrence is derived from the start date (never from
// the previous occurrence), so month-end rules do not drift: a rule on the
// 31st yields Jan 31, Feb 28/29, Mar 31. Dates are local calendar dates;
// DueAt converts them to instants in the rule's IANA zone, DST-safely.
package recurrence

import (
	"errors"
	"time"
)

// Frequencies.
const (
	Daily      = "daily"
	Weekly     = "weekly"
	Biweekly   = "biweekly"
	Monthly    = "monthly"
	Bimonthly  = "bimonthly"
	Quarterly  = "quarterly"
	Semiannual = "semiannual"
	Yearly     = "yearly"
	Custom     = "custom"
)

// Rule describes a recurrence.
type Rule struct {
	Frequency     string
	Interval      int           // custom: every N units (≥1)
	Unit          string        // custom: day | week | month | year
	ByMonthDay    int           // monthly family: 1..31, -1 = last day, 0 = start's day
	ByWeekday     *time.Weekday // weekly family / nth-weekday rules
	ByWeekOfMonth int           // monthly family: 1..5 (5 = last if absent), -1 = last
	Start         time.Time     // first eligible local date
	End           *time.Time    // last eligible local date (inclusive)
	Count         int           // maximum occurrences (0 = unlimited)
	Location      *time.Location
	Hour, Minute  int
}

// ErrInvalid is returned for inconsistent rules.
var ErrInvalid = errors.New("invalid recurrence rule")

// Validate checks the rule.
func (r Rule) Validate() error {
	switch r.Frequency {
	case Daily, Weekly, Biweekly, Monthly, Bimonthly, Quarterly, Semiannual, Yearly:
	case Custom:
		if r.Interval < 1 || r.Interval > 366 {
			return ErrInvalid
		}
		switch r.Unit {
		case "day", "week", "month", "year":
		default:
			return ErrInvalid
		}
	default:
		return ErrInvalid
	}
	if r.ByMonthDay < -1 || r.ByMonthDay > 31 || r.ByWeekOfMonth < -1 || r.ByWeekOfMonth > 5 {
		return ErrInvalid
	}
	if r.ByWeekOfMonth != 0 && r.ByWeekday == nil {
		return ErrInvalid
	}
	if r.End != nil && dateOnly(*r.End).Before(dateOnly(r.Start)) {
		return ErrInvalid
	}
	if r.Count < 0 || r.Hour < 0 || r.Hour > 23 || r.Minute < 0 || r.Minute > 59 {
		return ErrInvalid
	}
	return nil
}

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// stepKind returns the base unit and multiplier.
func (r Rule) step() (unit string, n int) {
	switch r.Frequency {
	case Daily:
		return "day", 1
	case Weekly:
		return "week", 1
	case Biweekly:
		return "week", 2
	case Monthly:
		return "month", 1
	case Bimonthly:
		return "month", 2
	case Quarterly:
		return "month", 3
	case Semiannual:
		return "month", 6
	case Yearly:
		return "month", 12
	}
	if r.Unit == "year" {
		return "month", 12 * r.Interval
	}
	return r.Unit, r.Interval
}

func daysIn(y int, m time.Month) int {
	return time.Date(y, m+1, 0, 0, 0, 0, 0, time.UTC).Day()
}

// nthWeekday returns the n-th (1..5, -1 last) weekday of a month; 5 falls
// back to the last when the month has only four.
func nthWeekday(y int, m time.Month, wd time.Weekday, n int) time.Time {
	if n == -1 {
		last := time.Date(y, m, daysIn(y, m), 0, 0, 0, 0, time.UTC)
		diff := (int(last.Weekday()) - int(wd) + 7) % 7
		return last.AddDate(0, 0, -diff)
	}
	first := time.Date(y, m, 1, 0, 0, 0, 0, time.UTC)
	diff := (int(wd) - int(first.Weekday()) + 7) % 7
	d := first.AddDate(0, 0, diff+7*(n-1))
	if d.Month() != m {
		return nthWeekday(y, m, wd, -1)
	}
	return d
}

// occurrence returns the i-th candidate date (0-based) before End/Count.
func (r Rule) occurrence(i int) time.Time {
	start := dateOnly(r.Start)
	unit, n := r.step()
	switch unit {
	case "day":
		return start.AddDate(0, 0, i*n)
	case "week":
		base := start
		if r.ByWeekday != nil {
			diff := (int(*r.ByWeekday) - int(start.Weekday()) + 7) % 7
			base = start.AddDate(0, 0, diff)
		}
		return base.AddDate(0, 0, 7*i*n)
	}
	// month family
	months := int(start.Month()) - 1 + i*n
	y := start.Year() + months/12
	m := time.Month(months%12 + 1)
	if r.ByWeekOfMonth != 0 && r.ByWeekday != nil {
		return nthWeekday(y, m, *r.ByWeekday, r.ByWeekOfMonth)
	}
	day := r.ByMonthDay
	if day == 0 {
		day = start.Day()
	}
	if day == -1 || day > daysIn(y, m) {
		day = daysIn(y, m)
	}
	return time.Date(y, m, day, 0, 0, 0, 0, time.UTC)
}

// Between returns occurrence dates in [from, to] (inclusive, local dates),
// capped at limit results.
func (r Rule) Between(from, to time.Time, limit int) []time.Time {
	if r.Validate() != nil || limit <= 0 {
		return nil
	}
	from, to = dateOnly(from), dateOnly(to)
	start := dateOnly(r.Start)
	if from.Before(start) {
		from = start
	}
	var out []time.Time
	for i := r.firstIndexNear(from); ; i++ {
		if r.Count > 0 && i >= r.Count {
			break
		}
		d := r.occurrence(i)
		if r.End != nil && d.After(dateOnly(*r.End)) {
			break
		}
		if d.After(to) {
			break
		}
		if d.Before(from) || d.Before(start) {
			continue
		}
		out = append(out, d)
		if len(out) >= limit {
			break
		}
	}
	return out
}

// firstIndexNear returns a safe starting index at or before the first
// occurrence on/after from (avoids iterating from the beginning).
func (r Rule) firstIndexNear(from time.Time) int {
	start := dateOnly(r.Start)
	unit, n := r.step()
	var i int
	switch unit {
	case "day":
		i = int(from.Sub(start).Hours()/24) / n
	case "week":
		i = int(from.Sub(start).Hours()/24) / (7 * n)
	default:
		months := (from.Year()-start.Year())*12 + int(from.Month()) - int(start.Month())
		i = months / n
	}
	if i > 1 {
		return i - 1
	}
	return 0
}

// Next returns the first occurrence on or after d.
func (r Rule) Next(d time.Time) (time.Time, bool) {
	horizon := dateOnly(d).AddDate(12, 0, 0)
	got := r.Between(d, horizon, 1)
	if len(got) == 0 {
		return time.Time{}, false
	}
	return got[0], true
}

// IndexOf returns the 0-based index of an occurrence date (for Count
// tracking), or -1 if the date is not an occurrence.
func (r Rule) IndexOf(d time.Time) int {
	d = dateOnly(d)
	for i := r.firstIndexNear(d); i < r.firstIndexNear(d)+3; i++ {
		if r.occurrence(i).Equal(d) {
			return i
		}
	}
	return -1
}

// DueAt converts a local occurrence date to an instant at the rule's local
// time. If that wall time does not exist (DST spring-forward gap) it moves
// forward by the gap; if it is ambiguous (fall-back) the first instance is
// used. The result never lands on a different local date.
func (r Rule) DueAt(date time.Time) time.Time {
	loc := r.Location
	if loc == nil {
		loc = time.UTC
	}
	y, m, day := date.Year(), date.Month(), date.Day()
	t := time.Date(y, m, day, r.Hour, r.Minute, 0, 0, loc)
	if t.Hour() != r.Hour || t.Minute() != r.Minute {
		// Gap: the wall time does not exist. Interpreting it with the offset
		// in effect before the transition shifts it forward by the gap.
		_, off := time.Date(y, m, day, 0, 0, 0, 0, loc).Zone()
		return time.Date(y, m, day, r.Hour, r.Minute, 0, 0, time.FixedZone("pre-transition", off)).UTC()
	}
	// Ambiguous times: prefer the earlier instant (first occurrence).
	if earlier := t.Add(-time.Hour).In(loc); earlier.Hour() == r.Hour && earlier.Minute() == r.Minute && earlier.Day() == day {
		return earlier.UTC()
	}
	return t.UTC()
}
