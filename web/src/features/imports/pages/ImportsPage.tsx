import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { importPath, paths, withQuery } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { useAccounts } from '@/shared/finance/reference';
import { formatDateTime, formatLocalDateRange, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { loadedImports, useImports } from '../api';
import { ImportStatusBadge } from '../components/ImportBadges';
import { isReviewable } from '../status';
import type { ImportBatch } from '../types';
import { HelpGuideLink } from '@/shared/help/HelpGuideLink';

/** Statement import history with each import's status, counts and dates (spec §4.10). */
export function ImportsPage() {
  const { t } = useI18n();
  useDocumentTitle(t('imports.title'));
  const [accountId, setAccountId] = useState('');
  const accounts = useAccounts(true);
  const imports = useImports(accountId);
  const loaded = loadedImports(imports.data);
  const names = new Map((accounts.data ?? []).map((account) => [account.id, account.name]));

  const newImport = (
    <ButtonLink to={withQuery(paths.importNew, { account_id: accountId || undefined })}>
      <Icon name="upload" className="size-4" />
      {t('imports.new')}
    </ButtonLink>
  );

  let content;
  if (imports.isPending) {
    content = <LoadingState label={t('imports.list.loading')} />;
  } else if (imports.isError && !imports.isFetchNextPageError) {
    content = hasErrorCode(imports.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('imports.list.error')}
        error={imports.error}
        retrying={imports.isFetching}
        onRetry={() => {
          void imports.refetch();
        }}
      />
    );
  } else if (loaded.length === 0) {
    content = (
      <EmptyState
        icon="upload"
        title={accountId ? t('imports.list.emptyAccount') : t('imports.list.empty')}
        description={t('imports.list.emptyBody')}
        action={newImport}
      />
    );
  } else {
    content = (
      <>
        <ul className="divide-y divide-line" aria-busy={imports.isFetching || undefined}>
          {loaded.map((batch) => (
            <ImportListItem
              key={batch.id}
              batch={batch}
              accountName={names.get(batch.account_id) ?? t('imports.list.unknownAccount')}
            />
          ))}
        </ul>
        <LoadMoreButton
          hasMore={imports.hasNextPage}
          loading={imports.isFetchingNextPage}
          failed={imports.isFetchNextPageError}
          onLoadMore={() => {
            void imports.fetchNextPage();
          }}
        />
      </>
    );
  }

  const accountOptions = (accounts.data ?? []).map((account) => ({
    value: account.id,
    label: account.name,
  }));

  return (
    <>
      <PageHeader
        help={<HelpGuideLink guide="imports" />}
        title={t('imports.title')}
        description={t('imports.description')}
        actions={newImport}
      />
      <Card
        title={t('imports.list.title')}
        description={t('imports.list.newestFirst')}
        actions={
          accountOptions.length > 0 ? (
            <Select
              label={t('imports.list.account')}
              hideLabel
              value={accountId}
              onChange={(event) => {
                setAccountId(event.target.value);
              }}
              options={[{ value: '', label: t('imports.list.allAccounts') }, ...accountOptions]}
            />
          ) : null
        }
      >
        {content}
      </Card>
    </>
  );
}

function ImportListItem({ batch, accountName }: { batch: ImportBatch; accountName: string }) {
  const { t, formatLocale } = useI18n();
  const created = parseTimestamp(batch.created_at);
  const title = created
    ? t('imports.list.itemTitle', {
        account: accountName,
        date: formatDateTime(created, formatLocale),
      })
    : accountName;
  const counts = [
    t('imports.list.rows', { count: batch.total_rows }),
    t('imports.list.imported', { count: batch.imported_count }),
    batch.skipped_count > 0 ? t('imports.list.skipped', { count: batch.skipped_count }) : null,
    batch.failed_count > 0 ? t('imports.list.failed', { count: batch.failed_count }) : null,
    batch.duplicate_rows > 0 ? t('imports.list.duplicates', { count: batch.duplicate_rows }) : null,
  ].filter(Boolean);
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center">
      <div className="min-w-0 flex-1 space-y-1">
        <p className="flex flex-wrap items-center gap-2">
          <TextLink to={importPath(batch.id)}>{title}</TextLink>
          <ImportStatusBadge batch={batch} />
        </p>
        <p className="text-sm text-fg-muted">{counts.join(' · ')}</p>
        {batch.statement_start && batch.statement_end ? (
          <p className="text-sm text-fg-muted">
            {t('imports.list.period', {
              period: formatLocalDateRange(
                batch.statement_start,
                batch.statement_end,
                formatLocale,
              ),
            })}
          </p>
        ) : null}
      </div>
      {isReviewable(batch.status) ? (
        <ButtonLink
          to={withQuery(paths.importNew, { import_id: batch.id })}
          variant="secondary"
          size="sm"
          aria-label={t('imports.list.continueLabel', { title })}
        >
          {t('imports.list.continue')}
        </ButtonLink>
      ) : null}
    </li>
  );
}
