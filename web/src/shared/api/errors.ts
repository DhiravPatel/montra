/**
 * Client-side model of the API error envelope:
 * `{"error": {"code", "message", "details": [{field, message, code?, params?}], "request_id"}}`.
 */

import type { components } from './schema';

/** Error codes the API can return: the closed `ErrorObject.code` enum in the contract. */
export type ContractErrorCode = components['schemas']['ErrorObject']['code'];

/**
 * Runtime list of the contract codes. The type assertions below fail
 * compilation when the regenerated contract adds or removes a code, so this
 * list (and the message table in shared/i18n) cannot drift from it.
 */
export const CONTRACT_ERROR_CODES = [
  'VALIDATION_ERROR',
  'BAD_REQUEST',
  'UNAUTHENTICATED',
  'MFA_REQUIRED',
  'MFA_CODE_INVALID',
  'MFA_CHALLENGE_EXPIRED',
  'REAUTH_REQUIRED',
  'EMAIL_NOT_VERIFIED',
  'FORBIDDEN',
  'CSRF_FAILED',
  'CONSENT_REQUIRED',
  'NOT_FOUND',
  'CONFLICT',
  'VERSION_CONFLICT',
  'IDEMPOTENCY_CONFLICT',
  'IDEMPOTENCY_IN_PROGRESS',
  'DUPLICATE',
  'DOMAIN_RULE_VIOLATION',
  'GONE',
  'PAYLOAD_TOO_LARGE',
  'UNSUPPORTED_MEDIA_TYPE',
  'RATE_LIMITED',
  'LOGIN_THROTTLED',
  'ACCOUNT_LOCKED',
  'TIMEOUT',
  'INTERNAL_ERROR',
  'SERVICE_UNAVAILABLE',
  'STORAGE_UNAVAILABLE',
  'PROVIDER_UNAVAILABLE',
  'FEATURE_NOT_CONFIGURED',
] as const satisfies readonly ContractErrorCode[];

type MissingContractCodes = Exclude<ContractErrorCode, (typeof CONTRACT_ERROR_CODES)[number]>;
/** Compile-time check: fails if the contract has a code missing from the list above. */
export const contractCodesAreListed: [MissingContractCodes] extends [never]
  ? true
  : MissingContractCodes = true;

/** Codes produced by the client itself (no usable server answer). */
export const CLIENT_ERROR_CODES = ['NETWORK_ERROR', 'UNKNOWN_ERROR', 'COOKIES_BLOCKED'] as const;

export type ClientErrorCode = (typeof CLIENT_ERROR_CODES)[number];

/** Every code an ApiError can carry. */
export type ApiErrorCode = ContractErrorCode | ClientErrorCode;

const contractCodes: ReadonlySet<string> = new Set(CONTRACT_ERROR_CODES);

function isContractErrorCode(value: string): value is ContractErrorCode {
  return contractCodes.has(value);
}

export interface FieldIssue {
  /** Request location from the API, e.g. `body.password`. */
  field?: string;
  message: string;
  /** Machine-readable reason (e.g. `refund_exceeds_remaining`, `repeated_parameter`). */
  code?: string;
  /** Values for the reason (e.g. `{remaining, currency}`); untrusted data. */
  params?: Readonly<Record<string, unknown>>;
}

interface ApiErrorInit {
  status: number;
  code: ApiErrorCode;
  /** The code exactly as the server sent it (differs only for codes newer than this client). */
  rawCode?: string;
  message: string;
  details?: FieldIssue[];
  requestId?: string | null;
  retryAfterSeconds?: number | null;
  cause?: unknown;
}

export class ApiError extends Error {
  /** HTTP status; 0 when no response was received. */
  readonly status: number;
  readonly code: ApiErrorCode;
  /** Server code as received; equals `code` unless the API added a code this client does not know. */
  readonly rawCode: string;
  readonly details: readonly FieldIssue[];
  /** Correlation ID to quote to support. */
  readonly requestId: string | null;
  /** Seconds to wait before retrying (from Retry-After), if the API said so. */
  readonly retryAfterSeconds: number | null;

