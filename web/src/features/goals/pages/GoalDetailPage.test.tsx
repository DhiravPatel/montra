import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import type { Goal, GoalContribution } from '@/shared/finance/types';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { API, envelope, errorBody, makeUser, meta } from '@/tests/fixtures';
import { makeTransaction, money } from '@/tests/financeFixtures';
import {
  CONTRIBUTION_FRIEND,
  CONTRIBUTION_HIDDEN,
  CONTRIBUTION_MINE,
  CONTRIBUTION_PLANNED,
  CONTRIBUTION_WITHDRAWAL,
  GOAL_TRIP,
  ME,
  TX_TO_SAVINGS,
  makeContribution,
  makeForecast,
  makeGoal,
  makeGoalMember,
  makeGoalReport,
  makeOwnerMember,
  makeSharedGoal,
} from '@/tests/goalsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { FRIEND_ID, GROUP_MEMBER_ID, makeFriend } from '@/tests/sharingFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

/** Read handlers for one goal; `current` lets a test change what the API returns. */
function serveGoal(
  initial: Goal = makeGoal(),
  contributions: GoalContribution[] = [makeContribution()],
) {
  const state = { goal: initial };
  server.use(
    http.get(`${API}/goals/:id`, () => HttpResponse.json(envelope(state.goal))),
    http.get(`${API}/goals/:id/forecast`, () => HttpResponse.json(envelope(makeForecast()))),
    http.get(`${API}/goals/:id/contributions`, () => HttpResponse.json(envelope(contributions))),
  );
  return state;
}

function region(name: string) {
  return screen.getByRole('region', { name });
}

