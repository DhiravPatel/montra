import { type ApiErrorCode, type FieldIssue, hasErrorCode, isApiError } from '@/shared/api/errors';
import { formatMoney } from '@/shared/formatting/money';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/**
 * Coded errors (docs/API.md "Domain rule codes"): `DOMAIN_RULE_VIOLATION`
 * (422) and the state conflicts `CONFLICT` / `DUPLICATE` (409) carry a
 * machine-readable reason in `details[0].code` and values in
 * `details[0].params` (strings). Known codes are shown in the interface
 * language; anything else falls back to the screen's own explanation.
 */
const simpleCodes: Readonly<Record<string, MessageKey>> = {
  original_not_refundable: 'finance.rule.original_not_refundable',
  account_inactive: 'finance.rule.account_inactive',
  group_linked: 'finance.rule.group_linked',
  has_linked_refunds: 'finance.rule.has_linked_refunds',
};

/** Lifecycle statuses named by `invalid_status_transition` (from / to). */
const lifecycleWords: Readonly<Record<string, MessageKey>> = {
  active: 'finance.lifecycle.active',
  paused: 'finance.lifecycle.paused',
  archived: 'finance.lifecycle.archived',
  cancelled: 'finance.lifecycle.cancelled',
  achieved: 'finance.lifecycle.achieved',
  trial: 'finance.lifecycle.trial',
  cancellation_pending: 'finance.lifecycle.cancellation_pending',
  ended: 'finance.lifecycle.ended',
  merged: 'finance.lifecycle.merged',
  draft: 'finance.lifecycle.draft',
  pending: 'finance.lifecycle.pending',
  posted: 'finance.lifecycle.posted',
  voided: 'finance.lifecycle.voided',
  reversed: 'finance.lifecycle.reversed',
};

/**
 * Generic field detail codes (`details[].code` on VALIDATION_ERROR): the
 * framework's schema checks and the community, moderation and challenge
 * validators. Codes with a value carry it in `details[].params`.
 */
const fieldCodes: Readonly<Record<string, MessageKey>> = {
  required: 'finance.field.required',
  too_short: 'finance.field.too_short',
  too_long: 'finance.field.too_long',
  too_few: 'finance.field.too_few',
  too_many: 'finance.field.too_many',
  too_small: 'finance.field.too_small',
  too_large: 'finance.field.too_large',
  invalid_choice: 'finance.field.invalid_choice',
  invalid_format: 'finance.field.invalid_format',
  invalid_type: 'finance.field.invalid_type',
  unexpected_property: 'finance.field.unexpected_property',
  invalid_characters: 'finance.field.invalid_characters',
  contains_secret: 'finance.field.contains_secret',
  too_many_links: 'finance.field.too_many_links',
  insecure_link: 'finance.field.insecure_link',
  link_required: 'finance.field.link_required',
  moderators_only: 'finance.field.moderators_only',
  poll_mismatch: 'finance.field.poll_mismatch',
  duplicate_option: 'finance.field.duplicate_option',
  must_be_future: 'finance.field.must_be_future',
  invalid_parent: 'finance.field.invalid_parent',
  invalid_option: 'finance.field.invalid_option',
  invalid_topic: 'finance.field.invalid_topic',
  self_not_allowed: 'finance.field.self_not_allowed',
  reason_required: 'finance.field.reason_required',
  share_required: 'finance.field.share_required',
  slug_taken: 'finance.field.slug_taken',
};

/** Codes whose message counts a limit (`min` or `max` in params). */
const fieldCounts: Readonly<Record<string, 'min' | 'max'>> = {
  too_short: 'min',
  too_long: 'max',
  too_few: 'min',
  too_many: 'max',
  too_many_links: 'max',
};

/**
 * A field problem in the interface language, by its detail code; the
 * server's English message is the fallback for codes this client does not
 * know (and for details without a code).
 */
export function fieldIssueMessage(detail: FieldIssue, t: Translate): string {
  const key = detail.code ? fieldCodes[detail.code] : undefined;
  if (!key || !detail.code) return detail.message;
  const counted = fieldCounts[detail.code];
  if (counted) {
    const count = detailCount(detail.params, counted);
    if (count === null) return detail.message;
    return t(key, { count });
  }
  if (detail.code === 'invalid_choice') {
    const allowed = detail.params?.allowed;
    const choices = Array.isArray(allowed) ? allowed.map(String).join(', ') : null;
    return choices ? t(key, { allowed: choices }) : t('finance.field.invalid_choice_generic');
  }
  if (detail.code === 'invalid_topic') {
    const index = detailCount(detail.params, 'index');
    return index === null ? t('finance.field.invalid_topic_generic') : t(key, { index: index + 1 });
  }
  return t(key);
}

/** `record_limit_reached` resources (fair-use caps from GET /limits). */
const limitMessages: Readonly<Record<string, MessageKey>> = {
  bills: 'finance.rule.record_limit_reached.bills',
  recurring_rules: 'finance.rule.record_limit_reached.recurring_rules',
  subscriptions: 'finance.rule.record_limit_reached.subscriptions',
  goals: 'finance.rule.record_limit_reached.goals',
};

export interface CodedDetail {
  code: string;
  /** Values for the code; untrusted data (read them with detailParam). */
  params: Readonly<Record<string, unknown>>;
}

