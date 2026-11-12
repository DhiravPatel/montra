import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, subscriptionPath } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { SubscriptionInput } from '@/shared/finance/types';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { subscriptionsApi } from '../api';
import { SubscriptionForm } from '../components/SubscriptionForm';
import { emptySubscriptionValues, toSubscriptionInput } from '../formValues';

export function SubscriptionCreatePage() {
  const t = useT();
  useDocumentTitle(t('subscriptions.create.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const user = useCurrentUser();
  const queryClient = useQueryClient();
  const [initialValues] = useState(() =>
    emptySubscriptionValues(user.base_currency, todayInTimeZone(user.timezone)),
  );
  // One key per draft: a retry after a lost response replays instead of adding it twice.
  const idempotency = useIdempotencyKey();
  const create = useMutation({
    mutationFn: (input: SubscriptionInput) => subscriptionsApi.create(input, idempotency.key),
    onSuccess: (subscription) => {
      idempotency.renew();
      queryClient.setQueryData(financeKeys.subscription(subscription.id), subscription);
      void invalidateFinance(queryClient);
    },
  });

  return (
    <>
      <PageHeader
        title={t('subscriptions.create.title')}
        description={t('subscriptions.create.description')}
      />
      <Card>
        <SubscriptionForm
          initialValues={initialValues}
          submitLabel={t('subscriptions.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.subscriptions} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (values, amount) => {
            if (create.isPending) return;
            const subscription = await create.mutateAsync(toSubscriptionInput(values, amount));
            toast.show({
              tone: 'success',
              title: t('subscriptions.create.done'),
              ...(subscription.duplicate_warnings.length > 0
                ? { description: t('subscriptions.create.duplicateHint') }
                : {}),
            });
            void navigate(subscriptionPath(subscription.id));
          }}
        />
      </Card>
    </>
  );
}
