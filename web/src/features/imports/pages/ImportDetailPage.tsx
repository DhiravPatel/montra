import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { useParams } from 'react-router';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { hasErrorCode } from '@/shared/api/errors';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { accountPath, accountReconcilePath, paths, withQuery } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import { useAccounts } from '@/shared/finance/reference';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { importsApi, useImportBatch } from '../api';
import { ImportStatusBadge } from '../components/ImportBadges';
import { CountGrid } from '../components/CountGrid';
import { BatchReasonAlert, PreviousImportAlert, ProcessingNotice } from '../components/Notices';
import { RowsReview } from '../components/RowsReview';
import { RESULT_FILTERS, REVIEW_FILTERS } from '../rowFilters';
import { StatementFacts } from '../components/StatementFacts';
import { resultCounts, reviewCounts } from '../counts';
import { importErrorMessage, isStateConflict } from '../errors';
import { importKeys } from '../keys';
import { canCancel, canRollback, isBusy, isFinished, isReviewable } from '../status';
import type { ImportBatch, ImportStatus } from '../types';

type Action = 'cancel' | 'retry' | 'rollback';

function DetailSkeleton() {
  return (
    <div className="space-y-6" aria-hidden="true">
      <Skeleton className="h-9 w-1/2" />
      <Skeleton className="h-32 w-full" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}

/** One import: status, counts, the statement, rows by status, and retry, cancel and undo. */
export function ImportDetailPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('imports.detail.documentTitle'));
  const { importId = '' } = useParams();
  const toast = useToast();
  const announce = useAnnounce();
  const queryClient = useQueryClient();
  const query = useImportBatch(importId);
  const accounts = useAccounts(true);
  const [action, setAction] = useState<Action | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  // Announce (and refresh balances) when a background stage ends.
  const status = query.data?.status ?? null;
  const errorCode = query.data?.error_code ?? null;
  const previousStatus = useRef<ImportStatus | null>(null);
  useEffect(() => {
    const before = previousStatus.current;
    previousStatus.current = status;
    if (!status || !before || before === status || !isBusy(before)) return;
    if (isFinished(status)) {
      void invalidateFinance(queryClient);
      announce(
        t(
          errorCode === 'rolled_back'
            ? 'imports.rollback.doneTitle'
            : status === 'cancelled'
              ? 'imports.announce.cancelled'
              : 'imports.announce.finished',
        ),
      );
    } else if (status === 'failed') {
      announce(t('imports.announce.failed'), 'assertive');
    } else if (status === 'preview_ready') {
      announce(t('imports.announce.previewReady'));
    }
  }, [status, errorCode, queryClient, announce, t]);

  const mutation = useMutation({
    mutationFn: (next: Action) =>
      next === 'cancel'
        ? importsApi.cancel(importId)
        : next === 'retry'
          ? importsApi.retryFailed(importId)
          : importsApi.rollback(importId),
    onSuccess: (updated) => {
      queryClient.setQueryData(importKeys.batch(importId), updated);
      void queryClient.invalidateQueries({ queryKey: importKeys.all });
    },
  });

  if (query.isPending) {
    return (
      <LoadingState label={t('imports.loading')}>
        <DetailSkeleton />
      </LoadingState>
    );
  }
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="upload"
          title={t('imports.notFound')}
          description={t('imports.notFoundBody')}
          action={<ButtonLink to={paths.imports}>{t('imports.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('imports.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const batch = query.data;
  const account = accounts.data?.find((item) => item.id === batch.account_id);
  const created = parseTimestamp(batch.created_at);

  const run = (next: Action) => {
    if (mutation.isPending) return;
    setActionError(null);
    mutation.mutate(next, {
      onSuccess: () => {
        setAction(null);
        toast.show({
          tone: next === 'retry' ? 'success' : 'info',
          title:
            next === 'retry'
              ? t('imports.retry.done')
              : next === 'rollback'
                ? t('imports.rollback.started')
                : batch.status === 'processing'
                  ? t('imports.cancel.stopping')
                  : t('imports.cancel.done'),
        });
      },
      onError: (error) => {
        if (isStateConflict(error)) {
          setAction(null);
          void query.refetch();
          toast.show({ tone: 'warning', title: importErrorMessage(error, t, formatLocale) });
        } else if (next === 'retry') {
          toast.show({ tone: 'danger', title: importErrorMessage(error, t, formatLocale) });
        } else {
          setActionError(importErrorMessage(error, t, formatLocale));
        }
      },
    });
  };

  const processing = batch.status === 'processing';
  const actions = (
    <>
      {isReviewable(batch.status) ? (
        <ButtonLink to={withQuery(paths.importNew, { import_id: batch.id })}>
          {t('imports.detail.continue')}
        </ButtonLink>
      ) : null}
      {/* Also after every failed row was corrected: corrected rows wait for this retry. */}
      {batch.status === 'completed_with_errors' ? (
        <Button
          loading={mutation.isPending && mutation.variables === 'retry'}
          onClick={() => {
            run('retry');
          }}
        >
          <Icon name="refresh" className="size-4" />
          {t('imports.retry.action')}
        </Button>
      ) : null}
      {canRollback(batch) ? (
        <Button
          variant="secondary"
          onClick={() => {
            setActionError(null);
            setAction('rollback');
          }}
        >
          <Icon name="undo" className="size-4" />
          {t('imports.rollback.action')}
        </Button>
      ) : null}
      {canCancel(batch) ? (
        <Button
          variant="secondary"
          onClick={() => {
            setActionError(null);
            setAction('cancel');
          }}
        >
          <Icon name="x" className="size-4" />
          {processing ? t('imports.cancel.stopAction') : t('imports.cancel.action')}
        </Button>
      ) : null}
    </>
  );

  return (
    <>
      <p className="mb-2">
        <TextLink to={paths.imports}>
          <Icon name="arrow-left" className="me-1 inline size-4" />
          {t('imports.backToList')}
        </TextLink>
      </p>
      <PageHeader
        title={t('imports.detail.title')}
        description={
          created
            ? t('imports.detail.subtitle', {
                account: account?.name ?? t('imports.list.unknownAccount'),
                date: formatDateTime(created, formatLocale),
              })
            : account?.name
        }
        actions={actions}
      />
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <ImportStatusBadge batch={batch} />
        {account ? (
          <TextLink to={accountPath(account.id)} className="text-sm">
            {t('imports.detail.viewAccount')}
          </TextLink>
        ) : null}
      </div>
      <div className="space-y-6">
        <StatusCard batch={batch} />
        <Card title={t('imports.detail.counts')}>
          <CountGrid
            items={isFinished(batch.status) ? resultCounts(batch, t) : reviewCounts(batch, t)}
          />
        </Card>
        <Card title={t('imports.statement.title')} description={t('imports.statement.help')}>
          <StatementFacts batch={batch} />
        </Card>
        <Card title={t('imports.detail.rows')} description={t('imports.detail.rowsHelp')}>
          {isBusy(batch.status) ? (
            <p className="text-sm text-fg-muted">{t('imports.detail.rowsBusy')}</p>
          ) : batch.status === 'failed' ? (
            <p className="text-sm text-fg-muted">{t('imports.detail.rowsFailed')}</p>
          ) : (
            <RowsReview
              batch={batch}
              filters={isFinished(batch.status) ? RESULT_FILTERS : REVIEW_FILTERS}
              editable={batch.status === 'completed_with_errors'}
              initialFilter={batch.status === 'completed_with_errors' ? 'failed' : ''}
            />
          )}
        </Card>
      </div>
      <ConfirmDialog
        open={action === 'cancel'}
        onOpenChange={(open) => {
          if (!open) setAction(null);
        }}
        tone="danger"
        title={processing ? t('imports.cancel.stopTitle') : t('imports.cancel.title')}
        description={processing ? t('imports.cancel.stopBody') : t('imports.cancel.body')}
        confirmLabel={processing ? t('imports.cancel.stopConfirm') : t('imports.cancel.confirm')}
        cancelLabel={t('imports.cancel.keep')}
        onConfirm={() => {
          run('cancel');
        }}
        pending={mutation.isPending}
        error={actionError}
      />
      <ConfirmDialog
        open={action === 'rollback'}
        onOpenChange={(open) => {
          if (!open) setAction(null);
        }}
        tone="danger"
        title={t('imports.rollback.title')}
        description={
          <div className="space-y-2">
            <p>{t('imports.rollback.body', { count: batch.imported_count })}</p>
            <p>{t('imports.rollback.kept')}</p>
            <p>{t('imports.rollback.background')}</p>
          </div>
        }
        confirmLabel={t('imports.rollback.confirm')}
        cancelLabel={t('imports.rollback.keep')}
        onConfirm={() => {
          run('rollback');
        }}
        pending={mutation.isPending}
        error={actionError}
      />
    </>
  );
}

function StatusCard({ batch }: { batch: ImportBatch }) {
  const { t, formatLocale } = useI18n();
  const timeline = [
    { label: t('imports.detail.created'), value: batch.created_at },
    { label: t('imports.detail.confirmed'), value: batch.confirmed_at },
    { label: t('imports.detail.completed'), value: batch.completed_at },
    { label: t('imports.detail.cancelled'), value: batch.cancelled_at },
  ].flatMap((item) => {
    const date = parseTimestamp(item.value);
    return date && item.value ? [{ ...item, date, iso: item.value }] : [];
  });
  return (
    <Card title={t('imports.detail.status')}>
      <div className="space-y-5">
        {batch.status === 'parsing' || batch.status === 'uploaded' ? (
          <ProcessingNotice title={t('imports.reading.title')}>
            {t('imports.reading.body')}
          </ProcessingNotice>
        ) : null}
        {batch.status === 'confirmed' || batch.status === 'processing' ? (
          <ProcessingNotice
            title={
              batch.cancel_requested ? t('imports.importing.stopping') : t('imports.detail.working')
            }
          >
            {t('imports.importing.body')}
          </ProcessingNotice>
        ) : null}
        {batch.status === 'needs_mapping' ? (
          <p className="text-sm text-fg">{t('imports.detail.needsMapping')}</p>
        ) : null}
        {batch.status === 'preview_ready' ? (
          <p className="text-sm text-fg">{t('imports.detail.previewReady')}</p>
        ) : null}
        <BatchReasonAlert batch={batch} />
        {batch.status === 'completed_with_errors' ? (
          <p className="text-sm text-fg">{t('imports.detail.withErrors')}</p>
        ) : null}
        <PreviousImportAlert batch={batch} />
        <Facts>
          {timeline.map((item) => (
            <Fact key={item.label} label={item.label}>
              <time dateTime={item.iso}>{formatDateTime(item.date, formatLocale)}</time>
            </Fact>
          ))}
        </Facts>
        {isFinished(batch.status) && batch.imported_count > 0 ? (
          <div className="flex flex-wrap gap-3">
            <ButtonLink
              to={withQuery(paths.transactions, { account_id: batch.account_id, source: 'import' })}
              variant="secondary"
              size="sm"
            >
              {t('imports.result.transactions')}
            </ButtonLink>
            <ButtonLink to={accountReconcilePath(batch.account_id)} variant="secondary" size="sm">
              <Icon name="scale" className="size-4" />
              {t('imports.result.reconcile')}
            </ButtonLink>
          </div>
        ) : null}
      </div>
    </Card>
  );
}