describe('GoalDetailPage', () => {
  it('shows progress, milestones, the outlook and contributions as the API reports them', async () => {
    serveGoal(makeGoal(), [
      makeContribution({
        id: CONTRIBUTION_MINE,
        status: 'verified',
        transaction_id: TX_TO_SAVINGS,
        amount: money('3000.00'),
        note: 'Salary day',
      }),
      makeContribution({
        id: CONTRIBUTION_FRIEND,
        user_id: FRIEND_ID,
        display_name: 'Ravi Kumar',
        mine: false,
        amount: undefined,
        percent_bp: 117,
      }),
      makeContribution({
        id: CONTRIBUTION_PLANNED,
        status: 'planned',
        amount: money('2000.00'),
        contributed_on: '2026-12-01',
      }),
      makeContribution({
        id: CONTRIBUTION_WITHDRAWAL,
        kind: 'withdrawal',
        amount: money('500.00'),
        voided: true,
      }),
      makeContribution({
        id: CONTRIBUTION_HIDDEN,
        user_id: GROUP_MEMBER_ID,
        display_name: 'Meera Rao',
        mine: false,
        amount: undefined,
      }),
    ]);
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    expect(document.title).not.toMatch(/Goa trip/);

    const progress = region('Progress');
    expect(within(progress).getByRole('meter', { name: 'Goa trip' })).toHaveAttribute(
      'aria-valuetext',
      '₹6,000.00 of ₹60,000.00 saved (10%)',
    );
    expect(within(progress).getByText('Verified by linked transactions')).toBeInTheDocument();
    expect(within(progress).getByText('₹3,000.00')).toBeInTheDocument();
    expect(within(progress).getByText('Planned, not counted yet')).toBeInTheDocument();
    expect(within(progress).getByText('₹2,000.00')).toBeInTheDocument();
    expect(within(progress).getByText('First step · 10% of target')).toBeInTheDocument();
    expect(within(progress).getByText(/^Reached /)).toBeInTheDocument();
    expect(within(progress).getAllByText('Not reached yet')).toHaveLength(2);

    const outlook = region('Outlook');
    expect(await within(outlook).findByText('₹7,714.29')).toBeInTheDocument();
    expect(within(outlook).getByText('₹1,666.67 a month')).toBeInTheDocument();
    expect(within(outlook).getByText(/^Around .*2029$/)).toBeInTheDocument();
    expect(within(outlook).getByText(/^237 days left until /)).toBeInTheDocument();
    expect(
      within(outlook).getByText(/you can also adjust the plan or the date\.$/),
    ).toBeInTheDocument();
    await user.click(within(outlook).getByRole('button', { name: 'How we estimate this' }));
    expect(
      within(outlook).getByText(
        'Amounts are exact in INR. No interest, returns or inflation are assumed.',
      ),
    ).toBeVisible();
    expect(
      within(outlook).getByText(
        'Recent pace is what was recorded or verified in the last 90 days, minus withdrawals, divided by 3.',
      ),
    ).toBeVisible();

    const contributions = region('Contributions');
    expect(await within(contributions).findByText('Salary day')).toBeInTheDocument();
    expect(within(contributions).getByText('Verified')).toBeInTheDocument();
    expect(within(contributions).getByText('Planned · not counted yet')).toBeInTheDocument();
    expect(within(contributions).getByText('Voided')).toBeInTheDocument();
    expect(within(contributions).getByText('1.2% of target')).toBeInTheDocument();
    expect(within(contributions).getByText('Amount kept private')).toBeInTheDocument();
    expect(within(contributions).getByRole('link', { name: 'View transaction' })).toHaveAttribute(
      'href',
      `/transactions/${TX_TO_SAVINGS}`,
    );
    // Only your own contributions can be voided, and not twice.
    expect(
      within(contributions).getAllByRole('button', { name: /^Void the contribution/ }),
    ).toHaveLength(2);
  });

  it('records a contribution linked to a ledger transaction, with an idempotency key', async () => {
    serveGoal();
    const transaction = makeTransaction({
      id: TX_TO_SAVINGS,
      description: 'Moved to savings',
      merchant: undefined,
      amount: money('3000.00'),
    });
    const searches: (string | null)[] = [];
    const posts: { key: string | null; body: unknown }[] = [];
    server.use(
      http.get(`${API}/transactions`, ({ request }) => {
        searches.push(new URL(request.url).searchParams.get('type'));
        return HttpResponse.json(envelope([transaction]));
      }),
      http.get(`${API}/transactions/:id`, () => HttpResponse.json(envelope(transaction))),
      http.post(`${API}/goals/:id/contributions`, async ({ request }) => {
        posts.push({ key: request.headers.get('Idempotency-Key'), body: await request.json() });
        return HttpResponse.json(
          envelope(makeContribution({ status: 'verified', transaction_id: TX_TO_SAVINGS })),
          { status: 201 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');

    await user.click(screen.getAllByRole('button', { name: 'Add contribution' })[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Add to this goal' });
    await user.click(within(dialog).getByRole('button', { name: 'Choose transaction' }));
    const picker = await screen.findByRole('dialog', { name: 'Link a transaction' });
    await user.click(await within(picker).findByRole('radio', { name: /Moved to savings/ }));
    await user.click(within(picker).getByRole('button', { name: 'Link transaction' }));

    expect(await within(dialog).findByText('This will be saved as verified.')).toBeInTheDocument();
    expect(within(dialog).getByLabelText('Amount')).toHaveValue('3000.00');
    // A linked transaction is an actual movement: no date or "planned" choice.
    expect(within(dialog).queryByLabelText('Date')).not.toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Add' }));

    expect(await screen.findByText('Contribution added')).toBeInTheDocument();
    expect(searches).toEqual(['transfer,expense']);
    expect(posts).toHaveLength(1);
    expect(posts[0]!.key).toMatch(/^web-/);
    expect(posts[0]!.body).toEqual({
      amount: '3000.00',
      kind: 'contribution',
      transaction_id: TX_TO_SAVINGS,
    });
  });

  it('explains a withdrawal larger than the amount saved, then retries the same draft', async () => {
    serveGoal();
    const posts: { key: string | null; body: unknown }[] = [];
    server.use(
      http.post(`${API}/goals/:id/contributions`, async ({ request }) => {
        posts.push({ key: request.headers.get('Idempotency-Key'), body: await request.json() });
        if (posts.length === 1) {
          return HttpResponse.json(
            {
              error: {
                code: 'DOMAIN_RULE_VIOLATION',
                message: 'A withdrawal cannot exceed the amount saved (6000.00).',
                details: [
                  {
                    message: 'A withdrawal cannot exceed the amount saved (6000.00).',
                    code: 'withdrawal_exceeds_saved',
                    params: { currency: 'INR', saved: '6000.00' },
                  },
                ],
                request_id: 'req-withdrawal',
              },
            },
            { status: 422 },
          );
        }
        return HttpResponse.json(envelope(makeContribution({ kind: 'withdrawal' })), {
          status: 201,
        });
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await user.click(screen.getAllByRole('button', { name: 'Add contribution' })[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Add to this goal' });
    await user.click(within(dialog).getByLabelText('I took money out'));
    await user.type(within(dialog).getByLabelText('Amount'), '7000');
    await user.click(within(dialog).getByRole('button', { name: 'Add' }));

    expect(
      await within(dialog).findByText(
        'You can take out at most ₹6,000.00, the amount saved so far.',
      ),
    ).toBeInTheDocument();
    const amount = within(dialog).getByLabelText('Amount');
    await user.clear(amount);
    await user.type(amount, '500');
    await user.click(within(dialog).getByRole('button', { name: 'Add' }));

    expect(await screen.findByText('Withdrawal recorded')).toBeInTheDocument();
    expect(posts.map((post) => post.key)).toEqual([posts[0]!.key, posts[0]!.key]);
    expect(posts[1]!.body).toEqual({
      amount: '500.00',
      kind: 'withdrawal',
      status: 'recorded',
      contributed_on: todayInTimeZone('Asia/Kolkata'),
    });
  });

  it('voids your own contribution after confirmation', async () => {
    serveGoal();
    let voided = '';
    server.use(
      http.post(`${API}/goals/:id/contributions/:contributionId/void`, ({ params }) => {
        voided = String(params.contributionId);
        return HttpResponse.json(envelope(makeGoal({ version: 5 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await user.click(await screen.findByRole('button', { name: /^Void the contribution from / }));
    const dialog = await screen.findByRole('dialog', { name: 'Void this contribution?' });
    await user.click(within(dialog).getByRole('button', { name: 'Void contribution' }));
    expect(await screen.findByText('Contribution voided')).toBeInTheDocument();
    expect(voided).toBe(CONTRIBUTION_MINE);
  });

  it('pauses an active goal after confirmation', async () => {
    const state = serveGoal();
    const calls: string[] = [];
    server.use(
      http.post(`${API}/goals/:id/pause`, ({ request }) => {
        calls.push(`pause ${new URL(request.url).search}`);
        state.goal = makeGoal({ status: 'paused', version: 5 });
        return HttpResponse.json(envelope(state.goal));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    const manage = region('Manage');
    expect(within(manage).getByRole('button', { name: 'Mark as achieved' })).toBeInTheDocument();
    await user.click(within(manage).getByRole('button', { name: 'Pause' }));
    const dialog = await screen.findByRole('dialog', { name: 'Pause this goal?' });
    await user.click(within(dialog).getByRole('button', { name: 'Pause goal' }));

    expect(await screen.findByText('Goal paused')).toBeInTheDocument();
    // The version on screen, so a goal changed elsewhere is not acted on blindly.
    expect(calls).toEqual(['pause ?version=4']);
    expect(
      await screen.findByText('This goal is paused. Contributions are on hold until it’s resumed.'),
    ).toBeInTheDocument();
    expect(within(region('Manage')).getByRole('button', { name: 'Resume' })).toBeInTheDocument();
    // Contributions wait until the goal is active again.
    expect(screen.queryByRole('button', { name: 'Add contribution' })).not.toBeInTheDocument();
  });

  it('explains a status that changed elsewhere and loads the current goal', async () => {
    let reads = 0;
    server.use(
      http.get(`${API}/goals/:id`, () => {
        reads += 1;
        return HttpResponse.json(
          envelope(reads === 1 ? makeGoal() : makeGoal({ status: 'archived', version: 5 })),
        );
      }),
      http.get(`${API}/goals/:id/forecast`, () => HttpResponse.json(envelope(makeForecast()))),
      http.get(`${API}/goals/:id/contributions`, () => HttpResponse.json(envelope([]))),
      http.post(`${API}/goals/:id/pause`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: 'A goal cannot move from archived to paused.',
                code: 'invalid_status_transition',
                params: { from: 'archived', to: 'paused' },
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await user.click(within(region('Manage')).getByRole('button', { name: 'Pause' }));
    const dialog = await screen.findByRole('dialog', { name: 'Pause this goal?' });
    await user.click(within(dialog).getByRole('button', { name: 'Pause goal' }));

    expect(
      await within(dialog).findByText(
        'This can’t change from archived to paused. Its status may have changed somewhere else, so we’ve loaded the latest version.',
      ),
    ).toBeInTheDocument();
    expect(
      await screen.findByText('This goal is archived. Its history is kept.'),
    ).toBeInTheDocument();
    expect(reads).toBe(2);
  });

  it('says when restoring would go past the open-goal limit', async () => {
    serveGoal(makeGoal({ status: 'archived' }));
    const searches: string[] = [];
    server.use(
      http.post(`${API}/goals/:id/resume`, ({ request }) => {
        searches.push(new URL(request.url).search);
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: 'You can keep up to 200 of these.',
                code: 'record_limit_reached',
                params: { resource: 'goals', limit: '200' },
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await user.click(within(region('Manage')).getByRole('button', { name: 'Restore' }));
    const dialog = await screen.findByRole('dialog', { name: 'Restore this goal?' });
    await user.click(within(dialog).getByRole('button', { name: 'Restore goal' }));
    expect(
      await within(dialog).findByText(
        'You can keep up to 200 open goals. Archive goals you no longer need, then try again.',
      ),
    ).toBeInTheDocument();
    expect(searches).toEqual(['?version=4']);
  });

  it('restores an archived goal', async () => {
    const state = serveGoal(makeGoal({ status: 'archived' }));
    server.use(
      http.post(`${API}/goals/:id/resume`, () => {
        state.goal = makeGoal({ status: 'active', version: 5 });
        return HttpResponse.json(envelope(state.goal));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    expect(screen.getByText('This goal is archived. Its history is kept.')).toBeInTheDocument();
    await user.click(within(region('Manage')).getByRole('button', { name: 'Restore' }));
    const dialog = await screen.findByRole('dialog', { name: 'Restore this goal?' });
    await user.click(within(dialog).getByRole('button', { name: 'Restore goal' }));
    expect(await screen.findByText('Goal restored')).toBeInTheDocument();
  });

  it('lists the owner first and lets the owner share the goal, change a role and remove a member', async () => {
    testBackend.people = [makeFriend()];
    const state = serveGoal(makeGoal(), []);
    const requests: { method: string; version: string | null; body?: unknown }[] = [];
    const version = (request: Request) => new URL(request.url).searchParams.get('version');
    server.use(
      http.post(`${API}/goals/:id/members`, async ({ request }) => {
        requests.push({ method: 'POST', version: version(request), body: await request.json() });
        state.goal = makeGoal({
          members: [makeOwnerMember(), makeGoalMember({ role: 'viewer' })],
          version: 5,
        });
        return HttpResponse.json(envelope(state.goal));
      }),
      http.patch(`${API}/goals/:id/members/:userId`, async ({ request, params }) => {
        requests.push({
          method: `PATCH ${String(params.userId)}`,
          version: version(request),
          body: await request.json(),
        });
        state.goal = makeGoal({
          members: [makeOwnerMember(), makeGoalMember({ role: 'contributor' })],
          version: 6,
        });
        return HttpResponse.json(envelope(state.goal));
      }),
      http.delete(`${API}/goals/:id/members/:userId`, ({ request, params }) => {
        requests.push({ method: `DELETE ${String(params.userId)}`, version: version(request) });
        state.goal = makeGoal({ members: [makeOwnerMember()], version: 7 });
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    const people = region('People');
    // The API lists the owner first (role owner); its role and place are fixed.
    expect(within(people).getByText('Asha Rao (you)')).toBeInTheDocument();
    expect(within(people).getByText('Owner · Shares amounts')).toBeInTheDocument();
    expect(within(people).getByText('Only you can see this goal.')).toBeInTheDocument();
    expect(within(people).queryByLabelText('Role for Asha Rao')).not.toBeInTheDocument();
    expect(
      within(people).queryByRole('button', { name: 'Remove Asha Rao' }),
    ).not.toBeInTheDocument();
    expect(within(people).queryByRole('button', { name: 'Leave goal' })).not.toBeInTheDocument();

    await user.click(within(people).getByRole('button', { name: 'Add person' }));
    const dialog = await screen.findByRole('dialog', { name: 'Share this goal' });
    await user.selectOptions(
      await within(dialog).findByLabelText('Person'),
      'Ravi Kumar (@ravi) · Friend',
    );
    await user.click(within(dialog).getByLabelText(/^Viewer/));
    await user.click(within(dialog).getByRole('button', { name: 'Share goal' }));
    expect(await screen.findByText('Goal shared')).toBeInTheDocument();
    expect(await within(people).findByText('Viewer · Shares amounts')).toBeInTheDocument();

    await user.selectOptions(within(people).getByLabelText('Role for Ravi Kumar'), 'Contributor');
    // Choosing an option does not save by itself (arrow keys move through options).
    expect(requests).toHaveLength(1);
    await user.click(within(people).getByRole('button', { name: 'Save role' }));
    expect(await screen.findByText('Role updated')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(people).queryByRole('button', { name: 'Save role' })).not.toBeInTheDocument();
    });

    await user.click(within(people).getByRole('button', { name: 'Remove Ravi Kumar' }));
    const confirm = await screen.findByRole('dialog', { name: 'Remove Ravi Kumar?' });
    await user.click(within(confirm).getByRole('button', { name: 'Remove' }));
    expect(await screen.findByText('Removed from the goal')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(people).queryByText('Ravi Kumar')).not.toBeInTheDocument();
    });

    // Each change sends the version on screen.
    expect(requests).toEqual([
      { method: 'POST', version: '4', body: { user_id: FRIEND_ID, role: 'viewer' } },
      { method: `PATCH ${FRIEND_ID}`, version: '5', body: { role: 'contributor' } },
      { method: `DELETE ${FRIEND_ID}`, version: '6' },
    ]);
  });

  it('lets the owner choose what others see of their own contributions', async () => {
    const state = serveGoal(makeGoal(), []);
    const requests: { path: string; version: string | null; body: unknown }[] = [];
    server.use(
      http.patch(`${API}/goals/:id/members/:userId`, async ({ request, params }) => {
        requests.push({
          path: String(params.userId),
          version: new URL(request.url).searchParams.get('version'),
          body: await request.json(),
        });
        state.goal = makeGoal({
          members: [makeOwnerMember({ contribution_visibility: 'hidden' })],
          version: 5,
        });
        return HttpResponse.json(envelope(state.goal));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    const people = region('People');
    expect(
      within(people).getByText(
        'As the owner, you stay on this goal. To stop tracking it, archive it.',
      ),
    ).toBeInTheDocument();
    await user.selectOptions(
      within(people).getByLabelText('What others see of your contributions'),
      'Nothing (kept private)',
    );
    await user.click(within(people).getByRole('button', { name: 'Save choice' }));
    expect(await screen.findByText('Your choice is saved')).toBeInTheDocument();
    expect(await within(people).findByText('Owner · Keeps contributions private')).toBeVisible();
    expect(requests).toEqual([
      { path: ME, version: '4', body: { contribution_visibility: 'hidden' } },
    ]);
  });

  it('explains who a goal can be shared with when the API refuses someone', async () => {
    testBackend.people = [makeFriend()];
    serveGoal(makeGoal(), []);
    server.use(
      http.post(`${API}/goals/:id/members`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.user_id',
                message: 'You can only share goals with friends or group members.',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await user.click(within(region('People')).getByRole('button', { name: 'Add person' }));
    const dialog = await screen.findByRole('dialog', { name: 'Share this goal' });
    await user.selectOptions(
      await within(dialog).findByLabelText('Person'),
      'Ravi Kumar (@ravi) · Friend',
    );
    await user.click(within(dialog).getByRole('button', { name: 'Share goal' }));
    expect(
      await within(dialog).findByText(
        'You can share goals only with friends or members of the goal’s group.',
      ),
    ).toBeInTheDocument();
  });

  it('lets a contributor choose what others see and leave the goal', async () => {
    const state = serveGoal(makeSharedGoal('contributor'), []);
    const requests: { method: string; version: string | null; body?: unknown }[] = [];
    server.use(
      http.patch(`${API}/goals/:id/members/:userId`, async ({ request, params }) => {
        requests.push({
          method: `PATCH ${String(params.userId)}`,
          version: new URL(request.url).searchParams.get('version'),
          body: await request.json(),
        });
        state.goal = makeSharedGoal(
          'contributor',
          { contribution_visibility: 'percent_only' },
          { version: 5 },
        );
        return HttpResponse.json(envelope(state.goal));
      }),
      http.delete(`${API}/goals/:id/members/:userId`, ({ request, params }) => {
        requests.push({
          method: `DELETE ${String(params.userId)}`,
          version: new URL(request.url).searchParams.get('version'),
        });
        return HttpResponse.json(envelope({ ok: true }));
      }),
      http.get(`${API}/goals`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/analytics/goals`, () =>
        HttpResponse.json(envelope(makeGoalReport({ goals: [], totals: [] }))),
      ),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    expect(screen.getByText('You can contribute to this goal')).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Edit goal' })).not.toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Manage' })).not.toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: 'Add contribution' }).length).toBeGreaterThan(0);

    const people = region('People');
    expect(within(people).getByText('Kiran Shah')).toBeInTheDocument();
    expect(within(people).getByText('Owner · Shares amounts')).toBeInTheDocument();
    expect(within(people).getByText('Asha Rao (you)')).toBeInTheDocument();
    await user.selectOptions(
      within(people).getByLabelText('What others see of your contributions'),
      'Only the share of the target',
    );
    await user.click(within(people).getByRole('button', { name: 'Save choice' }));
    expect(await screen.findByText('Your choice is saved')).toBeInTheDocument();

    await user.click(within(people).getByRole('button', { name: 'Leave goal' }));
    const confirm = await screen.findByRole('dialog', { name: 'Leave this goal?' });
    await user.click(within(confirm).getByRole('button', { name: 'Leave goal' }));
    await findPageHeading('Goals');
    expect(router.state.location.pathname).toBe('/goals');
    expect(screen.getByText('You left the goal')).toBeInTheDocument();
    expect(requests).toEqual([
      {
        method: `PATCH ${ME}`,
        version: '4',
        body: { contribution_visibility: 'percent_only' },
      },
      { method: `DELETE ${ME}`, version: '5' },
    ]);
  });

  it('names the owner neutrally when their profile is not visible', async () => {
    serveGoal(
      makeSharedGoal(
        'viewer',
        {},
        {
          owner: { user_id: 'c0c0c0c0-3333-4333-8333-000000000001' },
        },
      ),
      [],
    );
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    const people = region('People');
    expect(within(people).getByText('The goal’s owner')).toBeInTheDocument();
    expect(within(people).queryByText('Kiran Shah')).not.toBeInTheDocument();
  });

  it('lets a viewer follow along without changing anything', async () => {
    serveGoal(makeSharedGoal('viewer'), [
      makeContribution({
        id: CONTRIBUTION_FRIEND,
        user_id: FRIEND_ID,
        display_name: 'Ravi Kumar',
        mine: false,
      }),
    ]);
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    expect(screen.getByText('You can view this goal')).toBeInTheDocument();
    expect(screen.getByText('Shared with you · View only')).toBeInTheDocument();
    expect(await screen.findByText(/Ravi Kumar/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Add contribution' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Edit goal' })).not.toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Manage' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Void/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Add person' })).not.toBeInTheDocument();
  });

  it('downloads the CSV under the server’s neutral file name, never the goal’s', async () => {
    serveGoal();
    const names = [
      'attachment; filename="goal-contributions-2026-11-04.csv"',
      // Anything else (e.g. a name carrying the goal's name) is replaced.
      'attachment; filename="goa-trip-contributions.csv"',
    ];
    let calls = 0;
    server.use(
      http.get(`${API}/goals/:id/export`, () => {
        const disposition = names[calls] ?? '';
        calls += 1;
        return new HttpResponse('date,contributor,kind,status,amount,currency\n', {
          headers: {
            'Content-Type': 'text/csv; charset=utf-8',
            'Content-Disposition': disposition,
          },
        });
      }),
    );
    const blobs: Blob[] = [];
    const saved: string[] = [];
    Object.assign(URL, {
      createObjectURL: vi.fn((blob: Blob) => {
        blobs.push(blob);
        return 'blob:goal-export';
      }),
      revokeObjectURL: vi.fn(),
    });
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (
      this: HTMLAnchorElement,
    ) {
      saved.push(this.download);
    });
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await user.click(screen.getByRole('button', { name: 'Download CSV' }));
    expect(await screen.findByText('Download started')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Download CSV' }));
    await waitFor(() => {
      expect(saved).toHaveLength(2);
    });

    expect(saved[0]).toBe('goal-contributions-2026-11-04.csv');
    expect(saved[1]).toBe(`goal-contributions-${todayInTimeZone('Asia/Kolkata')}.csv`);
    expect(blobs[0]!.type).toBe('text/csv;charset=utf-8');
    expect(await blobs[0]!.text()).toBe('date,contributor,kind,status,amount,currency\n');
    click.mockRestore();
  });

  it('records a planned contribution once, with an idempotency key kept for retries', async () => {
    serveGoal(makeGoal(), [
      makeContribution({
        id: CONTRIBUTION_PLANNED,
        status: 'planned',
        amount: money('2000.00'),
        contributed_on: '2026-11-01',
      }),
    ]);
    const posts: { path: string; key: string | null; body: unknown }[] = [];
    server.use(
      http.post(
        `${API}/goals/:id/contributions/:contributionId/record`,
        async ({ request, params }) => {
          posts.push({
            path: String(params.contributionId),
            key: request.headers.get('Idempotency-Key'),
            body: await request.json(),
          });
          if (posts.length === 1) {
            return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
          }
          return HttpResponse.json(
            envelope(makeContribution({ id: CONTRIBUTION_PLANNED, status: 'recorded' })),
          );
        },
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await user.click(
      await screen.findByRole('button', { name: /^Record the planned contribution from / }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Record this planned contribution' });
    expect(within(dialog).getByLabelText('Amount set aside')).toHaveValue('2000.00');
    expect(within(dialog).getByLabelText('Date')).toHaveValue(todayInTimeZone('Asia/Kolkata'));
    await user.click(within(dialog).getByRole('button', { name: 'Record' }));
    expect(await within(dialog).findByRole('alert')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Record' }));

    expect(await screen.findByText('Contribution recorded')).toBeInTheDocument();
    expect(posts).toHaveLength(2);
    expect(posts[0]!.key).toMatch(/^web-/);
    expect(posts[1]!.key).toBe(posts[0]!.key);
    // The planned amount is the default, so only the date is sent.
    expect(posts[1]).toEqual({
      path: CONTRIBUTION_PLANNED,
      key: posts[0]!.key,
      body: { contributed_on: todayInTimeZone('Asia/Kolkata') },
    });
  });

  it('explains a planned contribution that was already recorded and refreshes the list', async () => {
    let lists = 0;
    server.use(
      http.get(`${API}/goals/:id`, () => HttpResponse.json(envelope(makeGoal()))),
      http.get(`${API}/goals/:id/forecast`, () => HttpResponse.json(envelope(makeForecast()))),
      http.get(`${API}/goals/:id/contributions`, () => {
        lists += 1;
        return HttpResponse.json(
          envelope([
            makeContribution({
              id: CONTRIBUTION_PLANNED,
              status: lists === 1 ? 'planned' : 'recorded',
              amount: money('2000.00'),
            }),
          ]),
        );
      }),
      http.post(`${API}/goals/:id/contributions/:contributionId/record`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                message: 'This contribution is already recorded.',
                code: 'contribution_not_planned',
                params: { status: 'recorded' },
              },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await user.click(
      await screen.findByRole('button', { name: /^Record the planned contribution from / }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Record this planned contribution' });
    const amount = within(dialog).getByLabelText('Amount set aside');
    await user.clear(amount);
    await user.type(amount, '2500');
    await user.click(within(dialog).getByRole('button', { name: 'Record' }));
    expect(
      await within(dialog).findByText(
        'This contribution is already recorded. We’ve refreshed the list.',
      ),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(lists).toBe(2);
    });
  });

  it('loads older contributions page by page', async () => {
    const cursors: (string | null)[] = [];
    server.use(
      http.get(`${API}/goals/:id`, () => HttpResponse.json(envelope(makeGoal()))),
      http.get(`${API}/goals/:id/forecast`, () => HttpResponse.json(envelope(makeForecast()))),
      http.get(`${API}/goals/:id/contributions`, ({ request }) => {
        const cursor = new URL(request.url).searchParams.get('cursor');
        cursors.push(cursor);
        if (!cursor) {
          return HttpResponse.json({
            data: [makeContribution({ note: 'Newest one' })],
            meta: { ...meta(), has_more: true, next_cursor: 'page-2' },
          });
        }
        if (cursors.length === 2) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json({
          data: [
            makeContribution({
              id: CONTRIBUTION_WITHDRAWAL,
              note: 'Oldest one',
              contributed_on: '2026-11-02',
            }),
          ],
          meta: { ...meta(), has_more: false },
        });
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    const contributions = region('Contributions');
    expect(await within(contributions).findByText('Newest one')).toBeInTheDocument();
    expect(within(contributions).queryByText('Oldest one')).not.toBeInTheDocument();
    await user.click(within(contributions).getByRole('button', { name: 'Load more' }));
    // A failed page keeps what is shown and offers the button again.
    expect(
      await within(contributions).findByText('We couldn’t load more. Try again.'),
    ).toBeInTheDocument();
    expect(within(contributions).getByText('Newest one')).toBeInTheDocument();
    await user.click(within(contributions).getByRole('button', { name: 'Load more' }));
    expect(await within(contributions).findByText('Oldest one')).toBeInTheDocument();
    expect(within(contributions).getByText('Newest one')).toBeInTheDocument();
    await waitFor(() => {
      expect(
        within(contributions).queryByRole('button', { name: 'Load more' }),
      ).not.toBeInTheDocument();
    });
    expect(cursors).toEqual([null, 'page-2', 'page-2']);
  });

  it('says when the goal does not exist or is no longer shared', async () => {
    server.use(
      http.get(`${API}/goals/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goal');
    expect(await screen.findByText('Goal not found')).toBeInTheDocument();
  });

  it('shows a recoverable error and a permission message', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/goals/:id`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-goal' }), {
              status: 500,
            })
          : HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    expect(await screen.findByText('We couldn’t load this goal')).toBeInTheDocument();
    expect(screen.getByText('req-goal')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
