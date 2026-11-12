package imports

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

func describe(op huma.Operation, description string) huma.Operation {
	op.Description = description
	return op
}

// Routes mounts statement import endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Imports"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }
	ok := func(ctx context.Context, b *ImportBatchDTO, err error) (*httpx.Response[ImportBatchDTO], error) {
		if err != nil {
			return nil, err
		}
		return httpx.OK(ctx, *b), nil
	}

	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("imports-create", http.MethodPost, "/imports",
		"Start importing an uploaded statement (parsing runs in the background)", tag),
		"Idempotent: a retry with the same Idempotency-Key and body returns the batch created first (Idempotent-Replayed: true) "+
			"without creating or parsing another one."))),
		func(ctx context.Context, in *struct {
			httpx.IdemHeader
			Body ImportCreateInput
		}) (*httpx.ReplayOutput[ImportBatchDTO], error) {
			b, replayed, err := s.Create(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *b, replayed), nil
		})
	httpx.Protected(api, describe(httpx.Op("imports-list", http.MethodGet, "/imports", "List imports", tag),
		"Newest first, a page at a time (meta.next_cursor / has_more); without cursor and limit the first 100, as before."),
		func(ctx context.Context, in *struct {
			AccountID string `query:"account_id" format:"uuid"`
			Cursor    string `query:"cursor" maxLength:"512"`
			Limit     int    `query:"limit" minimum:"1" maximum:"200" default:"100"`
		}) (*httpx.Response[[]ImportBatchDTO], error) {
			var acct *uuid.UUID
			if in.AccountID != "" {
				id, err := uuid.Parse(in.AccountID)
				if err != nil {
					return nil, huma.Error422UnprocessableEntity("account_id must be a UUID")
				}
				acct = &id
			}
			l, next, err := s.List(ctx, acct, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Op("imports-get", http.MethodGet, "/imports/{id}", "Get an import with counts, mapping and totals", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[ImportBatchDTO], error) {
			b, err := s.Get(ctx, in.ID)
			return ok(ctx, b, err)
		})
	httpx.Protected(api, write(httpx.Op("imports-mapping", http.MethodPatch, "/imports/{id}/mapping",
		"Set the column mapping and formats (re-derives rows; decisions are reset)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body ImportMappingInput
		}) (*httpx.Response[ImportBatchDTO], error) {
			b, err := s.SetMapping(ctx, in.ID, in.Body)
			return ok(ctx, b, err)
		})
	httpx.Protected(api, httpx.Op("imports-rows", http.MethodGet, "/imports/{id}/rows", "Rows with normalized values, status and reasons", tag),
		func(ctx context.Context, in *struct {
			IDPath
			Status   string `query:"status" enum:"parsed,invalid,duplicate,ready,imported,skipped,failed,"`
			AfterRow int32  `query:"after_row" minimum:"0"`
			Limit    int    `query:"limit" minimum:"0" maximum:"500"`
		}) (*httpx.Response[ImportRowPage], error) {
			p, err := s.Rows(ctx, in.ID, in.Status, in.AfterRow, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, write(httpx.Op("imports-row-update", http.MethodPatch, "/imports/{id}/rows/{rowId}",
		"Decide (import/skip), categorize or correct a row", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			RowID uuid.UUID `path:"rowId"`
			Body  ImportRowUpdate
		}) (*httpx.Response[ImportRowDTO], error) {
			r, err := s.UpdateRow(ctx, in.ID, in.RowID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Accepted(write(httpx.Op("imports-confirm", http.MethodPost, "/imports/{id}/confirm",
		"Confirm and import the ready rows (runs in the background)", tag))),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body ImportConfirmInput
		}) (*httpx.ReplayOutput[ImportBatchDTO], error) {
			b, replayed, err := s.ConfirmIdempotent(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *b, replayed), nil
		})
	for path, fn := range map[string]func(context.Context, uuid.UUID) (*ImportBatchDTO, error){
		"cancel": s.Cancel, "retry-failed": s.RetryFailed, "rollback": s.Rollback,
	} {
		fn := fn
		summary := map[string]string{"cancel": "Cancel (processing stops between rows)", "retry-failed": "Retry failed rows",
			"rollback": "Void this import's transactions that were not edited since (runs in the background)"}[path]
		httpx.Protected(api, write(httpx.Op("imports-"+path, http.MethodPost, "/imports/{id}/"+path, summary, tag)),
			func(ctx context.Context, in *IDPath) (*httpx.Response[ImportBatchDTO], error) {
				b, err := fn(ctx, in.ID)
				return ok(ctx, b, err)
			})
	}
}
