import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACCOUNT_CARD,
  ACCOUNT_CASH,
  ACCOUNT_USD,
  CATEGORY_GROCERIES,
  TAG_HOME,
  TX_GROCERIES,
  makeAccount,
  makeCard,
  makeCategory,
  makeIncome,
  makePaymentMethod,
  makeTag,
  makeTransaction,
  makeTransfer,
  money,
  starterCategories,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

/** Handlers the transaction detail page needs after a redirect. */
function detailHandlers(transaction = makeTransaction()) {
  return [
    http.get(`${API}/transactions/:id`, () => HttpResponse.json(envelope(transaction))),
    http.get(`${API}/transactions/:id/audit`, () => HttpResponse.json(envelope([]))),
    http.get(`${API}/transactions/:id/attachments`, () => HttpResponse.json(envelope([]))),
  ];
}

describe('TransactionCreatePage', () => {
  it('validates the amount exactly against the account currency before calling the API', async () => {
    testBackend.accounts = [makeAccount()];
    const user = userEvent.setup();
    renderRoute('/transactions/new', { user: signedIn() });
    await findPageHeading('Add a transaction');
    await user.type(await screen.findByLabelText('Amount'), '12.345');
    await user.click(screen.getByRole('button', { name: 'Save transaction' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Amount')).toHaveAccessibleDescription(
        /INR amounts can have at most 2 decimal places\./,
      );
    });
  });

  it('creates an expense with an Idempotency-Key, new tags and the default account, then shows duplicate hints', async () => {
    testBackend.accounts = [makeAccount()];
    testBackend.categories = starterCategories();
    testBackend.tags = [makeTag()];
    testBackend.paymentMethods = [makePaymentMethod({ is_default: true })];
    testBackend.preferences = { ...testBackend.preferences, default_account_id: ACCOUNT_CASH };
    const keys: (string | null)[] = [];
    let body: unknown = null;
    server.use(
      http.post(`${API}/transactions`, async ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        body = await request.json();
        return HttpResponse.json(
          envelope({
            transaction: makeTransaction(),
            possible_duplicates: [
              {
                transaction_id: '77777777-7777-4777-8777-777777777799',
                local_date: '2026-11-02',
                // Localized from the codes (the English `reasons` are only a fallback).
                reason_codes: ['same_account_amount', 'within_days'],
                days_apart: 2,
                reasons: ['same account and amount', 'within 3 day(s)'],
              },
            ],
          }),
          { status: 201 },
        );
      }),
      ...detailHandlers(),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/transactions/new', { user: signedIn() });
    await findPageHeading('Add a transaction');
    expect(await screen.findByLabelText('Account')).toHaveValue(ACCOUNT_CASH);
    await user.type(screen.getByLabelText('Amount'), '1,250.5');
    await user.clear(screen.getByLabelText('Date'));
    await user.type(screen.getByLabelText('Date'), '2026-11-04');
    await user.selectOptions(screen.getByLabelText(/^Category/), CATEGORY_GROCERIES);
    await user.type(screen.getByLabelText(/^Merchant or payee/), 'Big Bazaar');
    await user.click(screen.getByLabelText('home'));
    await user.type(screen.getByLabelText('New tag'), 'weekly{Enter}');
    await user.click(screen.getByRole('button', { name: 'Save transaction' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/transactions/${TX_GROCERIES}`);
    });
    expect(body).toEqual({
      type: 'expense',
      account_id: ACCOUNT_CASH,
      amount: '1250.50',
      local_date: '2026-11-04',
      category_id: CATEGORY_GROCERIES,
      merchant_name: 'Big Bazaar',
      payment_method_id: makePaymentMethod().id,
      tag_ids: [TAG_HOME],
      tag_names: ['weekly'],
    });
    expect(keys[0]).toMatch(/^web-/);
    expect(await screen.findByText('This might already be recorded')).toBeInTheDocument();
    expect(screen.getByText(/same account and amount, within 2 days/)).toBeInTheDocument();
  });

  it('keeps the same Idempotency-Key when retrying after a lost response', async () => {
    testBackend.accounts = [makeAccount()];
    const keys: (string | null)[] = [];
    server.use(
      http.post(`${API}/transactions`, ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        if (keys.length === 1) return HttpResponse.error();
        return HttpResponse.json(envelope({ transaction: makeIncome(), possible_duplicates: [] }), {
          status: 201,
        });
      }),
      ...detailHandlers(makeIncome()),
    );
    const user = userEvent.setup();
    renderRoute('/transactions/new?type=income', { user: signedIn() });
    await findPageHeading('Add a transaction');
    expect(await screen.findByLabelText('Income')).toBeChecked();
    await user.type(screen.getByLabelText('Amount'), '5000');
    await user.click(screen.getByRole('button', { name: 'Save transaction' }));
    expect(await screen.findByText(/couldn’t reach Montra/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Save transaction' }));
    expect(await findPageHeading('November salary')).toBeInTheDocument();
    expect(keys).toHaveLength(2);
    expect(keys[1]).toBe(keys[0]);
  });

  it('explains that an account is needed first', async () => {
    renderRoute('/transactions/new', { user: signedIn() });
    await findPageHeading('Add a transaction');
    expect(await screen.findByText('Add an account first')).toBeInTheDocument();
  });
});

describe('TransactionEditPage', () => {
  it('sends only the changes with the version and reloads on a version conflict', async () => {
    testBackend.accounts = [makeAccount()];
    testBackend.categories = [makeCategory()];
    testBackend.tags = [makeTag()];
    let version = 3;
    const bodies: unknown[] = [];
    server.use(
      http.get(`${API}/transactions/:id`, () =>
        HttpResponse.json(envelope(makeTransaction({ version }))),
      ),
      http.patch(`${API}/transactions/:id`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          version = 4;
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(
          envelope(makeTransaction({ version: 5, amount: money('300.00') })),
        );
      }),
      http.get(`${API}/transactions/:id/audit`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/transactions/:id/attachments`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    renderRoute(`/transactions/${TX_GROCERIES}/edit`, { user: signedIn() });
    await findPageHeading('Edit transaction');
    const amount = await screen.findByLabelText('Amount');
    expect(amount).toHaveValue('250.75');
    await user.clear(amount);
    await user.type(amount, '300');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    expect(bodies[0]).toEqual({ version: 3, amount: '300.00' });

    const reloaded = await screen.findByLabelText('Amount');
    await user.clear(reloaded);
    await user.type(reloaded, '300');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Transaction updated')).toBeInTheDocument();
    expect(bodies[1]).toEqual({ version: 4, amount: '300.00' });
  });

  it('only allows descriptive edits on a transfer leg, and saves them', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    const leg = makeTransaction({
      type: 'transfer',
      transfer_id: makeTransfer().id,
      category: undefined,
      merchant: undefined,
      tags: [],
      description: 'Card payment',
    });
    let body: unknown = null;
    server.use(
      http.get(`${API}/transactions/:id`, () => HttpResponse.json(envelope(leg))),
      http.patch(`${API}/transactions/:id`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope({ ...leg, description: 'November card bill', version: 4 }),
        );
      }),
      http.get(`${API}/transactions/:id/audit`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/transactions/:id/attachments`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/transactions/transfers/:id`, () =>
        HttpResponse.json(envelope(makeTransfer())),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/transactions/${TX_GROCERIES}/edit`, { user: signedIn() });
    await findPageHeading('Edit transaction');
    expect(
      await screen.findByText(/Only the merchant, description, notes and tags/),
    ).toBeInTheDocument();
    expect(screen.getByLabelText('Amount')).toBeDisabled();
    expect(screen.getByLabelText('Account')).toBeDisabled();
    const description = screen.getByLabelText(/^Description/);
    await user.clear(description);
    await user.type(description, 'November card bill');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Transaction updated')).toBeInTheDocument();
    expect(body).toEqual({ version: 3, description: 'November card bill' });
  });
});

describe('TransferCreatePage', () => {
  it('requires two different accounts', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    const user = userEvent.setup();
    renderRoute(`/transfers/new?from_account_id=${ACCOUNT_CASH}`, { user: signedIn() });
    await findPageHeading('Transfer between your accounts');
    await user.selectOptions(await screen.findByLabelText('To account'), ACCOUNT_CASH);
    await user.type(screen.getByLabelText('Amount sent'), '100');
    await user.click(screen.getByRole('button', { name: 'Save transfer' }));
    await waitFor(() => {
      expect(screen.getByLabelText('To account')).toHaveAccessibleDescription(
        /Choose two different accounts\./,
      );
    });
  });

  it('records a cross-currency transfer with the amount received and a fee', async () => {
    testBackend.accounts = [
      makeAccount(),
      makeAccount({
        id: ACCOUNT_USD,
        name: 'USD Savings',
        account_type: 'savings',
        currency: 'USD',
        balance: money('100.00', 'USD'),
      }),
    ];
    let body: unknown = null;
    let key: string | null = null;
    const transfer = makeTransfer({
      to_account_id: ACCOUNT_USD,
      to_amount: money('12.00', 'USD'),
      fx_rate: '0.012',
    });
    server.use(
      http.post(`${API}/transactions/transfers`, async ({ request }) => {
        body = await request.json();
        key = request.headers.get('Idempotency-Key');
        return HttpResponse.json(envelope(transfer), { status: 201 });
      }),
      ...detailHandlers(
        makeTransaction({
          id: transfer.from_transaction_id,
          type: 'transfer',
          transfer_id: transfer.id,
          merchant: undefined,
          category: undefined,
          description: 'To savings',
        }),
      ),
      http.get(`${API}/transactions/transfers/:id`, () => HttpResponse.json(envelope(transfer))),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/transfers/new', { user: signedIn() });
    await findPageHeading('Transfer between your accounts');
    await user.selectOptions(await screen.findByLabelText('From account'), ACCOUNT_CASH);
    await user.selectOptions(screen.getByLabelText('To account'), ACCOUNT_USD);
    await user.type(screen.getByLabelText('Amount sent'), '1000');
    expect(screen.getByText(/different currencies \(INR and USD\)/)).toBeInTheDocument();
    await user.type(screen.getByLabelText('Amount received'), '12');
    await user.type(screen.getByLabelText(/^Fee/), '10');
    await user.type(screen.getByLabelText(/^Description/), 'To savings');
    await user.click(screen.getByRole('button', { name: 'Save transfer' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/transactions/${transfer.from_transaction_id}`);
    });
    expect(body).toMatchObject({
      from_account_id: ACCOUNT_CASH,
      to_account_id: ACCOUNT_USD,
      amount: '1000.00',
      to_amount: '12.00',
      fee: '10.00',
      description: 'To savings',
    });
    expect(key).toMatch(/^web-/);
    const section = await screen.findByRole('region', { name: 'Transfer' });
    expect(await within(section).findByText('1 INR = 0.012 USD')).toBeInTheDocument();
  });

  it('accepts an exchange rate instead of the received amount', async () => {
    testBackend.accounts = [
      makeAccount(),
      makeAccount({
        id: ACCOUNT_USD,
        name: 'USD Savings',
        currency: 'USD',
        balance: money('100.00', 'USD'),
      }),
    ];
    let body: unknown = null;
    server.use(
      http.post(`${API}/transactions/transfers`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(errorBody({ code: 'DOMAIN_RULE_VIOLATION' }), { status: 422 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/transfers/new', { user: signedIn() });
    await findPageHeading('Transfer between your accounts');
    await user.selectOptions(await screen.findByLabelText('From account'), ACCOUNT_CASH);
    await user.selectOptions(screen.getByLabelText('To account'), ACCOUNT_USD);
    await user.type(screen.getByLabelText('Amount sent'), '1000');
    await user.click(screen.getByLabelText('The exchange rate'));
    await user.type(screen.getByLabelText('Exchange rate'), '0.0120');
    await user.click(screen.getByRole('button', { name: 'Save transfer' }));
    expect(await screen.findByText(/Both accounts must be yours and active/)).toBeInTheDocument();
    expect(body).toMatchObject({ fx_rate: '0.0120', amount: '1000.00' });
    expect(body).not.toHaveProperty('to_amount');
  });

  it('explains that two accounts are needed', async () => {
    testBackend.accounts = [makeAccount({ id: ACCOUNT_CARD })];
    renderRoute('/transfers/new', { user: signedIn() });
    await findPageHeading('Transfer between your accounts');
    expect(await screen.findByText('You need two accounts')).toBeInTheDocument();
  });
});
