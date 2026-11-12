import { type ApiErrorCode, hasErrorCode, isApiError } from '@/shared/api/errors';
import { domainRuleCode, errorDetail } from '@/shared/finance/domainErrors';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/**
 * Group rule codes (422 DOMAIN_RULE_VIOLATION, `details[0].code`; see
 * docs/API.md "Domain rule codes") in the interface language.
 */
const groupRules: Readonly<Record<string, MessageKey>> = {
  balance_open: 'groups.rule.balance_open',
  balances_open: 'groups.rule.balances_open',
  transfer_ownership_first: 'groups.rule.transfer_ownership_first',
  group_archived: 'groups.rule.group_archived',
  currency_locked: 'groups.rule.currency_locked',
};

/**
 * Coded state conflicts (409 CONFLICT, `details[0].code`). `group_archived`
 * moved from a 422 rule to a 409 conflict; both are understood.
 */
const groupConflicts: Readonly<Record<string, MessageKey>> = {
  already_member: 'groups.invite.alreadyMember',
  join_request_pending: 'groups.conflict.join_request_pending',
  invitation_used: 'groups.conflict.invitation_used',
  group_archived: 'groups.rule.group_archived',
  group_not_archived: 'groups.owner.restore.notArchived',
};

export interface GroupErrorContext {
  /** Sentences for coded rules in this context (e.g. balance_open when removing someone). */
  rules?: Readonly<Partial<Record<string, MessageKey>>>;
  /** Sentences for coded 409 conflicts in this context (e.g. join_request_pending from the admins' side). */
  conflicts?: Readonly<Partial<Record<string, MessageKey>>>;
  /**
   * Sentences for error codes in this context (a CONFLICT without a detail
   * code, GONE, NOT_FOUND…): each action names what its answer means.
   */
  codes?: Readonly<Partial<Record<ApiErrorCode, MessageKey>>>;
}

/** The coded 409 conflict of an error (`already_member`, `invitation_used`…), or null. */
export function groupConflictCode(error: unknown): string | null {
  return errorDetail(error, ['CONFLICT'])?.code ?? null;
}

/** The coded group rule of an error, localized; null for anything else. */
export function groupRuleMessage(
  error: unknown,
  t: Translate,
  rules?: GroupErrorContext['rules'],
): string | null {
  const rule = domainRuleCode(error);
  if (!rule) return null;
  const key = rules?.[rule.code] ?? groupRules[rule.code];
  return key ? t(key) : null;
}

/** The coded 409 conflict of an error, localized; null for anything else. */
export function groupConflictMessage(
  error: unknown,
  t: Translate,
  conflicts?: GroupErrorContext['conflicts'],
): string | null {
  const code = groupConflictCode(error);
  if (!code) return null;
  const key = conflicts?.[code] ?? groupConflicts[code];
  return key ? t(key) : null;
}

/** A localized sentence for a failed group action. */
export function groupErrorMessage(
  error: unknown,
  t: Translate,
  context: GroupErrorContext = {},
): string {
  const rule = groupRuleMessage(error, t, context.rules);
  if (rule) return rule;
  const conflict = groupConflictMessage(error, t, context.conflicts);
  if (conflict) return conflict;
  if (isApiError(error)) {
    const key = context.codes?.[error.code];
    if (key) return t(key);
    if (error.code === 'FORBIDDEN') return t('groups.errors.forbidden');
    if (error.code === 'VERSION_CONFLICT') return t('finance.conflict.body');
  }
  return describeError(error, t);
}

/**
 * An invitation named nobody, or both a username and a friend
 * (`username_or_user_id` on body.username or body.user_id).
 */
export function isUsernameOrUserIdError(error: unknown): boolean {
  return (
    isApiError(error) &&
    error.code === 'VALIDATION_ERROR' &&
    error.details.some((detail) => detail.code === 'username_or_user_id')
  );
}

/**
 * The group changed under the screen (role, status or membership): the
 * page reloads it so controls match what the server allows now.
 */
export function shouldReloadGroup(error: unknown): boolean {
  if (hasErrorCode(error, 'FORBIDDEN') || hasErrorCode(error, 'VERSION_CONFLICT')) return true;
  if (hasErrorCode(error, 'NOT_FOUND') || hasErrorCode(error, 'CONFLICT')) return true;
  return domainRuleCode(error)?.code === 'group_archived';
}
