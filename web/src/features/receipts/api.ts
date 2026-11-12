import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { fileAccess, type FilePreview, loadFilePreview } from '@/shared/files/preview';
import { receiptsKeys } from './keys';
import type {
  FileAccess,
  Receipt,
  ReceiptCreateTransactionInput,
  ReceiptDetail,
  ReceiptMatchCandidate,
  ReceiptReviewInput,
  ReceiptStatusFilter,
} from './types';

/** Receipts per inbox page (the API allows up to 200); the next page follows `meta.next_cursor`. */
export const RECEIPT_PAGE_SIZE = 50;

export interface ReceiptPage {
  items: Receipt[];
  nextCursor: string | null;
  hasMore: boolean;
}

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

function path(id: string) {
  return { params: { path: { id } } };
}

/**
 * Receipt inbox (spec §4.9). People enter every value themselves: receipts
 * are created without asking for reading (`read_automatically` is never
 * sent), and automatic reading (POST /receipts/{id}/process) is never
 * requested.
 */
export const receiptsApi = {
  list: async (
    status: ReceiptStatusFilter,
    cursor: string | null,
    signal?: AbortSignal,
  ): Promise<ReceiptPage> => {
    const envelope = await apiEnvelope(
      api.GET('/receipts', {
        params: {
          query: {
            ...(status ? { status } : {}),
            ...(cursor ? { cursor } : {}),
            limit: RECEIPT_PAGE_SIZE,
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
  get: (id: string, signal?: AbortSignal): Promise<ReceiptDetail> =>
    apiData(api.GET('/receipts/{id}', { ...path(id), ...signalOption(signal) })),
  /**
   * One receipt from ready files with purpose `receipt`, in page order. A
   * retry with the same Idempotency-Key and body returns the first receipt.
   */
  create: (fileIds: readonly string[], notes: string, key: string): Promise<Receipt> =>
    apiData(
      api.POST('/receipts', {
        params: { header: { 'Idempotency-Key': key } },
        body: { file_ids: [...fileIds], ...(notes ? { notes } : {}) },
      }),
    ),
  /** Stores every value as a new reviewed version (`version` guards against lost updates). */
  review: (id: string, body: ReceiptReviewInput): Promise<Receipt> =>
    apiData(api.PATCH('/receipts/{id}/review', { ...path(id), body })),
  matchCandidates: (id: string, signal?: AbortSignal): Promise<ReceiptMatchCandidate[]> =>
    apiData(api.GET('/receipts/{id}/match-candidates', { ...path(id), ...signalOption(signal) })),
  /** Links an existing transaction (no new money is recorded). */
  match: (id: string, transactionId: string): Promise<Receipt> =>
    apiData(
      api.POST('/receipts/{id}/match-transaction', {
        ...path(id),
        body: { transaction_id: transactionId },
      }),
    ),
  /** A financial write: a retry with the same key replays the first result. */
  createTransaction: (
    id: string,
    body: ReceiptCreateTransactionInput,
    key: string,
  ): Promise<Receipt> =>
    apiData(
      api.POST('/receipts/{id}/create-transaction', {
        params: { path: { id }, header: { 'Idempotency-Key': key } },
        body,
      }),
    ),
  unlink: (id: string): Promise<Receipt> => apiData(api.POST('/receipts/{id}/unlink', path(id))),
  /** Removes the receipt from the inbox (and unlinks it); its files are kept. `version` guards the state seen. */
  discard: (id: string, version: number): Promise<Receipt> =>
    apiData(api.POST('/receipts/{id}/discard', { params: { path: { id }, query: { version } } })),
  /** Brings a discarded receipt back (reviewed when its values are the reviewed version, else needs_review). */
  restore: (id: string, version: number): Promise<Receipt> =>
    apiData(api.POST('/receipts/{id}/restore', { params: { path: { id }, query: { version } } })),
  /** A short-lived signed link (authorization is checked on every call). */
  fileAccess: (fileId: string, signal?: AbortSignal): Promise<FileAccess> =>
    fileAccess(fileId, signal),
  /** Deletes an uploaded page that never became part of a receipt. */
  deleteFile: (fileId: string) =>
    apiData(api.DELETE('/files/{fileId}', { params: { path: { fileId } } })),
};

/** The inbox, a page at a time ("Load more" follows the API's cursor; it never goes in the URL). */
export function useReceipts(status: ReceiptStatusFilter) {
  return useInfiniteQuery({
    queryKey: receiptsKeys.list(status),
    queryFn: ({ pageParam, signal }) => receiptsApi.list(status, pageParam, signal),
    initialPageParam: null as string | null,
    getNextPageParam: (page) => (page.hasMore ? page.nextCursor : null),
  });
}

export function useReceipt(id: string) {
  return useQuery({
    queryKey: receiptsKeys.detail(id),
    queryFn: ({ signal }) => receiptsApi.get(id, signal),
  });
}

export function useMatchCandidates(id: string, enabled: boolean) {
  return useQuery({
    queryKey: receiptsKeys.candidates(id),
    queryFn: ({ signal }) => receiptsApi.matchCandidates(id, signal),
    enabled,
  });
}

/** A page ready to show: images as a `data:` URL, other files (PDF) as `src: null`. */
export type PagePreview = FilePreview;

export function usePagePreview(fileId: string, enabled = true) {
  return useQuery({
    queryKey: receiptsKeys.preview(fileId),
    queryFn: ({ signal }) => loadFilePreview(fileId, signal),
    enabled,
    staleTime: Number.POSITIVE_INFINITY,
    refetchOnWindowFocus: false,
  });
}
