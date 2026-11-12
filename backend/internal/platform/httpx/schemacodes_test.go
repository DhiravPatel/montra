package httpx

import (
	"context"
	"fmt"
	"testing"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/validation"
)

// Schema failures keep Huma's message and gain a stable detail code. The
// messages come from Huma's own formats, so an upgrade that changes them
// fails here.
func TestSchemaDetailCodes(t *testing.T) {
	cases := []struct {
		msg, code, key, val string
	}{
		{fmt.Sprintf(validation.MsgExpectedMinLength, 3), "too_short", "min", "3"},
		{fmt.Sprintf(validation.MsgExpectedMaxLength, 80), "too_long", "max", "80"},
		{fmt.Sprintf(validation.MsgExpectedMinItems, 2), "too_few", "min", "2"},
		{fmt.Sprintf(validation.MsgExpectedMaxItems, 10), "too_many", "max", "10"},
		{fmt.Sprintf(validation.MsgExpectedMinimumNumber, 1), "too_small", "min", "1"},
		{fmt.Sprintf(validation.MsgExpectedExclusiveMinimumNumber, 0), "too_small", "min", "0"},
		{fmt.Sprintf(validation.MsgExpectedMaximumNumber, 3650), "too_large", "max", "3650"},
		{fmt.Sprintf(validation.MsgExpectedRequiredProperty, "title"), "required", "property", "title"},
		{fmt.Sprintf(validation.MsgExpectedOneOf, "public, private"), "invalid_choice", "allowed", "public, private"},
		{fmt.Sprintf(validation.MsgExpectedMatchPattern, "^[a-z]+$"), "invalid_format", "", ""},
		{validation.MsgExpectedRFC3339DateTime, "invalid_format", "", ""},
		{validation.MsgExpectedString, "invalid_type", "", ""},
		{validation.MsgUnexpectedProperty, "unexpected_property", "", ""},
		{"something else", "", "", ""},
	}
	for _, c := range cases {
		d := schemaDetail("body.x", c.msg)
		if d.Code != c.code || d.Message != c.msg || d.Field != "body.x" || (c.key != "" && d.Params[c.key] != c.val) || (c.key == "" && d.Params != nil) {
			t.Fatalf("schemaDetail(%q) = %+v; want code %q %s=%q", c.msg, d, c.code, c.key, c.val)
		}
	}
	// Framework errors reach clients through BuildError.
	resp := BuildError(context.Background(), 422, "validation failed", &huma.ErrorDetail{Location: "body.name",
		Message: fmt.Sprintf(validation.MsgExpectedMinLength, 3)})
	if len(resp.Err.Details) != 1 || resp.Err.Details[0].Code != "too_short" || resp.Err.Details[0].Params["min"] != "3" {
		t.Fatalf("BuildError details = %+v", resp.Err.Details)
	}
}
