// Package subdetect finds possible subscriptions in a merchant's charge
// history using explainable rules (spec §4.8, §20B.9): a consistent cadence,
// amounts within a tolerance, and recent activity. It never decides on its
// own: results are candidates with evidence and a confidence score that the
// user confirms or dismisses.
package subdetect

import (
	"fmt"
	"sort"
	"time"
)

// Charge is one posted expense.
type Charge struct {
	ID     string
	Date   time.Time // local calendar date
	Amount int64     // minor units, > 0
}

// Cadence describes an accepted billing interval.
type Cadence struct {
	Name     string
	Min, Max int // accepted interval in days (inclusive)
	months   int // calendar step for next-date projection (0 = days)
	days     int
}

// Cadences are the detectable billing cycles.
var Cadences = []Cadence{
	{Name: "weekly", Min: 6, Max: 8, days: 7},
	{Name: "monthly", Min: 27, Max: 33, months: 1},
	{Name: "quarterly", Min: 84, Max: 98, months: 3},
	{Name: "semiannual", Min: 174, Max: 190, months: 6},
	{Name: "yearly", Min: 352, Max: 378, months: 12},
}

// Candidate is a detected recurring charge pattern.
type Candidate struct {
	Cadence          string
	Amount           int64 // median of matching charges
	Tolerance        int64 // accepted absolute deviation
	ConfidenceMilli  int   // 0..1000
	EvidenceIDs      []string
	IntervalsDays    []int
	MedianInterval   int
	AmountsMinor     []int64
	LastCharge       time.Time
	NextExpected     time.Time
	Reasons          []string
	AmountConsistent int // charges within tolerance
}

// MinConfidenceMilli is the reporting threshold.
const MinConfidenceMilli = 600

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func days(a, b time.Time) int { return int(dateOnly(b).Sub(dateOnly(a)).Hours() / 24) }

func median(v []int) int {
	s := append([]int(nil), v...)
	sort.Ints(s)
	n := len(s)
	if n%2 == 1 {
		return s[n/2]
	}
	return (s[n/2-1] + s[n/2]) / 2
}

func median64(v []int64) int64 {
	s := append([]int64(nil), v...)
	sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })
	n := len(s)
	if n%2 == 1 {
		return s[n/2]
	}
	return (s[n/2-1] + s[n/2]) / 2
}

func abs64(x int64) int64 {
	if x < 0 {
		return -x
	}
	return x
}

// Detect evaluates one merchant/currency series as of today. It uses the
// most recent charges (up to 12), so an old price does not hide a current
// subscription.
func Detect(charges []Charge, today time.Time) (Candidate, bool) {
	cs := make([]Charge, 0, len(charges))
	for _, c := range charges {
		if c.Amount > 0 {
			cs = append(cs, Charge{ID: c.ID, Date: dateOnly(c.Date), Amount: c.Amount})
		}
	}
	sort.SliceStable(cs, func(i, j int) bool { return cs[i].Date.Before(cs[j].Date) })
	// Collapse same-day charges (split payments/retries): keep the largest.
	merged := cs[:0:0]
	for _, c := range cs {
		if n := len(merged); n > 0 && merged[n-1].Date.Equal(c.Date) {
			if c.Amount > merged[n-1].Amount {
				merged[n-1] = c
			}
			continue
		}
		merged = append(merged, c)
	}
	cs = merged
	if len(cs) > 12 {
		cs = cs[len(cs)-12:]
	}
	if len(cs) < 2 {
		return Candidate{}, false
	}
	intervals := make([]int, 0, len(cs)-1)
	for i := 1; i < len(cs); i++ {
		intervals = append(intervals, days(cs[i-1].Date, cs[i].Date))
	}
	med := median(intervals)
	var cad *Cadence
	for i := range Cadences {
		if med >= Cadences[i].Min && med <= Cadences[i].Max {
			cad = &Cadences[i]
			break
		}
	}
	if cad == nil {
		return Candidate{}, false
	}
	// Short cycles need at least three charges; yearly may use two.
	if len(cs) < 3 && cad.Name != "yearly" {
		return Candidate{}, false
	}
	inBand := 0
	for _, d := range intervals {
		if d >= cad.Min && d <= cad.Max {
			inBand++
		}
	}
	amounts := make([]int64, len(cs))
	for i, c := range cs {
		amounts[i] = c.Amount
	}
	medAmt := median64(amounts)
	tol := medAmt * 5 / 100 // 5% tolerance
	if tol < 1 {
		tol = 1
	}
	var evidence []string
	consistent := 0
	for _, c := range cs {
		if abs64(c.Amount-medAmt) <= tol {
			consistent++
			evidence = append(evidence, c.ID)
		}
	}
	intervalScore := inBand * 1000 / len(intervals)
	amountScore := consistent * 1000 / len(cs)
	countScore := min(len(cs)*1000/6, 1000)
	if cad.Name == "yearly" {
		countScore = min(len(cs)*1000/3, 1000)
	}
	conf := (450*intervalScore + 350*amountScore + 200*countScore) / 1000
	last := cs[len(cs)-1]
	// Stale series (no charge for ~1.5 cycles) are likely cancelled.
	if days(last.Date, today) > cad.Max+cad.Max/2 {
		return Candidate{}, false
	}
	if intervalScore < 750 || amountScore < 600 || conf < MinConfidenceMilli {
		return Candidate{}, false
	}
	next := last.Date.AddDate(0, cad.months, cad.days)
	reasons := []string{
		fmt.Sprintf("%d charges, typically every %d days (%s)", len(cs), med, cad.Name),
		fmt.Sprintf("%d of %d intervals fit the %s cycle", inBand, len(intervals), cad.Name),
		fmt.Sprintf("%d of %d amounts within 5%% of the typical amount", consistent, len(cs)),
	}
	return Candidate{Cadence: cad.Name, Amount: medAmt, Tolerance: tol, ConfidenceMilli: conf, EvidenceIDs: evidence,
		IntervalsDays: intervals, MedianInterval: med, AmountsMinor: amounts, LastCharge: last.Date, NextExpected: next,
		Reasons: reasons, AmountConsistent: consistent}, true
}
