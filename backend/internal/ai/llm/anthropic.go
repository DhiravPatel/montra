package llm

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/anthropics/anthropic-sdk-go/v2"
	"github.com/anthropics/anthropic-sdk-go/v2/option"
	"github.com/anthropics/anthropic-sdk-go/v2/shared/constant"
)

// AnthropicConfig configures the Claude provider.
type AnthropicConfig struct {
	APIKey  string
	Model   string        // default claude-opus-5-5
	Timeout time.Duration // per HTTP attempt
	BaseURL string        // tests only (httptest fake); empty = Anthropic API
	Retries int           // SDK retries for 408/409/429/5xx and connection errors
}

// Anthropic calls Claude through the official Go SDK (Messages API, beta
// surface for server-side refusal fallbacks).
type Anthropic struct {
	client anthropic.Client
	model  string
}

// NewAnthropic builds the provider. It never reads ANTHROPIC_* environment
// variables implicitly: configuration comes from Montra's config only.
func NewAnthropic(cfg AnthropicConfig) *Anthropic {
	model := cfg.Model
	if model == "" {
		model = "claude-opus-5-5"
	}
	opts := []option.RequestOption{option.WithAPIKey(cfg.APIKey), option.WithMaxRetries(max(cfg.Retries, 0))}
	if cfg.Timeout > 0 {
		opts = append(opts, option.WithRequestTimeout(cfg.Timeout))
	}
	if cfg.BaseURL != "" {
		opts = append(opts, option.WithBaseURL(cfg.BaseURL))
	}
	return &Anthropic{client: anthropic.NewClient(opts...), model: model}
}

// Name implements Provider.
func (a *Anthropic) Name() string { return "anthropic" }

// Model implements Provider.
func (a *Anthropic) Model() string { return a.model }

// Configured implements Provider.
func (a *Anthropic) Configured() bool { return true }

func userBlocks(blocks []Block) ([]anthropic.BetaContentBlockParamUnion, error) {
	out := make([]anthropic.BetaContentBlockParamUnion, 0, len(blocks))
	// Documents and images go before the text that refers to them.
	for _, b := range blocks {
		if b.MediaType == "" {
			continue
		}
		data := base64.StdEncoding.EncodeToString(b.Data)
		switch b.MediaType {
		case "application/pdf":
			out = append(out, anthropic.NewBetaDocumentBlock(anthropic.BetaBase64PDFSourceParam{Data: data}))
		case "image/jpeg", "image/png", "image/webp", "image/gif":
			out = append(out, anthropic.NewBetaImageBlock(anthropic.BetaBase64ImageSourceParam{Data: data,
				MediaType: anthropic.BetaBase64ImageSourceMediaType(b.MediaType)}))
		default:
			return nil, fmt.Errorf("%w: unsupported media type %s", ErrRejected, b.MediaType)
		}
	}
	for _, b := range blocks {
		if b.MediaType == "" && b.Text != "" {
			out = append(out, anthropic.NewBetaTextBlock(b.Text))
		}
	}
	return out, nil
}

func betaTools(tools []Tool) []anthropic.BetaToolUnionParam {
	out := make([]anthropic.BetaToolUnionParam, 0, len(tools))
	for _, t := range tools {
		props := t.Properties
		if props == nil {
			props = map[string]any{}
		}
		req := t.Required
		if req == nil {
			req = []string{}
		}
		tp := anthropic.BetaToolParam{
			Name:        t.Name,
			Description: anthropic.String(t.Description),
			Strict:      anthropic.Bool(true),
			InputSchema: anthropic.BetaToolInputSchemaParam{Properties: props, Required: req,
				ExtraFields: map[string]any{"additionalProperties": false}},
		}
		out = append(out, anthropic.BetaToolUnionParam{OfTool: &tp})
	}
	return out
}

