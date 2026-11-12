import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { useEffect, useRef } from 'react';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { importKeys } from './keys';
import { isBusy } from './status';
import type {
  ColumnMapping,
  ImportBatch,
  ImportCreateInput,
  ImportRow,
  ImportRowPage,
  ImportRowUpdate,
  RowFilter,
  RowsQuery,
} from './types';
import { usePageVisible } from './usePageVisible';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/** Imports per history page (the API allows up to 200); the next page follows `meta.next_cursor`. */
export const IMPORTS_PAGE_SIZE = 50;

export interface ImportPage {
  items: ImportBatch[];
  nextCursor: string | null;
  hasMore: boolean;
}

/** Statement import endpoints (spec §4.10, §20B.11). Parsing and importing run on the server. */
export const importsApi = {
  list: async (
    accountId: string,
    cursor: string | null,
    signal?: AbortSignal,
  ): Promise<ImportPage> => {
    const envelope = await apiEnvelope(
      api.GET('/imports', {
        params: {
          query: {
            ...(accountId ? { account_id: accountId } : {}),
            ...(cursor ? { cursor } : {}),
            limit: IMPORTS_PAGE_SIZE,
          },
        },
        ...signalOption(signal),
      }),
    );
    const nextCursor = envelope.meta.next_cursor ?? null;
    return {
      items: envelope.data,
      nextCursor,
      hasMore: envelope.meta.has_more ?? nextCursor !== null,
    };
  },
  get: (id: string, signal?: AbortSignal): Promise<ImportBatch> =>
    apiData(api.GET('/imports/{id}', { params: { path: { id } }, ...signalOption(signal) })),
  /** Starts an import. A retry with the same Idempotency-Key and body returns the first batch. */
  create: (body: ImportCreateInput, idempotencyKey: string): Promise<ImportBatch> =>
    apiData(
      api.POST('/imports', { params: { header: { 'Idempotency-Key': idempotencyKey } }, body }),
    ),
  setMapping: (id: string, mapping: ColumnMapping, version: number): Promise<ImportBatch> =>
    apiData(
      api.PATCH('/imports/{id}/mapping', {
        params: { path: { id } },
        body: { mapping, version },
      }),
    ),
  rows: (id: string, query: RowsQuery, signal?: AbortSignal): Promise<ImportRowPage> =>
    apiData(
      api.GET('/imports/{id}/rows', { params: { path: { id }, query }, ...signalOption(signal) }),
    ),
  updateRow: (id: string, rowId: string, body: ImportRowUpdate): Promise<ImportRow> =>
    apiData(api.PATCH('/imports/{id}/rows/{rowId}', { params: { path: { id, rowId } }, body })),
  confirm: (id: string, version: number, idempotencyKey: string): Promise<ImportBatch> =>
    apiData(
      api.POST('/imports/{id}/confirm', {
        params: { path: { id }, header: { 'Idempotency-Key': idempotencyKey } },
        body: { version },
      }),
    ),
  cancel: (id: string): Promise<ImportBatch> =>
    apiData(api.POST('/imports/{id}/cancel', { params: { path: { id } } })),
  retryFailed: (id: string): Promise<ImportBatch> =>
    apiData(api.POST('/imports/{id}/retry-failed', { params: { path: { id } } })),
  rollback: (id: string): Promise<ImportBatch> =>
    apiData(api.POST('/imports/{id}/rollback', { params: { path: { id } } })),
};

/** Polls every second at first, then every three seconds for long imports. */
const FAST_POLL_MS = 1000;
const SLOW_POLL_MS = 3000;
const FAST_POLLS = 20;

function pollInterval(updates: number): number {
  return updates < FAST_POLLS ? FAST_POLL_MS : SLOW_POLL_MS;
}

/**
 * Refetches as soon as the page becomes visible again while the server is
 * still working (polling itself pauses while the tab is hidden).
 */
function useCatchUpWhenVisible(visible: boolean, busy: boolean, refetch: () => unknown) {
  const wasVisible = useRef(visible);
  useEffect(() => {
    if (visible && !wasVisible.current && busy) void refetch();
    wasVisible.current = visible;
  }, [visible, busy, refetch]);
}

/** One import. Polls while the server reads or imports it, only while the page is visible. */
export function useImportBatch(id: string) {
  const visible = usePageVisible();
  const query = useQuery({
    queryKey: importKeys.batch(id),
    queryFn: ({ signal }) => importsApi.get(id, signal),
    enabled: id !== '',
    refetchInterval: (current) =>
      visible && isBusy(current.state.data?.status)
        ? pollInterval(current.state.dataUpdateCount)
        : false,
  });
  useCatchUpWhenVisible(visible, isBusy(query.data?.status), query.refetch);
  return query;
}

/** The imports loaded so far (every page), in the API's order (newest first). */
export function loadedImports(data: { pages: ImportPage[] } | undefined): ImportBatch[] {
  return data?.pages.flatMap((page) => page.items) ?? [];
}

/**
 * Import history, newest first, a page at a time ("Load more" follows the
 * API's cursor). Polls while any loaded import is in progress.
 */
export function useImports(accountId = '', enabled = true) {
  const visible = usePageVisible();
  const query = useInfiniteQuery({
    queryKey: importKeys.list(accountId),
    queryFn: ({ pageParam, signal }) => importsApi.list(accountId, pageParam, signal),
    initialPageParam: null as string | null,
    getNextPageParam: (page) => (page.hasMore ? page.nextCursor : null),
    enabled,
    placeholderData: keepPreviousData,
    refetchInterval: (current) =>
      visible && loadedImports(current.state.data).some((batch) => isBusy(batch.status))
        ? pollInterval(current.state.dataUpdateCount)
        : false,
  });
  useCatchUpWhenVisible(
    visible,
    loadedImports(query.data).some((batch) => isBusy(batch.status)),
    query.refetch,
  );
  return query;
}

export const ROWS_PAGE_SIZE = 50;
const SAMPLE_SIZE = 30;

/** The rows of one stage of an import, by status, a page at a time (keyset on the row number). */
export function useImportRows(batch: ImportBatch, filter: RowFilter) {
  const stage = `${batch.version}:${batch.status}`;
  return useInfiniteQuery({
    queryKey: importKeys.rows(batch.id, filter, stage),
    queryFn: ({ pageParam, signal }) =>
      importsApi.rows(
        batch.id,
        { ...(filter ? { status: filter } : {}), after_row: pageParam, limit: ROWS_PAGE_SIZE },
        signal,
      ),
    initialPageParam: 0,
    getNextPageParam: (page) => page.next_cursor,
    enabled: !isBusy(batch.status),
  });
}

/** The first rows of the file exactly as read (the header row is chosen among them). */
export function useImportSample(batch: ImportBatch) {
  const stage = `${batch.version}:${batch.status}`;
  return useQuery({
    queryKey: importKeys.sample(batch.id, stage),
    queryFn: ({ signal }) => importsApi.rows(batch.id, { limit: SAMPLE_SIZE }, signal),
    enabled: !isBusy(batch.status),
  });
}
