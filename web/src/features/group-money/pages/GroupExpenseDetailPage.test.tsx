import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { ACCOUNT_CASH, makeAccount, money } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  EXPENSE_ID,
  ME,
  MEERA,
  MONEY_GROUP,
  RAVI,
  makeExpenseDetail,
  makeMoneyGroup,
  serveMoneyGroup,
} from '@/tests/groupMoneyFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import type { GroupExpenseDetail } from '../types';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const PATH = `/groups/${MONEY_GROUP}/expenses/${EXPENSE_ID}`;
const DISPUTE_ID = 'd1d1d1d1-0000-4000-8000-000000000001';

function serveExpense(initial: GroupExpenseDetail) {
  const state = { current: initial };
  server.use(
    http.get(`${API}/groups/:id/expenses/:expenseId`, () =>
      HttpResponse.json(envelope(state.current)),
    ),
  );
  return state;
}

describe('GroupExpenseDetailPage', () => {
  it('shows who paid, each share, the items and the foreign amount from the server', async () => {
    serveMoneyGroup();
    serveExpense(
      makeExpenseDetail({
        description: 'Dinner in Goa',
        amount: money('8325.00'),
        original_amount: money('100.00', 'USD'),
        fx_rate: '83.25',
        fx_rate_source: 'manual',
        fx_rate_at: '2026-11-04T10:00:00Z',
        split_method: 'itemized',
        notes: 'Beach shack',
        payers: [
          { user_id: ME, paid: money('5000.00') },
          { user_id: MEERA, paid: money('3325.00') },
        ],
        shares: [
          { user_id: ME, share: money('4162.50') },
          { user_id: RAVI, share: money('4162.50') },
        ],
        items: [
          {
            description: 'Fish thali',
            amount: money('8325.00'),
            shares: [
              { user_id: ME, share: money('4162.50'), input_value: '1' },
              { user_id: RAVI, share: money('4162.50'), input_value: '1' },
            ],
          },
        ],
        my_paid: money('5000.00'),
        my_share: money('4162.50'),
        revisions: 3,
      }),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Dinner in Goa');
    expect(screen.getByText('Rate used: 1 USD = 83.25 INR')).toBeInTheDocument();
    expect(screen.getByText(/^a member’s rate, from /)).toBeInTheDocument();
    expect(screen.getByText('Beach shack')).toBeInTheDocument();
    expect(screen.getByText('Edited 2 times (earlier versions are kept)')).toBeInTheDocument();

    const table = screen.getByRole('table', { name: 'Each person’s share and what they paid' });
    const meera = within(table).getByRole('row', { name: /^Meera Rao/ });
    // Meera paid but has no share: shown, never computed.
    expect(within(meera).getByText('No share')).toBeInTheDocument();
    expect(within(meera).getByText('₹3,325.00')).toBeInTheDocument();
    const items = screen.getByRole('region', { name: 'Items' });
    expect(within(items).getByText('Fish thali')).toBeInTheDocument();
    expect(within(items).getByText('Ravi Kumar:')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Edit' })).toHaveAttribute('href', `${PATH}/edit`);
  });

  it('adds a comment and shows it from the server', async () => {
    serveMoneyGroup();
    const state = serveExpense(makeExpenseDetail());
    let posted: unknown = null;
    server.use(
      http.post(`${API}/groups/:id/expenses/:expenseId/comments`, async ({ request }) => {
        posted = await request.json();
        const comment = {
          id: 'c0c0c0c0-0000-4000-8000-000000000001',
          author_id: ME,
          body: 'Includes the oat milk',
          created_at: '2026-11-05T10:05:00Z',
        };
        state.current = makeExpenseDetail({ comments: [comment] });
        return HttpResponse.json(envelope(comment), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Groceries');
    expect(screen.getByText('No comments yet.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Post comment' }));
    expect(screen.getByLabelText('Add a comment')).toHaveAccessibleDescription(
      /Write a comment first./,
    );
    await user.type(screen.getByLabelText('Add a comment'), '  Includes the oat milk ');
    await user.click(screen.getByRole('button', { name: 'Post comment' }));

    expect(await screen.findByText('Comment added')).toBeInTheDocument();
    expect(posted).toEqual({ body: 'Includes the oat milk' });
    const comments = screen.getByRole('region', { name: 'Comments' });
    expect(await within(comments).findByText('Includes the oat milk')).toBeInTheDocument();
    expect(screen.getByLabelText('Add a comment')).toHaveValue('');
  });

  it('raises a dispute with a reason and the raiser resolves it', async () => {
    serveMoneyGroup(makeMoneyGroup({ my_role: 'member' }));
    const state = serveExpense(makeExpenseDetail({ created_by: MEERA }));
    let disputeBody: unknown = null;
    let resolveBody: unknown = null;
    const dispute = {
      id: DISPUTE_ID,
      raised_by: ME,
      reason: 'Wrong total',
      status: 'open' as const,
      created_at: '2026-11-05T10:00:00Z',
    };
    server.use(
      http.post(`${API}/groups/:id/expenses/:expenseId/disputes`, async ({ request }) => {
        disputeBody = await request.json();
        state.current = makeExpenseDetail({
          created_by: MEERA,
          status: 'disputed',
          disputes: [dispute],
        });
        return HttpResponse.json(envelope(dispute), { status: 201 });
      }),
      http.post(`${API}/groups/:id/disputes/:disputeId/resolve`, async ({ params, request }) => {
        expect(params.disputeId).toBe(DISPUTE_ID);
        resolveBody = await request.json();
        state.current = makeExpenseDetail({
          created_by: MEERA,
          disputes: [{ ...dispute, status: 'resolved', resolution: 'Fixed the total' }],
        });
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Groceries');
    // A member who did not add it cannot delete it.
    expect(screen.queryByRole('button', { name: 'Delete' })).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Dispute this expense' }));
    const dialog = await screen.findByRole('dialog', { name: 'Dispute this expense?' });
    await user.click(within(dialog).getByRole('button', { name: 'Raise dispute' }));
    expect(within(dialog).getByLabelText('What’s wrong?')).toHaveAccessibleDescription(
      /Say what’s wrong./,
    );
    await user.type(within(dialog).getByLabelText('What’s wrong?'), 'Wrong total');
    await user.click(within(dialog).getByRole('button', { name: 'Raise dispute' }));
    expect(await screen.findByText('Dispute raised')).toBeInTheDocument();
    expect(disputeBody).toEqual({ reason: 'Wrong total' });
    expect(await screen.findByText('This expense is disputed')).toBeInTheDocument();

    const disputes = screen.getByRole('region', { name: 'Disputes' });
    await user.click(within(disputes).getByRole('button', { name: 'Resolve' }));
    const resolveDialog = await screen.findByRole('dialog', { name: 'Resolve this dispute?' });
    await user.type(
      within(resolveDialog).getByLabelText(/How was it resolved\?/),
      'Fixed the total',
    );
    await user.click(within(resolveDialog).getByRole('button', { name: 'Mark resolved' }));
    expect(await screen.findByText('Dispute resolved')).toBeInTheDocument();
    expect(resolveBody).toEqual({ resolution: 'Fixed the total' });
    expect(await within(disputes).findByText('Resolution: Fixed the total')).toBeInTheDocument();
    expect(screen.queryByText('This expense is disputed')).not.toBeInTheDocument();
  });

  it('lets the raiser withdraw a dispute', async () => {
    serveMoneyGroup();
    const state = serveExpense(
      makeExpenseDetail({
        status: 'disputed',
        disputes: [
          {
            id: DISPUTE_ID,
            raised_by: ME,
            reason: 'Wrong total',
            status: 'open',
            created_at: '2026-11-05T10:00:00Z',
          },
        ],
      }),
    );
    let body: unknown = null;
    server.use(
      http.post(`${API}/groups/:id/disputes/:disputeId/resolve`, async ({ request }) => {
        body = await request.json();
        state.current = makeExpenseDetail();
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Groceries');
    await user.click(screen.getByRole('button', { name: 'Withdraw' }));
    const dialog = await screen.findByRole('dialog', { name: 'Withdraw your dispute?' });
    await user.click(within(dialog).getByRole('button', { name: 'Withdraw dispute' }));
    expect(await screen.findByText('Dispute withdrawn')).toBeInTheDocument();
    expect(body).toEqual({ withdraw: true });
  });

  it('deletes after confirmation and goes back to the list', async () => {
    serveMoneyGroup();
    serveExpense(makeExpenseDetail());
    let deleted = 0;
    server.use(
      http.delete(`${API}/groups/:id/expenses/:expenseId`, () => {
        deleted += 1;
        return HttpResponse.json(envelope({ ok: true }));
      }),
      http.get(`${API}/groups/:id/expenses`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Groceries');
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this expense?' });
    expect(
      within(dialog).getByText(/It stops counting in everyone’s balances/),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    expect(deleted).toBe(0);

    await user.click(screen.getByRole('button', { name: 'Delete' }));
    await user.click(
      within(await screen.findByRole('dialog')).getByRole('button', { name: 'Delete expense' }),
    );
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/groups/${MONEY_GROUP}/expenses`);
    });
    expect(deleted).toBe(1);
    expect(await screen.findByText('Expense deleted')).toBeInTheDocument();
  });

  it('explains a refused delete inside the dialog', async () => {
    serveMoneyGroup();
    serveExpense(makeExpenseDetail());
    server.use(
      http.delete(`${API}/groups/:id/expenses/:expenseId`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Groceries');
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    await user.click(
      within(await screen.findByRole('dialog')).getByRole('button', { name: 'Delete expense' }),
    );
    expect(
      await screen.findByText('Only the person who added it or a group admin can delete it.'),
    ).toBeInTheDocument();
  });

  it('records my payment in one of my accounts and removes it again', async () => {
    serveMoneyGroup();
    testBackend.accounts = [
      makeAccount(),
      makeAccount({ id: '33333333-3333-4333-8333-333333333333', name: 'Dollars', currency: 'USD' }),
    ];
    const state = serveExpense(makeExpenseDetail());
    const bodies: unknown[] = [];
    server.use(
      http.post(`${API}/groups/:id/expenses/:expenseId/my-record`, async ({ request }) => {
        const body = (await request.json()) as { action: string };
        bodies.push(body);
        state.current =
          body.action === 'link'
            ? makeExpenseDetail({ my_transaction_id: '77777777-7777-4777-8777-777777777701' })
            : makeExpenseDetail();
        return HttpResponse.json(envelope(state.current));
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Groceries');
    const record = screen.getByRole('region', { name: 'Your account record' });
    // Only accounts in the group currency are offered.
    const select = await within(record).findByLabelText('Account');
    expect(within(select).queryByRole('option', { name: /Dollars/ })).not.toBeInTheDocument();
    await user.click(within(record).getByRole('button', { name: 'Record payment' }));
    expect(select).toHaveAccessibleDescription(/Choose an account./);
    await user.selectOptions(select, ACCOUNT_CASH);
    await user.click(within(record).getByRole('button', { name: 'Record payment' }));
    expect(await screen.findByText('Recorded in your account')).toBeInTheDocument();
    expect(
      await within(record).findByRole('link', { name: 'View in my transactions' }),
    ).toHaveAttribute('href', '/transactions/77777777-7777-4777-8777-777777777701');

    await user.click(within(record).getByRole('button', { name: 'Remove from my account' }));
    const dialog = await screen.findByRole('dialog', { name: 'Remove your account record?' });
    await user.click(within(dialog).getByRole('button', { name: 'Remove record' }));
    expect(await screen.findByText('Account record removed')).toBeInTheDocument();
    expect(bodies).toEqual([{ action: 'link', account_id: ACCOUNT_CASH }, { action: 'unlink' }]);
  });

  it('says when the expense is gone', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/expenses/:expenseId`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Shared expense');
    expect(await screen.findByText('Expense not found')).toBeInTheDocument();
  });

  it('shows a deleted expense as history without actions', async () => {
    serveMoneyGroup();
    serveExpense(makeExpenseDetail({ status: 'deleted' }));
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Groceries');
    expect(screen.getByText('This expense was deleted')).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Edit' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Delete' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Dispute this expense' })).not.toBeInTheDocument();
  });
});
