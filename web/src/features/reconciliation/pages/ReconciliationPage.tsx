import { useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { accountPath, paths, withQuery } from '@/shared/config/paths';
import { formatDateTime, formatLocalDateRange, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { loadedImports, useImports } from '@/features/imports/api';
import { useReconcileAccount } from '../api';
import { CandidatesCard } from '../components/CandidatesCard';
import { HistoryCard } from '../components/HistoryCard';
import { MatchesCard } from '../components/MatchesCard';
import { ReconcileForm } from '../components/ReconcileForm';
import { StatementLinesCard } from '../components/StatementLinesCard';

function PageSkeleton() {
  return (
    <div className="space-y-6" aria-hidden="true">
      <Skeleton className="h-9 w-1/2" />
      <Skeleton className="h-48 w-full" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}

/**
 * Reconciles an account against its bank statement (spec §4.10, §20B.11):
 * a balance check where the server computes the difference, suggested
 * matches to confirm one by one, confirmed matches with undo, and history.
 */
export function ReconciliationPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('reconciliation.documentTitle'));
  const { accountId = '' } = useParams();
  const account = useReconcileAccount(accountId);
  const owned = account.data?.owned === true;
  const imports = useImports(accountId, owned);
  const [importId, setImportId] = useState('');

  if (account.isPending) {
    return (
      <LoadingState label={t('reconciliation.loading')}>
        <PageSkeleton />
      </LoadingState>
    );
  }
  if (account.isError) {
    if (hasErrorCode(account.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="wallet"
          title={t('reconciliation.notFound')}
          description={t('reconciliation.notFoundBody')}
          action={<ButtonLink to={paths.accounts}>{t('reconciliation.toAccounts')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(account.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('reconciliation.error')}
        error={account.error}
        retrying={account.isFetching}
        onRetry={() => {
          void account.refetch();
        }}
      />
    );
  }

  const current = account.data;
  const back = (
    <p className="mb-2">
      <TextLink to={accountPath(current.id)}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {t('reconciliation.back', { name: current.name })}
      </TextLink>
    </p>
  );

  if (!current.owned) {
    return (
      <>
        {back}
        <PageHeader title={t('reconciliation.title', { name: current.name })} />
        <PermissionDenied
          titleAs="h2"
          title={t('reconciliation.ownerOnly')}
          description={t('reconciliation.ownerOnlyBody')}
        />
      </>
    );
  }

  const lastReconciled = parseTimestamp(current.last_reconciled_at);
  const lastImport = parseTimestamp(current.last_import_at);

  // Imports that produced statement rows (a failed or still-reading import has none to match).
  const importOptions = loadedImports(imports.data)
    .filter((batch) => batch.status !== 'failed' && batch.status !== 'awaiting_upload')
    .map((batch) => {
      const created = parseTimestamp(batch.created_at);
      const label =
        batch.statement_start && batch.statement_end
          ? t('reconciliation.form.importPeriod', {
              period: formatLocalDateRange(
                batch.statement_start,
                batch.statement_end,
                formatLocale,
              ),
            })
          : created
            ? t('reconciliation.form.importCreated', {
                date: formatDateTime(created, formatLocale),
              })
            : batch.id;
      return { value: batch.id, label };
    });

  return (
    <>
      {back}
      <PageHeader
        title={t('reconciliation.title', { name: current.name })}
        description={
          <>
            {t('reconciliation.description')}
            {lastReconciled ? (
              <>
                {' '}
                {t('reconciliation.lastReconciled', {
                  date: formatDateTime(lastReconciled, formatLocale),
                })}
                {current.last_reconciled_balance ? (
                  <>
                    {' '}
                    (<MoneyText money={current.last_reconciled_balance} />)
                  </>
                ) : null}
              </>
            ) : null}
            {lastImport ? (
              <>
                {' '}
                {t('reconciliation.lastImport', { date: formatDateTime(lastImport, formatLocale) })}
              </>
            ) : null}
          </>
        }
        actions={
          current.status === 'active' ? (
            <ButtonLink
              to={withQuery(paths.importNew, { account_id: current.id })}
              variant="secondary"
            >
              <Icon name="upload" className="size-4" />
              {t('imports.accountAction')}
            </ButtonLink>
          ) : null
        }
      />
      <div className="space-y-6">
        <Card
          title={t('reconciliation.form.title')}
          description={
            <span>
              {t('reconciliation.form.description')}{' '}
              <span className="whitespace-nowrap">
                {t('reconciliation.form.current')} <MoneyText money={current.balance} />
              </span>
            </span>
          }
        >
          <ReconcileForm
            account={current}
            importOptions={importOptions}
            importId={importId}
            onImportChange={setImportId}
          />
        </Card>
        <CandidatesCard accountId={current.id} batchId={importId} />
        <StatementLinesCard accountId={current.id} batchId={importId} />
        <MatchesCard accountId={current.id} />
        <HistoryCard accountId={current.id} />
      </div>
    </>
  );
}
