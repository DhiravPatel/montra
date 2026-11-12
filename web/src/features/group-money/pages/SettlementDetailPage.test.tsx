import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { ACCOUNT_CASH, makeAccount, money } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ME,
  MEERA,
  MONEY_GROUP,
  RAVI,
  SETTLEMENT_2,
  SETTLEMENT_ID,
  makeGroupWithFormerMember,
  makeMoneyGroup,
  makeSettlement,
  serveMoneyGroup,
} from '@/tests/groupMoneyFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import type { Settlement } from '../types';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const PATH = `/groups/${MONEY_GROUP}/settlements/${SETTLEMENT_ID}`;

interface ActionCall {
  action: string;
  body: Record<string, unknown>;
}

/** Serves the settlement and answers lifecycle actions with `next(action, current)`. */
function serveSettlement(
  initial: Settlement,
  next?: (action: string, current: Settlement, body: Record<string, unknown>) => Settlement,
) {
  const state = { current: initial, calls: [] as ActionCall[], reads: 0 };
  server.use(
    http.get(`${API}/groups/:id/settlements/:settlementId`, ({ params }) => {
      state.reads += 1;
      return params.settlementId === state.current.id
        ? HttpResponse.json(envelope(state.current))
        : HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
    }),
    http.post(
      `${API}/groups/:id/settlements/:settlementId/:action`,
      async ({ params, request }) => {
        const action = String(params.action);
        const body = (await request.json()) as Record<string, unknown>;
        state.calls.push({ action, body });
        if (!next) return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        state.current = next(action, state.current, body);
        return HttpResponse.json(envelope(state.current));
      },
    ),
  );
  return state;
}

