import { useState } from 'react';
import { Link, useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { merchantPath } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import type { Merchant } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useMerchantList } from '../api';
import { OrganizeSubNav } from '../components/OrganizeSubNav';
import { MERCHANT_STATUSES, merchantStatusFilterLabel, parseMerchantStatus } from '../labels';

function MerchantRow({ merchant }: { merchant: Merchant }) {
  const { t, formatLocale } = useI18n();
  const details = [
    t('organize.transactionCount', { count: merchant.transaction_count }),
    merchant.last_used_on
      ? t('merchants.lastUsed', { date: formatLocalDate(merchant.last_used_on, formatLocale) })
      : null,
    merchant.aliases.length > 0
      ? t('merchants.aliasCount', { count: merchant.aliases.length })
      : null,
  ].filter(Boolean);
  return (
    <li className="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
      <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name="shopping-bag" className="size-4" />
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        <Link
          to={merchantPath(merchant.id)}
          className="font-medium text-fg underline-offset-4 hover:underline"
        >
          {merchant.name}
        </Link>
        <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        {merchant.status === 'archived' ? (
          <StatusBadge icon="archive">{t('organize.archived')}</StatusBadge>
        ) : null}
        {merchant.status === 'merged' ? (
          <StatusBadge icon="git-merge">{t('merchants.merged')}</StatusBadge>
        ) : null}
      </div>
      <Icon name="chevron-right" className="size-4 text-fg-muted" />
    </li>
  );
}

/**
 * Merchants the user has paid, by status (active by default), searchable and
 * in cursor pages. The status filter is in the URL; the search text and the
 * cursor stay in memory.
 */
export function MerchantsPage() {
  const { t } = useI18n();
  useDocumentTitle(t('merchants.title'));
  const [params, setParams] = useSearchParams();
  const status = parseMerchantStatus(params.get('status'));
  const [search, setSearch] = useState('');
  const q = useDebouncedValue(search.trim(), 300);
  const merchants = useMerchantList(q, status);
  const items = merchants.data?.pages.flatMap((page) => page.items) ?? [];

  let content;
  if (merchants.isPending) {
    content = <LoadingState label={t('merchants.loading')} />;
  } else if (merchants.isError && items.length === 0) {
    content = hasErrorCode(merchants.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('merchants.error')}
        error={merchants.error}
        retrying={merchants.isFetching}
        onRetry={() => {
          void merchants.refetch();
        }}
      />
    );
  } else if (items.length === 0) {
    if (q) {
      content = (
        <p className="py-6 text-center text-sm text-fg-muted">{t('merchants.noMatches')}</p>
      );
    } else if (status === 'active') {
      content = (
        <EmptyState
          icon="shopping-bag"
          title={t('merchants.empty.title')}
          description={t('merchants.empty.body')}
        />
      );
    } else {
      content = (
        <p className="py-6 text-center text-sm text-fg-muted">{t('merchants.empty.filtered')}</p>
      );
    }
  } else {
    content = (
      <>
        <ul className="divide-y divide-line">
          {items.map((merchant) => (
            <MerchantRow key={merchant.id} merchant={merchant} />
          ))}
        </ul>
        <LoadMoreButton
          hasMore={merchants.hasNextPage}
          loading={merchants.isFetchingNextPage}
          failed={merchants.isFetchNextPageError}
          onLoadMore={() => {
            void merchants.fetchNextPage();
          }}
        />
      </>
    );
  }

  return (
    <>
      <PageHeader title={t('merchants.title')} description={t('merchants.description')} />
      <OrganizeSubNav />
      <Card
        title={t('merchants.list.title')}
        actions={
          <Select
            label={t('merchants.filter.label')}
            hideLabel
            className="min-w-44"
            value={status}
            options={MERCHANT_STATUSES.map((value) => ({
              value,
              label: t(merchantStatusFilterLabel[value]),
            }))}
            onChange={(event) => {
              const next = parseMerchantStatus(event.target.value);
              setParams(next === 'active' ? {} : { status: next }, { replace: true });
            }}
          />
        }
      >
        <div className="mb-5 max-w-md">
          <TextField
            label={t('merchants.search')}
            type="search"
            optional
            autoComplete="off"
            maxLength={100}
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
            }}
          />
          <p role="status" className="sr-only">
            {merchants.isSuccess && q
              ? merchants.hasNextPage
                ? t('merchants.resultCountMore', { count: items.length })
                : t('merchants.resultCount', { count: items.length })
              : ''}
          </p>
        </div>
        {content}
      </Card>
    </>
  );
}
