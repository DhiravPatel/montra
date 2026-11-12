package analytics

import (
	"reflect"
	"strings"
	"testing"
)

// The contract's widget key enum must list every registered widget, in the
// default order, so generated clients know them all.
func TestWidgetKeyEnumMatchesRegistry(t *testing.T) {
	f, ok := reflect.TypeOf(WidgetDTO{}).FieldByName("Key")
	if !ok {
		t.Fatal("WidgetDTO.Key missing")
	}
	if got, want := f.Tag.Get("enum"), strings.Join(widgetRegistry, ","); got != want {
		t.Fatalf("WidgetDTO.Key enum = %q, registry = %q", got, want)
	}
}