describe('SettlementDetailPage', () => {
  it('shows both sides and lets the payee confirm, recording it in an account', async () => {
    serveMoneyGroup();
    testBackend.accounts = [makeAccount()];
    const state = serveSettlement(makeSettlement(), (_action, current) => ({
      ...current,
      status: 'confirmed',
      counted: true,
      confirmed_by: ME,
      confirmed_at: '2026-11-05T12:00:00Z',
      my_transaction_id: '77777777-7777-4777-8777-777777777777',
      version: current.version + 1,
    }));
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    expect(await screen.findByText('Meera Rao paid you')).toBeInTheDocument();
    expect(screen.getByText('Paid, waiting for confirmation')).toBeInTheDocument();
    expect(screen.getByText('Not counted yet')).toBeInTheDocument();
    const sides = screen.getByRole('region', { name: 'Both sides' });
    expect(within(sides).getByText('Paying: Meera Rao')).toBeInTheDocument();
    expect(within(sides).getByText(/^Reported paying on/)).toBeInTheDocument();
    expect(within(sides).getByText('Receiving: You')).toBeInTheDocument();
    expect(within(sides).getByText('Hasn’t confirmed it yet')).toBeInTheDocument();
    expect(
      screen.getByText('Reported by members. Montra didn’t verify or move this money.'),
    ).toBeInTheDocument();
    // The payer marks paid; the payee confirms.
    expect(screen.queryByRole('button', { name: 'Mark as paid' })).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Confirm I received it' }));
    const dialog = await screen.findByRole('dialog', { name: 'Confirm you received it?' });
    expect(
      within(dialog).getByText(/Confirm you received ₹300.00 from Meera Rao/),
    ).toBeInTheDocument();
    await user.selectOptions(
      await within(dialog).findByLabelText(/^Also record it in my account/),
      ACCOUNT_CASH,
    );
    await user.click(within(dialog).getByRole('button', { name: 'Confirm' }));

    expect(await screen.findByText('Payment confirmed')).toBeInTheDocument();
    expect(state.calls).toEqual([
      { action: 'confirm', body: { version: 1, account_id: ACCOUNT_CASH } },
    ]);
    expect(await within(sides).findByText(/^Confirmed receiving it on/)).toBeInTheDocument();
    expect(screen.getByText('Counts toward balances')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'View in my transactions' })).toHaveAttribute(
      'href',
      '/transactions/77777777-7777-4777-8777-777777777777',
    );
  });

  it('disputes a confirmed payment with a reason', async () => {
    serveMoneyGroup();
    const state = serveSettlement(
      makeSettlement({ status: 'confirmed', counted: true, version: 2 }),
      (_action, current, body) => ({
        ...current,
        status: 'disputed',
        counted: false,
        dispute_reason: String(body.reason),
        version: current.version + 1,
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    await user.click(await screen.findByRole('button', { name: 'Dispute' }));
    const dialog = await screen.findByRole('dialog', { name: 'Dispute this payment?' });
    await user.click(within(dialog).getByRole('button', { name: 'Dispute payment' }));
    expect(within(dialog).getByLabelText('What’s wrong?')).toHaveAccessibleDescription(
      /Say what’s wrong./,
    );
    expect(state.calls).toHaveLength(0);
    await user.type(within(dialog).getByLabelText('What’s wrong?'), 'Only got 250');
    await user.click(within(dialog).getByRole('button', { name: 'Dispute payment' }));

    expect(await screen.findByText('Payment disputed')).toBeInTheDocument();
    expect(state.calls).toEqual([
      { action: 'dispute', body: { version: 2, reason: 'Only got 250' } },
    ]);
    expect(await screen.findByText('Disputed: Only got 250')).toBeInTheDocument();
  });

  it('corrects a payment with an Idempotency-Key and opens the new record', async () => {
    serveMoneyGroup();
    serveSettlement(makeSettlement({ status: 'disputed', dispute_reason: 'Only got 250' }));
    let body: unknown = null;
    let key: string | null = null;
    const corrected = makeSettlement({
      id: SETTLEMENT_2,
      amount: money('250.00'),
      corrects_settlement_id: SETTLEMENT_ID,
      status: 'confirmed',
      counted: true,
    });
    server.use(
      http.post(`${API}/groups/:id/settlements/:settlementId/correct`, async ({ request }) => {
        body = await request.json();
        key = request.headers.get('Idempotency-Key');
        return HttpResponse.json(envelope(corrected), { status: 201 });
      }),
      http.get(`${API}/groups/:id/settlements/${SETTLEMENT_2}`, () =>
        HttpResponse.json(envelope(corrected)),
      ),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    await user.click(await screen.findByRole('button', { name: 'Correct' }));
    const dialog = await screen.findByRole('dialog', { name: 'Correct this payment' });
    expect(
      within(dialog).getByText(
        'The original payment is voided and kept in the history, and this one replaces it.',
      ),
    ).toBeInTheDocument();
    const amount = within(dialog).getByLabelText('Amount');
    expect(amount).toHaveValue('300.00');
    await user.clear(amount);
    await user.type(amount, '250');
    await user.click(within(dialog).getByRole('button', { name: 'Save correction' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(
        `/groups/${MONEY_GROUP}/settlements/${SETTLEMENT_2}`,
      );
    });
    expect(key).toMatch(/^web-/);
    expect(body).toMatchObject({
      payer_user_id: MEERA,
      payee_user_id: ME,
      amount: '250.00',
      method: 'upi',
      state: 'paid',
      settled_on: '2026-11-05',
    });
    expect(await screen.findByText('Correction saved')).toBeInTheDocument();
    expect(await screen.findByRole('link', { name: 'View the original payment' })).toHaveAttribute(
      'href',
      PATH,
    );
  });

  it('voids only after a confirmation with a reason', async () => {
    serveMoneyGroup();
    const state = serveSettlement(makeSettlement(), (_action, current, body) => ({
      ...current,
      status: 'voided',
      counted: false,
      void_reason: String(body.reason),
      voided_by: ME,
      version: current.version + 1,
    }));
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    await user.click(await screen.findByRole('button', { name: 'Void' }));
    const dialog = await screen.findByRole('dialog', { name: 'Void this payment?' });
    expect(within(dialog).getByText(/This can’t be undone./)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Void payment' }));
    expect(within(dialog).getByLabelText('Reason')).toHaveAccessibleDescription(
      /Give a reason for voiding it./,
    );
    await user.type(within(dialog).getByLabelText('Reason'), 'Paid in cash instead');
    await user.click(within(dialog).getByRole('button', { name: 'Void payment' }));

    expect(await screen.findByText('Payment voided')).toBeInTheDocument();
    expect(state.calls).toEqual([
      { action: 'void', body: { version: 1, reason: 'Paid in cash instead' } },
    ]);
    expect(await screen.findByText('This payment was voided')).toBeInTheDocument();
    expect(
      screen.getByText('It no longer counts toward balances. Reason: Paid in cash instead'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Void' })).not.toBeInTheDocument();
  });

  it('lets the payer mark a planned payment paid, then record and unlink it', async () => {
    serveMoneyGroup();
    testBackend.accounts = [makeAccount()];
    const state = serveSettlement(
      makeSettlement({
        payer_user_id: ME,
        payer_name: 'Asha Rao',
        payee_user_id: RAVI,
        payee_name: 'Ravi Kumar',
        status: 'proposed',
        proposed_by: ME,
      }),
      (action, current) => {
        if (action === 'mark-paid') {
          return { ...current, status: 'user_reported_paid', version: current.version + 1 };
        }
        if (action === 'record') {
          return { ...current, my_transaction_id: '77777777-7777-4777-8777-777777777702' };
        }
        const rest = { ...current };
        delete rest.my_transaction_id;
        return rest;
      },
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    expect(await screen.findByText('You plan to pay Ravi Kumar')).toBeInTheDocument();
    expect(screen.getByText('Planned, not paid yet')).toBeInTheDocument();
    expect(
      screen.getByText('You can record it in your account once it’s marked paid.'),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Mark as paid' }));
    const markDialog = await screen.findByRole('dialog', {
      name: 'Mark this payment as paid?',
    });
    await user.click(within(markDialog).getByRole('button', { name: 'Mark paid' }));
    expect(await screen.findByText('Marked as paid')).toBeInTheDocument();

    await user.click(await screen.findByRole('button', { name: 'Record in my account' }));
    const recordDialog = await screen.findByRole('dialog', { name: 'Record it in your account?' });
    await user.click(within(recordDialog).getByRole('button', { name: 'Record in my account' }));
    expect(await within(recordDialog).findByLabelText('Account')).toHaveAccessibleDescription(
      /Choose an account./,
    );
    await user.selectOptions(within(recordDialog).getByLabelText('Account'), ACCOUNT_CASH);
    await user.click(within(recordDialog).getByRole('button', { name: 'Record in my account' }));
    expect(
      await screen.findByText('Recorded in your account', { selector: 'p' }),
    ).toBeInTheDocument();

    await user.click(await screen.findByRole('button', { name: 'Remove from my account' }));
    const unlink = await screen.findByRole('dialog', { name: 'Remove your account record?' });
    await user.click(within(unlink).getByRole('button', { name: 'Remove record' }));
    expect(await screen.findByText('Account record removed')).toBeInTheDocument();

    expect(state.calls).toEqual([
      { action: 'mark-paid', body: { version: 1 } },
      { action: 'record', body: { version: 2, account_id: ACCOUNT_CASH } },
      { action: 'unlink', body: { version: 2 } },
    ]);
  });

  it('reloads after a version conflict and says so', async () => {
    serveMoneyGroup();
    const state = serveSettlement(makeSettlement());
    server.use(
      http.post(`${API}/groups/:id/settlements/:settlementId/confirm`, () => {
        state.current = makeSettlement({ version: 2, note: 'Sent on GPay' });
        return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    await user.click(await screen.findByRole('button', { name: 'Confirm I received it' }));
    await user.click(
      within(await screen.findByRole('dialog')).getByRole('button', { name: 'Confirm' }),
    );
    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    expect(await screen.findByText('Sent on GPay')).toBeInTheDocument();
    expect(state.reads).toBeGreaterThanOrEqual(2);
  });

  it('explains a coded state conflict and reloads the payment', async () => {
    serveMoneyGroup();
    const state = serveSettlement(makeSettlement({ status: 'confirmed', counted: true }));
    server.use(
      http.post(`${API}/groups/:id/settlements/:settlementId/dispute`, () => {
        state.current = makeSettlement({
          status: 'disputed',
          counted: false,
          dispute_reason: 'Wrong amount',
          version: 2,
        });
        return HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                message: 'Only a reported or confirmed settlement can be disputed.',
                code: 'settlement_not_disputable',
                params: { status: 'disputed' },
              },
            ],
          }),
          { status: 409 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    await user.click(await screen.findByRole('button', { name: 'Dispute' }));
    const dialog = await screen.findByRole('dialog', { name: 'Dispute this payment?' });
    await user.type(within(dialog).getByLabelText('What’s wrong?'), 'Only got 250');
    await user.click(within(dialog).getByRole('button', { name: 'Dispute payment' }));
    expect(
      await within(dialog).findByText('This payment can’t be disputed now. It is: Disputed.'),
    ).toBeInTheDocument();
    // The page follows the state someone else moved it to.
    expect(await screen.findByText('Disputed: Wrong amount')).toBeInTheDocument();
    expect(state.reads).toBeGreaterThanOrEqual(2);
  });

  it('lets an admin confirm a payment made to someone who left the group', async () => {
    serveMoneyGroup(makeGroupWithFormerMember());
    const state = serveSettlement(
      makeSettlement({
        payer_user_id: MEERA,
        payer_name: 'Meera Rao',
        payee_user_id: RAVI,
        payee_name: 'Ravi Kumar',
        proposed_by: MEERA,
      }),
      (_action, current) => ({
        ...current,
        status: 'confirmed',
        counted: true,
        confirmed_by: ME,
        confirmed_at: '2026-11-05T12:00:00Z',
        version: current.version + 1,
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    expect(await screen.findByText('Meera Rao paid Ravi Kumar')).toBeInTheDocument();
    expect(
      screen.getByText(
        'They are no longer in the group, so a group admin can confirm it for them.',
      ),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Confirm for Ravi Kumar' }));
    const dialog = await screen.findByRole('dialog', {
      name: 'Confirm this payment for Ravi Kumar?',
    });
    expect(
      within(dialog).getByText(/Ravi Kumar is no longer in the group, so a group admin confirms/),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByText(/Confirm that Meera Rao paid them ₹300.00/),
    ).toBeInTheDocument();
    // Nothing is recorded in the admin's own accounts on someone else's behalf.
    expect(within(dialog).queryByLabelText(/account/i)).not.toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Confirm' }));

    expect(await screen.findByText('Payment confirmed')).toBeInTheDocument();
    expect(state.calls).toEqual([{ action: 'confirm', body: { version: 1 } }]);
    expect(screen.getByText('Counts toward balances')).toBeInTheDocument();
  });

  it('offers no lifecycle actions to a member who is not part of the payment', async () => {
    serveMoneyGroup(makeMoneyGroup({ my_role: 'member' }));
    serveSettlement(
      makeSettlement({ payee_user_id: RAVI, payee_name: 'Ravi Kumar', proposed_by: MEERA }),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    expect(await screen.findByText('Meera Rao paid Ravi Kumar')).toBeInTheDocument();
    for (const name of ['Confirm I received it', 'Dispute', 'Correct', 'Void', 'Mark as paid']) {
      expect(screen.queryByRole('button', { name })).not.toBeInTheDocument();
    }
    expect(screen.queryByRole('region', { name: 'Your account record' })).not.toBeInTheDocument();
  });

  it('says when the payment is not found', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/settlements/:settlementId`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Payment');
    expect(await screen.findByText('Payment not found')).toBeInTheDocument();
    for (const link of screen.getAllByRole('link', { name: 'Back to balances' })) {
      expect(link).toHaveAttribute('href', `/groups/${MONEY_GROUP}/balances`);
    }
  });
});
