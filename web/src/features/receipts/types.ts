import type { components, operations } from '@/shared/api/schema';

/** Receipt types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type Receipt = Schemas['ReceiptDTO'];
export type ReceiptDetail = Schemas['ReceiptDetail'];
export type ReceiptStatus = Receipt['status'];
export type ReceiptPage = Schemas['ReceiptFile'];
export type ReceiptExtraction = Schemas['ReceiptExtractionDTO'];
export type ReceiptExtractionSummary = Schemas['ReceiptExtractionSummary'];
export type ReceiptLineItem = Schemas['ReceiptLineItemDTO'];
export type ReceiptReviewInput = Schemas['ReceiptReviewInput'];
export type ReceiptLineItemInput = Schemas['ReceiptLineItemInput'];
export type ReceiptMatchCandidate = Schemas['ReceiptMatchCandidate'];
export type ReceiptCreateTransactionInput = Schemas['ReceiptCreateTransactionInput'];
export type FileAccess = Schemas['Access'];

/** `''` is the inbox: every receipt except discarded ones. */
export type ReceiptStatusFilter = NonNullable<
  NonNullable<operations['receipts-list']['parameters']['query']>['status']
>;
