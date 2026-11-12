import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { accountReconcilePath, importPath, paths, withQuery } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import { useAccounts } from '@/shared/finance/reference';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useI18n } from '@/shared/i18n/I18nContext';
import { importsApi, useImportBatch } from '../api';
import { reviewCounts, resultCounts } from '../counts';
import { importErrorMessage, isStateConflict } from '../errors';
import { importKeys } from '../keys';
import { batchReason } from '../reasons';
import { canCancel, isBusy, isFinished } from '../status';
import type { ImportBatch, ImportStatus } from '../types';
import { CountGrid } from './CountGrid';
import { MappingForm } from './MappingForm';
import { BatchReasonAlert, PreviousImportAlert, ProcessingNotice } from './Notices';
import { REVIEW_FILTERS } from '../rowFilters';
import { RowsReview } from './RowsReview';
import { StatementFacts } from './StatementFacts';
import { WizardCard } from './WizardCard';
import type { WizardStep } from './WizardSteps';

type View = 'columns' | 'review' | 'confirm';

/** Which wizard step an import is on (the server's status decides; `view` picks among review steps). */
function stepFor(batch: ImportBatch, view: View): WizardStep {
  switch (batch.status) {
    case 'failed':
    case 'awaiting_upload':
      return 'file';
    case 'uploaded':
    case 'parsing':
      return view === 'review' ? 'review' : 'columns';
    case 'needs_mapping':
      return 'columns';
    case 'preview_ready':
      return view;
    default:
      return 'done';
  }
}

const formatLabels: Readonly<Record<string, string>> = {
  csv: 'CSV',
  xlsx: 'XLSX',
  ofx: 'OFX',
  qfx: 'QFX',
  pdf: 'PDF',
};

interface BatchStepsProps {
  importId: string;
  onStepChange: (step: WizardStep | null) => void;
}

/**
 * Steps 3–6 for an import the server already has: columns, review, confirm
 * and the result. The server's status drives the step; while it reads or
 * imports, the import is polled (only while the page is visible).
 */
