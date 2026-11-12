import { hasErrorCode } from '@/shared/api/errors';
import {
  detailParam,
  domainRuleCode,
  domainRuleMessage,
  errorDetail,
} from '@/shared/finance/domainErrors';
import { formatMoney } from '@/shared/formatting/money';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/** Coded goal rules without values (422 DOMAIN_RULE_VIOLATION). */
const simpleRules: Readonly<Record<string, MessageKey>> = {
  goal_inactive: 'goals.contribute.errors.inactive',
  owner_role_fixed: 'goals.rule.owner_role_fixed',
  owner_cannot_leave: 'goals.rule.owner_cannot_leave',
  member_controls_visibility: 'goals.rule.member_controls_visibility',
};

/**
 * Coded goal rules (`DOMAIN_RULE_VIOLATION` with `details[0].code`) in the
 * interface language, then the shared finance rules (invalid_status_transition,
 * record_limit_reached…); null for anything else.
 */
export function goalRuleMessage(error: unknown, t: Translate, locale: string): string | null {
  const rule = domainRuleCode(error);
  if (!rule) return null;
  if (rule.code === 'withdrawal_exceeds_saved') {
    const saved = detailParam(rule.params, 'saved');
    const currency = detailParam(rule.params, 'currency');
    if (saved && currency) {
      try {
        return t('goals.contribute.errors.exceedsSaved', {
          amount: formatMoney(saved, currency, locale),
        });
      } catch {
        // fall through to the message without an amount
      }
    }
    return t('goals.contribute.errors.exceedsSavedGeneric');
  }
  const key = simpleRules[rule.code];
  if (key) return t(key);
  return domainRuleMessage(error, t, locale);
}

/**
 * 409 answers about one contribution: already recorded or voided
 * (CONFLICT details), or a transaction that already backs a contribution
 * (DUPLICATE transaction_already_counted).
 */
export function contributionConflictMessage(error: unknown, t: Translate): string | null {
  const detail = errorDetail(error, ['CONFLICT', 'DUPLICATE']);
  if (detail?.code === 'contribution_voided') return t('goals.record.errors.voided');
  if (detail?.code === 'contribution_not_planned') {
    const status = detailParam(detail.params, 'status');
    if (status === 'verified') return t('goals.record.errors.alreadyVerified');
    return t('goals.record.errors.alreadyRecorded');
  }
  if (detail?.code === 'transaction_already_counted' || hasErrorCode(error, 'DUPLICATE')) {
    return t('goals.contribute.errors.alreadyLinked');
  }
  return null;
}

/** True when a contribution changed elsewhere (the history should be reloaded). */
export function isContributionStale(error: unknown): boolean {
  const code = errorDetail(error, ['CONFLICT'])?.code;
  return code === 'contribution_voided' || code === 'contribution_not_planned';
}

/** Why a contribution could not be saved (validation errors are shown on the fields). */
export function contributionErrorMessage(error: unknown, t: Translate, locale: string): string {
  const rule = goalRuleMessage(error, t, locale);
  if (rule) return rule;
  const conflict = contributionConflictMessage(error, t);
  if (conflict) return conflict;
  if (hasErrorCode(error, 'FORBIDDEN')) return t('goals.contribute.errors.notAllowed');
  if (hasErrorCode(error, 'IDEMPOTENCY_CONFLICT')) return t('finance.errors.maybeSaved');
  return describeError(error, t);
}

/**
 * A failed goal write (edit, lifecycle, sharing): coded rules first, then a
 * stale version (the screen reloads the goal), then the generic text.
 */
export function goalErrorMessage(error: unknown, t: Translate, locale: string): string {
  const rule = goalRuleMessage(error, t, locale);
  if (rule) return rule;
  if (hasErrorCode(error, 'VERSION_CONFLICT')) return t('goals.lifecycle.changedElsewhere');
  if (hasErrorCode(error, 'IDEMPOTENCY_CONFLICT')) return t('finance.errors.maybeSaved');
  return describeError(error, t);
}
