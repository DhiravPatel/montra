import { api } from '@/shared/api/client';
import { rememberCsrfToken } from '@/shared/api/csrf';
import { isApiError } from '@/shared/api/errors';
import { apiData } from '@/shared/api/request';
import type { Session, User } from '@/shared/api/types';

export interface AuthSession {
  user: User;
  session: Session;
}

export const sessionQueryKey = ['auth', 'session'] as const;

/**
 * Loads the signed-in user and session (`GET /auth/session`). Resolves to
 * null when there is no valid session; other failures (offline, 5xx) throw
 * so the UI can offer a retry instead of signing the user out.
 */
export async function fetchSession(signal?: AbortSignal): Promise<AuthSession | null> {
  try {
    const result = await apiData(api.GET('/auth/session', signal ? { signal } : {}));
    rememberCsrfToken(result.csrf_token);
    if (result.status !== 'authenticated' || !result.user || !result.session) return null;
    return { user: result.user, session: result.session };
  } catch (error) {
    if (isApiError(error) && error.status === 401) return null;
    throw error;
  }
}
