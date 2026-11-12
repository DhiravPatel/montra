import { useState } from 'react';
import { Link } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { accountPath, paths } from '@/shared/config/paths';
import {
  ACCOUNT_TYPES,
  accountIcon,
  accountTypeGroupLabel,
  isAccountType,
} from '@/shared/finance/labels';
import { useAccounts } from '@/shared/finance/reference';
import type { Account, AccountType } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { useAccountTotals } from '../api';
import { AccountBalance } from '../components/AccountBalance';
import { AccountsSubNav } from '../components/AccountsSubNav';
import { AccountStatusBadges } from '../components/AccountStatusBadges';

function groupAccounts(accounts: readonly Account[]): { type: AccountType; accounts: Account[] }[] {
  const sorted = [...accounts].sort(
    (a, b) => a.display_order - b.display_order || a.name.localeCompare(b.name),
  );
  return ACCOUNT_TYPES.map((type) => ({
    type,
    accounts: sorted.filter((account) =>
      isAccountType(account.account_type) ? account.account_type === type : type === 'custom',
    ),
  })).filter((group) => group.accounts.length > 0);
}

function AccountRow({ account }: { account: Account }) {
  const t = useT();
  const details = [
    account.institution_label,
    account.masked_number ? `•••• ${account.masked_number}` : null,
    account.currency,
  ].filter(Boolean);
  return (
    <li className="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
      <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name={accountIcon(account)} />
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        <Link
          to={accountPath(account.id)}
          className="font-medium text-fg underline-offset-4 hover:underline"
        >
          {account.name}
        </Link>
        <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        <AccountStatusBadges account={account} />
      </div>
      <AccountBalance account={account} />
      <span className="sr-only">{t('accounts.list.trackedNote')}</span>
    </li>
  );
}

function AccountsSkeleton() {
  return (
    <ul className="space-y-4" aria-hidden="true">
      {[0, 1, 2].map((key) => (
        <li key={key} className="flex items-center gap-3">
          <Skeleton className="size-10" />
          <div className="flex-1 space-y-2">
            <Skeleton className="h-4 w-1/3" />
            <Skeleton className="h-3 w-1/2" />
          </div>
          <Skeleton className="h-5 w-24" />
        </li>
      ))}
    </ul>
  );
}

function TotalsCard() {
  const t = useT();
  const totals = useAccountTotals();
  const rows = totals.data?.totals ?? [];
  if (rows.length === 0) return null;
  return (
    <Card title={t('accounts.totals.title')} description={t('accounts.totals.description')}>
      <ul className="grid gap-4 sm:grid-cols-2">
        {rows.map((total) => (
          <li key={total.currency} className="rounded-lg border border-line p-4">
            <p className="text-sm font-medium text-fg-muted">
              {t('accounts.totals.currency', { currency: total.currency })}
            </p>
            <dl className="mt-2 space-y-1 text-sm">
              <div className="flex justify-between gap-3">
                <dt className="text-fg-muted">{t('accounts.totals.netWorth')}</dt>
                <dd>
                  <MoneyText money={total.net_worth} className="text-lg font-semibold" />
                </dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-fg-muted">{t('accounts.totals.assets')}</dt>
                <dd>
                  <MoneyText money={total.assets} />
                </dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-fg-muted">{t('accounts.totals.liabilities')}</dt>
                <dd>
                  <MoneyText money={total.liabilities} />
                </dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-fg-muted">{t('accounts.totals.count')}</dt>
                <dd className="tabular-nums">{total.account_count}</dd>
              </div>
            </dl>
          </li>
        ))}
      </ul>
    </Card>
  );
}

/** Accounts grouped by type with ledger balances (spec §4.3, §20B.4). */
export function AccountsPage() {
  const t = useT();
  useDocumentTitle(t('accounts.title'));
  const [showArchived, setShowArchived] = useState(false);
  const accounts = useAccounts(showArchived);

  let content;
  if (accounts.isPending) {
    content = (
      <LoadingState label={t('accounts.list.loading')}>
        <AccountsSkeleton />
      </LoadingState>
    );
  } else if (accounts.isError) {
    content = hasErrorCode(accounts.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('accounts.list.error')}
        error={accounts.error}
        retrying={accounts.isFetching}
        onRetry={() => {
          void accounts.refetch();
        }}
      />
    );
  } else if (accounts.data.length === 0) {
    content = (
      <EmptyState
        icon="wallet"
        title={showArchived ? t('accounts.list.emptyArchived') : t('accounts.list.empty.title')}
        description={t('accounts.list.empty.body')}
        action={
          <ButtonLink to={paths.accountNew}>
            <Icon name="plus" className="size-4" />
            {t('accounts.add')}
          </ButtonLink>
        }
      />
    );
  } else {
    content = (
      <div className="space-y-8">
        {groupAccounts(accounts.data).map((group) => (
          <section key={group.type} aria-labelledby={`accounts-group-${group.type}`}>
            <h3
              id={`accounts-group-${group.type}`}
              className="mb-3 text-sm font-semibold uppercase tracking-wide text-fg-muted"
            >
              {t(accountTypeGroupLabel[group.type])}
            </h3>
            <ul className="divide-y divide-line">
              {group.accounts.map((account) => (
                <AccountRow key={account.id} account={account} />
              ))}
            </ul>
          </section>
        ))}
      </div>
    );
  }

  return (
    <>
      <PageHeader
        title={t('accounts.title')}
        description={t('accounts.description')}
        actions={
          <>
            <ButtonLink to={paths.accountNew}>
              <Icon name="plus" className="size-4" />
              {t('accounts.add')}
            </ButtonLink>
            <ButtonLink to={paths.transferNew} variant="secondary">
              <Icon name="arrow-left-right" className="size-4" />
              {t('transfers.add')}
            </ButtonLink>
          </>
        }
      />
      <AccountsSubNav />
      <div className="space-y-6">
        <TotalsCard />
        <Card
          title={t('accounts.list.title')}
          description={t('accounts.list.description')}
          actions={
            <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 text-sm text-fg">
              <input
                type="checkbox"
                checked={showArchived}
                onChange={(event) => {
                  setShowArchived(event.target.checked);
                }}
                className="size-4 accent-accent"
              />
              {t('accounts.list.showArchived')}
            </label>
          }
        >
          {content}
        </Card>
      </div>
    </>
  );
}
