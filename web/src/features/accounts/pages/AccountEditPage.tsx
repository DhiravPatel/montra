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
import { accountPath, paths } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { AccountPatch } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { accountsApi, useAccount } from '../api';
import { AccountForm } from '../components/AccountForm';
import { accountToValues } from '../formValues';
import { toAccountPatch } from '../patch';

export function AccountEditPage() {
  const { t, formatLocale } = useI18n();
  const { accountId = '' } = useParams();
  useDocumentTitle(t('accounts.edit.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const query = useAccount(accountId);
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (patch: AccountPatch) => accountsApi.update(accountId, patch),
    onSuccess: (account) => {
      queryClient.setQueryData(financeKeys.account(account.id), account);
      void invalidateFinance(queryClient);
    },
  });

  if (query.isPending) return <LoadingState label={t('accounts.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="wallet"
          title={t('accounts.detail.notFound')}
          description={t('accounts.detail.notFoundBody')}
          action={<ButtonLink to={paths.accounts}>{t('accounts.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('accounts.detail.error')}
        error={query.error}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const account = query.data;
  if (!account.owned) {
    return (
      <PermissionDenied
        titleAs="h2"
        title={t('accounts.detail.readOnlyTitle')}
        description={t('accounts.detail.readOnlyBody')}
      />
    );
  }

  return (
    <>
      <PageHeader title={t('accounts.edit.title')} description={account.name} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-6" title={t('finance.conflict.title')}>
          {t('finance.conflict.body')}
        </Alert>
      ) : null}
      <Card>
        <AccountForm
          // Remount with the latest values after a version conflict reload.
          key={account.version}
          mode="edit"
          lockedType
          initialValues={accountToValues(account, formatLocale)}
          submitLabel={t('accounts.edit.submit')}
          secondaryAction={
            <ButtonLink to={accountPath(account.id)} variant="ghost">
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
            const patch = toAccountPatch(account, result);
            setConflict(false);
            if (Object.keys(patch).length > 1) await update.mutateAsync(patch);
            toast.show({ tone: 'success', title: t('accounts.edit.done') });
            void navigate(accountPath(account.id));
          }}
        />
      </Card>
    </>
  );
}
