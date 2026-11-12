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
import { billPath, paths } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { BillPatch } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { planningApi, useBill } from '../api';
import { BackLink } from '../components/BackLink';
import { BillForm } from '../components/BillForm';
import { billToValues } from '../formValues';
import { isEmptyPatch } from '../patches';

export function BillEditPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('bills.edit.title'));
  const { billId = '' } = useParams();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const query = useBill(billId);
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (patch: BillPatch) => planningApi.updateBill(billId, patch),
    onSuccess: (bill) => {
      queryClient.setQueryData(financeKeys.bill(bill.id), bill);
      void invalidateFinance(queryClient);
    },
  });

  if (query.isPending) return <LoadingState label={t('bills.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="receipt"
          title={t('bills.detail.notFound')}
          description={t('bills.detail.notFoundBody')}
          action={<ButtonLink to={paths.bills}>{t('bills.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('bills.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const bill = query.data;
  if (!bill.owned) {
    return (
      <PermissionDenied
        titleAs="h2"
        title={t('bills.readOnlyTitle')}
        description={t('bills.readOnly')}
      />
    );
  }

  return (
    <>
      <BackLink to={billPath(bill.id)} label={t('bills.backToBill')} />
      <PageHeader title={t('bills.edit.title')} description={bill.name} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-6" title={t('finance.conflict.title')}>
          {t('finance.conflict.body')}
        </Alert>
      ) : null}
      <Card>
        <BillForm
          // Remount with the latest values after a version conflict reload.
          key={bill.version}
          mode="edit"
          bill={bill}
          initialValues={billToValues(bill, formatLocale)}
          submitLabel={t('bills.edit.submit')}
          secondaryAction={
            <ButtonLink to={billPath(bill.id)} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onError={(error) => {
            if (!hasErrorCode(error, 'VERSION_CONFLICT')) return false;
            setConflict(true);
            void query.refetch();
            return true;
          }}
          onSubmit={async (patch) => {
            if (update.isPending) return;
            setConflict(false);
            if (isEmptyPatch(patch)) {
              toast.show({ tone: 'info', title: t('bills.edit.noChanges') });
              void navigate(billPath(bill.id));
              return;
            }
            await update.mutateAsync(patch);
            toast.show({ tone: 'success', title: t('bills.edit.done') });
            void navigate(billPath(bill.id));
          }}
        />
      </Card>
    </>
  );
}
