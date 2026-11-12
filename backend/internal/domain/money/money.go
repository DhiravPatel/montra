// Package money implements exact monetary arithmetic on integer minor units
// (ADR-006). Floating point is never used. Decimal strings are parsed and
// formatted exactly according to each currency's ISO 4217 exponent.
package money

import (
	"errors"
	"fmt"
	"math/big"
	"strings"

	"montra/backend/internal/domain/currency"
)

// MaxMinor bounds any single amount (10^15 minor units) so that sums of many
// amounts stay far from int64 overflow and remain exact in JavaScript and
// Dart clients (< 2^53).
const MaxMinor int64 = 1_000_000_000_000_000

// Errors returned by parsing and arithmetic.
var (
	ErrUnknownCurrency = errors.New("unsupported currency")
	ErrInvalidAmount   = errors.New("invalid amount")
	ErrTooPrecise      = errors.New("too many decimal places for currency")
	ErrNegative        = errors.New("amount must not be negative")
	ErrOutOfRange      = errors.New("amount out of range")
	ErrOverflow        = errors.New("arithmetic overflow")
)

// Amount is a signed amount in minor units of a currency.
type Amount struct {
	Minor    int64
	Currency string
}

// ParseOptions controls decimal parsing.
type ParseOptions struct {
	AllowNegative bool
	AllowZero     bool
}

// Parse converts a decimal string such as "1234.50" into minor units for the
// currency. It accepts an optional leading "-" (when allowed), digits, and an
// optional fractional part. Excess fractional digits are rejected unless they
// are zeros. No exponent notation, grouping separators, or whitespace inside
// the number are accepted.
func Parse(s, code string, opt ParseOptions) (int64, error) {
	exp := currency.Exponent(code)
	if exp < 0 {
		return 0, ErrUnknownCurrency
	}
	s = strings.TrimSpace(s)
	if s == "" || len(s) > 40 {
		return 0, ErrInvalidAmount
	}
	neg := false
	if s[0] == '-' || s[0] == '+' {
		neg = s[0] == '-'
		s = s[1:]
		if s == "" {
			return 0, ErrInvalidAmount
		}
	}
	intPart, fracPart, hasDot := strings.Cut(s, ".")
	if intPart == "" || (hasDot && fracPart == "") {
		return 0, ErrInvalidAmount
	}
	if !allDigits(intPart) || !allDigits(fracPart) {
		return 0, ErrInvalidAmount
	}
	if len(fracPart) > exp {
		if strings.Trim(fracPart[exp:], "0") != "" {
			return 0, ErrTooPrecise
		}
		fracPart = fracPart[:exp]
	}
	fracPart += strings.Repeat("0", exp-len(fracPart))
	digits := strings.TrimLeft(intPart+fracPart, "0")
	if digits == "" {
		digits = "0"
	}
	if len(digits) > 18 {
		return 0, ErrOutOfRange
	}
	var v int64
	for _, ch := range digits {
		v = v*10 + int64(ch-'0')
	}
	if v > MaxMinor {
		return 0, ErrOutOfRange
	}
	if v == 0 && !opt.AllowZero {
		return 0, ErrInvalidAmount
	}
	if neg && v != 0 {
		if !opt.AllowNegative {
			return 0, ErrNegative
		}
		v = -v
	}
	return v, nil
}

func allDigits(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}

// Format renders minor units as an exact decimal string ("-1234.50").
func Format(minor int64, code string) string {
	exp := currency.Exponent(code)
	if exp < 0 {
		exp = 2
	}
	return FormatExp(minor, exp)
}

// FormatExp renders minor units with an explicit exponent.
func FormatExp(minor int64, exp int) string {
	neg := minor < 0
	var u uint64
	if neg {
		u = uint64(-(minor + 1)) + 1 // safe for math.MinInt64
	} else {
		u = uint64(minor)
	}
	s := fmt.Sprintf("%d", u)
	if exp > 0 {
		if len(s) <= exp {
			s = strings.Repeat("0", exp-len(s)+1) + s
		}
		s = s[:len(s)-exp] + "." + s[len(s)-exp:]
	}
	if neg {
		s = "-" + s
	}
	return s
}

// Add returns a+b or ErrOverflow.
func Add(a, b int64) (int64, error) {
	c := a + b
	if (c > a) != (b > 0) {
		return 0, ErrOverflow
	}
	return c, nil
}

// Sub returns a-b or ErrOverflow.
func Sub(a, b int64) (int64, error) {
	c := a - b
	if (c < a) != (b > 0) {
		return 0, ErrOverflow
	}
	return c, nil
}

