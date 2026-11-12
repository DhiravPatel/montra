import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type {
  ChecklistItemPatch,
  SubscriptionActionInput,
  SubscriptionDetail,
  SubscriptionPaymentInput,
} from '@/shared/finance/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { makeAccount, makeTransaction, money, starterCategories } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import {
  MERCHANT_NETFLIX,
  SUB_GYM,
  SUB_NETFLIX,
  SUB_NETFLIX_FAMILY,
  TX_NETFLIX_CHARGE,
  TX_NETFLIX_OLD,
  makeDuplicateWarning,
  makePaymentCandidate,
  makeSubscription,
  makeSubscriptionEvent,
} from '@/tests/subscriptionsFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const path = `/subscriptions/${SUB_NETFLIX}`;

function groceries() {
  return makeTransaction({ id: TX_NETFLIX_OLD, description: 'Groceries' });
}

/** Reads the subscription from `state`; lets a test swap it after a write. */
function subscriptionHandler(state: { current: SubscriptionDetail }, reads = { count: 0 }) {
  return http.get(`${API}/subscriptions/:id`, () => {
    reads.count += 1;
    return HttpResponse.json(envelope(state.current));
  });
}

/** A payment the API lists as linked now (`SubscriptionDetail.payments`). */
function linkedPayment(transactionId: string, date: string) {
  return {
    transaction_id: transactionId,
    local_date: date,
    amount: money('649.00'),
    account_name: 'Wallet',
    linked_at: `${date}T06:00:00Z`,
  };
}

function paymentRecorded(id: string, transactionId: string, createdAt: string) {
  return makeSubscriptionEvent({
    id,
    kind: 'payment_recorded',
    new_amount: money('649.00'),
    transaction_id: transactionId,
    occurred_on: createdAt.slice(0, 10),
    created_at: createdAt,
  });
}

