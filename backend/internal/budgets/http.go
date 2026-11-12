package budgets

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// IDPath binds {id}.
type IDPath struct {
	ID uuid.UUID `path:"id"`
}

// VersionedIDPath binds {id} and an optional ?version= for state changes.
type VersionedIDPath struct {
	IDPath
	Version int32 `query:"version" minimum:"0" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

// Routes mounts budget endpoints.
func (s *Service) Routes(api huma.API, fin *finance.Service) {
	const tag = "Budgets"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }
	httpx.Protected(api, httpx.Op("budgets-list", http.MethodGet, "/budgets", "List budgets with current progress", tag),
		func(ctx context.Context, in *struct {
			IncludeArchived bool `query:"include_archived"`
		}) (*httpx.Response[[]BudgetDTO], error) {
			l, err := s.List(ctx, in.IncludeArchived)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("budgets-create", http.MethodPost, "/budgets", "Create a budget", tag))),
		func(ctx context.Context, in *struct{ Body BudgetInput }) (*httpx.Response[BudgetDTO], error) {
			b, err := s.Save(ctx, nil, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, httpx.Op("budgets-get", http.MethodGet, "/budgets/{id}", "Get a budget with progress and allocations", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[BudgetDTO], error) {
			b, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, write(httpx.Op("budgets-update", http.MethodPatch, "/budgets/{id}",
		"Update a budget: only the fields sent change (lists sent replace the list); applies from the current period onward", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body BudgetPatch
		}) (*httpx.Response[BudgetDTO], error) {
			b, err := s.Patch(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, write(httpx.Op("budgets-delete", http.MethodDelete, "/budgets/{id}", "Archive a budget (history kept)", tag)),
		func(ctx context.Context, in *VersionedIDPath) (*httpx.Response[BudgetDTO], error) {
			b, err := s.SetStatus(ctx, in.ID, "archive", in.Version)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	for _, action := range []string{"pause", "resume", "restore"} {
		httpx.Protected(api, write(httpx.Op("budgets-"+action, http.MethodPost, "/budgets/{id}/"+action, action+" a budget", tag)),
			func(ctx context.Context, in *VersionedIDPath) (*httpx.Response[BudgetDTO], error) {
				b, err := s.SetStatus(ctx, in.ID, action, in.Version)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *b), nil
			})
	}
	httpx.Protected(api, httpx.Op("budgets-progress", http.MethodGet, "/budgets/{id}/progress", "Progress for a period and the previous period", tag),
		func(ctx context.Context, in *struct {
			IDPath
			Date string `query:"date" doc:"Any date inside the period (YYYY-MM-DD); default today"`
		}) (*httpx.Response[[]ProgressDTO], error) {
			p, err := s.ProgressHistory(ctx, in.ID, in.Date)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, p), nil
		})
	httpx.Protected(api, httpx.Op("budgets-transactions", http.MethodGet, "/budgets/{id}/transactions",
		"Exactly the transactions counted in a period, newest first (owner only: collaborators get 403 and see totals; "+
			"group budgets answer group_budget)", tag),
		func(ctx context.Context, in *struct {
			IDPath
			Date   string `query:"date" doc:"YYYY-MM-DD in the period to list (default: the current period)"`
			Cursor string `query:"cursor" maxLength:"512"`
			Limit  int    `query:"limit" minimum:"1" maximum:"200" default:"50"`
		}) (*httpx.Response[[]finance.TransactionDTO], error) {
			l, next, err := s.Transactions(ctx, fin, in.ID, in.Date, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, write(httpx.Op("budgets-members-add", http.MethodPost, "/budgets/{id}/members", "Share with a friend or group member", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body MemberInput
		}) (*httpx.Response[BudgetDTO], error) {
			b, err := s.SetMember(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, write(httpx.Op("budgets-members-update", http.MethodPatch, "/budgets/{id}/members/{userId}", "Change a member's role/allocation", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			UserID uuid.UUID `path:"userId"`
			Body   struct {
				Role       string `json:"role" enum:"editor,viewer"`
				Allocation string `json:"allocation,omitempty"`
			}
		}) (*httpx.Response[BudgetDTO], error) {
			b, err := s.SetMember(ctx, in.ID, MemberInput{UserID: in.UserID, Role: in.Body.Role, Allocation: in.Body.Allocation})
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, write(httpx.Op("budgets-members-remove", http.MethodDelete, "/budgets/{id}/members/{userId}", "Remove a member (or leave)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			UserID uuid.UUID `path:"userId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.RemoveMember(ctx, in.ID, in.UserID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Op("budget-alerts-list", http.MethodGet, "/budget-alerts", "Budget alerts", tag),
		func(ctx context.Context, in *struct {
			Status   string `query:"status" enum:"active,dismissed,snoozed," doc:"Default: all statuses"`
			BudgetID string `query:"budget_id" format:"uuid" doc:"Only this budget's alerts"`
			Cursor   string `query:"cursor" maxLength:"512"`
			Limit    int    `query:"limit" minimum:"1" maximum:"200" default:"50"`
		}) (*httpx.Response[[]AlertDTO], error) {
			var budgetID *uuid.UUID
			if in.BudgetID != "" {
				id, err := uuid.Parse(in.BudgetID)
				if err != nil {
					return nil, apperr.FieldError("query.budget_id", "Invalid budget.")
				}
				budgetID = &id
			}
			l, next, err := s.ListAlerts(ctx, in.Status, budgetID, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Op("budget-alerts-update", http.MethodPatch, "/budget-alerts/{id}", "Dismiss, snooze or reactivate an alert", tag),
		func(ctx context.Context, in *struct {
			IDPath
			Body struct {
				Status       string     `json:"status" enum:"active,dismissed,snoozed"`
				SnoozedUntil *time.Time `json:"snoozed_until,omitempty"`
			}
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.UpdateAlert(ctx, in.ID, in.Body.Status, in.Body.SnoozedUntil); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
}
