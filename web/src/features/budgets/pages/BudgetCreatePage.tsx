import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { useToast } from '@/shared/components/toast/ToastContext';
import { budgetPath, paths } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { BudgetInput } from '@/shared/finance/types';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { budgetsApi } from '../api';
import { BudgetForm } from '../components/BudgetForm';
import { newBudgetValues, toBudgetInput } from '../formValues';

export function BudgetCreatePage() {
  const t = useT();
  useDocumentTitle(t('budgets.create.title'));
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const create = useMutation({
    mutationFn: (body: BudgetInput) => budgetsApi.create(body),
    onSuccess: (budget) => {
      queryClient.setQueryData(financeKeys.budget(budget.id), budget);
      void invalidateFinance(queryClient);
    },
  });

  return (
    <>
      <PageHeader title={t('budgets.create.title')} description={t('budgets.create.description')} />
      <Card>
        <BudgetForm
          mode="create"
          initialValues={newBudgetValues(user.base_currency, todayInTimeZone(user.timezone))}
          submitLabel={t('budgets.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.budgets} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (values, amounts) => {
            if (create.isPending) return;
            const budget = await create.mutateAsync(toBudgetInput(values, amounts));
            toast.show({ tone: 'success', title: t('budgets.create.done') });
            void navigate(budgetPath(budget.id));
          }}
        />
      </Card>
    </>
  );
}
