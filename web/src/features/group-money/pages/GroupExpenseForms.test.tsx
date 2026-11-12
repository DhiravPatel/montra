import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { ACCOUNT_CASH, makeAccount, money } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  EXPENSE_ID,
  FILE_ID,
  ME,
  MEERA,
  MONEY_GROUP,
  RAVI,
  makeExpenseDetail,
  serveMoneyGroup,
} from '@/tests/groupMoneyFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import type { GroupExpenseDetail } from '../types';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const NEW = `/groups/${MONEY_GROUP}/expenses/new`;
const DETAIL = `/groups/${MONEY_GROUP}/expenses/${EXPENSE_ID}`;
const ME_LABEL = 'You (Asha Rao)';
const MEERA_LABEL = 'Meera Rao (@meera)';
const RAVI_LABEL = 'Ravi Kumar (@ravi)';

interface Captured {
  body: Record<string, unknown> | null;
  key: string | null;
  calls: number;
}

/** POST /groups/{id}/expenses answering with `saved`; GET of the expense serves it afterwards. */
function serveCreate(saved: GroupExpenseDetail): Captured {
  const captured: Captured = { body: null, key: null, calls: 0 };
  server.use(
    http.post(`${API}/groups/:id/expenses`, async ({ request }) => {
      captured.calls += 1;
      captured.body = (await request.json()) as Record<string, unknown>;
      captured.key = request.headers.get('Idempotency-Key');
      return HttpResponse.json(envelope(saved), { status: 201 });
    }),
    http.get(`${API}/groups/:id/expenses/:expenseId`, () => HttpResponse.json(envelope(saved))),
  );
  return captured;
}

async function openCreate() {
  serveMoneyGroup();
  const user = userEvent.setup();
  const view = renderRoute(NEW, { user: signedIn() });
  await findPageHeading('Add a shared expense');
  await user.type(await screen.findByLabelText('Description'), 'Dinner');
  return { user, ...view };
}

function sharesTable() {
  return screen.findByRole('table', { name: 'Each person’s share and what they paid' });
}

