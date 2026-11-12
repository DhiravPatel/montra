package receipts

import (
	"strings"
	"testing"
	"unicode"
)

func TestMaskPANHidesCardNumbersInEveryFormat(t *testing.T) {
	for _, c := range []struct{ in, want string }{
		// Card numbers, however they are grouped.
		{"4111111111111111", "•••• 1111"},
		{"card 4111 1111 1111 1111", "card •••• 1111"},
		{"4111-1111-1111-1111", "•••• 1111"},
		{"4111.1111.1111.1111", "•••• 1111"},
		{"4111 - 1111 - 1111 - 1111", "•••• 1111"},
		{"Visa 4111  1111\t1111 1111 exp 12/27", "Visa •••• 1111 exp 12/27"},
		{"3782 822463 10005", "•••• 0005"},                  // Amex grouping
		{"4111\u00a01111\u00a01111\u00a01111", "•••• 1111"}, // non-breaking spaces
		{"4111\u20131111\u20141111\u22121111", "•••• 1111"}, // en dash, em dash, minus sign
		{"4111\u00b71111•1111\uff0e1111", "•••• 1111"},      // middle dot, bullet, fullwidth full stop
		{"४१११ ४१११ ४१११ १२३४", "•••• १२३४"},                // Devanagari digits are digits too
		{"card ••••••••••••1111", "card ••••••••••••1111"},  // already masked: unchanged
		{"card •••• 1111", "card •••• 1111"},
		// Account and UPI reference numbers (five or more digits).
		{"A/c 12345", "A/c •••• 2345"},
		{"UPI ref 4321 5678 9012", "UPI ref •••• 9012"},
		{"acct no.123456789", "acct no.•••• 6789"},
		// Short numbers and separators that do not join digits stay as written.
		{"card ending 1234", "card ending 1234"},
		{"1234 x 5678", "1234 x 5678"},
		{"a1b2c3d4e5f6", "a1b2c3d4e5f6"},
		{"4111 1111 ", "•••• 1111 "},
		{"-4111-1111-", "-•••• 1111-"},
		{"cash", "cash"},
		{"", ""},
		{"1234/5678", "1234/5678"},
	} {
		if got := maskPAN(c.in); got != c.want {
			t.Errorf("maskPAN(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

// No masked value keeps five digits that a reader could join into a number,
// and masking twice changes nothing.
func TestMaskPANLeavesNoLongDigitRuns(t *testing.T) {
	inputs := []string{
		"4111 1111 1111 1111", "4111-1111-1111-1111", "4111.1111.1111.1111", "41111111111111111111",
		"1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6", "12-34-56", "1.2.3.4.5", "card 4111 1111 1111 1111 and 5500 0000 0000 0004",
		"99999 88888", "0000\u202f1111\u20092222\u20073333",
	}
	for _, in := range inputs {
		out := maskPAN(in)
		if n := longestJoinedDigits([]rune(out)); n >= 5 {
			t.Errorf("maskPAN(%q) = %q keeps %d joined digits", in, out, n)
		}
		if again := maskPAN(out); again != out {
			t.Errorf("masking %q twice: %q then %q", in, out, again)
		}
	}
}

func longestJoinedDigits(rs []rune) int {
	longest := 0
	for i := 0; i < len(rs); i++ {
		if unicode.IsDigit(rs[i]) {
			_, digits := scanNumber(rs, i)
			if len(digits) > longest {
				longest = len(digits)
			}
		}
	}
	return longest
}

func TestMaskPANFitsTheStoredLength(t *testing.T) {
	// The hint is clipped to 60 characters after masking, so a clipped value
	// can only lose characters, never reveal digits.
	in := strings.Repeat("x", 55) + " 4111 1111 1111 1111"
	if got := trim(maskPAN(in), 60); got == nil || strings.Contains(*got, "4111") || len([]rune(*got)) > 60 {
		t.Fatalf("clipped hint = %v", got)
	}
}
