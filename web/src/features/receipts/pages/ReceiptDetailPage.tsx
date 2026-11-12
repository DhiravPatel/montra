import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, receiptPath } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { receiptsApi, useReceipt } from '../api';
import { MatchTransactionDialog } from '../components/MatchTransactionDialog';
import { ReceiptHistoryCard } from '../components/ReceiptHistoryCard';
import { ReceiptLinkCard } from '../components/ReceiptLinkCard';
import { ReceiptPreview } from '../components/ReceiptPreview';
import { ReceiptReviewForm } from '../components/ReceiptReviewForm';
import { ReceiptStatusBadge } from '../components/ReceiptStatusBadge';
import { ReceiptValuesList } from '../components/ReceiptValuesList';
import { RecordExpenseDialog } from '../components/RecordExpenseDialog';
import { receiptConflictCode, receiptErrorMessage } from '../errors';
import { formatAddedOn } from '../format';
import { canMatch, canRecord, canReview, reviewedValues } from '../labels';
import type { ReceiptDetail } from '../types';

function DetailSkeleton() {
  return (
    <div className="space-y-6" aria-hidden="true">
      <Skeleton className="h-9 w-1/2" />
      <Skeleton className="h-80 w-full" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}

/** Read-only details when the receipt cannot be changed (linked, discarded or processing). */
function LockedDetails({ receipt }: { receipt: ReceiptDetail }) {
  const { t } = useI18n();
  const reviewed = reviewedValues(receipt);
  return (
    <div className="space-y-5">
      {receipt.status === 'matched' ? (
        <Alert tone="info">{t('receipts.detail.lockedLinked')}</Alert>
      ) : null}
      {receipt.status === 'processing' ? (
        <Alert tone="info">{t('receipts.detail.lockedProcessing')}</Alert>
      ) : null}
      {reviewed ? (
        <ReceiptValuesList values={reviewed} />
      ) : (
        <p className="text-sm text-fg-muted">{t('receipts.detail.noDetails')}</p>
      )}
    </div>
  );
}

/** One receipt: its pages, the person's review, the linked purchase and history. */
export function ReceiptDetailPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('receipts.detail.documentTitle'));
  const { receiptId = '' } = useParams();
  const user = useCurrentUser();
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();
  const query = useReceipt(receiptId);
  // One key per purchase draft, kept across dialog openings until a success.
  const recordKey = useIdempotencyKey();
  const [conflict, setConflict] = useState(false);
  const [recording, setRecording] = useState(false);
  const [matching, setMatching] = useState(false);
  const [discarding, setDiscarding] = useState(false);
  const [discardError, setDiscardError] = useState<string | null>(null);

  const unlink = useMutation({
    mutationFn: () => receiptsApi.unlink(receiptId),
    onSettled: () => invalidateFinance(queryClient),
  });
  // Discard and restore send the version on screen (409 VERSION_CONFLICT when it moved on).
  const discard = useMutation({
    mutationFn: (version: number) => receiptsApi.discard(receiptId, version),
    onSettled: () => invalidateFinance(queryClient),
  });
  const restore = useMutation({
    mutationFn: (version: number) => receiptsApi.restore(receiptId, version),
    onSettled: () => invalidateFinance(queryClient),
  });

  if (query.isPending) {
    return (
      <LoadingState label={t('receipts.detail.loading')}>
        <DetailSkeleton />
      </LoadingState>
    );
  }
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="receipt"
          title={t('receipts.detail.notFound')}
          description={t('receipts.detail.notFoundBody')}
          action={<ButtonLink to={paths.receipts}>{t('receipts.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('receipts.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const receipt = query.data;
  const reviewed = reviewedValues(receipt);
  const added = formatAddedOn(receipt.created_at, formatLocale, user.timezone);
  const summary = [
    added ? t('receipts.list.added', { date: added }) : null,
    t('receipts.list.pages', { count: receipt.files.length }),
  ].filter(Boolean);

  const runUnlink = () => {
    if (unlink.isPending) return;
    // A dialog left open when the receipt got linked (here or elsewhere) was
    // unmounted, not closed: unlinking must not bring it back.
    setMatching(false);
    setRecording(false);
    unlink.mutate(undefined, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('receipts.link.unlinked') });
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('receipts.link.unlinkFailed'),
          description: receiptErrorMessage(error, 'unlink', t, formatLocale),
        });
      },
    });
  };

  const confirmDiscard = () => {
    if (discard.isPending) return;
    setDiscardError(null);
    discard.mutate(receipt.version, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('receipts.discard.done') });
        setDiscarding(false);
        void navigate(paths.receipts);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          setDiscarding(false);
          void navigate(paths.receipts);
          return;
        }
        if (receiptConflictCode(error) === 'receipt_discarded') {
          // Already discarded elsewhere: the reloaded receipt shows it.
          setDiscarding(false);
          toast.show({ tone: 'info', title: t('receipts.errors.receiptDiscarded') });
          return;
        }
        setDiscardError(receiptErrorMessage(error, 'discard', t, formatLocale));
      },
    });
  };

  const runRestore = () => {
    if (restore.isPending) return;
    restore.mutate(receipt.version, {
      onSuccess: (restored) => {
        toast.show({
          tone: 'success',
          title: t('receipts.restore.done'),
          description:
            restored.status === 'reviewed'
              ? t('receipts.restore.doneReviewed')
              : t('receipts.restore.doneNeedsReview'),
        });
      },
      onError: (error) => {
        // A stale version or a receipt that is no longer discarded: the refreshed record tells.
        const stale =
          hasErrorCode(error, 'VERSION_CONFLICT') ||
          receiptConflictCode(error) === 'receipt_not_discarded';
        toast.show({
          tone: stale ? 'warning' : 'danger',
          title: stale ? t('finance.conflict.title') : t('receipts.restore.failed'),
          description: receiptErrorMessage(error, 'restore', t, formatLocale),
        });
      },
    });
  };

  return (
    <>
      <p className="mb-2">
        <TextLink to={paths.receipts}>
          <Icon name="arrow-left" className="me-1 inline size-4" />
          {t('receipts.backToList')}
        </TextLink>
      </p>
      <PageHeader
        title={reviewed?.merchant_name ?? t('receipts.detail.title')}
        description={summary.join(' · ')}
      />
      <div className="mb-6 flex flex-wrap gap-2">
        <ReceiptStatusBadge status={receipt.status} />
      </div>
      <div className="mb-6 space-y-4 empty:hidden">
        {receipt.duplicate_of_id ? (
          <Alert tone="warning" title={t('receipts.duplicate.title')}>
            <p>{t('receipts.duplicate.body')}</p>
            <p>
              <TextLink to={receiptPath(receipt.duplicate_of_id)}>
                {t('receipts.duplicate.open')}
              </TextLink>
            </p>
          </Alert>
        ) : null}
        {receipt.status === 'discarded' ? (
          <Alert tone="info" title={t('receipts.detail.discardedTitle')}>
            {t('receipts.detail.discardedBody')}
          </Alert>
        ) : null}
        {receipt.status === 'failed' ? (
          <Alert tone="info">{t('receipts.detail.failedBody')}</Alert>
        ) : null}
      </div>
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Card title={t('receipts.detail.pages')}>
            <ReceiptPreview pages={receipt.files} />
          </Card>
          <Card
            title={t('receipts.detail.details')}
            description={canReview(receipt) ? t('receipts.detail.detailsHelp') : undefined}
          >
            {conflict ? (
              <Alert
                tone="warning"
                live="assertive"
                className="mb-5"
                title={t('finance.conflict.title')}
              >
                {t('finance.conflict.body')}
              </Alert>
            ) : null}
            {canReview(receipt) ? (
              <ReceiptReviewForm
                key={receipt.version}
                receipt={receipt}
                onConflict={() => {
                  setConflict(true);
                  void query.refetch();
                }}
                onSaved={() => {
                  setConflict(false);
                }}
              />
            ) : (
              <LockedDetails receipt={receipt} />
            )}
          </Card>
        </div>
        <div className="space-y-6">
          <ReceiptLinkCard
            receipt={receipt}
            onRecord={() => {
              setRecording(true);
            }}
            onMatch={() => {
              setMatching(true);
            }}
            onUnlink={runUnlink}
            unlinking={unlink.isPending}
          />
          {receipt.notes ? (
            <Card title={t('receipts.detail.notes')}>
              <p className="whitespace-pre-line break-words text-fg">{receipt.notes}</p>
            </Card>
          ) : null}
          <ReceiptHistoryCard receipt={receipt} />
          <Card title={t('receipts.detail.manage')}>
            {receipt.status === 'discarded' ? (
              <div className="space-y-2">
                <Button variant="secondary" loading={restore.isPending} onClick={runRestore}>
                  <Icon name="undo" className="size-4" />
                  {t('receipts.restore.action')}
                </Button>
                <p className="text-sm text-fg-muted">{t('receipts.restore.help')}</p>
              </div>
            ) : (
              <div className="space-y-2">
                <Button
                  variant="secondary"
                  onClick={() => {
                    setDiscardError(null);
                    setDiscarding(true);
                  }}
                >
                  <Icon name="trash" className="size-4" />
                  {t('receipts.discard.action')}
                </Button>
                <p className="text-sm text-fg-muted">{t('receipts.discard.help')}</p>
              </div>
            )}
          </Card>
        </div>
      </div>
      {reviewed && canRecord(receipt) ? (
        <RecordExpenseDialog
          receiptId={receipt.id}
          values={reviewed}
          idempotency={recordKey}
          open={recording}
          onOpenChange={setRecording}
        />
      ) : null}
      {canMatch(receipt) ? (
        <MatchTransactionDialog receipt={receipt} open={matching} onOpenChange={setMatching} />
      ) : null}
      <ConfirmDialog
        open={discarding}
        onOpenChange={(open) => {
          if (!open) setDiscarding(false);
        }}
        title={t('receipts.discard.title')}
        description={
          receipt.transaction_id ? t('receipts.discard.bodyLinked') : t('receipts.discard.body')
        }
        confirmLabel={t('receipts.discard.confirm')}
        onConfirm={confirmDiscard}
        pending={discard.isPending}
        error={discardError}
      />
    </>
  );
}
