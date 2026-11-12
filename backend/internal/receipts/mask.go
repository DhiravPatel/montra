package receipts

import (
	"strings"
	"unicode"
)

// maskPAN hides card and account numbers in a payment hint before it is
// stored. Digits joined only by spaces, dashes or dots (including their
// Unicode forms, such as a non-breaking space or an en dash) form one
// number, so "4111 1111 1111 1111", "4111-1111-1111-1111" and
// "4111111111111111" are the same number. A number with five or more
// digits keeps at most its last four: "•••• 1111" (the length is not
// revealed). Shorter numbers ("card ending 1234") stay as written.
//
// The migration helper montra.mask_payment_hint applies the same rule in
// the database with a subset of these separators, so it never changes a
// value masked here.
func maskPAN(s string) string {
	rs := []rune(s)
	var b strings.Builder
	for i := 0; i < len(rs); {
		if !unicode.IsDigit(rs[i]) {
			b.WriteRune(rs[i])
			i++
			continue
		}
		end, digits := scanNumber(rs, i)
		if len(digits) >= 5 {
			b.WriteString("•••• ")
			b.WriteString(string(digits[len(digits)-4:]))
		} else {
			b.WriteString(string(rs[i:end]))
		}
		i = end
	}
	return b.String()
}

// scanNumber reads the number starting at rs[start] (a digit): digits plus
// separators that have another digit after them. It returns the end of the
// number and its digits.
func scanNumber(rs []rune, start int) (int, []rune) {
	var digits []rune
	end := start
	for j := start; j < len(rs); {
		if unicode.IsDigit(rs[j]) {
			digits = append(digits, rs[j])
			j++
			end = j
			continue
		}
		k := j
		for k < len(rs) && panSeparator(rs[k]) {
			k++
		}
		if k == j || k == len(rs) || !unicode.IsDigit(rs[k]) {
			break // not a separator, or separators that end the number
		}
		j = k
	}
	return end, digits
}

// panSeparator reports characters people put between the digit groups of a
// card or account number: spaces, dashes and dots.
func panSeparator(r rune) bool {
	switch {
	case unicode.IsSpace(r), unicode.Is(unicode.Pd, r):
		return true
	}
	switch r {
	case '.', '\u2212', // minus sign
		'\u00b7', '\u2022', '\u2024', '\u2027', '\u30fb', '\uff0e', '\uff65': // middle dot, bullet, dot leader, hyphenation point, fullwidth/halfwidth dots
		return true
	}
	return false
}
