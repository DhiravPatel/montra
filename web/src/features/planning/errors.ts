import { hasErrorCode } from '@/shared/api/errors';
import {
  domainRuleCode,
  domainRuleMessage,
  errorDetailCode,
  financeErrorMessage,
} from '@/shared/finance/domainErrors';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/** DOMAIN_RULE_VIOLATION codes of the recurring and bill endpoints. */
const ruleMessages: Readonly<Record<string, MessageKey>> = {
  bill_inactive: 'planning.rule.bill_inactive',
  transfer_needs_two_accounts: 'planning.rule.transfer_needs_two_accounts',
  cross_currency_transfer_not_auto_posted: 'planning.rule.cross_currency_transfer_not_auto_posted',
  bills_not_auto_posted: 'planning.rule.bills_not_auto_posted',
  auto_post_needs_amount_and_account: 'planning.rule.auto_post_needs_amount_and_account',
  use_bill_screen: 'planning.rule.use_bill_screen',
  postpone_needs_later_open_occurrence: 'planning.rule.postpone_needs_later_open_occurrence',
  transaction_voided: 'planning.rule.transaction_voided',
  transfer_missing_destination: 'planning.rule.transfer_missing_destination',
};

/**
 * 409 CONFLICT reasons (`details[0].code`): the schedule or occurrence is
 * no longer in the state the screen showed. Every planning write refreshes
 * finance data when it settles, so the messages can say it was refreshed.
 */
const conflictMessages: Readonly<Record<string, MessageKey>> = {
  schedule_ended: 'planning.conflict.schedule_ended',
  rule_in_use: 'planning.conflict.rule_in_use',
  no_open_occurrence: 'planning.conflict.no_open_occurrence',
  occurrence_not_open: 'planning.conflict.occurrence_not_open',
  occurrence_not_skipped: 'planning.conflict.occurrence_not_skipped',
  occurrence_already_handled: 'planning.conflict.occurrence_already_handled',
};

/** Lifecycle statuses of bills and schedules, as words inside a sentence. */
/** The 409 CONFLICT reason of a planning error, if any. */
export function planningConflictCode(error: unknown): string | null {
  return errorDetailCode(error, ['CONFLICT']);
}

/**
 * A localized message for a failed planning write: coded rule violations
 * first (including the shared invalid_status_transition and
 * record_limit_reached), then coded conflicts, duplicate links and stale
 * versions, then the generic text for the error code.
 */
export function planningErrorMessage(error: unknown, t: Translate, locale: string): string {
  const rule = domainRuleCode(error);
  if (rule) {
    const key = ruleMessages[rule.code];
    if (key) return t(key);
  }
  if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
    return domainRuleMessage(error, t, locale) ?? describeError(error, t);
  }
  const conflict = planningConflictCode(error);
  const conflictKey = conflict ? conflictMessages[conflict] : undefined;
  if (conflictKey) return t(conflictKey);
  if (hasErrorCode(error, 'DUPLICATE')) return t('planning.errors.alreadyLinked');
  if (hasErrorCode(error, 'CONFLICT')) return t('planning.errors.alreadyHandled');
  if (hasErrorCode(error, 'VERSION_CONFLICT')) return t('planning.errors.changedElsewhere');
  return financeErrorMessage(error, t, locale);
}
