package httpx

import (
	"net/http"

	"github.com/danielgtaylor/huma/v2"
)

// DocumentConventions adds cross-cutting request and response headers to
// every operation in the generated contract, as reusable components
// referenced by each operation. Middleware enforces them; the contract
// documents them (spec §6).
func DocumentConventions(api huma.API) {
	oapi := api.OpenAPI()
	str := func(enum ...any) *huma.Schema { return &huma.Schema{Type: huma.TypeString, Enum: enum} }
	if oapi.Components.Parameters == nil {
		oapi.Components.Parameters = map[string]*huma.Param{}
	}
	if oapi.Components.Headers == nil {
		oapi.Components.Headers = map[string]*huma.Header{}
	}
	oapi.Components.Parameters["MontraClient"] = &huma.Param{Name: "X-Montra-Client", In: "header", Schema: str("web", "android", "ios"),
		Description: "Client kind. web uses HttpOnly cookies; android/ios receive tokens in the response body."}
	oapi.Components.Parameters["ClientVersion"] = &huma.Param{Name: "X-Client-Version", In: "header", Schema: str(),
		Description: "Client application version (diagnostics and compatibility)."}
	oapi.Components.Parameters["CSRFToken"] = &huma.Param{Name: "X-CSRF-Token", In: "header", Schema: str(),
		Description: "Required for cookie-authenticated (web) unsafe requests: `csrf_token` from the auth response or the `montra_csrf` cookie."}
	oapi.Components.Headers["RequestID"] = &huma.Header{Schema: str(), Description: "Correlation ID (also in meta.request_id / error.request_id)."}
	oapi.Components.Headers["RetryAfter"] = &huma.Header{Schema: &huma.Schema{Type: huma.TypeInteger}, Description: "Seconds to wait before retrying."}

	ref := func(kind, name string) string { return "#/components/" + kind + "/" + name }
	for _, item := range oapi.Paths {
		for method, op := range map[string]*huma.Operation{
			http.MethodGet: item.Get, http.MethodPost: item.Post, http.MethodPut: item.Put,
			http.MethodPatch: item.Patch, http.MethodDelete: item.Delete,
		} {
			if op == nil {
				continue
			}
			op.Parameters = append(op.Parameters, &huma.Param{Ref: ref("parameters", "MontraClient")},
				&huma.Param{Ref: ref("parameters", "ClientVersion")})
			if method != http.MethodGet && op.Metadata[MetaAuth] == "required" {
				op.Parameters = append(op.Parameters, &huma.Param{Ref: ref("parameters", "CSRFToken")})
			}
			for status, resp := range op.Responses {
				if resp == nil {
					continue
				}
				if resp.Headers == nil {
					resp.Headers = map[string]*huma.Param{}
				}
				resp.Headers["X-Request-ID"] = &huma.Param{Ref: ref("headers", "RequestID")}
				if status == "429" || status == "503" {
					resp.Headers["Retry-After"] = &huma.Param{Ref: ref("headers", "RetryAfter")}
				}
			}
		}
	}
}
