import { hasErrorCode } from '@/shared/api/errors';
import { Card } from '@/shared/components/Card';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { groupPath } from '@/shared/config/paths';
import { categoriesById } from '@/shared/finance/categories';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { TransactionListItem } from '@/shared/finance/components/TransactionListItem';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { useCategories } from '@/shared/finance/reference';
import type { Budget } from '@/shared/finance/types';
import { useT } from '@/shared/i18n/I18nContext';
import { useBudgetTransactions } from '../api';

interface BudgetTransactionsCardProps {
  budget: Budget;
  /** A date inside the period being looked at ('' = the current period). */
  date: string;
}

/**
 * Exactly the transactions counted in a period, newest first, in cursor
 * pages ("Load more"). Owner only: collaborators see totals, never
 * individual transactions; group budgets count the group's shared expenses,
 * which are listed in the group.
 */
export function BudgetTransactionsCard({ budget, date }: BudgetTransactionsCardProps) {
  const t = useT();
  const owner = budget.access === 'owner';
  const grouped = Boolean(budget.group_id);
  const transactions = useBudgetTransactions(budget.id, date, owner && !grouped);
  const categories = useCategories();
  const byId = categoriesById(categories.data);
  const ownerOnly = <p className="text-sm text-fg-muted">{t('budgets.transactions.ownerOnly')}</p>;
  const groupNote = (
    <p className="text-sm text-fg-muted">
      {t('budgets.transactions.groupBudget')}{' '}
      {budget.group_id ? (
        <TextLink to={groupPath(budget.group_id)}>{t('budgets.transactions.openGroup')}</TextLink>
      ) : null}
    </p>
  );

  let content;
  if (!owner) {
    content = ownerOnly;
  } else if (grouped) {
    content = groupNote;
  } else if (transactions.isPending) {
    content = <LoadingState label={t('budgets.transactions.loading')} />;
  } else if (transactions.isError && !transactions.isFetchNextPageError) {
    if (hasErrorCode(transactions.error, 'FORBIDDEN')) {
      content = ownerOnly;
    } else if (domainRuleCode(transactions.error)?.code === 'group_budget') {
      content = groupNote;
    } else {
      content = (
        <ErrorState
          titleAs="p"
          title={t('budgets.transactions.error')}
          error={transactions.error}
          retrying={transactions.isFetching}
          onRetry={() => {
            void transactions.refetch();
          }}
        />
      );
    }
  } else {
    const items = transactions.data.pages.flatMap((page) => page.items);
    content =
      items.length === 0 ? (
        <EmptyState
          titleAs="p"
          icon="list"
          title={t('budgets.transactions.empty')}
          description={t('budgets.transactions.emptyBody')}
        />
      ) : (
        <>
          <ul className="divide-y divide-line">
            {items.map((transaction) => (
              <TransactionListItem
                key={transaction.id}
                transaction={transaction}
                categories={byId}
              />
            ))}
          </ul>
          <LoadMoreButton
            hasMore={transactions.hasNextPage}
            loading={transactions.isFetchingNextPage}
            failed={transactions.isFetchNextPageError}
            onLoadMore={() => {
              void transactions.fetchNextPage();
            }}
          />
        </>
      );
  }

  return (
    <Card
      title={t('budgets.transactions.title')}
      description={
        date ? t('budgets.transactions.selectedPeriod') : t('budgets.transactions.description')
      }
    >
      {content}
    </Card>
  );
}
