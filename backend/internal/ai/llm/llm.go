// Package llm is Montra's language-model boundary (spec §4.12, §20B.13,
// ADR-012). Models never compute financial facts or authorize anything:
// callers send minimal, redacted context, expose only read-only tools
// backed by deterministic services, and validate structured output against
// a schema. The provider is off unless configured, and every call reports
// model, latency, tokens and an estimated cost for internal accounting.
package llm

import (
	"context"
	"encoding/json"
	"errors"
	"time"
)

// Errors returned by providers. Callers fall back to deterministic results.
var (
	ErrNotConfigured = errors.New("ai provider is not configured")
	ErrUnavailable   = errors.New("ai provider is unavailable")
	ErrRateLimited   = errors.New("ai provider is rate limited")
	ErrRefused       = errors.New("ai provider declined the request")
	ErrTruncated     = errors.New("ai output was cut off")
	ErrBadOutput     = errors.New("ai output did not match the schema")
	ErrRejected      = errors.New("ai provider rejected the request")
)

// Block is one piece of user content.
type Block struct {
	Text string
	// Image or PDF bytes with their media type (image/jpeg, image/png,
	// image/webp, image/gif, application/pdf).
	MediaType string
	Data      []byte
}

// Tool is a read-only function the model may call.
type Tool struct {
	Name        string
	Description string
	// Properties and Required describe the JSON input object; the schema is
	// sent with additionalProperties=false and strict validation.
	Properties map[string]any
	Required   []string
}

// ToolCall is a model request to run a tool.
type ToolCall struct {
	ID    string
	Name  string
	Input json.RawMessage
}

// ToolRecord is an executed tool call with its (deterministic) output, kept
// so callers can verify that answers only cite tool results.
type ToolRecord struct {
	Name    string
	Input   json.RawMessage
	Output  string
	IsError bool
}

// ToolExecutor runs one tool call and returns its result text (JSON).
type ToolExecutor func(ctx context.Context, call ToolCall) (output string, isError bool)

// Request is one model task.
type Request struct {
	Feature string // ask | categorize | receipt | statement | narrative
	// System is stable instructions (cached); per-request data goes in
	// Blocks so the cached prefix never changes.
	System string
	Blocks []Block
	Tools  []Tool
	// Schema constrains the final answer (structured output). Every object
	// must list all properties as required with additionalProperties false.
	Schema    map[string]any
	MaxTokens int
	Effort    string // low | medium | high
	// MaxToolRounds bounds the tool loop (default 4).
	MaxToolRounds int
	// UserRef is an opaque per-user identifier for provider abuse
	// monitoring (never a name, email or account number).
	UserRef string
}

// Usage is token accounting for one call (all rounds).
type Usage struct {
	InputTokens      int64
	OutputTokens     int64
	CacheReadTokens  int64
	CacheWriteTokens int64
	CostMicroUSD     int64
}

// Result is a completed model call.
type Result struct {
	Text       string // final text; JSON when a Schema was given
	Model      string // the model that produced the answer (may be a fallback)
	StopReason string
	Usage      Usage
	Latency    time.Duration
	Tools      []ToolRecord
	Rounds     int
}

// Provider generates model output.
type Provider interface {
	Name() string
	Model() string
	Configured() bool
	Generate(ctx context.Context, req Request, exec ToolExecutor) (*Result, error)
}

// Disabled is the provider used when AI is off: every call fails with
// ErrNotConfigured and callers use deterministic results.
type Disabled struct{}

// Name implements Provider.
func (Disabled) Name() string { return "disabled" }

// Model implements Provider.
func (Disabled) Model() string { return "" }

// Configured implements Provider.
func (Disabled) Configured() bool { return false }

// Generate implements Provider.
func (Disabled) Generate(context.Context, Request, ToolExecutor) (*Result, error) {
	return nil, ErrNotConfigured
}

// Price is USD per million tokens.
type Price struct {
	Input, Output, CacheRead float64
}

// prices are first-party API list prices (USD per MTok) used to estimate
// cost internally; cache writes are billed at 1.25x input (5-minute TTL).
var prices = map[string]Price{
	"claude-fable-5-1":  {10, 50, 1},
	"claude-opus-5-5":   {4, 20, 0.20},
	"claude-opus-5":     {5, 25, 0.50},
	"claude-opus-4-8":   {5, 25, 0.50},
	"claude-sonnet-5-5": {2, 10, 0.20},
	"claude-sonnet-5":   {2, 10, 0.20},
	"claude-haiku-5-5":  {0.10, 0.50, 0.01},
}

// EstimateCost returns micro-USD for the usage on a model (0 when the
// model's price is unknown).
func EstimateCost(model string, u Usage) int64 {
	p, ok := prices[model]
	if !ok {
		return 0
	}
	// tokens × USD/MTok = micro-USD.
	c := float64(u.InputTokens)*p.Input + float64(u.OutputTokens)*p.Output + float64(u.CacheReadTokens)*p.CacheRead +
		float64(u.CacheWriteTokens)*p.Input*1.25
	return int64(c + 0.5)
}
