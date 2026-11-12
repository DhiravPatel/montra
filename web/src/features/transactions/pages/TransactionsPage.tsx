import { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { categoriesById } from '@/shared/finance/categories';
import { TransactionListItem } from '@/shared/finance/components/TransactionListItem';
import { useCategories } from '@/shared/finance/reference';
import { transactionTitle } from '@/shared/finance/transactionDisplay';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { useTransactionList } from '../api';
import { BulkActionsBar } from '../components/BulkActionsBar';
import { TransactionFilters } from '../components/TransactionFilters';
import {
  countActiveFilters,
  emptyPrivateFilters,
  type PrivateFilters,
  readUrlFilters,
  toListQuery,
  type UrlFilters,
  writeUrlFilters,
} from '../filters';

const MAX_BULK = 500;

function ListSkeleton() {
  return (
    <ul className="space-y-4" aria-hidden="true">
      {[0, 1, 2, 3, 4].map((key) => (
        <li key={key} className="flex items-center gap-3">
          <Skeleton className="size-9" />
          <div className="flex-1 space-y-2">
            <Skeleton className="h-4 w-1/3" />
            <Skeleton className="h-3 w-1/2" />
          </div>
          <Skeleton className="h-5 w-20" />
        </li>
      ))}
    </ul>
  );
}

/** Transaction list with filters, search, cursor pagination and bulk actions. */
export function TransactionsPage() {
  const t = useT();
  useDocumentTitle(t('transactions.title'));
  const announce = useAnnounce();
  const user = useCurrentUser();
  const [searchParams, setSearchParams] = useSearchParams();
  const url = useMemo(() => readUrlFilters(searchParams), [searchParams]);
  const [search, setSearch] = useState('');
  const q = useDebouncedValue(search, 300);
  const [amounts, setAmounts] = useState<PrivateFilters>(emptyPrivateFilters);
  const query = useMemo(() => toListQuery(url, { ...amounts, q }), [url, amounts, q]);
  const queryKey = JSON.stringify(query);
  const list = useTransactionList(query);
  const categories = useCategories(true);
  const byId = useMemo(() => categoriesById(categories.data), [categories.data]);
  // Selection belongs to one result set; changing filters starts afresh.
  const [selection, setSelection] = useState<{ key: string; ids: ReadonlySet<string> }>({
    key: queryKey,
    ids: new Set(),
  });
  const selected = selection.key === queryKey ? selection.ids : new Set<string>();

  const items = useMemo(() => list.data?.pages.flatMap((page) => page.items) ?? [], [list.data]);
  const selectable = items.filter((item) => item.owned && item.status !== 'voided');
  const filtered = countActiveFilters(url, amounts) > 0 || Boolean(q.trim()) || url.range !== 'all';

  const lastAnnounced = useRef<string | null>(null);
  useEffect(() => {
    if (!list.isSuccess || list.isFetching) return;
    const message = list.hasNextPage
      ? t('transactions.list.countMore', { count: items.length })
      : t('transactions.list.count', { count: items.length });
    if (lastAnnounced.current === null) {
      lastAnnounced.current = message; // the first load is not announced
      return;
    }
    if (lastAnnounced.current !== message) {
      lastAnnounced.current = message;
      announce(message);
    }
  }, [list.isSuccess, list.isFetching, list.hasNextPage, items.length, announce, t]);

  const setUrl = (next: UrlFilters) => {
    setSearchParams(writeUrlFilters(next), { replace: true });
  };

  const toggle = (id: string, checked: boolean) => {
    const ids = new Set(selected);
    if (checked) {
      if (ids.size >= MAX_BULK) return;
      ids.add(id);
    } else {
      ids.delete(id);
    }
    setSelection({ key: queryKey, ids });
  };

  const clearSelection = () => {
    setSelection({ key: queryKey, ids: new Set() });
  };

  let content;
  if (list.isPending) {
    content = (
      <LoadingState label={t('transactions.list.loading')}>
        <ListSkeleton />
      </LoadingState>
    );
  } else if (list.isError) {
    if (hasErrorCode(list.error, 'FORBIDDEN')) content = <PermissionDenied />;
    else
      content = (
        <ErrorState
          title={t('transactions.list.error')}
          error={list.error}
          description={
            hasErrorCode(list.error, 'VALIDATION_ERROR')
              ? t('transactions.list.badFilters')
              : undefined
          }
          retrying={list.isFetching}
          onRetry={() => {
            void list.refetch();
          }}
        />
      );
  } else if (items.length === 0) {
    content = filtered ? (
      <EmptyState
        icon="search"
        title={t('transactions.list.noMatches')}
        description={t('transactions.list.noMatchesBody')}
      />
    ) : (
      <EmptyState
        icon="list"
        title={t('transactions.list.empty.title')}
        description={t('transactions.list.empty.body')}
        action={
          <ButtonLink to={paths.transactionNew}>
            <Icon name="plus" className="size-4" />
            {t('transactions.add')}
          </ButtonLink>
        }
      />
    );
  } else {
    content = (
      <div
        className={cx(
          'transition-opacity motion-reduce:transition-none',
          list.isPlaceholderData && 'opacity-60',
        )}
        aria-busy={list.isFetching || undefined}
      >
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2 text-sm text-fg-muted">
          <p>
            {list.hasNextPage
              ? t('transactions.list.countMore', { count: items.length })
              : t('transactions.list.count', { count: items.length })}
          </p>
          {selectable.length > 0 ? (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                if (selected.size > 0) clearSelection();
                else
                  setSelection({
                    key: queryKey,
                    ids: new Set(selectable.slice(0, MAX_BULK).map((item) => item.id)),
                  });
              }}
            >
              {selected.size > 0 ? t('transactions.bulk.clear') : t('transactions.bulk.selectAll')}
            </Button>
          ) : null}
        </div>
        <ul className="divide-y divide-line">
          {items.map((transaction) => {
            const canSelect = transaction.owned && transaction.status !== 'voided';
            return (
              <TransactionListItem
                key={transaction.id}
                transaction={transaction}
                categories={byId}
                leading={
                  canSelect ? (
                    <input
                      type="checkbox"
                      checked={selected.has(transaction.id)}
                      aria-label={t('transactions.bulk.selectOne', {
                        name: transactionTitle(transaction, t),
                      })}
                      onChange={(event) => {
                        toggle(transaction.id, event.target.checked);
                      }}
                      className="mt-2.5 size-5 shrink-0 cursor-pointer accent-accent"
                    />
                  ) : (
                    <span className="w-5 shrink-0" aria-hidden="true" />
                  )
                }
              />
            );
          })}
        </ul>
        {list.hasNextPage ? (
          <div className="mt-6 flex justify-center">
            <Button
              variant="secondary"
              loading={list.isFetchingNextPage}
              onClick={() => {
                void list.fetchNextPage();
              }}
            >
              {t('common.loadMore')}
            </Button>
          </div>
        ) : null}
      </div>
    );
  }

  return (
    <>
      <PageHeader
        title={t('transactions.title')}
        description={t('transactions.description')}
        actions={
          <>
            <ButtonLink to={paths.transactionNew}>
              <Icon name="plus" className="size-4" />
              {t('transactions.add')}
            </ButtonLink>
            <ButtonLink to={paths.transferNew} variant="secondary">
              <Icon name="arrow-left-right" className="size-4" />
              {t('transfers.add')}
            </ButtonLink>
          </>
        }
      />
      <TransactionFilters
        url={url}
        onUrlChange={setUrl}
        search={search}
        onSearchChange={setSearch}
        amounts={amounts}
        onAmountsChange={setAmounts}
        defaultCurrency={user.base_currency}
      />
      {selected.size > 0 ? (
        <BulkActionsBar selectedIds={[...selected]} onClear={clearSelection} />
      ) : null}
      <Card>{content}</Card>
    </>
  );
}
