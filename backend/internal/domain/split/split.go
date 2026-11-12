// Package split allocates an amount across participants in exact minor
// units. Every allocation sums exactly to the total; remainders are
// distributed deterministically by the largest-remainder method with ties
// broken by participant position (spec §4.15, ADR-006).
package split

import (
	"errors"
	"math/big"
	"sort"
	"strings"
)

// Errors.
var (
	ErrNoParticipants = errors.New("at least one participant is required")
	ErrNonPositive    = errors.New("total must be positive")
	ErrWeights        = errors.New("weights must be non-negative with at least one positive")
	ErrSumMismatch    = errors.New("allocations do not sum to the total")
	ErrPercentSum     = errors.New("percentages must sum to exactly 100")
	ErrPercentFormat  = errors.New("percentages must have at most 2 decimal places")
	ErrItems          = errors.New("itemized split is invalid")
)

// ByWeights allocates total proportionally to weights.
func ByWeights(total int64, weights []int64) ([]int64, error) {
	if len(weights) == 0 {
		return nil, ErrNoParticipants
	}
	if total <= 0 {
		return nil, ErrNonPositive
	}
	sumW := new(big.Int)
	for _, w := range weights {
		if w < 0 {
			return nil, ErrWeights
		}
		sumW.Add(sumW, big.NewInt(w))
	}
	if sumW.Sign() == 0 {
		return nil, ErrWeights
	}
	type rem struct {
		idx int
		r   *big.Int
	}
	out := make([]int64, len(weights))
	rems := make([]rem, len(weights))
	allocated := int64(0)
	T := big.NewInt(total)
	for i, w := range weights {
		prod := new(big.Int).Mul(T, big.NewInt(w))
		q, r := new(big.Int).QuoRem(prod, sumW, new(big.Int))
		out[i] = q.Int64()
		allocated += out[i]
		rems[i] = rem{idx: i, r: r}
	}
	left := total - allocated
	sort.SliceStable(rems, func(a, b int) bool {
		c := rems[a].r.Cmp(rems[b].r)
		if c != 0 {
			return c > 0
		}
		return rems[a].idx < rems[b].idx
	})
	for i := int64(0); i < left; i++ {
		// Only positive-weight participants can receive remainder units.
		out[rems[i].idx]++
	}
	return out, nil
}

// Equal splits total evenly among n participants.
func Equal(total int64, n int) ([]int64, error) {
	if n <= 0 {
		return nil, ErrNoParticipants
	}
	w := make([]int64, n)
	for i := range w {
		w[i] = 1
	}
	return ByWeights(total, w)
}

// Exact validates explicit allocations.
func Exact(total int64, amounts []int64) ([]int64, error) {
	if len(amounts) == 0 {
		return nil, ErrNoParticipants
	}
	if total <= 0 {
		return nil, ErrNonPositive
	}
	var sum int64
	for _, a := range amounts {
		if a < 0 {
			return nil, ErrWeights
		}
		sum += a
		if sum > total {
			return nil, ErrSumMismatch
		}
	}
	if sum != total {
		return nil, ErrSumMismatch
	}
	return append([]int64(nil), amounts...), nil
}

// ParsePercent parses "33.33" into basis points (3333).
func ParsePercent(s string) (int64, error) {
	s = strings.TrimSpace(s)
	ip, fp, _ := strings.Cut(s, ".")
	if ip == "" || len(fp) > 2 || len(ip) > 3 {
		return 0, ErrPercentFormat
	}
	for _, c := range ip + fp {
		if c < '0' || c > '9' {
			return 0, ErrPercentFormat
		}
	}
	fp += strings.Repeat("0", 2-len(fp))
	var v int64
	for _, c := range ip + fp {
		v = v*10 + int64(c-'0')
	}
	if v > 10000 {
		return 0, ErrPercentSum
	}
	return v, nil
}

// ByPercentages allocates total by percentages given in basis points, which
// must sum to exactly 10000 (100.00 %).
func ByPercentages(total int64, basisPoints []int64) ([]int64, error) {
	var sum int64
	for _, b := range basisPoints {
		if b < 0 {
			return nil, ErrWeights
		}
		sum += b
	}
	if sum != 10000 {
		return nil, ErrPercentSum
	}
	return ByWeights(total, basisPoints)
}

// Item is one line of an itemized split. Weights are per participant index
// (length = number of participants); zero means the participant did not
// share this item.
type Item struct {
	AmountMinor int64
	Weights     []int64
}

// Itemized allocates item amounts by their weights, then distributes any
// remaining amount (tax, tip, service charge, rounding = total minus item
// sum) proportionally to each participant's item subtotal.
func Itemized(total int64, participants int, items []Item) ([]int64, error) {
	if participants <= 0 {
		return nil, ErrNoParticipants
	}
	if total <= 0 || len(items) == 0 {
		return nil, ErrItems
	}
	subtotals := make([]int64, participants)
	var itemsSum int64
	for _, it := range items {
		if it.AmountMinor < 0 || len(it.Weights) != participants {
			return nil, ErrItems
		}
		itemsSum += it.AmountMinor
		if it.AmountMinor == 0 {
			continue
		}
		alloc, err := ByWeights(it.AmountMinor, it.Weights)
		if err != nil {
			return nil, ErrItems
		}
		for i, a := range alloc {
			subtotals[i] += a
		}
	}
	if itemsSum > total {
		return nil, ErrSumMismatch
	}
	extra := total - itemsSum
	if extra == 0 {
		return subtotals, nil
	}
	if itemsSum == 0 {
		return nil, ErrItems
	}
	extraAlloc, err := ByWeights(extra, subtotals)
	if err != nil {
		return nil, ErrItems
	}
	for i := range subtotals {
		subtotals[i] += extraAlloc[i]
	}
	return subtotals, nil
}
