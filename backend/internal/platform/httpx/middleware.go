package httpx

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"runtime/debug"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/logging"
	"montra/backend/internal/platform/observability"
)

type ctxKey int

const (
	keyClientIP ctxKey = iota
	keyUserAgent
	keyClientKind
	keyClientVersion
)

// ClientInfo describes the calling client (never contains secrets).
type ClientInfo struct {
	IP      string
	UA      string
	Kind    string // web | android | ios | unknown
	Version string
}

// Client returns client information captured by the middleware.
func Client(ctx context.Context) ClientInfo {
	ci := ClientInfo{}
	ci.IP, _ = ctx.Value(keyClientIP).(string)
	ci.UA, _ = ctx.Value(keyUserAgent).(string)
	ci.Kind, _ = ctx.Value(keyClientKind).(string)
	ci.Version, _ = ctx.Value(keyClientVersion).(string)
	if ci.Kind == "" {
		ci.Kind = "unknown"
	}
	return ci
}

// HashIP returns a salted SHA-256 digest of an IP so security events can be
// correlated without storing raw addresses.
func HashIP(ip, salt string) string {
	if ip == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(salt + "|" + ip))
	return hex.EncodeToString(sum[:16])
}

// RequestID assigns or propagates a UUID request ID.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-ID")
		if _, err := uuid.Parse(id); err != nil {
			id = uuid.NewString()
		}
		w.Header().Set("X-Request-ID", id)
		next.ServeHTTP(w, r.WithContext(logging.WithRequestID(r.Context(), id)))
	})
}

// ClientContext records client IP, user agent and declared client kind.
func ClientContext(trustProxy bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := remoteIP(r, trustProxy)
			ctx := context.WithValue(r.Context(), keyClientIP, ip)
			ua := r.UserAgent()
			if len(ua) > 256 {
				ua = ua[:256]
			}
			ctx = context.WithValue(ctx, keyUserAgent, ua)
			kind := strings.ToLower(r.Header.Get("X-Montra-Client"))
			switch kind {
			case "web", "android", "ios":
			default:
				kind = "unknown"
			}
			ctx = context.WithValue(ctx, keyClientKind, kind)
			ver := r.Header.Get("X-Client-Version")
			if len(ver) > 32 {
				ver = ver[:32]
			}
			ctx = context.WithValue(ctx, keyClientVersion, ver)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func remoteIP(r *http.Request, trustProxy bool) string {
	if trustProxy {
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			first := strings.TrimSpace(strings.Split(xff, ",")[0])
			if ip := net.ParseIP(first); ip != nil {
				return ip.String()
			}
		}
		if xr := strings.TrimSpace(r.Header.Get("X-Real-IP")); xr != "" {
			if ip := net.ParseIP(xr); ip != nil {
				return ip.String()
			}
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// Recoverer converts panics into a 500 envelope and logs the stack.
func Recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				if e, ok := rec.(error); ok && errors.Is(e, http.ErrAbortHandler) {
					panic(rec)
				}
				slog.ErrorContext(r.Context(), "panic recovered",
					slog.Any("panic", rec), slog.String("stack", string(debug.Stack())))
				WriteError(w, r, apperr.Internal(nil))
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// SecurityHeaders sets conservative headers for API responses.
func SecurityHeaders(production bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := w.Header()
			h.Set("X-Content-Type-Options", "nosniff")
			h.Set("X-Frame-Options", "DENY")
			h.Set("Referrer-Policy", "no-referrer")
			h.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=()")
			h.Set("Cross-Origin-Resource-Policy", "same-site")
			if !strings.HasPrefix(r.URL.Path, "/api/v1/docs") {
				h.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
			}
			if production {
				h.Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
			}
			next.ServeHTTP(w, r)
		})
	}
}

// NoStore marks API responses as non-cacheable (financial data).
func NoStore(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}

// CORS implements a strict allow-list CORS policy with credentials.
func CORS(allowed []string) func(http.Handler) http.Handler {
	allow := map[string]bool{}
	wildcard := false
	for _, o := range allowed {
		if o == "*" {
			wildcard = true
		}
		allow[strings.TrimRight(o, "/")] = true
	}
	const allowHeaders = "Accept, Authorization, Content-Type, Idempotency-Key, If-Match, X-CSRF-Token, X-Request-ID, X-Montra-Client, X-Client-Version, X-Upload-Checksum"
	const exposeHeaders = "X-Request-ID, Retry-After, Idempotent-Replayed, ETag, Content-Disposition"
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin != "" && (allow[origin] || wildcard) {
				h := w.Header()
				h.Set("Access-Control-Allow-Origin", origin)
				h.Add("Vary", "Origin")
				h.Set("Access-Control-Allow-Credentials", "true")
				h.Set("Access-Control-Expose-Headers", exposeHeaders)
				if r.Method == http.MethodOptions && r.Header.Get("Access-Control-Request-Method") != "" {
					h.Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
					h.Set("Access-Control-Allow-Headers", allowHeaders)
					h.Set("Access-Control-Max-Age", "600")
					w.WriteHeader(http.StatusNoContent)
					return
				}
			} else if r.Method == http.MethodOptions && r.Header.Get("Access-Control-Request-Method") != "" {
				w.WriteHeader(http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// BodyLimit caps request bodies for all routes; individual operations may
// set lower limits.
func BodyLimit(max int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.ContentLength > max {
				WriteError(w, r, apperr.New(apperr.CodePayloadTooLarge, http.StatusRequestEntityTooLarge, "The request body is too large."))
				return
			}
			r.Body = http.MaxBytesReader(w, r.Body, max)
			next.ServeHTTP(w, r)
		})
	}
}

