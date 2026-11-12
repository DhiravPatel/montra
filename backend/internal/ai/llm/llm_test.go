package llm

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// fakeAPI is a local stand-in for the Messages API (no network).
type fakeAPI struct {
	mu       sync.Mutex
	requests []map[string]any
	headers  []http.Header
	replies  []func(w http.ResponseWriter)
}

func (f *fakeAPI) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	body, _ := io.ReadAll(r.Body)
	var m map[string]any
	_ = json.Unmarshal(body, &m)
	f.requests = append(f.requests, m)
	f.headers = append(f.headers, r.Header.Clone())
	i := len(f.requests) - 1
	if i >= len(f.replies) {
		http.Error(w, `{"type":"error","error":{"type":"api_error","message":"unexpected"}}`, 500)
		return
	}
	f.replies[i](w)
}

func message(w http.ResponseWriter, stop string, content string) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = io.WriteString(w, `{"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5-5","stop_reason":"`+stop+`",
		"content":`+content+`,"usage":{"input_tokens":1000,"output_tokens":200,"cache_read_input_tokens":500,"cache_creation_input_tokens":0}}`)
}

func status(code int) func(w http.ResponseWriter) {
	return func(w http.ResponseWriter) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(code)
		_, _ = io.WriteString(w, `{"type":"error","error":{"type":"x","message":"nope"}}`)
	}
}

func provider(t *testing.T, f *fakeAPI) *Anthropic {
	t.Helper()
	srv := httptest.NewServer(f)
	t.Cleanup(srv.Close)
	return NewAnthropic(AnthropicConfig{APIKey: "test-key", BaseURL: srv.URL, Retries: 0})
}

var answerSchema = map[string]any{"type": "object", "additionalProperties": false, "required": []string{"answer"},
	"properties": map[string]any{"answer": map[string]any{"type": "string"}}}

func TestToolLoopRequestShapeAndUsage(t *testing.T) {
	f := &fakeAPI{replies: []func(http.ResponseWriter){
		func(w http.ResponseWriter) {
			message(w, "tool_use", `[{"type":"thinking","thinking":"","signature":"sig"},{"type":"tool_use","id":"tu_1","name":"cash_flow","input":{"range":"this_month"}}]`)
		},
		func(w http.ResponseWriter) {
			message(w, "end_turn", `[{"type":"text","text":"{\"answer\":\"You spent 1,200.00\"}"}]`)
		},
	}}
	p := provider(t, f)
	var ran []string
	res, err := p.Generate(context.Background(), Request{Feature: "ask", System: "Be accurate.", Blocks: []Block{{Text: "How much did I spend?"}},
		Tools:  []Tool{{Name: "cash_flow", Description: "Totals", Properties: map[string]any{"range": map[string]any{"type": "string"}}, Required: []string{"range"}}},
		Schema: answerSchema, MaxTokens: 2000, Effort: "low", UserRef: "u_abc"},
		func(_ context.Context, c ToolCall) (string, bool) {
			ran = append(ran, c.Name+string(c.Input))
			return `{"expense":"1200.00"}`, false
		})
	if err != nil {
		t.Fatal(err)
	}
	if res.Text != `{"answer":"You spent 1,200.00"}` || res.Rounds != 2 || len(res.Tools) != 1 || len(ran) != 1 || !strings.Contains(ran[0], "this_month") {
		t.Fatalf("result = %+v ran=%v", res, ran)
	}
	if res.Usage.InputTokens != 2000 || res.Usage.OutputTokens != 400 || res.Usage.CostMicroUSD != EstimateCost("claude-opus-5-5", res.Usage) || res.Usage.CostMicroUSD == 0 {
		t.Fatalf("usage = %+v", res.Usage)
	}
	first := f.requests[0]
	if first["model"] != "claude-opus-5-5" || first["fallbacks"] != "default" || first["thinking"] != nil {
		t.Fatalf("request = %v", first)
	}
	auth := f.headers[0].Get("X-Api-Key")
	if auth == "" {
		auth = strings.TrimPrefix(f.headers[0].Get("Authorization"), "Bearer ")
	}
	if !strings.Contains(f.headers[0].Get("Anthropic-Beta"), "server-side-fallback-2026-07-01") || auth != "test-key" {
		t.Fatalf("headers = %v", f.headers[0])
	}
	oc := first["output_config"].(map[string]any)
	if oc["effort"] != "low" || oc["format"].(map[string]any)["type"] != "json_schema" {
		t.Fatalf("output_config = %v", oc)
	}
	tool := first["tools"].([]any)[0].(map[string]any)
	if tool["strict"] != true || tool["input_schema"].(map[string]any)["additionalProperties"] != false {
		t.Fatalf("tool = %v", tool)
	}
	if first["metadata"].(map[string]any)["user_id"] != "u_abc" {
		t.Fatalf("metadata = %v", first["metadata"])
	}
	sys := first["system"].([]any)[0].(map[string]any)
	if sys["cache_control"] == nil {
		t.Fatalf("system prompt must be cached: %v", sys)
	}
	// Round 2 replays the assistant turn unchanged and answers the tool call.
	msgs := f.requests[1]["messages"].([]any)
	if len(msgs) != 3 {
		t.Fatalf("round 2 messages = %d", len(msgs))
	}
	asst := msgs[1].(map[string]any)["content"].([]any)
	if asst[0].(map[string]any)["type"] != "thinking" || asst[1].(map[string]any)["type"] != "tool_use" {
		t.Fatalf("assistant turn not replayed unchanged: %v", asst)
	}
	tr := msgs[2].(map[string]any)["content"].([]any)[0].(map[string]any)
	if tr["type"] != "tool_result" || tr["tool_use_id"] != "tu_1" {
		t.Fatalf("tool result = %v", tr)
	}
}

