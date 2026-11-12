import type { Money } from '@/shared/api/types';
import { compareDecimal } from '@/shared/formatting/decimal';
import { amountSign } from '@/shared/formatting/money';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { Comparison, MetricChange } from './types';

export type Direction = 'higher' | 'lower' | 'same';

/**
 * Which of two exact API amounts (same currency) is larger. A display
 * choice only: no difference is calculated on the client.
 */
export function moneyDirection(current: string, comparison: string): Direction {
  const order = compareDecimal(current, comparison);
  return order === 1 ? 'higher' : order === -1 ? 'lower' : 'same';
}

export function countDirection(current: number, comparison: number): Direction {
  return current > comparison ? 'higher' : current < comparison ? 'lower' : 'same';
}

type NoteCode = Comparison['note_codes'][number];

const noteKeys: Readonly<Record<NoteCode, MessageKey>> = {
  same_filters_and_rules: 'analytics.compare.note.sameRules',
  compared_as_totals: 'analytics.compare.note.differentLengths',
  currencies_separate: 'analytics.compare.note.currenciesSeparate',
};

/**
 * How the periods are compared, in the interface language by `note_codes`
 * (in the order of the API's English `notes`, which are the fallback for a
 * code newer than this client).
 */
export function comparisonNotes(data: Comparison, t: Translate): string[] {
  if (data.note_codes.length === 0) return [...data.notes];
  return data.note_codes.map((code, index) => {
    if (!Object.hasOwn(noteKeys, code)) return data.notes[index] ?? code;
    if (code === 'compared_as_totals') {
      return t(noteKeys[code], {
        current: data.window.days,
        other: data.comparison_window.days,
      });
    }
    return t(noteKeys[code]);
  });
}

/** Which way a server-computed change points (a display choice; the amount is the API's). */
export function changeDirection(change: Pick<Money, 'amount'>): Direction {
  const sign = amountSign(change.amount);
  return sign === 1 ? 'higher' : sign === -1 ? 'lower' : 'same';
}

/** "+₹950.50 (+316.8%)" or "+₹800.00" when the comparison amount was zero. */
export function formatChange(
  change: MetricChange,
  format: (money: Money) => string,
  locale: string,
): string {
  const amount = format(change.change);
  return change.change_bp === undefined
    ? amount
    : `${amount} (${formatChangeBp(change.change_bp, locale)})`;
}

export const directionLabel: Readonly<Record<Direction, MessageKey>> = {
  higher: 'analytics.compare.higher',
  lower: 'analytics.compare.lower',
  same: 'analytics.compare.same',
};

/** Signed percentage of a change in basis points ("+316.8%"). */
export function formatChangeBp(basisPoints: number, locale: string): string {
  return new Intl.NumberFormat(locale, {
    style: 'percent',
    maximumFractionDigits: 1,
    signDisplay: 'exceptZero',
  }).format(basisPoints / 10_000);
}
