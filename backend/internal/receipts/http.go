package receipts

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// IDPath binds {id}.
type IDPath struct {
	ID uuid.UUID `path:"id"`
}

// lifecycleInput is a discard or restore request.
type lifecycleInput struct {
	IDPath
	Version int32 `query:"version" minimum:"0" doc:"Optional: the receipt's version; a stale version answers 409 VERSION_CONFLICT"`
}

func describe(op huma.Operation, description string) huma.Operation {
	op.Description = description
	return op
}

// Routes mounts receipt endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Receipts"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }
	one := func(ctx context.Context, r *ReceiptDTO, err error) (*httpx.Response[ReceiptDTO], error) {
		if err != nil {
			return nil, err
		}
		return httpx.OK(ctx, *r), nil
	}
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("receipts-create", http.MethodPost, "/receipts",
		"Add a receipt from uploaded pages (entered manually unless read_automatically is true)", tag),
		"Idempotent: a retry with the same Idempotency-Key and body returns the first receipt with Idempotent-Replayed: true. "+
			"409 CONFLICT codes: page_not_ready (file_id, status), file_in_use (file_id, receipt_id: a page of another receipt that is not discarded)."))),
		func(ctx context.Context, in *struct {
			httpx.IdemHeader
			Body ReceiptCreateInput
		}) (*httpx.ReplayOutput[ReceiptDTO], error) {
			r, replayed, err := s.Create(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *r, replayed), nil
		})
	httpx.Protected(api, describe(httpx.Op("receipts-list", http.MethodGet, "/receipts", "Receipt inbox, newest first", tag),
		"Pages with a cursor: pass meta.next_cursor as cursor while meta.has_more is true. The filters stay the same on every page."),
		func(ctx context.Context, in *struct {
			Status string `query:"status" enum:"uploaded,processing,needs_review,reviewed,matched,failed,discarded," doc:"Default (empty): every status except discarded"`
			Cursor string `query:"cursor" maxLength:"512" doc:"meta.next_cursor of the previous page"`
			Limit  int    `query:"limit" minimum:"1" maximum:"200" default:"200"`
		}) (*httpx.Response[[]ReceiptDTO], error) {
			l, next, err := s.List(ctx, in.Status, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Op("receipts-get", http.MethodGet, "/receipts/{id}", "Receipt with pages, values and extraction history", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[ReceiptDetail], error) {
			r, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Accepted(write(describe(httpx.Op("receipts-process", http.MethodPost, "/receipts/{id}/process",
		"Read the receipt automatically (creates a new extraction version)", tag),
		"Needs automatic reading to be configured (503 FEATURE_NOT_CONFIGURED) and, for AI reading, AI on with both AI consents (403 CONSENT_REQUIRED). "+
			"409 CONFLICT codes: receipt_linked, receipt_discarded, receipt_processing."))),
		func(ctx context.Context, in *IDPath) (*httpx.Response[ReceiptDTO], error) {
			r, err := s.Process(ctx, in.ID)
			return one(ctx, r, err)
		})
	httpx.Protected(api, write(describe(httpx.Op("receipts-review", http.MethodPatch, "/receipts/{id}/review",
		"Confirm or correct every value (stored as a reviewed version)", tag),
		"409 CONFLICT codes: receipt_linked, receipt_discarded, receipt_processing (VERSION_CONFLICT when version is stale).")),
		func(ctx context.Context, in *struct {
			IDPath
			Body ReceiptReviewInput
		}) (*httpx.Response[ReceiptDTO], error) {
			r, err := s.Review(ctx, in.ID, in.Body)
			return one(ctx, r, err)
		})
	httpx.Protected(api, httpx.Op("receipts-match-candidates", http.MethodGet, "/receipts/{id}/match-candidates",
		"Existing transactions that may be this purchase", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]ReceiptMatchCandidate], error) {
			l, err := s.MatchCandidates(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("receipts-match", http.MethodPost, "/receipts/{id}/match-transaction",
		"Link the receipt to an existing transaction", tag),
		"409 CONFLICT codes: receipt_linked (transaction_id), receipt_discarded, receipt_processing; "+
			"409 DUPLICATE with code transaction_has_receipt when the transaction already has another receipt.")),
		func(ctx context.Context, in *struct {
			IDPath
			Body ReceiptMatchInput
		}) (*httpx.Response[ReceiptDTO], error) {
			r, err := s.Match(ctx, in.ID, in.Body)
			return one(ctx, r, err)
		})
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("receipts-create-transaction", http.MethodPost, "/receipts/{id}/create-transaction",
		"Record the purchase from the reviewed values", tag),
		"409 CONFLICT codes: receipt_linked (transaction_id), receipt_discarded, receipt_processing; "+
			"422 receipt_not_reviewed or receipt_incomplete."))),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body ReceiptCreateTransactionInput
		}) (*httpx.ReplayOutput[ReceiptDTO], error) {
			r, replayed, err := s.CreateTransaction(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *r, replayed), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("receipts-unlink", http.MethodPost, "/receipts/{id}/unlink", "Unlink the transaction", tag),
		"Returns to reviewed (values reviewed) or needs_review. 409 CONFLICT code: receipt_not_linked.")),
		func(ctx context.Context, in *IDPath) (*httpx.Response[ReceiptDTO], error) {
			r, err := s.Unlink(ctx, in.ID)
			return one(ctx, r, err)
		})
	httpx.Protected(api, write(describe(httpx.Op("receipts-discard", http.MethodPost, "/receipts/{id}/discard",
		"Remove from the inbox (files are kept until deleted)", tag),
		"Unlinks a linked transaction; reading under way is dropped. Undo with POST /receipts/{id}/restore. "+
			"409 CONFLICT code: receipt_discarded (already discarded).")),
		func(ctx context.Context, in *lifecycleInput) (*httpx.Response[ReceiptDTO], error) {
			r, err := s.Discard(ctx, in.ID, in.Version)
			return one(ctx, r, err)
		})
	httpx.Protected(api, write(describe(httpx.Op("receipts-restore", http.MethodPost, "/receipts/{id}/restore",
		"Bring a discarded receipt back to the inbox", tag),
		"The receipt returns to reviewed when its current values are your reviewed version, otherwise to needs_review. "+
			"A transaction unlinked by the discard stays unlinked. 409 CONFLICT codes: receipt_not_discarded (status), "+
			"file_in_use (file_id, receipt_id: a page now belongs to another receipt).")),
		func(ctx context.Context, in *lifecycleInput) (*httpx.Response[ReceiptDTO], error) {
			r, err := s.Restore(ctx, in.ID, in.Version)
			return one(ctx, r, err)
		})
}
