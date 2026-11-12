import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { EmptyState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { categoriesById } from '@/shared/finance/categories';
import { TransactionListItem } from '@/shared/finance/components/TransactionListItem';
import { useCategories } from '@/shared/finance/reference';
import { useT } from '@/shared/i18n/I18nContext';
import { WidgetCard } from '../components/WidgetCard';
import type { WidgetProps } from './types';

/** The latest entries across your accounts (not limited to the period). */
export function RecentTransactionsWidget({ summary, title }: WidgetProps) {
  const t = useT();
  const categories = useCategories(true);
  const byId = categoriesById(categories.data);
  const recent = summary.recent_transactions;
  return (
    <WidgetCard
      title={title}
      scopeLabel={t('dashboard.latestEntries')}
      generatedAt={summary.generated_at}
      drillDown={{ to: paths.transactions, label: t('dashboard.viewAll') }}
    >
      {recent.length === 0 ? (
        <EmptyState
          icon="list"
          title={t('transactions.list.empty.title')}
          description={t('transactions.list.empty.body')}
          action={
            <ButtonLink to={paths.transactionNew}>
              <Icon name="plus" className="size-4" />
              {t('transactions.add')}
            </ButtonLink>
          }
        />
      ) : (
        <ul className="divide-y divide-line">
          {recent.map((transaction) => (
            <TransactionListItem key={transaction.id} transaction={transaction} categories={byId} />
          ))}
        </ul>
      )}
    </WidgetCard>
  );
}
