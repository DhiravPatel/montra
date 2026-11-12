import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACCOUNT_CARD,
  ACCOUNT_CASH,
  CATEGORY_SALARY,
  makeAccount,
  makeCard,
  money,
  starterCategories,
} from '@/tests/financeFixtures';
import {
  BILL_ID,
  BILL_RULE_ID,
  RULE_ID,
  makeOccurrence,
  makeRule,
  makeRuleDetail,
} from '@/tests/planningFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const SALARY_ID = 'c2222222-2222-4222-8222-222222222222';
const GYM_ID = 'c3333333-3333-4333-8333-333333333333';
const MERCHANT_ID = '99999999-9999-4999-8999-999999999902';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

beforeAll(async () => {
  await Promise.all([
    import('./RecurringRulesPage'),
    import('./RecurringRuleCreatePage'),
    import('./RecurringRuleEditPage'),
    import('./RecurringRuleDetailPage'),
  ]);
});

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
  testBackend.accounts = [makeAccount()];
  testBackend.categories = starterCategories();
});

describe('RecurringRulesPage', () => {
  it('lists recurring items with schedule, next date and amount, leaving bills to their page', async () => {
    server.use(
      http.get(`${API}/recurring-rules`, () =>
        HttpResponse.json(
          envelope([
            makeRule(),
            makeRule({
              id: SALARY_ID,
              kind: 'income',
              name: 'Salary',
              auto_post: true,
              amount: money('85000.00'),
              by_month_day: 1,
              category_id: CATEGORY_SALARY,
              merchant: { id: MERCHANT_ID, name: 'Acme' },
              next_occurrence: '2026-12-01',
            }),
            makeRule({ id: BILL_RULE_ID, kind: 'bill', name: 'Electricity' }),
            makeRule({
              id: GYM_ID,
              name: 'Gym',
              status: 'paused',
              frequency: 'weekly',
              by_month_day: undefined,
              by_weekday: 6,
              amount: undefined,
              amount_is_variable: true,
              account_id: undefined,
              next_occurrence: undefined,
            }),
          ]),
        ),
      ),
    );
    renderRoute('/planning/recurring', { user: signedIn() });
    await findPageHeading('Recurring');

    const rent = (await screen.findByRole('link', { name: 'Rent' })).closest('li');
    expect(screen.getByRole('link', { name: 'Rent' })).toHaveAttribute(
      'href',
      `/planning/recurring/${RULE_ID}`,
    );
    expect(
      within(rent!).getByText('Expense · Every month on the last day · Wallet'),
    ).toBeInTheDocument();
    expect(within(rent!).getByText('Next Nov 30, 2026')).toBeInTheDocument();
    expect(within(rent!).getByText('₹15,000.00')).toBeInTheDocument();

    const salary = screen.getByRole('link', { name: 'Salary' }).closest('li');
    expect(within(salary!).getByText('Recorded automatically')).toBeInTheDocument();
    expect(
      within(salary!).getByText('Income · Every month on day 1 · Wallet · Acme'),
    ).toBeInTheDocument();

    const gym = screen.getByRole('link', { name: 'Gym' }).closest('li');
    expect(within(gym!).getByText('Paused')).toBeInTheDocument();
    expect(within(gym!).getByText('Expense · Every week on Saturday')).toBeInTheDocument();
    expect(within(gym!).getByText('Amount varies')).toBeInTheDocument();
    expect(within(gym!).getByText('Nothing scheduled')).toBeInTheDocument();

    expect(screen.queryByRole('link', { name: 'Electricity' })).not.toBeInTheDocument();
  });

  it('filters by type and status through the API', async () => {
    const seen: string[] = [];
    server.use(
      http.get(`${API}/recurring-rules`, ({ request }) => {
        const search = new URL(request.url).search;
        seen.push(search);
        return HttpResponse.json(envelope(search ? [] : [makeRule()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/planning/recurring', { user: signedIn() });
    await findPageHeading('Recurring');
    await screen.findByRole('link', { name: 'Rent' });
    await user.selectOptions(screen.getByRole('combobox', { name: 'Type' }), 'income');
    await user.selectOptions(screen.getByRole('combobox', { name: 'Status' }), 'paused');
    expect(await screen.findByText('No recurring items match these filters.')).toBeInTheDocument();
    expect(seen).toEqual(['', '?kind=income', '?kind=income&status=paused']);
  });

  it('shows a first-use empty state and a recoverable error', async () => {
    server.use(http.get(`${API}/recurring-rules`, () => HttpResponse.json(envelope([]))));
    const first = renderRoute('/planning/recurring', { user: signedIn() });
    await findPageHeading('Recurring');
    expect(await screen.findByText('No recurring items yet')).toBeInTheDocument();
    first.unmount();

    server.use(
      http.get(`${API}/recurring-rules`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-rules' }), {
          status: 500,
        }),
      ),
    );
    renderRoute('/planning/recurring', { user: signedIn() });
    await findPageHeading('Recurring');
    expect(await screen.findByText('We couldn’t load your recurring items')).toBeInTheDocument();
    expect(screen.getByText('req-rules')).toBeInTheDocument();
  });
});

describe('RecurringRuleCreatePage', () => {
  it('requires an account before recording automatically, then creates the income', async () => {
    let body: unknown;
    let key: string | null = null;
    server.use(
      http.post(`${API}/recurring-rules`, async ({ request }) => {
        key = request.headers.get('Idempotency-Key');
        body = await request.json();
        return HttpResponse.json(envelope(makeRule({ id: SALARY_ID, name: 'Salary' })), {
          status: 201,
        });
      }),
      http.get(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(envelope(makeRuleDetail({ id: SALARY_ID, name: 'Salary' }))),
      ),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/planning/recurring/new', { user: signedIn() });
    await findPageHeading('Add a recurring item');
    await user.click(await screen.findByRole('radio', { name: 'Income' }));
    await user.type(screen.getByLabelText('Name'), 'Salary');
    await user.type(screen.getByLabelText('Amount'), '85000');
    await user.selectOptions(screen.getByLabelText(/^Category/), CATEGORY_SALARY);
    await user.type(screen.getByLabelText(/^Received from/), 'Acme');
    await user.selectOptions(screen.getByLabelText(/^Date of the month/), '1');
    await user.click(screen.getByLabelText('Record it automatically when it’s due'));
    await user.click(screen.getByRole('button', { name: 'Add recurring item' }));
    expect(
      await screen.findByText('Choose an account to record it automatically.'),
    ).toBeInTheDocument();
    expect(body).toBeUndefined();

    await user.selectOptions(screen.getByRole('combobox', { name: /^Account/ }), ACCOUNT_CASH);
    await user.click(screen.getByRole('button', { name: 'Add recurring item' }));
    await findPageHeading('Salary');
    expect(router.state.location.pathname).toBe(`/planning/recurring/${SALARY_ID}`);
    expect(body).toEqual({
      kind: 'income',
      name: 'Salary',
      frequency: 'monthly',
      by_month_day: 1,
      start_date: '2026-11-05',
      local_time: '09:00',
      reminder_days_before: [1],
      amount_is_variable: false,
      auto_post: true,
      amount: '85000.00',
      account_id: ACCOUNT_CASH,
      category_id: CATEGORY_SALARY,
      merchant_name: 'Acme',
    });
    expect(key).toMatch(/^web-/);
  });

  it('keeps the Idempotency-Key for a retry and explains the schedule limit', async () => {
    const keys: (string | null)[] = [];
    server.use(
      http.post(`${API}/recurring-rules`, ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        if (keys.length === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: 'You can keep up to 500 of these.',
                code: 'record_limit_reached',
                params: { resource: 'recurring_rules', limit: '500' },
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/planning/recurring/new', { user: signedIn() });
    await findPageHeading('Add a recurring item');
    await user.type(await screen.findByLabelText('Name'), 'Rent');
    await user.type(screen.getByLabelText('Amount'), '15000');
    await user.click(screen.getByRole('button', { name: 'Add recurring item' }));
    expect(
      await screen.findByText('Something went wrong on our side. Try again in a moment.'),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add recurring item' }));
    expect(
      await screen.findByText(
        'You can keep up to 500 active recurring items. End or delete ones you no longer need, then try again.',
      ),
    ).toBeInTheDocument();
    expect(keys).toHaveLength(2);
    expect(keys[1]).toBe(keys[0]);
  });

  it('creates a transfer between two different accounts', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    let body: unknown;
    server.use(
      http.post(`${API}/recurring-rules`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(makeRule({ kind: 'transfer' })), { status: 201 });
      }),
      http.get(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(envelope(makeRuleDetail({ kind: 'transfer' }))),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/planning/recurring/new', { user: signedIn() });
    await findPageHeading('Add a recurring item');
    await user.click(await screen.findByRole('radio', { name: 'Transfer' }));
    await user.type(screen.getByLabelText('Name'), 'Card payment');
    await user.type(screen.getByLabelText('Amount'), '5000');
    await user.selectOptions(screen.getByLabelText('From account'), ACCOUNT_CASH);
    await user.selectOptions(screen.getByLabelText('To account'), ACCOUNT_CASH);
    expect(screen.queryByLabelText(/^Category/)).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add recurring item' }));
    expect(await screen.findByText('Choose two different accounts.')).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('To account'), ACCOUNT_CARD);
    await user.click(screen.getByRole('button', { name: 'Add recurring item' }));
    await findPageHeading('Rent');
    expect(body).toMatchObject({
      kind: 'transfer',
      name: 'Card payment',
      amount: '5000.00',
      account_id: ACCOUNT_CASH,
      to_account_id: ACCOUNT_CARD,
    });
    expect(body).not.toHaveProperty('category_id');
    expect(body).not.toHaveProperty('merchant_name');
  });

  it('shows the API’s rule explanation in the interface language', async () => {
    server.use(
      http.post(`${API}/recurring-rules`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            message: 'Auto-posting needs a fixed amount and an account.',
            details: [
              {
                message: 'Auto-posting needs a fixed amount and an account.',
                code: 'auto_post_needs_amount_and_account',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/planning/recurring/new', { user: signedIn() });
    await findPageHeading('Add a recurring item');
    await user.type(await screen.findByLabelText('Name'), 'Rent');
    await user.type(screen.getByLabelText('Amount'), '15000');
    await user.click(screen.getByRole('button', { name: 'Add recurring item' }));
    expect(
      await screen.findByText('Recording automatically needs a fixed amount and an account.'),
    ).toBeInTheDocument();
  });
});

describe('RecurringRuleEditPage', () => {
  it('sends only what changed with its version, keeps the payee, and reloads after a conflict', async () => {
    let version = 3;
    const bodies: unknown[] = [];
    server.use(
      http.get(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(
          envelope(
            makeRuleDetail({
              merchant_id: MERCHANT_ID,
              merchant: { id: MERCHANT_ID, name: 'Landlord' },
              version,
              amount: version === 3 ? money('15000.00') : money('16000.00'),
            }),
          ),
        ),
      ),
      http.patch(`${API}/recurring-rules/:id`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          version = 4;
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeRule({ version: 5 })));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`/planning/recurring/${RULE_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit recurring item');
    expect(await screen.findByLabelText(/^Paid to/)).toHaveValue('Landlord');
    expect(screen.getByRole('radio', { name: 'Income' })).toBeDisabled();
    const amount = screen.getByLabelText('Amount');
    await user.clear(amount);
    await user.type(amount, '15500');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    // Partial update: the payee and everything else unchanged are not sent.
    expect(bodies[0]).toEqual({ amount: '15500.00', version: 3 });
    await waitFor(() => {
      expect(screen.getByLabelText('Amount')).toHaveValue('16000.00');
    });
    const reloaded = screen.getByLabelText('Amount');
    await user.clear(reloaded);
    await user.type(reloaded, '16500');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Recurring item updated')).toBeInTheDocument();
    expect(bodies[1]).toEqual({ amount: '16500.00', version: 4 });
    expect(router.state.location.pathname).toBe(`/planning/recurring/${RULE_ID}`);
  });

  it('clears an emptied account and category and empties the payee', async () => {
    let body: unknown;
    server.use(
      http.get(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(
          envelope(makeRuleDetail({ merchant: { id: MERCHANT_ID, name: 'Landlord' } })),
        ),
      ),
      http.patch(`${API}/recurring-rules/:id`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(makeRule({ version: 4 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/planning/recurring/${RULE_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit recurring item');
    await user.selectOptions(await screen.findByRole('combobox', { name: /^Account/ }), '');
    await user.selectOptions(screen.getByLabelText(/^Category/), '');
    await user.clear(screen.getByLabelText(/^Paid to/));
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Recurring item updated')).toBeInTheDocument();
    expect(body).toEqual({
      version: 3,
      merchant_name: '',
      clear: ['account_id', 'category_id'],
    });
  });

  it('sends bills to their own page', async () => {
    server.use(
      http.get(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(
          envelope(
            makeRuleDetail({
              id: BILL_RULE_ID,
              kind: 'bill',
              name: 'Electricity',
              bill_id: BILL_ID,
              occurrences: [makeOccurrence()],
            }),
          ),
        ),
      ),
    );
    renderRoute(`/planning/recurring/${BILL_RULE_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit recurring item');
    expect(screen.getByRole('link', { name: 'Open the bill' })).toHaveAttribute(
      'href',
      `/planning/bills/${BILL_ID}`,
    );
    expect(screen.queryByLabelText('Name')).not.toBeInTheDocument();
  });

  it('does not offer editing to someone who cannot change the item', async () => {
    server.use(
      http.get(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(envelope(makeRuleDetail({ owned: false }))),
      ),
    );
    renderRoute(`/planning/recurring/${RULE_ID}/edit`, { user: signedIn() });
    expect(await screen.findByText('You can’t change this item')).toBeInTheDocument();
  });
});
