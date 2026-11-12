import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACCOUNT_CARD,
  ACCOUNT_CASH,
  makeAccount,
  makeCard,
  makeTransaction,
  money,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

describe('AccountsPage', () => {
  it('groups accounts by type with server balances and shows credit cards as amounts owed', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    renderRoute('/accounts', { user: signedIn() });
    await findPageHeading('Accounts');

    const cash = await screen.findByRole('region', { name: 'Cash' });
    expect(within(cash).getByRole('link', { name: 'Wallet' })).toHaveAttribute(
      'href',
      `/accounts/${ACCOUNT_CASH}`,
    );
    expect(within(cash).getByText('₹1,500.50')).toBeInTheDocument();

    const cards = screen.getByRole('region', { name: 'Credit cards' });
    // The API's -2000.00 is shown as ₹2,000.00 "Owed", never as a bare negative number.
    expect(within(cards).getByText('₹2,000.00')).toBeInTheDocument();
    expect(within(cards).getByText('Owed')).toBeInTheDocument();
    expect(within(cards).getByText('•••• 4821 · INR')).toBeInTheDocument();

    const totals = screen.getByRole('region', { name: 'Totals' });
    expect(within(totals).getByText('₹4,239.75')).toBeInTheDocument();
  });

  it('asks the API for archived and closed accounts only when requested', async () => {
    const seen: string[] = [];
    server.use(
      http.get(`${API}/accounts`, ({ request }) => {
        seen.push(new URL(request.url).search);
        return HttpResponse.json(
          envelope([makeAccount({ status: 'archived', name: 'Old wallet', id: ACCOUNT_CARD })]),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/accounts', { user: signedIn() });
    await findPageHeading('Accounts');
    await user.click(await screen.findByLabelText('Show archived and closed'));
    expect(await screen.findByText('Archived')).toBeInTheDocument();
    expect(seen).toContain('?include_archived=true');
  });

  it('shows a first-use empty state', async () => {
    renderRoute('/accounts', { user: signedIn() });
    await findPageHeading('Accounts');
    expect(await screen.findByText('No accounts yet')).toBeInTheDocument();
  });

  it('shows a recoverable error', async () => {
    server.use(
      http.get(`${API}/accounts`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-acc' }), {
          status: 500,
        }),
      ),
    );
    renderRoute('/accounts', { user: signedIn() });
    await findPageHeading('Accounts');
    expect(await screen.findByText('We couldn’t load your accounts')).toBeInTheDocument();
    expect(screen.getByText('req-acc')).toBeInTheDocument();
  });
});

describe('AccountCreatePage', () => {
  it('validates fields before calling the API', async () => {
    const user = userEvent.setup();
    renderRoute('/accounts/new', { user: signedIn() });
    await findPageHeading('Add an account');
    await user.type(await screen.findByLabelText(/^Current balance/), '10.555');
    await user.click(screen.getByRole('button', { name: 'Add account' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Account name')).toHaveAccessibleDescription(
        /Enter a name for the account\./,
      );
    });
    expect(screen.getByLabelText('Account type')).toHaveAccessibleDescription(
      /Choose an account type\./,
    );
  });

  it('creates a credit card with an Idempotency-Key and sends the amount owed as a negative balance', async () => {
    let body: unknown = null;
    let key: string | null = null;
    server.use(
      http.post(`${API}/accounts`, async ({ request }) => {
        body = await request.json();
        key = request.headers.get('Idempotency-Key');
        return HttpResponse.json(envelope(makeCard()), { status: 201 });
      }),
      http.get(`${API}/accounts/:id`, () => HttpResponse.json(envelope(makeCard()))),
      http.get(`${API}/accounts/:id/balance`, () =>
        HttpResponse.json(
          envelope({
            account_id: ACCOUNT_CARD,
            as_of: '2026-11-04',
            balance: money('-2000.00'),
            balance_source: 'calculated',
            verified: false,
            history: [],
          }),
        ),
      ),
      http.get(`${API}/accounts/:id/transactions`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/accounts/new', { user: signedIn() });
    await findPageHeading('Add an account');
    await user.type(await screen.findByLabelText('Account name'), 'HDFC Credit');
    await user.selectOptions(screen.getByLabelText('Account type'), 'credit_card');
    await user.type(screen.getByLabelText(/^Amount you owe today/), '2,000');
    await user.type(screen.getByLabelText(/^Credit limit/), '50000');
    await user.type(screen.getByLabelText(/^Last digits/), '4821');
    await user.click(screen.getByRole('button', { name: 'Add account' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/accounts/${ACCOUNT_CARD}`);
    });
    expect(key).toMatch(/^web-[0-9a-f-]{36}$/);
    expect(body).toMatchObject({
      name: 'HDFC Credit',
      account_type: 'credit_card',
      currency: 'INR',
      opening_balance: '-2000.00',
      credit_limit: '50000.00',
      masked_number: '4821',
      include_in_overview: true,
    });
    expect(await screen.findByText('Account added')).toBeInTheDocument();
  });

  it('maps API field errors to the form', async () => {
    server.use(
      http.post(`${API}/accounts`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.name', message: 'Name is required.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/accounts/new', { user: signedIn() });
    await findPageHeading('Add an account');
    await user.type(await screen.findByLabelText('Account name'), '  x');
    await user.selectOptions(screen.getByLabelText('Account type'), 'cash');
    await user.click(screen.getByRole('button', { name: 'Add account' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Account name')).toHaveAccessibleDescription(
        /Name is required\./,
      );
    });
  });
});

function detailHandlers(account = makeCard()) {
  return [
    http.get(`${API}/accounts/:id`, () => HttpResponse.json(envelope(account))),
    http.get(`${API}/accounts/:id/balance`, () =>
      HttpResponse.json(
        envelope({
          account_id: account.id,
          as_of: '2026-11-04',
          balance: account.balance,
          balance_source: 'calculated',
          verified: false,
          history: [
            { date: '2026-11-03', balance: money('-3000.00') },
            { date: '2026-11-04', balance: money('-2000.00') },
          ],
        }),
      ),
    ),
    http.get(`${API}/accounts/:id/transactions`, () =>
      HttpResponse.json(
        envelope([makeTransaction({ account_id: account.id, account_name: account.name })]),
      ),
    ),
  ];
}

describe('AccountDetailPage', () => {
  it('shows the tracked balance, credit details, history table and recent transactions', async () => {
    server.use(...detailHandlers());
    const user = userEvent.setup();
    renderRoute(`/accounts/${ACCOUNT_CARD}`, { user: signedIn() });
    await findPageHeading('HDFC Credit');

    const balance = screen.getByRole('region', { name: 'Balance' });
    expect(within(balance).getByText('₹2,000.00')).toBeInTheDocument();
    expect(within(balance).getByText('Owed')).toBeInTheDocument();
    expect(
      within(balance).getByText('Tracked from your records, not verified by a bank.'),
    ).toBeInTheDocument();

    const details = screen.getByRole('region', { name: 'Details' });
    expect(within(details).getByText('₹48,000.00')).toBeInTheDocument(); // available credit (server value)

    const history = screen.getByRole('region', { name: 'Balance history' });
    expect(
      await within(history).findByText(/On November 3, 2026 the balance was -₹3,000\.00\./),
    ).toBeInTheDocument();
    await user.click(within(history).getByRole('button', { name: 'Show as table' }));
    const table = within(history).getByRole('table', { name: 'Daily balance' });
    expect(within(table).getAllByRole('row')).toHaveLength(3);

    const recent = screen.getByRole('region', { name: 'Recent transactions' });
    expect(await within(recent).findByRole('link', { name: 'Big Bazaar' })).toBeInTheDocument();
  });

  it('records a balance correction with a reason and an Idempotency-Key', async () => {
    let body: unknown = null;
    let key: string | null = null;
    server.use(
      ...detailHandlers(makeAccount()),
      http.post(`${API}/accounts/:id/adjustments`, async ({ request }) => {
        body = await request.json();
        key = request.headers.get('Idempotency-Key');
        return HttpResponse.json(envelope(makeAccount({ balance: money('1400.00'), version: 2 })), {
          status: 201,
        });
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/accounts/${ACCOUNT_CASH}`, { user: signedIn() });
    await findPageHeading('Wallet');
    await user.click(screen.getByRole('button', { name: 'Correct balance' }));
    const dialog = await screen.findByRole('dialog', { name: 'Correct the balance' });
    await user.type(within(dialog).getByLabelText('Correct balance'), '1400');
    await user.type(within(dialog).getByLabelText('Reason'), 'Counted the cash');
    await user.click(within(dialog).getByRole('button', { name: 'Save correction' }));

    expect(await screen.findByText('Balance corrected')).toBeInTheDocument();
    expect(body).toMatchObject({ target_balance: '1400.00', reason: 'Counted the cash' });
    expect(key).toMatch(/^web-/);
  });

  it('refuses a correction to the balance it already has without calling the API', async () => {
    server.use(...detailHandlers(makeAccount()));
    const user = userEvent.setup();
    renderRoute(`/accounts/${ACCOUNT_CASH}`, { user: signedIn() });
    await findPageHeading('Wallet');
    await user.click(screen.getByRole('button', { name: 'Correct balance' }));
    const dialog = await screen.findByRole('dialog', { name: 'Correct the balance' });
    await user.type(within(dialog).getByLabelText('Correct balance'), '1500.5');
    await user.type(within(dialog).getByLabelText('Reason'), 'Checked it');
    await user.click(within(dialog).getByRole('button', { name: 'Save correction' }));
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Correct balance')).toHaveAccessibleDescription(
        /already the balance/,
      );
    });
  });

  it('archives after confirmation, sending the version it showed', async () => {
    let archived: URL | null = null;
    server.use(
      ...detailHandlers(makeAccount({ version: 4 })),
      http.post(`${API}/accounts/:id/archive`, ({ request }) => {
        archived = new URL(request.url);
        return HttpResponse.json(envelope(makeAccount({ status: 'archived', version: 5 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/accounts/${ACCOUNT_CASH}`, { user: signedIn() });
    await findPageHeading('Wallet');
    await user.click(screen.getByRole('button', { name: 'Archive' }));
    const dialog = await screen.findByRole('dialog', { name: 'Archive this account?' });
    expect(within(dialog).getByRole('button', { name: 'Cancel' })).toHaveFocus();
    await user.click(within(dialog).getByRole('button', { name: 'Archive account' }));
    expect(await screen.findByText('Account archived')).toBeInTheDocument();
    expect(archived!.searchParams.get('version')).toBe('4');
  });

  it('links to importing a statement (account preselected) and to reconciling the account', async () => {
    server.use(...detailHandlers(makeAccount()));
    renderRoute(`/accounts/${ACCOUNT_CASH}`, { user: signedIn() });
    await findPageHeading('Wallet');
    const manage = screen.getByRole('region', { name: 'Manage' });
    expect(within(manage).getByRole('link', { name: 'Import statement' })).toHaveAttribute(
      'href',
      `/imports/new?account_id=${ACCOUNT_CASH}`,
    );
    expect(within(manage).getByRole('link', { name: 'Reconcile' })).toHaveAttribute(
      'href',
      `/accounts/${ACCOUNT_CASH}/reconcile`,
    );
  });

  it('offers no import or reconcile actions on an account shared with you', async () => {
    server.use(...detailHandlers(makeAccount({ owned: false })));
    renderRoute(`/accounts/${ACCOUNT_CASH}`, { user: signedIn() });
    await findPageHeading('Wallet');
    expect(screen.queryByRole('link', { name: 'Import statement' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Reconcile' })).not.toBeInTheDocument();
  });

  it('only allows closing at a zero balance', async () => {
    server.use(...detailHandlers(makeAccount()));
    renderRoute(`/accounts/${ACCOUNT_CASH}`, { user: signedIn() });
    await findPageHeading('Wallet');
    expect(screen.getByRole('button', { name: 'Close account' })).toBeDisabled();
    expect(screen.getByText(/first bring its balance to zero/)).toBeInTheDocument();
  });

  it('shows a not-found state', async () => {
    server.use(
      http.get(`${API}/accounts/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(`/accounts/${ACCOUNT_CASH}`, { user: signedIn() });
    expect(await screen.findByText('Account not found')).toBeInTheDocument();
  });
});

describe('AccountEditPage', () => {
  it('sends only changed fields with the version, and reloads after a version conflict', async () => {
    let version = 1;
    const bodies: unknown[] = [];
    server.use(
      http.get(`${API}/accounts/:id`, () =>
        HttpResponse.json(
          envelope(makeAccount({ version, name: version === 1 ? 'Wallet' : 'Cash pouch' })),
        ),
      ),
      http.patch(`${API}/accounts/:id`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          version = 2;
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeAccount({ version: 3, name: 'Daily cash' })));
      }),
      ...detailHandlers(makeAccount({ name: 'Daily cash' })).slice(1),
    );
    const user = userEvent.setup();
    renderRoute(`/accounts/${ACCOUNT_CASH}/edit`, { user: signedIn() });
    await findPageHeading('Edit account');
    const name = await screen.findByLabelText('Account name');
    await user.clear(name);
    await user.type(name, 'Daily cash');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    expect(bodies[0]).toEqual({ version: 1, name: 'Daily cash' });
    // The form now shows the latest version from the server.
    await waitFor(() => {
      expect(screen.getByLabelText('Account name')).toHaveValue('Cash pouch');
    });
    const reloaded = screen.getByLabelText('Account name');
    await user.clear(reloaded);
    await user.type(reloaded, 'Daily cash');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Account updated')).toBeInTheDocument();
    expect(bodies[1]).toEqual({ version: 2, name: 'Daily cash' });
  });

  it('clears a credit card’s statement and due days by sending 0', async () => {
    const card = makeCard({ statement_day: 12, payment_due_day: 2, version: 3 });
    const bodies: unknown[] = [];
    server.use(
      http.get(`${API}/accounts/:id`, () => HttpResponse.json(envelope(card))),
      http.patch(`${API}/accounts/:id`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeCard({ version: 4 })));
      }),
      ...detailHandlers(makeCard()).slice(1),
    );
    const user = userEvent.setup();
    renderRoute(`/accounts/${ACCOUNT_CARD}/edit`, { user: signedIn() });
    await findPageHeading('Edit account');
    await user.selectOptions(await screen.findByLabelText(/^Statement day/), '');
    await user.selectOptions(screen.getByLabelText(/^Payment due day/), '');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Account updated')).toBeInTheDocument();
    expect(bodies[0]).toEqual({ version: 3, statement_day: 0, payment_due_day: 0 });
  });

  it('shows a loading state', async () => {
    server.use(
      http.get(`${API}/accounts/:id`, async () => {
        await delay('infinite');
        return HttpResponse.json(envelope(makeAccount()));
      }),
    );
    renderRoute(`/accounts/${ACCOUNT_CASH}/edit`, { user: signedIn() });
    expect(await screen.findByText('Loading the account…')).toBeInTheDocument();
  });
});
