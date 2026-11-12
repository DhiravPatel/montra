package ledger

import (
	"errors"
	"testing"
)

func TestClassifyExcludesTransfersAndCountsGroupShare(t *testing.T) {
	share := int64(1000)
	if c := Classify(TypeGroupExpense, 3000, &share); c.ExpenseMinor != 1000 {
		t.Fatalf("group expense should count only the payer's share, got %d", c.ExpenseMinor)
	}
	for _, typ := range []string{TypeTransfer, TypeAdjustment, TypeOpeningBalance, TypeSettlement} {
		if c := Classify(typ, 500, nil); !c.Excluded || c.ExpenseMinor != 0 || c.IncomeMinor != 0 {
			t.Errorf("%s must be excluded from income/expense", typ)
		}
	}
	if c := Classify(TypeRefund, 200, nil); c.RefundMinor != 200 || c.IncomeMinor != 0 {
		t.Fatal("refund must be contra-expense, not income")
	}
}

func TestDirectionAndTransitions(t *testing.T) {
	if err := ValidateDirection(TypeExpense, Inflow); !errors.Is(err, ErrDirection) {
		t.Fatal("expense inflow accepted")
	}
	if err := ValidateDirection(TypeAdjustment, Inflow); err != nil {
		t.Fatal(err)
	}
	if !CanTransition(StatusPosted, StatusVoided) || !CanTransition(StatusVoided, StatusPosted) {
		t.Fatal("void/restore transitions must be allowed")
	}
	if CanTransition(StatusPosted, StatusDraft) {
		t.Fatal("posted → draft must be rejected")
	}
	if SignedAmount(Outflow, 100) != -100 || SignedAmount(Inflow, 100) != 100 {
		t.Fatal("sign convention")
	}
}

func TestRefundCap(t *testing.T) {
	if err := CheckRefundCap(1000, 600, 400, false); err != nil {
		t.Fatal("exact cap must be allowed")
	}
	if err := CheckRefundCap(1000, 600, 401, false); !errors.Is(err, ErrRefundCap) {
		t.Fatal("over-refund accepted")
	}
	if err := CheckRefundCap(1000, 600, 401, true); err != nil {
		t.Fatal("explicit correction must bypass the cap")
	}
}
