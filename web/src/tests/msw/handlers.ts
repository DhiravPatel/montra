import { http, HttpResponse } from 'msw';
import { API, envelope, errorBody, testCurrencies } from '../fixtures';
import { currentSession, testBackend } from './backend';

const unauthenticated = () =>
  HttpResponse.json(
    errorBody({ code: 'UNAUTHENTICATED', message: 'Authentication is required.' }),
    { status: 401 },
  );

/** Default handlers shaped like the contract; individual tests override with server.use(). */
export const handlers = [
  http.get(`${API}/auth/session`, () => {
    const user = testBackend.user;
    if (!user) return unauthenticated();
    return HttpResponse.json(
      envelope({
        status: 'authenticated',
        user,
        session: currentSession(),
        csrf_token: 'csrf-from-session',
      }),
    );
  }),
  http.post(`${API}/auth/refresh`, () =>
    HttpResponse.json(
      errorBody({ code: 'UNAUTHENTICATED', message: 'Your session has expired. Sign in again.' }),
      {
        status: 401,
      },
    ),
  ),
  http.post(`${API}/auth/logout`, () => {
    testBackend.user = null;
    return HttpResponse.json(envelope({ ok: true }));
  }),
  http.post(`${API}/auth/logout-all`, () => {
    testBackend.user = null;
    return HttpResponse.json(envelope({ ok: true }));
  }),
  http.get(`${API}/currencies`, () => HttpResponse.json(envelope(testCurrencies))),
  http.get(`${API}/me/sessions`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope(testBackend.sessions));
  }),

  // The shell's notification bell polls this on every signed-in page.
  http.get(`${API}/notifications/unread-count`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope({ unread: 0 }));
  }),

  // Finance reference data (reads only).
  http.get(`${API}/accounts`, ({ request }) => {
    if (!testBackend.user) return unauthenticated();
    const archived = new URL(request.url).searchParams.get('include_archived') === 'true';
    return HttpResponse.json(
      envelope(testBackend.accounts.filter((account) => archived || account.status === 'active')),
    );
  }),
  http.get(`${API}/categories`, ({ request }) => {
    if (!testBackend.user) return unauthenticated();
    const archived = new URL(request.url).searchParams.get('include_archived') === 'true';
    return HttpResponse.json(
      envelope(
        testBackend.categories.filter((category) => archived || category.status === 'active'),
      ),
    );
  }),
  http.get(`${API}/tags`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope(testBackend.tags));
  }),
  http.get(`${API}/merchants`, ({ request }) => {
    if (!testBackend.user) return unauthenticated();
    const q = (new URL(request.url).searchParams.get('q') ?? '').toLowerCase();
    return HttpResponse.json(
      envelope(testBackend.merchants.filter((merchant) => merchant.name.toLowerCase().includes(q))),
    );
  }),
  http.get(`${API}/payment-methods`, ({ request }) => {
    if (!testBackend.user) return unauthenticated();
    const archived = new URL(request.url).searchParams.get('include_archived') === 'true';
    return HttpResponse.json(
      envelope(testBackend.paymentMethods.filter((method) => archived || !method.archived_at)),
    );
  }),
  http.get(`${API}/me/preferences`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope(testBackend.preferences));
  }),
  http.get(`${API}/me/onboarding`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope(testBackend.onboarding));
  }),
  http.get(`${API}/dashboard/widgets`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope(testBackend.widgets));
  }),
  http.get(`${API}/analytics/accounts`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope(testBackend.accountTotals));
  }),

  // People and groups to share with (reads only).
  http.get(`${API}/connections`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope(testBackend.people));
  }),
  http.get(`${API}/groups`, () => {
    if (!testBackend.user) return unauthenticated();
    return HttpResponse.json(envelope(testBackend.groups));
  }),
  http.get(`${API}/groups/:id`, ({ params }) => {
    if (!testBackend.user) return unauthenticated();
    const group = testBackend.groupDetails[String(params.id)];
    if (!group) {
      return HttpResponse.json(errorBody({ code: 'NOT_FOUND', message: 'Not found.' }), {
        status: 404,
      });
    }
    return HttpResponse.json(envelope(group));
  }),
];
