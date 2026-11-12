import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import type {
  Consent,
  ConsentGrant,
  Deletion,
  DeletionRequest,
  ExportJob,
  FileAccess,
  Legal,
  Limits,
  RevocableConsent,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/**
 * Consents, data export, deactivation and deletion (spec §4.1, §18). Export,
 * deactivation and deletion need a recent re-authentication: call them
 * through useReauth().withReauth().
 */
export const privacyApi = {
  /** Active consents, or every grant and withdrawal with `history`. */
  consents: (history: boolean, signal?: AbortSignal): Promise<Consent[]> =>
    apiData(
      api.GET('/me/consents', {
        params: { query: history ? { history: true } : {} },
        ...signalOption(signal),
      }),
    ),
  grant: (body: ConsentGrant): Promise<Consent> => apiData(api.POST('/me/consents', { body })),
  revoke: (consentType: RevocableConsent) =>
    apiData(api.DELETE('/me/consents/{consentType}', { params: { path: { consentType } } })),

  /** The current wording version of every consent type (send it with a grant). */
  legal: (signal?: AbortSignal): Promise<Legal> => apiData(api.GET('/legal', signalOption(signal))),

  /** Your data exports, newest first (a completed one past its window reads `expired`). */
  exports: (signal?: AbortSignal): Promise<ExportJob[]> =>
    apiData(api.GET('/me/exports', signalOption(signal))),
  /** Starts an export, or returns the one already in progress (re-authentication required). */
  requestExport: (): Promise<ExportJob> => apiData(api.POST('/me/export')),
  getExport: (exportId: string, signal?: AbortSignal): Promise<ExportJob> =>
    apiData(
      api.GET('/me/export/{exportId}', { params: { path: { exportId } }, ...signalOption(signal) }),
    ),
  /** A signed link (valid for minutes) to a ready file; ownership is checked on every call. */
  fileAccess: (fileId: string): Promise<FileAccess> =>
    apiData(api.GET('/files/{fileId}/access', { params: { path: { fileId } } })),

  /** Closes the account reversibly and signs out every session (re-authentication required). */
  deactivate: () => apiData(api.POST('/me/deactivate')),

  deletionStatus: (signal?: AbortSignal): Promise<Deletion> =>
    apiData(api.GET('/me/deletion-request', signalOption(signal))),
  /** Schedules deletion after the grace period (re-authentication required). */
  requestDeletion: (body: DeletionRequest): Promise<Deletion> =>
    apiData(api.POST('/me/deletion-request', { body })),
  cancelDeletion: (): Promise<Deletion> => apiData(api.DELETE('/me/deletion-request')),

  limits: (signal?: AbortSignal): Promise<Limits> =>
    apiData(api.GET('/limits', signalOption(signal))),
};
