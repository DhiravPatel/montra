import { hasErrorCode } from '@/shared/api/errors';
import { domainRuleCode, domainRuleMessage } from '@/shared/finance/domainErrors';
import { formatMoney } from '@/shared/formatting/money';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/** DOMAIN_RULE_VIOLATION codes of the reconciliation endpoints (docs/API.md). */
const ruleMessages: Readonly<Record<string, MessageKey>> = {
  direction_mismatch: 'reconciliation.errors.direction_mismatch',
  invalid_match_shape: 'reconciliation.errors.invalid_match_shape',
  invalid_pair: 'reconciliation.errors.invalid_pair',
};

function param(params: unknown, key: string): string | null {
  if (typeof params !== 'object' || params === null || !(key in params)) return null;
  const value: unknown = (params as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : null;
}

function money(amount: string, currency: string, locale: string): string {
  try {
    return formatMoney(amount, currency, locale);
  } catch {
    return `${amount} ${currency}`;
  }
}

/**
 * A localized message for a failed match, unmatch or balance check: coded
 * rules first (the sums of both sides are quoted from the server), then
 * conflicts (already matched, or the match changed), then generic text.
 */
export function reconciliationErrorMessage(error: unknown, t: Translate, locale: string): string {
  const rule = domainRuleCode(error);
  if (rule) {
    if (rule.code === 'sums_differ') {
      const statement = param(rule.params, 'statement');
      const ledger = param(rule.params, 'ledger');
      const currency = param(rule.params, 'currency');
      return statement && ledger && currency
        ? t('reconciliation.errors.sums_differ', {
            statement: money(statement, currency, locale),
            ledger: money(ledger, currency, locale),
          })
        : t('reconciliation.errors.sums_differ_generic');
    }
    const key = ruleMessages[rule.code];
    if (key) return t(key);
  }
  if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
    return domainRuleMessage(error, t, locale) ?? describeError(error, t);
  }
  if (hasErrorCode(error, 'DUPLICATE')) return t('reconciliation.errors.alreadyMatched');
  if (hasErrorCode(error, 'CONFLICT')) return t('reconciliation.errors.changed');
  if (hasErrorCode(error, 'NOT_FOUND')) return t('reconciliation.errors.notFound');
  return describeError(error, t);
}
