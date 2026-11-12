import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useId, useRef, useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { useToast } from '@/shared/components/toast/ToastContext';
import { invalidateFinance } from '@/shared/finance/keys';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { hasActiveRun, integrationsApi, useConnectionStatus } from '../api';
import { integrationErrorMessage } from '../errors';
import { integrationsKeys } from '../keys';
import { NEEDS_RECONNECT, SYNCABLE, connectionStatusLook, errorCodeKey } from '../labels';
import type { Connection, Provider } from '../types';
import { SyncHistory } from './SyncHistory';

interface ConnectionItemProps {
  connection: Connection;
  provider: Provider | undefined;
  /** The linked Montra account's name, when known. */
  accountName: string | null;
  timeZone: string;
  onReconnect: (provider: Provider) => void;
  onDisconnect: (connection: Connection, mode: 'disconnect' | 'delete-data') => void;
}

/**
 * One connection with its honest status, consent window and last sync,
 * plus sync now, sync history, reconnect and disconnect. Actions the
 * server would refuse are not offered (e.g. syncing a provider that is no
 * longer available, or a connection whose consent expired).
 */
export function ConnectionItem({
  connection,
  provider,
  accountName,
  timeZone,
  onReconnect,
  onDisconnect,
}: ConnectionItemProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const historyId = useId();
  const [historyOpen, setHistoryOpen] = useState(false);
  const status = useConnectionStatus(connection.id, historyOpen);
  const sync = useMutation({
    mutationFn: () => integrationsApi.sync(connection.id),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: integrationsKeys.status(connection.id) }),
        queryClient.invalidateQueries({ queryKey: integrationsKeys.overview() }),
      ]),
  });

  // When a sync finishes, refresh the overview and every finance view (new transactions).
  const active = hasActiveRun(status.data);
  const wasActive = useRef(active);
  useEffect(() => {
    if (wasActive.current && !active) {
      void queryClient.invalidateQueries({ queryKey: integrationsKeys.overview() });
      void invalidateFinance(queryClient);
    }
    wasActive.current = active;
  }, [active, queryClient]);

  const name = provider?.name ?? t('integrations.connection.unknownProvider');
  const look = connectionStatusLook[connection.status];
  const available = provider?.status === 'available';
  const canSync = available && SYNCABLE.has(connection.status);
  const canReconnect =
    available &&
    (NEEDS_RECONNECT.has(connection.status) ||
      connection.status === 'pending' ||
      (connection.status === 'failed' && connection.last_error_code === 'token_exchange_failed'));
  const ended = connection.status === 'revoked' || connection.status === 'disconnected';
  const expires = parseTimestamp(connection.consent_expires_at);
  const lastSync = parseTimestamp(connection.last_sync_at);
  const errorKey = errorCodeKey(connection.last_error_code);

  const syncNow = () => {
    if (sync.isPending) return;
    sync.mutate(undefined, {
      onSuccess: () => {
        setHistoryOpen(true);
        toast.show({
          tone: 'success',
          title: t('integrations.sync.started'),
          description: t('integrations.sync.startedBody'),
        });
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('integrations.sync.failed'),
          description: integrationErrorMessage(error, t, 'sync'),
        });
      },
    });
  };

  return (
    <li className="py-5 first:pt-0 last:pb-0">
      <div className="flex flex-wrap items-center gap-2">
        <h3 className="text-base font-semibold text-fg">{name}</h3>
        <StatusBadge tone={look.tone} icon={look.icon}>
          {t(look.label)}
        </StatusBadge>
      </div>
      <dl className="mt-2 grid gap-1 text-sm sm:grid-cols-2">
        {accountName ? (
          <div className="flex gap-1">
            <dt className="text-fg-muted">{t('integrations.connection.account')}</dt>
            <dd className="font-medium text-fg">{accountName}</dd>
          </div>
        ) : null}
        {expires && !ended ? (
          <div className="flex gap-1">
            <dt className="text-fg-muted">
              {connection.status === 'consent_expired'
                ? t('integrations.connection.consentEnded')
                : t('integrations.connection.consentUntil')}
            </dt>
            <dd className="text-fg">{formatDateTime(expires, formatLocale, timeZone)}</dd>
          </div>
        ) : null}
        <div className="flex gap-1">
          <dt className="text-fg-muted">{t('integrations.connection.lastSync')}</dt>
          <dd className="text-fg">
            {lastSync
              ? formatDateTime(lastSync, formatLocale, timeZone)
              : t('integrations.connection.never')}
          </dd>
        </div>
      </dl>
      {errorKey ? <p className="mt-2 text-sm text-fg">{t(errorKey)}</p> : null}
      {connection.status === 'consent_expired' ? (
        <p className="mt-2 text-sm text-fg">{t('integrations.connection.expiredHelp')}</p>
      ) : null}
      {provider && provider.status !== 'available' && !ended ? (
        <p className="mt-2 text-sm text-fg">{t('integrations.connection.providerGone')}</p>
      ) : null}
      <div className="mt-3 flex flex-wrap gap-2">
        {canSync ? (
          <Button
            variant="secondary"
            size="sm"
            loading={sync.isPending}
            aria-label={`${t('integrations.sync.action')}: ${name}`}
            onClick={syncNow}
          >
            <Icon name="refresh" className="size-4" />
            {t('integrations.sync.action')}
          </Button>
        ) : null}
        <Button
          variant="ghost"
          size="sm"
          aria-expanded={historyOpen}
          aria-controls={historyOpen ? historyId : undefined}
          onClick={() => {
            setHistoryOpen((open) => !open);
          }}
        >
          <Icon name="history" className="size-4" />
          {historyOpen ? t('integrations.history.hide') : t('integrations.history.show')}
        </Button>
        {canReconnect ? (
          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              onReconnect(provider);
            }}
          >
            <Icon name="link" className="size-4" />
            {connection.status === 'pending'
              ? t('integrations.connection.startAgain')
              : t('integrations.connection.reconnect')}
          </Button>
        ) : null}
        {ended ? (
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              onDisconnect(connection, 'delete-data');
            }}
          >
            <Icon name="trash" className="size-4" />
            {t('integrations.disconnect.dataAction')}
          </Button>
        ) : (
          <Button
            variant="ghost"
            size="sm"
            aria-label={`${t('integrations.disconnect.action')}: ${name}`}
            onClick={() => {
              onDisconnect(connection, 'disconnect');
            }}
          >
            <Icon name="x-circle" className="size-4" />
            {t('integrations.disconnect.action')}
          </Button>
        )}
      </div>
      {historyOpen ? <SyncHistory id={historyId} status={status} timeZone={timeZone} /> : null}
    </li>
  );
}
