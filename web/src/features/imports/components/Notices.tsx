import type { ReactNode } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Spinner } from '@/shared/components/Spinner';
import { TextLink } from '@/shared/components/TextLink';
import { importPath } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { batchReason } from '../reasons';
import type { ImportBatch } from '../types';

/** The server is working on the import; announced politely, with a calm explanation. */
export function ProcessingNotice({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div
      role="status"
      className="flex items-start gap-3 rounded-lg border border-info/40 bg-info-soft p-4 text-sm text-fg"
    >
      <Spinner size="sm" className="mt-0.5 shrink-0 text-info" />
      <div className="min-w-0 space-y-1">
        <p className="font-semibold">{title}</p>
        {children ? <div className="text-fg-muted">{children}</div> : null}
      </div>
    </div>
  );
}

/** Why the import failed, or how its undo ended (the server's reason, localized when known). */
export function BatchReasonAlert({ batch }: { batch: ImportBatch }) {
  const t = useT();
  const reason = batchReason(batch, t);
  if (batch.status === 'failed') {
    return (
      <Alert tone="danger" title={t('imports.failed.title')}>
        <p>{reason ?? t('imports.failed.generic')}</p>
      </Alert>
    );
  }
  if (batch.error_code === 'rolled_back') {
    return (
      <Alert tone="info" title={t('imports.rollback.doneTitle')}>
        {reason ? <p>{reason}</p> : null}
      </Alert>
    );
  }
  if (batch.status === 'cancelled') {
    return (
      <Alert tone="info" title={t('imports.cancelled.title')}>
        <p>
          {reason ??
            (batch.imported_count > 0
              ? t('imports.cancelled.body')
              : t('imports.cancelled.nothing'))}
        </p>
      </Alert>
    );
  }
  return null;
}

/** The same file was already imported into this account (its rows show as duplicates). */
export function PreviousImportAlert({ batch }: { batch: ImportBatch }) {
  const t = useT();
  if (!batch.previous_import_of_file) return null;
  return (
    <Alert tone="warning" title={t('imports.previous.title')}>
      <p>{t('imports.previous.body')}</p>
      <p>
        <TextLink to={importPath(batch.previous_import_of_file)}>
          {t('imports.previous.link')}
        </TextLink>
      </p>
    </Alert>
  );
}
