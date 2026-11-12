import type { Translate } from '@/shared/i18n/types';
import type { CountItem } from './components/CountGrid';
import type { ImportBatch } from './types';

/** Server counts while reviewing (before confirmation), including what confirming would import now. */
export function reviewCounts(batch: ImportBatch, t: Translate): CountItem[] {
  return [
    {
      key: 'toImport',
      label: t('imports.counts.toImport'),
      value: batch.to_import_rows,
      note: t('imports.counts.toImportNote'),
    },
    { key: 'total', label: t('imports.counts.total'), value: batch.total_rows },
    { key: 'valid', label: t('imports.counts.valid'), value: batch.valid_rows },
    {
      key: 'duplicates',
      label: t('imports.counts.duplicates'),
      value: batch.duplicate_rows,
      note: t('imports.counts.duplicatesNote'),
    },
    {
      key: 'invalid',
      label: t('imports.counts.invalid'),
      value: batch.invalid_rows,
      note: t('imports.counts.invalidNote'),
    },
  ];
}

/** Server counts once the import ran: imported, skipped, failed and duplicate rows. */
export function resultCounts(batch: ImportBatch, t: Translate): CountItem[] {
  return [
    { key: 'imported', label: t('imports.counts.imported'), value: batch.imported_count },
    { key: 'skipped', label: t('imports.counts.skipped'), value: batch.skipped_count },
    { key: 'failed', label: t('imports.counts.failed'), value: batch.failed_count },
    { key: 'duplicates', label: t('imports.counts.duplicates'), value: batch.duplicate_rows },
    { key: 'invalid', label: t('imports.counts.invalid'), value: batch.invalid_rows },
    { key: 'total', label: t('imports.counts.total'), value: batch.total_rows },
  ];
}
