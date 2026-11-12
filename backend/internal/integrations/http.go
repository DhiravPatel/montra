package integrations

import (
	"context"
	"net/http"
	"strings"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// Routes mounts integration endpoints. {ref} is a provider ID for connect
// and callback, and a connection ID elsewhere.
func (s *Service) Routes(api huma.API) {
	const tag = "Integrations"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }

	httpx.Protected(api, httpx.Op("integrations-list", http.MethodGet, "/integrations",
		"Providers (with honest availability) and your connections", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[Overview], error) {
			o, err := s.List(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *o), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("integrations-connect", http.MethodPost, "/integrations/{ref}/connect",
		"Start connecting a provider (consent required; you approve access at the provider)", tag))),
		func(ctx context.Context, in *struct {
			Ref  string `path:"ref" maxLength:"40" doc:"Provider ID"`
			Body ConnectInput
		}) (*httpx.Response[ConnectResult], error) {
			r, err := s.Connect(ctx, in.Ref, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Errs(write(httpx.Op("integrations-callback", http.MethodGet, "/integrations/{ref}/callback",
		"Finish connecting after the provider redirects back (the one-time state must match your request)", tag)), http.StatusGone),
		func(ctx context.Context, in *struct {
			Ref   string `path:"ref" maxLength:"40" doc:"Provider ID"`
			State string `query:"state" minLength:"16" maxLength:"128"`
			Code  string `query:"code" minLength:"1" maxLength:"2048"`
		}) (*httpx.Response[ConnectionDTO], error) {
			c, err := s.Callback(ctx, in.Ref, in.State, in.Code)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Accepted(write(httpx.Op("integrations-sync", http.MethodPost, "/integrations/{ref}/sync", "Sync a connection now", tag))),
		func(ctx context.Context, in *struct {
			Ref uuid.UUID `path:"ref" doc:"Connection ID"`
		}) (*httpx.Response[SyncRunDTO], error) {
			r, err := s.SyncNow(ctx, in.Ref)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("integrations-status", http.MethodGet, "/integrations/{ref}/status", "Connection status and recent syncs", tag),
		func(ctx context.Context, in *struct {
			Ref uuid.UUID `path:"ref" doc:"Connection ID"`
		}) (*httpx.Response[ConnectionStatus], error) {
			st, err := s.Status(ctx, in.Ref)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *st), nil
		})
	httpx.Protected(api, write(httpx.Op("integrations-disconnect", http.MethodDelete, "/integrations/{ref}",
		"Disconnect: revoke access, delete stored credentials, and optionally void imported transactions", tag)),
		func(ctx context.Context, in *struct {
			Ref        uuid.UUID `path:"ref" doc:"Connection ID"`
			DeleteData bool      `query:"delete_data" doc:"Also void the transactions this connection imported"`
			Confirm    bool      `query:"confirm" doc:"Must be true"`
		}) (*httpx.Response[DisconnectResult], error) {
			if !in.Confirm {
				return nil, apperr.FieldError("query.confirm", "Confirm that you want to disconnect.")
			}
			r, err := s.Disconnect(ctx, in.Ref, in.DeleteData)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	hook := httpx.MaxBody(httpx.Accepted(httpx.Rate(httpx.Op("webhooks-receive", http.MethodPost, "/webhooks/{provider}",
		"Provider webhook (signature, timestamp and replay checked; invalid signatures are quarantined and answered 401)", tag),
		ratelimit.Default.Name)), 256<<10)
	hook.SkipValidateBody = true // the adapter verifies the exact signed bytes
	httpx.Public(api, hook,
		func(ctx context.Context, in *webhookInput) (*httpx.Response[WebhookResult], error) {
			r, err := s.ReceiveWebhook(ctx, in.Provider, in.headers, in.RawBody)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}

// webhookInput hands the adapter the raw body and the request headers
// (providers sign with different header names). Cookies are dropped.
type webhookInput struct {
	Provider string `path:"provider" maxLength:"40"`
	RawBody  []byte `contentType:"application/json"`
	headers  http.Header
}

// Resolve captures the request headers.
func (w *webhookInput) Resolve(ctx huma.Context) []error {
	w.headers = http.Header{}
	ctx.EachHeader(func(name, value string) {
		if !strings.EqualFold(name, "Cookie") {
			w.headers.Add(name, value)
		}
	})
	return nil
}
