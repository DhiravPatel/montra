import { useQuery } from '@tanstack/react-query';
import { useSyncExternalStore } from 'react';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { integrationsKeys } from './keys';
import type {
  ConnectResult,
  ConnectionStatus,
  DisconnectResult,
  IntegrationsOverview,
  SyncRun,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/**
 * Financial-data integrations (spec §4.18, ADR-016/048). Montra never asks
 * for bank passwords, PINs, OTPs or CVVs: access is approved at the
 * provider (OAuth) and tokens stay encrypted on the server.
 */
export const integrationsApi = {
  overview: (signal?: AbortSignal): Promise<IntegrationsOverview> =>
    apiData(api.GET('/integrations', signalOption(signal))),
  /** Starts a consented connection and returns the provider's approval URL. */
  connect: (provider: string, accountId: string): Promise<ConnectResult> =>
    apiData(
      api.POST('/integrations/{ref}/connect', {
        params: { path: { ref: provider } },
        body: { account_id: accountId, consent_confirm: true },
      }),
    ),
  /** Finishes the OAuth return: the one-time state must match the caller's pending connection. */
  callback: (provider: string, state: string, code: string) =>
    apiData(
      api.GET('/integrations/{ref}/callback', {
        params: { path: { ref: provider }, query: { state, code } },
      }),
    ),
  status: (connectionId: string, signal?: AbortSignal): Promise<ConnectionStatus> =>
    apiData(
      api.GET('/integrations/{ref}/status', {
        params: { path: { ref: connectionId } },
        ...signalOption(signal),
      }),
    ),
  sync: (connectionId: string): Promise<SyncRun> =>
    apiData(api.POST('/integrations/{ref}/sync', { params: { path: { ref: connectionId } } })),
  disconnect: (connectionId: string, deleteData: boolean): Promise<DisconnectResult> =>
    apiData(
      api.DELETE('/integrations/{ref}', {
        params: { path: { ref: connectionId }, query: { confirm: true, delete_data: deleteData } },
      }),
    ),
};

/**
 * Leaves Montra for the provider's approval page. Kept behind an object so
 * tests can observe the redirect instead of navigating.
 */
export const browserNavigation = {
  assign(url: string): void {
    window.location.assign(url);
  },
};

/** Only HTTPS provider pages are ever opened (never script or data URLs). */
export function isSafeProviderUrl(value: string): boolean {
  try {
    return new URL(value).protocol === 'https:';
  } catch {
    return false;
  }
}

function subscribeVisibility(onChange: () => void) {
  document.addEventListener('visibilitychange', onChange);
  return () => {
    document.removeEventListener('visibilitychange', onChange);
  };
}

function usePageVisible(): boolean {
  return useSyncExternalStore(
    subscribeVisibility,
    () => document.visibilityState !== 'hidden',
    () => true,
  );
}

export function useIntegrations() {
  return useQuery({
    queryKey: integrationsKeys.overview(),
    queryFn: ({ signal }) => integrationsApi.overview(signal),
  });
}

const ACTIVE_RUN: ReadonlySet<SyncRun['status']> = new Set(['queued', 'running']);

/** A sync is waiting or running (status polls until it ends). */
export function hasActiveRun(status: ConnectionStatus | undefined): boolean {
  return (
    status?.status === 'syncing' || (status?.runs ?? []).some((run) => ACTIVE_RUN.has(run.status))
  );
}

/** How often an open sync history refreshes while a sync is running (tab visible only). */
export const STATUS_POLL_MS = 5_000;

/** A connection's status and its last 20 sync runs. */
export function useConnectionStatus(connectionId: string, enabled: boolean) {
  const visible = usePageVisible();
  return useQuery({
    queryKey: integrationsKeys.status(connectionId),
    queryFn: ({ signal }) => integrationsApi.status(connectionId, signal),
    enabled,
    refetchInterval: (query) =>
      visible && hasActiveRun(query.state.data) ? STATUS_POLL_MS : false,
  });
}