// Generate runs the request, executing tool calls through exec until the
// model answers (append-only history within the call) or MaxToolRounds is
// reached.
func (a *Anthropic) Generate(ctx context.Context, req Request, exec ToolExecutor) (*Result, error) {
	start := time.Now()
	content, err := userBlocks(req.Blocks)
	if err != nil {
		return nil, err
	}
	maxTokens := int64(req.MaxTokens)
	if maxTokens <= 0 {
		maxTokens = 4096
	}
	effort := anthropic.BetaOutputConfigEffort(req.Effort)
	if effort == "" {
		effort = anthropic.BetaOutputConfigEffortMedium
	}
	params := anthropic.BetaMessageNewParams{
		Model:     a.model,
		MaxTokens: maxTokens,
		// Stable instructions first, cached; per-request data is in Messages.
		System:   []anthropic.BetaTextBlockParam{{Text: req.System, CacheControl: anthropic.NewBetaCacheControlEphemeralParam()}},
		Messages: []anthropic.BetaMessageParam{anthropic.NewBetaUserMessage(content...)},
		// A policy decline is re-served by a fallback model in the same call.
		Betas:        []anthropic.AnthropicBeta{anthropic.AnthropicBetaServerSideFallback2026_07_01},
		Fallbacks:    anthropic.BetaFallbacksParamUnion{OfDefault: constant.ValueOf[constant.Default]()},
		OutputConfig: anthropic.BetaOutputConfigParam{Effort: effort},
	}
	if req.Schema != nil {
		params.OutputConfig.Format = anthropic.BetaJSONOutputFormatParam{Schema: req.Schema}
	}
	if req.UserRef != "" {
		params.Metadata = anthropic.BetaMetadataParam{UserID: anthropic.String(req.UserRef)}
	}
	if len(req.Tools) > 0 {
		params.Tools = betaTools(req.Tools)
	}
	rounds := req.MaxToolRounds
	if rounds <= 0 {
		rounds = 4
	}
	res := &Result{}
	for round := 1; ; round++ {
		msg, err := a.client.Beta.Messages.New(ctx, params)
		if err != nil {
			return nil, classify(err)
		}
		res.Rounds, res.Model, res.StopReason = round, msg.Model, string(msg.StopReason)
		u := Usage{InputTokens: msg.Usage.InputTokens, OutputTokens: msg.Usage.OutputTokens, CacheReadTokens: msg.Usage.CacheReadInputTokens,
			CacheWriteTokens: msg.Usage.CacheCreationInputTokens}
		u.CostMicroUSD = EstimateCost(res.Model, u)
		res.Usage.InputTokens += u.InputTokens
		res.Usage.OutputTokens += u.OutputTokens
		res.Usage.CacheReadTokens += u.CacheReadTokens
		res.Usage.CacheWriteTokens += u.CacheWriteTokens
		res.Usage.CostMicroUSD += u.CostMicroUSD
		switch msg.StopReason {
		case anthropic.BetaStopReasonRefusal:
			res.Latency = time.Since(start)
			return res, ErrRefused
		case anthropic.BetaStopReasonMaxTokens, anthropic.BetaStopReasonModelContextWindowExceeded:
			res.Latency = time.Since(start)
			return res, ErrTruncated
		}
		var text strings.Builder
		var calls []ToolCall
		for _, block := range msg.Content {
			switch b := block.AsAny().(type) {
			case anthropic.BetaTextBlock:
				text.WriteString(b.Text)
			case anthropic.BetaToolUseBlock:
				calls = append(calls, ToolCall{ID: b.ID, Name: b.Name, Input: json.RawMessage(b.JSON.Input.Raw())})
			}
		}
		if msg.StopReason != anthropic.BetaStopReasonToolUse || len(calls) == 0 {
			res.Text, res.Latency = strings.TrimSpace(text.String()), time.Since(start)
			if req.Schema != nil && !json.Valid([]byte(res.Text)) {
				return res, ErrBadOutput
			}
			return res, nil
		}
		if exec == nil || round >= rounds {
			res.Latency = time.Since(start)
			return res, fmt.Errorf("%w: tool rounds exhausted", ErrBadOutput)
		}
		// Keep the assistant turn exactly as returned (thinking blocks
		// included), then answer every tool call in one user turn.
		params.Messages = append(params.Messages, msg.ToParam())
		results := make([]anthropic.BetaContentBlockParamUnion, 0, len(calls))
		for _, c := range calls {
			out, isErr := exec(ctx, c)
			res.Tools = append(res.Tools, ToolRecord{Name: c.Name, Input: c.Input, Output: out, IsError: isErr})
			results = append(results, anthropic.NewBetaToolResultBlock(c.ID, out, isErr))
		}
		params.Messages = append(params.Messages, anthropic.NewBetaUserMessage(results...))
	}
}

// classify maps SDK errors to provider errors without leaking details.
func classify(err error) error {
	var apierr *anthropic.Error
	if errors.As(err, &apierr) {
		switch {
		case apierr.StatusCode == 429:
			return fmt.Errorf("%w (status 429)", ErrRateLimited)
		case apierr.StatusCode >= 500 || apierr.StatusCode == 408:
			return fmt.Errorf("%w (status %d)", ErrUnavailable, apierr.StatusCode)
		case apierr.StatusCode == 401 || apierr.StatusCode == 403:
			return fmt.Errorf("%w (status %d: check the API key and model access)", ErrUnavailable, apierr.StatusCode)
		default:
			return fmt.Errorf("%w (status %d)", ErrRejected, apierr.StatusCode)
		}
	}
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
		return fmt.Errorf("%w: %w", ErrUnavailable, err)
	}
	var ne net.Error
	if errors.As(err, &ne) {
		return fmt.Errorf("%w: network error", ErrUnavailable)
	}
	return fmt.Errorf("%w: %w", ErrUnavailable, err)
}
