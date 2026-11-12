package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	"montra/backend/internal/ai/llm"
	"montra/backend/internal/analytics"
)

// Ranges a tool may ask for (the analytics service resolves them in the
// user's time zone).
var ranges = []string{"this_month", "last_month", "this_week", "last_week", "last_7_days", "last_30_days", "last_90_days", "this_year", "last_year"}

var rangeProp = map[string]any{"type": "string", "enum": ranges, "description": "Reporting period in the user's time zone"}

// groundingTools are read-only and backed by deterministic services; they
// run as the caller, so row-level security limits them to the caller's data.
var groundingTools = []llm.Tool{
	{Name: "cash_flow", Description: "Income, net spending and net cash flow per currency for a period, with the previous period of the same length.",
		Properties: map[string]any{"range": rangeProp}, Required: []string{"range"}},
	{Name: "spending_by_category", Description: "Net spending by category for a period (largest first), with each category's share.",
		Properties: map[string]any{"range": rangeProp}, Required: []string{"range"}},
	{Name: "top_merchants", Description: "Net spending by merchant for a period (largest first).",
		Properties: map[string]any{"range": rangeProp}, Required: []string{"range"}},
	{Name: "accounts_overview", Description: "Current balances by account (names, types, balances; never account numbers).",
		Properties: map[string]any{}, Required: []string{}},
	{Name: "budgets_status", Description: "Each budget's limit, spent, remaining and pace for its current period.",
		Properties: map[string]any{}, Required: []string{}},
	{Name: "recurring_and_subscriptions", Description: "Recurring commitments normalized to a month, amounts due in the next 30 days, subscription totals and upcoming renewals.",
		Properties: map[string]any{}, Required: []string{}},
	{Name: "goals_progress", Description: "Goals with target, saved amount, progress and target dates.",
		Properties: map[string]any{}, Required: []string{}},
}

// executor runs grounding tools for one request.
type executor struct {
	s *Service
}

func (e executor) run(ctx context.Context, call llm.ToolCall) (string, bool) {
	var in struct {
		Range string `json:"range"`
	}
	if len(call.Input) > 0 {
		if err := json.Unmarshal(call.Input, &in); err != nil {
			return `{"error":"invalid input"}`, true
		}
	}
	valid := false
	for _, r := range ranges {
		valid = valid || r == in.Range
	}
	needsRange := call.Name == "cash_flow" || call.Name == "spending_by_category" || call.Name == "top_merchants"
	if needsRange && !valid {
		return `{"error":"unknown range"}`, true
	}
	var v any
	var err error
	switch call.Name {
	case "cash_flow":
		v, err = e.s.Analytics.CashFlow(ctx, analytics.Filter{Range: in.Range}, "month")
	case "spending_by_category":
		var r *analytics.CategoryReport
		if r, err = e.s.Analytics.Categories(ctx, analytics.Filter{Range: in.Range}, true); err == nil && len(r.Categories) > 15 {
			r.Categories = r.Categories[:15]
		}
		v = r
	case "top_merchants":
		v, err = e.s.Analytics.Merchants(ctx, analytics.Filter{Range: in.Range}, 10)
	case "accounts_overview":
		v, err = e.s.Analytics.Accounts(ctx, false)
	case "budgets_status":
		v, err = e.s.Analytics.Budgets(ctx, e.s.Planning)
	case "recurring_and_subscriptions":
		rec, rerr := e.s.Analytics.Recurring(ctx)
		if rerr != nil {
			return `{"error":"unavailable"}`, true
		}
		sum, serr := e.s.Subs.Summary(ctx)
		if serr != nil {
			return `{"error":"unavailable"}`, true
		}
		v = map[string]any{"recurring": rec, "subscriptions": sum}
	case "goals_progress":
		v, err = e.s.Analytics.GoalsSummary(ctx, e.s.Planning)
	default:
		return `{"error":"unknown tool"}`, true
	}
	if err != nil {
		return `{"error":"unavailable"}`, true
	}
	out, err := compactJSON(v)
	if err != nil {
		return `{"error":"unavailable"}`, true
	}
	return out, false
}

// dropKeys are identifiers and metadata the model never needs.
var dropKeys = map[string]bool{"id": true, "version": true, "created_at": true, "updated_at": true, "owned": true, "icon": true, "color": true,
	"members": true, "series": true, "coverage": true, "display_order": true, "access": true, "my_role": true, "notes": true}

// compactJSON turns a deterministic report into minimal model context:
// identifiers dropped, Money objects collapsed to "amount CUR", and free
// text (names, descriptions) redacted.
func compactJSON(v any) (string, error) {
	raw, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	var tree any
	if err := json.Unmarshal(raw, &tree); err != nil {
		return "", err
	}
	out, err := json.Marshal(compact(tree))
	return string(out), err
}

func compact(v any) any {
	switch x := v.(type) {
	case map[string]any:
		if amt, ok := x["amount"].(string); ok {
			if cur, ok := x["currency"].(string); ok && len(x) <= 3 {
				return amt + " " + cur
			}
		}
		m := map[string]any{}
		for k, val := range x {
			if dropKeys[k] || strings.HasSuffix(k, "_id") || strings.HasSuffix(k, "_ids") || strings.HasSuffix(k, "_file_id") {
				continue
			}
			if val == nil {
				continue
			}
			m[k] = compact(val)
		}
		return m
	case []any:
		out := make([]any, 0, len(x))
		for _, e := range x {
			out = append(out, compact(e))
		}
		return out
	case string:
		return redact(x)
	}
	return v
}

var (
	reEmail = regexp.MustCompile(`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`)
	reDigit = regexp.MustCompile(`\b\d[\d -]{7,}\d\b`) // long digit runs: card/account/phone numbers
	reUPI   = regexp.MustCompile(`\b[\w.-]{2,}@[a-z]{3,}\b`)
)

// redact masks identifiers in untrusted free text before it reaches the
// model: emails, UPI handles and long digit runs (keeps the last 4).
func redact(s string) string {
	if len(s) > 300 {
		s = s[:300]
	}
	s = reEmail.ReplaceAllString(s, "[email]")
	s = reUPI.ReplaceAllString(s, "[upi]")
	s = reDigit.ReplaceAllStringFunc(s, func(m string) string {
		d := strings.Map(func(r rune) rune {
			if r >= '0' && r <= '9' {
				return r
			}
			return -1
		}, m)
		if len(d) < 8 {
			return m
		}
		return "••••" + d[len(d)-4:]
	})
	return s
}

// todayLabel is the request date shown to the model (it has no clock).
func todayLabel(now time.Time, tz string) string {
	loc, err := time.LoadLocation(tz)
	if err != nil {
		loc = time.UTC
	}
	return fmt.Sprintf("%s (%s)", now.In(loc).Format("Monday 2 January 2006"), tz)
}
