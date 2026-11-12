// Package reconcile scores possible matches between statement rows and
// ledger transactions with explainable reasons (spec §4.10, §20B.11). It
// never decides: callers present candidates for user confirmation.
package reconcile

import (
	"sort"
	"strings"
	"time"
	"unicode"
)

// Item is one side of a possible match.
type Item struct {
	ID          string
	Date        time.Time
	AmountMinor int64
	Direction   string // inflow | outflow
	Description string
	Reference   string
}

// Candidate is a scored one-to-one or one-to-many pairing.
type Candidate struct {
	Left            Item   // statement row, pending or manual transaction
	Right           []Item // ledger transaction(s)
	ConfidenceMilli int
	Reasons         []Reason
	DaysApart       int // largest date distance between Left and a Right item
}

// Reason codes: stable explanations of a score (Text is the English
// fallback). Callers add their own codes for user-confirmed matches.
const (
	ReasonSameAmountDirection = "same_amount_direction"
	ReasonSameDate            = "same_date"
	ReasonOneDayApart         = "one_day_apart"
	ReasonWithin3Days         = "within_3_days"
	ReasonWithinWeek          = "within_a_week"
	ReasonSameReference       = "same_reference"
	ReasonSimilarDescription  = "similar_description"
	ReasonAmountsAddUp        = "amounts_add_up"
	ReasonAllWithinWeek       = "all_within_a_week"
)

// Reason is one explanation of a score: a stable code and its English text.
type Reason struct {
	Code string
	Text string
}

// Codes returns the reasons' codes, in order (never nil).
func Codes(rs []Reason) []string {
	out := make([]string, 0, len(rs))
	for _, r := range rs {
		out = append(out, r.Code)
	}
	return out
}

// Texts returns the reasons' English texts, in order (never nil).
func Texts(rs []Reason) []string {
	out := make([]string, 0, len(rs))
	for _, r := range rs {
		out = append(out, r.Text)
	}
	return out
}

// Thresholds.
const (
	MaxDateDistanceDays = 7
	MinConfidenceMilli  = 500
)

func days(a, b time.Time) int {
	d := int(b.Sub(a).Hours() / 24)
	if d < 0 {
		d = -d
	}
	return d
}

// DaysApart is the whole number of days between two dates (never negative).
func DaysApart(a, b time.Time) int { return days(a, b) }

func normRef(s string) string {
	var sb strings.Builder
	for _, r := range strings.ToLower(s) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			sb.WriteRune(r)
		}
	}
	return sb.String()
}

func tokens(s string) map[string]bool {
	out := map[string]bool{}
	for _, f := range strings.FieldsFunc(strings.ToLower(s), func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) }) {
		digits := true
		for _, r := range f {
			if r < '0' || r > '9' {
				digits = false
				break
			}
		}
		if len(f) >= 3 && !digits {
			out[f] = true
		}
	}
	return out
}

// similarity is a token Jaccard score in thousandths.
func similarity(a, b string) int {
	ta, tb := tokens(a), tokens(b)
	if len(ta) == 0 || len(tb) == 0 {
		return 0
	}
	inter := 0
	for t := range ta {
		if tb[t] {
			inter++
		}
	}
	return inter * 1000 / (len(ta) + len(tb) - inter)
}

