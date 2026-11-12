import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type ChangeEvent, useEffect, useRef, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { buttonClasses } from '@/shared/components/buttonStyles';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Spinner } from '@/shared/components/Spinner';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { receiptPath } from '@/shared/config/paths';
import { filePolicies, uploadFile } from '@/shared/files/upload';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { invalidateFinance } from '@/shared/finance/keys';
import type { Attachment } from '@/shared/finance/types';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { cx } from '@/shared/utils/cx';
import {
  failedForSure,
  fileProblem,
  fileProblemMessage,
  uploadErrorMessage,
  wasStopped,
} from '@/shared/files/uploadChecks';
import { transactionsApi, useTransaction, useTransactionAttachments } from '../api';

const PURPOSE = 'transaction_attachment';

function formatSize(bytes: number | undefined, locale: string): string | null {
  if (bytes === undefined) return null;
  const units = ['byte', 'kilobyte', 'megabyte'] as const;
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return new Intl.NumberFormat(locale, {
    style: 'unit',
    unit: units[unit],
    unitDisplay: 'short',
    maximumFractionDigits: unit === 0 ? 0 : 1,
  }).format(value);
}

/** Why a file could not be attached, in the interface language. */
function attachErrorMessage(error: unknown, t: Translate, locale: string): string {
  const rule = domainRuleCode(error);
  if (rule?.code === 'file_not_attachable') return t('transactions.attachments.notAttachable');
  if (rule?.code === 'file_not_ready') return t('transactions.attachments.notReady');
  return uploadErrorMessage(error, t, locale);
}

interface AttachmentsCardProps {
  transactionId: string;
  editable: boolean;
}

interface UploadProgress {
  index: number;
  total: number;
  name: string;
}

/**
 * Files attached to a transaction (receipts, invoices). Opening one asks the
 * API for a short-lived link. Editors can attach photos or PDFs: each is
 * uploaded (intent → bytes → complete) and then linked to the transaction.
 */