export function BatchSteps({ importId, onStepChange }: BatchStepsProps) {
  const { t, formatLocale } = useI18n();
  const navigate = useNavigate();
  const toast = useToast();
  const announce = useAnnounce();
  const queryClient = useQueryClient();
  const query = useImportBatch(importId);
  const accounts = useAccounts(true);
  const [view, setView] = useState<View>('columns');
  const [conflict, setConflict] = useState<{ message: string | null } | null>(null);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);

  const batch = query.data;
  const step = batch ? stepFor(batch, view) : null;
  useEffect(() => {
    onStepChange(step);
  }, [step, onStepChange]);

  // Tell screen-reader users when the server finishes a background stage.
  const status = batch?.status ?? null;
  const previousStatus = useRef<ImportStatus | null>(null);
  useEffect(() => {
    const before = previousStatus.current;
    previousStatus.current = status;
    if (!status || !before || before === status || !isBusy(before)) return;
    if (isFinished(status)) {
      // New transactions change balances, lists and reports.
      void invalidateFinance(queryClient);
      announce(
        t(status === 'cancelled' ? 'imports.announce.cancelled' : 'imports.announce.finished'),
      );
    } else if (status === 'preview_ready') {
      announce(t('imports.announce.previewReady'));
    } else if (status === 'needs_mapping') {
      announce(t('imports.announce.needsMapping'));
    } else if (status === 'failed') {
      announce(t('imports.announce.failed'), 'assertive');
    }
  }, [status, queryClient, announce, t]);

  const cancel = useMutation({
    mutationFn: () => importsApi.cancel(importId),
    onSuccess: (updated) => {
      queryClient.setQueryData(importKeys.batch(importId), updated);
      void queryClient.invalidateQueries({ queryKey: importKeys.all });
    },
  });

  if (query.isPending) return <LoadingState label={t('imports.loading')} />;
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

  const current = query.data;
  const accountName =
    accounts.data?.find((account) => account.id === current.account_id)?.name ?? null;
  const format = current.source_format ? (formatLabels[current.source_format] ?? null) : null;
  const processing = current.status === 'processing' || current.status === 'confirmed';

  const runCancel = () => {
    if (cancel.isPending) return;
    setCancelError(null);
    const stopping = current.status === 'processing';
    cancel.mutate(undefined, {
      onSuccess: () => {
        setCancelOpen(false);
        if (stopping) {
          toast.show({ tone: 'info', title: t('imports.cancel.stopping') });
        } else {
          toast.show({ tone: 'success', title: t('imports.cancel.done') });
          void navigate(paths.imports);
        }
      },
      onError: (error) => {
        if (isStateConflict(error)) {
          setCancelOpen(false);
          void query.refetch();
          toast.show({ tone: 'warning', title: importErrorMessage(error, t, formatLocale) });
        } else {
          setCancelError(importErrorMessage(error, t, formatLocale));
        }
      },
    });
  };

  const cancelButton = canCancel(current) ? (
    <Button
      variant="ghost"
      onClick={() => {
        setCancelError(null);
        setCancelOpen(true);
      }}
    >
      <Icon name="x" className="size-4" />
      {processing ? t('imports.cancel.stopAction') : t('imports.cancel.action')}
    </Button>
  ) : null;

  const reloaded = () => {
    void query.refetch();
  };

  let body;
  // An import without a readable file (the server never left one waiting for its upload).
  if (current.status === 'failed' || current.status === 'awaiting_upload') {
    body = (
      <WizardCard title={t('imports.failed.stepTitle')}>
        <div className="space-y-5">
          <Alert tone="danger" title={t('imports.failed.title')}>
            <p>{batchReason(current, t) ?? t('imports.failed.generic')}</p>
          </Alert>
          <div className="flex flex-wrap gap-3">
            <ButtonLink
              to={withQuery(paths.importNew, { account_id: current.account_id, step: 'file' })}
            >
              <Icon name="upload" className="size-4" />
              {t('imports.failed.tryAnother')}
            </ButtonLink>
            <ButtonLink to={paths.imports} variant="secondary">
              {t('imports.backToList')}
            </ButtonLink>
          </div>
        </div>
      </WizardCard>
    );
  } else if (step === 'columns') {
    body = (
      <WizardCard title={t('imports.mapping.title')} description={t('imports.mapping.description')}>
        <div className="space-y-5">
          {conflict ? (
            <Alert tone="warning" live="polite" title={t('finance.conflict.title')}>
              <p>{conflict.message ?? t('finance.conflict.body')}</p>
            </Alert>
          ) : null}
          <PreviousImportAlert batch={current} />
          {isBusy(current.status) ? (
            <ProcessingNotice title={t('imports.reading.title')}>
              {t('imports.reading.body')}
            </ProcessingNotice>
          ) : (
            <MappingForm
              key={current.version}
              batch={current}
              onApplied={() => {
                setConflict(null);
                setView('review');
              }}
              onContinue={() => {
                setConflict(null);
                setView('review');
              }}
              onConflict={(message) => {
                setConflict({ message });
                void query.refetch();
              }}
              secondaryActions={cancelButton}
            />
          )}
        </div>
      </WizardCard>
    );
  } else if (step === 'review') {
    body = (
      <WizardCard title={t('imports.review.title')} description={t('imports.review.description')}>
        {isBusy(current.status) ? (
          <ProcessingNotice title={t('imports.reading.rowsTitle')}>
            {t('imports.reading.body')}
          </ProcessingNotice>
        ) : (
          <div className="space-y-6">
            <PreviousImportAlert batch={current} />
            <CountGrid items={reviewCounts(current, t)} />
            <Disclosure summary={t('imports.statement.show')}>
              <StatementFacts batch={current} />
            </Disclosure>
            <RowsReview batch={current} filters={REVIEW_FILTERS} editable />
            <div className="flex flex-col-reverse gap-3 border-t border-line pt-5 sm:flex-row sm:justify-between">
              <div className="flex flex-wrap gap-3">
                <Button
                  variant="secondary"
                  onClick={() => {
                    setView('columns');
                  }}
                >
                  <Icon name="arrow-left" className="size-4" />
                  {t('imports.review.back')}
                </Button>
                {cancelButton}
              </div>
              <Button
                onClick={() => {
                  setView('confirm');
                }}
              >
                {t('common.continue')}
                <Icon name="arrow-right" className="size-4" />
              </Button>
            </div>
          </div>
        )}
      </WizardCard>
    );
  } else if (step === 'confirm') {
    body = (
      <ConfirmStep
        batch={current}
        accountName={accountName}
        cancelButton={cancelButton}
        onBack={() => {
          setView('review');
        }}
        onConflict={reloaded}
      />
    );
  } else if (processing) {
    body = (
      <WizardCard title={t('imports.importing.title')}>
        <div className="space-y-5">
          <ProcessingNotice
            title={
              current.cancel_requested
                ? t('imports.importing.stopping')
                : t('imports.importing.running')
            }
          >
            {t('imports.importing.body')}
          </ProcessingNotice>
          {cancelButton ? <div>{cancelButton}</div> : null}
        </div>
      </WizardCard>
    );
  } else {
    body = <ResultStep batch={current} />;
  }

  return (
    <div className="space-y-4">
      <p className="text-sm text-fg-muted">
        {[accountName, current.currency, format].filter(Boolean).join(' · ')}
      </p>
      {body}
      <ConfirmDialog
        open={cancelOpen}
        onOpenChange={setCancelOpen}
        tone="danger"
        title={processing ? t('imports.cancel.stopTitle') : t('imports.cancel.title')}
        description={processing ? t('imports.cancel.stopBody') : t('imports.cancel.body')}
        confirmLabel={processing ? t('imports.cancel.stopConfirm') : t('imports.cancel.confirm')}
        cancelLabel={t('imports.cancel.keep')}
        onConfirm={runCancel}
        pending={cancel.isPending}
        error={cancelError}
      />
    </div>
  );
}

