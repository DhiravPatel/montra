package ai

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/ratelimit"
)

// DuplicateCheckInput names the transaction to check.
type DuplicateCheckInput struct {
	TransactionID uuid.UUID `json:"transaction_id"`
}

// DetectResult reports a subscription detection run.
type DetectResult struct {
	NewCandidates     int `json:"new_candidates"`
	PendingDetections int `json:"pending_detections" doc:"Review them in Subscriptions; nothing is added without your confirmation"`
}

// DeletedResult reports deleted conversations.
type DeletedResult struct {
	Deleted int64 `json:"deleted"`
}

// Routes mounts AI endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "AI"
	ai := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.AI.Name) }

	httpx.Protected(api, httpx.Op("ai-preferences-get", http.MethodGet, "/ai/preferences",
		"AI settings, consent state and the disclosure of what AI processing involves", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[AIPreferences], error) {
			p, err := s.Preferences(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, httpx.Errs(httpx.Op("ai-preferences-update", http.MethodPatch, "/ai/preferences",
		"Turn AI or AI history on or off (turning AI on needs the ai_processing consent)", tag), http.StatusForbidden),
		func(ctx context.Context, in *struct{ Body AIPreferencesPatch }) (*httpx.Response[AIPreferences], error) {
			p, err := s.UpdatePreferences(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, ai(httpx.Op("ai-ask", http.MethodPost, "/ai/ask",
		"Ask about your own finances; facts come from Montra's calculations (deterministic answers when AI is off)", tag)),
		func(ctx context.Context, in *struct{ Body AskInput }) (*httpx.Response[AskAnswer], error) {
			a, err := s.Ask(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
	httpx.Protected(api, httpx.Op("ai-conversations-list", http.MethodGet, "/ai/conversations", "Your saved AI conversations", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]ConversationDTO], error) {
			l, err := s.Conversations(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("ai-conversations-get", http.MethodGet, "/ai/conversations/{id}", "One saved conversation", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[ConversationDetail], error) {
			c, err := s.Conversation(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Op("ai-conversations-delete", http.MethodDelete, "/ai/conversations/{id}", "Delete a conversation", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[DeletedResult], error) {
			id := in.ID
			n, err := s.DeleteConversations(ctx, &id)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, DeletedResult{Deleted: n}), nil
		})
	httpx.Protected(api, httpx.Op("ai-conversations-delete-all", http.MethodDelete, "/ai/conversations", "Delete all of your AI conversation history", tag),
		func(ctx context.Context, in *struct {
			Confirm bool `query:"confirm" doc:"Must be true"`
		}) (*httpx.Response[DeletedResult], error) {
			if !in.Confirm {
				return nil, errConfirm
			}
			n, err := s.DeleteConversations(ctx, nil)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, DeletedResult{Deleted: n}), nil
		})
	httpx.Protected(api, ai(httpx.Op("ai-transactions-categorize", http.MethodPost, "/ai/transactions/categorize",
		"Suggest categories (your history first, AI for the rest when on); nothing is changed until you apply a suggestion", tag)),
		func(ctx context.Context, in *struct{ Body CategorizeInput }) (*httpx.Response[CategorizeResult], error) {
			r, err := s.Categorize(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, ai(httpx.Op("ai-transactions-duplicate-check", http.MethodPost, "/ai/transactions/duplicate-check",
		"Explain possible duplicates of a transaction (never merged automatically)", tag)),
		func(ctx context.Context, in *struct{ Body DuplicateCheckInput }) (*httpx.Response[DuplicateCheckResult], error) {
			r, err := s.DuplicateCheck(ctx, in.Body.TransactionID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, ai(httpx.Op("ai-subscriptions-detect", http.MethodPost, "/ai/subscriptions/detect",
		"Look for recurring charges that may be subscriptions (explainable rules; you confirm each)", tag)),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[DetectResult], error) {
			uid, err := identity.UserID(ctx)
			if err != nil {
				return nil, err
			}
			n, err := s.Subs.DetectForUser(ctx, uid)
			if err != nil {
				return nil, err
			}
			sum, err := s.Subs.Summary(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, DetectResult{NewCandidates: n, PendingDetections: sum.PendingDetections}), nil
		})
	httpx.Protected(api, ai(httpx.Op("ai-forecast", http.MethodPost, "/ai/forecast",
		"Project this month's spending with a range, from your own history and scheduled payments", tag)),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[ForecastDTO], error) {
			f, err := s.Forecast(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *f), nil
		})
	httpx.Protected(api, ai(httpx.Op("ai-report-summary", http.MethodPost, "/ai/report-summary",
		"Summarize a period in plain language from computed facts", tag)),
		func(ctx context.Context, in *struct{ Body SummaryInput }) (*httpx.Response[SummaryDTO], error) {
			r, err := s.ReportSummary(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}