  constructor(init: ApiErrorInit) {
    super(init.message, init.cause === undefined ? undefined : { cause: init.cause });
    this.name = 'ApiError';
    this.status = init.status;
    this.code = init.code;
    this.rawCode = init.rawCode ?? init.code;
    this.details = init.details ?? [];
    this.requestId = init.requestId ?? null;
    this.retryAfterSeconds = init.retryAfterSeconds ?? null;
  }

  is(code: ApiErrorCode): boolean {
    return this.code === code;
  }
}

export function isApiError(value: unknown): value is ApiError {
  return value instanceof ApiError;
}

export function hasErrorCode(value: unknown, code: ApiErrorCode): value is ApiError {
  return isApiError(value) && value.code === code;
}

/** Mirrors the server's status → code mapping for bodies that are not an envelope (proxies, gateways). */
export function codeForStatus(status: number): ApiErrorCode {
  switch (status) {
    case 400:
    case 422:
      return 'VALIDATION_ERROR';
    case 401:
      return 'UNAUTHENTICATED';
    case 403:
      return 'FORBIDDEN';
    case 404:
      return 'NOT_FOUND';
    case 409:
      return 'CONFLICT';
    case 410:
      return 'GONE';
    case 413:
      return 'PAYLOAD_TOO_LARGE';
    case 415:
      return 'UNSUPPORTED_MEDIA_TYPE';
    case 429:
      return 'RATE_LIMITED';
    case 408:
    case 504:
      return 'TIMEOUT';
    case 502:
    case 503:
      return 'SERVICE_UNAVAILABLE';
    default:
      return status >= 500 ? 'INTERNAL_ERROR' : 'UNKNOWN_ERROR';
  }
}

/** Parses Retry-After (delta-seconds or HTTP-date) into whole seconds. */
export function parseRetryAfter(value: string | null, now: number = Date.now()): number | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (/^\d+$/.test(trimmed)) return Math.max(1, Number.parseInt(trimmed, 10));
  const date = Date.parse(trimmed);
  if (Number.isNaN(date)) return null;
  return Math.max(1, Math.ceil((date - now) / 1000));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function readDetails(value: unknown): FieldIssue[] {
  if (!Array.isArray(value)) return [];
  const issues: FieldIssue[] = [];
  for (const item of value) {
    if (!isRecord(item) || typeof item.message !== 'string') continue;
    issues.push({
      message: item.message,
      ...(typeof item.field === 'string' ? { field: item.field } : {}),
      ...(typeof item.code === 'string' ? { code: item.code } : {}),
      ...(isRecord(item.params) ? { params: item.params } : {}),
    });
  }
  return issues;
}

/** Builds an ApiError from an HTTP error response and its (possibly non-JSON) body. */
export function toApiError(response: Response, body: unknown): ApiError {
  const retryAfterSeconds = parseRetryAfter(response.headers.get('Retry-After'));
  const headerRequestId = response.headers.get('X-Request-ID');
  const envelope = isRecord(body) && isRecord(body.error) ? body.error : null;
  if (envelope && typeof envelope.code === 'string' && typeof envelope.message === 'string') {
    return new ApiError({
      status: response.status,
      // v1 evolves additively: a code newer than this client degrades to a generic error.
      code: isContractErrorCode(envelope.code) ? envelope.code : 'UNKNOWN_ERROR',
      rawCode: envelope.code,
      message: envelope.message,
      details: readDetails(envelope.details),
      requestId: typeof envelope.request_id === 'string' ? envelope.request_id : headerRequestId,
      retryAfterSeconds,
    });
  }
  const code = response.ok ? 'UNKNOWN_ERROR' : codeForStatus(response.status);
  return new ApiError({
    status: response.status,
    code,
    message: `Request failed with status ${response.status}`,
    requestId: headerRequestId,
    retryAfterSeconds,
  });
}

/** The request never produced a response (offline, DNS, CORS, aborted connection). */
export function networkError(cause: unknown): ApiError {
  return new ApiError({
    status: 0,
    code: 'NETWORK_ERROR',
    message: 'The Montra API could not be reached.',
    cause,
  });
}

/** Errors worth retrying automatically for idempotent reads. */
export function isTransientError(error: unknown): boolean {
  if (!isApiError(error)) return false;
  return (
    error.code === 'NETWORK_ERROR' ||
    error.code === 'SERVICE_UNAVAILABLE' ||
    error.code === 'TIMEOUT' ||
    error.status >= 500
  );
}
