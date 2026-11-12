import { hasErrorCode } from '@/shared/api/errors';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/** Coded moderation rules (422 DOMAIN_RULE_VIOLATION). */
const ruleMessages: Readonly<Record<string, MessageKey>> = {
  appeal_window_passed: 'moderation.errors.appealWindowPassed',
  not_appealable: 'moderation.errors.notAppealable',
  appeal_needs_other_moderator: 'moderation.errors.needsOtherModerator',
  own_content: 'moderation.errors.ownContent',
  already_deleted: 'moderation.errors.alreadyDeleted',
  owner_protected: 'moderation.errors.ownerProtected',
};

export function moderationRuleCode(error: unknown): string | null {
  const code = domainRuleCode(error)?.code;
  return code && code in ruleMessages ? code : null;
}

function ruleMessage(error: unknown, t: Translate): string | null {
  const code = moderationRuleCode(error);
  const key = code ? ruleMessages[code] : undefined;
  return key ? t(key) : null;
}

/** Asking for a review failed (validation is shown on the field). */
export function appealErrorMessage(error: unknown, t: Translate): string {
  const rule = ruleMessage(error, t);
  if (rule) return rule;
  if (hasErrorCode(error, 'CONFLICT')) return t('moderation.errors.alreadyAppealed');
  if (hasErrorCode(error, 'NOT_FOUND')) return t('moderation.errors.actionNotFound');
  return describeError(error, t);
}

/** A staff action failed. */
export function actErrorMessage(error: unknown, t: Translate): string {
  const rule = ruleMessage(error, t);
  if (rule) return rule;
  if (hasErrorCode(error, 'NOT_FOUND')) return t('moderation.errors.targetNotFound');
  if (hasErrorCode(error, 'CONFLICT')) return t('moderation.errors.actConflict');
  if (hasErrorCode(error, 'FORBIDDEN')) return t('moderation.errors.forbidden');
  return describeError(error, t);
}

/** Reversing failed. */
export function reverseErrorMessage(error: unknown, t: Translate): string {
  const rule = ruleMessage(error, t);
  if (rule) return rule;
  if (hasErrorCode(error, 'CONFLICT')) return t('moderation.errors.alreadyReversed');
  if (hasErrorCode(error, 'NOT_FOUND')) return t('moderation.errors.actionNotFound');
  if (hasErrorCode(error, 'FORBIDDEN')) return t('moderation.errors.forbidden');
  return describeError(error, t);
}

/** Deciding an appeal failed. */
export function decideErrorMessage(error: unknown, t: Translate): string {
  const rule = ruleMessage(error, t);
  if (rule) return rule;
  if (hasErrorCode(error, 'CONFLICT')) return t('moderation.errors.alreadyDecided');
  if (hasErrorCode(error, 'NOT_FOUND')) return t('moderation.errors.appealNotFound');
  if (hasErrorCode(error, 'FORBIDDEN')) return t('moderation.errors.forbidden');
  return describeError(error, t);
}
