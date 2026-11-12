import { MoneyText } from '@/shared/components/MoneyText';
import type { Account } from '@/shared/finance/types';
import { amountSign } from '@/shared/formatting/money';
import { absDecimal } from '@/shared/formatting/decimal';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';

interface AccountBalanceProps {
  account: Pick<Account, 'balance' | 'is_liability'>;
  size?: 'md' | 'lg';
  align?: 'start' | 'end';
}

/**
 * A tracked balance in words as well as numbers. Credit cards and loans show
 * the amount owed (the API's negative balance) as "Owed", never as a bare
 * negative number; other accounts below zero say so explicitly.
 */
export function AccountBalance({ account, size = 'md', align = 'end' }: AccountBalanceProps) {
  const t = useT();
  const sign = amountSign(account.balance.amount);
  let note: string | null = null;
  let money = account.balance;
  if (account.is_liability) {
    money = { ...account.balance, amount: absDecimal(account.balance.amount) };
    note =
      sign === -1
        ? t('accounts.balance.owed')
        : sign === 1
          ? t('accounts.balance.inCredit')
          : t('accounts.balance.nothingOwed');
  } else if (sign === -1) {
    note = t('accounts.balance.belowZero');
  }
  return (
    <div className={cx('shrink-0', align === 'end' ? 'text-end' : 'text-start')}>
      <MoneyText
        money={money}
        className={cx('block font-semibold text-fg', size === 'lg' ? 'text-3xl' : 'text-base')}
      />
      {note ? <span className="block text-sm text-fg-muted">{note}</span> : null}
    </div>
  );
}
