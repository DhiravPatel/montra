import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { money } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ME,
  MONEY_GROUP,
  RAVI,
  SETTLEMENT_2,
  SETTLEMENT_ID,
  makeBalances,
  makeGroupWithFormerMember,
  makeMoneyGroup,
  makeSettlement,
  makeSuggestions,
  serveMoneyGroup,
} from '@/tests/groupMoneyFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import type { GroupBalances, GroupSuggestions, Settlement } from '../types';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const PATH = `/groups/${MONEY_GROUP}/balances`;

function serveBalances({
  balances = makeBalances(),
  suggestions = makeSuggestions(),
  settlements = [makeSettlement()],
}: {
  balances?: GroupBalances;
  suggestions?: GroupSuggestions;
  settlements?: Settlement[];
} = {}) {
  const seen = { suggestions: [] as string[], settlements: [] as string[] };
  server.use(
    http.get(`${API}/groups/:id/balances`, () => HttpResponse.json(envelope(balances))),
    http.get(`${API}/groups/:id/settlement-suggestions`, ({ request }) => {
      const search = new URL(request.url).search;
      seen.suggestions.push(search);
      return HttpResponse.json(
        envelope(
          search.includes('mine=true')
            ? {
                ...suggestions,
                suggestions: suggestions.suggestions.filter((item) => item.involves_me),
              }
            : suggestions,
        ),
      );
    }),
    http.get(`${API}/groups/:id/settlements`, ({ request }) => {
      const search = new URL(request.url).search;
      seen.settlements.push(search);
      return HttpResponse.json(
        envelope(
          search.includes('include_voided=true')
            ? [
                ...settlements,
                makeSettlement({
                  id: SETTLEMENT_2,
                  status: 'voided',
                  payer_user_id: RAVI,
                  payer_name: 'Ravi Kumar',
                }),
              ]
            : settlements,
        ),
      );
    }),
  );
  return seen;
}