func TestImagesAndPDFsPrecedeText(t *testing.T) {
	f := &fakeAPI{replies: []func(http.ResponseWriter){func(w http.ResponseWriter) {
		message(w, "end_turn", `[{"type":"text","text":"{\"answer\":\"ok\"}"}]`)
	}}}
	p := provider(t, f)
	if _, err := p.Generate(context.Background(), Request{System: "x", Schema: answerSchema, Blocks: []Block{{Text: "Read this"},
		{MediaType: "image/png", Data: []byte{1, 2, 3}}, {MediaType: "application/pdf", Data: []byte("%PDF-1.7")}}}, nil); err != nil {
		t.Fatal(err)
	}
	content := f.requests[0]["messages"].([]any)[0].(map[string]any)["content"].([]any)
	if len(content) != 3 || content[0].(map[string]any)["type"] != "image" || content[1].(map[string]any)["type"] != "document" ||
		content[2].(map[string]any)["type"] != "text" {
		t.Fatalf("content order = %v", content)
	}
	if _, err := p.Generate(context.Background(), Request{System: "x", Blocks: []Block{{MediaType: "application/zip", Data: []byte{1}}}}, nil); !errors.Is(err, ErrRejected) {
		t.Fatalf("unsupported media: %v", err)
	}
}

func TestErrorClassification(t *testing.T) {
	cases := []struct {
		reply func(http.ResponseWriter)
		want  error
	}{
		{status(429), ErrRateLimited},
		{status(529), ErrUnavailable},
		{status(500), ErrUnavailable},
		{status(401), ErrUnavailable},
		{status(400), ErrRejected},
		{func(w http.ResponseWriter) { message(w, "refusal", `[]`) }, ErrRefused},
		{func(w http.ResponseWriter) { message(w, "max_tokens", `[{"type":"text","text":"{\"ans"}]`) }, ErrTruncated},
		{func(w http.ResponseWriter) { message(w, "end_turn", `[{"type":"text","text":"not json"}]`) }, ErrBadOutput},
		{func(w http.ResponseWriter) {
			message(w, "tool_use", `[{"type":"tool_use","id":"t","name":"x","input":{}}]`)
		}, ErrBadOutput},
	}
	for i, c := range cases {
		p := provider(t, &fakeAPI{replies: []func(http.ResponseWriter){c.reply}})
		_, err := p.Generate(context.Background(), Request{System: "x", Schema: answerSchema, Blocks: []Block{{Text: "q"}}}, nil)
		if !errors.Is(err, c.want) {
			t.Fatalf("case %d: got %v, want %v", i, err, c.want)
		}
	}
	if _, err := (Disabled{}).Generate(context.Background(), Request{}, nil); !errors.Is(err, ErrNotConfigured) {
		t.Fatal("disabled provider")
	}
}

func TestEstimateCost(t *testing.T) {
	u := Usage{InputTokens: 1_000_000, OutputTokens: 100_000, CacheReadTokens: 1_000_000, CacheWriteTokens: 100_000}
	// opus 5.5: 4.00 + 2.00 + 0.20 + 0.50 = 6.70 USD
	if c := EstimateCost("claude-opus-5-5", u); c != 6_700_000 {
		t.Fatalf("cost = %d", c)
	}
	if EstimateCost("unknown-model", u) != 0 {
		t.Fatal("unknown model priced")
	}
}
