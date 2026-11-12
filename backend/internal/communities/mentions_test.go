package communities

import (
	"reflect"
	"strings"
	"testing"
)

func TestMentions(t *testing.T) {
	cases := map[string][]string{
		"Thanks @Asha_K and @ravi.m!":    {"asha_k", "ravi.m"},
		"mail me at someone@example.com": nil,
		"@asha_k @ASHA_K @asha_k":        {"asha_k"},
		"(@ab) too short, @abc ok":       {"abc"},
		"ends with dot @priya.":          {"priya"},
		"no mentions here":               nil,
	}
	for in, want := range cases {
		if got := Mentions(in); !reflect.DeepEqual(got, want) {
			t.Errorf("Mentions(%q) = %v, want %v", in, got, want)
		}
	}
	var many []string
	for i := 0; i < 15; i++ {
		many = append(many, "@user_"+strings.Repeat("x", i+1))
	}
	if got := Mentions(strings.Join(many, " ")); len(got) != maxMentions {
		t.Fatalf("cap: %d", len(got))
	}
}
