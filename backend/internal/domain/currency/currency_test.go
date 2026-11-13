package currency

import (
	"regexp"
	"testing"
	"time"
)

func TestLookupKnownCurrencies(t *testing.T) {
	cases := []struct {
		code, name, symbol string
		exp                int
	}{
		{"INR", "Indian Rupee", "₹", 2},
		{"USD", "US Dollar", "$", 2},
		{"EUR", "Euro", "€", 2},
		{"JPY", "Yen", "¥", 0},
		{"KRW", "Won", "₩", 0},
		{"BHD", "Bahraini Dinar", "", 3},
		{"KWD", "Kuwaiti Dinar", "", 3},
		{"CLP", "Chilean Peso", "", 0},
	}
	for _, c := range cases {
		got, ok := Lookup(c.code)
		if !ok {
			t.Fatalf("Lookup(%q) not found", c.code)
		}
		if got.Code != c.code || got.Name != c.name || got.Exponent != c.exp || got.Symbol != c.symbol {
			t.Errorf("Lookup(%q) = %+v, want name %q exponent %d symbol %q", c.code, got, c.name, c.exp, c.symbol)
		}
		if !Valid(c.code) || Exponent(c.code) != c.exp {
			t.Errorf("%s: Valid=%v Exponent=%d", c.code, Valid(c.code), Exponent(c.code))
		}
	}
}

func TestUnknownAndMalformedCodes(t *testing.T) {
	for _, code := range []string{"", "inr", "Inr", "XXX", "ABCD", "IN", " INR", "INR ", "XAU", "XTS"} {
		if _, ok := Lookup(code); ok {
			t.Errorf("Lookup(%q) found a currency", code)
		}
		if Valid(code) || Selectable(code) {
			t.Errorf("%q: Valid=%v Selectable=%v, want false", code, Valid(code), Selectable(code))
		}
		if Exponent(code) != -1 {
			t.Errorf("Exponent(%q) = %d, want -1", code, Exponent(code))
		}
	}
}

// Retired currencies stay valid for history but cannot be chosen for new
// records, and name the currency that replaced them.
func TestRetiredCurrencies(t *testing.T) {
	bgn, ok := Lookup("BGN")
	if !ok || !Valid("BGN") {
		t.Fatal("BGN must stay valid for historical records")
	}
	if Selectable("BGN") {
		t.Error("BGN must not be selectable for new records")
	}
	if bgn.ReplacedBy != "EUR" || bgn.RetiredOn != "2026-01-01" || bgn.Exponent != 2 {
		t.Errorf("BGN = %+v", bgn)
	}
	for code, r := range retired {
		c, ok := Lookup(code)
		if !ok {
			t.Fatalf("retired %s missing from the registry", code)
		}
		if !Selectable(r[0]) {
			t.Errorf("%s is replaced by %s, which is not selectable", code, r[0])
		}
		if _, err := time.Parse("2006-01-02", c.RetiredOn); err != nil {
			t.Errorf("%s retired on %q: %v", code, c.RetiredOn, err)
		}
	}
}

// Every registry entry is well-formed: a three-letter upper-case code that
// matches its key, a name, and an exponent the database accepts (0-4).
func TestRegistryInvariants(t *testing.T) {
	codeRe := regexp.MustCompile(`^[A-Z]{3}$`)
	all := All()
	if len(all) != len(registry) || len(all) < 150 {
		t.Fatalf("All() returned %d of %d currencies", len(all), len(registry))
	}
	retiredSeen := 0
	for i, c := range all {
		if i > 0 && all[i-1].Code >= c.Code {
			t.Fatalf("All() not strictly sorted at %d: %s then %s", i, all[i-1].Code, c.Code)
		}
		if !codeRe.MatchString(c.Code) || c.Name == "" || c.Exponent < 0 || c.Exponent > 4 {
			t.Errorf("malformed currency %+v", c)
		}
		if got, _ := Lookup(c.Code); got != c {
			t.Errorf("All() and Lookup disagree for %s", c.Code)
		}
		if (c.ReplacedBy == "") != (c.RetiredOn == "") {
			t.Errorf("%s: ReplacedBy and RetiredOn must be set together", c.Code)
		}
		if c.ReplacedBy != "" {
			retiredSeen++
		} else if !Selectable(c.Code) {
			t.Errorf("%s is current but not selectable", c.Code)
		}
	}
	if retiredSeen != len(retired) {
		t.Errorf("found %d retired currencies, want %d", retiredSeen, len(retired))
	}
}

// All returns a copy: changing it never changes the registry.
func TestAllReturnsACopy(t *testing.T) {
	all := All()
	all[0].Exponent = 9
	all[0].Name = "changed"
	if c, _ := Lookup(all[0].Code); c.Exponent == 9 || c.Name == "changed" {
		t.Fatal("All() exposed the registry")
	}
}
