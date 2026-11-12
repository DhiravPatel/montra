package support

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// Routes mounts support endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Support"
	httpx.Protected(api, httpx.Created(httpx.Rate(httpx.Op("support-requests-create", http.MethodPost, "/support/requests",
		"Contact support, report a bug, a security or privacy issue, or send feedback", tag), ratelimit.Write.Name)),
		func(ctx context.Context, in *struct{ Body RequestInput }) (*httpx.Response[RequestDTO], error) {
			r, err := s.Create(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("support-requests-list", http.MethodGet, "/support/requests", "Your support requests", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]RequestDTO], error) {
			l, err := s.Mine(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("support-requests-get", http.MethodGet, "/support/requests/{id}", "One of your support requests", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[RequestDTO], error) {
			r, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("support-requests-messages", http.MethodGet, "/support/requests/{id}/messages",
		"The message thread of a request (requester and staff)", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[[]MessageDTO], error) {
			l, err := s.Messages(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(httpx.Rate(httpx.Op("support-requests-messages-create", http.MethodPost, "/support/requests/{id}/messages",
		"Reply on a request (requester and staff; staff replies notify the requester; audited)", tag), ratelimit.Write.Name)),
		func(ctx context.Context, in *struct {
			ID   uuid.UUID `path:"id"`
			Body MessageInput
		}) (*httpx.Response[MessageDTO], error) {
			m, err := s.PostMessage(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *m), nil
		})
	httpx.Public(api, httpx.Accepted(httpx.Rate(httpx.Op("support-contact", http.MethodPost, "/support/contact",
		"Contact support without signing in (for example when you cannot sign in)", tag), ratelimit.Auth.Name)),
		func(ctx context.Context, in *struct{ Body ContactInput }) (*httpx.Response[ContactResult], error) {
			r, err := s.Contact(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Staff(httpx.Op("support-queue", http.MethodGet, "/support/queue", "Support queue, security and privacy first (staff)", tag), "support"),
		func(ctx context.Context, in *struct {
			Status string `query:"status" enum:"open,in_progress,resolved,closed,"`
			Kind   string `query:"kind" enum:"support,bug,security,privacy,feedback,"`
		}) (*httpx.Response[[]StaffRequestDTO], error) {
			l, err := s.Queue(ctx, in.Status, in.Kind)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Staff(httpx.Op("support-queue-update", http.MethodPatch, "/support/queue/{id}", "Change a request's status (staff; audited)", tag), "support"),
		func(ctx context.Context, in *struct {
			ID   uuid.UUID `path:"id"`
			Body StatusInput
		}) (*httpx.Response[StaffRequestDTO], error) {
			r, err := s.SetStatus(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}
