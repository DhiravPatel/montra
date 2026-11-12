import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import { formatMoney } from '@/shared/formatting/money';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type {
  Receipt,
  ReceiptExtraction,
  ReceiptMatchCandidate,
  ReceiptStatus,
  ReceiptStatusFilter,
} from './types';

/** Filter choices in the order shown; `''` is the inbox (everything not discarded). */
export const RECEIPT_STATUS_FILTERS = [
  '',
  'needs_review',
  'reviewed',
  'matched',
  'failed',
  'processing',
  'discarded',
] as const satisfies readonly ReceiptStatusFilter[];

export type ReceiptFilterChoice = (typeof RECEIPT_STATUS_FILTERS)[number];

const filters: ReadonlySet<string> = new Set(RECEIPT_STATUS_FILTERS);

export function isReceiptStatusFilter(value: string | null): value is ReceiptFilterChoice {
  return value !== null && filters.has(value);
}

export const receiptStatusLabel: Readonly<Record<ReceiptStatus, MessageKey>> = {
  uploaded: 'receipts.status.uploaded',
  processing: 'receipts.status.processing',
  needs_review: 'receipts.status.needs_review',
  reviewed: 'receipts.status.reviewed',
  matched: 'receipts.status.matched',
  failed: 'receipts.status.failed',
  discarded: 'receipts.status.discarded',
};

export const receiptStatusTone: Readonly<Record<ReceiptStatus, Tone>> = {
  uploaded: 'info',
  processing: 'info',
  needs_review: 'warning',
  reviewed: 'info',
  matched: 'success',
  failed: 'warning',
  discarded: 'neutral',
};

export const receiptStatusIcon: Readonly<Record<ReceiptStatus, IconName>> = {
  uploaded: 'upload',
  processing: 'clock',
  needs_review: 'pencil',
  reviewed: 'check',
  matched: 'link',
  failed: 'alert-triangle',
  discarded: 'archive',
};

export function receiptFilterLabel(filter: ReceiptFilterChoice): MessageKey {
  return filter === '' ? 'receipts.filter.inbox' : receiptStatusLabel[filter];
}

/**
 * The values the user entered or confirmed. Values that were read
 * automatically in the past are only shown as history, never as facts or
 * as suggestions for the form.
 */
export function reviewedValues(receipt: Pick<Receipt, 'current'>): ReceiptExtraction | null {
  const current = receipt.current;
  return current?.method === 'manual' && current.status === 'succeeded' ? current : null;
}

/** Values read automatically before (shown as read-only history). */
export function earlierValues(receipt: Pick<Receipt, 'current'>): ReceiptExtraction | null {
  const current = receipt.current;
  return current && current.method !== 'manual' && current.status === 'succeeded' ? current : null;
}

/** The API accepts details while a receipt is not linked, discarded or still processing. */
export function canReview(receipt: Pick<Receipt, 'status'>): boolean {
  return (
    receipt.status !== 'matched' &&
    receipt.status !== 'discarded' &&
    receipt.status !== 'processing'
  );
}

export function canMatch(receipt: Pick<Receipt, 'status' | 'transaction_id'>): boolean {
  return (
    !receipt.transaction_id && receipt.status !== 'discarded' && receipt.status !== 'processing'
  );
}

/** Recording a purchase needs reviewed values (the API never uses unreviewed ones). */
export function canRecord(receipt: Pick<Receipt, 'status' | 'transaction_id'>): boolean {
  return receipt.status === 'reviewed' && !receipt.transaction_id;
}

/*
 * Match reasons and value warnings come with stable codes (`reason_codes`,
 * `warning_codes`) next to the API's English text. Codes are shown in the
 * interface language; the English text is the fallback for anything newer
 * than this client (and for a reader's note, which is text by nature).
 */
type ReasonCode = ReceiptMatchCandidate['reason_codes'][number];

const reasonKeys: Readonly<Record<ReasonCode, MessageKey>> = {
  same_amount: 'receipts.match.reason.sameAmount',
  amount_close: 'receipts.match.reason.closeAmount',
  same_date: 'receipts.match.reason.sameDate',
  near_date: 'receipts.match.reason.nearDate',
  same_merchant: 'receipts.match.reason.sameMerchant',
};

export function candidateReasons(
  candidate: Pick<ReceiptMatchCandidate, 'reason_codes' | 'reasons'>,
  t: Translate,
): string[] {
  if (candidate.reason_codes.length === 0) return [...candidate.reasons];
  return candidate.reason_codes.map((code, index) =>
    Object.hasOwn(reasonKeys, code) ? t(reasonKeys[code]) : (candidate.reasons[index] ?? code),
  );
}

type WarningCode = ReceiptExtraction['warning_codes'][number];

const warningKeys: Readonly<Partial<Record<WarningCode, MessageKey>>> = {
  totals_mismatch: 'receipts.warning.sums',
  line_items_mismatch: 'receipts.warning.lineItems',
  amount_unreadable: 'receipts.warning.amountUnreadable',
  date_unreadable: 'receipts.warning.dateUnreadable',
  currency_unrecognized: 'receipts.warning.currencyUnrecognized',
  extractor_not_configured: 'receipts.warning.readingFailed',
  consent_required: 'receipts.warning.readingFailed',
  file_unavailable: 'receipts.warning.readingFailed',
  timeout: 'receipts.warning.readingFailed',
  provider_error: 'receipts.warning.readingFailed',
};

function money(amount: string, currency: string, locale: string): string {
  try {
    return formatMoney(amount, currency, locale);
  } catch {
    return `${amount} ${currency}`;
  }
}

/** The values' warnings in the interface language, each once. */
export function warningMessages(
  values: Pick<ReceiptExtraction, 'warnings' | 'warning_codes' | 'warning_params' | 'currency'>,
  t: Translate,
  locale: string,
): string[] {
  const messages = new Set<string>();
  if (values.warning_codes.length === 0) {
    // Values stored before codes existed: one neutral sentence for anything flagged.
    if (values.warnings.length > 0) messages.add(t('receipts.warning.other'));
    return [...messages];
  }
  values.warning_codes.forEach((code, index) => {
    const params = values.warning_params[index] ?? {};
    const text = values.warnings[index];
    if (code === 'reader_note') {
      if (text) messages.add(text);
      return;
    }
    if (code === 'line_items_mismatch' && params.line_items_total && params.subtotal) {
      const currency = params.currency ?? values.currency ?? '';
      messages.add(
        t('receipts.warning.lineItemsDetail', {
          items: money(params.line_items_total, currency, locale),
          subtotal: money(params.subtotal, currency, locale),
        }),
      );
      return;
    }
    if (code === 'amount_unreadable' && params.value) {
      messages.add(t('receipts.warning.amountUnreadableValue', { value: params.value }));
      return;
    }
    const key = warningKeys[code];
    messages.add(key ? t(key) : (text ?? t('receipts.warning.other')));
  });
  return [...messages];
}

export function extractionMethodLabel(method: string): MessageKey {
  return method === 'manual' ? 'receipts.history.manual' : 'receipts.history.automatic';
}

const extractionStatusLabels: Readonly<Record<string, MessageKey>> = {
  queued: 'receipts.history.status.queued',
  running: 'receipts.history.status.running',
  succeeded: 'receipts.history.status.succeeded',
  failed: 'receipts.history.status.failed',
};

export function extractionStatusLabel(status: string): MessageKey {
  return extractionStatusLabels[status] ?? 'receipts.history.status.other';
}
