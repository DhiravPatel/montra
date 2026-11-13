import { type SubmitEvent, useState } from 'react';
import { useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { Skeleton } from '@/shared/components/Skeleton';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { TextLink } from '@/shared/components/TextLink';
import { staffJobPath } from '@/shared/config/paths';
import { formatDateTime, isLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useJobs } from '../api';
import { JobError } from '../components/JobError';
import { isJobStatus, JOB_STATUSES, jobStatusLabel, jobStatusTone } from '../jobLabels';
import type { JobFilters } from '../types';

const TYPE_PATTERN = /^[a-z0-9_.-]{1,100}$/;

/** Filters from the address (job types, statuses and dates only: nothing personal). */
function readFilters(params: URLSearchParams): JobFilters {
  const status = params.get('status');
  const type = params.get('type') ?? '';
  const from = params.get('from') ?? '';
  const to = params.get('to') ?? '';
  return {
    status: isJobStatus(status) ? status : '',
    type: TYPE_PATTERN.test(type) ? type : '',
    from: isLocalDate(from) ? from : '',
    to: isLocalDate(to) ? to : '',
  };
}

function writeFilters(filters: JobFilters): URLSearchParams {
  const params = new URLSearchParams();
  if (filters.status) params.set('status', filters.status);
  if (filters.type) params.set('type', filters.type);
  if (filters.from) params.set('from', filters.from);
  if (filters.to) params.set('to', filters.to);
  return params;
}

function JobFilterForm({
  filters,
  onApply,
}: {
  filters: JobFilters;
  onApply: (next: JobFilters) => void;
}) {
  const { t } = useI18n();
  const [draft, setDraft] = useState(filters);
  const [dateError, setDateError] = useState<string | undefined>(undefined);

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (draft.from && draft.to && draft.to < draft.from) {
      setDateError(t('adminJobs.filters.badDates'));
      return;
    }
    setDateError(undefined);
    onApply({ ...draft, type: draft.type.trim() });
  };

  return (
    <form
      aria-label={t('adminJobs.filters.label')}
      onSubmit={submit}
      noValidate
      className="mb-6 rounded-xl border border-line bg-surface p-4 shadow-card sm:p-5"
    >
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Select
          label={t('adminJobs.filters.status')}
          value={draft.status}
          placeholder={t('adminJobs.filters.anyStatus')}
          optional
          options={JOB_STATUSES.map((status) => ({
            value: status,
            label: t(jobStatusLabel[status]),
          }))}
          onChange={(event) => {
            const value = event.target.value;
            setDraft({ ...draft, status: isJobStatus(value) ? value : '' });
          }}
        />
        <TextField
          label={t('adminJobs.filters.type')}
          help={t('adminJobs.filters.typeHelp')}
          optional
          value={draft.type}
          maxLength={100}
          autoComplete="off"
          spellCheck={false}
          onChange={(event) => {
            setDraft({ ...draft, type: event.target.value });
          }}
        />
        <TextField
          type="date"
          label={t('adminJobs.filters.from')}
          help={t('adminJobs.filters.datesHelp')}
          optional
          value={draft.from}
          onChange={(event) => {
            setDraft({ ...draft, from: event.target.value });
          }}
        />
        <TextField
          type="date"
          label={t('adminJobs.filters.to')}
          optional
          value={draft.to}
          error={dateError}
          onChange={(event) => {
            setDraft({ ...draft, to: event.target.value });
          }}
        />
      </div>
      <div className="mt-4 flex flex-wrap gap-2">
        <Button type="submit">{t('adminJobs.filters.apply')}</Button>
        <Button
          variant="ghost"
          onClick={() => {
            const empty: JobFilters = { status: '', type: '', from: '', to: '' };
            setDraft(empty);
            setDateError(undefined);
            onApply(empty);
          }}
        >
          {t('adminJobs.filters.clear')}
        </Button>
      </div>
    </form>
  );
}

