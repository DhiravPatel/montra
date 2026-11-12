// Package apitypes holds wire types shared across API modules.
package apitypes

import (
	"montra/backend/internal/domain/money"
)

// Money is the API representation of an amount (ADR-006): exact integer
// minor units plus the exact decimal string and ISO 4217 currency. Clients
// display `amount` and never perform floating-point arithmetic.
type Money struct {
	AmountMinor int64  `json:"amount_minor" doc:"Integer minor units (e.g. paise)"`
	Amount      string `json:"amount" doc:"Exact decimal string in major units"`
	Currency    string `json:"currency" doc:"ISO 4217 code" example:"INR"`
}

// M builds a Money value.
func M(minor int64, currency string) Money {
	return Money{AmountMinor: minor, Amount: money.Format(minor, currency), Currency: currency}
}

// MP builds an optional Money value.
func MP(minor *int64, currency string) *Money {
	if minor == nil {
		return nil
	}
	m := M(*minor, currency)
	return &m
}
