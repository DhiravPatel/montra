package textsafe

import (
	"errors"
	"strings"
	"testing"
)

func TestClean(t *testing.T) {
	cases := []struct {
		in, want string
		err      error
	}{
		{"  hello\r\nworld  ", "hello\nworld", nil},
		{"a\u202Eevil\u200Btext\u00AD", "aeviltext", nil},
		{"line\x00one\x07", "lineone", nil},
		{"tab\tseparated", "tab separated", nil},
		{"a\n\n\n\n\n\nb", "a\n\n\nb", nil},
		{"   ", "", ErrEmpty},
		{string([]byte{0xff, 0xfe}), "", ErrEncoding},
	}
	for _, c := range cases {
		got, err := Clean(c.in, 1, 50)
		if !errors.Is(err, c.err) || got != c.want {
			t.Fatalf("Clean(%q) = %q, %v; want %q, %v", c.in, got, err, c.want, c.err)
		}
	}
	if _, err := Clean(strings.Repeat("é", 51), 1, 50); !errors.Is(err, ErrTooLong) {
		t.Fatalf("rune limit: %v", err)
	}
	if got, err := Clean(strings.Repeat("é", 50), 1, 50); err != nil || got == "" {
		t.Fatalf("50 runes must fit: %v", err)
	}
}

func TestSecret(t *testing.T) {
	secret := []string{
		"my card 4111 1111 1111 1111 works",
		"4111-1111-1111-1111",
		"CVV 123", "cvv: 4567", "My UPI PIN is 4321", "OTP: 556677", "one-time password 123456",
		"password: hunter22", "netbanking password = s3cret!",
	}
	for _, s := range secret {
		if !Secret(s) {
			t.Fatalf("Secret(%q) = false", s)
		}
	}
	fine := []string{
		"Can a moderator pin this post?", "I saved 4500 this month", "Phone 9876543210",
		"Order 1234 5678 9012 3456", // not Luhn-valid
		"I changed my password today", "pin 12", "The OTP never arrived",
	}
	for _, s := range fine {
		if Secret(s) {
			t.Fatalf("Secret(%q) = true", s)
		}
	}
}

func TestLink(t *testing.T) {
	ok := map[string]string{
		"https://Example.com/a?b=1#frag": "https://example.com/a?b=1",
		" https://rbi.org.in/scripts ":   "https://rbi.org.in/scripts",
		"https://xn--n3h.example/path":   "https://xn--n3h.example/path",
	}
	for in, want := range ok {
		got, err := Link(in)
		if err != nil || got != want {
			t.Fatalf("Link(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	bad := []string{"http://example.com", "javascript:alert(1)", "https://user:pw@example.com", "https://127.0.0.1/x", "https://[::1]/",
		"https://localhost/x", "https://intranet/x", "https://printer.local/", "https://exaаmple.com", "data:text/html,hi", "",
		"https://" + strings.Repeat("a", 500) + ".com"}
	for _, in := range bad {
		if _, err := Link(in); err == nil {
			t.Fatalf("Link(%q) accepted", in)
		}
	}
	if n := Links("see https://a.com and http://b.org, also HTTPS://c.net"); n != 3 {
		t.Fatalf("Links = %d", n)
	}
}

// Too-short text is told apart from empty text (still matching ErrEmpty
// for older callers) and every error maps to a stable detail code.
func TestCodes(t *testing.T) {
	_, short := Clean(" ab\u200b ", 3, 10)
	_, empty := Clean(" \u200b ", 3, 10)
	_, long := Clean("abcdefghijk", 3, 10)
	_, enc := Clean(string([]byte{0xff}), 1, 10)
	_, link := Link("http://example.com")
	if !errors.Is(short, ErrTooShort) || !errors.Is(short, ErrEmpty) || errors.Is(empty, ErrTooShort) {
		t.Fatalf("short = %v, empty = %v", short, empty)
	}
	for err, want := range map[error]string{short: CodeTooShort, empty: CodeRequired, long: CodeTooLong, enc: CodeInvalidCharacters, link: CodeInsecureLink} {
		if got := Code(err); got != want {
			t.Fatalf("Code(%v) = %q, want %q", err, got, want)
		}
	}
}

func FuzzClean(f *testing.F) {
	f.Add("hello\u202E\r\nworld")
	f.Fuzz(func(t *testing.T, s string) {
		out, err := Clean(s, 0, 10000)
		if err != nil {
			return
		}
		for _, r := range out {
			if (r < 0x20 && r != '\n') || invisible(r) || r == 0x7f {
				t.Fatalf("Clean left %U in %q", r, out)
			}
		}
	})
}
