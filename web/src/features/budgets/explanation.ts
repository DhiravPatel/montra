import type { Money } from '@/shared/api/types';
import { detailCount, detailParam } from '@/shared/finance/domainErrors';
import type { BudgetExplainItem, BudgetProgress } from '@/shared/finance/types';
import { formatLocalDate, isLocalDate } from '@/shared/formatting/dates';
import { absDecimal } from '@/shared/formatting/decimal';
import type { Translate } from '@/shared/i18n/types';

type FormatMoney = (money: Pick<Money, 'amount' | 'currency'>) => string;

const DECIMAL = /^-?\d+(\.\d+)?$/;
const CURRENCY = /^[A-Z]{3}$/;

/** A money param pair from the API (decimal string + currency), formatted; null when malformed. */
function moneyParam(
  params: BudgetExplainItem['params'],
  key: string,
  formatMoney: FormatMoney,
): string | null {
  const amount = detailParam(params, key);
  const currency = detailParam(params, 'currency');
  if (!amount || !currency || !DECIMAL.test(amount) || !CURRENCY.test(currency)) return null;
  try {
    return formatMoney({ amount, currency });
  } catch {
    return null;
  }
}

function dateParam(params: BudgetExplainItem['params'], key: string, locale: string) {
  const value = detailParam(params, key);
  return value && isLocalDate(value) ? formatLocalDate(value, locale) : null;
}

/** One explanation line in the interface language, or null for a code this client does not know. */
function explainLine(
  item: BudgetExplainItem,
  t: Translate,
  formatMoney: FormatMoney,
  locale: string,
): string | null {
  const params = item.params;
  switch (item.code) {
    case 'spent_of_limit': {
      const spent = moneyParam(params, 'spent', formatMoney);
      const limit = moneyParam(params, 'limit', formatMoney);
      const from = dateParam(params, 'from', locale);
      const to = dateParam(params, 'to', locale);
      return spent && limit && from && to
        ? t('budgets.explain.spent', { spent, limit, from, to })
        : null;
    }
    case 'refunds_restore':
      return t('budgets.explain.refundsRestore');
    case 'refunds_do_not_restore':
      return t('budgets.explain.refundsDoNotRestore');
    case 'rollover_included': {
      const raw = detailParam(params, 'amount');
      const currency = detailParam(params, 'currency');
      if (!raw || !currency || !DECIMAL.test(raw) || !CURRENCY.test(currency)) return null;
      const amount = formatMoney({ amount: absDecimal(raw), currency });
      return raw.startsWith('-')
        ? t('budgets.explain.rolloverOverspend', { amount })
        : t('budgets.explain.rolloverUnused', { amount });
    }
    case 'projection_estimate': {
      const amount = moneyParam(params, 'projected', formatMoney);
      return amount ? t('budgets.explain.projected', { amount }) : null;
    }
    case 'other_currencies_excluded': {
      const count = detailCount(params, 'count');
      return count === null ? null : t('budgets.explain.otherCurrencies', { count });
    }
    case 'owner_totals_only':
      return t('budgets.explain.collaborator');
    default:
      return null;
  }
}

/**
 * How the progress was worked out, from the API's `explanation_items`
 * (codes with values) in the interface language. A line whose code this
 * client does not know yet falls back to the API's English line at the same
 * position, so nothing is silently dropped.
 */
export function progressExplanation(
  progress: Pick<BudgetProgress, 'explanation' | 'explanation_items'>,
  t: Translate,
  formatMoney: FormatMoney,
  locale: string,
): string[] {
  const lines: string[] = [];
  progress.explanation_items.forEach((item, index) => {
    const line = explainLine(item, t, formatMoney, locale) ?? progress.explanation[index];
    if (line) lines.push(line);
  });
  return lines;
}

/** Day-based position of "expected by today" on the meter (basis points), or null. */
export function expectedMarker(progress: BudgetProgress): number | null {
  if (progress.total_days <= 0 || progress.elapsed_days <= 0) return null;
  if (progress.elapsed_days >= progress.total_days) return null;
  return Math.round((progress.elapsed_days / progress.total_days) * 10_000);
}
