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
import { paths, subscriptionPath } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { SubscriptionPatch } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { subscriptionsApi, useSubscription } from '../api';
import { SubscriptionForm } from '../components/SubscriptionForm';
import { subscriptionToValues, toSubscriptionPatch } from '../formValues';

export function SubscriptionEditPage() {
  const { t, formatLocale } = useI18n();
  const { subscriptionId = '' } = useParams();
  useDocumentTitle(t('subscriptions.edit.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const query = useSubscription(subscriptionId);
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (patch: SubscriptionPatch) => subscriptionsApi.update(subscriptionId, patch),
    onSuccess: (subscription) => {
      queryClient.setQueryData(financeKeys.subscription(subscription.id), subscription);
      void invalidateFinance(queryClient);
    },
  });

  if (query.isPending) return <LoadingState label={t('subscriptions.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="repeat"
          title={t('subscriptions.detail.notFound')}
          description={t('subscriptions.detail.notFoundBody')}
          action={<ButtonLink to={paths.subscriptions}>{t('subscriptions.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('subscriptions.detail.error')}
        error={query.error}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const subscription = query.data;
  if (!subscription.owned) {
    return (
      <PermissionDenied
        titleAs="h2"
        title={t('subscriptions.readOnly.title')}
        description={t('subscriptions.readOnly.body')}
      />
    );
  }

  return (
    <>
      <PageHeader title={t('subscriptions.edit.title')} description={subscription.name} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-6" title={t('finance.conflict.title')}>
          {t('subscriptions.conflict')}
        </Alert>
      ) : null}
      <Alert tone="info" className="mb-6">
        {t('subscriptions.edit.priceHistoryNote')}
      </Alert>
      <Card>
        <SubscriptionForm
          // Remount with the latest values after a version conflict reload.
          key={subscription.version}
          initialValues={subscriptionToValues(subscription, formatLocale)}
          existing={subscription}
          submitLabel={t('common.save')}
          secondaryAction={
            <ButtonLink to={subscriptionPath(subscription.id)} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onError={(error) => {
            if (!hasErrorCode(error, 'VERSION_CONFLICT')) return false;
            setConflict(true);
            void query.refetch();
            return true;
          }}
          onSubmit={async (values, amount) => {
            if (update.isPending) return;
            setConflict(false);
            // Only what changed is sent (with the version on screen).
            await update.mutateAsync(toSubscriptionPatch(values, amount, subscription));
            toast.show({ tone: 'success', title: t('subscriptions.edit.done') });
            void navigate(subscriptionPath(subscription.id));
          }}
        />
      </Card>
    </>
  );
}