// Score rates a one-to-one pairing; 0 means "not a match". The amount and
// direction must be equal; date distance, references and descriptions
// raise confidence.
func Score(a, b Item) (int, []Reason) {
	if a.Direction != b.Direction || a.AmountMinor != b.AmountMinor || a.AmountMinor <= 0 {
		return 0, nil
	}
	d := days(a.Date, b.Date)
	if d > MaxDateDistanceDays {
		return 0, nil
	}
	score := 450
	reasons := []Reason{{ReasonSameAmountDirection, "Same amount and direction"}}
	switch {
	case d == 0:
		score += 250
		reasons = append(reasons, Reason{ReasonSameDate, "Same date"})
	case d <= 1:
		score += 200
		reasons = append(reasons, Reason{ReasonOneDayApart, "One day apart"})
	case d <= 3:
		score += 120
		reasons = append(reasons, Reason{ReasonWithin3Days, "Within 3 days"})
	default:
		score += 40
		reasons = append(reasons, Reason{ReasonWithinWeek, "Within a week"})
	}
	if ra, rb := normRef(a.Reference), normRef(b.Reference); ra != "" && ra == rb {
		score += 250
		reasons = append(reasons, Reason{ReasonSameReference, "Same reference"})
	}
	if sim := similarity(a.Description, b.Description); sim >= 300 {
		score += sim * 250 / 1000
		reasons = append(reasons, Reason{ReasonSimilarDescription, "Similar description"})
	}
	return min(score, 1000), reasons
}

// BestOneToOne pairs left and right items greedily by score so each item is
// used at most once (deterministic tie-breaking by date distance then ID).
func BestOneToOne(left, right []Item, minScore int) []Candidate {
	type pair struct {
		l, r    int
		score   int
		reasons []Reason
		dist    int
	}
	var pairs []pair
	for i, a := range left {
		for j, b := range right {
			if s, why := Score(a, b); s >= minScore {
				pairs = append(pairs, pair{i, j, s, why, days(a.Date, b.Date)})
			}
		}
	}
	sort.SliceStable(pairs, func(x, y int) bool {
		if pairs[x].score != pairs[y].score {
			return pairs[x].score > pairs[y].score
		}
		if pairs[x].dist != pairs[y].dist {
			return pairs[x].dist < pairs[y].dist
		}
		return left[pairs[x].l].ID+right[pairs[x].r].ID < left[pairs[y].l].ID+right[pairs[y].r].ID
	})
	usedL, usedR := map[int]bool{}, map[int]bool{}
	var out []Candidate
	for _, p := range pairs {
		if usedL[p.l] || usedR[p.r] {
			continue
		}
		usedL[p.l], usedR[p.r] = true, true
		out = append(out, Candidate{Left: left[p.l], Right: []Item{right[p.r]}, ConfidenceMilli: p.score, Reasons: p.reasons, DaysApart: p.dist})
	}
	return out
}

// OneToMany finds up to maxParts right items (same direction, within the
// date window) whose amounts sum exactly to the left amount, e.g. a single
// card settlement covering several purchases. The search is bounded.
func OneToMany(left Item, right []Item, maxParts int) (Candidate, bool) {
	var pool []Item
	for _, r := range right {
		if r.Direction == left.Direction && r.AmountMinor > 0 && r.AmountMinor < left.AmountMinor && days(left.Date, r.Date) <= MaxDateDistanceDays {
			pool = append(pool, r)
		}
	}
	if len(pool) > 20 {
		sort.SliceStable(pool, func(i, j int) bool { return days(left.Date, pool[i].Date) < days(left.Date, pool[j].Date) })
		pool = pool[:20]
	}
	var best []Item
	var walk func(start int, sum int64, picked []Item)
	walk = func(start int, sum int64, picked []Item) {
		if best != nil {
			return
		}
		if sum == left.AmountMinor && len(picked) >= 2 {
			best = append([]Item(nil), picked...)
			return
		}
		if len(picked) == maxParts || sum >= left.AmountMinor {
			return
		}
		for i := start; i < len(pool); i++ {
			walk(i+1, sum+pool[i].AmountMinor, append(picked, pool[i]))
		}
	}
	walk(0, 0, nil)
	if best == nil {
		return Candidate{}, false
	}
	far := 0
	for _, r := range best {
		far = max(far, days(left.Date, r.Date))
	}
	return Candidate{Left: left, Right: best, ConfidenceMilli: 550, DaysApart: far,
		Reasons: []Reason{{ReasonAmountsAddUp, "Amounts add up exactly"}, {ReasonAllWithinWeek, "All within a week"}}}, true
}
