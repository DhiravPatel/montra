import { hasErrorCode } from '@/shared/api/errors';
import {
  domainRuleCode,
  domainRuleMessage,
  errorDetailCode,
  fieldIssueMessage,
} from '@/shared/finance/domainErrors';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

export type ReceiptAction =
  'create' | 'review' | 'match' | 'record' | 'unlink' | 'discard' | 'restore';

/**
 * 409 CONFLICT and DUPLICATE reasons (`details[0].code`, docs/API.md
 * "Receipts notes"): the receipt's state no longer allows the action, a page
 * belongs to another receipt, or the transaction already has a receipt.
 */
const conflictKeys: Readonly<Record<string, MessageKey>> = {
  file_in_use: 'receipts.errors.fileInUse',
  page_not_ready: 'receipts.errors.pagesNotReady',
  receipt_linked: 'receipts.errors.receiptLinked',
  receipt_discarded: 'receipts.errors.receiptDiscarded',
  receipt_processing: 'receipts.errors.receiptProcessing',
  receipt_not_linked: 'receipts.errors.unlinkConflict',
  receipt_not_discarded: 'receipts.errors.notDiscarded',
  transaction_has_receipt: 'receipts.errors.alreadyLinked',
};

/* A conflict without a code (older servers): the message depends on what the person tried. */
const fallbackConflictKeys: Readonly<Record<ReceiptAction, MessageKey>> = {
  create: 'receipts.errors.pagesNotReady',
  review: 'receipts.errors.reviewConflict',
  match: 'receipts.errors.matchConflict',
  record: 'receipts.errors.recordConflict',
  unlink: 'receipts.errors.unlinkConflict',
  discard: 'receipts.errors.receiptDiscarded',
  restore: 'receipts.errors.notDiscarded',
};

/** The coded reason of a receipt conflict (409 CONFLICT / DUPLICATE), if any. */
export function receiptConflictCode(error: unknown): string | null {
  return errorDetailCode(error, ['CONFLICT', 'DUPLICATE']);
}

/** Why a receipt action failed, in the interface language (field errors are shown on fields). */
export function receiptErrorMessage(
  error: unknown,
  action: ReceiptAction,
  t: Translate,
  locale: string,
): string {
  const rule = domainRuleCode(error);
  if (rule?.code === 'receipt_not_reviewed') return t('receipts.errors.notReviewed');
  if (rule?.code === 'receipt_incomplete') return t('receipts.errors.incomplete');
  const shared = domainRuleMessage(error, t, locale);
  if (shared) return shared;
  const conflict = receiptConflictCode(error);
  const conflictKey = conflict ? conflictKeys[conflict] : undefined;
  if (conflictKey) return t(conflictKey);
  if (hasErrorCode(error, 'DUPLICATE')) return t('receipts.errors.alreadyLinked');
  if (hasErrorCode(error, 'CONFLICT')) return t(fallbackConflictKeys[action]);
  if (hasErrorCode(error, 'VERSION_CONFLICT')) return t('finance.conflict.body');
  if (hasErrorCode(error, 'NOT_FOUND')) return t('receipts.errors.notFound');
  if (
    hasErrorCode(error, 'IDEMPOTENCY_CONFLICT') ||
    hasErrorCode(error, 'IDEMPOTENCY_IN_PROGRESS')
  ) {
    return t('finance.errors.maybeSaved');
  }
  if (hasErrorCode(error, 'VALIDATION_ERROR')) {
    if (action === 'match') return t('receipts.errors.transactionUnavailable');
    if (action === 'create') {
      const coded = error.details.find((detail) => detail.code);
      return coded ? fieldIssueMessage(coded, t) : t('receipts.errors.pagesInvalid');
    }
  }
  return describeError(error, t);
}
