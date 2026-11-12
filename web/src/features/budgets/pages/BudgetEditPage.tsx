import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { budgetPath, paths } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { BudgetPatch } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { budgetsApi, useBudget } from '../api';
import { BudgetForm } from '../components/BudgetForm';
import { budgetToValues, toBudgetPatch } from '../formValues';

export function BudgetEditPage() {
  const { t, formatLocale } = useI18n();
  const { budgetId = '' } = useParams();
  useDocumentTitle(t('budgets.edit.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const query = useBudget(budgetId);
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (body: BudgetPatch) => budgetsApi.update(budgetId, body),
    onSuccess: (budget) => {
      queryClient.setQueryData(financeKeys.budget(budget.id), budget);
      void invalidateFinance(queryClient);
    },
  });

  if (query.isPending) return <LoadingState label={t('budgets.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="pie-chart"
          title={t('budgets.notFound')}
          description={t('budgets.notFoundBody')}
          action={<ButtonLink to={paths.budgets}>{t('budgets.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('budgets.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const budget = query.data;
  if (budget.access === 'viewer') {
    return (
      <PermissionDenied
        titleAs="h2"
        title={t('budgets.readOnlyTitle')}
        description={t('budgets.readOnlyBody')}
      />
    );
  }
  if (budget.status === 'archived') {
    return (
      <EmptyState
        titleAs="h2"
        icon="archive"
        title={t('budgets.edit.archivedTitle')}
        description={t('budgets.edit.archivedBody')}
        action={
          <ButtonLink to={budgetPath(budget.id)}>{t('budgets.edit.backToBudget')}</ButtonLink>
        }
      />
    );
  }

  return (
    <>
      <PageHeader title={t('budgets.edit.title')} description={budget.name} />
      <div className="mb-6 space-y-4">
        {conflict ? (
          <Alert tone="warning" live="assertive" title={t('finance.conflict.title')}>
            {t('budgets.edit.conflict')}
          </Alert>
        ) : null}
        <Alert tone="info">{t('budgets.edit.appliesFrom')}</Alert>
      </div>
      <Card>
        <BudgetForm
          // Remount with the latest values after a version conflict reload.
          key={budget.version}
          mode="edit"
          access={budget.access}
          initialValues={budgetToValues(budget, formatLocale)}
          submitLabel={t('budgets.edit.submit')}
          secondaryAction={
            <ButtonLink to={budgetPath(budget.id)} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onError={(error) => {
            if (!hasErrorCode(error, 'VERSION_CONFLICT')) return false;
            setConflict(true);
            void query.refetch();
            return true;
          }}
          onSubmit={async (values, amounts) => {
            if (update.isPending) return;
            setConflict(false);
            // Only what changed is sent (with the version); the budget keeps its time zone.
            const patch = toBudgetPatch(values, amounts, budget);
            if (!patch) {
              toast.show({ tone: 'info', title: t('budgets.edit.noChanges') });
              void navigate(budgetPath(budget.id));
              return;
            }
            await update.mutateAsync(patch);
            toast.show({ tone: 'success', title: t('budgets.edit.done') });
            void navigate(budgetPath(budget.id));
          }}
        />
      </Card>
    </>
  );
}
