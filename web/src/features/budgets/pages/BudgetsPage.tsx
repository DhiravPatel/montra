import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { useBudgets } from '../api';
import { BudgetAlertsCard } from '../components/BudgetAlertsCard';
import { BudgetListItem } from '../components/BudgetListItem';
import { HelpGuideLink } from '@/shared/help/HelpGuideLink';

/** Budgets with this period's progress, plus budget alerts (spec §4.6). */
export function BudgetsPage() {
  const t = useT();
  useDocumentTitle(t('budgets.title'));
  const [showArchived, setShowArchived] = useState(false);
  const budgets = useBudgets(showArchived);

  let content;
  if (budgets.isPending) {
    content = <LoadingState label={t('budgets.loading')} />;
  } else if (budgets.isError) {
    content = hasErrorCode(budgets.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('budgets.error')}
        error={budgets.error}
        retrying={budgets.isFetching}
        onRetry={() => {
          void budgets.refetch();
        }}
      />
    );
  } else if (budgets.data.length === 0) {
    content = (
      <EmptyState
        icon="pie-chart"
        title={showArchived ? t('budgets.empty.archivedTitle') : t('budgets.empty.title')}
        description={t('budgets.empty.body')}
        action={
          <ButtonLink to={paths.budgetNew}>
            <Icon name="plus" className="size-4" />
            {t('budgets.create.action')}
          </ButtonLink>
        }
      />
    );
  } else {
    content = (
      <ul className="grid gap-4 lg:grid-cols-2">
        {budgets.data.map((budget) => (
          <BudgetListItem key={budget.id} budget={budget} />
        ))}
      </ul>
    );
  }

  return (
    <>
      <PageHeader
        help={<HelpGuideLink guide="budgets" />}
        title={t('budgets.title')}
        description={t('budgets.description')}
        actions={
          <ButtonLink to={paths.budgetNew}>
            <Icon name="plus" className="size-4" />
            {t('budgets.create.action')}
          </ButtonLink>
        }
      />
      <div className="space-y-6">
        <Card
          title={t('budgets.list.title')}
          description={t('budgets.list.description')}
          actions={
            <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 text-sm text-fg">
              <input
                type="checkbox"
                checked={showArchived}
                onChange={(event) => {
                  setShowArchived(event.target.checked);
                }}
                className="size-4 accent-accent"
              />
              {t('budgets.showArchived')}
            </label>
          }
        >
          {content}
        </Card>
        <BudgetAlertsCard />
      </div>
    </>
  );
}
