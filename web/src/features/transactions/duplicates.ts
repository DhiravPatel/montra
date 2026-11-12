import type { DuplicateHint } from '@/shared/finance/types';
import type { Translate } from '@/shared/i18n/types';

/**
 * Why a transaction looks like a duplicate, in the interface language.
 * `reason_codes` (with `days_apart`) are preferred; the English `reasons`
 * are kept as a fallback for codes this client does not know yet.
 */
export function duplicateReasons(hint: DuplicateHint, t: Translate): string[] {
  const codes = hint.reason_codes;
  if (codes.length === 0) return hint.reasons.map((reason) => duplicateReason(reason, t));
  return codes.map((code, index) => {
    if (code === 'same_account_amount') return t('transactions.duplicates.reason.sameAmount');
    if (code === 'same_date') return t('transactions.duplicates.reason.sameDate');
    if (code === 'same_description') return t('transactions.duplicates.reason.sameDescription');
    if (code === 'within_days') {
      return t('transactions.duplicates.reason.withinDays', { count: hint.days_apart });
    }
    return duplicateReason(hint.reasons[index] ?? code, t);
  });
}

/** Older English reasons (kept for compatibility with earlier API builds). */
export function duplicateReason(reason: string, t: Translate): string {
  if (reason === 'same account and amount') return t('transactions.duplicates.reason.sameAmount');
  if (reason === 'same date') return t('transactions.duplicates.reason.sameDate');
  if (reason === 'same description') return t('transactions.duplicates.reason.sameDescription');
  const within = /^within (\d+) day\(s\)$/.exec(reason);
  if (within) return t('transactions.duplicates.reason.withinDays', { count: Number(within[1]) });
  return reason;
}

/** Router state carried to the new transaction's page (IDs and dates only). */
export interface CreatedState {
  duplicates: DuplicateHint[];
}

export function readCreatedState(state: unknown): DuplicateHint[] {
  if (typeof state !== 'object' || state === null || !('duplicates' in state)) return [];
  const value: unknown = state.duplicates;
  if (!Array.isArray(value)) return [];
  return value.filter(
    (item): item is DuplicateHint =>
      typeof item === 'object' &&
      item !== null &&
      typeof (item as DuplicateHint).transaction_id === 'string' &&
      typeof (item as DuplicateHint).local_date === 'string',
  );
}
