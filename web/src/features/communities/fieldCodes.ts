import type { FieldValues, Path, UseFormSetError } from 'react-hook-form';
import { type ApiError, type FieldIssue, hasErrorCode } from '@/shared/api/errors';
import { detailCount, detailParam } from '@/shared/finance/domainErrors';
import { formatWait } from '@/shared/i18n/formatWait';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/*
 * Coded field problems and daily caps, as the community, challenge and
 * moderation endpoints answer them (docs/API.md "Field detail codes" and
 * "Daily caps"). Every `details[]` item carries a stable `code` next to its
 * English `message`: known codes are shown in the interface language and
 * anything else falls back to the message as sent. Challenges and
 * moderation reuse this module (the codes are the same).
 */

/** Codes whose sentence needs no value. */
const simpleCodes: Readonly<Record<string, MessageKey>> = {
  required: 'communities.field.required',
  invalid_characters: 'communities.field.characters',
  contains_secret: 'communities.field.secret',
  insecure_link: 'communities.field.httpsLink',
  link_required: 'communities.field.linkRequired',
  moderators_only: 'communities.field.verifiedGuidance',
  poll_mismatch: 'communities.field.pollMismatch',
  duplicate_option: 'communities.field.pollDistinct',
  must_be_future: 'communities.field.pollCloses',
  invalid_parent: 'communities.field.invalidParent',
  invalid_option: 'communities.field.invalidOption',
  self_not_allowed: 'communities.field.selfNotAllowed',
  reason_required: 'communities.field.reasonRequired',
  share_required: 'communities.field.shareRequired',
  slug_taken: 'communities.field.slugTaken',
  too_small: 'communities.field.tooSmall',
  too_large: 'communities.field.tooLarge',
  invalid_choice: 'communities.field.invalidChoice',
  invalid_format: 'communities.field.invalidFormat',
  invalid_type: 'communities.field.invalid',
  unexpected_property: 'communities.field.invalid',
};

/** Codes whose sentence carries a count (`params.min` / `params.max`). */
const countedCodes: Readonly<Record<string, { key: MessageKey; param: 'min' | 'max' }>> = {
  too_short: { key: 'communities.field.tooShort', param: 'min' },
  too_long: { key: 'communities.field.tooLongMax', param: 'max' },
  too_few: { key: 'communities.field.tooFew', param: 'min' },
  too_many: { key: 'communities.field.tooMany', param: 'max' },
  too_many_links: { key: 'communities.field.linksMax', param: 'max' },
};

/** One field problem in the interface language; unknown codes keep the API's message. */
export function fieldCodeMessage(issue: FieldIssue, t: Translate): string {
  const code = issue.code;
  if (!code) return issue.message;
  const counted = countedCodes[code];
  if (counted) {
    const count = detailCount(issue.params, counted.param);
    if (count !== null) return t(counted.key, { count });
  }
  if (code === 'invalid_topic') {
    const index = detailCount(issue.params, 'index');
    if (index !== null) return t('communities.field.invalidTopic', { number: index + 1 });
    return t('communities.field.topics');
  }
  const key = simpleCodes[code];
  return key ? t(key) : issue.message;
}

/**
 * Maps coded API field problems (`details[].field` such as `body.title`) to
 * form fields, localized by code. Keys of `fieldMap` are the API field
 * names without the `body.` prefix. Returns the messages that belong to no
 * field so the form can show them in its summary.
 */
export function applyCodedServerErrors<T extends FieldValues>(
  error: ApiError,
  setError: UseFormSetError<T>,
  fieldMap: Readonly<Partial<Record<string, Path<T>>>>,
  t: Translate,
): string[] {
  const unmatched: string[] = [];
  let focused = false;
  for (const detail of error.details) {
    const apiField = detail.field?.replace(/^body\./u, '');
    const formField = apiField ? fieldMap[apiField] : undefined;
    const message = fieldCodeMessage(detail, t);
    if (formField) {
      setError(formField, { type: 'server', message }, { shouldFocus: !focused });
      focused = true;
    } else {
      unmatched.push(message);
    }
  }
  return unmatched;
}

/** What a daily cap (429 `daily_cap`) counted, and when it opens again. */
export interface DailyCap {
  /** The cap (e.g. 20 posts a day), when the API said it. */
  limit: number | null;
  /** `params.resource` or `params.kind`, e.g. `posts`. */
  resource: string | null;
  /** Seconds until the oldest counted action leaves the window (Retry-After, or from `retry_at`). */
  waitSeconds: number | null;
}

/** The daily cap behind a 429, or null for any other error (including burst limits). */
export function dailyCap(error: unknown, now: number = Date.now()): DailyCap | null {
  if (!hasErrorCode(error, 'RATE_LIMITED')) return null;
  const detail = error.details.find((item) => item.code === 'daily_cap');
  if (!detail) return null;
  let waitSeconds = error.retryAfterSeconds;
  if (waitSeconds === null) {
    const retryAt = Date.parse(detailParam(detail.params, 'retry_at') ?? '');
    waitSeconds = Number.isNaN(retryAt) ? null : Math.max(1, Math.ceil((retryAt - now) / 1000));
  }
  return {
    limit: detailCount(detail.params, 'limit'),
    resource: detailParam(detail.params, 'resource') ?? detailParam(detail.params, 'kind'),
    waitSeconds,
  };
}

const resourceKeys: Readonly<Record<string, MessageKey>> = {
  posts: 'communities.errors.dailyCap.posts',
  comments: 'communities.errors.dailyCap.comments',
  reports: 'communities.errors.dailyCap.reports',
  communities: 'communities.errors.dailyCap.communities',
  challenges: 'communities.errors.dailyCap.challenges',
};

/**
 * "You’ve reached today’s limit of 20 posts. You can try again in 3 hours."
 * for a daily cap; null for any other error.
 */
export function dailyCapMessage(
  error: unknown,
  t: Translate,
  now: number = Date.now(),
): string | null {
  const cap = dailyCap(error, now);
  if (!cap) return null;
  const key = cap.resource ? resourceKeys[cap.resource] : undefined;
  const reached =
    key && cap.limit !== null
      ? t(key, { count: cap.limit })
      : t('communities.errors.dailyCap.generic');
  const again =
    cap.waitSeconds === null
      ? t('communities.errors.dailyCap.later')
      : t('communities.errors.dailyCap.wait', { wait: formatWait(t, cap.waitSeconds) });
  return `${reached} ${again}`;
}
