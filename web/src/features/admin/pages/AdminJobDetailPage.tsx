import { useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { detailParam, domainRuleCode } from '@/shared/finance/domainErrors';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useJob, useRetryJob } from '../api';
import { JobError } from '../components/JobError';
import { attemptOutcomeLabel, isJobStatus, jobStatusLabel, jobStatusTone } from '../jobLabels';
import type { Job, JobAttempt } from '../types';

function RetryControl({ job }: { job: Job }) {
  const { t } = useI18n();
  const toast = useToast();
  const retry = useRetryJob(job.id);
  const idempotency = useIdempotencyKey();
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const status = t(jobStatusLabel[job.status]).toLocaleLowerCase();

  const confirm = () => {
    if (retry.isPending) return;
    setError(null);
    retry.mutate(idempotency.key, {
      onSuccess: () => {
        idempotency.renew();
        setConfirming(false);
        toast.show({ tone: 'success', title: t('adminJobs.retry.done') });
      },
      onError: (failure) => {
        const rule = domainRuleCode(failure);
        if (rule?.code === 'job_not_retryable') {
          const current = detailParam(rule.params, 'status');
          setError(
            t('adminJobs.retry.notAllowed', {
              status: isJobStatus(current)
                ? t(jobStatusLabel[current]).toLocaleLowerCase()
                : (current ?? status),
            }),
          );
          return;
        }
        setError(describeError(failure, t));
      },
    });
  };

  return (
    <div className="space-y-2">
      <Button
        variant="secondary"
        disabled={!job.retryable}
        aria-describedby={job.retryable ? undefined : `retry-note-${job.id}`}
        onClick={() => {
          setError(null);
          setConfirming(true);
        }}
      >
        <Icon name="refresh" className="size-4" />
        {t('adminJobs.retry.button')}
      </Button>
      {job.retryable ? null : (
        <p id={`retry-note-${job.id}`} className="text-sm text-fg-muted">
          {t('adminJobs.retry.notRetryable', { status })}
        </p>
      )}
      <ConfirmDialog
        open={confirming}
        onOpenChange={(open) => {
          if (!open) setConfirming(false);
        }}
        title={t('adminJobs.retry.title')}
        description={t('adminJobs.retry.body')}
        confirmLabel={t('adminJobs.retry.confirm')}
        tone="primary"
        onConfirm={confirm}
        pending={retry.isPending}
        error={error}
      />
    </div>
  );
}

