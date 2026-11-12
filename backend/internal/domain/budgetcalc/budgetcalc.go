// Package budgetcalc computes budget progress, pace, projections,
// rollovers and threshold crossings with exact integer arithmetic
// (spec §4.6, §20B.7).
package budgetcalc

import (
	"math/big"
	"sort"
)

// Pace classifications.
const (
	PaceUnder   = "under_pace"    // spending slower than the even pace
	PaceOnTrack = "on_track"      // within ±10 % of the even pace
	PaceAhead   = "ahead_of_pace" // spending faster than the even pace
	PaceOver    = "over_budget"   // already above the limit
)

// Progress is the state of a budget period.
type Progress struct {
	LimitMinor          int64
	SpentMinor          int64
	RemainingMinor      int64
	OverspentMinor      int64
	PercentBP           int64 // spent / limit in basis points
	ElapsedDays         int
	TotalDays           int
	ExpectedByNowMinor  int64 // even-pace expectation for elapsed days
	ProjectedMinor      int64 // spent extrapolated to the full period
	ProjectedOverMinor  int64
	DailyAllowanceMinor int64 // remaining / remaining days
	Pace                string
}

func ratio(a, num, den int64) int64 {
	if den == 0 {
		return 0
	}
	r := new(big.Rat).SetFrac(new(big.Int).Mul(big.NewInt(a), big.NewInt(num)), big.NewInt(den))
	q := new(big.Int).Quo(r.Num(), r.Denom()) // truncation toward zero is fine for display figures
	rem := new(big.Int).Rem(r.Num(), r.Denom())
	if new(big.Int).Lsh(new(big.Int).Abs(rem), 1).Cmp(r.Denom()) >= 0 { // round half away from zero
		if r.Sign() >= 0 {
			q.Add(q, big.NewInt(1))
		} else {
			q.Sub(q, big.NewInt(1))
		}
	}
	return q.Int64()
}

// Compute derives progress. limit includes any rollover carried in.
func Compute(limit, spent int64, elapsed, total int) Progress {
	if total <= 0 {
		total = 1
	}
	if elapsed < 0 {
		elapsed = 0
	}
	if elapsed > total {
		elapsed = total
	}
	p := Progress{LimitMinor: limit, SpentMinor: spent, ElapsedDays: elapsed, TotalDays: total}
	if spent > limit {
		p.OverspentMinor = spent - limit
	} else {
		p.RemainingMinor = limit - spent
	}
	if limit > 0 {
		p.PercentBP = ratio(spent, 10000, limit)
	}
	p.ExpectedByNowMinor = ratio(limit, int64(elapsed), int64(total))
	if elapsed > 0 {
		p.ProjectedMinor = ratio(spent, int64(total), int64(elapsed))
	} else {
		p.ProjectedMinor = spent
	}
	if p.ProjectedMinor > limit {
		p.ProjectedOverMinor = p.ProjectedMinor - limit
	}
	if left := total - elapsed; left > 0 {
		p.DailyAllowanceMinor = p.RemainingMinor / int64(left)
	}
	switch {
	case spent > limit:
		p.Pace = PaceOver
	case p.ExpectedByNowMinor > 0 && spent*10 > p.ExpectedByNowMinor*11:
		p.Pace = PaceAhead
	case p.ExpectedByNowMinor > 0 && spent*10 < p.ExpectedByNowMinor*9:
		p.Pace = PaceUnder
	default:
		p.Pace = PaceOnTrack
	}
	return p
}

// Rollover returns the amount carried into the next period (may be
// negative for overspend) under a policy, bounded by cap (absolute).
func Rollover(policy string, limit, spent int64, capMinor *int64) int64 {
	var carry int64
	switch policy {
	case "carry_unused":
		if limit > spent {
			carry = limit - spent
		}
	case "carry_overspend":
		if spent > limit {
			carry = limit - spent
		}
	case "carry_both":
		carry = limit - spent
	default:
		return 0
	}
	if capMinor != nil {
		c := *capMinor
		if carry > c {
			carry = c
		}
		if carry < -c {
			carry = -c
		}
	}
	return carry
}

// CrossedThresholds lists thresholds (percent) newly crossed when spend
// moves from prev to cur against limit, ascending. Each threshold is
// reported once per period by the caller's dedupe key.
func CrossedThresholds(prev, cur, limit int64, thresholds []int16) []int16 {
	if limit <= 0 {
		return nil
	}
	var out []int16
	for _, t := range thresholds {
		mark := ratio(limit, int64(t), 100)
		if cur >= mark && prev < mark {
			out = append(out, t)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i] < out[j] })
	return out
}

// ReachedThresholds lists all thresholds at or below the current spend
// (used for idempotent re-evaluation: dedupe prevents repeats).
func ReachedThresholds(cur, limit int64, thresholds []int16) []int16 {
	return CrossedThresholds(-1, cur, limit, thresholds)
}
