import { formatMoney } from '@/shared/formatting/money';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { Match } from './types';

/*
 * The server explains every suggested match, every confirmed match and
 * every possible duplicate found during an import with stable reason codes
 * (`reason_codes`, in the order of the English `reasons`) and the values
 * they refer to (`reason_params`). Codes are shown in the interface
 * language; a reason newer than this client is shown as the server wrote it.
 */
export type ReasonCode = Match['reason_codes'][number];

const reasonKeys: Readonly<Record<ReasonCode, MessageKey>> = {
  same_amount_direction: 'reconciliation.reason.sameAmount',
  same_date: 'reconciliation.reason.sameDate',
  one_day_apart: 'reconciliation.reason.oneDay',
  within_3_days: 'reconciliation.reason.threeDays',
  within_a_week: 'reconciliation.reason.week',
  same_reference: 'reconciliation.reason.sameReference',
  similar_description: 'reconciliation.reason.similarDescription',
  amounts_add_up: 'reconciliation.reason.amountsAddUp',
  all_within_a_week: 'reconciliation.reason.allWithinWeek',
  dates_far_apart: 'reconciliation.reason.datesFarApart',
  pending_replaced_by_posted: 'reconciliation.reason.pendingReplaced',
  pending_amount_differs: 'reconciliation.reason.amountsDiffer',
  entered_manually_and_imported: 'reconciliation.reason.enteredTwice',
};

export type ReasonParams = Readonly<Record<string, string>>;

function money(amount: string, currency: string | undefined, locale: string): string {
  if (!currency) return amount;
  try {
    return formatMoney(amount, currency, locale);
  } catch {
    return `${amount} ${currency}`;
  }
}

function isReasonCode(value: string): value is ReasonCode {
  return Object.hasOwn(reasonKeys, value);
}

/**
 * One localized reason by its code. `fallback` is the server's English
 * text for that reason; `currency` formats amounts quoted in a reason when
 * the params carry none.
 */
export function reasonCodeText(
  code: string,
  params: ReasonParams | undefined,
  t: Translate,
  locale: string,
  fallback?: string,
  currency?: string,
): string {
  if (!isReasonCode(code)) return fallback ?? code;
  if (code === 'dates_far_apart') {
    const days = Number(params?.days_apart);
    return Number.isInteger(days) && days > 0
      ? t('reconciliation.reason.datesFarApartDays', { count: days })
      : t(reasonKeys[code]);
  }
  if (code === 'pending_amount_differs') {
    if (!params?.pending_amount || !params.posted_amount) {
      return t('reconciliation.reason.amountsDifferGeneric');
    }
    const pending = params.pending_amount;
    const posted = params.posted_amount;
    const quoted = params.currency ?? currency;
    return t(reasonKeys[code], {
      pending: money(pending, quoted, locale),
      posted: money(posted, quoted, locale),
    });
  }
  return t(reasonKeys[code]);
}

export interface Explained {
  reason_codes: readonly string[];
  reason_params?: ReasonParams;
  /** English, in the order of the codes (the fallback for unknown codes). */
  reasons: readonly string[];
}

/** Every reason of a candidate or match in the interface language. */
export function reasonsText(
  explained: Explained,
  t: Translate,
  locale: string,
  currency?: string,
): string[] {
  if (explained.reason_codes.length === 0) return [...explained.reasons];
  return explained.reason_codes.map((code, index) =>
    reasonCodeText(code, explained.reason_params, t, locale, explained.reasons[index], currency),
  );
}
