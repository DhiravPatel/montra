import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, recurringPath } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import type { RecurringRuleInput } from '@/shared/finance/types';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { planningApi } from '../api';
import { BackLink } from '../components/BackLink';
import { RecurringRuleForm } from '../components/RecurringRuleForm';
import { emptyRuleValues } from '../formValues';

export function RecurringRuleCreatePage() {
  const t = useT();
  useDocumentTitle(t('recurring.create.title'));
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [initialValues] = useState(() =>
    emptyRuleValues(user.base_currency, todayInTimeZone(user.timezone)),
  );
  // One key per draft: a retry after a lost response replays the first result
  // instead of adding the schedule twice. A new key only after a success.
  const idempotency = useIdempotencyKey();
  const create = useMutation({
    mutationFn: (input: RecurringRuleInput) => planningApi.createRule(input, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      return invalidateFinance(queryClient);
    },
  });

  return (
    <>
      <BackLink to={paths.recurring} label={t('recurring.backToList')} />
      <PageHeader
        title={t('recurring.create.title')}
        description={t('recurring.create.description')}
      />
      <Card>
        <RecurringRuleForm
          mode="create"
          initialValues={initialValues}
          submitLabel={t('recurring.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.recurring} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (input) => {
            if (create.isPending) return;
            const rule = await create.mutateAsync(input);
            toast.show({ tone: 'success', title: t('recurring.create.done') });
            void navigate(recurringPath(rule.id));
          }}
        />
      </Card>
    </>
  );
}
