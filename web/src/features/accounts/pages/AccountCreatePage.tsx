import { useState } from 'react';
import { useNavigate } from 'react-router';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { accountPath, paths } from '@/shared/config/paths';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { AccountForm } from '../components/AccountForm';
import { emptyAccountValues } from '../formValues';
import { AccountsSubNav } from '../components/AccountsSubNav';
import { toAccountInput, useCreateAccount } from '../useCreateAccount';

export function AccountCreatePage() {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const user = useCurrentUser();
  useDocumentTitle(t('accounts.create.title'));
  const [initialValues] = useState(() =>
    emptyAccountValues(user.base_currency, todayInTimeZone(user.timezone)),
  );
  const create = useCreateAccount();

  return (
    <>
      <PageHeader
        title={t('accounts.create.title')}
        description={t('accounts.create.description')}
      />
      <AccountsSubNav />
      <Card>
        <AccountForm
          mode="create"
          initialValues={initialValues}
          submitLabel={t('accounts.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.accounts} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (result) => {
            if (create.isPending) return;
            const account = await create.mutateAsync(toAccountInput(result));
            toast.show({ tone: 'success', title: t('accounts.create.done') });
            void navigate(accountPath(account.id));
          }}
        />
      </Card>
    </>
  );
}
