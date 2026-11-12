import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useNow } from '@/shared/hooks/useNow';
import { privacyApi } from './api';
import { privacyKeys } from './keys';
import type { ExportJob } from './types';

export function useConsents() {
  return useQuery({
    queryKey: privacyKeys.consents(),
    queryFn: ({ signal }) => privacyApi.consents(false, signal),
  });
}

/** Every grant and withdrawal, loaded only when someone opens the history. */
export function useConsentHistory(enabled: boolean) {
  return useQuery({
    queryKey: privacyKeys.consentHistory(),
    queryFn: ({ signal }) => privacyApi.consents(true, signal),
    enabled,
  });
}

export function isExportActive(job: ExportJob | undefined): boolean {
  return job?.status === 'queued' || job?.status === 'running';
}

/** Polls stop after this many checks (about 15 minutes); the page then offers a manual check. */
export const EXPORT_POLL_LIMIT = 120;

/**
 * Checking an export while the worker prepares it: every 2 s for the first
 * minute, then every 10 s. TanStack Query pauses the polling while the tab
 * is in the background.
 */
export function exportPollInterval(job: ExportJob | undefined, checks: number): number | false {
  if (!isExportActive(job) || checks >= EXPORT_POLL_LIMIT) return false;
  return checks < 30 ? 2_000 : 10_000;
}

export function useExportJob(exportId: string | null) {
  return useQuery({
    queryKey: privacyKeys.exportJob(exportId ?? ''),
    queryFn: ({ signal }) => privacyApi.getExport(exportId ?? '', signal),
    enabled: exportId !== null,
    refetchInterval: (query) => exportPollInterval(query.state.data, query.state.dataUpdateCount),
  });
}

/** Your exports, newest first (GET /me/exports). */
export function useExports() {
  return useQuery({
    queryKey: privacyKeys.exports(),
    queryFn: ({ signal }) => privacyApi.exports(signal),
  });
}

/** Consent wording versions (GET /legal); they rarely change. */
export function useLegal() {
  return useQuery({
    queryKey: privacyKeys.legal(),
    queryFn: ({ signal }) => privacyApi.legal(signal),
    staleTime: 10 * 60_000,
  });
}

/**
 * True once polling has given up on an export that is still queued or
 * running (the page then offers a manual check). Re-evaluated every 15 s,
 * because the last poll may not change the export's data.
 */
export function useExportStalled(exportId: string | null, job: ExportJob | undefined): boolean {
  const queryClient = useQueryClient();
  useNow(15_000);
  if (exportId === null || !isExportActive(job)) return false;
  const checks = queryClient.getQueryState(privacyKeys.exportJob(exportId))?.dataUpdateCount ?? 0;
  return checks >= EXPORT_POLL_LIMIT;
}

export function useDeletion() {
  return useQuery({
    queryKey: privacyKeys.deletion(),
    queryFn: ({ signal }) => privacyApi.deletionStatus(signal),
  });
}

export function useLimits() {
  return useQuery({
    queryKey: privacyKeys.limits(),
    queryFn: ({ signal }) => privacyApi.limits(signal),
  });
}
