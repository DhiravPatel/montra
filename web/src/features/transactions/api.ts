import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { commaSeparatedArrays } from '@/shared/api/query';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { financeKeys } from '@/shared/finance/keys';
import type {
  Attachment,
  AuditEvent,
  BulkUpdateInput,
  CreateResult,
  RefundInput,
  Transaction,
  TransactionInput,
  TransactionListQuery,
  TransactionPatch,
  Transfer,
  TransferInput,
} from '@/shared/finance/types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

function idempotent(key: string) {
  return { 'Idempotency-Key': key };
}

export interface TransactionPage {
  items: Transaction[];
  nextCursor: string | null;
}

/** Transaction and transfer endpoints (spec §4.4, §18, §20B.5). */
export const transactionsApi = {
  list: async (query: TransactionListQuery, signal?: AbortSignal): Promise<TransactionPage> => {
    const options = {
      params: { query },
      querySerializer: commaSeparatedArrays,
      ...signalOption(signal),
    };
    // Same filters; /search is the contract's endpoint for text search.
    const envelope = await apiEnvelope(
      query.q ? api.GET('/transactions/search', options) : api.GET('/transactions', options),
    );
    return { items: envelope.data, nextCursor: envelope.meta.next_cursor ?? null };
  },
  get: (id: string, signal?: AbortSignal): Promise<Transaction> =>
    apiData(api.GET('/transactions/{id}', { params: { path: { id } }, ...signalOption(signal) })),
  create: (body: TransactionInput, key: string): Promise<CreateResult> =>
    apiData(api.POST('/transactions', { params: { header: idempotent(key) }, body })),
  update: (id: string, body: TransactionPatch): Promise<Transaction> =>
    apiData(api.PATCH('/transactions/{id}', { params: { path: { id } }, body })),
  /** Voids (soft-deletes) a transaction; a transfer leg voids the whole transfer. */
  void: (id: string): Promise<Transaction> =>
    apiData(api.DELETE('/transactions/{id}', { params: { path: { id } } })),
  restore: (id: string): Promise<Transaction> =>
    apiData(api.POST('/transactions/{id}/restore', { params: { path: { id } } })),
  duplicate: (id: string, localDate: string, key: string): Promise<CreateResult> =>
    apiData(
      api.POST('/transactions/{id}/duplicate', {
        params: { path: { id }, header: idempotent(key) },
        body: localDate ? { local_date: localDate } : {},
      }),
    ),
  refund: (id: string, body: RefundInput, key: string): Promise<CreateResult> =>
    apiData(
      api.POST('/transactions/{id}/refunds', {
        params: { path: { id }, header: idempotent(key) },
        body,
      }),
    ),
  audit: (id: string, signal?: AbortSignal): Promise<AuditEvent[]> =>
    apiData(
      api.GET('/transactions/{id}/audit', { params: { path: { id } }, ...signalOption(signal) }),
    ),
  attachments: (id: string, signal?: AbortSignal): Promise<Attachment[]> =>
    apiData(
      api.GET('/transactions/{id}/attachments', {
        params: { path: { id } },
        ...signalOption(signal),
      }),
    ),
  /** Links an uploaded, ready file to the transaction (attaching it again changes nothing). */
  attach: (id: string, fileId: string): Promise<Transaction> =>
    apiData(
      api.POST('/transactions/{id}/attachments', {
        params: { path: { id } },
        body: { file_id: fileId },
      }),
    ),
  detach: (id: string, fileId: string) =>
    apiData(
      api.DELETE('/transactions/{id}/attachments/{fileId}', { params: { path: { id, fileId } } }),
    ),
  /** Deletes an uploaded file that could not be attached (it would only use storage). */
  deleteFile: (fileId: string) =>
    apiData(api.DELETE('/files/{fileId}', { params: { path: { fileId } } })),
  /** A short-lived download URL (authorization is checked on every call). */
  fileAccess: (fileId: string) =>
    apiData(api.GET('/files/{fileId}/access', { params: { path: { fileId } } })),
  bulkUpdate: (body: BulkUpdateInput) => apiData(api.POST('/transactions/bulk-update', { body })),
  bulkDelete: (ids: string[]) =>
    apiData(
      api.POST('/transactions/bulk-delete', { body: { confirm: true, transaction_ids: ids } }),
    ),
  createTransfer: (body: TransferInput, key: string): Promise<Transfer> =>
    apiData(api.POST('/transactions/transfers', { params: { header: idempotent(key) }, body })),
  /** Deletes a transfer as one unit: both legs and the fee (restorable). */
  voidTransfer: (id: string): Promise<Transfer> =>
    apiData(api.DELETE('/transactions/transfers/{id}', { params: { path: { id } } })),
  restoreTransfer: (id: string): Promise<Transfer> =>
    apiData(api.POST('/transactions/transfers/{id}/restore', { params: { path: { id } } })),
  getTransfer: (id: string, signal?: AbortSignal): Promise<Transfer> =>
    apiData(
      api.GET('/transactions/transfers/{id}', {
        params: { path: { id } },
        ...signalOption(signal),
      }),
    ),
};

export const PAGE_SIZE = 50;

/** Cursor-paginated list. The cursor stays in memory, never in the URL. */
export function useTransactionList(query: TransactionListQuery) {
  return useInfiniteQuery({
    queryKey: financeKeys.transactions(query),
    queryFn: ({ pageParam, signal }) =>
      transactionsApi.list(
        { ...query, limit: PAGE_SIZE, ...(pageParam ? { cursor: pageParam } : {}) },
        signal,
      ),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    placeholderData: keepPreviousData,
  });
}

export function useTransaction(id: string) {
  return useQuery({
    queryKey: financeKeys.transaction(id),
    queryFn: ({ signal }) => transactionsApi.get(id, signal),
  });
}

export function useTransactionAudit(id: string) {
  return useQuery({
    queryKey: financeKeys.transactionAudit(id),
    queryFn: ({ signal }) => transactionsApi.audit(id, signal),
  });
}

export function useTransactionAttachments(id: string) {
  return useQuery({
    queryKey: financeKeys.transactionAttachments(id),
    queryFn: ({ signal }) => transactionsApi.attachments(id, signal),
  });
}

export function useTransfer(id: string | undefined) {
  return useQuery({
    queryKey: financeKeys.transfer(id ?? ''),
    queryFn: ({ signal }) => transactionsApi.getTransfer(id ?? '', signal),
    enabled: Boolean(id),
  });
}
