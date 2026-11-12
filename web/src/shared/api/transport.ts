import createClient, { type Client, type Middleware } from 'openapi-fetch';
import { appConfig } from '@/shared/config/env';
import { getCsrfToken } from './csrf';
import type { paths } from './schema';

const UNSAFE_METHODS: ReadonlySet<string> = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

export function isUnsafeMethod(method: string): boolean {
  return UNSAFE_METHODS.has(method.toUpperCase());
}

/** Resolves the configured base (path or URL) against the page origin, without a trailing slash. */
export function resolveApiBaseUrl(configured: string, origin: string): string {
  return new URL(configured, origin).toString().replace(/\/+$/, '');
}

export const apiBaseUrl = resolveApiBaseUrl(appConfig.apiBaseUrl, window.location.origin);

/** Same-origin API: session cookies are first-party and `montra_csrf` is readable. */
export const apiIsSameOrigin = new URL(apiBaseUrl).origin === window.location.origin;

/** Adds client identification and the CSRF header to every request. */
export const clientHeadersMiddleware: Middleware = {
  onRequest({ request }) {
    request.headers.set('Accept', 'application/json');
    request.headers.set('X-Montra-Client', 'web');
    request.headers.set('X-Client-Version', appConfig.clientVersion);
    if (isUnsafeMethod(request.method)) {
      const token = getCsrfToken();
      if (token) request.headers.set('X-CSRF-Token', token);
    }
    return request;
  },
};

export type MontraClient = Client<paths>;

export function createMontraClient(...middleware: Middleware[]): MontraClient {
  const client = createClient<paths>({
    baseUrl: apiBaseUrl,
    // Session cookies (montra_at / montra_rt) are HttpOnly and sent by the browser.
    credentials: 'include',
    // Resolve fetch at call time so interceptors installed after import are honoured.
    fetch: (request: Request) => globalThis.fetch(request),
  });
  client.use(clientHeadersMiddleware, ...middleware);
  return client;
}

/** Client without automatic session recovery; used by the recovery logic itself. */
export const rawApi: MontraClient = createMontraClient();
