// Package apperr defines Montra's closed set of API error codes and the error
// type used by services. Only the safe Code/Message/Details are ever sent to
// clients; the wrapped cause is logged server-side and never serialized
// (spec §6: never return SQL, stack traces, or secrets).
package apperr

import (
	"errors"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"time"
)

// Code is a stable, documented API error code.
type Code string

// Error codes. Keep in sync with docs/API.md.
const (
	CodeValidation          Code = "VALIDATION_ERROR"
	CodeBadRequest          Code = "BAD_REQUEST"
	CodeUnauthenticated     Code = "UNAUTHENTICATED"
	CodeMFARequired         Code = "MFA_REQUIRED"
	CodeMFACodeInvalid      Code = "MFA_CODE_INVALID"      // wrong code; the same attempt can be retried
	CodeMFAChallengeExpired Code = "MFA_CHALLENGE_EXPIRED" // attempt expired or used up; sign in again
	CodeReauthRequired      Code = "REAUTH_REQUIRED"
	CodeEmailNotVerified    Code = "EMAIL_NOT_VERIFIED"
	CodeForbidden           Code = "FORBIDDEN"
	CodeCSRF                Code = "CSRF_FAILED"
	CodeConsentRequired     Code = "CONSENT_REQUIRED"
	CodeNotFound            Code = "NOT_FOUND"
	CodeConflict            Code = "CONFLICT"
	CodeVersionConflict     Code = "VERSION_CONFLICT"
	CodeIdempotencyConflict Code = "IDEMPOTENCY_CONFLICT"
	CodeIdempotencyInFlight Code = "IDEMPOTENCY_IN_PROGRESS"
	CodeDuplicate           Code = "DUPLICATE"
	CodeDomainRule          Code = "DOMAIN_RULE_VIOLATION"
	CodeGone                Code = "GONE"
	CodePayloadTooLarge     Code = "PAYLOAD_TOO_LARGE"
	CodeUnsupportedMedia    Code = "UNSUPPORTED_MEDIA_TYPE"
	CodeRateLimited         Code = "RATE_LIMITED"
	CodeLoginThrottled      Code = "LOGIN_THROTTLED"
	CodeAccountLocked       Code = "ACCOUNT_LOCKED"
	CodeTimeout             Code = "TIMEOUT"
	CodeInternal            Code = "INTERNAL_ERROR"
	CodeUnavailable         Code = "SERVICE_UNAVAILABLE"
	CodeStorageUnavailable  Code = "STORAGE_UNAVAILABLE"
	CodeProviderUnavailable Code = "PROVIDER_UNAVAILABLE"
	CodeNotConfigured       Code = "FEATURE_NOT_CONFIGURED"
)

// AllCodes lists every code (used for the OpenAPI enum and docs).
var AllCodes = []Code{
	CodeValidation, CodeBadRequest, CodeUnauthenticated, CodeMFARequired,
	CodeReauthRequired, CodeEmailNotVerified, CodeForbidden, CodeCSRF,
	CodeConsentRequired, CodeNotFound, CodeConflict, CodeVersionConflict,
	CodeIdempotencyConflict, CodeIdempotencyInFlight, CodeDuplicate,
	CodeDomainRule, CodeGone, CodePayloadTooLarge, CodeUnsupportedMedia,
	CodeRateLimited, CodeLoginThrottled, CodeAccountLocked, CodeTimeout,
	CodeInternal, CodeUnavailable, CodeStorageUnavailable,
	CodeProviderUnavailable, CodeNotConfigured,
}

// Detail is a field- or item-level problem description.
type Detail struct {
	Field   string `json:"field,omitempty" doc:"Request location, e.g. body.amount"`
	Message string `json:"message" doc:"Human readable description"`
	Code    string `json:"code,omitempty" doc:"Machine readable detail code"`
	// Params carries the values a code refers to, so clients can show a
	// localized message (for example the remaining refundable amount).
	Params map[string]string `json:"params,omitempty" doc:"Values referenced by the code (amounts as decimal strings)"`
}

// Error is the service-layer error type.
type Error struct {
	Code    Code
	Status  int
	Message string
	Details []Detail
	// RetryAfter, when set, is sent as the Retry-After header.
	RetryAfter time.Duration
	cause      error
}

