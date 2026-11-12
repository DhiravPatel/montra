import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import type { ImportBatch, ImportRow, ImportRowStatus, ImportStatus } from './types';

/*
 * Import and row states as the server reports them. The maps are typed
 * against the generated unions, so a status added to the contract fails
 * compilation until it has a label.
 */

export const IMPORT_STATUSES = [
  'awaiting_upload',
  'uploaded',
  'parsing',
  'needs_mapping',
  'preview_ready',
  'confirmed',
  'processing',
  'completed',
  'completed_with_errors',
  'failed',
  'cancelled',
] as const satisfies readonly ImportStatus[];

type MissingImportStatuses = Exclude<ImportStatus, (typeof IMPORT_STATUSES)[number]>;
/** Compile-time check: every contract import status is listed above. */
export const importStatusesAreListed: [MissingImportStatuses] extends [never]
  ? true
  : MissingImportStatuses = true;

export interface StatusView {
  label: MessageKey;
  tone: Tone;
  icon: IconName;
}

const importStatusView: Readonly<Record<ImportStatus, StatusView>> = {
  awaiting_upload: { label: 'imports.status.awaiting_upload', tone: 'neutral', icon: 'clock' },
  uploaded: { label: 'imports.status.uploaded', tone: 'info', icon: 'clock' },
  parsing: { label: 'imports.status.parsing', tone: 'info', icon: 'refresh' },
  needs_mapping: { label: 'imports.status.needs_mapping', tone: 'warning', icon: 'table' },
  preview_ready: { label: 'imports.status.preview_ready', tone: 'info', icon: 'list' },
  confirmed: { label: 'imports.status.confirmed', tone: 'info', icon: 'clock' },
  processing: { label: 'imports.status.processing', tone: 'info', icon: 'refresh' },
  completed: { label: 'imports.status.completed', tone: 'success', icon: 'check-circle' },
  completed_with_errors: {
    label: 'imports.status.completed_with_errors',
    tone: 'warning',
    icon: 'alert-triangle',
  },
  failed: { label: 'imports.status.failed', tone: 'danger', icon: 'alert-circle' },
  cancelled: { label: 'imports.status.cancelled', tone: 'neutral', icon: 'ban' },
};

/** Label, tone and icon for an import (an undone import reads "Undone", a stopping one "Stopping"). */
export function batchStatusView(
  batch: Pick<ImportBatch, 'status' | 'error_code' | 'cancel_requested'>,
): StatusView {
  if (batch.status === 'cancelled' && batch.error_code === 'rolled_back') {
    return { label: 'imports.status.rolledBack', tone: 'neutral', icon: 'undo' };
  }
  if (batch.status === 'processing' && batch.cancel_requested) {
    return { label: 'imports.status.stopping', tone: 'warning', icon: 'pause' };
  }
  return importStatusView[batch.status];
}

const rowStatusView: Readonly<Record<ImportRowStatus, StatusView>> = {
  parsed: { label: 'imports.rowStatus.parsed', tone: 'neutral', icon: 'clock' },
  ready: { label: 'imports.rowStatus.ready', tone: 'success', icon: 'check-circle' },
  duplicate: { label: 'imports.rowStatus.duplicate', tone: 'warning', icon: 'copy' },
  invalid: { label: 'imports.rowStatus.invalid', tone: 'danger', icon: 'alert-circle' },
  imported: { label: 'imports.rowStatus.imported', tone: 'success', icon: 'check' },
  skipped: { label: 'imports.rowStatus.skipped', tone: 'neutral', icon: 'skip-forward' },
  failed: { label: 'imports.rowStatus.failed', tone: 'danger', icon: 'x-circle' },
};

/**
 * The row's transaction was removed when the import was undone (the server
 * keeps `transaction_id` on the row, but that transaction is voided).
 */
export function isRemovedByUndo(row: Pick<ImportRow, 'error_code'>): boolean {
  return row.error_code === 'rolled_back';
}

export function rowStatusViewFor(row: Pick<ImportRow, 'status' | 'error_code'>): StatusView {
  if (isRemovedByUndo(row)) {
    return { label: 'imports.rowStatus.removed', tone: 'neutral', icon: 'undo' };
  }
  if (row.status === 'duplicate' && row.error_code === 'already_imported') {
    return { label: 'imports.rowStatus.alreadyImported', tone: 'neutral', icon: 'copy' };
  }
  return rowStatusView[row.status];
}

/** The server is still working on the import (reading, re-reading or importing): poll it. */
export function isBusy(status: ImportStatus | undefined): boolean {
  return (
    status === 'uploaded' ||
    status === 'parsing' ||
    status === 'confirmed' ||
    status === 'processing'
  );
}

/** Finished one way or another (summary, retry and undo live here). */
export function isFinished(status: ImportStatus): boolean {
  return status === 'completed' || status === 'completed_with_errors' || status === 'cancelled';
}

/** Columns and rows can still be changed (before confirmation). */
export function isReviewable(status: ImportStatus): boolean {
  return status === 'needs_mapping' || status === 'preview_ready';
}

/** The server accepts a cancel (processing stops between rows). */
export function canCancel(batch: Pick<ImportBatch, 'status' | 'cancel_requested'>): boolean {
  switch (batch.status) {
    case 'awaiting_upload':
    case 'uploaded':
    case 'parsing':
    case 'needs_mapping':
    case 'preview_ready':
    case 'confirmed':
      return true;
    case 'processing':
      return !batch.cancel_requested;
    default:
      return false;
  }
}

/** Something was imported and the import is over, so it can be undone. */
export function canRollback(batch: Pick<ImportBatch, 'status' | 'imported_count'>): boolean {
  return isFinished(batch.status) && batch.imported_count > 0;
}

export const ROW_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Accepts only well-formed IDs from the URL (anything else is ignored). */
export function uuidParam(value: string | null): string | null {
  return value && ROW_ID_PATTERN.test(value) ? value : null;
}
