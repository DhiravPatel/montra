import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { ACCOUNT_CASH, makeAccount, money } from '@/tests/financeFixtures';
import {
  BILL_ID,
  OCC_DUE,
  TX_BILL_PAYMENT,
  makeBill,
  makeCandidate,
  makeOccurrence,
} from '@/tests/planningFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const WATER_ID = 'b3333333-3333-4333-8333-333333333333';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

beforeAll(async () => {
  await Promise.all([
    import('./BillsPage'),
    import('./BillCreatePage'),
    import('./BillEditPage'),
    import('./BillDetailPage'),
  ]);
});

beforeEach(() => {
  // Only Date is faked: "today" is 5 Nov 2026 in Asia/Kolkata.
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
  testBackend.accounts = [makeAccount()];
});

describe('BillsPage', () => {
  it('puts bills that are due first and marks one paid by linking the recorded payment', async () => {
    const water = makeBill({
      id: WATER_ID,
      name: 'Water',
      provider_name: undefined,
      state: 'upcoming',
      amount_is_variable: true,
      expected_amount: undefined,
      next_due: makeOccurrence({
        id: 'd9999999-9999-4999-8999-999999999999',
        bill_id: WATER_ID,
        effective_date: '2026-11-20',
        occurrence_date: '2026-11-20',
        amount: undefined,
      }),
    });
    const requests: { key: string | null; body: unknown }[] = [];
    server.use(
      http.get(`${API}/bills`, () => HttpResponse.json(envelope([makeBill(), water]))),
      http.get(`${API}/bills/:id/payment-candidates`, ({ request }) => {
        expect(new URL(request.url).searchParams.get('occurrence_id')).toBe(OCC_DUE);
        return HttpResponse.json(envelope([makeCandidate()]));
      }),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([]))),
      http.post(`${API}/bills/:id/mark-paid`, async ({ request, params }) => {
        expect(params.id).toBe(BILL_ID);
        requests.push({
          key: request.headers.get('Idempotency-Key'),
          body: await request.json(),
        });
        return HttpResponse.json(envelope(makeBill({ state: 'paid' })));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/planning/bills', { user: signedIn() });
    await findPageHeading('Bills');

    const dueNow = await screen.findByRole('region', { name: 'Due now' });
    expect(within(dueNow).getByRole('link', { name: 'Electricity' })).toHaveAttribute(
      'href',
      `/planning/bills/${BILL_ID}`,
    );
    expect(within(dueNow).getByText('Due today')).toBeInTheDocument();
    expect(within(dueNow).getByText('BESCOM · Every month on day 5')).toBeInTheDocument();
    expect(within(dueNow).getByText('Next due Nov 5, 2026')).toBeInTheDocument();
    const others = screen.getByRole('region', { name: 'Other bills' });
    expect(within(others).getByText('Upcoming')).toBeInTheDocument();
    expect(within(others).getByText('Amount varies')).toBeInTheDocument();

    await user.click(within(dueNow).getByRole('button', { name: 'Mark paid: Electricity' }));
    const choose = await screen.findByRole('dialog', { name: 'Mark “Electricity” paid' });
    expect(within(choose).getByText('Due November 5, 2026 · ₹1,200.00')).toBeInTheDocument();
    expect(
      within(choose).getByRole('radio', { name: /Link a payment I already recorded/ }),
    ).toBeChecked();
    await user.click(within(choose).getByRole('button', { name: 'Continue' }));

    const picker = await screen.findByRole('dialog', {
      name: 'Link the payment for “Electricity”',
    });
    const suggestion = await within(picker).findByRole('radio', { name: /BESCOM/ });
    // Reason codes and the days from the due date are shown in the interface language.
    expect(within(picker).getByText('Same provider')).toBeInTheDocument();
    expect(within(picker).getByText('Same amount as expected')).toBeInTheDocument();
    expect(within(picker).getByText('Within 10 days of the due date')).toBeInTheDocument();
    expect(within(picker).getByText('1 day before the due date')).toBeInTheDocument();
    await user.click(suggestion);
    await user.click(within(picker).getByRole('button', { name: 'Link payment' }));

    expect(await screen.findByText('“Electricity” marked as paid')).toBeInTheDocument();
    expect(requests).toHaveLength(1);
    expect(requests[0]?.body).toEqual({ occurrence_id: OCC_DUE, transaction_id: TX_BILL_PAYMENT });
    expect(requests[0]?.key).toMatch(/^web-/);
  });

  it('filters by status through the API', async () => {
    const seen: string[] = [];
    server.use(
      http.get(`${API}/bills`, ({ request }) => {
        const search = new URL(request.url).search;
        seen.push(search);
        return HttpResponse.json(envelope(search ? [] : [makeBill()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/planning/bills', { user: signedIn() });
    await findPageHeading('Bills');
    await screen.findByRole('link', { name: 'Electricity' });
    await user.selectOptions(screen.getByRole('combobox', { name: 'Show bills' }), 'archived');
    expect(await screen.findByText('No bills to show here.')).toBeInTheDocument();
    expect(seen).toEqual(['', '?status=archived']);
  });

  it('shows a first-use empty state, errors and missing access', async () => {
    server.use(http.get(`${API}/bills`, () => HttpResponse.json(envelope([]))));
    const first = renderRoute('/planning/bills', { user: signedIn() });
    await findPageHeading('Bills');
    expect(await screen.findByText('No bills yet')).toBeInTheDocument();
    first.unmount();

    server.use(
      http.get(`${API}/bills`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-bills' }), {
          status: 500,
        }),
      ),
    );
    const second = renderRoute('/planning/bills', { user: signedIn() });
    await findPageHeading('Bills');
    expect(await screen.findByText('We couldn’t load your bills')).toBeInTheDocument();
    expect(screen.getByText('req-bills')).toBeInTheDocument();
    second.unmount();

    server.use(
      http.get(`${API}/bills`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/planning/bills', { user: signedIn() });
    await findPageHeading('Bills');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});

describe('BillCreatePage', () => {
  it('validates before calling the API', async () => {
    const user = userEvent.setup();
    renderRoute('/planning/bills/new', { user: signedIn() });
    await findPageHeading('Add a bill');
    await user.click(await screen.findByRole('button', { name: 'Add bill' }));
    expect(await screen.findByText('Enter a name for the bill.')).toBeInTheDocument();
    expect(screen.getByText('Enter an amount.')).toBeInTheDocument();
  });

  it('creates a monthly bill paid from an account', async () => {
    let body: unknown;
    let key: string | null = null;
    server.use(
      http.post(`${API}/bills`, async ({ request }) => {
        key = request.headers.get('Idempotency-Key');
        body = await request.json();
        return HttpResponse.json(envelope(makeBill()), { status: 201 });
      }),
      http.get(`${API}/bills/:id`, () => HttpResponse.json(envelope(makeBill()))),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/planning/bills/new', { user: signedIn() });
    await findPageHeading('Add a bill');
    await user.type(await screen.findByLabelText('Bill name'), 'Electricity');
    await user.type(screen.getByLabelText(/^Provider/), 'BESCOM');
    await user.selectOptions(screen.getByLabelText(/^Usually paid from/), ACCOUNT_CASH);
    expect(screen.getByText('In INR, the account’s currency.')).toBeInTheDocument();
    await user.type(screen.getByLabelText('Expected amount'), '1200');
    await user.selectOptions(screen.getByLabelText(/^Date of the month/), '5');
    await user.click(screen.getByRole('button', { name: 'Add bill' }));

    await findPageHeading('Electricity');
    expect(router.state.location.pathname).toBe(`/planning/bills/${BILL_ID}`);
    expect(screen.getByText('Bill added')).toBeInTheDocument();
    expect(body).toEqual({
      name: 'Electricity',
      provider_name: 'BESCOM',
      frequency: 'monthly',
      by_month_day: 5,
      start_date: '2026-11-05',
      local_time: '09:00',
      reminder_days_before: [1],
      amount_is_variable: false,
      currency: 'INR',
      expected_amount: '1200.00',
      payment_account_id: ACCOUNT_CASH,
    });
    expect(key).toMatch(/^web-/);
  });

  it('retries a failed create with the same Idempotency-Key and explains the bill limit', async () => {
    const keys: (string | null)[] = [];
    server.use(
      http.post(`${API}/bills`, ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        if (keys.length === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: 'You can keep up to 200 of these.',
                code: 'record_limit_reached',
                params: { resource: 'bills', limit: '200' },
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/planning/bills/new', { user: signedIn() });
    await findPageHeading('Add a bill');
    await user.type(await screen.findByLabelText('Bill name'), 'Water');
    await user.type(screen.getByLabelText('Expected amount'), '400');
    await user.click(screen.getByRole('button', { name: 'Add bill' }));
    expect(
      await screen.findByText('Something went wrong on our side. Try again in a moment.'),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add bill' }));
    expect(
      await screen.findByText(
        'You can keep up to 200 open bills. Archive or delete bills you no longer need, then try again.',
      ),
    ).toBeInTheDocument();
    expect(keys).toHaveLength(2);
    expect(keys[0]).toMatch(/^web-/);
    expect(keys[1]).toBe(keys[0]);
  });

  it('creates a variable bill on a custom schedule with an end and reminders', async () => {
    let body: unknown;
    server.use(
      http.post(`${API}/bills`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(makeBill()), { status: 201 });
      }),
      http.get(`${API}/bills/:id`, () => HttpResponse.json(envelope(makeBill()))),
    );
    const user = userEvent.setup();
    renderRoute('/planning/bills/new', { user: signedIn() });
    await findPageHeading('Add a bill');
    await user.type(await screen.findByLabelText('Bill name'), 'Cleaner');
    await user.click(screen.getByLabelText('The amount changes each time'));
    expect(screen.queryByLabelText('Expected amount')).not.toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Repeats'), 'custom');
    await user.clear(screen.getByLabelText('Every'));
    await user.type(screen.getByLabelText('Every'), '2');
    await user.selectOptions(screen.getByLabelText('Unit'), 'week');
    await user.selectOptions(screen.getByLabelText(/^Day of the week/), '1');
    await user.click(screen.getByRole('radio', { name: 'After a number of times' }));
    await user.type(screen.getByLabelText('Number of times'), '6');
    await user.click(screen.getByRole('checkbox', { name: 'On the day' }));
    await user.click(screen.getByRole('checkbox', { name: '1 day before' }));
    await user.click(screen.getByRole('button', { name: 'Add bill' }));

    await findPageHeading('Electricity');
    expect(body).toEqual({
      name: 'Cleaner',
      frequency: 'custom',
      interval_count: 2,
      interval_unit: 'week',
      by_weekday: 1,
      start_date: '2026-11-05',
      max_occurrences: 6,
      local_time: '09:00',
      reminder_days_before: [0],
      amount_is_variable: true,
      currency: 'INR',
    });
  });

  it('shows schedule errors from the form and the API', async () => {
    server.use(
      http.post(`${API}/bills`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.start_date', message: 'Enter a valid date.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/planning/bills/new', { user: signedIn() });
    await findPageHeading('Add a bill');
    await user.type(await screen.findByLabelText('Bill name'), 'Rent');
    await user.type(screen.getByLabelText('Expected amount'), '15000');
    await user.click(screen.getByRole('radio', { name: 'On a date' }));
    await user.type(screen.getByLabelText('End date'), '2026-10-01');
    await user.click(screen.getByRole('button', { name: 'Add bill' }));
    expect(
      await screen.findByText('The end date must be on or after the start date.'),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('radio', { name: 'Never' }));
    await user.click(screen.getByRole('button', { name: 'Add bill' }));
    expect(await screen.findByText('Enter a valid date.')).toBeInTheDocument();
    expect(screen.getByLabelText('Starts on')).toHaveAttribute('aria-invalid', 'true');
  });
});

describe('BillEditPage', () => {
  it('sends only what changed with its version and reloads after a conflict', async () => {
    let version = 4;
    const bodies: unknown[] = [];
    server.use(
      http.get(`${API}/bills/:id`, () =>
        HttpResponse.json(
          envelope(version === 4 ? makeBill() : makeBill({ version: 5, name: 'Power' })),
        ),
      ),
      http.patch(`${API}/bills/:id`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          version = 5;
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeBill({ version: 6, name: 'Power bill' })));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`/planning/bills/${BILL_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit bill');
    const name = await screen.findByLabelText('Bill name');
    await user.clear(name);
    await user.type(name, 'Electricity bill');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    // Partial update: only the changed field and the version on screen.
    expect(bodies[0]).toEqual({ name: 'Electricity bill', version: 4 });
    await waitFor(() => {
      expect(screen.getByLabelText('Bill name')).toHaveValue('Power');
    });
    const reloaded = screen.getByLabelText('Bill name');
    await user.clear(reloaded);
    await user.type(reloaded, 'Power bill');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Bill updated')).toBeInTheDocument();
    expect(bodies[1]).toEqual({ name: 'Power bill', version: 5 });
    expect(router.state.location.pathname).toBe(`/planning/bills/${BILL_ID}`);
  });

  it('clears emptied fields and sends the anchors of a new frequency', async () => {
    let body: unknown;
    server.use(
      http.get(`${API}/bills/:id`, () =>
        HttpResponse.json(envelope(makeBill({ notes: 'Pay before the 5th' }))),
      ),
      http.patch(`${API}/bills/:id`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(makeBill()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/planning/bills/${BILL_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit bill');
    await user.clear(await screen.findByLabelText(/^Provider/));
    await user.selectOptions(screen.getByLabelText(/^Usually paid from/), '');
    await user.clear(screen.getByLabelText(/^Notes/));
    await user.selectOptions(screen.getByLabelText('Repeats'), 'weekly');
    await user.selectOptions(screen.getByLabelText(/^Day of the week/), '1');
    await user.click(screen.getByRole('checkbox', { name: '1 day before' }));
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('Bill updated')).toBeInTheDocument();
    expect(body).toEqual({
      version: 4,
      provider_name: '',
      notes: '',
      frequency: 'weekly',
      by_weekday: 1,
      reminder_days_before: [],
      clear: ['payment_account_id', 'by_month_day'],
    });
  });

  it('does not call the API when nothing changed', async () => {
    let patched = false;
    server.use(
      http.get(`${API}/bills/:id`, () => HttpResponse.json(envelope(makeBill()))),
      http.patch(`${API}/bills/:id`, () => {
        patched = true;
        return HttpResponse.json(envelope(makeBill()));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`/planning/bills/${BILL_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit bill');
    await screen.findByLabelText('Bill name');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(
      await screen.findByText('Nothing changed, so there was nothing to save'),
    ).toBeInTheDocument();
    expect(router.state.location.pathname).toBe(`/planning/bills/${BILL_ID}`);
    expect(patched).toBe(false);
  });

  it('does not offer editing to someone who cannot change the bill', async () => {
    server.use(
      http.get(`${API}/bills/:id`, () => HttpResponse.json(envelope(makeBill({ owned: false })))),
    );
    renderRoute(`/planning/bills/${BILL_ID}/edit`, { user: signedIn() });
    expect(await screen.findByText('You can’t change this bill')).toBeInTheDocument();
    expect(screen.queryByLabelText('Bill name')).not.toBeInTheDocument();
  });

  it('keeps an amount the user types exactly', async () => {
    let body: { expected_amount?: string } = {};
    server.use(
      http.get(`${API}/bills/:id`, () =>
        HttpResponse.json(envelope(makeBill({ expected_amount: money('999.99') }))),
      ),
      http.patch(`${API}/bills/:id`, async ({ request }) => {
        body = (await request.json()) as { expected_amount?: string };
        return HttpResponse.json(envelope(makeBill()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/planning/bills/${BILL_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit bill');
    const amount = await screen.findByLabelText('Expected amount');
    expect(amount).toHaveValue('999.99');
    await user.clear(amount);
    await user.type(amount, '1,234.56');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Bill updated')).toBeInTheDocument();
    expect(body.expected_amount).toBe('1234.56');
  });
});
