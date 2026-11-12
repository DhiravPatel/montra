import type { MessageKey } from '@/shared/i18n/types';
import type { RowFilter } from './types';

export const filterLabels: Readonly<Record<RowFilter, MessageKey>> = {
  '': 'imports.rows.filter.all',
  parsed: 'imports.rows.filter.parsed',
  ready: 'imports.rows.filter.ready',
  duplicate: 'imports.rows.filter.duplicate',
  invalid: 'imports.rows.filter.invalid',
  skipped: 'imports.rows.filter.skipped',
  imported: 'imports.rows.filter.imported',
  failed: 'imports.rows.filter.failed',
};

/** Filters while reviewing (before confirmation) and after the import ran. */
export const REVIEW_FILTERS: readonly RowFilter[] = [
  '',
  'ready',
  'duplicate',
  'invalid',
  'skipped',
];
export const RESULT_FILTERS: readonly RowFilter[] = [
  '',
  'imported',
  'failed',
  'skipped',
  'duplicate',
  'invalid',
];
