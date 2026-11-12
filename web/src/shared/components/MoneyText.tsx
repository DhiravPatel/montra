import type { Money } from '@/shared/api/types';
import { amountSign, formatMoney, type FormatMoneyOptions } from '@/shared/formatting/money';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';

interface MoneyTextProps extends FormatMoneyOptions {
  money: Pick<Money, 'amount' | 'currency'>;
  /**
   * `signed` adds color to negative/positive amounts in addition to the
   * explicit sign, which is always present (never color alone).
   */
  emphasis?: 'none' | 'signed';
  className?: string;
}

/** Displays an exact API money value in the user's locale. */
export function MoneyText({ money, emphasis = 'none', className, ...options }: MoneyTextProps) {
  const { formatLocale } = useI18n();
  const signDisplay = options.signDisplay ?? (emphasis === 'signed' ? 'exceptZero' : 'auto');
  let text: string;
  try {
    text = formatMoney(money.amount, money.currency, formatLocale, { ...options, signDisplay });
  } catch {
    text = `${money.amount} ${money.currency}`; // never hide a value because formatting failed
  }
  const sign = amountSign(money.amount);
  return (
    <data
      value={money.amount}
      className={cx(
        'tabular-nums',
        emphasis === 'signed' && sign === -1 && 'text-danger',
        emphasis === 'signed' && sign === 1 && 'text-success',
        className,
      )}
    >
      {text}
    </data>
  );
}
