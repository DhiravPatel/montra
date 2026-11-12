import { hasErrorCode } from '@/shared/api/errors';
import { detailCount, detailParam, domainRuleCode } from '@/shared/finance/domainErrors';
import { formatWait } from '@/shared/i18n/formatWait';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/**
 * Support caps and refusals (docs/API.md "Search and support notes"):
 * 10 requests and 10 thread messages a day per account, 10 contact
 * messages a day per address. Each cap answers 429 RATE_LIMITED with a
 * Retry-After header and `details[0]` `{code: daily_cap, params: {limit,
 * window_hours, kind}}`.
 */
export interface SupportDailyCap {
  limit: number | null;
  /** `params.kind`: `support requests`, `support messages` or the contact form's. */
  kind: string | null;
  /** Seconds until the oldest counted message leaves the window, when known. */
  waitSeconds: number | null;
}

/** The daily cap behind a 429, or null for any other error (including short bursts). */
export function supportDailyCap(error: unknown): SupportDailyCap | null {
  if (!hasErrorCode(error, 'RATE_LIMITED')) return null;
  const detail = error.details.find((item) => item.code === 'daily_cap');
  if (!detail) return null;
  return {
    limit: detailCount(detail.params, 'limit'),
    kind: detailParam(detail.params, 'kind'),
    waitSeconds: error.retryAfterSeconds,
  };
}

const capKeys: Readonly<Record<string, MessageKey>> = {
  'support requests': 'support.cap.requests',
  'support messages': 'support.cap.messages',
};

/**
 * "You can send up to 10 requests a day. You can send more in 24 hours."
 * for a daily cap; null for any other error. `contact` words it for the
 * signed-out form, whose cap counts messages from one email address.
 */
export function dailyCapMessage(
  error: unknown,
  t: Translate,
  { contact = false }: { contact?: boolean } = {},
): string | null {
  const cap = supportDailyCap(error);
  if (!cap) return null;
  let reached: string;
  if (cap.limit === null) reached = t('support.cap.generic');
  else if (contact) reached = t('support.cap.contact', { count: cap.limit });
  else
    reached = t((cap.kind ? capKeys[cap.kind] : undefined) ?? 'support.cap.requests', {
      count: cap.limit,
    });
  const again =
    cap.waitSeconds === null
      ? t('support.cap.later')
      : t('support.cap.wait', { wait: formatWait(t, cap.waitSeconds) });
  return `${reached} ${again}`;
}

/** 422 `request_closed`: the request was closed, so its thread takes no new messages. */
export function isRequestClosed(error: unknown): boolean {
  return domainRuleCode(error)?.code === 'request_closed';
}

/** True when the API refused text because it looks like a card number, PIN, OTP or password. */
export function containsSecretRefusal(error: unknown): boolean {
  return (
    hasErrorCode(error, 'VALIDATION_ERROR') &&
    error.details.some((detail) => detail.code === 'contains_secret')
  );
}
