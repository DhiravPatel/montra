package httpx

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humachi"
	"github.com/go-chi/chi/v5"
)

// APIVersion is the contract version published in OpenAPI.
const APIVersion = "1.0.0"

// NewAPI creates the Huma API mounted on r (expected to be the /api/v1
// sub-router). Docs/OpenAPI endpoints are exposed only when enableDocs.
func NewAPI(r chi.Router, enableDocs bool) huma.API {
	InstallHumaErrorModel()
	cfg := huma.DefaultConfig("Montra API", APIVersion)
	cfg.CreateHooks = nil // no $schema link injection: bodies stay in the documented envelope
	// Lists are never null: the schema says so and the encoder makes it true.
	huma.DefaultArrayNullable = false
	cfg.Formats = map[string]huma.Format{
		"application/json": jsonFormat,
		"json":             jsonFormat,
	}
	cfg.Info.Description = "Montra personal and social finance API. All amounts are integer minor units " +
		"(`amount_minor`) with an ISO 4217 `currency`; requests send exact decimal strings (`amount`). " +
		"Successful responses use `{data, meta}`; errors use `{error: {code, message, details, request_id}}`."
	cfg.Servers = []*huma.Server{{URL: "/api/v1", Description: "Version 1"}}
	cfg.Components.SecuritySchemes = map[string]*huma.SecurityScheme{
		"bearerAuth": {Type: "http", Scheme: "bearer", Description: "Opaque access token (mobile clients)."},
		"cookieAuth": {Type: "apiKey", In: "cookie", Name: CookieAccess,
			Description: "HttpOnly session cookie (web). Unsafe methods also require the X-CSRF-Token header."},
	}
	if !enableDocs {
		cfg.DocsPath = ""
		cfg.OpenAPIPath = ""
		cfg.SchemasPath = ""
	}
	return humachi.New(r, cfg)
}

// Cookie names (web sessions).
const (
	CookieAccess  = "montra_at"
	CookieRefresh = "montra_rt"
	CookieCSRF    = "montra_csrf"
)

// Metadata keys understood by middleware.
const (
	MetaAuth       = "auth"        // "public" | "required"
	MetaReauth     = "reauth"      // true → recent re-authentication required
	MetaRole       = "role"        // "admin" | "support" → platform staff only
	MetaRatePolicy = "rate_policy" // ratelimit policy name
)

var commonErrors = []int{http.StatusBadRequest, http.StatusUnprocessableEntity, http.StatusTooManyRequests, http.StatusInternalServerError,
	http.StatusServiceUnavailable}

// Op builds an operation definition.
func Op(id, method, path, summary string, tags ...string) huma.Operation {
	return huma.Operation{OperationID: id, Method: method, Path: path, Summary: summary, Tags: tags, Metadata: map[string]any{}}
}

// Created marks an operation as returning 201.
func Created(op huma.Operation) huma.Operation { op.DefaultStatus = http.StatusCreated; return op }

// Accepted marks an operation as returning 202.
func Accepted(op huma.Operation) huma.Operation { op.DefaultStatus = http.StatusAccepted; return op }

// Rate sets the rate-limit policy.
func Rate(op huma.Operation, policy string) huma.Operation {
	op.Metadata[MetaRatePolicy] = policy
	return op
}

// Reauth requires recent re-authentication (password/MFA within window).
func Reauth(op huma.Operation) huma.Operation { op.Metadata[MetaReauth] = true; return op }

// Staff restricts an operation to platform staff roles.
func Staff(op huma.Operation, role string) huma.Operation { op.Metadata[MetaRole] = role; return op }

// MaxBody sets the maximum request body size.
func MaxBody(op huma.Operation, n int64) huma.Operation { op.MaxBodyBytes = n; return op }

// Errs declares additional error statuses an operation can return (for
// example 401 on sign-in or 410 for expired links).
func Errs(op huma.Operation, statuses ...int) huma.Operation {
	op.Errors = append(op.Errors, statuses...)
	return op
}

// Public registers an unauthenticated operation.
func Public[I, O any](api huma.API, op huma.Operation, h func(context.Context, *I) (*O, error)) {
	if op.Metadata == nil {
		op.Metadata = map[string]any{}
	}
	op.Metadata[MetaAuth] = "public"
	op.Errors = append(op.Errors, commonErrors...)
	huma.Register(api, op, h)
}

// Protected registers an operation that requires an authenticated session.
func Protected[I, O any](api huma.API, op huma.Operation, h func(context.Context, *I) (*O, error)) {
	if op.Metadata == nil {
		op.Metadata = map[string]any{}
	}
	op.Metadata[MetaAuth] = "required"
	op.Security = []map[string][]string{{"bearerAuth": {}}, {"cookieAuth": {}}}
	op.Errors = append(op.Errors, append([]int{http.StatusUnauthorized, http.StatusForbidden, http.StatusNotFound}, commonErrors...)...)
	if op.Method != http.MethodGet {
		op.Errors = append(op.Errors, http.StatusConflict) // version, idempotency, duplicate and state conflicts
	}
	huma.Register(api, op, h)
}
