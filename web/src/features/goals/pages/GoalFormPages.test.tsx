import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { ACCOUNT_CASH, makeAccount, money } from '@/tests/financeFixtures';
import { GOAL_TRIP, makeContribution, makeForecast, makeGoal } from '@/tests/goalsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { GROUP_ID, makeGroup } from '@/tests/sharingFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

/** Reads for the goal detail page that a successful save navigates to. */
function detailHandlers(goal = makeGoal()) {
  return [
    http.get(`${API}/goals/:id`, () => HttpResponse.json(envelope(goal))),
    http.get(`${API}/goals/:id/forecast`, () => HttpResponse.json(envelope(makeForecast()))),
    http.get(`${API}/goals/:id/contributions`, () =>
      HttpResponse.json(envelope([makeContribution()])),
    ),
  ];
}

describe('GoalCreatePage', () => {
  it('checks the form before calling the API', async () => {
    let posted = false;
    server.use(
      http.post(`${API}/goals`, () => {
        posted = true;
        return HttpResponse.json(envelope(makeGoal()), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/goals/new', { user: signedIn() });
    await findPageHeading('New goal');
    await user.click(await screen.findByRole('button', { name: 'Create goal' }));

    expect(await screen.findByText('Enter a name.')).toBeInTheDocument();
    expect(screen.getByText('Choose a type.')).toBeInTheDocument();
    expect(screen.getByText('Enter an amount.')).toBeInTheDocument();

    // Milestones are whole, distinct percentages.
    const second = screen.getByLabelText('Milestone 2: percent of target');
    await user.clear(second);
    await user.type(second, '25');
    await user.click(screen.getByRole('button', { name: 'Create goal' }));
    expect(
      await screen.findByText('Use a different percentage for each milestone.'),
    ).toBeInTheDocument();
    expect(posted).toBe(false);
  });

  it('creates a goal with exact amounts, a plan and milestones, then opens it', async () => {
    testBackend.accounts = [makeAccount()];
    testBackend.groups = [makeGroup()];
    const bodies: unknown[] = [];
    const keys: (string | null)[] = [];
    server.use(
      http.post(`${API}/goals`, async ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeGoal()), { status: 201 });
      }),
      ...detailHandlers(),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/goals/new', { user: signedIn() });
    await findPageHeading('New goal');

    await user.type(await screen.findByLabelText('Name'), 'Goa trip');
    await user.selectOptions(screen.getByLabelText('Type'), 'Travel');
    await user.type(screen.getByLabelText('Target amount'), '60,000');
    await user.type(screen.getByLabelText(/^Already saved/), '1000.5');
    await user.type(screen.getByLabelText(/^Target date/), '2027-06-30');
    await user.selectOptions(screen.getByLabelText('How often you plan to save'), 'Every month');
    await user.type(await screen.findByLabelText(/^Planned amount each time/), '5000');
    await user.selectOptions(screen.getByLabelText('Priority'), 'High');
    await user.click(screen.getByRole('button', { name: 'Remove milestone 4' }));
    await user.type(screen.getByLabelText(/^Milestone 1: label/), 'First step');
    await user.click(screen.getByLabelText('Remind me to contribute'));
    await user.selectOptions(screen.getByLabelText(/^Linked account/), 'Wallet (INR)');
    await user.selectOptions(screen.getByLabelText(/^Track with a group/), 'Home');
    await user.click(screen.getByLabelText(/Also the members of the group/));
    await user.click(screen.getByRole('button', { name: 'Create goal' }));

    await findPageHeading('Goa trip');
    expect(router.state.location.pathname).toBe(`/goals/${GOAL_TRIP}`);
    expect(screen.getByText('Goal created')).toBeInTheDocument();
    // A financial create: one client-generated key per draft.
    expect(keys).toHaveLength(1);
    expect(keys[0]).toMatch(/^web-.{8,}/);
    expect(bodies).toEqual([
      {
        name: 'Goa trip',
        goal_type: 'travel',
        currency: 'INR',
        target_amount: '60000.00',
        starting_amount: '1000.50',
        start_date: todayInTimeZone('Asia/Kolkata'),
        target_date: '2027-06-30',
        contribution_schedule: 'monthly',
        planned_contribution: '5000.00',
        priority: 2,
        milestones: [{ percent: 25, label: 'First step' }, { percent: 50 }, { percent: 75 }],
        linked_account_id: ACCOUNT_CASH,
        group_id: GROUP_ID,
        visibility: 'members',
        reminders_enabled: true,
      },
    ]);
  });

  it('explains the open-goal limit and retries the same draft with the same key', async () => {
    const keys: (string | null)[] = [];
    server.use(
      http.post(`${API}/goals`, ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        if (keys.length === 1) {
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
        }
        return HttpResponse.json(envelope(makeGoal()), { status: 201 });
      }),
      ...detailHandlers(),
    );
    const user = userEvent.setup();
    renderRoute('/goals/new', { user: signedIn() });
    await findPageHeading('New goal');
    await user.type(await screen.findByLabelText('Name'), 'Goa trip');
    await user.selectOptions(screen.getByLabelText('Type'), 'Travel');
    await user.type(screen.getByLabelText('Target amount'), '60000');
    await user.click(screen.getByRole('button', { name: 'Create goal' }));

    expect(
      await screen.findByText(
        'You can keep up to 200 open goals. Archive goals you no longer need, then try again.',
      ),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Create goal' }));
    await findPageHeading('Goa trip');
    expect(keys).toHaveLength(2);
    expect(keys[1]).toBe(keys[0]);
  });

  it('asks for the planned amount when a schedule is chosen', async () => {
    let posted = false;
    server.use(
      http.post(`${API}/goals`, () => {
        posted = true;
        return HttpResponse.json(envelope(makeGoal()), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/goals/new', { user: signedIn() });
    await findPageHeading('New goal');
    await user.type(await screen.findByLabelText('Name'), 'Goa trip');
    await user.selectOptions(screen.getByLabelText('Type'), 'Travel');
    await user.type(screen.getByLabelText('Target amount'), '60000');
    await user.selectOptions(screen.getByLabelText('How often you plan to save'), 'Every month');
    await user.click(screen.getByRole('button', { name: 'Create goal' }));
    expect(await screen.findByLabelText('Planned amount each time')).toHaveAttribute(
      'aria-invalid',
      'true',
    );
    expect(posted).toBe(false);
  });

  it('shows the API’s field problems next to the fields', async () => {
    server.use(
      http.post(`${API}/goals`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.name', message: 'Use a shorter name.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/goals/new', { user: signedIn() });
    await findPageHeading('New goal');
    await user.type(await screen.findByLabelText('Name'), 'Fund');
    await user.selectOptions(screen.getByLabelText('Type'), 'Emergency fund');
    await user.type(screen.getByLabelText('Target amount'), '100000');
    await user.click(screen.getByRole('button', { name: 'Create goal' }));
    expect(await screen.findByText('Use a shorter name.')).toBeInTheDocument();
    expect(screen.getByLabelText('Name')).toHaveAttribute('aria-invalid', 'true');
  });
});

describe('GoalEditPage', () => {
  it('sends only what changed, with its version, and clears removed links', async () => {
    const goal = makeGoal({
      group_id: GROUP_ID,
      visibility: 'members',
      linked_account_id: ACCOUNT_CASH,
      notes: 'Book early',
      starting: money('1000.00'),
    });
    testBackend.accounts = [makeAccount()];
    testBackend.groups = [makeGroup()];
    const bodies: unknown[] = [];
    server.use(
      http.patch(`${API}/goals/:id`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeGoal({ name: 'Goa trip 2027', version: 5 })));
      }),
      ...detailHandlers(goal),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`/goals/${GOAL_TRIP}/edit`, { user: signedIn() });
    await findPageHeading('Edit goal');

    const name = await screen.findByLabelText('Name');
    expect(name).toHaveValue('Goa trip');
    expect(screen.getByLabelText('Currency')).toBeDisabled();
    expect(screen.getByText('The currency can’t change after the goal is created.')).toBeVisible();
    await user.clear(name);
    await user.type(name, 'Goa trip 2027');
    await user.clear(screen.getByLabelText(/^Notes/));
    await user.selectOptions(screen.getByLabelText(/^Linked account/), 'None');
    await user.selectOptions(screen.getByLabelText(/^Track with a group/), 'None');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/goals/${GOAL_TRIP}`);
    });
    expect(await screen.findByText('Goal updated')).toBeInTheDocument();
    // Untouched fields (amounts, dates, milestones) are left out and keep their values.
    expect(bodies).toEqual([
      {
        version: 4,
        name: 'Goa trip 2027',
        visibility: 'private',
        notes: '',
        clear: ['linked_account_id', 'group_id'],
      },
    ]);
  });

  it('goes back without a request when nothing changed', async () => {
    let patched = false;
    server.use(
      http.patch(`${API}/goals/:id`, () => {
        patched = true;
        return HttpResponse.json(envelope(makeGoal()));
      }),
      ...detailHandlers(),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`/goals/${GOAL_TRIP}/edit`, { user: signedIn() });
    await findPageHeading('Edit goal');
    await user.click(await screen.findByRole('button', { name: 'Save changes' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/goals/${GOAL_TRIP}`);
    });
    expect(await screen.findByText('No changes to save')).toBeInTheDocument();
    expect(patched).toBe(false);
  });

  it('reloads after a version conflict and saves with the new version', async () => {
    let version = 4;
    const bodies: { version?: number; name?: string }[] = [];
    server.use(
      http.get(`${API}/goals/:id`, () =>
        HttpResponse.json(
          envelope(makeGoal({ version, name: version === 4 ? 'Goa trip' : 'Goa trip (family)' })),
        ),
      ),
      http.patch(`${API}/goals/:id`, async ({ request }) => {
        const body = (await request.json()) as { version?: number; name?: string };
        bodies.push(body);
        if (body.version === 4) {
          version = 5;
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeGoal({ version: 6 })));
      }),
      http.get(`${API}/goals/:id/forecast`, () => HttpResponse.json(envelope(makeForecast()))),
      http.get(`${API}/goals/:id/contributions`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    renderRoute(`/goals/${GOAL_TRIP}/edit`, { user: signedIn() });
    await findPageHeading('Edit goal');
    await user.type(await screen.findByLabelText(/^What it’s for/), 'Beach week');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    expect(
      screen.getByText(/We loaded the latest version; check it and save again\./),
    ).toBeVisible();
    await waitFor(() => {
      expect(screen.getByLabelText('Name')).toHaveValue('Goa trip (family)');
    });
    // The form starts again from the latest goal: the change is made again.
    await user.type(screen.getByLabelText(/^What it’s for/), 'Beach week');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Goal updated')).toBeInTheDocument();
    expect(bodies).toEqual([
      { version: 4, description: 'Beach week' },
      { version: 5, description: 'Beach week' },
    ]);
  });

  it('lets only the owner edit', async () => {
    server.use(
      http.get(`${API}/goals/:id`, () =>
        HttpResponse.json(envelope(makeGoal({ access: 'contributor' }))),
      ),
    );
    renderRoute(`/goals/${GOAL_TRIP}/edit`, { user: signedIn() });
    await findPageHeading('Edit goal');
    expect(await screen.findByText('Only the owner can change this goal')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Save changes' })).not.toBeInTheDocument();
  });

  it('says when the goal no longer exists', async () => {
    server.use(
      http.get(`${API}/goals/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(`/goals/${GOAL_TRIP}/edit`, { user: signedIn() });
    await findPageHeading('Edit goal');
    expect(await screen.findByText('Goal not found')).toBeInTheDocument();
    for (const link of screen.getAllByRole('link', { name: 'All goals' })) {
      expect(link).toHaveAttribute('href', '/goals');
    }
  });
});
