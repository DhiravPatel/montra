import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { financeKeys } from '@/shared/finance/keys';
import type { Account } from '@/shared/finance/types';
import { reconciliationKeys } from './keys';
import type {
  Candidate,
  Match,
  MatchInput,
  Reconciliation,
  ReconciliationInput,
  StatementLine,
  StatementLineStatus,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/** Rows per page of the cursor-paged lists (the API allows up to 200). */
export const RECONCILIATION_PAGE_SIZE = 50;

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
  hasMore: boolean;
}

interface ListEnvelope<T> {
  data: T[];
  meta: { next_cursor?: string; has_more?: boolean };
}

function toPage<T>(envelope: ListEnvelope<T>): Page<T> {
  const nextCursor = envelope.meta.next_cursor ?? null;
  return {
    items: envelope.data,
    nextCursor,
    hasMore: envelope.meta.has_more ?? nextCursor !== null,
  };
}

function pageQuery(cursor: string | null) {
  return { ...(cursor ? { cursor } : {}), limit: RECONCILIATION_PAGE_SIZE };
}

/**
 * Reconciliation endpoints (spec §4.10, §20B.11). The server computes every
 * balance and difference and explains every suggestion; nothing is matched
 * or voided until the user confirms.
 */
export const reconciliationApi = {
  account: (id: string, signal?: AbortSignal): Promise<Account> =>
    apiData(api.GET('/accounts/{id}', { params: { path: { id } }, ...signalOption(signal) })),
  history: async (
    accountId: string,
    cursor: string | null,
    signal?: AbortSignal,
  ): Promise<Page<Reconciliation>> =>
    toPage(
      await apiEnvelope(
        api.GET('/accounts/{id}/reconciliations', {
          params: { path: { id: accountId }, query: pageQuery(cursor) },
          ...signalOption(signal),
        }),
      ),
    ),
  reconcile: (accountId: string, body: ReconciliationInput): Promise<Reconciliation> =>
    apiData(
      api.POST('/accounts/{id}/reconciliations', { params: { path: { id: accountId } }, body }),
    ),
  candidates: (accountId: string, batchId: string, signal?: AbortSignal): Promise<Candidate[]> =>
    apiData(
      api.GET('/reconciliation/candidates', {
        params: { query: { account_id: accountId, ...(batchId ? { batch_id: batchId } : {}) } },
        ...signalOption(signal),
      }),
    ),
  matches: async (
    accountId: string,
    cursor: string | null,
    signal?: AbortSignal,
  ): Promise<Page<Match>> =>
    toPage(
      await apiEnvelope(
        api.GET('/reconciliation/matches', {
          params: { query: { account_id: accountId, ...pageQuery(cursor) } },
          ...signalOption(signal),
        }),
      ),
    ),
  /** Confirms a suggestion, or matches a statement line with transactions chosen by hand. */
  match: (body: MatchInput): Promise<Match> =>
    apiData(api.POST('/reconciliation/matches', { body })),
  unmatch: (id: string): Promise<Match> =>
    apiData(api.DELETE('/reconciliation/matches/{id}', { params: { path: { id } } })),
  /** Statement lines neither imported nor matched (or, with `matched`, in a confirmed match). */
  statementLines: async (
    accountId: string,
    status: StatementLineStatus,
    batchId: string,
    cursor: string | null,
    signal?: AbortSignal,
  ): Promise<Page<StatementLine>> =>
    toPage(
      await apiEnvelope(
        api.GET('/accounts/{id}/statement-lines', {
          params: {
            path: { id: accountId },
            query: { status, ...(batchId ? { batch_id: batchId } : {}), ...pageQuery(cursor) },
          },
          ...signalOption(signal),
        }),
      ),
    ),
};

/** The account being reconciled (shares the account detail's cache entry). */
export function useReconcileAccount(id: string) {
  return useQuery({
    queryKey: financeKeys.account(id),
    queryFn: ({ signal }) => reconciliationApi.account(id, signal),
  });
}

const pageOptions = {
  initialPageParam: null as string | null,
  getNextPageParam: <T>(page: Page<T>) => (page.hasMore ? page.nextCursor : null),
};

export function useReconciliationHistory(accountId: string, enabled: boolean) {
  return useInfiniteQuery({
    queryKey: reconciliationKeys.history(accountId),
    queryFn: ({ pageParam, signal }) => reconciliationApi.history(accountId, pageParam, signal),
    ...pageOptions,
    enabled,
  });
}

export function useCandidates(accountId: string, batchId: string, enabled: boolean) {
  return useQuery({
    queryKey: reconciliationKeys.candidates(accountId, batchId),
    queryFn: ({ signal }) => reconciliationApi.candidates(accountId, batchId, signal),
    enabled,
  });
}

export function useMatches(accountId: string, enabled: boolean) {
  return useInfiniteQuery({
    queryKey: reconciliationKeys.matches(accountId),
    queryFn: ({ pageParam, signal }) => reconciliationApi.matches(accountId, pageParam, signal),
    ...pageOptions,
    enabled,
  });
}

export function useStatementLines(
  accountId: string,
  status: StatementLineStatus,
  batchId: string,
  enabled: boolean,
) {
  return useInfiniteQuery({
    queryKey: reconciliationKeys.statementLines(accountId, status, batchId),
    queryFn: ({ pageParam, signal }) =>
      reconciliationApi.statementLines(accountId, status, batchId, pageParam, signal),
    ...pageOptions,
    enabled,
  });
}

/** Every loaded page's items, in the API's order. */
export function loadedItems<T>(data: { pages: Page<T>[] } | undefined): T[] {
  return data?.pages.flatMap((page) => page.items) ?? [];
}