describe('SubscriptionDetailPage', () => {
  it('shows server costs, renewal, payments, price history and coded duplicate reasons', async () => {
    testBackend.accounts = [makeAccount()];
    testBackend.categories = starterCategories();
    const state = {
      current: makeSubscription({
        duplicate_warnings: [
          makeDuplicateWarning(),
          makeDuplicateWarning({
            subscription_id: SUB_GYM,
            name: 'Video plan',
            reason: 'Same price and billing cycle',
            reason_code: 'same_price_and_cycle',
            reason_params: {
              name: 'Video plan',
              amount: '649.00',
              currency: 'INR',
              billing_frequency: 'monthly',
            },
          }),
        ],
        last_payment: {
          occurred_on: '2026-11-02',
          amount: money('649.00'),
          transaction_id: TX_NETFLIX_CHARGE,
        },
        payments: [linkedPayment(TX_NETFLIX_CHARGE, '2026-11-02')],
        events: [
          {
            ...paymentRecorded(
              'e5e5e5e5-5555-4555-8555-000000000003',
              TX_NETFLIX_CHARGE,
              '2026-11-02T06:00:00Z',
            ),
            note: 'Matched by detection',
            note_code: 'matched_by_detection',
          },
          makeSubscriptionEvent({
            id: 'e5e5e5e5-5555-4555-8555-000000000002',
            kind: 'price_changed',
            old_amount: money('599.00'),
            new_amount: money('649.00'),
            occurred_on: '2026-10-20',
            created_at: '2026-10-20T06:00:00Z',
          }),
          makeSubscriptionEvent({ new_amount: money('599.00') }),
        ],
      }),
    };
    server.use(subscriptionHandler(state));
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    expect(screen.getByText('Standard · Netflix · Monthly')).toBeInTheDocument();

    const cost = screen.getByRole('region', { name: 'Cost' });
    expect(within(cost).getByText('₹649.00 a month')).toBeInTheDocument();
    expect(within(cost).getByText('₹7,788.00')).toBeInTheDocument();

    const renewal = screen.getByRole('region', { name: 'Renewal' });
    expect(within(renewal).getByText('November 10, 2026')).toBeInTheDocument();
    expect(within(renewal).getByText('3 days before, 1 day before')).toBeInTheDocument();
    expect(within(renewal).queryByText('Cancelled on')).toBeNull();

    const payments = screen.getByRole('region', { name: 'Payments' });
    expect(within(payments).getByRole('link', { name: 'View transaction' })).toHaveAttribute(
      'href',
      `/transactions/${TX_NETFLIX_CHARGE}`,
    );
    // The API's linked payments: date, account and amount as sent.
    expect(within(payments).getByText('November 2, 2026 · Wallet')).toBeInTheDocument();
    // Montra's own note is localized by note_code, not shown as sent.
    expect(
      within(payments).getByText('Matched automatically from your transactions'),
    ).toBeInTheDocument();

    const prices = screen.getByRole('region', { name: 'Price history' });
    // Started at ₹599.00, then changed from ₹599.00 to ₹649.00.
    expect(within(prices).getAllByText('₹599.00')).toHaveLength(2);
    expect(within(prices).getByText(/Changed from/)).toBeInTheDocument();
    expect(within(prices).getByText(/Started at/)).toBeInTheDocument();

    const history = screen.getByRole('region', { name: 'History' });
    expect(within(history).getByText('Payment linked')).toBeInTheDocument();
    expect(within(history).getByText('Price changed')).toBeInTheDocument();

    const details = screen.getByRole('region', { name: 'Details' });
    expect(await within(details).findByText('Wallet')).toBeInTheDocument();
    expect(within(details).getByText('Added by you')).toBeInTheDocument();

    expect(screen.getByText('This might be a duplicate')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Netflix family' })).toHaveAttribute(
      'href',
      `/subscriptions/${SUB_NETFLIX_FAMILY}`,
    );
    expect(screen.getByText(/Same name/)).toBeInTheDocument();
    // same_price_and_cycle names the price and cycle from reason_params.
    expect(screen.getByText(/Same price \(₹649\.00\) and billing cycle \(Monthly\)/)).toBeVisible();
  });

  it('shows the cancellation date of a cancelled subscription from cancelled_on', async () => {
    server.use(
      subscriptionHandler({
        current: makeSubscription({
          status: 'cancelled',
          next_renewal_date: undefined,
          cancelled_on: '2026-11-01',
        }),
      }),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    const renewal = screen.getByRole('region', { name: 'Renewal' });
    expect(within(renewal).getByText('Cancelled on')).toBeInTheDocument();
    expect(within(renewal).getByText('November 1, 2026')).toBeInTheDocument();
    expect(within(renewal).getByText('No upcoming renewal')).toBeInTheDocument();
    // A cancelled subscription takes no new payments.
    expect(screen.queryByRole('button', { name: 'Link a payment' })).toBeNull();
    expect(
      within(screen.getByRole('region', { name: 'Manage' })).getByRole('button', {
        name: 'Reactivate',
      }),
    ).toBeInTheDocument();
  });

  it('suggests payments from the API with localized reasons and reuses the key on retry', async () => {
    const state = { current: makeSubscription() };
    const keys: (string | null)[] = [];
    const bodies: SubscriptionPaymentInput[] = [];
    server.use(
      subscriptionHandler(state),
      http.get(`${API}/subscriptions/:id/payment-candidates`, () =>
        HttpResponse.json(envelope([makePaymentCandidate()])),
      ),
      http.get(`${API}/transactions`, () =>
        HttpResponse.json(
          envelope([
            makeTransaction({
              id: TX_NETFLIX_CHARGE,
              merchant: { id: MERCHANT_NETFLIX, name: 'Netflix' },
              amount: money('649.00'),
            }),
            groceries(),
          ]),
        ),
      ),
      http.post(`${API}/subscriptions/:id/payments`, async ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        bodies.push((await request.json()) as SubscriptionPaymentInput);
        if (keys.length === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        state.current = makeSubscription({
          version: 3,
          events: [
            paymentRecorded(
              'e5e5e5e5-5555-4555-8555-000000000009',
              TX_NETFLIX_CHARGE,
              '2026-11-12T06:00:00Z',
            ),
          ],
        });
        return HttpResponse.json(envelope(state.current), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    await user.click(screen.getAllByRole('button', { name: 'Link a payment' })[0]!);

    const dialog = await screen.findByRole('dialog', { name: 'Link a payment' });
    expect(await within(dialog).findByText('Suggested matches')).toBeInTheDocument();
    // reason_codes and days_from_renewal in the interface language.
    expect(within(dialog).getByText('Same merchant')).toBeInTheDocument();
    expect(within(dialog).getByText('Same amount as the price')).toBeInTheDocument();
    expect(within(dialog).getByText('Near the renewal date')).toBeInTheDocument();
    expect(
      within(dialog).getByText('2 days after the renewal expected on November 10, 2026'),
    ).toBeInTheDocument();
    // The suggestion is not repeated in the search results.
    expect(await within(dialog).findAllByRole('radio')).toHaveLength(2);

    await user.click(within(dialog).getAllByRole('radio')[0]!);
    await user.click(within(dialog).getByRole('button', { name: 'Link payment' }));
    expect(await within(dialog).findByText(/Something went wrong|server/i)).toBeInTheDocument();

    await user.click(within(dialog).getByRole('button', { name: 'Link payment' }));
    // The toast, then the new event in the history.
    expect((await screen.findAllByText('Payment linked')).length).toBeGreaterThan(0);
    expect(bodies).toEqual([
      { transaction_id: TX_NETFLIX_CHARGE, update_price: false },
      { transaction_id: TX_NETFLIX_CHARGE, update_price: false },
    ]);
    expect(keys[0]).toMatch(/^web-/);
    // Same request retried: same key, so the API can replay instead of recording twice.
    expect(keys[1]).toBe(keys[0]);
    await waitFor(() => {
      expect(screen.queryByRole('dialog', { name: 'Link a payment' })).toBeNull();
    });
  });

  it('explains an empty suggestion list and a payment linked to another subscription', async () => {
    const state = { current: makeSubscription() };
    server.use(
      subscriptionHandler(state),
      http.get(`${API}/subscriptions/:id/payment-candidates`, () =>
        HttpResponse.json(envelope([])),
      ),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([groceries()]))),
      http.get(`${API}/transactions/:id`, () =>
        HttpResponse.json(envelope({ ...groceries(), amount: money('649.00') })),
      ),
      http.post(`${API}/subscriptions/:id/payments`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DUPLICATE',
            details: [
              {
                code: 'payment_linked_elsewhere',
                message: 'This payment is already recorded for another subscription.',
              },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    await user.click(screen.getAllByRole('button', { name: 'Link a payment' })[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Link a payment' });
    expect(
      await within(dialog).findByText(
        'No unlinked expenses look like a payment of this subscription. Search for it below.',
      ),
    ).toBeInTheDocument();
    await user.click(await within(dialog).findByRole('radio'));
    await user.click(within(dialog).getByRole('button', { name: 'Link payment' }));
    expect(
      await within(dialog).findByText(
        'That payment is already linked to another subscription. Choose a different one.',
      ),
    ).toBeInTheDocument();
  });

  it('asks whether the price changed when the charge differs', async () => {
    const state = { current: makeSubscription() };
    const bodies: SubscriptionPaymentInput[] = [];
    server.use(
      subscriptionHandler(state),
      http.get(`${API}/subscriptions/:id/payment-candidates`, () =>
        HttpResponse.json(
          envelope([
            makePaymentCandidate({
              amount: money('699.00'),
              reason_codes: ['same_merchant', 'amount_close', 'on_renewal_date'],
              days_from_renewal: 0,
            }),
          ]),
        ),
      ),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([]))),
      http.post(`${API}/subscriptions/:id/payments`, async ({ request }) => {
        bodies.push((await request.json()) as SubscriptionPaymentInput);
        state.current = makeSubscription({ amount: money('699.00'), version: 4 });
        return HttpResponse.json(envelope(state.current), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    await user.click(screen.getAllByRole('button', { name: 'Link a payment' })[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Link a payment' });
    expect(await within(dialog).findByText('Close to the price')).toBeInTheDocument();
    expect(
      within(dialog).getByText('On the renewal expected on November 10, 2026'),
    ).toBeInTheDocument();
    await user.click((await within(dialog).findAllByRole('radio'))[0]!);
    await user.click(within(dialog).getByRole('button', { name: 'Link payment' }));

    const choice = await screen.findByRole('dialog', {
      name: 'This charge differs from the price',
    });
    expect(
      within(choice).getByText(/This payment was ₹699.00, but the price you track is ₹649.00/),
    ).toBeInTheDocument();
    await user.click(within(choice).getByRole('button', { name: 'Yes, the price is now ₹699.00' }));
    expect(await screen.findByText('Payment linked and price updated')).toBeInTheDocument();
    expect(bodies).toEqual([{ transaction_id: TX_NETFLIX_CHARGE, update_price: true }]);
  });

  it('unlinks a wrong payment after confirmation; the history keeps both entries', async () => {
    const linkedAt = '2026-11-02T06:00:00Z';
    const state = {
      current: makeSubscription({
        payments: [linkedPayment(TX_NETFLIX_CHARGE, '2026-11-02')],
        events: [
          paymentRecorded('e5e5e5e5-5555-4555-8555-000000000011', TX_NETFLIX_CHARGE, linkedAt),
          // That payment also updated the tracked price.
          makeSubscriptionEvent({
            id: 'e5e5e5e5-5555-4555-8555-000000000015',
            kind: 'price_changed',
            old_amount: money('599.00'),
            new_amount: money('649.00'),
            transaction_id: TX_NETFLIX_CHARGE,
            occurred_on: '2026-11-02',
            created_at: linkedAt,
          }),
          // Linked and unlinked before: no longer a payment.
          paymentRecorded(
            'e5e5e5e5-5555-4555-8555-000000000012',
            TX_NETFLIX_OLD,
            '2026-10-02T06:00:00Z',
          ),
          makeSubscriptionEvent({
            id: 'e5e5e5e5-5555-4555-8555-000000000013',
            kind: 'payment_unlinked',
            new_amount: money('649.00'),
            transaction_id: TX_NETFLIX_OLD,
            occurred_on: '2026-10-05',
            created_at: '2026-10-05T06:00:00Z',
          }),
        ],
      }),
    };
    const deleted: string[] = [];
    server.use(
      subscriptionHandler(state),
      http.delete(`${API}/subscriptions/:id/payments/:transactionId`, ({ params }) => {
        deleted.push(String(params.transactionId));
        state.current = {
          ...state.current,
          version: 3,
          payments: [],
          events: [
            ...state.current.events,
            makeSubscriptionEvent({
              id: 'e5e5e5e5-5555-4555-8555-000000000014',
              kind: 'payment_unlinked',
              new_amount: money('649.00'),
              transaction_id: TX_NETFLIX_CHARGE,
              occurred_on: '2026-11-05',
              created_at: '2026-11-05T06:00:00Z',
            }),
          ],
        };
        return HttpResponse.json(envelope(state.current));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    const payments = screen.getByRole('region', { name: 'Payments' });
    // Only the payment that is still linked can be unlinked.
    expect(within(payments).getAllByRole('link', { name: 'View transaction' })).toHaveLength(1);
    await user.click(
      within(payments).getByRole('button', { name: 'Unlink the payment of November 2, 2026' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Unlink this payment?' });
    expect(within(dialog).getByText(/The transaction itself doesn’t change/)).toBeInTheDocument();
    expect(within(dialog).getByText(/The price stays as it is/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Unlink payment' }));

    expect(await within(payments).findByText(/No payments linked yet/)).toBeInTheDocument();
    expect(deleted).toEqual([TX_NETFLIX_CHARGE]);
    const history = screen.getByRole('region', { name: 'History' });
    expect(within(history).getAllByText('Payment unlinked')).toHaveLength(2);
    expect(within(history).getAllByText('Payment linked')).toHaveLength(2);
  });

  it('pauses, notes cancelling and marks it cancelled with the version and date', async () => {
    const state = { current: makeSubscription() };
    const calls: { action: string; version: string | null; body: SubscriptionActionInput }[] = [];
    const respond = (status: SubscriptionDetail['status']) => {
      state.current = { ...state.current, status, version: state.current.version + 1 };
      return HttpResponse.json(envelope(state.current));
    };
    server.use(
      subscriptionHandler(state),
      http.post(`${API}/subscriptions/:id/:action`, async ({ params, request }) => {
        const action = String(params.action);
        calls.push({
          action,
          version: new URL(request.url).searchParams.get('version'),
          body: (await request.json()) as SubscriptionActionInput,
        });
        if (action === 'pause') return respond('paused');
        if (action === 'cancellation-started') return respond('cancellation_pending');
        if (action === 'cancelled') {
          state.current = { ...state.current, cancelled_on: '2026-11-01' };
          return respond('cancelled');
        }
        return HttpResponse.json(errorBody({ code: 'BAD_REQUEST' }), { status: 400 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    const manage = screen.getByRole('region', { name: 'Manage' });

    await user.click(within(manage).getByRole('button', { name: 'Pause tracking' }));
    expect(await screen.findByText('Subscription paused')).toBeInTheDocument();
    expect(
      await within(manage).findByRole('button', { name: 'Resume tracking' }),
    ).toBeInTheDocument();

    await user.click(within(manage).getByRole('button', { name: 'I’m cancelling it' }));
    const start = await screen.findByRole('dialog', {
      name: 'You’re cancelling this subscription',
    });
    expect(
      within(start).getByRole('link', { name: /Open the provider’s cancellation page/ }),
    ).toHaveAttribute('href', 'https://www.netflix.com/cancelplan');
    await user.type(within(start).getByLabelText(/^Note/), 'Ticket 42');
    await user.click(within(start).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Noted that you are cancelling')).toBeInTheDocument();
    expect(await screen.findByText('Cancellation in progress')).toBeInTheDocument();

    await user.click(within(manage).getByRole('button', { name: 'Mark as cancelled' }));
    const done = await screen.findByRole('dialog', { name: 'Mark as cancelled' });
    await user.click(within(done).getByRole('button', { name: 'Mark as cancelled' }));
    expect(
      await within(done).findByText('Tick this once the provider has confirmed the cancellation.'),
    ).toBeInTheDocument();
    expect(calls.map((call) => call.action)).toEqual(['pause', 'cancellation-started']);

    const date = within(done).getByLabelText('Cancelled on');
    await user.clear(date);
    await user.type(date, '2026-11-01');
    await user.click(
      within(done).getByLabelText('The provider confirmed that Netflix is cancelled'),
    );
    await user.click(within(done).getByRole('button', { name: 'Mark as cancelled' }));
    expect(await screen.findByText('Marked as cancelled')).toBeInTheDocument();
    // Every action carries the version that was on screen.
    expect(calls.map((call) => call.version)).toEqual(['2', '3', '4']);
    expect(calls[1]!.body).toEqual({
      effective_on: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/) as string,
      note: 'Ticket 42',
    });
    expect(calls[2]).toMatchObject({
      action: 'cancelled',
      body: { cancelled_on: '2026-11-01', confirm: true },
    });
    const renewal = screen.getByRole('region', { name: 'Renewal' });
    expect(await within(renewal).findByText('November 1, 2026')).toBeInTheDocument();
  });

  it('explains a status that changed elsewhere and loads the latest version', async () => {
    const state = { current: makeSubscription() };
    const reads = { count: 0 };
    server.use(
      subscriptionHandler(state, reads),
      http.post(`${API}/subscriptions/:id/pause`, () => {
        // Cancelled on another device meanwhile.
        state.current = makeSubscription({
          status: 'cancelled',
          cancelled_on: '2026-11-03',
          next_renewal_date: undefined,
          version: 5,
        });
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                code: 'invalid_status_transition',
                message: 'A subscription cannot move from cancelled to paused.',
                params: { from: 'cancelled', to: 'paused' },
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    const manage = screen.getByRole('region', { name: 'Manage' });
    await user.click(within(manage).getByRole('button', { name: 'Pause tracking' }));
    expect(
      await screen.findByText(
        'This can’t change from cancelled to paused. Its status may have changed somewhere else, so we’ve loaded the latest version.',
      ),
    ).toBeInTheDocument();
    expect(await within(manage).findByRole('button', { name: 'Reactivate' })).toBeInTheDocument();
    expect(within(manage).queryByRole('button', { name: 'Pause tracking' })).toBeNull();
    expect(reads.count).toBeGreaterThan(1);
  });

  it('explains the fair-use limit when reactivating', async () => {
    const state = {
      current: makeSubscription({ status: 'cancelled', cancelled_on: '2026-11-01' }),
    };
    server.use(
      subscriptionHandler(state),
      http.post(`${API}/subscriptions/:id/reactivate`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                code: 'record_limit_reached',
                message: 'You can keep up to 500 of these.',
                params: { resource: 'subscriptions', limit: '500' },
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    await user.click(screen.getByRole('button', { name: 'Reactivate' }));
    expect(
      await screen.findByText(
        'You can keep up to 500 open subscriptions. Mark ones you no longer pay for as cancelled, then try again.',
      ),
    ).toBeInTheDocument();
  });

  it('ticks one cancellation step with its index and the version on screen', async () => {
    const state = { current: makeSubscription() };
    const calls: { index: string; body: ChecklistItemPatch }[] = [];
    server.use(
      subscriptionHandler(state),
      http.patch(
        `${API}/subscriptions/:id/cancellation-checklist/:index`,
        async ({ params, request }) => {
          calls.push({
            index: String(params.index),
            body: (await request.json()) as ChecklistItemPatch,
          });
          state.current = makeSubscription({
            version: 3,
            cancellation_checklist: [{ item: 'Download invoices', done: true }],
          });
          return HttpResponse.json(envelope(state.current));
        },
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    await user.click(screen.getByLabelText('Download invoices'));
    await waitFor(() => {
      expect(screen.getByLabelText('Download invoices')).toBeChecked();
    });
    expect(calls).toEqual([{ index: '0', body: { done: true, version: 2 } }]);
  });

  it('reloads the checklist when it changed somewhere else', async () => {
    const state = { current: makeSubscription() };
    server.use(
      subscriptionHandler(state),
      http.patch(`${API}/subscriptions/:id/cancellation-checklist/:index`, () => {
        state.current = makeSubscription({
          version: 3,
          cancellation_checklist: [{ item: 'Download invoices', done: true }],
        });
        return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    await user.click(screen.getByLabelText('Download invoices'));
    expect(
      await screen.findByText(
        'This subscription changed somewhere else. We loaded the latest version; tick the step again.',
      ),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.getByLabelText('Download invoices')).toBeChecked();
    });
  });

  it('is read-only for people it is shared with', async () => {
    server.use(
      subscriptionHandler({
        current: makeSubscription({
          owned: false,
          events: [
            paymentRecorded(
              'e5e5e5e5-5555-4555-8555-000000000021',
              TX_NETFLIX_CHARGE,
              '2026-11-02T06:00:00Z',
            ),
          ],
        }),
      }),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Netflix');
    expect(screen.getByText('Shared with you to view')).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Manage' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Edit' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Link a payment' })).toBeNull();
    expect(screen.queryByRole('button', { name: /Unlink/ })).toBeNull();
    expect(screen.getByLabelText('Download invoices')).toBeDisabled();
  });

  it('shows not found and retryable errors', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/subscriptions/:id`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('We couldn’t load this subscription')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('Subscription not found')).toBeInTheDocument();
  });
});
