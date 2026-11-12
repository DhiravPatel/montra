import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import type { Translate } from '@/shared/i18n/types';
import { detailCount, detailParam, errorDetail } from './domainErrors';

/**
 * A fair-use daily cap (429 RATE_LIMITED with details[0].code `daily_cap`):
 * challenge creation, community posts, comments and reports, support
 * requests and contact messages. The API also sends Retry-After; `retryAt`
 * is taken from `params.retry_at` first, then from that header.
 */
export interface DailyCap {
  /** What is capped (`resource` or `kind` as the API names it), if given. */
  resource: string | null;
  /** How many are allowed per window. */
  limit: number | null;
  /** When the next one is allowed (an instant), when known. */
  retryAt: Date | null;
  /** The window length in hours, when given instead of an instant. */
  windowHours: number | null;
}

export function dailyCap(error: unknown, now: number = Date.now()): DailyCap | null {
  if (!hasErrorCode(error, 'RATE_LIMITED')) return null;
  const detail = errorDetail(error, ['RATE_LIMITED']);
  if (detail?.code !== 'daily_cap') return null;
  const retryAt = parseTimestamp(detailParam(detail.params, 'retry_at') ?? undefined);
  return {
    resource: detailParam(detail.params, 'resource') ?? detailParam(detail.params, 'kind'),
    limit: detailCount(detail.params, 'limit'),
    retryAt:
      retryAt ?? (error.retryAfterSeconds ? new Date(now + error.retryAfterSeconds * 1000) : null),
    windowHours: detailCount(detail.params, 'window_hours'),
  };
}

/** The instant a rate-limited request can be tried again, from Retry-After or a daily cap. */
export function retryAt(error: unknown, now: number = Date.now()): Date | null {
  if (!hasErrorCode(error, 'RATE_LIMITED')) return null;
  const cap = dailyCap(error, now);
  if (cap?.retryAt) return cap.retryAt;
  return error.retryAfterSeconds ? new Date(now + error.retryAfterSeconds * 1000) : null;
}

/**
 * "You can try again at …" for a 429, worded from the daily cap when the
 * API sent one (limit per day, time of the next try); otherwise the generic
 * rate-limit sentence. Null for any other error.
 */
export function rateLimitMessage(
  error: unknown,
  t: Translate,
  locale: string,
  timeZone?: string,
  now: number = Date.now(),
): string | null {
  if (!isApiError(error) || error.code !== 'RATE_LIMITED') return null;
  const cap = dailyCap(error, now);
  const at = retryAt(error, now);
  const time = at ? formatDateTime(at, locale, timeZone) : null;
  if (cap?.limit !== null && cap?.limit !== undefined) {
    if (time) return t('finance.rateLimit.dailyCapAt', { count: cap.limit, time });
    if (cap.windowHours) {
      return t('finance.rateLimit.dailyCapWindow', { count: cap.limit, hours: cap.windowHours });
    }
    return t('finance.rateLimit.dailyCap', { count: cap.limit });
  }
  if (time) return t('finance.rateLimit.tryAgainAt', { time });
  return describeError(error, t);
}