func (e *Error) Error() string {
	if e.cause != nil {
		return fmt.Sprintf("%s: %s: %v", e.Code, e.Message, e.cause)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// Unwrap exposes the internal cause for errors.Is/As and logging.
func (e *Error) Unwrap() error { return e.cause }

// WithCause attaches an internal cause (never sent to clients).
func (e *Error) WithCause(err error) *Error {
	cp := *e
	cp.cause = err
	return &cp
}

// WithRetryAfter returns a copy that tells clients when to retry.
func (e *Error) WithRetryAfter(d time.Duration) *Error {
	cp := *e
	cp.RetryAfter = d
	return &cp
}

// GetHeaders implements huma.HeadersError: Huma writes these headers on the
// error response.
func (e *Error) GetHeaders() http.Header {
	if e.RetryAfter <= 0 {
		return nil
	}
	return http.Header{"Retry-After": []string{strconv.Itoa(int(math.Ceil(e.RetryAfter.Seconds())))}}
}

// WithDetails returns a copy with details attached.
func (e *Error) WithDetails(d ...Detail) *Error {
	cp := *e
	cp.Details = append(append([]Detail{}, e.Details...), d...)
	return &cp
}

// New constructs an error.
func New(code Code, status int, msg string) *Error {
	return &Error{Code: code, Status: status, Message: msg}
}

// Validation reports invalid input.
func Validation(msg string, details ...Detail) *Error {
	if msg == "" {
		msg = "The request could not be processed."
	}
	return &Error{Code: CodeValidation, Status: http.StatusUnprocessableEntity, Message: msg, Details: details}
}

// FieldError is a convenience for a single invalid field.
func FieldError(field, msg string) *Error {
	return Validation("The request could not be processed.", Detail{Field: field, Message: msg})
}

// BadRequest reports a malformed request.
func BadRequest(msg string) *Error {
	return &Error{Code: CodeBadRequest, Status: http.StatusBadRequest, Message: msg}
}

// Unauthenticated reports a missing or invalid session.
func Unauthenticated() *Error {
	return &Error{Code: CodeUnauthenticated, Status: http.StatusUnauthorized, Message: "Authentication is required."}
}

// Forbidden reports an authorization failure. The message is deliberately
// generic.
func Forbidden() *Error {
	return &Error{Code: CodeForbidden, Status: http.StatusForbidden, Message: "You do not have permission to perform this action."}
}

// NotFound reports a missing resource. Callers must use NotFound (not
// Forbidden) when the resource belongs to someone else, to avoid confirming
// its existence.
func NotFound(resource string) *Error {
	if resource == "" {
		resource = "resource"
	}
	return &Error{Code: CodeNotFound, Status: http.StatusNotFound, Message: fmt.Sprintf("The %s was not found.", resource)}
}

// Conflict reports a state conflict.
func Conflict(msg string) *Error {
	return &Error{Code: CodeConflict, Status: http.StatusConflict, Message: msg}
}

// VersionConflict reports an optimistic concurrency failure.
func VersionConflict() *Error {
	return &Error{Code: CodeVersionConflict, Status: http.StatusConflict,
		Message: "This record was changed by another request. Reload and try again."}
}

// DomainRule reports a business-rule violation.
func DomainRule(msg string) *Error {
	return &Error{Code: CodeDomainRule, Status: http.StatusUnprocessableEntity, Message: msg}
}

// ConflictCode is a 409 conflict with a stable reason (details[0].code) and
// optional values, e.g. a name already in use or a record still in use.
func ConflictCode(reason, msg string, params map[string]string) *Error {
	return &Error{Code: CodeConflict, Status: http.StatusConflict, Message: msg, Details: []Detail{{Code: reason, Message: msg, Params: params}}}
}

// HasDetail reports whether err is an *Error whose first detail carries the
// given stable reason code.
func HasDetail(err error, reason string) bool {
	var e *Error
	return errors.As(err, &e) && len(e.Details) > 0 && e.Details[0].Code == reason
}

// Rule is a domain-rule violation with a stable reason (details[0].code)
// and optional values (details[0].params) for localized messages.
func Rule(reason, msg string, params map[string]string) *Error {
	return &Error{Code: CodeDomainRule, Status: http.StatusUnprocessableEntity, Message: msg,
		Details: []Detail{{Code: reason, Message: msg, Params: params}}}
}

// RateLimited reports throttling.
func RateLimited() *Error {
	return &Error{Code: CodeRateLimited, Status: http.StatusTooManyRequests, Message: "Too many requests. Please wait and try again."}
}

// Internal wraps an unexpected error. The cause is logged, never returned.
func Internal(err error) *Error {
	return &Error{Code: CodeInternal, Status: http.StatusInternalServerError,
		Message: "An unexpected error occurred.", cause: err}
}

// Unavailable reports a dependency outage.
func Unavailable(code Code, msg string) *Error {
	return &Error{Code: code, Status: http.StatusServiceUnavailable, Message: msg}
}

// From converts any error into an *Error, defaulting to Internal.
func From(err error) *Error {
	if err == nil {
		return nil
	}
	var e *Error
	if errors.As(err, &e) {
		return e
	}
	return Internal(err)
}

// CodeForStatus maps an HTTP status (from framework-level failures such as
// schema validation) to an error code.
func CodeForStatus(status int) Code {
	switch status {
	case http.StatusBadRequest, http.StatusUnprocessableEntity:
		return CodeValidation
	case http.StatusUnauthorized:
		return CodeUnauthenticated
	case http.StatusForbidden:
		return CodeForbidden
	case http.StatusNotFound:
		return CodeNotFound
	case http.StatusConflict:
		return CodeConflict
	case http.StatusRequestEntityTooLarge:
		return CodePayloadTooLarge
	case http.StatusUnsupportedMediaType:
		return CodeUnsupportedMedia
	case http.StatusTooManyRequests:
		return CodeRateLimited
	case http.StatusRequestTimeout, http.StatusGatewayTimeout:
		return CodeTimeout
	case http.StatusServiceUnavailable:
		return CodeUnavailable
	case http.StatusGone:
		return CodeGone
	default:
		if status >= 500 {
			return CodeInternal
		}
		return CodeBadRequest
	}
}

// Codes returns every error code (published as an enum in the contract).
func Codes() []Code {
	return []Code{
		CodeValidation,
		CodeBadRequest,
		CodeUnauthenticated,
		CodeMFARequired,
		CodeMFACodeInvalid,
		CodeMFAChallengeExpired,
		CodeReauthRequired,
		CodeEmailNotVerified,
		CodeForbidden,
		CodeCSRF,
		CodeConsentRequired,
		CodeNotFound,
		CodeConflict,
		CodeVersionConflict,
		CodeIdempotencyConflict,
		CodeIdempotencyInFlight,
		CodeDuplicate,
		CodeDomainRule,
		CodeGone,
		CodePayloadTooLarge,
		CodeUnsupportedMedia,
		CodeRateLimited,
		CodeLoginThrottled,
		CodeAccountLocked,
		CodeTimeout,
		CodeInternal,
		CodeUnavailable,
		CodeStorageUnavailable,
		CodeProviderUnavailable,
		CodeNotConfigured,
	}
}
