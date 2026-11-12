import type { MessageKey, Translate } from '@/shared/i18n/types';
import { reasonCodeText } from '@/features/reconciliation/reasons';
import type { ImportBatch, ImportRow } from './types';

/*
 * Every import row and every failed or undone import carries the server's
 * reason: a stable `error_code`, the values it refers to (`error_params`),
 * for rows the value to correct (`error_field`) and, for possible
 * duplicates, the matcher's `duplicate_reason_codes`. Known codes are
 * explained in the interface language; an unknown code shows the server's
 * own English words, so a reason is never hidden.
 */

const rowReasonKeys: Readonly<Record<string, MessageKey>> = {
  preamble: 'imports.reason.preamble',
  header: 'imports.reason.header',
  missing_date: 'imports.reason.missing_date',
  zero_amount: 'imports.reason.zero_amount',
  both_debit_credit: 'imports.reason.both_debit_credit',
  rolled_back: 'imports.reason.rolled_back',
  reconciled: 'imports.reason.reconciled',
  // Processing: the ledger refused the row (status `failed`).
  invalid_date: 'imports.reason.invalid_date',
  invalid_amount: 'imports.reason.invalid_amount',
  invalid_category: 'imports.reason.invalid_category',
  invalid_description: 'imports.reason.invalid_description',
  invalid_reference: 'imports.reason.invalid_reference',
  invalid_row: 'imports.reason.invalid_row',
  rejected: 'imports.reason.rejected',
  // Domain rules a row can hit while it is imported.
  account_inactive: 'finance.rule.account_inactive',
};

type RowReasonInput = Pick<
  ImportRow,
  | 'status'
  | 'error_code'
  | 'error_message'
  | 'error_params'
  | 'error_field'
  | 'duplicate_reason_codes'
>;

/** The reason a row is not (or was not) imported as is; null when there is none. */
export function rowReason(
  row: RowReasonInput,
  batch: Pick<ImportBatch, 'currency' | 'mapping'>,
  t: Translate,
  locale: string,
): string | null {
  const code = row.error_code;
  const message = row.error_message ?? '';
  if (!code) return message || null;
  const params = row.error_params ?? {};
  const key = rowReasonKeys[code];
  if (key) return t(key);
  switch (code) {
    case 'bad_date': {
      const format = params.format ?? batch.mapping?.date_format;
      return format
        ? t('imports.reason.bad_date', { format })
        : t('imports.reason.bad_date_generic');
    }
    case 'bad_amount':
      return t('imports.reason.bad_amount', { currency: params.currency ?? batch.currency });
    case 'currency_mismatch': {
      const currency = params.currency;
      return currency
        ? t('imports.reason.currency_mismatch', { currency })
        : t('imports.reason.currency_mismatch_generic');
    }
    case 'already_imported':
      return params.matched_by === 'external_id'
        ? t('imports.reason.already_imported_reference')
        : t('imports.reason.already_imported');
    case 'possible_duplicate': {
      const codes = row.duplicate_reason_codes ?? [];
      if (codes.length === 0) return t('imports.reason.possible_duplicate_generic');
      const reasons = codes
        .map((reason) => reasonCodeText(reason, params, t, locale, undefined, batch.currency))
        .join(', ');
      return t('imports.reason.possible_duplicate', { reasons });
    }
  }
  if (row.status === 'failed') {
    // A code this client does not know: the server's specific English reason, if it has one.
    if (!message || GENERIC_MESSAGES.has(message)) return t('imports.reason.failed_values');
    return t('imports.reason.failed', { reason: message });
  }
  return message || null;
}

/** Envelope messages that say nothing about the row itself. */
const GENERIC_MESSAGES: ReadonlySet<string> = new Set([
  'The request could not be processed.',
  'Request failed.',
]);

type ErrorField = NonNullable<ImportRow['error_field']>;

const fieldHints: Readonly<Record<ErrorField, MessageKey>> = {
  posted_date: 'imports.fix.hint.posted_date',
  amount: 'imports.fix.hint.amount',
  category_id: 'imports.fix.hint.category_id',
  description: 'imports.fix.hint.description',
};

/** "Correct the date" — which value the server says to fix, when it names one. */
export function fieldHint(field: ImportRow['error_field'], t: Translate): string | null {
  return field && Object.hasOwn(fieldHints, field) ? t(fieldHints[field]) : null;
}

const batchReasonKeys: Readonly<Record<string, MessageKey>> = {
  unsupported_format: 'imports.batchReason.unsupported_format',
  pdf_needs_ai: 'imports.batchReason.pdf',
  pdf_unreadable: 'imports.batchReason.pdf',
  empty: 'imports.batchReason.empty',
  too_large: 'imports.batchReason.too_large',
  too_many_rows: 'imports.batchReason.too_many_rows',
  too_many_columns: 'imports.batchReason.too_many_columns',
  malformed: 'imports.batchReason.malformed',
  file_unavailable: 'imports.batchReason.file_unavailable',
};

function count(value: string | undefined): number | null {
  return value !== undefined && /^\d+$/.test(value) ? Number(value) : null;
}

/** Why an import failed or how an undo ended; null when the server gave no reason. */
export function batchReason(
  batch: Pick<ImportBatch, 'error_code' | 'error_message' | 'error_params'>,
  t: Translate,
): string | null {
  const code = batch.error_code;
  const message = batch.error_message ?? '';
  if (!code) return message || null;
  const params = batch.error_params ?? {};
  const key = batchReasonKeys[code];
  if (key) return t(key);
  if (code === 'currency_mismatch') {
    const statement = params.statement_currency;
    const account = params.account_currency;
    return statement && account
      ? t('imports.batchReason.currency_mismatch', { statement, account })
      : t('imports.batchReason.currency_mismatch_generic');
  }
  if (code === 'rolled_back') {
    const removed = count(params.voided);
    const kept = count(params.kept);
    if (removed === null || kept === null) {
      return message || t('imports.batchReason.rolled_back_generic');
    }
    return t('imports.batchReason.rolled_back', { removed, kept });
  }
  return message || null;
}

type NoteCode = ImportBatch['mapping_note_codes'][number];

const noteKeys: Readonly<Partial<Record<NoteCode, MessageKey>>> = {
  no_header_row: 'imports.note.noHeader',
  unknown_date_format: 'imports.note.unknownDateFormat',
  decimal_comma: 'imports.note.decimalComma',
  mapping_incomplete: 'imports.note.incomplete',
  check_sign_convention: 'imports.note.checkSign',
};

/**
 * The server's notes about its suggested column mapping, in the interface
 * language by `mapping_note_codes` (a note newer than this client is shown
 * as the server wrote it).
 */
export function mappingNotes(
  batch: Pick<ImportBatch, 'mapping_notes' | 'mapping_note_codes' | 'mapping_note_params'>,
  t: Translate,
): string[] {
  if (batch.mapping_note_codes.length === 0) return [...batch.mapping_notes];
  return batch.mapping_note_codes.map((code, index) => {
    const fallback = batch.mapping_notes[index] ?? code;
    if (code === 'ambiguous_date_order') {
      const format = batch.mapping_note_params.assumed_date_format;
      return format ? t('imports.note.ambiguousDates', { format }) : fallback;
    }
    const key = noteKeys[code];
    return key ? t(key) : fallback;
  });
}
