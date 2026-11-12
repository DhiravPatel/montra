import type { IconName } from '@/shared/components/Icon';
import type { Translate } from '@/shared/i18n/types';
import { transactionTypeLabel } from './labels';
import type { Transaction, TransactionType } from './types';

const typeIcon: Readonly<Record<TransactionType, IconName>> = {
  expense: 'shopping-bag',
  income: 'trending-up',
  transfer: 'arrow-left-right',
  refund: 'undo',
  reimbursement: 'undo',
  adjustment: 'sliders',
  opening_balance: 'wallet',
  group_expense: 'users',
  settlement: 'users',
};

export function transactionIcon(type: TransactionType): IconName {
  return typeIcon[type];
}

/** The best short name for a transaction: merchant, then description, then its type. */
export function transactionTitle(transaction: Transaction, t: Translate): string {
  return (
    transaction.merchant?.name ||
    transaction.description ||
    t(transactionTypeLabel[transaction.type])
  );
}