/** Operator job view (JOB-007): background jobs newest first, filtered, with links to details. */
export function AdminJobsPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('adminJobs.title'));
  const user = useCurrentUser();
  const isAdmin = user.platform_role === 'admin';
  const [params, setParams] = useSearchParams();
  const filters = readFilters(params);
  const jobs = useJobs(filters, isAdmin);
  const items = jobs.data?.pages.flatMap((page) => page.items) ?? [];
  const time = (iso: string | undefined) => {
    const date = parseTimestamp(iso);
    return date ? formatDateTime(date, formatLocale) : t('adminJobs.none');
  };

  let content;
  if (!isAdmin || hasErrorCode(jobs.error, 'FORBIDDEN')) {
    content = (
      <PermissionDenied
        titleAs="h2"
        title={t('adminJobs.forbidden.title')}
        description={t('adminJobs.forbidden.body')}
      />
    );
  } else if (jobs.isPending) {
    content = (
      <LoadingState label={t('adminJobs.loading')}>
        <Skeleton className="h-64 w-full" />
      </LoadingState>
    );
  } else if (jobs.isError) {
    content = (
      <ErrorState
        titleAs="h2"
        title={t('adminJobs.error')}
        error={jobs.error}
        retrying={jobs.isFetching}
        onRetry={() => {
          void jobs.refetch();
        }}
      />
    );
  } else if (items.length === 0) {
    content = (
      <Card>
        <p className="text-sm text-fg-muted">{t('adminJobs.list.empty')}</p>
      </Card>
    );
  } else {
    content = (
      <Card>
        <p className="mb-3 text-sm text-fg-muted" aria-live="polite">
          {t('adminJobs.list.count', { count: items.length })}
        </p>
        <div className="overflow-x-auto">
          <table className="w-full min-w-max border-collapse text-sm">
            <caption className="sr-only">{t('adminJobs.list.caption')}</caption>
            <thead>
              <tr className="border-b border-line text-start text-fg-muted">
                <th scope="col" className="py-2 pe-4 text-start font-medium">
                  {t('adminJobs.list.type')}
                </th>
                <th scope="col" className="py-2 pe-4 text-start font-medium">
                  {t('adminJobs.list.status')}
                </th>
                <th scope="col" className="py-2 pe-4 text-end font-medium">
                  {t('adminJobs.list.attempts')}
                </th>
                <th scope="col" className="py-2 pe-4 text-start font-medium">
                  {t('adminJobs.list.lastError')}
                </th>
                <th scope="col" className="py-2 pe-4 text-start font-medium">
                  {t('adminJobs.list.created')}
                </th>
                <th scope="col" className="py-2 text-start font-medium">
                  <span className="sr-only">{t('adminJobs.list.open')}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {items.map((job) => (
                <tr key={job.id} className="border-b border-line align-top last:border-b-0">
                  <th scope="row" className="py-2 pe-4 text-start font-normal">
                    <code className="break-all">{job.type}</code>
                    {job.user_scoped ? (
                      <span className="block text-xs text-fg-muted">
                        {t('adminJobs.userScoped')}
                      </span>
                    ) : null}
                  </th>
                  <td className="py-2 pe-4">
                    <StatusBadge tone={jobStatusTone[job.status]}>
                      {t(jobStatusLabel[job.status])}
                    </StatusBadge>
                  </td>
                  <td className="py-2 pe-4 text-end tabular-nums">
                    {t('adminJobs.attemptsOf', {
                      attempts: job.attempts,
                      max: job.max_attempts,
                    })}
                  </td>
                  <td className="max-w-xs py-2 pe-4">
                    <JobError code={job.last_error_code} />
                  </td>
                  <td className="py-2 pe-4 whitespace-nowrap">{time(job.created_at)}</td>
                  <td className="py-2">
                    <TextLink
                      to={staffJobPath(job.id)}
                      aria-label={t('adminJobs.list.openNamed', {
                        type: job.type,
                        time: time(job.created_at),
                      })}
                      className="inline-flex min-h-11 items-center"
                    >
                      {t('adminJobs.list.open')}
                    </TextLink>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {jobs.hasNextPage ? (
          <div className="mt-4 flex justify-center">
            <Button
              variant="secondary"
              loading={jobs.isFetchingNextPage}
              onClick={() => {
                void jobs.fetchNextPage();
              }}
            >
              {t('adminJobs.list.more')}
            </Button>
          </div>
        ) : null}
      </Card>
    );
  }

  return (
    <>
      <PageHeader title={t('adminJobs.title')} description={t('adminJobs.description')} />
      {isAdmin ? (
        <JobFilterForm
          key={params.toString()}
          filters={filters}
          onApply={(next) => {
            setParams(writeFilters(next), { replace: true });
          }}
        />
      ) : null}
      {content}
    </>
  );
}
