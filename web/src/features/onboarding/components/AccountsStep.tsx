import { useState } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { AccountBalance } from '@/features/accounts/components/AccountBalance';
import { AccountForm } from '@/features/accounts/components/AccountForm';
import { emptyAccountValues } from '@/features/accounts/formValues';
import { toAccountInput, useCreateAccount } from '@/features/accounts/useCreateAccount';
import { accountLabel } from '@/shared/finance/labels';
import { useAccounts } from '@/shared/finance/reference';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { useT } from '@/shared/i18n/I18nContext';
import { StepActions } from './StepActions';
import type { StepProps } from './types';
import { usePreferencePatch } from './usePreferencePatch';

/** Optional first accounts: cash, bank or card, tracked manually (bank linking is never required). */
export function AccountsStep({ preferences, onNext, onBack, advancing }: StepProps) {
  const t = useT();
  const user = useCurrentUser();
  const announce = useAnnounce();
  const accounts = useAccounts();
  const create = useCreateAccount();
  const setDefault = usePreferencePatch();
  const [formKey, setFormKey] = useState(0);
  const [today] = useState(() => todayInTimeZone(user.timezone));

  if (accounts.isPending) return <LoadingState label={t('accounts.list.loading')} />;
  if (accounts.isError) {
    return (
      <ErrorState
        title={t('accounts.list.error')}
        error={accounts.error}
        onRetry={() => {
          void accounts.refetch();
        }}
      />
    );
  }
  const list = accounts.data;

  return (
    <div className="space-y-6">
      <p className="text-fg">{t('onboarding.accounts.body')}</p>
      <Alert tone="info">{t('onboarding.accounts.noBank')}</Alert>
      {list.length > 0 ? (
        <section aria-labelledby="onboarding-accounts-added">
          <h3 id="onboarding-accounts-added" className="mb-2 font-semibold text-fg">
            {t('onboarding.accounts.added')}
          </h3>
          <ul className="divide-y divide-line rounded-lg border border-line">
            {list.map((account) => (
              <li key={account.id} className="flex items-center gap-3 p-3">
                <Icon name="check-circle" className="text-success" />
                <div className="min-w-0 flex-1">
                  <p className="font-medium text-fg">{account.name}</p>
                  <p className="text-sm text-fg-muted">{t(accountLabel(account))}</p>
                </div>
                <AccountBalance account={account} />
              </li>
            ))}
          </ul>
        </section>
      ) : null}
      <section
        aria-labelledby="onboarding-accounts-form"
        className="rounded-lg border border-line p-4 sm:p-5"
      >
        <h3 id="onboarding-accounts-form" className="mb-4 font-semibold text-fg">
          {list.length > 0
            ? t('onboarding.accounts.addAnother')
            : t('onboarding.accounts.addFirst')}
        </h3>
        <AccountForm
          key={formKey}
          mode="create"
          initialValues={emptyAccountValues(preferences.base_currency, today)}
          submitLabel={t('accounts.create.submit')}
          onSubmit={async (result) => {
            if (create.isPending) return;
            const account = await create.mutateAsync(toAccountInput(result));
            announce(t('onboarding.accounts.created', { name: account.name }));
            if (!preferences.default_account_id && list.length === 0) {
              // The first account becomes the default for new transactions (it can be changed later).
              setDefault.mutate({ default_account_id: account.id });
            }
            setFormKey((key) => key + 1);
          }}
        />
      </section>
      <StepActions
        onBack={onBack}
        onSkip={
          list.length === 0
            ? () => {
                onNext('skipped');
              }
            : undefined
        }
        primaryLabel={t('common.continue')}
        primaryDisabled={list.length === 0}
        onPrimary={() => {
          onNext('completed');
        }}
        pending={advancing}
      />
    </div>
  );
}
