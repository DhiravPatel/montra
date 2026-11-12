import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ACCOUNT_CASH, makeAccount, makeCard } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CONNECTION_ID,
  aggregatorProvider,
  makeConnection,
  makeConnectionStatus,
  makeOverview,
  makeSyncRun,
  sandboxProvider,
  serveOverview,
} from '@/tests/integrationsFixtures';
import { serveUnreadCount } from '@/tests/notificationsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { browserNavigation } from '../api';

const signedIn = () => makeUser({ onboarding_completed: true });
const main = () => within(screen.getByRole('main'));
const AUTHORIZE_URL = 'https://sandbox-bank.example/authorize?state=abc&redirect_uri=x';

beforeEach(() => {
  serveUnreadCount(0);
  testBackend.accounts = [makeAccount(), makeCard()];
});

describe('IntegrationsPage: providers and consent', () => {
  it('shows the honest status of each provider and never offers unavailable ones', async () => {
    serveOverview(
      makeOverview([
        aggregatorProvider(),
        sandboxProvider({ id: 'card_feed', name: 'Card Feed', status: 'not_configured' }),
      ]),
    );
    renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');

    expect(main().getByText('Montra works fully without connections')).toBeInTheDocument();
    expect(
      main().getByText(/Montra never asks for your bank password, UPI PIN, OTP or card CVV/),
    ).toBeInTheDocument();
    const providers = await main().findByRole('region', { name: 'Services' });
    expect(
      within(providers).getByText(
        'None of these services can be connected yet. Each one says why.',
      ),
    ).toBeInTheDocument();
    expect(within(providers).getByText('Not available')).toBeInTheDocument();
    expect(
      within(providers).getByText(/Needs an approved Account Aggregator partner/),
    ).toBeInTheDocument();
    expect(within(providers).getByText('Not set up')).toBeInTheDocument();
    expect(within(providers).getByText(/isn’t set up on this Montra server/)).toBeInTheDocument();
    expect(
      within(providers).getByText('Would read: transactions, account balances'),
    ).toBeInTheDocument();
    expect(within(providers).queryByRole('button', { name: /^Connect/ })).not.toBeInTheDocument();

    const connections = main().getByRole('region', { name: 'Your connections' });
    expect(within(connections).getByText('No connections')).toBeInTheDocument();
    expect(within(connections).getByRole('link', { name: 'Import a statement' })).toHaveAttribute(
      'href',
      '/imports/new',
    );
  });

  it('asks for consent and an account, then sends the user to the provider', async () => {
    serveOverview(makeOverview([aggregatorProvider(), sandboxProvider()]));
    const bodies: unknown[] = [];
    server.use(
      http.post(`${API}/integrations/:ref/connect`, async ({ request, params }) => {
        expect(params.ref).toBe('sandbox_bank');
        bodies.push(await request.json());
        return HttpResponse.json(
          envelope({ connection_id: CONNECTION_ID, authorize_url: AUTHORIZE_URL }),
          { status: 201 },
        );
      }),
    );
    const assign = vi.spyOn(browserNavigation, 'assign').mockImplementation(() => undefined);
    const user = userEvent.setup();
    renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');

    await user.click(await main().findByRole('button', { name: 'Connect: Sandbox Bank' }));
    const dialog = await screen.findByRole('dialog', { name: 'Connect Sandbox Bank' });
    expect(within(dialog).getByText('Keep your Montra account up to date')).toBeInTheDocument();
    expect(within(dialog).getByText('transactions')).toBeInTheDocument();
    expect(within(dialog).getByText('90 days, unless you disconnect sooner')).toBeInTheDocument();
    expect(within(dialog).getByText(/You sign in on Sandbox Bank’s own site/)).toBeInTheDocument();
    expect(
      within(dialog).getByText('Montra can only read. It can’t move money or make payments.'),
    ).toBeInTheDocument();
    // Never a field for bank passwords, PINs, OTPs or CVVs.
    expect(dialog.querySelector('input[type="password"]')).toBeNull();
    expect(within(dialog).queryByRole('textbox')).not.toBeInTheDocument();

    await user.click(within(dialog).getByRole('button', { name: 'Continue to Sandbox Bank' }));
    expect(await within(dialog).findByText('Choose the account to fill.')).toBeInTheDocument();
    expect(within(dialog).getByText('Agree to the consent to continue.')).toBeInTheDocument();
    expect(bodies).toEqual([]);

    await user.selectOptions(
      within(dialog).getByLabelText(/^Montra account to fill/),
      ACCOUNT_CASH,
    );
    await user.click(
      within(dialog).getByRole('checkbox', { name: /I agree that Montra may read/ }),
    );
    await user.click(within(dialog).getByRole('button', { name: 'Continue to Sandbox Bank' }));
    await waitFor(() => {
      expect(assign).toHaveBeenCalledWith(AUTHORIZE_URL);
    });
    expect(bodies).toEqual([{ account_id: ACCOUNT_CASH, consent_confirm: true }]);
    expect(within(dialog).getByText('Opening Sandbox Bank…')).toBeInTheDocument();
  });

  it('refuses to open an approval page that is not HTTPS, and explains connect errors', async () => {
    serveOverview(makeOverview([sandboxProvider()]));
    let answer: 'bad-url' | 'not-configured' = 'bad-url';
    server.use(
      http.post(`${API}/integrations/:ref/connect`, () =>
        answer === 'bad-url'
          ? HttpResponse.json(
              envelope({ connection_id: CONNECTION_ID, authorize_url: 'javascript:alert(1)' }),
              { status: 201 },
            )
          : HttpResponse.json(errorBody({ code: 'FEATURE_NOT_CONFIGURED' }), { status: 503 }),
      ),
    );
    const assign = vi.spyOn(browserNavigation, 'assign').mockImplementation(() => undefined);
    const user = userEvent.setup();
    renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');
    await user.click(await main().findByRole('button', { name: 'Connect: Sandbox Bank' }));
    const dialog = await screen.findByRole('dialog', { name: 'Connect Sandbox Bank' });
    await user.selectOptions(
      within(dialog).getByLabelText(/^Montra account to fill/),
      ACCOUNT_CASH,
    );
    await user.click(
      within(dialog).getByRole('checkbox', { name: /I agree that Montra may read/ }),
    );
    await user.click(within(dialog).getByRole('button', { name: 'Continue to Sandbox Bank' }));
    expect(
      await within(dialog).findByText(/approval page address looks wrong/),
    ).toBeInTheDocument();
    expect(assign).not.toHaveBeenCalled();

    answer = 'not-configured';
    await user.click(within(dialog).getByRole('button', { name: 'Continue to Sandbox Bank' }));
    expect(
      await within(dialog).findByText(/This service isn’t available. Add transactions by hand/),
    ).toBeInTheDocument();
    expect(assign).not.toHaveBeenCalled();
  });

  it('shows an error with retry, and permission denied on 403', async () => {
    let fail = true;
    server.use(
      http.get(`${API}/integrations`, () =>
        fail
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(envelope(makeOverview())),
      ),
    );
    const user = userEvent.setup();
    const { unmount } = renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');
    expect(await main().findByText('We couldn’t load integrations')).toBeInTheDocument();
    fail = false;
    await user.click(main().getByRole('button', { name: 'Try again' }));
    expect(await main().findByText('Account Aggregator (India)')).toBeInTheDocument();
    unmount();

    server.use(
      http.get(`${API}/integrations`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');
    expect(await main().findByText('You don’t have access to this')).toBeInTheDocument();
  });
});

describe('IntegrationsPage: connections', () => {
  it('shows status with sync runs and syncs now', async () => {
    serveOverview(
      makeOverview([sandboxProvider()], [makeConnection({ linked_account_id: ACCOUNT_CASH })]),
    );
    let runs = [makeSyncRun()];
    let statusCalls = 0;
    let syncCalls = 0;
    server.use(
      http.get(`${API}/integrations/:ref/status`, ({ params }) => {
        expect(params.ref).toBe(CONNECTION_ID);
        statusCalls += 1;
        return HttpResponse.json(envelope(makeConnectionStatus(makeConnection(), runs)));
      }),
      http.post(`${API}/integrations/:ref/sync`, ({ params }) => {
        expect(params.ref).toBe(CONNECTION_ID);
        syncCalls += 1;
        const queued = makeSyncRun({
          id: 'e5f6a7b8-5555-4e6f-9a71-000000000042',
          status: 'succeeded',
          trigger: 'manual',
          items_fetched: 3,
          items_created: 1,
          items_updated: 0,
          items_skipped: 2,
        });
        runs = [queued, ...runs];
        return HttpResponse.json(envelope({ ...queued, status: 'queued' }), { status: 202 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');

    const connections = await main().findByRole('region', { name: 'Your connections' });
    expect(await within(connections).findByText('Sandbox Bank')).toBeInTheDocument();
    expect(within(connections).getByText('Connected')).toBeInTheDocument();
    expect(await within(connections).findByText('Wallet')).toBeInTheDocument();

    const history = within(connections).getByRole('button', { name: 'Show sync history' });
    expect(history).toHaveAttribute('aria-expanded', 'false');
    await user.click(history);
    expect(history).toHaveAttribute('aria-expanded', 'true');
    const list = await within(connections).findByRole('list', { name: 'Recent syncs' });
    expect(within(list).getByText('First import')).toBeInTheDocument();
    expect(within(list).getByText('Finished')).toBeInTheDocument();
    expect(within(list).getByText('Read 5 · added 3 · updated 0 · skipped 2')).toBeInTheDocument();

    await user.click(within(connections).getByRole('button', { name: 'Sync now: Sandbox Bank' }));
    expect(await screen.findByText('Sync started')).toBeInTheDocument();
    expect(await within(connections).findByText('Started by you')).toBeInTheDocument();
    expect(
      within(connections).getByText('Read 3 · added 1 · updated 0 · skipped 2'),
    ).toBeInTheDocument();
    expect(syncCalls).toBe(1);
    expect(statusCalls).toBeGreaterThanOrEqual(2);
  });

  it('explains why a sync did not start', async () => {
    serveOverview(makeOverview([sandboxProvider()], [makeConnection()]));
    server.use(
      http.post(`${API}/integrations/:ref/sync`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            message: 'A sync is already running.',
            details: [{ message: 'A sync is already running.', code: 'sync_running' }],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');
    await user.click(await main().findByRole('button', { name: 'Sync now: Sandbox Bank' }));
    expect(await screen.findByText('Sync didn’t start')).toBeInTheDocument();
    expect(
      screen.getByText('A sync is already running. Wait for it to finish.'),
    ).toBeInTheDocument();
  });

  it('does not offer syncing after consent expired, and offers to reconnect', async () => {
    serveOverview(
      makeOverview(
        [sandboxProvider()],
        [makeConnection({ status: 'consent_expired', last_error_code: 'consent_expired' })],
      ),
    );
    renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');
    const connections = await main().findByRole('region', { name: 'Your connections' });
    expect(await within(connections).findByText('Consent expired')).toBeInTheDocument();
    expect(
      within(connections).getByText(/Your consent ended, so syncing stopped/),
    ).toBeInTheDocument();
    expect(within(connections).getByRole('button', { name: 'Reconnect' })).toBeInTheDocument();
    expect(
      within(connections).queryByRole('button', { name: /^Sync now/ }),
    ).not.toBeInTheDocument();
  });

  it('confirms a disconnection, explains imported data and can delete it', async () => {
    const overview = serveOverview(makeOverview([sandboxProvider()], [makeConnection()]));
    const queries: URLSearchParams[] = [];
    server.use(
      http.delete(`${API}/integrations/:ref`, ({ request, params }) => {
        expect(params.ref).toBe(CONNECTION_ID);
        queries.push(new URL(request.url).searchParams);
        overview.overview = makeOverview(
          [sandboxProvider()],
          [makeConnection({ status: 'revoked', last_sync_at: undefined })],
        );
        return HttpResponse.json(envelope({ status: 'revoked', deleted_records: 2 }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/integrations', { user: signedIn() });
    await findPageHeading('Integrations');

    await user.click(await main().findByRole('button', { name: 'Disconnect: Sandbox Bank' }));
    let dialog = await screen.findByRole('dialog', { name: 'Disconnect Sandbox Bank?' });
    expect(
      within(dialog).getByText(/Montra stops syncing, deletes its stored access/),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    expect(queries).toEqual([]);

    await user.click(main().getByRole('button', { name: 'Disconnect: Sandbox Bank' }));
    dialog = await screen.findByRole('dialog', { name: 'Disconnect Sandbox Bank?' });
    const deleteData = within(dialog).getByRole('checkbox', {
      name: 'Also delete the transactions this connection imported',
    });
    expect(deleteData).not.toBeChecked();
    expect(deleteData).toHaveAccessibleDescription(/Transactions you added yourself stay/);
    await user.click(deleteData);
    await user.click(within(dialog).getByRole('button', { name: 'Disconnect' }));

    expect(await screen.findByText('Disconnected from Sandbox Bank')).toBeInTheDocument();
    expect(screen.getByText('2 imported transactions were deleted.')).toBeInTheDocument();
    expect(queries[0]?.get('confirm')).toBe('true');
    expect(queries[0]?.get('delete_data')).toBe('true');
    expect(await main().findByText('Disconnected')).toBeInTheDocument();
    expect(
      main().getByRole('button', { name: 'Delete imported transactions' }),
    ).toBeInTheDocument();
  });
});
