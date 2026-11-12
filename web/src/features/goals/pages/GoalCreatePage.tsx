import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { goalPath, paths } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { GoalInput } from '@/shared/finance/types';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { goalsApi } from '../api';
import { GoalForm } from '../components/GoalForm';
import { emptyGoalValues, toGoalInput } from '../formValues';

export function GoalCreatePage() {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const user = useCurrentUser();
  const queryClient = useQueryClient();
  useDocumentTitle(t('goals.create.title'));
  const [initialValues] = useState(() =>
    emptyGoalValues(user.base_currency, todayInTimeZone(user.timezone)),
  );
  // One key per draft: a retry after a lost response replays the first result
  // instead of creating the goal twice; a new key only after a success.
  const idempotency = useIdempotencyKey();
  const create = useMutation({
    mutationFn: (input: GoalInput) => goalsApi.create(input, idempotency.key),
    onSuccess: (goal) => {
      idempotency.renew();
      queryClient.setQueryData(financeKeys.goal(goal.id), goal);
      void invalidateFinance(queryClient);
    },
  });

  return (
    <>
      <p className="mb-2">
        <TextLink to={paths.goals}>
          <Icon name="arrow-left" className="me-1 inline size-4" />
          {t('goals.backToList')}
        </TextLink>
      </p>
      <PageHeader title={t('goals.create.title')} description={t('goals.create.description')} />
      <Card>
        <GoalForm
          mode="create"
          initialValues={initialValues}
          submitLabel={t('goals.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.goals} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (values, amounts) => {
            if (create.isPending) return;
            const goal = await create.mutateAsync(toGoalInput(values, amounts));
            toast.show({ tone: 'success', title: t('goals.create.done') });
            void navigate(goalPath(goal.id));
          }}
        />
      </Card>
    </>
  );
}
