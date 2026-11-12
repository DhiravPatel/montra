import type { ReceiptStatusFilter } from './types';

/**
 * Receipt query keys. Records start with `finance`, so invalidateFinance()
 * refreshes them after any financial write (linking a receipt changes a
 * transaction too). Page previews are file bytes, which never change for a
 * file ID: they stay outside `finance` so writes do not download them again.
 */
export const receiptsKeys = {
  all: ['finance', 'receipts'] as const,
  list: (status: ReceiptStatusFilter) => ['finance', 'receipts', { status }] as const,
  detail: (id: string) => ['finance', 'receipt', id] as const,
  candidates: (id: string) => ['finance', 'receipt', id, 'candidates'] as const,
  preview: (fileId: string) => ['receipt-page-preview', fileId] as const,
};
