import { useCallback } from 'react';
import { type ApiErrorCode, hasErrorCode, isApiError } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { detailParam, domainRuleCode, errorDetailCode } from '@/shared/finance/domainErrors';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { formatWait } from '@/shared/i18n/formatWait';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { dailyCapMessage, fieldCodeMessage } from './fieldCodes';

/**
 * Community rule codes (422 DOMAIN_RULE_VIOLATION `details[0].code`; see
 * docs/API.md "Domain rule codes") in the interface language.
 */
const communityRules: Readonly<Record<string, MessageKey>> = {
  not_accepting_posts: 'communities.rule.not_accepting_posts',
  join_community_first: 'communities.rule.join_community_first',
  account_restricted: 'communities.rule.account_restricted',
  not_accepting_members: 'communities.rule.not_accepting_members',
  invitation_only: 'communities.rule.invitation_only',
  transfer_ownership_first: 'communities.rule.transfer_ownership_first',
  community_suspended: 'communities.rule.community_suspended',
  post_locked: 'communities.rule.post_locked',
  new_account_links: 'communities.rule.new_account_links',
  comments_closed: 'communities.rule.comments_closed',
  comment_locked: 'communities.rule.comment_locked',
  content_unavailable: 'communities.rule.content_unavailable',
  poll_closed: 'communities.rule.poll_closed',
  own_content: 'communities.rule.own_content',
  owner_protected: 'communities.rule.owner_protected',
  already_deleted: 'communities.rule.already_deleted',
  not_appealable: 'communities.rule.not_appealable',
  appeal_window_passed: 'communities.rule.appeal_window_passed',
  appeal_needs_other_moderator: 'communities.rule.appeal_needs_other_moderator',
};

/** Coded 409 CONFLICT answers (docs/API.md "409 CONFLICT"). */
const conflictRules: Readonly<Record<string, MessageKey>> = {
  already_member: 'communities.conflict.already_member',
  invitation_used: 'communities.conflict.invitation_used',
  invitation_inactive: 'communities.conflict.invitation_inactive',
  slug_taken: 'communities.field.slugTaken',
  already_reported: 'communities.report.already',
};

/** The reason code of a 409 CONFLICT, when the API gave one. */
export function conflictCode(error: unknown): string | null {
  return errorDetailCode(error, ['CONFLICT']);
}

export interface CommunityErrorContext {
  /** Sentences for coded rules in this context (e.g. own_content when reporting). */
  rules?: Readonly<Partial<Record<string, MessageKey>>>;
  /**
   * Sentences for error codes in this context (e.g. what 404 or 410 means
   * for this action). Coded 409 CONFLICT answers are explained by their code
   * first.
   */
  codes?: Readonly<Partial<Record<ApiErrorCode, MessageKey>>>;
}

/**
 * Rate limits answer calmly: a daily cap says what was counted and when it
 * opens again (429 `daily_cap` with Retry-After); a burst limit says how
 * long to wait; anything else is a plain "try again later".
 */
export function rateLimitMessage(error: unknown, t: Translate): string | null {
  if (!hasErrorCode(error, 'RATE_LIMITED')) return null;
  const cap = dailyCapMessage(error, t);
  if (cap) return cap;
  return error.retryAfterSeconds
    ? t('communities.errors.slowDown', { wait: formatWait(t, error.retryAfterSeconds) })
    : t('communities.errors.dailyLimit');
}

/** A localized sentence for a failed community action. */
export function communityErrorMessage(
  error: unknown,
  t: Translate,
  format: { locale: string; timeZone: string },
  context: CommunityErrorContext = {},
): string {
  const rule = domainRuleCode(error);
  if (rule) {
    if (rule.code === 'posting_restricted') {
      const until = parseTimestamp(detailParam(rule.params, 'until'));
      return until
        ? t('communities.rule.posting_restricted', {
            date: formatDateTime(until, format.locale, format.timeZone),
          })
        : t('communities.rule.posting_restricted_generic');
    }
    const key = context.rules?.[rule.code] ?? communityRules[rule.code];
    if (key) return t(key);
  }
  const conflict = conflictCode(error);
  if (conflict) {
    const key = context.rules?.[conflict] ?? conflictRules[conflict];
    if (key) return t(key);
  }
  const limited = rateLimitMessage(error, t);
  if (limited) return limited;
  if (isApiError(error)) {
    const key = context.codes?.[error.code];
    if (key) return t(key);
    if (error.code === 'FORBIDDEN') return t('communities.errors.forbidden');
    if (error.code === 'VERSION_CONFLICT') return t('communities.settings.details.conflictBody');
  }
  return describeError(error, t);
}

/** `communityErrorMessage` with the user's language and time zone. */
export function useCommunityError() {
  const { t, formatLocale } = useI18n();
  const { timezone } = useCurrentUser();
  return useCallback(
    (error: unknown, context?: CommunityErrorContext) =>
      communityErrorMessage(error, t, { locale: formatLocale, timeZone: timezone }, context),
    [t, formatLocale, timezone],
  );
}

export interface FieldProblem {
  /** API field without the `body.` prefix, e.g. `title` or `poll.options`. */
  field: string;
  message: string;
  /** The API's stable code, when it sent one. */
  code?: string;
}

/** The field problems of a VALIDATION_ERROR, localized by code (the message is the fallback). */
export function fieldProblems(error: unknown, t: Translate): FieldProblem[] {
  if (!hasErrorCode(error, 'VALIDATION_ERROR')) return [];
  return error.details.map((detail) => ({
    field: detail.field?.replace(/^body\./u, '') ?? '',
    message: fieldCodeMessage(detail, t),
    ...(detail.code ? { code: detail.code } : {}),
  }));
}

/**
 * Splits field problems into the ones a form shows next to its fields and
 * the rest (shown in the form's summary).
 */
export function splitFieldProblems<F extends string>(
  problems: readonly FieldProblem[],
  fields: Readonly<Partial<Record<string, F>>>,
): { byField: Partial<Record<F, string>>; rest: string[] } {
  const byField: Partial<Record<F, string>> = {};
  const rest: string[] = [];
  for (const problem of problems) {
    const field = fields[problem.field];
    if (field && byField[field] === undefined) byField[field] = problem.message;
    else if (!field) rest.push(problem.message);
  }
  return { byField, rest };
}
