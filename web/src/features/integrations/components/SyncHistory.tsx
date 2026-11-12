import type { UseQueryResult } from '@tanstack/react-query';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { integrationErrorMessage } from '../errors';
import { errorCodeKey, syncRunLook, syncTriggerLabel } from '../labels';
import type { ConnectionStatus } from '../types';

interface SyncHistoryProps {
  status: UseQueryResult<ConnectionStatus>;
  timeZone: string;
  id: string;
}

/** The connection's last 20 sync runs with their counts (refreshes while one runs). */
export function SyncHistory({ status, timeZone, id }: SyncHistoryProps) {
  const { t, formatLocale } = useI18n();

  let content;
  if (status.isPending) {
    content = <LoadingState label={t('integrations.history.loading')} />;
  } else if (status.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('integrations.history.error')}
        description={integrationErrorMessage(status.error, t, 'load')}
        error={status.error}
        retrying={status.isFetching}
        onRetry={() => {
          void status.refetch();
        }}
      />
    );
  } else if (status.data.runs.length === 0) {
    content = <p className="text-sm text-fg-muted">{t('integrations.history.empty')}</p>;
  } else {
    content = (
      <ol className="divide-y divide-line" aria-label={t('integrations.history.label')}>
        {status.data.runs.map((run) => {
          const look = syncRunLook[run.status];
          const at = run.finished_at ?? run.started_at ?? run.created_at;
          const when = parseTimestamp(at);
          const errorKey = errorCodeKey(run.error_code);
          return (
            <li key={run.id} className="space-y-1 py-3 first:pt-0 last:pb-0">
              <div className="flex flex-wrap items-center gap-2">
                <StatusBadge tone={look.tone} icon={look.icon}>
                  {t(look.label)}
                </StatusBadge>
                <span className="text-sm text-fg">{t(syncTriggerLabel[run.trigger])}</span>
                {when ? (
                  <time dateTime={at} className="text-sm text-fg-muted">
                    {formatDateTime(when, formatLocale, timeZone)}
                  </time>
                ) : null}
              </div>
              <p className="text-sm text-fg-muted">
                {t('integrations.history.counts', {
                  fetched: run.items_fetched,
                  created: run.items_created,
                  updated: run.items_updated,
                  skipped: run.items_skipped,
                })}
              </p>
              {errorKey ? <p className="text-sm text-fg">{t(errorKey)}</p> : null}
            </li>
          );
        })}
      </ol>
    );
  }

  return (
    <div id={id} className="mt-4 rounded-lg border border-line p-4">
      <h4 className="mb-3 text-sm font-semibold text-fg">{t('integrations.history.title')}</h4>
      {content}
    </div>
  );
}
