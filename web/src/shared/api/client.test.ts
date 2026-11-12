import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import { API, envelope, errorBody, makeSession, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { api } from './client';
import { CSRF_COOKIE, rememberCsrfToken } from './csrf';
import { ApiError, CONTRACT_ERROR_CODES, parseRetryAfter, toApiError } from './errors';
import { describeError } from '@/shared/i18n/describeError';
import { createTranslator } from '@/shared/i18n/translate';
import { apiEvents } from './events';
import { apiData } from './request';

function setCsrfCookie(value: string) {
  document.cookie = `${CSRF_COOKIE}=${value}; path=/`;
}

const unauthenticated = () =>
  HttpResponse.json(
    errorBody({ code: 'UNAUTHENTICATED', message: 'Authentication is required.' }),
    { status: 401 },
  );

describe('request headers', () => {
  it('identifies the web client on every request and sends CSRF only on unsafe methods', async () => {
    setCsrfCookie('cookie-token');
    const seen: {
      method: string;
      client: string | null;
      version: string | null;
      csrf: string | null;
    }[] = [];
    server.use(
      http.get(`${API}/me/sessions`, ({ request }) => {
        seen.push({
          method: request.method,
          client: request.headers.get('X-Montra-Client'),
          version: request.headers.get('X-Client-Version'),
          csrf: request.headers.get('X-CSRF-Token'),
        });
        return HttpResponse.json(envelope([]));
      }),
      http.delete(`${API}/me/sessions/:sessionId`, ({ request }) => {
        seen.push({
          method: request.method,
          client: request.headers.get('X-Montra-Client'),
          version: request.headers.get('X-Client-Version'),
          csrf: request.headers.get('X-CSRF-Token'),
        });
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );

    await apiData(api.GET('/me/sessions'));
    await apiData(
      api.DELETE('/me/sessions/{sessionId}', { params: { path: { sessionId: 'abc' } } }),
    );

    expect(seen).toEqual([
      { method: 'GET', client: 'web', version: __APP_VERSION__, csrf: null },
      { method: 'DELETE', client: 'web', version: __APP_VERSION__, csrf: 'cookie-token' },
    ]);
  });

  it('falls back to the in-memory token when the CSRF cookie is not readable', async () => {
    rememberCsrfToken('memory-token');
    let csrf: string | null = null;
    server.use(
      http.post(`${API}/auth/logout`, ({ request }) => {
        csrf = request.headers.get('X-CSRF-Token');
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    await apiData(api.POST('/auth/logout'));
    expect(csrf).toBe('memory-token');
  });

  it('includes credentials so session cookies are sent', async () => {
    // MSW's Node interceptor rebuilds requests without `credentials`, so
    // inspect the Request handed to fetch instead.
    const fetchSpy = vi.spyOn(globalThis, 'fetch');
    server.use(http.get(`${API}/auth/session`, unauthenticated));
    await expect(apiData(api.GET('/auth/session'))).rejects.toBeInstanceOf(ApiError);
    const sent = fetchSpy.mock.calls[0]?.[0];
    expect(sent).toBeInstanceOf(Request);
    expect((sent as Request).credentials).toBe('include');
  });
});

describe('session refresh', () => {
  it('refreshes once for concurrent 401s and retries every request', async () => {
    setCsrfCookie('cookie-token');
    let refreshed = false;
    let refreshCalls = 0;
    let sessionCalls = 0;
    server.use(
      http.get(`${API}/me/sessions`, async () => {
        sessionCalls += 1;
        await delay(5);
        return refreshed ? HttpResponse.json(envelope([makeSession()])) : unauthenticated();
      }),
      http.post(`${API}/auth/refresh`, async ({ request }) => {
        refreshCalls += 1;
        expect(await request.json()).toEqual({}); // contract: body required, web relies on cookie
        await delay(20);
        refreshed = true;
        return HttpResponse.json(
          envelope({ status: 'authenticated', user: makeUser(), csrf_token: 'rotated' }),
        );
      }),
    );

    const results = await Promise.all([
      apiData(api.GET('/me/sessions')),
      apiData(api.GET('/me/sessions')),
      apiData(api.GET('/me/sessions')),
    ]);

    expect(results).toHaveLength(3);
    for (const sessions of results) expect(sessions).toHaveLength(1);
    expect(refreshCalls).toBe(1);
    expect(sessionCalls).toBe(6); // three originals + three retries
  });

  it('retries a write with its original body after refreshing', async () => {
    setCsrfCookie('cookie-token');
    let refreshed = false;
    const bodies: unknown[] = [];
    server.use(
      http.post(`${API}/me/password`, async ({ request }) => {
        bodies.push(await request.json());
        return refreshed ? HttpResponse.json(envelope({ ok: true })) : unauthenticated();
      }),
      http.post(`${API}/auth/refresh`, () => {
        refreshed = true;
        return HttpResponse.json(envelope({ status: 'authenticated', csrf_token: 'rotated' }));
      }),
    );

    await apiData(
      api.POST('/me/password', {
        body: { current_password: 'old-secret', new_password: 'new-secret-123' },
      }),
    );

    const expected = { current_password: 'old-secret', new_password: 'new-secret-123' };
    expect(bodies).toEqual([expected, expected]);
  });

  it('signals session expiry when the refresh is rejected, without looping', async () => {
    setCsrfCookie('cookie-token');
    const expired = vi.fn();
    const unsubscribe = apiEvents.on('session-expired', expired);
    let refreshCalls = 0;
    server.use(
      http.get(`${API}/me/sessions`, unauthenticated),
      http.post(`${API}/auth/refresh`, () => {
        refreshCalls += 1;
        return unauthenticated();
      }),
      http.get(`${API}/auth/session`, unauthenticated),
    );

    const error = await apiData(api.GET('/me/sessions')).catch((failure: unknown) => failure);

    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).code).toBe('UNAUTHENTICATED');
    expect(refreshCalls).toBe(1);
    expect(expired).toHaveBeenCalledTimes(1);
    unsubscribe();
  });

  it('skips the refresh call when this browser holds no session cookies', async () => {
    const expired = vi.fn();
    const unsubscribe = apiEvents.on('session-expired', expired);
    const refresh = vi.fn(() => unauthenticated());
    server.use(
      http.get(`${API}/auth/session`, unauthenticated),
      http.post(`${API}/auth/refresh`, refresh),
    );

    await expect(apiData(api.GET('/auth/session'))).rejects.toMatchObject({
      code: 'UNAUTHENTICATED',
    });
    expect(refresh).not.toHaveBeenCalled();
    expect(expired).toHaveBeenCalledTimes(1);
    unsubscribe();
  });

  it('does not refresh on REAUTH_REQUIRED (a 401 about the request, not the session)', async () => {
    setCsrfCookie('cookie-token');
    const refresh = vi.fn(() => HttpResponse.json(envelope({ status: 'authenticated' })));
    server.use(
      http.post(`${API}/me/mfa/totp/setup`, () =>
        HttpResponse.json(
          errorBody({ code: 'REAUTH_REQUIRED', message: 'Confirm your password to continue.' }),
          {
            status: 401,
          },
        ),
      ),
      http.post(`${API}/auth/refresh`, refresh),
    );

    await expect(apiData(api.POST('/me/mfa/totp/setup'))).rejects.toMatchObject({
      status: 401,
      code: 'REAUTH_REQUIRED',
    });
    expect(refresh).not.toHaveBeenCalled();
  });

  it('does not refresh when login itself is rejected', async () => {
    setCsrfCookie('cookie-token');
    const refresh = vi.fn(() => unauthenticated());
    server.use(
      http.post(`${API}/auth/login`, () =>
        HttpResponse.json(
          errorBody({ code: 'UNAUTHENTICATED', message: 'Invalid email or password.' }),
          {
            status: 401,
          },
        ),
      ),
      http.post(`${API}/auth/refresh`, refresh),
    );
    await expect(
      apiData(
        api.POST('/auth/login', { body: { email: 'a@example.com', password: 'wrong-password' } }),
      ),
    ).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
    expect(refresh).not.toHaveBeenCalled();
  });

  it('re-reads the CSRF token and retries once after CSRF_FAILED', async () => {
    rememberCsrfToken('stale-token');
    const tokens: (string | null)[] = [];
    server.use(
      http.post(`${API}/auth/logout-all`, ({ request }) => {
        const token = request.headers.get('X-CSRF-Token');
        tokens.push(token);
        return token === 'fresh-token'
          ? HttpResponse.json(envelope({ ok: true }))
          : HttpResponse.json(errorBody({ code: 'CSRF_FAILED' }), { status: 403 });
      }),
      http.get(`${API}/auth/session`, () =>
        HttpResponse.json(
          envelope({ status: 'authenticated', user: makeUser(), csrf_token: 'fresh-token' }),
        ),
      ),
    );

    await apiData(api.POST('/auth/logout-all'));
    expect(tokens).toEqual(['stale-token', 'fresh-token']);
  });
});

describe('error mapping', () => {
  it('maps the error envelope, field details and Retry-After', async () => {
    server.use(
      http.post(`${API}/auth/register`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            message: 'The request could not be processed.',
            details: [{ field: 'body.password', message: 'This password is too common.' }],
            request_id: 'req-123',
          }),
          { status: 422, headers: { 'Retry-After': '17' } },
        ),
      ),
    );

    const error = await apiData(
      api.POST('/auth/register', {
        body: {
          email: 'a@example.com',
          password: 'password123',
          display_name: 'A',
          accept_terms: true,
          confirm_adult: true,
          terms_version: '2026-11-01',
          privacy_version: '2026-11-01',
        },
      }),
    ).catch((failure: unknown) => failure);

    expect(error).toBeInstanceOf(ApiError);
    expect(error).toMatchObject({
      status: 422,
      code: 'VALIDATION_ERROR',
      requestId: 'req-123',
      retryAfterSeconds: 17,
      details: [{ field: 'body.password', message: 'This password is too common.' }],
    });
  });

  it('maps non-JSON gateway errors by status and keeps the request ID header', async () => {
    server.use(
      http.get(
        `${API}/me/sessions`,
        () =>
          new HttpResponse('<html>Bad gateway</html>', {
            status: 502,
            headers: { 'Content-Type': 'text/html', 'X-Request-ID': 'gw-1' },
          }),
      ),
    );
    await expect(apiData(api.GET('/me/sessions'))).rejects.toMatchObject({
      status: 502,
      code: 'SERVICE_UNAVAILABLE',
      requestId: 'gw-1',
    });
  });

  it('reports network failures as NETWORK_ERROR', async () => {
    server.use(http.get(`${API}/me/sessions`, () => HttpResponse.error()));
    await expect(apiData(api.GET('/me/sessions'))).rejects.toMatchObject({
      status: 0,
      code: 'NETWORK_ERROR',
    });
  });

  it('parses Retry-After seconds and HTTP dates', () => {
    expect(parseRetryAfter('30')).toBe(30);
    expect(parseRetryAfter(null)).toBeNull();
    expect(parseRetryAfter('soon')).toBeNull();
    const now = Date.parse('2026-11-04T10:00:00Z');
    expect(parseRetryAfter('Wed, 04 Nov 2026 10:00:45 GMT', now)).toBe(45);
  });

  it('builds an ApiError even when the body is empty', () => {
    const error = toApiError(new Response(null, { status: 404 }), undefined);
    expect(error.code).toBe('NOT_FOUND');
    expect(error.details).toEqual([]);
  });

  it('degrades codes newer than this client to UNKNOWN_ERROR but keeps the raw code', () => {
    const error = toApiError(
      new Response(null, { status: 422 }),
      errorBody({ code: 'SOME_FUTURE_CODE', message: 'New rule.' }),
    );
    expect(error.code).toBe('UNKNOWN_ERROR');
    expect(error.rawCode).toBe('SOME_FUTURE_CODE');
  });

  it('has a specific localized message for every contract error code', () => {
    const t = createTranslator('en', 'en');
    const generic = t('errors.UNKNOWN_ERROR');
    for (const code of CONTRACT_ERROR_CODES) {
      const message = describeError(new ApiError({ status: 400, code, message: 'x' }), t);
      expect(message, code).not.toBe(generic);
      expect(message, code).not.toMatch(/^errors\./);
    }
  });

  it('describes throttling with the wait from Retry-After', () => {
    const t = createTranslator('en', 'en');
    const throttled = new ApiError({
      status: 429,
      code: 'LOGIN_THROTTLED',
      message: 'x',
      retryAfterSeconds: 900,
    });
    expect(describeError(throttled, t)).toBe(
      'Too many failed sign-in attempts. Try again in 15 minutes or reset your password.',
    );
  });
});