describe('GroupExpenseCreatePage', () => {
  it('adds an equal split with an Idempotency-Key and shows the shares the server worked out', async () => {
    const captured = serveCreate(makeExpenseDetail());
    const { user, router } = await openCreate();
    await user.type(screen.getByLabelText('Amount'), '100');
    expect(screen.getByText('Split equally between 3 people.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(captured.key).toMatch(/^web-[0-9a-f-]{36}$/);
    expect(captured.body).toEqual({
      description: 'Dinner',
      amount: '100.00',
      expense_date: todayInTimeZone('Asia/Kolkata'),
      split_method: 'equal',
      participants: [{ user_id: ME }, { user_id: MEERA }, { user_id: RAVI }],
      payers: [{ user_id: ME }],
    });
    expect(await screen.findByText('Saved')).toBeInTheDocument();
    expect(
      screen.getByText(
        'These are the exact shares Montra worked out. Everyone in the group sees the same amounts.',
      ),
    ).toBeInTheDocument();
    const table = await sharesTable();
    // The remainder paisa went to the first person: shown exactly as the server sent it.
    expect(
      within(within(table).getByRole('row', { name: /^You/ })).getByText('₹33.34'),
    ).toBeInTheDocument();
    expect(
      within(within(table).getByRole('row', { name: /^Meera Rao/ })).getByText('₹33.33'),
    ).toBeInTheDocument();
    expect(await screen.findByText('Expense added')).toBeInTheDocument();
  });

  it('guides exact amounts with exact decimals and blocks a split that does not add up', async () => {
    const captured = serveCreate(
      makeExpenseDetail({
        amount: money('50.00'),
        split_method: 'exact',
        shares: [
          { user_id: ME, share: money('20.00'), input_value: '20.00' },
          { user_id: MEERA, share: money('30.00'), input_value: '30.00' },
        ],
        payers: [{ user_id: ME, paid: money('50.00') }],
      }),
    );
    const { user, router } = await openCreate();
    await user.type(screen.getByLabelText('Amount'), '50');
    await user.click(screen.getByRole('radio', { name: 'Exact amounts' }));
    await user.click(screen.getByRole('checkbox', { name: RAVI_LABEL }));
    await user.type(screen.getByLabelText(`Amount for ${ME_LABEL}`), '20');
    expect(screen.getByText('₹30.00 left to assign.')).toBeInTheDocument();
    await user.type(screen.getByLabelText(`Amount for ${MEERA_LABEL}`), '20');
    expect(screen.getByText('₹10.00 left to assign.')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    expect(
      await screen.findByText('The amounts add up to ₹40.00; they need to add up to ₹50.00.'),
    ).toBeInTheDocument();
    expect(screen.getByText('Check the highlighted fields.')).toBeInTheDocument();
    expect(captured.calls).toBe(0);

    await user.clear(screen.getByLabelText(`Amount for ${MEERA_LABEL}`));
    await user.type(screen.getByLabelText(`Amount for ${MEERA_LABEL}`), '30');
    expect(screen.getByText('Adds up to the total.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(captured.body).toMatchObject({
      amount: '50.00',
      split_method: 'exact',
      participants: [
        { user_id: ME, value: '20.00' },
        { user_id: MEERA, value: '30.00' },
      ],
    });
    const table = await sharesTable();
    expect(within(table).getByRole('columnheader', { name: 'Entered as' })).toBeInTheDocument();
    expect(
      within(within(table).getByRole('row', { name: /^Meera Rao/ })).getAllByText('₹30.00'),
    ).toHaveLength(2);
  });

  it('validates percentages to exactly 100% and shows the server’s rounding', async () => {
    const captured = serveCreate(
      makeExpenseDetail({
        amount: money('999.99'),
        split_method: 'percentage',
        shares: [
          { user_id: ME, share: money('333.30'), input_value: '33.33' },
          { user_id: MEERA, share: money('333.30'), input_value: '33.33' },
          { user_id: RAVI, share: money('333.39'), input_value: '33.34' },
        ],
        payers: [{ user_id: ME, paid: money('999.99') }],
      }),
    );
    const { user, router } = await openCreate();
    await user.type(screen.getByLabelText('Amount'), '999.99');
    await user.click(screen.getByRole('radio', { name: 'Percentages' }));
    await user.type(screen.getByLabelText(`Percent for ${ME_LABEL}`), '33.33');
    await user.type(screen.getByLabelText(`Percent for ${MEERA_LABEL}`), '33.333');
    await user.type(screen.getByLabelText(`Percent for ${RAVI_LABEL}`), '33.33');
    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    expect(screen.getByLabelText(`Percent for ${MEERA_LABEL}`)).toHaveAccessibleDescription(
      /Enter a percentage like 25 or 33.33./,
    );

    await user.clear(screen.getByLabelText(`Percent for ${MEERA_LABEL}`));
    await user.type(screen.getByLabelText(`Percent for ${MEERA_LABEL}`), '33.33');
    expect(screen.getByText('0.01% left to assign.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    expect(
      await screen.findByText('The percentages add up to 99.99%; they need to add up to 100%.'),
    ).toBeInTheDocument();
    await user.clear(screen.getByLabelText(`Percent for ${RAVI_LABEL}`));
    await user.type(screen.getByLabelText(`Percent for ${RAVI_LABEL}`), '33.34');
    expect(screen.getByText('Adds up to 100%.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(captured.body).toMatchObject({
      split_method: 'percentage',
      participants: [
        { user_id: ME, value: '33.33' },
        { user_id: MEERA, value: '33.33' },
        { user_id: RAVI, value: '33.34' },
      ],
    });
    const ravi = within(await sharesTable()).getByRole('row', { name: /^Ravi Kumar/ });
    expect(within(ravi).getByText('33.34%')).toBeInTheDocument();
    expect(within(ravi).getByText('₹333.39')).toBeInTheDocument();
  });

  it('splits by shares with several payers and records my payment in my account', async () => {
    testBackend.accounts = [makeAccount()];
    const captured = serveCreate(
      makeExpenseDetail({
        description: 'Electricity',
        amount: money('1000.00'),
        split_method: 'shares',
        shares: [
          { user_id: ME, share: money('500.00'), input_value: '2' },
          { user_id: MEERA, share: money('250.00'), input_value: '1' },
          { user_id: RAVI, share: money('250.00'), input_value: '1' },
        ],
        payers: [
          { user_id: ME, paid: money('600.00') },
          { user_id: MEERA, paid: money('400.00') },
        ],
        my_paid: money('600.00'),
        my_share: money('500.00'),
        my_transaction_id: '77777777-7777-4777-8777-777777777799',
      }),
    );
    const { user, router } = await openCreate();
    await user.type(screen.getByLabelText('Amount'), '1000');
    await user.click(screen.getByRole('radio', { name: 'Shares' }));
    await user.type(screen.getByLabelText(`Shares for ${ME_LABEL}`), '2');
    await user.type(screen.getByLabelText(`Shares for ${MEERA_LABEL}`), '1');
    await user.type(screen.getByLabelText(`Shares for ${RAVI_LABEL}`), '1');
    expect(
      screen.getByText('4 shares in total. Each person pays in proportion to their shares.'),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('radio', { name: 'Several people' }));
    await user.type(screen.getByLabelText(/^Paid by You \(Asha Rao\)/), '600');
    expect(screen.getByText('₹400.00 left to assign.')).toBeInTheDocument();
    await user.type(screen.getByLabelText(/^Paid by Meera Rao/), '500');
    expect(screen.getByText('₹100.00 more than the total.')).toBeInTheDocument();
    await user.clear(screen.getByLabelText(/^Paid by Meera Rao/));
    await user.type(screen.getByLabelText(/^Paid by Meera Rao/), '400');
    expect(screen.getAllByText('Adds up to the total.')).toHaveLength(1);
    await user.selectOptions(await screen.findByLabelText(/^Record my payment in/), ACCOUNT_CASH);
    await user.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(captured.body).toMatchObject({
      amount: '1000.00',
      split_method: 'shares',
      participants: [
        { user_id: ME, value: '2' },
        { user_id: MEERA, value: '1' },
        { user_id: RAVI, value: '1' },
      ],
      payers: [
        { user_id: ME, amount: '600.00' },
        { user_id: MEERA, amount: '400.00' },
      ],
      payer_account_id: ACCOUNT_CASH,
    });
    const table = await sharesTable();
    const meera = within(table).getByRole('row', { name: /^Meera Rao/ });
    expect(within(meera).getByText('1 share')).toBeInTheDocument();
    expect(within(meera).getByText('₹400.00')).toBeInTheDocument();
    expect(
      screen.getByText('Recorded in your account. It updates when the expense changes.'),
    ).toBeInTheDocument();
  });

  it('splits by item with tax shared in proportion', async () => {
    const captured = serveCreate(
      makeExpenseDetail({
        amount: money('880.00'),
        split_method: 'itemized',
        shares: [
          { user_id: ME, share: money('330.00') },
          { user_id: MEERA, share: money('330.00') },
          { user_id: RAVI, share: money('220.00') },
        ],
        payers: [{ user_id: ME, paid: money('880.00') }],
        items: [
          {
            description: 'Pizza',
            amount: money('600.00'),
            shares: [
              { user_id: ME, share: money('300.00'), input_value: '1' },
              { user_id: MEERA, share: money('300.00'), input_value: '1' },
            ],
          },
          {
            description: 'Drinks',
            amount: money('200.00'),
            quantity: '2.000',
            shares: [{ user_id: RAVI, share: money('200.00'), input_value: '1' }],
          },
        ],
      }),
    );
    const { user, router } = await openCreate();
    await user.type(screen.getByLabelText('Amount'), '880');
    await user.click(screen.getByRole('radio', { name: 'By item' }));

    const first = screen.getByRole('group', { name: 'Item 1' });
    await user.type(within(first).getByLabelText('Item'), 'Pizza');
    await user.type(within(first).getByLabelText('Item amount'), '600');
    await user.click(within(first).getByRole('checkbox', { name: ME_LABEL }));
    await user.click(within(first).getByRole('checkbox', { name: MEERA_LABEL }));
    await user.click(screen.getByRole('button', { name: 'Add an item' }));
    const second = screen.getByRole('group', { name: 'Item 2' });
    await user.type(within(second).getByLabelText('Item'), 'Drinks');
    await user.type(within(second).getByLabelText('Item amount'), '200');
    await user.type(within(second).getByLabelText(/^Quantity/), '2');
    expect(
      screen.getByText(
        'Items: ₹800.00. The other ₹80.00 (tax, tip or service) is shared in proportion to each person’s items.',
      ),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    expect(within(second).getByRole('group', { name: 'Shared by' })).toHaveAccessibleDescription(
      /Choose who shared this item./,
    );
    await user.click(within(second).getByRole('checkbox', { name: RAVI_LABEL }));
    await user.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(captured.body).toMatchObject({
      amount: '880.00',
      split_method: 'itemized',
      participants: [{ user_id: ME }, { user_id: MEERA }, { user_id: RAVI }],
      items: [
        {
          description: 'Pizza',
          amount: '600.00',
          shared_by: [{ user_id: ME }, { user_id: MEERA }],
        },
        { description: 'Drinks', amount: '200.00', quantity: '2', shared_by: [{ user_id: RAVI }] },
      ],
    });
    const items = await screen.findByRole('region', { name: 'Items' });
    expect(within(items).getByText('× 2')).toBeInTheDocument();
    expect(within(await sharesTable()).getAllByText('₹330.00')).toHaveLength(2);
  });

  it('asks the server for Montra’s rate and lets it work out the amount', async () => {
    const captured = serveCreate(
      makeExpenseDetail({
        description: 'Airport taxi',
        amount: money('8325.00'),
        original_amount: money('100.00', 'USD'),
        fx_rate: '83.25',
        fx_rate_source: 'ecb',
        fx_rate_at: '2026-11-04T16:00:00Z',
        payers: [{ user_id: ME, paid: money('8325.00') }],
        shares: [
          { user_id: ME, share: money('2775.00') },
          { user_id: MEERA, share: money('2775.00') },
          { user_id: RAVI, share: money('2775.00') },
        ],
      }),
    );
    const lookups: string[] = [];
    server.use(
      http.get(`${API}/fx/convert`, ({ request }) => {
        lookups.push(new URL(request.url).search);
        return HttpResponse.json(
          envelope({
            from: money('100.00', 'USD'),
            to: money('8325.00'),
            rate: {
              base: 'USD',
              quote: 'INR',
              rate: '83.25',
              source: 'ecb',
              as_of: '2026-11-04T16:00:00Z',
              inverted: false,
            },
            policy: 'historical',
            rounding_delta: '0',
          }),
        );
      }),
    );
    const { user, router } = await openCreate();
    await user.click(screen.getByRole('checkbox', { name: /Paid in another currency/ }));
    expect(screen.queryByLabelText('Amount')).not.toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Currency paid in'), 'USD');
    await user.type(screen.getByLabelText('Amount paid'), '100');
    expect(
      await screen.findByText(
        /^Montra’s rate for .*: 1 USD = 83.25 INR \(European Central Bank\)\.$/,
      ),
    ).toBeInTheDocument();
    // Only the server's conversion is shown; nothing is multiplied here.
    expect(
      screen.getByText('$100.00 will be saved as ₹8,325.00 at Montra’s rate.'),
    ).toBeInTheDocument();
    expect(screen.getByText('Split equally between 3 people.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(lookups[0]).toContain('amount=100.00');
    expect(lookups[0]).toContain('from=USD');
    expect(lookups[0]).toContain('to=INR');
    expect(lookups[0]).toContain('policy=historical');
    // The server looks the rate up and derives the amount, also the payer's.
    expect(captured.body).toEqual({
      description: 'Dinner',
      expense_date: todayInTimeZone('Asia/Kolkata'),
      split_method: 'equal',
      participants: [{ user_id: ME }, { user_id: MEERA }, { user_id: RAVI }],
      payers: [{ user_id: ME }],
      original_amount: '100.00',
      original_currency: 'USD',
      fx_rate_source: 'lookup',
    });
    // The rate the server stored is shown with the expense, with its source and time.
    expect(await screen.findByText('Rate used: 1 USD = 83.25 INR')).toBeInTheDocument();
    expect(screen.getByText(/^Montra’s rate \(European Central Bank\), from /)).toBeInTheDocument();
  });

  it('lets you enter the rate you paid when Montra has none and sends it as yours', async () => {
    const captured = serveCreate(
      makeExpenseDetail({
        amount: money('8325.70'),
        original_amount: money('100.00', 'USD'),
        fx_rate: '83.257',
        fx_rate_source: 'manual',
        fx_rate_at: '2026-11-05T10:00:00Z',
        payers: [{ user_id: MEERA, paid: money('8325.70') }],
        my_paid: money('0.00'),
      }),
    );
    server.use(
      http.get(`${API}/fx/convert`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    const { user, router } = await openCreate();
    await user.click(screen.getByRole('checkbox', { name: /Paid in another currency/ }));
    await user.selectOptions(screen.getByLabelText('Currency paid in'), 'USD');
    await user.type(screen.getByLabelText('Amount paid'), '100');
    expect(
      await screen.findByText(
        'Montra has no USD to INR rate for this date. Enter the rate you paid instead.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Add a rate in Exchange rates' })).toHaveAttribute(
      'href',
      '/settings/exchange-rates',
    );
    // Montra has no rate: saving with it is refused before anything is sent.
    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    expect(captured.calls).toBe(0);

    await user.click(screen.getByRole('button', { name: 'Enter the rate I paid' }));
    await user.type(screen.getByLabelText('INR for 1 USD'), '83.257');
    expect(
      screen.getByText('Montra works out the amount in INR from your rate when you save.'),
    ).toBeInTheDocument();
    expect(screen.queryByText(/8,325/)).not.toBeInTheDocument();
    // Someone else paid everything: sent without an amount, which the server derives.
    await user.selectOptions(screen.getByLabelText('Paid by'), MEERA);
    await user.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(captured.body).toMatchObject({
      original_amount: '100.00',
      original_currency: 'USD',
      fx_rate: '83.257',
      fx_rate_source: 'manual',
      payers: [{ user_id: MEERA }],
    });
    expect(captured.body).not.toHaveProperty('amount');
    expect(await screen.findByText('Rate used: 1 USD = 83.257 INR')).toBeInTheDocument();
    expect(screen.getByText(/^a member’s rate, from /)).toBeInTheDocument();
  });

  it('shows the server’s coded “rounds to zero” refusal on the amount paid', async () => {
    server.use(
      http.get(`${API}/fx/convert`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
      http.post(`${API}/groups/:id/expenses`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.original_amount',
                code: 'converted_too_small',
                message: 'The converted amount is less than the smallest unit of INR.',
                params: { currency: 'INR' },
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const { user } = await openCreate();
    await user.click(screen.getByRole('checkbox', { name: /Paid in another currency/ }));
    await user.selectOptions(screen.getByLabelText('Currency paid in'), 'USD');
    await user.type(screen.getByLabelText('Amount paid'), '0.01');
    await user.click(await screen.findByRole('button', { name: 'Enter the rate I paid' }));
    await user.type(screen.getByLabelText('INR for 1 USD'), '0.0001');
    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    expect(
      await screen.findAllByText('With this rate the amount in INR is zero. Check the rate.'),
    ).not.toHaveLength(0);
  });

  it('explains when the server has no rate for the date and keeps your own rate available', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/fx/convert`, () =>
        HttpResponse.json(
          envelope({
            from: money('100.00', 'USD'),
            to: money('8325.00'),
            rate: {
              base: 'USD',
              quote: 'INR',
              rate: '83.25',
              source: 'provider',
              as_of: '2026-11-04T16:00:00Z',
              inverted: false,
            },
            policy: 'historical',
            rounding_delta: '0',
          }),
        ),
      ),
      http.post(`${API}/groups/:id/expenses`, () => {
        calls += 1;
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: 'Montra has no USD→INR rate for this date; enter the rate you used.',
                code: 'fx_rate_unavailable',
                params: { from: 'USD', to: 'INR', date: '2026-11-04' },
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const { user } = await openCreate();
    await user.click(screen.getByRole('checkbox', { name: /Paid in another currency/ }));
    await user.selectOptions(screen.getByLabelText('Currency paid in'), 'USD');
    await user.type(screen.getByLabelText('Amount paid'), '100');
    await screen.findByText(/^Montra’s rate for /);
    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    // Shown as the form summary and next to the rate choice.
    expect(
      await screen.findAllByText(
        'Montra has no USD to INR rate for Nov 4, 2026. Enter the rate you paid instead.',
      ),
    ).toHaveLength(2);
    expect(calls).toBe(1);
    expect(screen.getByRole('radio', { name: /^The rate I paid/ })).toBeInTheDocument();
  });

  it('shows the server’s split and field errors and keeps the same key for the retry', async () => {
    const keys: (string | null)[] = [];
    let calls = 0;
    server.use(
      http.post(`${API}/groups/:id/expenses`, ({ request }) => {
        calls += 1;
        keys.push(request.headers.get('Idempotency-Key'));
        if (calls === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'DOMAIN_RULE_VIOLATION',
              details: [{ message: 'The split does not add up.', code: 'split_mismatch' }],
            }),
            { status: 422 },
          );
        }
        return HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.participants[1].value',
                message: 'Enter each person’s amount in INR.',
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const { user } = await openCreate();
    await user.type(screen.getByLabelText('Amount'), '50');
    await user.click(screen.getByRole('radio', { name: 'Exact amounts' }));
    await user.click(screen.getByRole('checkbox', { name: MEERA_LABEL }));
    await user.type(screen.getByLabelText(`Amount for ${ME_LABEL}`), '25');
    await user.type(screen.getByLabelText(`Amount for ${RAVI_LABEL}`), '25');
    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    expect(
      await screen.findAllByText(
        'The split doesn’t add up to the total. Check each person’s amount, percentage or shares.',
      ),
    ).toHaveLength(2);

    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    await waitFor(() => {
      // participants[1] is Ravi: Meera was not sent.
      expect(screen.getByLabelText(`Amount for ${RAVI_LABEL}`)).toHaveAccessibleDescription(
        /Enter each person’s amount in INR./,
      );
    });
    expect(keys).toHaveLength(2);
    expect(keys[0]).toBe(keys[1]);
  });

  it('uploads an attachment to the group before saving', async () => {
    const captured = serveCreate(makeExpenseDetail({ receipt_file_id: FILE_ID }));
    let intent: unknown = null;
    const fileRecord = (status: string) => ({
      id: FILE_ID,
      purpose: 'group_attachment',
      status,
      group_id: MONEY_GROUP,
      original_filename: 'bill.png',
      created_at: '2026-11-05T08:00:00Z',
    });
    server.use(
      http.post(`${API}/files/upload-intent`, async ({ request }) => {
        intent = await request.json();
        return HttpResponse.json(
          envelope({
            file: fileRecord('pending_upload'),
            upload_url: `http://localhost:8080/api/v1/files/${FILE_ID}/content`,
            method: 'PUT',
            headers: { 'X-Upload-Token': 'tok-1' },
            expires_at: '2026-11-05T08:15:00Z',
            max_bytes: 15728640,
          }),
          { status: 201 },
        );
      }),
      http.put(`${API}/files/${FILE_ID}/content`, () =>
        HttpResponse.json(envelope(fileRecord('uploaded'))),
      ),
      http.post(`${API}/files/${FILE_ID}/complete`, () =>
        HttpResponse.json(envelope(fileRecord('ready'))),
      ),
    );
    const { user, router } = await openCreate();
    await user.type(screen.getByLabelText('Amount'), '100');
    const file = new File([new Uint8Array([137, 80, 78, 71, 1, 2])], 'bill.png', {
      type: 'image/png',
    });
    await user.upload(screen.getByLabelText(/^Receipt or photo/), file);
    expect(screen.getByText('bill.png')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(intent).toMatchObject({ purpose: 'group_attachment', group_id: MONEY_GROUP });
    expect(captured.body).toMatchObject({ receipt_file_id: FILE_ID });
    expect(await screen.findByRole('button', { name: 'Open attachment' })).toBeInTheDocument();
  });
});

describe('GroupExpenseEditPage', () => {
  it('sends the whole expense with its version and reloads after a version conflict', async () => {
    serveMoneyGroup();
    let current = makeExpenseDetail({ notes: 'Weekly shop', receipt_file_id: FILE_ID });
    const bodies: Record<string, unknown>[] = [];
    server.use(
      http.get(`${API}/groups/:id/expenses/:expenseId`, () => HttpResponse.json(envelope(current))),
      http.patch(`${API}/groups/:id/expenses/:expenseId`, async ({ request }) => {
        const body = (await request.json()) as Record<string, unknown>;
        bodies.push(body);
        if (body.version !== current.version) {
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        current = makeExpenseDetail({
          ...current,
          description: String(body.description),
          version: current.version + 1,
          revisions: current.revisions + 1,
        });
        return HttpResponse.json(envelope(current));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`${DETAIL}/edit`, { user: signedIn() });
    await findPageHeading('Edit expense');
    const description = await screen.findByLabelText('Description');
    expect(description).toHaveValue('Groceries');
    expect(screen.getByLabelText('Amount')).toHaveValue('100.00');

    // Someone else saves first.
    current = makeExpenseDetail({ ...current, description: 'Groceries and milk', version: 2 });
    await user.clear(description);
    await user.type(description, 'Groceries (week 45)');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.getByLabelText('Description')).toHaveValue('Groceries and milk');
    });
    expect(bodies[0]).toEqual({
      description: 'Groceries (week 45)',
      amount: '100.00',
      expense_date: '2026-11-04',
      split_method: 'equal',
      category_key: 'groceries',
      notes: 'Weekly shop',
      participants: [{ user_id: ME }, { user_id: MEERA }, { user_id: RAVI }],
      payers: [{ user_id: ME }],
      receipt_file_id: FILE_ID,
      version: 1,
    });

    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(bodies[1]).toMatchObject({ description: 'Groceries and milk', version: 2 });
    expect(await screen.findByText('Expense updated')).toBeInTheDocument();
  });

  it('keeps the saved rate of a foreign-currency expense unless another choice is made', async () => {
    serveMoneyGroup();
    const current = makeExpenseDetail({
      description: 'Airport taxi',
      amount: money('8325.00'),
      original_amount: money('100.00', 'USD'),
      fx_rate: '83.25',
      fx_rate_source: 'provider',
      fx_rate_at: '2026-11-04T16:00:00Z',
      payers: [{ user_id: ME, paid: money('8325.00') }],
      shares: [
        { user_id: ME, share: money('2775.00') },
        { user_id: MEERA, share: money('2775.00') },
        { user_id: RAVI, share: money('2775.00') },
      ],
    });
    const bodies: Record<string, unknown>[] = [];
    server.use(
      http.get(`${API}/groups/:id/expenses/:expenseId`, () => HttpResponse.json(envelope(current))),
      http.patch(`${API}/groups/:id/expenses/:expenseId`, async ({ request }) => {
        bodies.push((await request.json()) as Record<string, unknown>);
        return HttpResponse.json(envelope({ ...current, version: 2 }));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`${DETAIL}/edit`, { user: signedIn() });
    await findPageHeading('Edit expense');
    const keep = await screen.findByRole('radio', { name: /^Keep the saved rate/ });
    expect(keep).toBeChecked();
    expect(
      screen.getByText('1 USD = 83.25 INR (Montra’s rate (rate provider))'),
    ).toBeInTheDocument();
    expect(screen.getByText('Saved as ₹8,325.00.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(DETAIL);
    });
    expect(bodies[0]).toEqual({
      description: 'Airport taxi',
      expense_date: '2026-11-04',
      split_method: 'equal',
      category_key: 'groceries',
      participants: [{ user_id: ME }, { user_id: MEERA }, { user_id: RAVI }],
      payers: [{ user_id: ME }],
      original_amount: '100.00',
      original_currency: 'USD',
      fx_rate: '83.25',
      fx_rate_source: 'provider',
      version: 1,
    });
  });

  it('shows the current state when the expense was deleted meanwhile', async () => {
    serveMoneyGroup();
    let current = makeExpenseDetail();
    server.use(
      http.get(`${API}/groups/:id/expenses/:expenseId`, () => HttpResponse.json(envelope(current))),
      http.patch(`${API}/groups/:id/expenses/:expenseId`, () => {
        current = makeExpenseDetail({ status: 'deleted', version: 2 });
        return HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [{ message: 'This expense was deleted.', code: 'expense_deleted' }],
          }),
          { status: 409 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`${DETAIL}/edit`, { user: signedIn() });
    await findPageHeading('Edit expense');
    await screen.findByLabelText('Description');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('This expense was deleted')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Save changes' })).not.toBeInTheDocument();
  });

  it('does not offer editing a deleted expense', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/expenses/:expenseId`, () =>
        HttpResponse.json(envelope(makeExpenseDetail({ status: 'deleted' }))),
      ),
    );
    renderRoute(`${DETAIL}/edit`, { user: signedIn() });
    await findPageHeading('Edit expense');
    expect(await screen.findByText('This expense was deleted')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Save changes' })).not.toBeInTheDocument();
  });
});
