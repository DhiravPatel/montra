import { useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { useT } from '@/shared/i18n/I18nContext';
import { usePagePreview } from '../api';
import type { ReceiptPage } from '../types';
import { useOpenFile } from '../useOpenFile';

type PageKind = 'image' | 'pdf' | 'other';

function pageKind(page: ReceiptPage): PageKind {
  if (page.content_type?.startsWith('image/')) return 'image';
  if (page.content_type === 'application/pdf') return 'pdf';
  return 'other';
}

/** The receipt's pages: images inline, PDFs as a download (each through a short-lived link). */
export function ReceiptPreview({ pages }: { pages: readonly ReceiptPage[] }) {
  const t = useT();
  const ordered = [...pages].sort((a, b) => a.page_no - b.page_no);
  const [selected, setSelected] = useState(0);
  const index = Math.min(selected, ordered.length - 1);
  const page = ordered[index];
  if (!page) return <EmptyState icon="image" title={t('receipts.preview.none')} />;
  return (
    <div className="space-y-4">
      {ordered.length > 1 ? (
        <div role="group" aria-label={t('receipts.preview.pages')} className="flex flex-wrap gap-2">
          {ordered.map((item, position) => (
            <Button
              key={item.file_id}
              size="sm"
              variant={position === index ? 'primary' : 'secondary'}
              aria-pressed={position === index}
              onClick={() => {
                setSelected(position);
              }}
            >
              {t('receipts.preview.page', { page: position + 1 })}
            </Button>
          ))}
        </div>
      ) : null}
      <PageView key={page.file_id} page={page} number={index + 1} count={ordered.length} />
    </div>
  );
}

function PageView({ page, number, count }: { page: ReceiptPage; number: number; count: number }) {
  const t = useT();
  const { open, opening } = useOpenFile();
  const kind = pageKind(page);
  const preview = usePagePreview(page.file_id, kind !== 'pdf');
  const [broken, setBroken] = useState(false);
  const name =
    count > 1
      ? t('receipts.preview.alt', { page: number, count })
      : t('receipts.preview.altSingle');

  let body;
  if (kind === 'pdf') {
    body = (
      <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed border-line px-4 py-10 text-center">
        <Icon name="file-text" className="size-8 text-fg-muted" />
        <p className="font-medium text-fg">{t('receipts.preview.pdf')}</p>
        <p className="text-sm text-fg-muted">{t('receipts.preview.pdfHelp')}</p>
      </div>
    );
  } else if (preview.isPending) {
    body = (
      <LoadingState label={t('receipts.preview.loading')}>
        <Skeleton className="h-80 w-full" />
      </LoadingState>
    );
  } else if (preview.isError) {
    body = (
      <ErrorState
        titleAs="p"
        title={t('receipts.preview.error')}
        error={preview.error}
        retrying={preview.isFetching}
        onRetry={() => {
          void preview.refetch();
        }}
      />
    );
  } else if (!preview.data.src || broken) {
    body = (
      <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed border-line px-4 py-10 text-center">
        <Icon name="image" className="size-8 text-fg-muted" />
        <p className="text-sm text-fg-muted">{t('receipts.preview.unavailable')}</p>
      </div>
    );
  } else {
    body = (
      <img
        src={preview.data.src}
        alt={name}
        className="mx-auto max-h-[70vh] w-auto max-w-full rounded-lg border border-line bg-surface-muted object-contain"
        onError={() => {
          setBroken(true);
        }}
      />
    );
  }

  return (
    <figure className="space-y-3">
      {body}
      <figcaption className="flex flex-wrap items-center justify-between gap-3 text-sm text-fg-muted">
        <span>{name}</span>
        <Button
          variant="secondary"
          size="sm"
          loading={opening === page.file_id}
          onClick={() => {
            void open(page.file_id);
          }}
        >
          <Icon name={kind === 'pdf' ? 'download' : 'external-link'} className="size-4" />
          {kind === 'image'
            ? t('receipts.preview.openImage')
            : kind === 'pdf'
              ? t('receipts.preview.downloadPdf')
              : t('receipts.preview.openFile')}
        </Button>
      </figcaption>
    </figure>
  );
}
