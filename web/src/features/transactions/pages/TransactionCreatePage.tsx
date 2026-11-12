import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, transactionPath } from '@/shared/config/paths';
import {
  useAccounts,
  usePaymentMethods,
  usePreferences,
  writableAccounts,
} from '@/shared/finance/reference';
import type { DuplicateHint } from '@/shared/finance/types';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { DuplicateHints } from '../components/DuplicateHints';
import { TransactionForm } from '../components/TransactionForm';
import type { CreatedState } from '../duplicates';
import { emptyTransactionValues, toTransactionInput } from '../formValues';
import { useCreateTransaction } from '../useCreateTransaction';

/** Add an expense or income (`/transactions/new?type=income&account_id=…`). */
export function TransactionCreatePage() {
  const t = useT();
  useDocumentTitle(t('transactions.create.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const user = useCurrentUser();
  const [params] = useSearchParams();
  const accounts = useAccounts();
  const preferences = usePreferences();
  const methods = usePaymentMethods();
  const create = useCreateTransaction();
  const [today] = useState(() => todayInTimeZone(user.timezone));
  const [recentDuplicates, setRecentDuplicates] = useState<DuplicateHint[]>([]);

  const ready = accounts.isSuccess && methods.isSuccess && !preferences.isPending;
  const header = (
    <PageHeader
      title={t('transactions.create.title')}
      description={t('transactions.create.description')}
    />
  );
  if (!ready && !accounts.isError && !methods.isError) {
    return (
      <>
        {header}
        <LoadingState label={t('transactions.form.loading')} />
      </>
    );
  }

  const writable = writableAccounts(accounts.data);
  const wanted = params.get('account_id') ?? preferences.data?.default_account_id ?? '';
  const accountId = writable.some((account) => account.id === wanted)
    ? wanted
    : writable.length === 1
      ? (writable[0]?.id ?? '')
      : '';
  const type = params.get('type') === 'income' ? 'income' : 'expense';
  const defaultMethod =
    type === 'expense'
      ? (methods.data?.find((method) => method.is_default && !method.archived_at)?.id ?? '')
      : '';

  return (
    <>
      {header}
      {recentDuplicates.length > 0 ? (
        <div className="mb-6">
          <DuplicateHints hints={recentDuplicates} />
        </div>
      ) : null}
      <Card>
        <TransactionForm
          mode="create"
          initialValues={emptyTransactionValues(type, accountId, today, defaultMethod)}
          submitLabel={t('transactions.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.transactions} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (result, intent) => {
            if (create.isPending) return;
            const created = await create.mutateAsync(toTransactionInput(result));
            const duplicates = created.possible_duplicates;
            if (intent === 'another') {
              setRecentDuplicates(duplicates);
              toast.show({ tone: 'success', title: t('transactions.create.done') });
              return;
            }
            toast.show({ tone: 'success', title: t('transactions.create.done') });
            const state: CreatedState = { duplicates };
            void navigate(transactionPath(created.transaction.id), { state });
          }}
        />
      </Card>
    </>
  );
}
