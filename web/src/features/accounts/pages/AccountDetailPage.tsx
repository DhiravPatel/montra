import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { accountEditPath, accountReconcilePath, paths, withQuery } from '@/shared/config/paths';
import { categoriesById } from '@/shared/finance/categories';
import { TransactionListItem } from '@/shared/finance/components/TransactionListItem';
import { invalidateFinance } from '@/shared/finance/keys';
import { accountLabel, balanceSourceLabel } from '@/shared/finance/labels';
import { useCategories } from '@/shared/finance/reference';
import type { Account } from '@/shared/finance/types';
import { formatDateTime, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { isZeroDecimal } from '@/shared/formatting/decimal';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n, useT } from '@/shared/i18n/I18nContext';
import { accountsApi, useAccount, useRecentAccountTransactions } from '../api';
import { AccountBalance } from '../components/AccountBalance';
import { AccountStatusBadges } from '../components/AccountStatusBadges';
import { AdjustBalanceDialog } from '../components/AdjustBalanceDialog';
import { BalanceHistoryCard } from '../components/BalanceHistoryCard';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

type StatusAction = 'archive' | 'close' | 'restore';

function DetailSkeleton() {
  return (
    <div className="space-y-6" aria-hidden="true">
      <Skeleton className="h-9 w-1/2" />
      <Skeleton className="h-40 w-full" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}

function RecentTransactionsCard({ account }: { account: Account }) {
  const t = useT();
  const recent = useRecentAccountTransactions(account.id);
  const categories = useCategories();
  const byId = categoriesById(categories.data);
  const viewAll = withQuery(paths.transactions, { account_id: account.id });
  let content;
  if (recent.isPending) {
    content = <LoadingState label={t('transactions.list.loading')} />;
  } else if (recent.isError) {
    content = (
      <ErrorState
        title={t('transactions.list.error')}
        error={recent.error}
        retrying={recent.isFetching}
        onRetry={() => {
          void recent.refetch();
        }}
      />
    );
  } else if (recent.data.items.length === 0) {
    content = (
      <EmptyState
        icon="list"
        title={t('accounts.detail.noTransactions')}
        description={t('accounts.detail.noTransactionsBody')}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {recent.data.items.map((transaction) => (
          <TransactionListItem
            key={transaction.id}
            transaction={transaction}
            categories={byId}
            showAccount={false}
          />
        ))}
      </ul>
    );
  }
  return (
    <Card
      title={t('accounts.detail.recent')}
      actions={
        <ButtonLink to={viewAll} variant="ghost" size="sm">
          {t('accounts.detail.viewAll')}
          <Icon name="arrow-right" className="size-4" />
        </ButtonLink>
      }
    >
      {content}
    </Card>
  );
}

function DetailsCard({ account }: { account: Account }) {
  const { t, formatLocale } = useI18n();
  const reconciled = parseTimestamp(account.last_reconciled_at);
  const imported = parseTimestamp(account.last_import_at);
  const created = parseTimestamp(account.created_at);
  return (
    <Card title={t('accounts.detail.details')}>
      <Facts>
        <Fact label={t('accounts.form.type')}>{t(accountLabel(account))}</Fact>
        <Fact label={t('accounts.form.currency')}>{account.currency}</Fact>
        <Fact label={t('accounts.form.openingDate')}>
          {formatLocalDate(account.opening_date, formatLocale, 'long')}
        </Fact>
        {account.institution_label ? (
          <Fact label={t('accounts.form.institution')}>{account.institution_label}</Fact>
        ) : null}
        {account.masked_number ? (
          <Fact label={t('accounts.form.masked')}>{`•••• ${account.masked_number}`}</Fact>
        ) : null}
        {account.credit_limit ? (
          <Fact label={t('accounts.form.creditLimit')}>
            <MoneyText money={account.credit_limit} />
          </Fact>
        ) : null}
        {account.available_credit ? (
          <Fact label={t('accounts.detail.availableCredit')}>
            <MoneyText money={account.available_credit} />
          </Fact>
        ) : null}
        {account.statement_day ? (
          <Fact label={t('accounts.form.statementDay')}>
            {t('accounts.detail.dayOfMonth', { day: account.statement_day })}
          </Fact>
        ) : null}
        {account.payment_due_day ? (
          <Fact label={t('accounts.form.dueDay')}>
            {t('accounts.detail.dayOfMonth', { day: account.payment_due_day })}
          </Fact>
        ) : null}
        <Fact label={t('accounts.detail.inOverview')}>
          {account.include_in_overview ? t('common.yes') : t('common.no')}
        </Fact>
        <Fact label={t('accounts.detail.balanceSource')}>
          {t(balanceSourceLabel[account.balance_source])}
        </Fact>
        {reconciled ? (
          <Fact label={t('accounts.detail.lastReconciled')}>
            <time dateTime={account.last_reconciled_at}>
              {formatDateTime(reconciled, formatLocale)}
            </time>
            {account.last_reconciled_balance ? (
              <>
                {' · '}
                <MoneyText money={account.last_reconciled_balance} />
              </>
            ) : null}
          </Fact>
        ) : null}
        {imported ? (
          <Fact label={t('accounts.detail.lastImport')}>
            <time dateTime={account.last_import_at}>{formatDateTime(imported, formatLocale)}</time>
          </Fact>
        ) : null}
        {account.notes ? (
          <Fact label={t('accounts.form.notes')}>
            <span className="whitespace-pre-line">{account.notes}</span>
          </Fact>
        ) : null}
        {created ? (
          <Fact label={t('accounts.detail.created')}>
            <time dateTime={account.created_at}>{formatDateTime(created, formatLocale)}</time>
          </Fact>
        ) : null}
      </Facts>
    </Card>
  );
}

const confirmCopy = {
  archive: {
    title: 'accounts.archive.title',
    body: 'accounts.archive.body',
    confirm: 'accounts.archive.confirm',
    done: 'accounts.archive.done',
  },
  close: {
    title: 'accounts.close.title',
    body: 'accounts.close.body',
    confirm: 'accounts.close.confirm',
    done: 'accounts.close.done',
  },
  restore: {
    title: 'accounts.restore.title',
    body: 'accounts.restore.body',
    confirm: 'accounts.restore.confirm',
    done: 'accounts.restore.done',
  },
} as const;

/** Account detail: balance, history, recent activity and lifecycle actions. */
export function AccountDetailPage() {
  const { t, formatLocale } = useI18n();
  const { accountId = '' } = useParams();
  useDocumentTitle(t('accounts.detail.documentTitle'));
  const toast = useToast();
  const queryClient = useQueryClient();
  const query = useAccount(accountId);
  const [adjustOpen, setAdjustOpen] = useState(false);
  const [action, setAction] = useState<StatusAction | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const status = useMutation({
    mutationFn: ({ next, version }: { next: StatusAction; version: number }) =>
      next === 'archive'
        ? accountsApi.archive(accountId, version)
        : next === 'close'
          ? accountsApi.close(accountId, version)
          : accountsApi.restore(accountId, version),
    onSuccess: () => invalidateFinance(queryClient),
  });

  if (query.isPending) {
    return (
      <LoadingState label={t('accounts.detail.loading')}>
        <DetailSkeleton />
      </LoadingState>
    );
  }
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
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const account = query.data;
  const active = account.status === 'active';
  const editable = account.owned;
  const zeroBalance = isZeroDecimal(account.balance.amount);

  const runAction = () => {
    if (!action || status.isPending) return;
    setActionError(null);
    status.mutate(
      { next: action, version: account.version },
      {
        onSuccess: () => {
          toast.show({ tone: 'success', title: t(confirmCopy[action].done) });
          setAction(null);
        },
        onError: (error) => {
          if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION'))
            setActionError(
              domainRuleMessage(error, t, formatLocale) ?? t('accounts.close.notZero'),
            );
          else if (hasErrorCode(error, 'CONFLICT') || hasErrorCode(error, 'VERSION_CONFLICT')) {
            setActionError(t('accounts.status.changedElsewhere'));
            void query.refetch();
          } else setActionError(describeError(error, t));
        },
      },
    );
  };

  const details = [t(accountLabel(account)), account.institution_label, account.currency].filter(
    Boolean,
  );

  return (
    <>
      <p className="mb-2">
        <TextLink to={paths.accounts}>
          <Icon name="arrow-left" className="me-1 inline size-4" />
          {t('accounts.backToList')}
        </TextLink>
      </p>
      <PageHeader
        title={account.name}
        description={details.join(' · ')}
        actions={
          editable && active ? (
            <>
              <ButtonLink to={withQuery(paths.transactionNew, { account_id: account.id })}>
                <Icon name="plus" className="size-4" />
                {t('transactions.add')}
              </ButtonLink>
              <ButtonLink
                to={withQuery(paths.transferNew, { from_account_id: account.id })}
                variant="secondary"
              >
                <Icon name="arrow-left-right" className="size-4" />
                {t('transfers.add')}
              </ButtonLink>
            </>
          ) : null
        }
      />
      <div className="mb-6">
        <AccountStatusBadges account={account} />
      </div>
      {!account.owned ? (
        <Alert tone="info" className="mb-6" title={t('accounts.detail.readOnlyTitle')}>
          {t('accounts.detail.readOnlyBody')}
        </Alert>
      ) : null}
      {account.status !== 'active' ? (
        <Alert tone="info" className="mb-6" title={t('accounts.detail.inactiveTitle')}>
          {t('accounts.detail.inactiveBody')}
        </Alert>
      ) : null}
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Card title={t('accounts.detail.balance')} description={t('accounts.detail.trackedNote')}>
            <AccountBalance account={account} size="lg" align="start" />
            {editable && active ? (
              <div className="mt-4">
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => {
                    setAdjustOpen(true);
                  }}
                >
                  <Icon name="sliders" className="size-4" />
                  {t('accounts.adjust.action')}
                </Button>
              </div>
            ) : null}
          </Card>
          <BalanceHistoryCard account={account} />
          <RecentTransactionsCard account={account} />
        </div>
        <div className="space-y-6">
          <DetailsCard account={account} />
          {editable ? (
            <Card title={t('accounts.detail.manage')}>
              <div className="flex flex-col gap-3">
                {active ? (
                  <>
                    <ButtonLink
                      to={withQuery(paths.importNew, { account_id: account.id })}
                      variant="secondary"
                    >
                      <Icon name="upload" className="size-4" />
                      {t('imports.accountAction')}
                    </ButtonLink>
                    <ButtonLink to={accountReconcilePath(account.id)} variant="secondary">
                      <Icon name="scale" className="size-4" />
                      {t('reconciliation.accountAction')}
                    </ButtonLink>
                    <ButtonLink to={accountEditPath(account.id)} variant="secondary">
                      <Icon name="pencil" className="size-4" />
                      {t('accounts.edit.action')}
                    </ButtonLink>
                    <Button
                      variant="secondary"
                      onClick={() => {
                        setActionError(null);
                        setAction('archive');
                      }}
                    >
                      <Icon name="archive" className="size-4" />
                      {t('accounts.archive.action')}
                    </Button>
                    <Button
                      variant="secondary"
                      onClick={() => {
                        setActionError(null);
                        setAction('close');
                      }}
                      disabled={!zeroBalance}
                      aria-describedby={zeroBalance ? undefined : 'close-help'}
                    >
                      <Icon name="lock" className="size-4" />
                      {t('accounts.close.action')}
                    </Button>
                    {zeroBalance ? null : (
                      <p id="close-help" className="text-sm text-fg-muted">
                        {t('accounts.close.needsZero')}
                      </p>
                    )}
                  </>
                ) : (
                  <Button
                    variant="secondary"
                    onClick={() => {
                      setActionError(null);
                      setAction('restore');
                    }}
                  >
                    <Icon name="archive-restore" className="size-4" />
                    {t('accounts.restore.action')}
                  </Button>
                )}
              </div>
            </Card>
          ) : null}
        </div>
      </div>
      {editable ? (
        <AdjustBalanceDialog account={account} open={adjustOpen} onOpenChange={setAdjustOpen} />
      ) : null}
      <ConfirmDialog
        open={action !== null}
        onOpenChange={(open) => {
          if (!open) setAction(null);
        }}
        tone={action === 'restore' ? 'primary' : 'danger'}
        title={action ? t(confirmCopy[action].title) : ''}
        description={action ? t(confirmCopy[action].body, { name: account.name }) : ''}
        confirmLabel={action ? t(confirmCopy[action].confirm) : ''}
        onConfirm={runAction}
        pending={status.isPending}
        error={actionError}
      />
    </>
  );
}