// Timeout bounds request processing via context cancellation. Routes under
// the given exempt prefixes (streaming transfers) are not bounded here.
func Timeout(d time.Duration, exemptPrefixes ...string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			for _, p := range exemptPrefixes {
				if strings.HasPrefix(r.URL.Path, p) {
					next.ServeHTTP(w, r)
					return
				}
			}
			ctx, cancel := context.WithTimeout(r.Context(), d)
			defer cancel()
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

type statusRecorder struct {
	http.ResponseWriter
	status int
	bytes  int
	// errBody keeps the start of an error response so the access log can
	// name its stable codes (never messages or values).
	errBody []byte
}

// maxErrBody bounds how much of an error body is kept for the access log
// (validation errors list at most a few dozen details, well under this).
const maxErrBody = 64 << 10

func (s *statusRecorder) WriteHeader(code int) {
	if s.status == 0 {
		s.status = code
	}
	s.ResponseWriter.WriteHeader(code)
}

func (s *statusRecorder) Write(b []byte) (int, error) {
	if s.status == 0 {
		s.status = http.StatusOK
	}
	n, err := s.ResponseWriter.Write(b)
	s.bytes += n
	if s.status >= 400 && len(s.errBody) < maxErrBody {
		s.errBody = append(s.errBody, b[:min(n, maxErrBody-len(s.errBody))]...)
	}
	return n, err
}

// errorCodes extracts the envelope's error code and the first detail's code
// and field (stable identifiers like VALIDATION_ERROR, too_long and
// body.amount). Messages, params and values are never read.
func errorCodes(body []byte) (code, detail, field string) {
	var env struct {
		Error struct {
			Code    string `json:"code"`
			Details []struct {
				Code  string `json:"code"`
				Field string `json:"field"`
			} `json:"details"`
		} `json:"error"`
	}
	if json.Unmarshal(body, &env) != nil {
		return "", "", ""
	}
	code = env.Error.Code
	if len(env.Error.Details) > 0 {
		detail, field = env.Error.Details[0].Code, env.Error.Details[0].Field
	}
	return code, detail, field
}

func (s *statusRecorder) Flush() {
	if f, ok := s.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// Unwrap supports http.ResponseController.
func (s *statusRecorder) Unwrap() http.ResponseWriter { return s.ResponseWriter }

// AccessLog logs one line per request using the route pattern (never the raw
// query string, which may carry signed tokens) and records metrics.
func AccessLog(metrics *observability.Metrics) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &statusRecorder{ResponseWriter: w}
			next.ServeHTTP(rec, r)
			if rec.status == 0 {
				rec.status = http.StatusOK
			}
			route := chi.RouteContext(r.Context())
			pattern := "unmatched"
			if route != nil {
				if p := route.RoutePattern(); p != "" {
					pattern = p
				}
			}
			dur := time.Since(start)
			if metrics != nil {
				metrics.ObserveHTTP(r.Method, pattern, rec.status, dur)
			}
			level := slog.LevelInfo
			if rec.status >= 500 {
				level = slog.LevelError
			} else if strings.HasPrefix(pattern, "/health") || pattern == "/metrics" {
				level = slog.LevelDebug
			}
			attrs := []any{
				slog.String("method", r.Method),
				slog.String("route", pattern),
				slog.Int("status", rec.status),
				slog.Int("bytes", rec.bytes),
				slog.Int64("duration_ms", dur.Milliseconds()),
				slog.String("client", Client(r.Context()).Kind),
			}
			if rec.status >= 400 {
				if code, detail, field := errorCodes(rec.errBody); code != "" {
					attrs = append(attrs, slog.String("error_code", code))
					if detail != "" {
						attrs = append(attrs, slog.String("detail_code", detail))
					}
					if field != "" {
						attrs = append(attrs, slog.String("detail_field", field))
					}
				}
			}
			slog.Log(r.Context(), level, "http request", attrs...)
		})
	}
}

// RetryAfter formats a Retry-After header value in seconds.
func RetryAfter(d time.Duration) string {
	s := int(d.Round(time.Second).Seconds())
	if s < 1 {
		s = 1
	}
	return strconv.Itoa(s)
}

// SingleQueryValues rejects repeated query parameters. List parameters are
// comma-separated (`type=expense,income`); silently keeping only the first
// of repeated keys would drop filters without telling the client.
func SingleQueryValues(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		for k, v := range r.URL.Query() {
			if len(v) > 1 {
				WriteError(w, r, apperr.Validation("Send each query parameter once; separate several values with commas.",
					apperr.Detail{Field: "query." + k, Message: "Repeated parameter: use one comma-separated value.", Code: "repeated_parameter"}))
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}
