import { MoneyText } from '@/shared/components/MoneyText';
import { negateDecimal } from '@/shared/formatting/decimal';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import type { Transaction } from '../types';

interface TransactionAmountProps {
  transaction: Pick<Transaction, 'amount' | 'direction' | 'status'>;
  className?: string;
}

/**
 * A transaction amount with its direction spelled out: money in shows "+"
 * (and the success color), money out shows "−". The sign and the hidden
 * "Money in/out" label carry the meaning; color only reinforces it.
 */
export function TransactionAmount({ transaction, className }: TransactionAmountProps) {
  const t = useT();
  const inflow = transaction.direction === 'inflow';
  const voided = transaction.status === 'voided';
  const amount = inflow ? transaction.amount.amount : negateDecimal(transaction.amount.amount);
  return (
    <span className={cx('whitespace-nowrap font-medium', voided && 'line-through', className)}>
      <span className="sr-only">
        {t(inflow ? 'finance.direction.inflow' : 'finance.direction.outflow')}:{' '}
      </span>
      <MoneyText
        money={{ amount, currency: transaction.amount.currency }}
        signDisplay="exceptZero"
        className={inflow && !voided ? 'text-success' : undefined}
      />
    </span>
  );
}
