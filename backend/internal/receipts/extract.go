package receipts

import (
	"context"
	"errors"
)

// Page is one receipt image or PDF page file.
type Page struct {
	MIME string
	Data []byte
}

// ExtractedLine is a line-item candidate.
type ExtractedLine struct {
	Description string
	Quantity    string // decimal, e.g. "2" or "0.750"
	UnitPrice   string // decimal in the receipt currency
	Amount      string
	Tax         string
	Confidence  float64
}

// Extracted holds candidate values read from a receipt. They are never
// treated as confirmed financial data: the user reviews every value.
type Extracted struct {
	MerchantName    string
	Date            string // YYYY-MM-DD
	Time            string // HH:MM
	Currency        string
	Subtotal        string
	Tax             string
	Tip             string
	Discount        string
	Total           string
	PaymentHint     string
	ReceiptNumber   string
	LineItems       []ExtractedLine
	FieldConfidence map[string]float64
	Overall         float64
	Warnings        []string
}

// Extractor reads receipt candidates (deterministic text, AI vision, ...).
type Extractor interface {
	// Info returns the method (deterministic_text | ai_vision), provider,
	// model and extractor version recorded on each extraction.
	Info() (method, provider, model, version string)
	Configured() bool
	Extract(ctx context.Context, pages []Page) (*Extracted, error)
}

// ErrNotConfigured is returned when no extractor is available.
var ErrNotConfigured = errors.New("receipt extraction is not configured")

// NotConfigured is the default extractor: users enter receipt details
// manually until an extraction provider is configured (P9).
type NotConfigured struct{}

// Info implements Extractor.
func (NotConfigured) Info() (string, string, string, string) { return "ai_vision", "", "", "none" }

// Configured implements Extractor.
func (NotConfigured) Configured() bool { return false }

// Extract implements Extractor.
func (NotConfigured) Extract(context.Context, []Page) (*Extracted, error) {
	return nil, ErrNotConfigured
}
