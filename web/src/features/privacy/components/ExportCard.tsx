import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import { useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { isReauthCancelled, useReauth } from '@/shared/auth/reauth/ReauthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { Spinner } from '@/shared/components/Spinner';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { privacyApi } from '../api';
import { downloadExport } from '../download';
import { isExportActive, useExportJob, useExportStalled, useExports } from '../hooks';
import { privacyKeys } from '../keys';
import type { ExportJob, ExportStatus } from '../types';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** True once a completed export's download window has passed. */
function isExpired(job: ExportJob, now: number): boolean {
  if (job.status === 'expired') return true;
  const expires = parseTimestamp(job.expires_at);
  return job.status === 'completed' && expires !== null && expires.getTime() <= now;
}

interface ExportCardProps {
  /** How long downloads stay available (GET /limits), when known. */
  downloadDays: number | null;
}

const statusWords: Readonly<Record<ExportStatus, { key: MessageKey; tone: Tone; icon: IconName }>> =
  {
    queued: { key: 'privacySettings.export.status.queued', tone: 'info', icon: 'clock' },
    running: { key: 'privacySettings.export.status.running', tone: 'info', icon: 'clock' },
    completed: {
      key: 'privacySettings.export.status.completed',
      tone: 'success',
      icon: 'check-circle',
    },
    failed: { key: 'privacySettings.export.status.failed', tone: 'danger', icon: 'alert-circle' },
    expired: { key: 'privacySettings.export.status.expired', tone: 'neutral', icon: 'archive' },
  };

interface EarlierExportsProps {
  exports: readonly ExportJob[];
  now: number;
  downloading: string | null;
  onDownload: (fileId: string) => void;
}

/** Earlier exports (GET /me/exports, newest first), with downloads while they last. */
function EarlierExports({ exports, now, downloading, onDownload }: EarlierExportsProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  if (exports.length === 0) return null;
  return (
    <div className="space-y-3 border-t border-line pt-5">
      <h3 className="font-semibold text-fg">{t('privacySettings.export.historyTitle')}</h3>
      <ul className="divide-y divide-line">
        {exports.map((job) => {
          const requested = parseTimestamp(job.requested_at);
          const expires = parseTimestamp(job.expires_at);
          const expired = isExpired(job, now);
          const words = statusWords[expired ? 'expired' : job.status];
          const fileId = job.file_id;
          const downloadable = job.status === 'completed' && !expired && fileId;
          return (
            <li
              key={job.id}
              className="flex flex-col gap-2 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between"
            >
              <div className="min-w-0 space-y-1 text-sm">
                <p className="flex flex-wrap items-center gap-2">
                  <StatusBadge tone={words.tone} icon={words.icon}>
                    {t(words.key)}
                  </StatusBadge>
                  {requested ? (
                    <span className="text-fg">
                      {t('privacySettings.export.requestedOn', {
                        date: formatDateTime(requested, formatLocale, user.timezone),
                      })}
                    </span>
                  ) : null}
                </p>
                {downloadable && expires ? (
                  <p className="text-fg-muted">
                    {t('privacySettings.export.availableUntil', {
                      date: formatDateTime(expires, formatLocale, user.timezone),
                    })}
                  </p>
                ) : null}
              </div>
              {downloadable ? (
                <Button
                  variant="secondary"
                  size="sm"
                  loading={downloading === fileId}
                  aria-label={
                    requested
                      ? t('privacySettings.export.downloadFrom', {
                          date: formatDateTime(requested, formatLocale, user.timezone),
                        })
                      : t('privacySettings.export.download')
                  }
                  onClick={() => {
                    onDownload(fileId);
                  }}
                >
                  <Icon name="download" className="size-4" />
                  {t('privacySettings.export.download')}
                </Button>
              ) : null}
            </li>
          );
        })}
      </ul>
    </div>
  );
}

/**
 * Data export: request (re-authentication required), follow the job, then
 * download the ZIP through a short-lived signed link. The export followed is
 * the one in the address (`?export=`, from the "export ready" notification)
 * or else the newest from GET /me/exports; earlier ones are listed below it.
 */
export function ExportCard({ downloadDays }: ExportCardProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const { withReauth } = useReauth();
  const [params, setParams] = useSearchParams();
  const exports = useExports();
  const fromUrl = params.get('export');
  const exportId = fromUrl && UUID.test(fromUrl) ? fromUrl : (exports.data?.[0]?.id ?? null);
  const job = useExportJob(exportId);
  const stalled = useExportStalled(exportId, job.data);
  // Re-checked every minute, so an export whose download window passes is shown as expired.
  const now = useNow(60_000);
  const [requestError, setRequestError] = useState<string | null>(null);

  // Announce when a followed export finishes (the status text alone may not be read out).
  const jobStatus = job.data?.status;
  const previousStatus = useRef<ExportStatus | undefined>(undefined);
  useEffect(() => {
    const before = previousStatus.current;
    previousStatus.current = jobStatus;
    if (before !== 'queued' && before !== 'running') return;
    if (jobStatus !== 'queued' && jobStatus !== 'running') {
      // The list shows every export's status too.
      void queryClient.invalidateQueries({ queryKey: privacyKeys.exports() });
    }
    if (jobStatus === 'completed') {
      toast.show({ tone: 'success', title: t('privacySettings.export.ready') });
    } else if (jobStatus === 'failed') {
      toast.show({ tone: 'danger', title: t('privacySettings.export.failed') });
    }
  }, [jobStatus, toast, t, queryClient]);

  const request = useMutation({
    mutationFn: () => withReauth(privacyApi.requestExport),
    onSuccess: (created) => {
      queryClient.setQueryData(privacyKeys.exportJob(created.id), created);
      void queryClient.invalidateQueries({ queryKey: privacyKeys.exports() });
      setParams(
        (current) => {
          const next = new URLSearchParams(current);
          next.set('export', created.id);
          return next;
        },
        { replace: true },
      );
    },
  });
  const download = useMutation({
    mutationFn: async (fileId: string) => {
      await downloadExport(await privacyApi.fileAccess(fileId));
    },
  });

  const startExport = () => {
    if (request.isPending) return;
    setRequestError(null);
    request.mutate(undefined, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('privacySettings.export.requested') });
      },
      onError: (error) => {
        if (isReauthCancelled(error)) return;
        setRequestError(describeError(error, t));
      },
    });
  };

  const startDownload = (fileId: string) => {
    if (download.isPending) return;
    download.mutate(fileId, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('privacySettings.export.downloadStarted') });
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('privacySettings.export.downloadFailed'),
          description:
            hasErrorCode(error, 'NOT_FOUND') || hasErrorCode(error, 'GONE')
              ? t('privacySettings.export.downloadGone')
              : describeError(error, t),
        });
      },
    });
  };

  const requestButton = (label: string, variant: 'primary' | 'secondary' = 'primary') => (
    <Button variant={variant} loading={request.isPending} onClick={startExport}>
      <Icon name="download" className="size-4" />
      {label}
    </Button>
  );

  let status;
  if (exportId === null && exports.isPending) {
    status = <LoadingState label={t('privacySettings.export.checking')} />;
  } else if (exportId === null && exports.isError) {
    status = (
      <ErrorState
        titleAs="h3"
        title={t('privacySettings.export.listError')}
        error={exports.error}
        retrying={exports.isFetching}
        onRetry={() => {
          void exports.refetch();
        }}
      />
    );
  } else if (exportId === null) {
    status = requestButton(t('privacySettings.export.request'));
  } else if (job.isPending) {
    status = <LoadingState label={t('privacySettings.export.checking')} />;
  } else if (job.isError) {
    status = hasErrorCode(job.error, 'NOT_FOUND') ? (
      <div className="space-y-4">
        <Alert tone="info">{t('privacySettings.export.notFound')}</Alert>
        {requestButton(t('privacySettings.export.request'))}
      </div>
    ) : (
      <ErrorState
        titleAs="h3"
        title={t('privacySettings.export.checkFailed')}
        error={job.error}
        retrying={job.isFetching}
        onRetry={() => {
          void job.refetch();
        }}
      />
    );
  } else {
    const current = job.data;
    const expires = parseTimestamp(current.expires_at);
    if (isExportActive(current)) {
      status = (
        <div className="space-y-4">
          <div role="status" className="flex items-start gap-3 rounded-lg bg-surface-muted p-4">
            <Spinner size="sm" />
            <div className="space-y-1 text-sm">
              <p className="font-semibold text-fg">
                {current.status === 'queued'
                  ? t('privacySettings.export.queued')
                  : t('privacySettings.export.running')}
              </p>
              <p className="text-fg-muted">
                {stalled ? t('privacySettings.export.stalled') : t('privacySettings.export.wait')}
              </p>
            </div>
          </div>
          {stalled ? (
            <Button
              variant="secondary"
              loading={job.isFetching}
              onClick={() => {
                void job.refetch();
              }}
            >
              <Icon name="refresh" className="size-4" />
              {t('privacySettings.export.checkAgain')}
            </Button>
          ) : null}
        </div>
      );
    } else if (current.status === 'completed' && current.file_id && !isExpired(current, now)) {
      const fileId = current.file_id;
      status = (
        <div className="space-y-4">
          <Alert tone="success" live="polite" title={t('privacySettings.export.ready')}>
            {expires ? (
              <p>
                {t('privacySettings.export.availableUntil', {
                  date: formatDateTime(expires, formatLocale, user.timezone),
                })}
              </p>
            ) : null}
          </Alert>
          <div className="flex flex-wrap gap-3">
            <Button
              loading={download.isPending}
              onClick={() => {
                startDownload(fileId);
              }}
            >
              <Icon name="download" className="size-4" />
              {t('privacySettings.export.download')}
            </Button>
            {requestButton(t('privacySettings.export.requestNew'), 'secondary')}
          </div>
        </div>
      );
    } else if (current.status === 'failed') {
      status = (
        <div className="space-y-4">
          <Alert tone="danger" live="polite" title={t('privacySettings.export.failed')}>
            <p>{t('privacySettings.export.failedBody')}</p>
          </Alert>
          {requestButton(t('privacySettings.export.tryAgain'))}
        </div>
      );
    } else {
      status = (
        <div className="space-y-4">
          <Alert tone="info" live="polite" title={t('privacySettings.export.expired')}>
            <p>{t('privacySettings.export.expiredBody')}</p>
          </Alert>
          {requestButton(t('privacySettings.export.requestNew'))}
        </div>
      );
    }
  }

  return (
    <Card
      title={t('privacySettings.export.title')}
      description={t('privacySettings.export.description')}
    >
      <div className="space-y-4">
        <ul className="list-disc space-y-1 ps-5 text-sm text-fg-muted">
          <li>{t('privacySettings.export.contents')}</li>
          <li>{t('privacySettings.export.secrets')}</li>
          <li>
            {downloadDays !== null
              ? t('privacySettings.export.window', { count: downloadDays })
              : t('privacySettings.export.windowUnknown')}
          </li>
          <li>{t('privacySettings.export.reauth')}</li>
        </ul>
        <FormAlert message={requestError} />
        {status}
        <EarlierExports
          exports={(exports.data ?? []).filter((item) => item.id !== exportId)}
          now={now}
          downloading={download.isPending ? download.variables : null}
          onDownload={startDownload}
        />
      </div>
    </Card>
  );
}
