import { useCallback } from 'react';
import type { Money } from '@/shared/api/types';
import { useI18n } from '@/shared/i18n/I18nContext';
import { formatMoney, type FormatMoneyOptions } from './money';

/**
 * Formats API money as a string for sentences and accessible summaries
 * (use <MoneyText> to show amounts on their own). Never hides a value.
 */
export function useFormatMoney() {
  const { formatLocale } = useI18n();
  return useCallback(
    (money: Pick<Money, 'amount' | 'currency'>, options?: FormatMoneyOptions) => {
      try {
        return formatMoney(money.amount, money.currency, formatLocale, options);
      } catch {
        return `${money.amount} ${money.currency}`;
      }
    },
    [formatLocale],
  );
}