describe('GroupBalancesPage', () => {
  it('explains balances from the server, with the simplified and original views', async () => {
    serveMoneyGroup();
    serveBalances({
      balances: makeBalances({
        disputed_expenses: 1,
        balances: makeBalances().balances.map((entry) =>
          entry.user_id === ME ? { ...entry, pending_in: money('300.00') } : entry,
        ),
      }),
    });
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Balances');
    expect(await screen.findByText('Montra never moves money')).toBeInTheDocument();
    expect(await screen.findByText('You’re owed ₹500.00')).toBeInTheDocument();
    expect(
      screen.getByText('₹300.00 reported paid to you is waiting for your confirmation.'),
    ).toBeInTheDocument();
    expect(
      screen.getByText('1 disputed expense still counts until it’s resolved.'),
    ).toBeInTheDocument();

    const debts = screen.getByRole('region', { name: 'Who owes whom' });
    const simplified = within(debts).getByRole('region', { name: 'Fewest payments in INR' });
    expect(within(simplified).getByText('Meera Rao owes you')).toBeInTheDocument();
    expect(within(simplified).getByText('₹200.00')).toBeInTheDocument();
    expect(within(simplified).queryByText('Ravi Kumar owes Meera Rao')).not.toBeInTheDocument();

    await user.click(within(debts).getByRole('radio', { name: /Original debts/ }));
    const original = within(debts).getByRole('region', { name: 'Original debts in INR' });
    expect(within(original).getByText('Ravi Kumar owes Meera Rao')).toBeInTheDocument();
    expect(within(original).getByText('₹150.00')).toBeInTheDocument();
    expect(within(original).getByText('₹50.00')).toBeInTheDocument();

    const members = screen.getByRole('table', { name: 'Balances in INR' });
    const meera = within(members).getByRole('row', { name: /^Meera Rao/ });
    expect(within(meera).getByText('Owes')).toBeInTheDocument();
    // Her share and what she owes, both as the server sent them.
    expect(within(meera).getAllByText('₹300.00')).toHaveLength(2);
    const me = within(members).getByRole('row', { name: /^You/ });
    expect(within(me).getByText('Is owed')).toBeInTheDocument();
    // Both debt views add up to the same totals: no rounding caveat.
    expect(screen.queryByText(/because of rounding/)).not.toBeInTheDocument();
  });

  it('keeps a removed member with an open balance in balances and suggestions', async () => {
    serveMoneyGroup(makeGroupWithFormerMember());
    serveBalances({
      balances: makeBalances({
        balances: makeBalances().balances.map((entry) =>
          entry.user_id === RAVI ? { ...entry, member_status: 'removed' } : entry,
        ),
      }),
    });
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Balances');
    const members = await screen.findByRole('table', { name: 'Balances in INR' });
    const ravi = within(members).getByRole('row', { name: /^Ravi Kumar/ });
    expect(within(ravi).getByText('Removed from the group')).toBeInTheDocument();
    expect(within(ravi).getByText('Owes')).toBeInTheDocument();
    expect(
      screen.getByText(/People who left or were removed with an open balance stay here/),
    ).toBeInTheDocument();
    // A payment with them can still be recorded.
    const suggestions = screen.getByRole('region', { name: 'Suggested payments' });
    await user.click(
      await within(suggestions).findByRole('button', {
        name: 'Record this payment: Ravi Kumar to you',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Record a payment' });
    expect(within(dialog).getByLabelText('Paid by')).toHaveValue(RAVI);
    // Offered on both sides of a payment, marked as no longer in the group.
    expect(
      within(dialog).getAllByRole('option', {
        name: 'Ravi Kumar (@ravi) · Removed from the group',
      }),
    ).toHaveLength(2);
  });

  it('records a payment from a suggestion with an Idempotency-Key', async () => {
    serveMoneyGroup();
    serveBalances();
    let body: unknown = null;
    let key: string | null = null;
    server.use(
      http.post(`${API}/groups/:id/settlements`, async ({ request }) => {
        body = await request.json();
        key = request.headers.get('Idempotency-Key');
        return HttpResponse.json(
          envelope(
            makeSettlement({
              id: SETTLEMENT_2,
              payer_user_id: RAVI,
              payer_name: 'Ravi Kumar',
              amount: money('200.00'),
              status: 'confirmed',
              counted: true,
            }),
          ),
          { status: 201 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Balances');
    const suggestions = await screen.findByRole('region', { name: 'Suggested payments' });
    await user.click(
      await within(suggestions).findByRole('button', {
        name: 'Record this payment: Ravi Kumar to you',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Record a payment' });
    expect(within(dialog).getByText(/Montra doesn’t move money/)).toBeInTheDocument();
    expect(within(dialog).getByLabelText('Paid by')).toHaveValue(RAVI);
    expect(within(dialog).getByLabelText('Paid to')).toHaveValue(ME);
    expect(within(dialog).getByLabelText('Amount')).toHaveValue('200.00');
    expect(
      within(dialog).getByText('You received it, so it counts toward balances right away.'),
    ).toBeInTheDocument();
    await user.selectOptions(within(dialog).getByLabelText('How it was paid'), 'cash');
    await user.click(within(dialog).getByRole('button', { name: 'Record payment' }));

    expect(await screen.findByText('Payment recorded and confirmed')).toBeInTheDocument();
    expect(key).toMatch(/^web-/);
    expect(body).toMatchObject({
      payer_user_id: RAVI,
      payee_user_id: ME,
      amount: '200.00',
      method: 'cash',
      state: 'paid',
    });
  });

  it('validates a new payment before sending it', async () => {
    serveMoneyGroup();
    serveBalances();
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Balances');
    await user.click((await screen.findAllByRole('button', { name: 'Record a payment' }))[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Record a payment' });
    await user.selectOptions(within(dialog).getByLabelText('Paid to'), ME);
    await user.click(within(dialog).getByRole('button', { name: 'Record payment' }));
    expect(within(dialog).getByLabelText('Paid to')).toHaveAccessibleDescription(
      /Choose two different people./,
    );
    expect(within(dialog).getByLabelText('Amount')).toHaveAccessibleDescription(/Enter an amount./);
  });

  it('lists settlements and asks for voided ones only when requested', async () => {
    serveMoneyGroup();
    const seen = serveBalances();
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Balances');
    const payments = await screen.findByRole('region', { name: 'Payments' });
    const link = await within(payments).findByRole('link', { name: 'Meera Rao paid you' });
    expect(link).toHaveAttribute('href', `/groups/${MONEY_GROUP}/settlements/${SETTLEMENT_ID}`);
    expect(within(payments).getByText('Paid, waiting for confirmation')).toBeInTheDocument();

    await user.click(within(payments).getByLabelText('Show voided'));
    expect(await within(payments).findByText('Voided')).toBeInTheDocument();
    expect(seen.settlements).toEqual(['', '?include_voided=true']);

    const suggestions = screen.getByRole('region', { name: 'Suggested payments' });
    await user.click(within(suggestions).getByLabelText('Only mine'));
    expect(seen.suggestions).toContain('?mine=true');
  });

  it('says when everyone is settled up and nothing was recorded', async () => {
    serveMoneyGroup();
    serveBalances({
      balances: makeBalances({
        my_net: money('0.00'),
        original_debts: [],
        simplified: [],
        balances: [],
      }),
      suggestions: makeSuggestions({ suggestions: [] }),
      settlements: [],
    });
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Balances');
    expect(await screen.findByText('You’re settled up')).toBeInTheDocument();
    expect(screen.getByText('Everyone is settled up')).toBeInTheDocument();
    expect(screen.getByText('No payments needed. Everyone is settled up.')).toBeInTheDocument();
    expect(await screen.findByText('No payments recorded yet')).toBeInTheDocument();
  });

  it('shows errors with retry and a permission state', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/balances`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-bal' }), {
          status: 500,
        }),
      ),
      http.get(`${API}/groups/:id/settlement-suggestions`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
      http.get(`${API}/groups/:id/settlements`, () => HttpResponse.json(envelope([]))),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Balances');
    expect(await screen.findByText('We couldn’t load the balances')).toBeInTheDocument();
    expect(screen.getByText('req-bal')).toBeInTheDocument();
    expect(await screen.findByText('We couldn’t load the suggestions')).toBeInTheDocument();
  });

  it('hides recording in an archived group', async () => {
    serveMoneyGroup(makeMoneyGroup({ status: 'archived' }));
    serveBalances();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Balances');
    await screen.findByText('You’re owed ₹500.00');
    expect(screen.queryByRole('button', { name: 'Record a payment' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Record this payment/ })).not.toBeInTheDocument();
    expect(screen.getByText('This group is archived')).toBeInTheDocument();
  });
});
