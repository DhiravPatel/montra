package reconciliation

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

func describe(op huma.Operation, description string) huma.Operation {
	op.Description = description
	return op
}

// Routes mounts reconciliation endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Reconciliation"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }
	httpx.Protected(api, httpx.Op("reconciliation-candidates", http.MethodGet, "/reconciliation/candidates",
		"Suggested matches with confidence and reasons (confirm each)", tag),
		func(ctx context.Context, in *struct {
			AccountID uuid.UUID `query:"account_id" required:"true"`
			Kind      string    `query:"kind" enum:"statement_to_ledger,pending_to_posted,manual_to_imported,"`
			BatchID   string    `query:"batch_id" format:"uuid"`
		}) (*httpx.Response[[]ReconCandidate], error) {
			var batch *uuid.UUID
			if in.BatchID != "" {
				id, err := uuid.Parse(in.BatchID)
				if err != nil {
					return nil, huma.Error422UnprocessableEntity("batch_id must be a UUID")
				}
				batch = &id
			}
			l, err := s.Candidates(ctx, in.AccountID, in.Kind, batch)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("reconciliation-match-create", http.MethodPost, "/reconciliation/matches",
		"Confirm a match (pending and manual duplicates are voided; undo restores them)", tag),
		"Matches a suggestion or records chosen by hand: any unmatched statement line of the account (GET /accounts/{id}/statement-lines) "+
			"with transactions of the account whose amounts add up. Owner only; audited."))),
		func(ctx context.Context, in *struct{ Body ReconMatchInput }) (*httpx.Response[ReconMatchDTO], error) {
			m, err := s.Confirm(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *m), nil
		})
	httpx.Protected(api, describe(httpx.Op("reconciliation-matches", http.MethodGet, "/reconciliation/matches", "Matches for an account", tag),
		"Newest first, a page at a time (meta.next_cursor / has_more); without cursor and limit the first 200, as before."),
		func(ctx context.Context, in *struct {
			AccountID uuid.UUID `query:"account_id" required:"true"`
			Cursor    string    `query:"cursor" maxLength:"512"`
			Limit     int       `query:"limit" minimum:"1" maximum:"200" default:"200"`
		}) (*httpx.Response[[]ReconMatchDTO], error) {
			l, next, err := s.ListMatches(ctx, in.AccountID, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, write(httpx.Op("reconciliation-match-delete", http.MethodDelete, "/reconciliation/matches/{id}",
		"Unmatch (restores voided records and row states)", tag)),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[ReconMatchDTO], error) {
			m, err := s.Unmatch(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *m), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("accounts-reconcile", http.MethodPost, "/accounts/{id}/reconciliations",
		"Reconcile the account against a statement balance", tag))),
		func(ctx context.Context, in *struct {
			ID   uuid.UUID `path:"id"`
			Body ReconBalanceInput
		}) (*httpx.Response[ReconBalanceDTO], error) {
			b, err := s.Reconcile(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, describe(httpx.Op("accounts-reconciliations", http.MethodGet, "/accounts/{id}/reconciliations", "Reconciliation history", tag),
		"Latest statement date first, a page at a time (meta.next_cursor / has_more); without cursor and limit the first 100, as before."),
		func(ctx context.Context, in *struct {
			ID     uuid.UUID `path:"id"`
			Cursor string    `query:"cursor" maxLength:"512"`
			Limit  int       `query:"limit" minimum:"1" maximum:"200" default:"100"`
		}) (*httpx.Response[[]ReconBalanceDTO], error) {
			l, next, err := s.ListBalances(ctx, in.ID, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, describe(httpx.Op("accounts-statement-lines", http.MethodGet, "/accounts/{id}/statement-lines",
		"Statement lines of the account's imports to match by hand", tag),
		"status=unmatched (default): lines neither imported nor matched, including those with no suggestion; match one with "+
			"POST /reconciliation/matches. status=matched: lines in a confirmed match (match_id). Oldest first, a page at a time "+
			"(meta.next_cursor / has_more). Owner only."),
		func(ctx context.Context, in *struct {
			ID      uuid.UUID `path:"id"`
			Status  string    `query:"status" enum:"unmatched,matched" default:"unmatched"`
			BatchID string    `query:"batch_id" format:"uuid" doc:"Only this import's lines"`
			Cursor  string    `query:"cursor" maxLength:"512"`
			Limit   int       `query:"limit" minimum:"1" maximum:"200" default:"100"`
		}) (*httpx.Response[[]StatementLineDTO], error) {
			var batch *uuid.UUID
			if in.BatchID != "" {
				id, err := uuid.Parse(in.BatchID)
				if err != nil {
					return nil, apperr.FieldError("query.batch_id", "Invalid import.")
				}
				batch = &id
			}
			l, next, err := s.StatementLines(ctx, in.ID, in.Status, batch, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
}
