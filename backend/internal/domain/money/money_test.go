package money

import (
	"errors"
	"math"
	"math/big"
	"testing"
)

func TestParse(t *testing.T) {
	pos := ParseOptions{}
	cases := []struct {
		in, cur string
		opt     ParseOptions
		want    int64
		err     error
	}{
		{"1234.50", "INR", pos, 123450, nil},
		{"1234.5", "INR", pos, 123450, nil},
		{"1234", "INR", pos, 123400, nil},
		{"0.01", "USD", pos, 1, nil},
		{"1234.500", "INR", pos, 123450, nil}, // trailing zeros beyond exponent are exact
		{"1234.505", "INR", pos, 0, ErrTooPrecise},
		{"1500", "JPY", pos, 1500, nil}, // zero-decimal currency
		{"1500.0", "JPY", pos, 1500, nil},
		{"1500.5", "JPY", pos, 0, ErrTooPrecise},
		{"1.234", "KWD", pos, 1234, nil}, // three-decimal currency
		{"1.2345", "KWD", pos, 0, ErrTooPrecise},
		{"-5.00", "INR", pos, 0, ErrNegative},
		{"-5.00", "INR", ParseOptions{AllowNegative: true}, -500, nil},
		{"+5", "INR", pos, 500, nil},
		{"0", "INR", pos, 0, ErrInvalidAmount},
		{"0", "INR", ParseOptions{AllowZero: true}, 0, nil},
		{"", "INR", pos, 0, ErrInvalidAmount},
		{"1e3", "INR", pos, 0, ErrInvalidAmount},
		{"1,234.00", "INR", pos, 0, ErrInvalidAmount},
		{"NaN", "INR", pos, 0, ErrInvalidAmount},
		{"Infinity", "INR", pos, 0, ErrInvalidAmount},
		{".5", "INR", pos, 0, ErrInvalidAmount},
		{"5.", "INR", pos, 0, ErrInvalidAmount},
		{"1 000", "INR", pos, 0, ErrInvalidAmount},
		{"10000000000000.00", "INR", pos, 1_000_000_000_000_000, nil}, // MaxMinor
		{"10000000000000.01", "INR", pos, 0, ErrOutOfRange},
		{"99999999999999999999", "INR", pos, 0, ErrOutOfRange},
		{"12.00", "XXX", pos, 0, ErrUnknownCurrency},
		{"  42.10 ", "USD", pos, 4210, nil},
	}
	for _, c := range cases {
		got, err := Parse(c.in, c.cur, c.opt)
		if !errors.Is(err, c.err) {
			t.Errorf("Parse(%q,%s) err = %v, want %v", c.in, c.cur, err, c.err)
			continue
		}
		if err == nil && got != c.want {
			t.Errorf("Parse(%q,%s) = %d, want %d", c.in, c.cur, got, c.want)
		}
	}
}

func TestFormat(t *testing.T) {
	cases := []struct {
		minor int64
		cur   string
		want  string
	}{
		{123450, "INR", "1234.50"},
		{5, "INR", "0.05"},
		{-5, "INR", "-0.05"},
		{0, "INR", "0.00"},
		{1500, "JPY", "1500"},
		{1234, "KWD", "1.234"},
		{7, "KWD", "0.007"},
		{math.MinInt64, "INR", "-92233720368547758.08"},
	}
	for _, c := range cases {
		if got := Format(c.minor, c.cur); got != c.want {
			t.Errorf("Format(%d,%s) = %q, want %q", c.minor, c.cur, got, c.want)
		}
	}
}

func TestAddSubOverflow(t *testing.T) {
	if _, err := Add(math.MaxInt64, 1); !errors.Is(err, ErrOverflow) {
		t.Fatal("expected overflow")
	}
	if _, err := Sub(math.MinInt64, 1); !errors.Is(err, ErrOverflow) {
		t.Fatal("expected overflow")
	}
	if v, err := Sum(1, 2, 3, -10); err != nil || v != -4 {
		t.Fatalf("Sum = %d, %v", v, err)
	}
}

func TestRounding(t *testing.T) {
	cases := []struct {
		num, den int64
		want     int64
	}{
		{5, 2, 3}, {-5, 2, -3}, {3, 2, 2}, {7, 3, 2}, {8, 3, 3}, {-7, 3, -2}, {1, 2, 1}, {-1, 2, -1}, {1, 3, 0},
	}
	for _, c := range cases {
		got, err := RoundHalfAwayFromZero(big.NewRat(c.num, c.den))
		if err != nil || got != c.want {
			t.Errorf("round(%d/%d) = %d, want %d", c.num, c.den, got, c.want)
		}
	}
}

func TestConvert(t *testing.T) {
	rate, _ := ParseRate("83.25")
	c, err := Convert(10000, "USD", "INR", rate) // $100.00
	if err != nil || c.ToMinor != 832500 {
		t.Fatalf("USD→INR = %+v, %v", c, err)
	}
	jpy, _ := ParseRate("0.0067")
	c, err = Convert(1000, "JPY", "USD", jpy) // ¥1000 → $6.70
	if err != nil || c.ToMinor != 670 {
		t.Fatalf("JPY→USD = %+v, %v", c, err)
	}
	kwd, _ := ParseRate("270.123")
	c, err = Convert(1234, "KWD", "INR", kwd) // 1.234 KWD → ₹333.33 (333.331782)
	if err != nil || c.ToMinor != 33333 {
		t.Fatalf("KWD→INR = %+v, %v", c, err)
	}
	if c.RoundingDelta == "" {
		t.Fatal("expected rounding delta")
	}
	if _, err := ParseRate("-1"); err == nil {
		t.Fatal("negative rate accepted")
	}
	if _, err := ParseRate("1e5"); err == nil {
		t.Fatal("exponent rate accepted")
	}
}

func TestPercentBasisPoints(t *testing.T) {
	if got := PercentBasisPoints(755, 1000); got != 7550 {
		t.Fatalf("got %d", got)
	}
	if got := PercentBasisPoints(1, 3); got != 3333 {
		t.Fatalf("got %d", got)
	}
	if got := PercentBasisPoints(5, 0); got != 0 {
		t.Fatalf("got %d", got)
	}
}

// FuzzParseFormatRoundTrip checks Parse(Format(x)) == x for all in-range
// values and that Parse never panics.
func FuzzParseFormatRoundTrip(f *testing.F) {
	for _, s := range []string{"0.01", "1234.50", "-9.99", "1e5", "..", "99999999999999.99"} {
		f.Add(s, "INR")
	}
	f.Add("1.234", "KWD")
	f.Add("15", "JPY")
	f.Fuzz(func(t *testing.T, s, cur string) {
		v, err := Parse(s, cur, ParseOptions{AllowNegative: true, AllowZero: true})
		if err != nil {
			return
		}
		if v > MaxMinor || v < -MaxMinor {
			t.Fatalf("out of range accepted: %d", v)
		}
		back, err := Parse(Format(v, cur), cur, ParseOptions{AllowNegative: true, AllowZero: true})
		if err != nil || back != v {
			t.Fatalf("round trip %q → %d → %q → %d (%v)", s, v, Format(v, cur), back, err)
		}
	})
}