const CODED_ERRORS: readonly ApiErrorCode[] = [
  'DOMAIN_RULE_VIOLATION',
  'CONFLICT',
  'DUPLICATE',
  'VALIDATION_ERROR',
];

/**
 * The reason code and params of a coded error (422 domain rules, 409
 * CONFLICT / DUPLICATE details, and coded VALIDATION_ERROR details such as
 * `cancellation_confirmation_required`). Limit it with `codes`.
 */
export function errorDetail(
  error: unknown,
  codes: readonly ApiErrorCode[] = CODED_ERRORS,
): CodedDetail | null {
  if (!isApiError(error) || !codes.includes(error.code)) return null;
  const detail = error.details.find((item) => item.code);
  if (!detail?.code) return null;
  return { code: detail.code, params: detail.params ?? {} };
}

/** The error's reason code (see errorDetail), or null. */
export function errorDetailCode(
  error: unknown,
  codes: readonly ApiErrorCode[] = CODED_ERRORS,
): string | null {
  return errorDetail(error, codes)?.code ?? null;
}

/** A string or number param of a coded error, as text. */
export function detailParam(params: unknown, key: string): string | null {
  if (typeof params !== 'object' || params === null || !(key in params)) return null;
  const value: unknown = (params as Record<string, unknown>)[key];
  return typeof value === 'string' || typeof value === 'number' ? String(value) : null;
}

/** A whole-number param (e.g. counts and limits), or null. */
export function detailCount(params: unknown, key: string): number | null {
  const value = detailParam(params, key);
  if (value === null || !/^\d+$/.test(value.trim())) return null;
  return Number(value.trim());
}

/** Details code and params of a coded domain-rule error, if any. */
export function domainRuleCode(error: unknown): { code: string; params: unknown } | null {
  if (!isApiError(error) || error.code !== 'DOMAIN_RULE_VIOLATION') return null;
  const detail = error.details.find((item) => item.code);
  if (!detail?.code) return null;
  return { code: detail.code, params: detail.params };
}

/**
 * The record changed somewhere else: a stale `version` (409
 * VERSION_CONFLICT) or a lifecycle action that no longer fits its status
 * (422 invalid_status_transition). Screens reload the record.
 */
export function isStaleRecordError(error: unknown): boolean {
  return (
    hasErrorCode(error, 'VERSION_CONFLICT') ||
    domainRuleCode(error)?.code === 'invalid_status_transition'
  );
}

/** "It can’t change from archived to paused" (statuses in the interface language). */
export function statusTransitionMessage(params: unknown, t: Translate): string {
  const from = detailParam(params, 'from');
  const to = detailParam(params, 'to');
  const fromKey = from ? lifecycleWords[from] : undefined;
  const toKey = to ? lifecycleWords[to] : undefined;
  // Repeating an action (pausing a paused record) names the same status twice.
  if (fromKey && from === to) {
    return t('finance.rule.invalid_status_transition_same', { status: t(fromKey) });
  }
  if (fromKey && toKey) {
    return t('finance.rule.invalid_status_transition', { from: t(fromKey), to: t(toKey) });
  }
  return t('finance.rule.invalid_status_transition_generic');
}

/** "You can keep up to 200 bills…" for `record_limit_reached`. */
export function recordLimitMessage(params: unknown, t: Translate): string {
  const resource = detailParam(params, 'resource');
  const limit = detailCount(params, 'limit');
  const key = resource ? limitMessages[resource] : undefined;
  if (limit === null) return t('finance.rule.record_limit_reached.unknown');
  return t(key ?? 'finance.rule.record_limit_reached.generic', { count: limit });
}

export function domainRuleMessage(error: unknown, t: Translate, locale: string): string | null {
  const rule = domainRuleCode(error);
  if (!rule) return null;
  if (rule.code === 'refund_exceeds_remaining') {
    const remaining = detailParam(rule.params, 'remaining');
    const currency = detailParam(rule.params, 'currency');
    if (remaining && currency) {
      let amount = `${remaining} ${currency}`;
      try {
        amount = formatMoney(remaining, currency, locale);
      } catch {
        // keep the raw value
      }
      return t('finance.rule.refund_exceeds_remaining', { amount });
    }
    return t('finance.rule.refund_exceeds_remaining_generic');
  }
  if (rule.code === 'currency_mismatch') {
    const currency = detailParam(rule.params, 'currency');
    return currency
      ? t('finance.rule.currency_mismatch', { currency })
      : t('finance.rule.currency_mismatch_generic');
  }
  if (rule.code === 'invalid_status_transition') return statusTransitionMessage(rule.params, t);
  if (rule.code === 'record_limit_reached') return recordLimitMessage(rule.params, t);
  const key = simpleCodes[rule.code];
  return key ? t(key) : null;
}

/**
 * A localized sentence for a failed finance write: the shared coded rules
 * first, then a stale-version note, then the generic text for the error code.
 */
export function financeErrorMessage(error: unknown, t: Translate, locale: string): string {
  const rule = domainRuleMessage(error, t, locale);
  if (rule) return rule;
  if (hasErrorCode(error, 'VERSION_CONFLICT')) return t('finance.conflict.body');
  if (hasErrorCode(error, 'IDEMPOTENCY_CONFLICT')) return t('finance.errors.maybeSaved');
  return describeError(error, t);
}
