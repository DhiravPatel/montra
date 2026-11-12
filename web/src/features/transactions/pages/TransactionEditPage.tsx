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
import { paths, transactionPath } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import { useAccounts } from '@/shared/finance/reference';
import type { TransactionPatch } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { transactionsApi, useTransaction } from '../api';
import { TransactionForm } from '../components/TransactionForm';
import { toTransactionPatch, transactionToValues } from '../formValues';

export function TransactionEditPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('transactions.edit.title'));
  const { transactionId = '' } = useParams();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const query = useTransaction(transactionId);
  const accounts = useAccounts(true);
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (patch: TransactionPatch) => transactionsApi.update(transactionId, patch),
    onSuccess: (transaction) => {
      queryClient.setQueryData(financeKeys.transaction(transaction.id), transaction);
      void invalidateFinance(queryClient);
    },
  });

  if (query.isPending) return <LoadingState label={t('transactions.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="list"
          title={t('transactions.detail.notFound')}
          description={t('transactions.detail.notFoundBody')}
          action={<ButtonLink to={paths.transactions}>{t('transactions.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('transactions.detail.error')}
        error={query.error}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const transaction = query.data;
  if (!transaction.owned || transaction.status === 'voided') {
    return (
      <PermissionDenied
        titleAs="h2"
        title={t('transactions.edit.unavailableTitle')}
        description={
          transaction.status === 'voided'
            ? t('transactions.edit.voidedBody')
            : t('transactions.edit.sharedBody')
        }
      />
    );
  }
  const currentAccount =
    accounts.data?.find((account) => account.id === transaction.account_id) ?? null;

  return (
    <>
      <PageHeader
        title={t('transactions.edit.title')}
        description={t('transactions.edit.description')}
      />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-6" title={t('finance.conflict.title')}>
          {t('finance.conflict.body')}
        </Alert>
      ) : null}
      <Card>
        <TransactionForm
          key={transaction.version}
          mode="edit"
          initialValues={transactionToValues(transaction, formatLocale)}
          currentStatus={transaction.status}
          lockedAccount={currentAccount}
          submitLabel={t('transactions.edit.submit')}
          secondaryAction={
            <ButtonLink to={transactionPath(transaction.id)} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onError={(error) => {
            if (!hasErrorCode(error, 'VERSION_CONFLICT')) return false;
            setConflict(true);
            void query.refetch();
            return true;
          }}
          onSubmit={async (result) => {
            if (update.isPending) return;
            setConflict(false);
            const patch = toTransactionPatch(transaction, result);
            if (Object.keys(patch).length > 1) await update.mutateAsync(patch);
            toast.show({ tone: 'success', title: t('transactions.edit.done') });
            void navigate(transactionPath(transaction.id));
          }}
        />
      </Card>
    </>
  );
}
