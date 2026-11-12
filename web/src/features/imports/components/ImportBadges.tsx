import { StatusBadge } from '@/shared/components/StatusBadge';
import { useT } from '@/shared/i18n/I18nContext';
import { batchStatusView, rowStatusViewFor } from '../status';
import type { ImportBatch, ImportRow } from '../types';

/** An import's status: icon plus words, never color alone. */
export function ImportStatusBadge({
  batch,
}: {
  batch: Pick<ImportBatch, 'status' | 'error_code' | 'cancel_requested'>;
}) {
  const t = useT();
  const view = batchStatusView(batch);
  return (
    <StatusBadge tone={view.tone} icon={view.icon}>
      {t(view.label)}
    </StatusBadge>
  );
}

export function RowStatusBadge({ row }: { row: Pick<ImportRow, 'status' | 'error_code'> }) {
  const t = useT();
  const view = rowStatusViewFor(row);
  return (
    <StatusBadge tone={view.tone} icon={view.icon}>
      {t(view.label)}
    </StatusBadge>
  );
}