export function AttachmentsCard({ transactionId, editable }: AttachmentsCardProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const attachments = useTransactionAttachments(transactionId);
  // Already loaded by the detail page; tells whether a receipt from the inbox is linked.
  const transaction = useTransaction(transactionId);
  const receiptId = transaction.data?.receipt_id;
  const [opening, setOpening] = useState<string | null>(null);
  const [detaching, setDetaching] = useState<Attachment | null>(null);
  const [detachError, setDetachError] = useState<string | null>(null);
  const [upload, setUpload] = useState<UploadProgress | null>(null);
  const [uploadProblems, setUploadProblems] = useState<string[]>([]);
  const [notice, setNotice] = useState<string | null>(null);
  const uploads = useRef<{ controller: AbortController | null; alive: boolean }>({
    controller: null,
    alive: true,
  });
  const detach = useMutation({
    mutationFn: (fileId: string) => transactionsApi.detach(transactionId, fileId),
    onSettled: () => invalidateFinance(queryClient),
  });

  useEffect(() => {
    const current = uploads.current;
    current.alive = true;
    return () => {
      current.alive = false;
      current.controller?.abort();
    };
  }, []);

  const open = async (attachment: Attachment) => {
    if (opening) return;
    // Open the tab now (inside the click) so pop-up blockers allow it; point it at the file once the link is issued.
    const tab = window.open('', '_blank');
    if (tab) tab.opener = null;
    setOpening(attachment.file_id);
    try {
      const access = await transactionsApi.fileAccess(attachment.file_id);
      if (tab) tab.location.href = access.url;
      else window.location.assign(access.url);
    } catch (error) {
      tab?.close();
      toast.show({
        tone: 'danger',
        title: t('transactions.attachments.openFailed'),
        description: describeError(error, t),
      });
    } finally {
      setOpening(null);
    }
  };

  const confirmDetach = () => {
    if (!detaching || detach.isPending) return;
    setDetachError(null);
    detach.mutate(detaching.file_id, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('transactions.attachments.detached') });
        setDetaching(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          setDetaching(null);
          return;
        }
        setDetachError(describeError(error, t));
      },
    });
  };

  const attachFiles = async (picked: readonly File[]) => {
    if (upload || picked.length === 0) return;
    const problems: string[] = [];
    const valid: File[] = [];
    for (const file of picked) {
      const problem = fileProblem(file, PURPOSE);
      if (problem) {
        problems.push(
          t('transactions.attachments.failedFile', {
            name: file.name,
            reason: fileProblemMessage(problem, PURPOSE, t, formatLocale),
          }),
        );
      } else {
        valid.push(file);
      }
    }
    setUploadProblems(problems);
    setNotice(null);
    if (valid.length === 0) return;

    const current = uploads.current;
    const controller = new AbortController();
    current.controller = controller;
    let attached = 0;
    try {
      for (const [index, file] of valid.entries()) {
        setUpload({ index: index + 1, total: valid.length, name: file.name });
        try {
          const record = await uploadFile(file, { purpose: PURPOSE, signal: controller.signal });
          try {
            await transactionsApi.attach(transactionId, record.id);
          } catch (error) {
            // A refused file would only use storage; after a lost answer it may be attached, so keep it.
            if (failedForSure(error)) {
              void transactionsApi.deleteFile(record.id).catch(() => undefined);
            }
            throw error;
          }
          attached += 1;
        } catch (error) {
          if (wasStopped(error, controller.signal)) throw error;
          problems.push(
            t('transactions.attachments.failedFile', {
              name: file.name,
              reason: attachErrorMessage(error, t, formatLocale),
            }),
          );
          if (current.alive) setUploadProblems([...problems]);
        }
      }
    } catch (error) {
      if (current.alive) {
        setNotice(
          wasStopped(error, controller.signal)
            ? t('transactions.attachments.stopped')
            : describeError(error, t),
        );
      }
    } finally {
      current.controller = null;
      if (current.alive) setUpload(null);
    }
    if (attached > 0) {
      void invalidateFinance(queryClient);
      if (current.alive) {
        toast.show({
          tone: 'success',
          title: t('transactions.attachments.attached', { count: attached }),
        });
      }
    }
  };

  const onPick = (event: ChangeEvent<HTMLInputElement>) => {
    void attachFiles(Array.from(event.target.files ?? []));
    // Allow picking the same file again.
    event.target.value = '';
  };

  let content;
  if (attachments.isPending) {
    content = <LoadingState label={t('transactions.attachments.loading')} />;
  } else if (attachments.isError) {
    content = (
      <ErrorState
        title={t('transactions.attachments.error')}
        error={attachments.error}
        retrying={attachments.isFetching}
        onRetry={() => {
          void attachments.refetch();
        }}
      />
    );
  } else if (attachments.data.length === 0) {
    content = (
      <EmptyState
        icon="paperclip"
        title={t('transactions.attachments.empty')}
        description={t('transactions.attachments.emptyBody')}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {attachments.data.map((attachment) => {
          const name = attachment.filename ?? t('transactions.attachments.unnamed');
          const attached = parseTimestamp(attachment.attached_at);
          const details = [
            attachment.content_type,
            formatSize(attachment.size_bytes, formatLocale),
            attached ? formatDateTime(attached, formatLocale) : null,
          ].filter(Boolean);
          return (
            <li
              key={attachment.file_id}
              className="flex flex-col gap-3 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
            >
              <div className="flex min-w-0 flex-1 items-start gap-3">
                <Icon name="file" className="mt-0.5 text-fg-muted" />
                <div className="min-w-0">
                  <p className="break-words font-medium text-fg">{name}</p>
                  <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
                </div>
              </div>
              <div className="flex shrink-0 gap-2">
                <Button
                  variant="secondary"
                  size="sm"
                  loading={opening === attachment.file_id}
                  aria-label={`${t('transactions.attachments.open')}: ${name}`}
                  onClick={() => {
                    void open(attachment);
                  }}
                >
                  <Icon name="external-link" className="size-4" />
                  {t('transactions.attachments.open')}
                </Button>
                {editable ? (
                  <Button
                    variant="secondary"
                    size="sm"
                    aria-label={`${t('transactions.attachments.detach')}: ${name}`}
                    onClick={() => {
                      setDetachError(null);
                      setDetaching(attachment);
                    }}
                  >
                    <Icon name="x" className="size-4" />
                    {t('transactions.attachments.detach')}
                  </Button>
                ) : null}
              </div>
            </li>
          );
        })}
      </ul>
    );
  }

  const actions =
    receiptId || editable ? (
      <>
        {receiptId ? (
          <ButtonLink to={receiptPath(receiptId)} variant="ghost" size="sm">
            <Icon name="receipt" className="size-4" />
            {t('transactions.attachments.openReceipt')}
          </ButtonLink>
        ) : null}
        {editable ? (
          <label
            className={buttonClasses(
              'secondary',
              'sm',
              cx(
                'cursor-pointer has-[:focus-visible]:outline-3 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-focus',
                upload && 'pointer-events-none opacity-60',
              ),
            )}
          >
            <Icon name="upload" className="size-4" />
            {t('transactions.attachments.attach')}
            <input
              type="file"
              multiple
              accept={filePolicies[PURPOSE].accept}
              className="sr-only"
              disabled={upload !== null}
              onChange={onPick}
            />
          </label>
        ) : null}
      </>
    ) : undefined;

  return (
    <Card title={t('transactions.attachments.title')} actions={actions}>
      {editable ? (
        <div className="mb-4 space-y-3 empty:hidden">
          {upload ? (
            <div className="flex flex-wrap items-center gap-3 rounded-lg border border-line bg-surface-muted px-3 py-2 text-sm">
              <Spinner size="sm" />
              <span className="min-w-0 flex-1 break-all text-fg">
                {t('transactions.attachments.uploading', {
                  name: upload.name,
                  index: upload.index,
                  total: upload.total,
                })}
              </span>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  uploads.current.controller?.abort();
                }}
              >
                {t('transactions.attachments.stop')}
              </Button>
            </div>
          ) : null}
          {uploadProblems.length > 0 ? (
            <Alert tone="danger" live="assertive" title={t('transactions.attachments.failedTitle')}>
              <ul className="list-disc space-y-1 ps-5">
                {uploadProblems.map((problem) => (
                  <li key={problem}>{problem}</li>
                ))}
              </ul>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setUploadProblems([]);
                }}
              >
                {t('transactions.attachments.dismiss')}
              </Button>
            </Alert>
          ) : null}
          {notice ? (
            <Alert tone="info" live="polite">
              {notice}
            </Alert>
          ) : null}
        </div>
      ) : null}
      <p role="status" className="sr-only">
        {upload
          ? t('transactions.attachments.uploading', {
              name: upload.name,
              index: upload.index,
              total: upload.total,
            })
          : ''}
      </p>
      {content}
      <ConfirmDialog
        open={detaching !== null}
        onOpenChange={(value) => {
          if (!value) setDetaching(null);
        }}
        title={t('transactions.attachments.detachTitle')}
        description={t('transactions.attachments.detachBody', {
          name: detaching?.filename ?? t('transactions.attachments.unnamed'),
        })}
        confirmLabel={t('transactions.attachments.detach')}
        onConfirm={confirmDetach}
        pending={detach.isPending}
        error={detachError}
      />
    </Card>
  );
}
