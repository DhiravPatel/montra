import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useCurrencies } from '@/shared/currency/api';
import { paths, transactionPath } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import { useAccounts, writableAccounts } from '@/shared/finance/reference';
import type { TransferInput } from '@/shared/finance/types';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { transactionsApi } from '../api';
import { TransferForm } from '../components/TransferForm';

/** Transfer between your own accounts (`/transfers/new?from_account_id=…`). */
export function TransferCreatePage() {
  const t = useT();
  useDocumentTitle(t('transfers.create.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const user = useCurrentUser();
  const [params] = useSearchParams();
  const accounts = useAccounts();
  const currencies = useCurrencies();
  const idempotency = useIdempotencyKey();
  const [today] = useState(() => todayInTimeZone(user.timezone));
  const create = useMutation({
    mutationFn: (body: TransferInput) => transactionsApi.createTransfer(body, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });

  let content;
  if (accounts.isError || currencies.isError) {
    content = (
      <ErrorState
        title={t('transactions.form.loadFailed')}
        error={accounts.error ?? currencies.error}
        onRetry={() => {
          void accounts.refetch();
          void currencies.refetch();
        }}
      />
    );
  } else if (accounts.isPending || currencies.isPending) {
    content = <LoadingState label={t('transactions.form.loading')} />;
  } else {
    const writable = writableAccounts(accounts.data);
    const wanted = params.get('from_account_id') ?? '';
    content = (
      <TransferForm
        accounts={writable}
        initialFromId={writable.some((account) => account.id === wanted) ? wanted : ''}
        today={today}
        submitting={create.isPending}
        secondaryAction={
          <ButtonLink to={paths.transactions} variant="ghost">
            {t('common.cancel')}
          </ButtonLink>
        }
        onSubmit={async (body) => {
          const transfer = await create.mutateAsync(body);
          toast.show({ tone: 'success', title: t('transfers.create.done') });
          void navigate(transactionPath(transfer.from_transaction_id));
        }}
      />
    );
  }

  return (
    <>
      <PageHeader
        title={t('transfers.create.title')}
        description={t('transfers.create.description')}
      />
      <Card>{content}</Card>
    </>
  );
}