function Attempts({ attempts }: { attempts: readonly JobAttempt[] }) {
  const { t, formatLocale } = useI18n();
  const numbers = new Intl.NumberFormat(formatLocale);
  if (attempts.length === 0) {
    return <p className="text-sm text-fg-muted">{t('adminJobs.attempts.none')}</p>;
  }
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-max border-collapse text-sm">
        <caption className="sr-only">{t('adminJobs.attempts.caption')}</caption>
        <thead>
          <tr className="border-b border-line text-fg-muted">
            {[
              t('adminJobs.attempts.number'),
              t('adminJobs.attempts.outcome'),
              t('adminJobs.attempts.error'),
              t('adminJobs.attempts.started'),
              t('adminJobs.attempts.duration'),
              t('adminJobs.attempts.worker'),
            ].map((column) => (
              <th key={column} scope="col" className="py-2 pe-4 text-start font-medium">
                {column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {attempts.map((attempt) => {
            const started = parseTimestamp(attempt.started_at);
            return (
              <tr key={attempt.attempt} className="border-b border-line align-top last:border-b-0">
                <th scope="row" className="py-2 pe-4 text-start font-normal tabular-nums">
                  {numbers.format(attempt.attempt)}
                </th>
                <td className="py-2 pe-4">
                  {t(attemptOutcomeLabel[attempt.outcome ?? 'running'])}
                </td>
                <td className="max-w-xs py-2 pe-4">
                  <JobError code={attempt.error_code} />
                </td>
                <td className="py-2 pe-4 whitespace-nowrap">
                  {started ? formatDateTime(started, formatLocale) : t('adminJobs.none')}
                </td>
                <td className="py-2 pe-4 tabular-nums">
                  {attempt.duration_ms === undefined
                    ? t('adminJobs.none')
                    : t('adminJobs.attempts.durationMs', { ms: attempt.duration_ms })}
                </td>
                <td className="py-2">
                  <code className="break-all">{attempt.worker_id}</code>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/** One background job (JOB-007): its facts, attempts and a confirmed, audited retry. */
export function AdminJobDetailPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('adminJobs.title'));
  const user = useCurrentUser();
  const isAdmin = user.platform_role === 'admin';
  const { jobId = '' } = useParams();
  const detail = useJob(jobId, isAdmin);
  const time = (iso: string | undefined) => {
    const date = parseTimestamp(iso);
    return date ? formatDateTime(date, formatLocale) : t('adminJobs.none');
  };

  let content;
  if (!isAdmin || hasErrorCode(detail.error, 'FORBIDDEN')) {
    content = (
      <PermissionDenied
        titleAs="h2"
        title={t('adminJobs.forbidden.title')}
        description={t('adminJobs.forbidden.body')}
      />
    );
  } else if (detail.isPending) {
    content = <LoadingState label={t('adminJobs.detail.loading')} />;
  } else if (hasErrorCode(detail.error, 'NOT_FOUND')) {
    content = <EmptyState titleAs="h2" icon="search" title={t('adminJobs.detail.notFound')} />;
  } else if (detail.isError) {
    content = (
      <ErrorState
        titleAs="h2"
        title={t('adminJobs.detail.error')}
        error={detail.error}
        retrying={detail.isFetching}
        onRetry={() => {
          void detail.refetch();
        }}
      />
    );
  } else {
    const { job, attempts } = detail.data;
    content = (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)] lg:items-start">
        <div className="space-y-6">
          <Card title={t('adminJobs.detail.facts')}>
            <Facts>
              <Fact label={t('adminJobs.list.status')}>
                <span className="flex flex-wrap items-center gap-2">
                  <StatusBadge tone={jobStatusTone[job.status]}>
                    {t(jobStatusLabel[job.status])}
                  </StatusBadge>
                  {job.cancel_requested ? (
                    <StatusBadge tone="warning">{t('adminJobs.cancelRequested')}</StatusBadge>
                  ) : null}
                </span>
              </Fact>
              <Fact label={t('adminJobs.detail.id')}>
                <code className="break-all">{job.id}</code>
              </Fact>
              <Fact label={t('adminJobs.detail.queue')}>
                <code>{job.queue}</code>
              </Fact>
              <Fact label={t('adminJobs.list.attempts')}>
                {t('adminJobs.attemptsOf', { attempts: job.attempts, max: job.max_attempts })}
              </Fact>
              <Fact label={t('adminJobs.list.lastError')}>
                <JobError code={job.last_error_code} />
              </Fact>
              <Fact label={t('adminJobs.detail.priority')}>
                {t('adminJobs.detail.priorityHelp', { priority: job.priority })}
              </Fact>
              <Fact label={t('adminJobs.detail.scope')}>
                {job.user_scoped
                  ? t('adminJobs.detail.scopeUser')
                  : t('adminJobs.detail.scopeSystem')}
              </Fact>
              <Fact label={t('adminJobs.list.created')}>{time(job.created_at)}</Fact>
              <Fact label={t('adminJobs.detail.runAfter')}>{time(job.run_after)}</Fact>
              <Fact label={t('adminJobs.detail.started')}>{time(job.started_at)}</Fact>
              <Fact label={t('adminJobs.detail.finished')}>{time(job.finished_at)}</Fact>
              <Fact label={t('adminJobs.detail.updated')}>{time(job.updated_at)}</Fact>
            </Facts>
          </Card>
          <Card title={t('adminJobs.attempts.title')}>
            <Attempts attempts={attempts} />
          </Card>
        </div>
        <Card title={t('adminJobs.retry.button')}>
          {job.last_error_code === 'provider_circuit_open' ? (
            <Alert tone="info" className="mb-4">
              {t('adminJobs.errorCode.provider_circuit_open')}
            </Alert>
          ) : null}
          <RetryControl job={job} />
        </Card>
      </div>
    );
  }

  return (
    <>
      <p className="mb-3">
        <TextLink to={paths.staffJobs} className="inline-flex min-h-11 items-center gap-1.5">
          <Icon name="arrow-left" className="size-4" />
          {t('adminJobs.detail.back')}
        </TextLink>
      </p>
      <PageHeader
        title={detail.data ? detail.data.job.type : t('adminJobs.title')}
        description={detail.data ? undefined : t('adminJobs.description')}
      />
      {content}
    </>
  );
}
