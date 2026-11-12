// Package textsafe normalizes user-generated text for community content
// (spec §20B.17): it removes control and invisible formatting characters
// (bidi overrides, zero-width), enforces limits, validates links, and
// detects payment secrets that must never be posted (card numbers, CVVs,
// PINs, OTPs). Content is stored and served as plain text; clients render
// it escaped, never as HTML.
package textsafe

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Errors.
var (
	ErrEmpty = errors.New("text is empty")
	// ErrTooShort is text that is not empty but shorter than the minimum.
	// It wraps ErrEmpty, so callers that only check ErrEmpty keep working.
	ErrTooShort = fmt.Errorf("text is too short: %w", ErrEmpty)
	ErrTooLong  = errors.New("text is too long")
	ErrEncoding = errors.New("text is not valid UTF-8")
	ErrLink     = errors.New("link must be a public https URL")
)

// Stable codes for problems in user text, sent as API error detail codes
// (error.details[].code) so clients can localize them.
const (
	CodeRequired          = "required"           // empty after cleaning
	CodeTooShort          = "too_short"          // shorter than the minimum (params: min)
	CodeTooLong           = "too_long"           // longer than the maximum (params: max)
	CodeInvalidCharacters = "invalid_characters" // not valid text
	CodeContainsSecret    = "contains_secret"    // a card number, CVV, PIN, OTP or password
	CodeTooManyLinks      = "too_many_links"     // more links than allowed (params: max)
	CodeInsecureLink      = "insecure_link"      // not a public https link
)

// Problem returns the detail code for an error from Clean (with the
// limits of the call) or Link, and the values the code refers to: min for
// too_short, max for too_long.
func Problem(err error, minRunes, maxRunes int) (code string, params map[string]string) {
	code = Code(err)
	switch code {
	case CodeTooShort:
		params = map[string]string{"min": strconv.Itoa(minRunes)}
	case CodeTooLong:
		params = map[string]string{"max": strconv.Itoa(maxRunes)}
	}
	return code, params
}

// Code returns the detail code for an error from Clean or Link.
func Code(err error) string {
	switch {
	case errors.Is(err, ErrTooShort):
		return CodeTooShort
	case errors.Is(err, ErrEmpty):
		return CodeRequired
	case errors.Is(err, ErrTooLong):
		return CodeTooLong
	case errors.Is(err, ErrLink):
		return CodeInsecureLink
	default:
		return CodeInvalidCharacters
	}
}

// invisible formatting characters that enable spoofing (bidi overrides,
// zero-width joiners and spaces, BOM, word joiner, soft hyphen).
func invisible(r rune) bool {
	switch {
	case r >= 0x200B && r <= 0x200F, r >= 0x202A && r <= 0x202E, r >= 0x2060 && r <= 0x2069, r == 0xFEFF, r == 0x00AD, r == 0x180E:
		return true
	}
	return false
}

// Clean trims, normalizes line endings, drops control and invisible
// characters (keeping newlines and tabs), collapses runs of more than two
// blank lines and enforces maxRunes. minRunes 0 allows empty text.
func Clean(s string, minRunes, maxRunes int) (string, error) {
	if !utf8.ValidString(s) {
		return "", ErrEncoding
	}
	s = strings.ReplaceAll(strings.ReplaceAll(s, "\r\n", "\n"), "\r", "\n")
	var b strings.Builder
	b.Grow(len(s))
	newlines := 0
	for _, r := range s {
		switch {
		case r == '\n':
			newlines++
			if newlines > 3 {
				continue
			}
			b.WriteRune(r)
			continue
		case r == '\t':
			b.WriteRune(' ')
		case unicode.IsControl(r) || invisible(r):
			continue
		default:
			b.WriteRune(r)
		}
		newlines = 0
	}
	out := strings.TrimSpace(b.String())
	n := utf8.RuneCountInString(out)
	if n == 0 && minRunes > 0 {
		return "", ErrEmpty
	}
	if n < minRunes {
		return "", ErrTooShort
	}
	if maxRunes > 0 && n > maxRunes {
		return "", ErrTooLong
	}
	return out, nil
}

var (
	digitRun = regexp.MustCompile(`(?:\d[ -]?){13,19}`)
	// Labelled numeric secrets ("CVV 123", "my UPI PIN is 4321", "OTP: 556677")
	// and explicitly assigned passwords ("password: hunter22").
	secretWords = regexp.MustCompile(`(?i)\b(?:cvv2?|cvc|upi\s*pin|atm\s*pin|mpin|pin|otp|one[- ]time\s+(?:password|code))\b\s*(?:is|:|=|-)?\s*\d{3,8}\b` +
		`|\b(?:net\s*banking\s+)?password\s*[:=]\s*\S{4,}`)
	linkRe = regexp.MustCompile(`(?i)\bhttps?://`)
)

// Secret reports whether the text appears to contain a card number
// (Luhn-valid 13-19 digits) or a labelled CVV, PIN, OTP or password.
func Secret(s string) bool {
	if secretWords.MatchString(s) {
		return true
	}
	for _, run := range digitRun.FindAllString(s, -1) {
		if Luhn(strings.NewReplacer(" ", "", "-", "").Replace(strings.TrimSpace(run))) {
			return true
		}
	}
	return false
}

// Luhn validates a 13-19 digit card number checksum.
func Luhn(d string) bool {
	if len(d) < 13 || len(d) > 19 {
		return false
	}
	sum, alt := 0, false
	for i := len(d) - 1; i >= 0; i-- {
		c := d[i]
		if c < '0' || c > '9' {
			return false
		}
		n := int(c - '0')
		if alt {
			if n *= 2; n > 9 {
				n -= 9
			}
		}
		sum += n
		alt = !alt
	}
	return sum%10 == 0
}

// Links counts http(s) links in free text.
func Links(s string) int { return len(linkRe.FindAllStringIndex(s, -1)) }

// Link validates an attached resource link: absolute https, a public DNS
// host (no IP literals, localhost or credentials), at most 500 bytes. It
// returns the normalized URL.
func Link(raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" || len(raw) > 500 {
		return "", ErrLink
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Opaque != "" {
		return "", ErrLink
	}
	host := strings.ToLower(u.Hostname())
	if host == "" || host == "localhost" || strings.HasSuffix(host, ".localhost") || strings.HasSuffix(host, ".local") ||
		strings.HasSuffix(host, ".internal") || net.ParseIP(host) != nil || !strings.Contains(host, ".") {
		return "", ErrLink
	}
	for _, r := range host {
		if r != '.' && r != '-' && (r < 'a' || r > 'z') && (r < '0' || r > '9') {
			return "", ErrLink // punycode only (xn--): no homoglyph hosts
		}
	}
	u.Host = strings.ToLower(u.Host)
	u.Fragment = ""
	return u.String(), nil
}
