import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { Budget } from '@/shared/finance/types';
import {
  BUDGET_ID,
  ME,
  OTHER_ALERT_ID,
  SHARED_BUDGET_ID,
  makeBudget,
  makeBudgetAlert,
  makeBudgetMember,
  makeProgress,
  makeSharedBudget,
  pageEnvelope,
  previousProgress,
} from '@/tests/budgetsFixtures';
import { makeTransaction, starterCategories } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { FRIEND_ID, makeFriend } from '@/tests/sharingFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

/** The budget (mutable per test) plus the reads its page makes. */
function budgetReads(initial: Budget, options: { progressDates?: string[] } = {}) {
  let current = initial;
  const handlers = [
    http.get(`${API}/budgets/:id`, () => HttpResponse.json(envelope(current))),
    http.get(`${API}/budgets/:id/progress`, ({ request }) => {
      options.progressDates?.push(new URL(request.url).searchParams.get('date') ?? '');
      return HttpResponse.json(envelope([makeProgress(), previousProgress()]));
    }),
    http.get(`${API}/budget-alerts`, () => HttpResponse.json(envelope([]))),
  ];
  return {
    handlers,
    set: (next: Budget) => {
      current = next;
    },
  };
}

describe('BudgetDetailPage', () => {
  it('explains this period in words and shows history, allocations and what was counted', async () => {
    testBackend.categories = starterCategories();
    const dates: string[] = [];
    const alertRequests: URLSearchParams[] = [];
    const reads = budgetReads(makeBudget(), { progressDates: dates });
    server.use(
      // Listed first: the first matching handler answers. The API filters by budget_id.
      http.get(`${API}/budget-alerts`, ({ request }) => {
        const params = new URL(request.url).searchParams;
        alertRequests.push(params);
        const all = [
          makeBudgetAlert(),
          makeBudgetAlert({ id: OTHER_ALERT_ID, budget_id: SHARED_BUDGET_ID, budget_name: 'Trip' }),
        ];
        const budgetId = params.get('budget_id');
        return HttpResponse.json(
          envelope(budgetId ? all.filter((alert) => alert.budget_id === budgetId) : all),
        );
      }),
      ...reads.handlers,
      http.get(`${API}/budgets/:id/transactions`, () =>
        HttpResponse.json(envelope([makeTransaction()])),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}`, { user: signedIn() });
    await findPageHeading('Food');
    expect(document.title).not.toContain('Food');

    const period = screen.getByRole('region', { name: 'This period' });
    const meter = within(period).getByRole('meter', { name: 'Food: budget used' });
    expect(meter).toHaveAttribute('aria-valuetext', '₹4,200.00 of ₹5,000.00 spent (84%)');
    expect(within(period).getByText('Spending faster than expected')).toBeInTheDocument();
    expect(within(period).getByText('About ₹32.00 a day')).toBeInTheDocument();
    expect(
      within(period).getByText('About ₹25,200.00 by Nov 30, 2026 (an estimate)'),
    ).toBeInTheDocument();
    expect(
      within(period).getByText('That would be ₹20,200.00 over the limit.'),
    ).toBeInTheDocument();
    expect(within(period).getByText('Day 5 of 30')).toBeInTheDocument();
    // Localized from explanation_items (codes with values); the API's English lines are not shown.
    expect(
      within(period).getByText(
        '₹4,200.00 of ₹5,000.00 spent between Nov 1, 2026 and Nov 30, 2026.',
      ),
    ).toBeInTheDocument();
    expect(
      within(period).getByText(
        'Transfers and balance adjustments never count. Refunds add back to the budget.',
      ),
    ).toBeInTheDocument();
    expect(
      within(period).getByText(
        'At the current pace you would spend about ₹25,200.00 by the end of the period. This is an estimate, not a promise.',
      ),
    ).toBeInTheDocument();
    expect(screen.queryByText(/English line for/)).not.toBeInTheDocument();

    const allocations = screen.getByRole('region', { name: 'Allocations' });
    expect(await within(allocations).findByText('Groceries')).toBeInTheDocument();
    // The API's overspent figure for the allocation.
    expect(within(allocations).getByText('₹1,200.00 over this allocation')).toBeInTheDocument();

    const history = screen.getByRole('region', { name: 'History' });
    const rows = await within(history).findAllByRole('row');
    expect(rows).toHaveLength(3);
    expect(within(history).getByText('Over the limit (140%)')).toBeInTheDocument();
    expect(within(history).getByText('84% used')).toBeInTheDocument();

    const counted = screen.getByRole('region', { name: 'Transactions counted' });
    expect(await within(counted).findByRole('link', { name: 'Big Bazaar' })).toBeInTheDocument();

    // Only this budget's alerts, filtered by the server (budget_id).
    const alerts = screen.getByRole('region', { name: 'Alerts' });
    expect(await within(alerts).findByText('Food reached 75% of its limit')).toBeInTheDocument();
    expect(within(alerts).queryByText(/Trip/)).not.toBeInTheDocument();
    expect(alertRequests[0]?.get('budget_id')).toBe(BUDGET_ID);

    await user.click(within(history).getByRole('button', { name: /Earlier/ }));
    await waitFor(() => {
      expect(dates).toEqual(['', '2026-09-30']);
    });
  });

  it('pauses, resumes, archives and restores the budget, sending the version shown', async () => {
    const reads = budgetReads(makeBudget({ version: 1 }));
    const versions: Record<string, string | null> = {};
    const answer = (action: string, request: Request, next: Budget) => {
      versions[action] = new URL(request.url).searchParams.get('version');
      reads.set(next);
      return HttpResponse.json(envelope(next));
    };
    server.use(
      ...reads.handlers,
      http.get(`${API}/budgets/:id/transactions`, () => HttpResponse.json(pageEnvelope([]))),
      http.post(`${API}/budgets/:id/pause`, ({ request }) =>
        answer('pause', request, makeBudget({ status: 'paused', version: 2 })),
      ),
      http.post(`${API}/budgets/:id/resume`, ({ request }) =>
        answer('resume', request, makeBudget({ version: 3 })),
      ),
      http.delete(`${API}/budgets/:id`, ({ request }) =>
        answer('archive', request, makeBudget({ status: 'archived', version: 4 })),
      ),
      http.post(`${API}/budgets/:id/restore`, ({ request }) =>
        answer('restore', request, makeBudget({ version: 5 })),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}`, { user: signedIn() });
    await findPageHeading('Food');

    await user.click(screen.getByRole('button', { name: 'Pause' }));
    expect(await screen.findByText('Budget paused')).toBeInTheDocument();
    expect(await screen.findByText(/This budget is paused/)).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Resume' }));
    expect(await screen.findByText('Budget resumed')).toBeInTheDocument();

    await user.click(await screen.findByRole('button', { name: 'Archive' }));
    const dialog = await screen.findByRole('dialog', { name: 'Archive this budget?' });
    await user.click(within(dialog).getByRole('button', { name: 'Archive' }));
    expect(await screen.findByText('Budget archived')).toBeInTheDocument();
    expect(
      await screen.findByText(/This budget is archived\. Its history is kept\. Restore it/),
    ).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Edit' })).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Restore' }));
    expect(await screen.findByText('Budget restored')).toBeInTheDocument();
    expect(await screen.findByRole('link', { name: 'Edit' })).toBeInTheDocument();
    expect(versions).toEqual({ pause: '1', resume: '2', archive: '3', restore: '4' });
  });

  it('explains a status change that no longer fits, and shows the budget as it is now', async () => {
    const reads = budgetReads(makeBudget({ version: 3 }));
    server.use(
      ...reads.handlers,
      http.get(`${API}/budgets/:id/transactions`, () => HttpResponse.json(pageEnvelope([]))),
      http.post(`${API}/budgets/:id/pause`, () => {
        // Archived on another device in the meantime.
        reads.set(makeBudget({ status: 'archived', version: 4 }));
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                code: 'invalid_status_transition',
                message: 'A budget cannot move from archived to paused.',
                params: { from: 'archived', to: 'paused' },
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}`, { user: signedIn() });
    await findPageHeading('Food');

    await user.click(screen.getByRole('button', { name: 'Pause' }));
    expect(
      await screen.findByText(
        'This can’t change from archived to paused. Its status may have changed somewhere else, so we’ve loaded the latest version.',
      ),
    ).toBeInTheDocument();
    expect(screen.queryByText('A budget cannot move from archived to paused.')).toBeNull();
    expect(await screen.findByRole('button', { name: 'Restore' })).toBeInTheDocument();
  });

  it('loads more of the counted transactions with the cursor', async () => {
    const reads = budgetReads(makeBudget());
    const cursors: (string | null)[] = [];
    server.use(
      ...reads.handlers,
      http.get(`${API}/budgets/:id/transactions`, ({ request }) => {
        const params = new URL(request.url).searchParams;
        cursors.push(params.get('cursor'));
        return params.get('cursor') === 'next-1'
          ? HttpResponse.json(
              pageEnvelope([
                makeTransaction({
                  id: '99999999-9999-4999-8999-999999999902',
                  merchant: { id: '99999999-9999-4999-8999-999999999903', name: 'Fresh Mart' },
                }),
              ]),
            )
          : HttpResponse.json(pageEnvelope([makeTransaction()], 'next-1'));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}`, { user: signedIn() });
    await findPageHeading('Food');
    const counted = screen.getByRole('region', { name: 'Transactions counted' });
    expect(await within(counted).findByRole('link', { name: 'Big Bazaar' })).toBeInTheDocument();

    await user.click(within(counted).getByRole('button', { name: 'Load more' }));
    expect(await within(counted).findByRole('link', { name: 'Fresh Mart' })).toBeInTheDocument();
    expect(within(counted).getByRole('link', { name: 'Big Bazaar' })).toBeInTheDocument();
    expect(within(counted).queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
    expect(cursors).toEqual([null, 'next-1']);
  });

  it('shares the budget with a friend, changes their role and stops sharing', async () => {
    testBackend.people = [makeFriend()];
    const reads = budgetReads(makeBudget());
    const sent: { method: string; body?: unknown }[] = [];
    server.use(
      ...reads.handlers,
      http.get(`${API}/budgets/:id/transactions`, () => HttpResponse.json(envelope([]))),
      http.post(`${API}/budgets/:id/members`, async ({ request }) => {
        sent.push({ method: 'POST', body: await request.json() });
        const shared = makeBudget({
          members: [makeBudgetMember({ role: 'editor', allocation: undefined })],
        });
        reads.set(shared);
        return HttpResponse.json(envelope(shared));
      }),
      http.patch(`${API}/budgets/:id/members/:userId`, async ({ request, params }) => {
        expect(params.userId).toBe(FRIEND_ID);
        sent.push({ method: 'PATCH', body: await request.json() });
        const changed = makeBudget({ members: [makeBudgetMember({ role: 'viewer' })] });
        reads.set(changed);
        return HttpResponse.json(envelope(changed));
      }),
      http.delete(`${API}/budgets/:id/members/:userId`, ({ params }) => {
        expect(params.userId).toBe(FRIEND_ID);
        sent.push({ method: 'DELETE' });
        reads.set(makeBudget());
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}`, { user: signedIn() });
    await findPageHeading('Food');
    const sharing = screen.getByRole('region', { name: 'Sharing' });
    expect(within(sharing).getByText('Not shared with anyone.')).toBeInTheDocument();

    await user.click(within(sharing).getByRole('button', { name: 'Share' }));
    const dialog = await screen.findByRole('dialog', { name: 'Share this budget' });
    await user.selectOptions(
      await within(dialog).findByLabelText('Person'),
      'Ravi Kumar (@ravi) · Friend',
    );
    await user.click(within(dialog).getByRole('radio', { name: /^Can edit/ }));
    await user.type(within(dialog).getByLabelText(/Their share of the limit/), '1000');
    await user.click(within(dialog).getByRole('button', { name: 'Share budget' }));
    expect(await screen.findByText('Budget shared')).toBeInTheDocument();
    expect(sent[0]).toEqual({
      method: 'POST',
      body: { user_id: FRIEND_ID, role: 'editor', allocation: '1000.00' },
    });
    expect(await within(sharing).findByText('Ravi Kumar')).toBeInTheDocument();

    await user.click(within(sharing).getByRole('button', { name: 'Change: Ravi Kumar' }));
    const change = await screen.findByRole('dialog', { name: 'Change sharing' });
    await user.click(within(change).getByRole('radio', { name: /^Can view/ }));
    await user.click(within(change).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Sharing updated')).toBeInTheDocument();
    expect(sent[1]).toEqual({ method: 'PATCH', body: { role: 'viewer' } });

    await user.click(await within(sharing).findByRole('button', { name: 'Remove: Ravi Kumar' }));
    const confirm = await screen.findByRole('dialog', { name: 'Stop sharing with this person?' });
    await user.click(within(confirm).getByRole('button', { name: 'Remove' }));
    expect(await screen.findByText('Stopped sharing with Ravi Kumar')).toBeInTheDocument();
    expect(sent[2]).toEqual({ method: 'DELETE' });
  });

  it('shows a viewer the totals only and lets them leave', async () => {
    const reads = budgetReads(makeSharedBudget());
    let left = '';
    server.use(
      ...reads.handlers,
      // No transactions handler: viewers never ask for individual transactions.
      http.delete(`${API}/budgets/:id/members/:userId`, ({ params }) => {
        left = String(params.userId);
        return HttpResponse.json(envelope({ ok: true }));
      }),
      http.get(`${API}/budgets`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${SHARED_BUDGET_ID}`, { user: signedIn() });
    await findPageHeading('Household');
    expect(screen.getAllByText('You can view this budget').length).toBeGreaterThan(0);
    expect(screen.getByText('Shared by Kiran Shah · Can view')).toBeInTheDocument();
    const sharing = screen.getByRole('region', { name: 'Sharing' });
    expect(within(sharing).getByText('Owner')).toBeInTheDocument();
    expect(within(sharing).getByText('Kiran Shah')).toBeInTheDocument();
    expect(
      screen.getByText(
        'You see the owner’s totals only. Their individual transactions stay private.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByText(/^Totals as of/)).toBeInTheDocument();
    expect(
      screen.getByText(
        'Only the budget’s owner can see individual transactions. You see the totals.',
      ),
    ).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Edit' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Pause' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Share' })).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Leave budget' }));
    const dialog = await screen.findByRole('dialog', { name: 'Leave this budget?' });
    await user.click(within(dialog).getByRole('button', { name: 'Leave budget' }));
    await findPageHeading('Budgets');
    expect(screen.getByText('You left the budget')).toBeInTheDocument();
    expect(left).toBe(ME);
  });

  it('shows not found, no access and load errors calmly', async () => {
    server.use(
      http.get(`${API}/budgets/:id`, ({ params }) => {
        if (params.id === 'gone') {
          return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
        }
        if (params.id === 'private') {
          return HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 });
        }
        return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
      }),
    );
    const first = renderRoute('/budgets/gone', { user: signedIn() });
    expect(
      await screen.findByRole('heading', { name: 'This budget isn’t available' }),
    ).toBeInTheDocument();
    first.unmount();

    const second = renderRoute('/budgets/private', { user: signedIn() });
    expect(
      await screen.findByRole('heading', { name: 'You don’t have access to this' }),
    ).toBeInTheDocument();
    second.unmount();

    renderRoute('/budgets/broken', { user: signedIn() });
    expect(
      await screen.findByRole('heading', { name: 'We couldn’t load this budget' }),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
  });
});