function ConfirmStep({
  batch,
  accountName,
  cancelButton,
  onBack,
  onConflict,
}: {
  batch: ImportBatch;
  accountName: string | null;
  cancelButton: ReactNode;
  onBack: () => void;
  onConflict: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const queryClient = useQueryClient();
  const idempotency = useIdempotencyKey();
  const [error, setError] = useState<string | null>(null);
  const [changed, setChanged] = useState(false);
  const confirm = useMutation({
    // A failed attempt stores nothing on the server, so the same key is kept
    // for a retry (a lost response is then replayed, never imported twice).
    mutationFn: () => importsApi.confirm(batch.id, batch.version, idempotency.key),
    onSuccess: (updated) => {
      idempotency.renew();
      queryClient.setQueryData(importKeys.batch(batch.id), updated);
      void queryClient.invalidateQueries({ queryKey: importKeys.all });
    },
  });

  const submit = () => {
    if (confirm.isPending) return;
    setError(null);
    setChanged(false);
    confirm.mutate(undefined, {
      onError: (failure) => {
        if (hasErrorCode(failure, 'VERSION_CONFLICT')) {
          // Reloaded: the user reviews the latest counts and confirms again.
          setChanged(true);
          onConflict();
        } else if (isStateConflict(failure)) {
          onConflict();
          setError(importErrorMessage(failure, t, formatLocale));
        } else {
          setError(importErrorMessage(failure, t, formatLocale));
        }
      },
    });
  };

  return (
    <WizardCard title={t('imports.confirm.title')} description={t('imports.confirm.description')}>
      <div className="space-y-6">
        {changed ? (
          <Alert tone="warning" live="polite" title={t('finance.conflict.title')}>
            <p>{t('finance.conflict.body')}</p>
          </Alert>
        ) : null}
        <FormAlert message={error} />
        <PreviousImportAlert batch={batch} />
        {accountName ? (
          <p className="text-sm text-fg">{t('imports.confirm.account', { name: accountName })}</p>
        ) : null}
        <p className="text-base font-semibold text-fg" role="status">
          {t('imports.confirm.toImport', { count: batch.to_import_rows })}
        </p>
        <CountGrid items={reviewCounts(batch, t)} />
        <section aria-labelledby="confirm-statement" className="space-y-3">
          <h3 id="confirm-statement" className="text-base font-semibold text-fg">
            {t('imports.statement.title')}
          </h3>
          <p className="text-sm text-fg-muted">{t('imports.statement.help')}</p>
          <StatementFacts batch={batch} />
        </section>
        <ul className="list-disc space-y-1 ps-5 text-sm text-fg">
          <li>{t('imports.confirm.ruleReady')}</li>
          <li>{t('imports.confirm.ruleLeftOut')}</li>
          <li>{t('imports.confirm.ruleBackground')}</li>
          <li>{t('imports.confirm.ruleUndo')}</li>
        </ul>
        <div className="flex flex-col-reverse gap-3 border-t border-line pt-5 sm:flex-row sm:justify-between">
          <div className="flex flex-wrap gap-3">
            <Button variant="secondary" onClick={onBack} disabled={confirm.isPending}>
              <Icon name="arrow-left" className="size-4" />
              {t('imports.confirm.back')}
            </Button>
            {cancelButton}
          </div>
          <Button onClick={submit} loading={confirm.isPending}>
            <Icon name="check" className="size-4" />
            {t('imports.confirm.submit')}
          </Button>
        </div>
      </div>
    </WizardCard>
  );
}

function ResultStep({ batch }: { batch: ImportBatch }) {
  const { t } = useI18n();
  const title =
    batch.status === 'completed'
      ? t('imports.result.completed')
      : batch.status === 'completed_with_errors'
        ? t('imports.result.withErrors')
        : t('imports.result.cancelled');
  return (
    <WizardCard title={title} description={t('imports.result.description')}>
      <div className="space-y-6">
        <BatchReasonAlert batch={batch} />
        {batch.failed_count > 0 ? (
          <Alert tone="warning" title={t('imports.result.failedTitle')}>
            <p>{t('imports.result.failedBody')}</p>
          </Alert>
        ) : null}
        <CountGrid items={resultCounts(batch, t)} />
        <div className="flex flex-wrap gap-3">
          <ButtonLink to={importPath(batch.id)}>{t('imports.result.view')}</ButtonLink>
          {batch.imported_count > 0 ? (
            <ButtonLink
              to={withQuery(paths.transactions, { account_id: batch.account_id, source: 'import' })}
              variant="secondary"
            >
              {t('imports.result.transactions')}
            </ButtonLink>
          ) : null}
          <ButtonLink to={accountReconcilePath(batch.account_id)} variant="secondary">
            <Icon name="scale" className="size-4" />
            {t('imports.result.reconcile')}
          </ButtonLink>
          <ButtonLink
            to={withQuery(paths.importNew, { account_id: batch.account_id })}
            variant="ghost"
          >
            {t('imports.result.another')}
          </ButtonLink>
        </div>
      </div>
    </WizardCard>
  );
}
