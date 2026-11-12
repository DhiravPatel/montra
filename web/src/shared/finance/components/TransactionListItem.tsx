import type { ReactNode } from 'react';
import { Link } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { transactionPath } from '@/shared/config/paths';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { categoryRefName } from '../categories';
import { transactionStatusLabel, transactionTypeLabel } from '../labels';
import { transactionIcon, transactionTitle } from '../transactionDisplay';
import type { Category, Transaction } from '../types';
import { TransactionAmount } from './TransactionAmount';

interface TransactionListItemProps {
  transaction: Transaction;
  categories: ReadonlyMap<string, Category>;
  showAccount?: boolean;
  /** e.g. a selection checkbox. */
  leading?: ReactNode;
}

export function TransactionListItem({
  transaction,
  categories,
  showAccount = true,
  leading,
}: TransactionListItemProps) {
  const { t, formatLocale } = useI18n();
  const voided = transaction.status === 'voided';
  const typeShown = transaction.type !== 'expense' && transaction.type !== 'income';
  const category = transaction.category
    ? categoryRefName(transaction.category, categories, t)
    : transaction.type === 'expense' || transaction.type === 'income'
      ? t('categories.uncategorized')
      : null;
  const details = [
    formatLocalDate(transaction.local_date, formatLocale),
    category,
    showAccount ? transaction.account_name : null,
  ].filter(Boolean);

  return (
    <li className="flex items-start gap-3 py-3 first:pt-0 last:pb-0">
      {leading}
      <span
        className={cx(
          'mt-0.5 inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted',
          voided && 'opacity-60',
        )}
      >
        <Icon name={transactionIcon(transaction.type)} className="size-4" />
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        <Link
          to={transactionPath(transaction.id)}
          className={cx(
            'font-medium text-fg underline-offset-4 hover:underline',
            voided && 'line-through',
          )}
        >
          {transactionTitle(transaction, t)}
        </Link>
        <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        <div className="flex flex-wrap gap-1.5">
          {typeShown ? (
            <StatusBadge tone="neutral" icon={transactionIcon(transaction.type)}>
              {t(transactionTypeLabel[transaction.type])}
            </StatusBadge>
          ) : null}
          {transaction.status !== 'posted' ? (
            <StatusBadge
              tone={voided ? 'neutral' : 'warning'}
              icon={voided ? 'ban' : transaction.status === 'draft' ? 'file-text' : 'clock'}
            >
              {t(transactionStatusLabel[transaction.status])}
            </StatusBadge>
          ) : null}
          {transaction.tags.map((tag) => (
            <StatusBadge key={tag.id} tone="neutral" icon="tag">
              {tag.name}
            </StatusBadge>
          ))}
          {transaction.attachment_count > 0 ? (
            <StatusBadge tone="neutral" icon="paperclip">
              {t('transactions.attachmentsCount', { count: transaction.attachment_count })}
            </StatusBadge>
          ) : null}
        </div>
      </div>
      <TransactionAmount transaction={transaction} className="pt-0.5 text-end" />
    </li>
  );
}
