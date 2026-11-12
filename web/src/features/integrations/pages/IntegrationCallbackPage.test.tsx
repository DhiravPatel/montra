import { screen, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { beforeEach, describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  OAUTH_STATE,
  makeConnection,
  makeOverview,
  sandboxProvider,
  serveOverview,
} from '@/tests/integrationsFixtures';
import { serveUnreadCount } from '@/tests/notificationsFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });
const main = () => within(screen.getByRole('main'));
const CODE = 'good-code';

/** Serves the API callback and records each call's provider and query. */
function serveCallback(respond: () => Response) {
  const calls: { provider: string; query: URLSearchParams }[] = [];
  server.use(
    http.get(`${API}/integrations/:ref/callback`, ({ request, params }) => {
      calls.push({ provider: String(params.ref), query: new URL(request.url).searchParams });
      return respond();
    }),
  );
  return calls;
}

beforeEach(() => {
  serveUnreadCount(0);
  serveOverview(makeOverview([sandboxProvider()]));
});

describe('IntegrationCallbackPage', () => {
  it('finishes the connection once with the code and state, then clears them from the URL', async () => {
    const calls = serveCallback(() => HttpResponse.json(envelope(makeConnection())));
    const { router } = renderRoute(
      `/settings/integrations/sandbox_bank/callback?state=${OAUTH_STATE}&code=${CODE}`,
      { user: signedIn() },
    );
    await findPageHeading('Finishing your connection');
    expect(await main().findByText('Connected to Sandbox Bank')).toBeInTheDocument();
    expect(main().getByText(/Montra is importing your transactions now/)).toBeInTheDocument();
    expect(calls).toHaveLength(1);
    expect(calls[0]?.provider).toBe('sandbox_bank');
    expect(calls[0]?.query.get('state')).toBe(OAUTH_STATE);
    expect(calls[0]?.query.get('code')).toBe(CODE);
    // The one-time values leave the address bar and the history entry.
    expect(router.state.location.pathname).toBe('/settings/integrations/sandbox_bank/callback');
    expect(router.state.location.search).toBe('');
    expect(main().getByRole('link', { name: 'Back to integrations' })).toHaveAttribute(
      'href',
      '/settings/integrations',
    );
  });

  it('explains an expired or already used request', async () => {
    const calls = serveCallback(() =>
      HttpResponse.json(errorBody({ code: 'GONE', message: 'This connection request expired.' }), {
        status: 410,
      }),
    );
    renderRoute(`/settings/integrations/sandbox_bank/callback?state=${OAUTH_STATE}&code=${CODE}`, {
      user: signedIn(),
    });
    await findPageHeading('Finishing your connection');
    expect(
      await main().findByText('This connection request expired or was already used'),
    ).toBeInTheDocument();
    expect(main().getByText(/A connection request works once, for 30 minutes/)).toBeInTheDocument();
    expect(calls).toHaveLength(1);
  });

  it('explains when the provider did not complete the connection', async () => {
    serveCallback(() =>
      HttpResponse.json(errorBody({ code: 'PROVIDER_UNAVAILABLE' }), { status: 503 }),
    );
    renderRoute(`/settings/integrations/sandbox_bank/callback?state=${OAUTH_STATE}&code=bad-code`, {
      user: signedIn(),
    });
    await findPageHeading('Finishing your connection');
    expect(await main().findByText('The connection wasn’t completed')).toBeInTheDocument();
    expect(
      main().getByText(/The service didn’t complete the connection, so nothing was saved/),
    ).toBeInTheDocument();
    expect(main().getByRole('link', { name: 'Back to integrations' })).toBeInTheDocument();
  });

  it('says nothing was shared when the user declined at the provider', async () => {
    const calls = serveCallback(() => HttpResponse.json(envelope(makeConnection())));
    renderRoute(
      `/settings/integrations/sandbox_bank/callback?error=access_denied&state=${OAUTH_STATE}`,
      { user: signedIn() },
    );
    await findPageHeading('Finishing your connection');
    expect(await main().findByText('You didn’t approve the connection')).toBeInTheDocument();
    expect(
      await main().findByText(/Nothing was shared with Montra from Sandbox Bank/),
    ).toBeInTheDocument();
    expect(calls).toHaveLength(0);
  });

  it('does not call the API without both a code and a state', async () => {
    const calls = serveCallback(() => HttpResponse.json(envelope(makeConnection())));
    renderRoute(`/settings/integrations/sandbox_bank/callback?code=${CODE}`, { user: signedIn() });
    await findPageHeading('Finishing your connection');
    expect(main().getByText('This page is missing the service’s answer')).toBeInTheDocument();
    expect(calls).toHaveLength(0);
  });
});
