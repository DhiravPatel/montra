package imports

import (
	"errors"
	"maps"
	"testing"

	"montra/backend/internal/platform/apperr"
)

// A refused row keeps the specific reason, never the request envelope.
func TestRowFailureKeepsTheSpecificReason(t *testing.T) {
	cases := []struct {
		name string
		err  error
		want failure
	}{
		{"future date", apperr.FieldError("body.occurred_at", "Date is too far in the future."),
			failure{"failed", "invalid_date", "Date is too far in the future.", nil}},
		{"date out of range", apperr.FieldError("body.local_date", "Date is out of range."),
			failure{"failed", "invalid_date", "Date is out of range.", nil}},
		{"archived category", apperr.FieldError("body.category_id", "This category is archived."),
			failure{"failed", "invalid_category", "This category is archived.", nil}},
		{"unknown field", apperr.FieldError("body.payment_method_id", "Payment method not found."),
			failure{"failed", "invalid_row", "Payment method not found.", nil}},
		{"domain rule", apperr.Rule("account_inactive", "This account is archived or closed.", map[string]string{"x": "1"}),
			failure{"failed", "account_inactive", "This account is archived or closed.", map[string]string{"x": "1"}}},
		{"bank id exists", apperr.New(apperr.CodeDuplicate, 409, "A transaction with this external reference already exists in the account."),
			failure{"duplicate", "already_imported", "A transaction with this bank ID already exists.", map[string]string{"matched_by": "external_id"}}},
		{"other refusal", apperr.Conflict("Something changed."), failure{"failed", "rejected", "Something changed.", nil}},
	}
	for _, tc := range cases {
		got, ok := rowFailure(tc.err)
		if !ok || got.status != tc.want.status || got.code != tc.want.code || got.message != tc.want.message || !maps.Equal(got.params, tc.want.params) {
			t.Errorf("%s: got %+v (%v), want %+v", tc.name, got, ok, tc.want)
		}
		if got.message == "The request could not be processed." {
			t.Errorf("%s: stored the envelope message", tc.name)
		}
	}
	for _, err := range []error{errors.New("connection reset"), apperr.Internal(errors.New("boom"))} {
		if _, ok := rowFailure(err); ok {
			t.Errorf("infrastructure error %v must be retried, not stored on the row", err)
		}
	}
	if f, ok := errorFields["invalid_date"]; !ok || f != "posted_date" {
		t.Errorf("invalid_date points at %q", f)
	}
}
