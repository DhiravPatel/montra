// Package ledger defines how transactions affect account balances and how
// they are classified for income/expense reporting (ADR-007, ADR-023,
// docs/METRICS.md). It has no I/O.
package ledger

import "errors"

// Transaction types.
const (
	TypeExpense        = "expense"
	TypeIncome         = "income"
	TypeTransfer       = "transfer"
	TypeRefund         = "refund"
	TypeReimbursement  = "reimbursement"
	TypeAdjustment     = "adjustment"
	TypeOpeningBalance = "opening_balance"
	TypeGroupExpense   = "group_expense"
	TypeSettlement     = "settlement"
)

// Directions.
const (
	Inflow  = "inflow"
	Outflow = "outflow"
)

// Statuses.
const (
	StatusDraft    = "draft"
	StatusPending  = "pending"
	StatusPosted   = "posted"
	StatusVoided   = "voided"
	StatusReversed = "reversed"
)

// Errors.
var (
	ErrDirection  = errors.New("direction does not match transaction type")
	ErrTransition = errors.New("invalid status transition")
	ErrRefundCap  = errors.New("refunds and reimbursements would exceed the original amount")
)

// DirectionFor returns the fixed direction for a type, or "" when the
// caller must choose (transfer legs, adjustments, opening balances,
// settlements).
func DirectionFor(typ string) string {
	switch typ {
	case TypeExpense, TypeGroupExpense:
		return Outflow
	case TypeIncome, TypeRefund, TypeReimbursement:
		return Inflow
	}
	return ""
}

// ValidateDirection checks a type/direction pair.
func ValidateDirection(typ, dir string) error {
	if dir != Inflow && dir != Outflow {
		return ErrDirection
	}
	if fixed := DirectionFor(typ); fixed != "" && fixed != dir {
		return ErrDirection
	}
	return nil
}

// AffectsBalance reports whether a status moves money in the ledger.
// Drafts are plans; voided/reversed transactions have been reversed.
func AffectsBalance(status string) bool {
	return status == StatusPosted || status == StatusPending
}

// SignedAmount returns the ledger amount (+inflow, −outflow).
func SignedAmount(dir string, amountMinor int64) int64 {
	if dir == Outflow {
		return -amountMinor
	}
	return amountMinor
}

// Classification is how a transaction counts in cash-flow reporting.
type Classification struct {
	IncomeMinor  int64 // counts toward income
	ExpenseMinor int64 // counts toward gross expense (positive)
	RefundMinor  int64 // reduces expense (contra-expense, positive)
	Excluded     bool  // transfers, adjustments, opening balances, settlements
}

// Classify applies the documented reporting rules (docs/METRICS.md):
//   - income → income; expense → expense
//   - group_expense → only the payer's own share is expense (ADR-023); the
//     rest is a receivable, not spending
//   - refund/reimbursement → contra-expense (reduces net spending)
//   - transfer, adjustment, opening_balance, settlement → excluded
func Classify(typ string, amountMinor int64, personalShare *int64) Classification {
	switch typ {
	case TypeIncome:
		return Classification{IncomeMinor: amountMinor}
	case TypeExpense:
		return Classification{ExpenseMinor: amountMinor}
	case TypeGroupExpense:
		share := amountMinor
		if personalShare != nil {
			share = *personalShare
		}
		return Classification{ExpenseMinor: share}
	case TypeRefund, TypeReimbursement:
		return Classification{RefundMinor: amountMinor}
	}
	return Classification{Excluded: true}
}

// allowed status transitions.
var transitions = map[string][]string{
	StatusDraft:   {StatusPending, StatusPosted, StatusVoided},
	StatusPending: {StatusPosted, StatusVoided},
	StatusPosted:  {StatusVoided, StatusReversed},
	StatusVoided:  {StatusPosted}, // restore
}

// CanTransition validates a status change.
func CanTransition(from, to string) bool {
	if from == to {
		return true
	}
	for _, t := range transitions[from] {
		if t == to {
			return true
		}
	}
	return false
}

// CheckRefundCap enforces that the sum of refunds/reimbursements linked to
// an original does not exceed it, unless an explicit correction is made.
func CheckRefundCap(originalMinor, alreadyRefundedMinor, newMinor int64, correction bool) error {
	if correction {
		return nil
	}
	if alreadyRefundedMinor+newMinor > originalMinor {
		return ErrRefundCap
	}
	return nil
}

// RefundableTypes are originals that may receive refunds/reimbursements.
func RefundableTypes(typ string) bool {
	return typ == TypeExpense || typ == TypeGroupExpense
}
