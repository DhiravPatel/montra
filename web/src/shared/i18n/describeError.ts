import { type ApiErrorCode, isApiError } from '@/shared/api/errors';
import { formatWait } from './formatWait';
import type { MessageKey, Translate } from './types';

/**
 * One localized sentence per error code. Typed against the contract's enum,
 * so a code added to the API without a message fails compilation.
 */
const errorMessages: Readonly<Record<ApiErrorCode, MessageKey>> = {
  VALIDATION_ERROR: 'errors.VALIDATION_ERROR',
  BAD_REQUEST: 'errors.BAD_REQUEST',
  UNAUTHENTICATED: 'errors.UNAUTHENTICATED',
  MFA_REQUIRED: 'errors.MFA_REQUIRED',
  MFA_CODE_INVALID: 'errors.MFA_CODE_INVALID',
  MFA_CHALLENGE_EXPIRED: 'errors.MFA_CHALLENGE_EXPIRED',
  REAUTH_REQUIRED: 'errors.REAUTH_REQUIRED',
  EMAIL_NOT_VERIFIED: 'errors.EMAIL_NOT_VERIFIED',
  FORBIDDEN: 'errors.FORBIDDEN',
  CSRF_FAILED: 'errors.CSRF_FAILED',
  CONSENT_REQUIRED: 'errors.CONSENT_REQUIRED',
  NOT_FOUND: 'errors.NOT_FOUND',
  CONFLICT: 'errors.CONFLICT',
  VERSION_CONFLICT: 'errors.VERSION_CONFLICT',
  IDEMPOTENCY_CONFLICT: 'errors.IDEMPOTENCY_CONFLICT',
  IDEMPOTENCY_IN_PROGRESS: 'errors.IDEMPOTENCY_IN_PROGRESS',
  DUPLICATE: 'errors.DUPLICATE',
  DOMAIN_RULE_VIOLATION: 'errors.DOMAIN_RULE_VIOLATION',
  GONE: 'errors.GONE',
  PAYLOAD_TOO_LARGE: 'errors.PAYLOAD_TOO_LARGE',
  UNSUPPORTED_MEDIA_TYPE: 'errors.UNSUPPORTED_MEDIA_TYPE',
  RATE_LIMITED: 'errors.RATE_LIMITED',
  LOGIN_THROTTLED: 'errors.LOGIN_THROTTLED',
  ACCOUNT_LOCKED: 'errors.ACCOUNT_LOCKED',
  TIMEOUT: 'errors.TIMEOUT',
  INTERNAL_ERROR: 'errors.INTERNAL_ERROR',
  SERVICE_UNAVAILABLE: 'errors.SERVICE_UNAVAILABLE',
  STORAGE_UNAVAILABLE: 'errors.STORAGE_UNAVAILABLE',
  PROVIDER_UNAVAILABLE: 'errors.PROVIDER_UNAVAILABLE',
  FEATURE_NOT_CONFIGURED: 'errors.FEATURE_NOT_CONFIGURED',
  NETWORK_ERROR: 'errors.NETWORK_ERROR',
  UNKNOWN_ERROR: 'errors.UNKNOWN_ERROR',
  COOKIES_BLOCKED: 'errors.COOKIES_BLOCKED',
};

/**
 * A safe, localized, user-facing sentence for any failure. Server messages
 * are English-only and are not shown here; field-level details are handled
 * by the form helpers.
 */
export function describeError(error: unknown, t: Translate): string {
  if (!isApiError(error)) return t('errors.UNKNOWN_ERROR');
  if (error.code === 'RATE_LIMITED' && error.retryAfterSeconds) {
    return t('errors.RATE_LIMITED_retry', { wait: formatWait(t, error.retryAfterSeconds) });
  }
  if (error.code === 'LOGIN_THROTTLED' && error.retryAfterSeconds) {
    return t('errors.LOGIN_THROTTLED_retry', { wait: formatWait(t, error.retryAfterSeconds) });
  }
  return t(errorMessages[error.code]);
}