// Sum adds values with overflow detection.
func Sum(values ...int64) (int64, error) {
	var total int64
	var err error
	for _, v := range values {
		if total, err = Add(total, v); err != nil {
			return 0, err
		}
	}
	return total, nil
}

// RoundHalfAwayFromZero rounds a rational to the nearest integer, with ties
// rounded away from zero (Montra's documented rounding policy).
func RoundHalfAwayFromZero(r *big.Rat) (int64, error) {
	num := new(big.Int).Set(r.Num())
	den := r.Denom()
	neg := num.Sign() < 0
	if neg {
		num.Neg(num)
	}
	q, rem := new(big.Int).QuoRem(num, den, new(big.Int))
	// round up when 2*rem >= den
	if new(big.Int).Lsh(rem, 1).Cmp(den) >= 0 {
		q.Add(q, big.NewInt(1))
	}
	if neg {
		q.Neg(q)
	}
	if !q.IsInt64() {
		return 0, ErrOverflow
	}
	return q.Int64(), nil
}

// MulRatio computes round(amount * num / den) exactly.
func MulRatio(amount, num, den int64) (int64, error) {
	if den == 0 {
		return 0, errors.New("division by zero")
	}
	r := new(big.Rat).SetFrac(new(big.Int).Mul(big.NewInt(amount), big.NewInt(num)), big.NewInt(den))
	return RoundHalfAwayFromZero(r)
}

// ParseRate parses a positive exact decimal exchange rate (e.g. "83.1234").
func ParseRate(s string) (*big.Rat, error) {
	s = strings.TrimSpace(s)
	if s == "" || len(s) > 40 || strings.ContainsAny(s, "eE/+-") {
		return nil, ErrInvalidAmount
	}
	intPart, frac, _ := strings.Cut(s, ".")
	if intPart == "" || !allDigits(intPart) || !allDigits(frac) || len(frac) > 12 {
		return nil, ErrInvalidAmount
	}
	r, ok := new(big.Rat).SetString(s)
	if !ok || r.Sign() <= 0 {
		return nil, ErrInvalidAmount
	}
	return r, nil
}

// FormatRate renders a rate with up to 12 decimal places, trimming zeros.
func FormatRate(r *big.Rat) string {
	s := r.FloatString(12)
	s = strings.TrimRight(s, "0")
	return strings.TrimSuffix(s, ".")
}

// Conversion is the exact result of converting between currencies.
type Conversion struct {
	FromMinor     int64
	FromCurrency  string
	ToMinor       int64
	ToCurrency    string
	Rate          string // quote per 1 unit of base (major units)
	RoundingDelta string // exact (unrounded - rounded) in target minor units, as a decimal string
}

// Convert converts minor units of `from` into minor units of `to` using a
// rate expressed as `to` major units per 1 `from` major unit. The result is
// rounded half away from zero; the exact rounding delta is reported.
func Convert(amountMinor int64, from, to string, rate *big.Rat) (Conversion, error) {
	fe, te := currency.Exponent(from), currency.Exponent(to)
	if fe < 0 || te < 0 {
		return Conversion{}, ErrUnknownCurrency
	}
	if rate == nil || rate.Sign() <= 0 {
		return Conversion{}, ErrInvalidAmount
	}
	// to_minor = amount_minor / 10^fe * rate * 10^te
	exact := new(big.Rat).SetInt64(amountMinor)
	exact.Mul(exact, rate)
	exact.Mul(exact, new(big.Rat).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(te)), nil)))
	exact.Quo(exact, new(big.Rat).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(fe)), nil)))
	rounded, err := RoundHalfAwayFromZero(exact)
	if err != nil {
		return Conversion{}, err
	}
	if rounded > MaxMinor || rounded < -MaxMinor {
		return Conversion{}, ErrOutOfRange
	}
	delta := new(big.Rat).Sub(exact, new(big.Rat).SetInt64(rounded))
	return Conversion{
		FromMinor: amountMinor, FromCurrency: from, ToMinor: rounded, ToCurrency: to,
		Rate: FormatRate(rate), RoundingDelta: strings.TrimSuffix(strings.TrimRight(delta.FloatString(12), "0"), "."),
	}, nil
}

// PercentBasisPoints returns round(part/whole * 10000) (e.g. 7550 = 75.50 %).
// Returns 0 when whole is 0.
func PercentBasisPoints(part, whole int64) int64 {
	if whole == 0 {
		return 0
	}
	v, err := MulRatio(part, 10000, whole)
	if err != nil {
		return 0
	}
	return v
}
