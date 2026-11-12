import type { Middleware } from 'openapi-fetch';
import { getCsrfToken, readCsrfCookie, rememberCsrfToken } from './csrf';
import { apiEvents } from './events';
import { apiIsSameOrigin, isUnsafeMethod, rawApi } from './transport';

/**
 * Automatic session recovery for cookie-authenticated requests.
 *
 * - A 401 `UNAUTHENTICATED` from a protected endpoint triggers ONE refresh
 *   (`POST /auth/refresh`). Concurrent failures share the same in-flight
 *   refresh (single flight); each original request is then retried once.
 * - Other 401 codes (`REAUTH_REQUIRED`, `MFA_REQUIRED`) are answers about the
 *   request itself and are passed through untouched.
 * - When the session cannot be renewed, `session-expired` is emitted so the
 *   auth layer clears client state and routes to sign-in.
 * - A 403 `CSRF_FAILED` re-reads the session's CSRF token and retries once.
 */

/** Endpoints whose 401 describes the submitted credentials, not an expired session. */
const NO_RECOVERY_PATHS: ReadonlySet<string> = new Set([
  '/auth/login',
  '/auth/register',
  '/auth/refresh',
  '/auth/mfa/verify',
  '/auth/password/forgot',
  '/auth/password/reset',
  '/auth/email/verify',
  '/auth/email/resend',
]);

export type RefreshOutcome = 'refreshed' | 'expired' | 'unavailable';

/** Incremented whenever session cookies are known to have been renewed. */
let sessionGeneration = 0;
let inflightRefresh: Promise<RefreshOutcome> | null = null;

async function performRefresh(): Promise<RefreshOutcome> {
  try {
    // Web relies on the HttpOnly cookie; `{}` is accepted by every API build (the body is optional now).
    const refreshed = await rawApi.POST('/auth/refresh', { body: {} });
    if (refreshed.response.ok && refreshed.data) {
      rememberCsrfToken(refreshed.data.data.csrf_token);
      sessionGeneration += 1;
      return 'refreshed';
    }
    if (refreshed.response.status !== 401) return 'unavailable'; // rate limited, server error...
    // Another tab may have rotated the refresh token at the same moment; the
    // shared cookie jar then already holds the renewed session.
    const current = await rawApi.GET('/auth/session');
    if (current.response.ok && current.data) {
      rememberCsrfToken(current.data.data.csrf_token);
      sessionGeneration += 1;
      return 'refreshed';
    }
    return current.response.status === 401 ? 'expired' : 'unavailable';
  } catch {
    return 'unavailable'; // offline: keep the user signed in and let the request fail
  }
}

/** Renews the session once for all concurrent callers. */
export function refreshSession(): Promise<RefreshOutcome> {
  inflightRefresh ??= performRefresh().finally(() => {
    inflightRefresh = null;
  });
  return inflightRefresh;
}

async function ensureSession(sentAtGeneration: number): Promise<RefreshOutcome> {
  // The cookies were renewed after this request was sent: just retry it.
  if (sessionGeneration > sentAtGeneration) return 'refreshed';
  // Same-origin deployments can see the CSRF cookie, which lives exactly as
  // long as the refresh token: without it there is no session to renew, so
  // anonymous visitors do not spend rate-limited refresh calls.
  if (apiIsSameOrigin && readCsrfCookie() === null) return 'expired';
  return refreshSession();
}

/** Fetches the current session's CSRF token (after a CSRF_FAILED response). */
async function resyncCsrfToken(): Promise<boolean> {
  try {
    const current = await rawApi.GET('/auth/session');
    const token = current.data?.data.csrf_token;
    if (!current.response.ok || !token) return false;
    rememberCsrfToken(token);
    return true;
  } catch {
    return false;
  }
}

async function readErrorCode(response: Response): Promise<string | null> {
  try {
    const body: unknown = await response.clone().json();
    if (typeof body === 'object' && body !== null && 'error' in body) {
      const error: unknown = body.error;
      if (
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        typeof error.code === 'string'
      ) {
        return error.code;
      }
    }
  } catch {
    // not JSON
  }
  return null;
}

function withCurrentCsrf(request: Request): Request {
  if (!isUnsafeMethod(request.method)) return request;
  const headers = new Headers(request.headers);
  const token = getCsrfToken();
  if (token) headers.set('X-CSRF-Token', token);
  else headers.delete('X-CSRF-Token');
  return new Request(request, { headers });
}

interface PendingRequest {
  /** Unsent copy of the request (bodies can only be read once). */
  retry: Request;
  generation: number;
}

const pending = new Map<string, PendingRequest>();

export const sessionRecoveryMiddleware: Middleware = {
  onRequest({ request, schemaPath, id }) {
    if (!NO_RECOVERY_PATHS.has(schemaPath)) {
      pending.set(id, { retry: request.clone(), generation: sessionGeneration });
    }
    return undefined;
  },

  async onResponse({ response, id, options }) {
    const entry = pending.get(id);
    pending.delete(id);
    if (!entry) return undefined;

    if (response.status === 401 && (await readErrorCode(response)) === 'UNAUTHENTICATED') {
      const outcome = await ensureSession(entry.generation);
      if (outcome === 'refreshed') {
        const retried = await options.fetch(withCurrentCsrf(entry.retry));
        if (retried.status === 401 && (await readErrorCode(retried)) === 'UNAUTHENTICATED') {
          apiEvents.emit('session-expired');
        }
        return retried;
      }
      if (outcome === 'expired') apiEvents.emit('session-expired');
      return undefined;
    }

    if (
      response.status === 403 &&
      isUnsafeMethod(entry.retry.method) &&
      (await readErrorCode(response)) === 'CSRF_FAILED' &&
      (await resyncCsrfToken())
    ) {
      return options.fetch(withCurrentCsrf(entry.retry));
    }

    return undefined;
  },

  onError({ id }) {
    pending.delete(id);
    return undefined;
  },
};

/** Test hook: resets module state between test cases. */
export function resetSessionRecoveryForTests(): void {
  sessionGeneration = 0;
  inflightRefresh = null;
  pending.clear();
}
