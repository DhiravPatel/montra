import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import type { Session } from '@/shared/api/types';

export const sessionsQueryKey = ['me', 'sessions'] as const;

/** Account-security endpoints (session required). */
export const securityApi = {
  // List data is never null (empty lists are `[]`).
  listSessions: (signal?: AbortSignal): Promise<Session[]> =>
    apiData(api.GET('/me/sessions', signal ? { signal } : {})),
  revokeSession: (sessionId: string) =>
    apiData(api.DELETE('/me/sessions/{sessionId}', { params: { path: { sessionId } } })),
  changePassword: (currentPassword: string, newPassword: string) =>
    apiData(
      api.POST('/me/password', {
        body: { current_password: currentPassword, new_password: newPassword },
      }),
    ),
  startTotpSetup: () => apiData(api.POST('/me/mfa/totp/setup')),
  activateTotp: (code: string) => apiData(api.POST('/me/mfa/totp/activate', { body: { code } })),
  disableTotp: (proof: { code: string } | { recovery_code: string }) =>
    apiData(api.POST('/me/mfa/totp/disable', { body: proof })),
  regenerateRecoveryCodes: () => apiData(api.POST('/me/mfa/recovery-codes')),
};

/** Current device first, then most recently active. */
export function sortSessions(sessions: readonly Session[]): Session[] {
  return [...sessions].sort((a, b) => {
    if (a.current !== b.current) return a.current ? -1 : 1;
    return Date.parse(b.last_seen_at) - Date.parse(a.last_seen_at);
  });
}
