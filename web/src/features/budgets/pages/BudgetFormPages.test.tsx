import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import {
  BUDGET_ID,
  makeBudget,
  makeProgress,
  makeSharedBudget,
  previousProgress,
} from '@/tests/budgetsFixtures';
import { CATEGORY_GROCERIES, makeAccount, money, starterCategories } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { GROUP_ID, GROUP_MEMBER_ID, makeGroup, makeGroupDetail } from '@/tests/sharingFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

/** Reads made by the budget page that opens after saving. */
function detailReads() {
  return [
    http.get(`${API}/budgets/:id/progress`, () =>
      HttpResponse.json(envelope([makeProgress(), previousProgress()])),
    ),
    http.get(`${API}/budgets/:id/transactions`, () => HttpResponse.json(envelope([]))),
    http.get(`${API}/budget-alerts`, () => HttpResponse.json(envelope([]))),
  ];
}

/** Every value of a select, in order. */
function optionValues(select: HTMLElement): string[] {
  return within(select)
    .getAllByRole('option')
    .map((option) => (option as HTMLOptionElement).value);
}

const DATE = /^\d{4}-\d{2}-\d{2}$/;

describe('BudgetCreatePage', () => {
  it('creates a category budget with an allocation and opens it', async () => {
    testBackend.categories = starterCategories();
    testBackend.accounts = [makeAccount()];
    let body: Record<string, unknown> = {};
    server.use(
      http.post(`${API}/budgets`, async ({ request }) => {
        body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope(makeBudget()), { status: 201 });
      }),
      ...detailReads(),
    );
    const user = userEvent.setup();
    renderRoute('/budgets/new', { user: signedIn() });
    await findPageHeading('Create a budget');

    await user.type(await screen.findByLabelText('Name'), 'Food');
    await user.click(screen.getByRole('radio', { name: /^By category/ }));
    await user.type(screen.getByLabelText('Limit for each period'), '5000');
    await user.click(screen.getByRole('button', { name: 'Add allocation' }));
    const allocation = screen.getByRole('group', { name: 'Allocation 1' });
    await user.selectOptions(within(allocation).getByLabelText('Category'), CATEGORY_GROCERIES);
    await user.type(within(allocation).getByLabelText('Limit'), '3000');
    await user.click(screen.getByRole('button', { name: 'Create budget' }));

    await findPageHeading('Food');
    expect(screen.getByText('Budget created')).toBeInTheDocument();
    const { starts_on: startsOn, ...rest } = body;
    expect(startsOn).toMatch(DATE);
    expect(rest).toEqual({
      name: 'Food',
      budget_type: 'category',
      period: 'monthly',
      currency: 'INR',
      limit: '5000.00',
      rollover_policy: 'none',
      included_account_ids: [],
      excluded_category_ids: [],
      merchant_ids: [],
      allocations: [{ limit: '3000.00', category_id: CATEGORY_GROCERIES }],
      alert_thresholds: [50, 75, 90, 100],
      alert_forecast: true,
      include_pending: false,
      refunds_restore: true,
      count_group_shares: true,
      visibility: 'private',
    });
  });

  it('checks the budget type rules before sending anything', async () => {
    testBackend.categories = starterCategories();
    const user = userEvent.setup();
    renderRoute('/budgets/new', { user: signedIn() });
    await findPageHeading('Create a budget');

    await user.type(await screen.findByLabelText('Name'), 'Envelopes');
    await user.click(screen.getByRole('radio', { name: /^Envelopes/ }));
    await user.type(screen.getByLabelText('Limit for each period'), '9000');
    await user.selectOptions(screen.getByLabelText('Period'), 'custom');
    await user.click(screen.getByRole('button', { name: 'Create budget' }));

    expect(await screen.findByText('Add at least one allocation.')).toBeInTheDocument();
    expect(
      screen.getByText('Choose the last day for a budget with custom dates.'),
    ).toBeInTheDocument();
  });

  it('shows the API’s field errors and explains the zero-based rule', async () => {
    testBackend.categories = starterCategories();
    let calls = 0;
    server.use(
      http.post(`${API}/budgets`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'VALIDATION_ERROR',
              details: [{ field: 'body.limit', message: 'Amount must be positive.' }],
            }),
            { status: 422 },
          );
        }
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                code: 'zero_based_unallocated',
                message: 'Zero-based budgets must allocate exactly the full limit.',
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/budgets/new', { user: signedIn() });
    await findPageHeading('Create a budget');
    await user.type(await screen.findByLabelText('Name'), 'Every rupee');
    await user.click(screen.getByRole('radio', { name: /^Zero-based/ }));
    await user.type(screen.getByLabelText('Limit for each period'), '1000');
    await user.click(screen.getByRole('button', { name: 'Add allocation' }));
    const allocation = screen.getByRole('group', { name: 'Allocation 1' });
    await user.selectOptions(within(allocation).getByLabelText('Category'), CATEGORY_GROCERIES);
    await user.type(within(allocation).getByLabelText('Limit'), '900');

    await user.click(screen.getByRole('button', { name: 'Create budget' }));
    expect(await screen.findByText('Amount must be positive.')).toBeInTheDocument();
    expect(screen.getByText('Please check the highlighted fields.')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Create budget' }));
    await waitFor(() => {
      expect(
        screen.getAllByText(
          'For a zero-based budget, the allocations must add up to exactly the limit.',
        ),
      ).toHaveLength(2);
    });
  });

  it('creates a household budget that tracks a group in the group’s currency', async () => {
    testBackend.categories = starterCategories();
    testBackend.groups = [makeGroup({ base_currency: 'EUR' })];
    testBackend.groupDetails = { [GROUP_ID]: makeGroupDetail({ base_currency: 'EUR' }) };
    let body: Record<string, unknown> = {};
    server.use(
      http.post(`${API}/budgets`, async ({ request }) => {
        body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(
          envelope(makeBudget({ group_id: GROUP_ID, currency: 'EUR', name: 'Home' })),
          { status: 201 },
        );
      }),
      ...detailReads(),
    );
    const user = userEvent.setup();
    renderRoute('/budgets/new', { user: signedIn() });
    await findPageHeading('Create a budget');
    await user.type(await screen.findByLabelText('Name'), 'Home');
    await user.type(screen.getByLabelText('Limit for each period'), '800');
    await user.selectOptions(screen.getByLabelText(/Track a group’s shared expenses/), GROUP_ID);

    expect(await screen.findByText('Group budgets use the group’s currency.')).toBeInTheDocument();
    expect(screen.queryByLabelText('Currency')).not.toBeInTheDocument();
    expect(screen.getByRole('radio', { name: /^Group members/ })).toBeChecked();

    await user.click(screen.getByRole('button', { name: 'Add allocation' }));
    const allocation = screen.getByRole('group', { name: 'Allocation 1' });
    const member = within(allocation).getByLabelText('Group member');
    await waitFor(() => {
      expect(within(member).getByRole('option', { name: 'Meera Rao' })).toBeInTheDocument();
    });
    await user.selectOptions(member, GROUP_MEMBER_ID);
    await user.type(within(allocation).getByLabelText('Limit'), '300');
    await user.click(screen.getByRole('button', { name: 'Create budget' }));

    await findPageHeading('Home');
    expect(body).toMatchObject({
      currency: 'EUR',
      limit: '800.00',
      group_id: GROUP_ID,
      visibility: 'members',
      allocations: [{ limit: '300.00', member_user_id: GROUP_MEMBER_ID }],
    });
  });
});

describe('BudgetCreatePage shape rules', () => {
  it('limits a group budget to group types and member allocations, and can turn alerts off', async () => {
    testBackend.categories = starterCategories();
    testBackend.accounts = [makeAccount()];
    testBackend.groups = [makeGroup({ base_currency: 'EUR' })];
    testBackend.groupDetails = { [GROUP_ID]: makeGroupDetail({ base_currency: 'EUR' }) };
    const bodies: Record<string, unknown>[] = [];
    server.use(
      http.post(`${API}/budgets`, async ({ request }) => {
        bodies.push((await request.json()) as Record<string, unknown>);
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                code: 'group_budget_allocation_unsupported',
                message: 'Group budgets are split between members.',
                params: { index: '0' },
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/budgets/new', { user: signedIn() });
    await findPageHeading('Create a budget');
    await user.type(await screen.findByLabelText('Name'), 'Flat');
    await user.click(screen.getByRole('radio', { name: /^By category/ }));
    await user.type(screen.getByLabelText('Limit for each period'), '800');
    await user.selectOptions(screen.getByLabelText(/Track a group’s shared expenses/), GROUP_ID);

    // Only the types a group budget supports; a personal type falls back to Overall.
    const types = screen.getByRole('group', { name: 'Budget type' });
    expect(
      within(types)
        .getAllByRole('radio')
        .map((radio) => radio.closest('label')?.textContent),
    ).toEqual([
      expect.stringMatching(/^Overall/),
      expect.stringMatching(/^Envelopes/),
      expect.stringMatching(/^Zero-based/),
    ]);
    expect(within(types).getByRole('radio', { name: /^Overall/ })).toBeChecked();
    // No account, category or merchant filters for a group budget.
    expect(screen.queryByRole('group', { name: 'Accounts' })).not.toBeInTheDocument();
    expect(screen.queryByText('Leave out some categories')).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Add allocation' }));
    const allocation = screen.getByRole('group', { name: 'Allocation 1' });
    expect(optionValues(within(allocation).getByLabelText('Applies to'))).toEqual(['member']);
    const member = within(allocation).getByLabelText('Group member');
    await waitFor(() => {
      expect(within(member).getByRole('option', { name: 'Meera Rao' })).toBeInTheDocument();
    });
    await user.selectOptions(member, GROUP_MEMBER_ID);
    await user.type(within(allocation).getByLabelText('Limit'), '300');
    await user.click(screen.getByRole('radio', { name: /^No spending level alerts/ }));
    await user.click(screen.getByRole('button', { name: 'Create budget' }));

    // The API's coded rule is shown in words on the allocation it names.
    expect(
      await within(allocation).findByText(
        'Group budgets are split between members, not categories, merchants or accounts.',
      ),
    ).toBeInTheDocument();
    expect(bodies[0]).toMatchObject({
      budget_type: 'total',
      group_id: GROUP_ID,
      included_account_ids: [],
      excluded_category_ids: [],
      merchant_ids: [],
      alert_thresholds: [],
      allocations: [{ limit: '300.00', member_user_id: GROUP_MEMBER_ID }],
    });
  });

  it('asks merchant budgets for merchants and account budgets for accounts', async () => {
    testBackend.categories = starterCategories();
    testBackend.accounts = [makeAccount()];
    const user = userEvent.setup();
    renderRoute('/budgets/new', { user: signedIn() });
    await findPageHeading('Create a budget');
    await user.type(await screen.findByLabelText('Name'), 'Shops');
    await user.type(screen.getByLabelText('Limit for each period'), '1000');

    await user.click(screen.getByRole('radio', { name: /^By merchant/ }));
    await user.click(screen.getByRole('button', { name: 'Add allocation' }));
    const allocation = screen.getByRole('group', { name: 'Allocation 1' });
    // Personal budgets: never by member; merchants only in merchant budgets.
    expect(optionValues(within(allocation).getByLabelText('Applies to'))).toEqual([
      'category',
      'merchant',
      'label',
    ]);
    await user.click(within(allocation).getByRole('button', { name: /Remove allocation 1/ }));
    await user.click(screen.getByRole('button', { name: 'Create budget' }));
    expect(
      await screen.findByText('Choose at least one merchant for a budget by merchant.'),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('radio', { name: /^By account/ }));
    await user.click(screen.getByRole('button', { name: 'Create budget' }));
    expect(
      await screen.findByText('Choose at least one account for a budget by account.'),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add allocation' }));
    expect(
      optionValues(
        within(screen.getByRole('group', { name: 'Allocation 1' })).getByLabelText('Applies to'),
      ),
    ).toEqual(['category', 'account', 'label']);
  });
});

describe('BudgetEditPage', () => {
  it('sends only the changed fields with the budget’s version', async () => {
    testBackend.categories = starterCategories();
    let body: unknown;
    server.use(
      http.get(`${API}/budgets/:id`, () =>
        HttpResponse.json(envelope(makeBudget({ version: 4, timezone: 'Asia/Kolkata' }))),
      ),
      http.patch(`${API}/budgets/:id`, async ({ request, params }) => {
        expect(params.id).toBe(BUDGET_ID);
        body = await request.json();
        return HttpResponse.json(envelope(makeBudget({ version: 5 })));
      }),
      ...detailReads(),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit budget');
    expect(
      screen.getByText(
        'Changes apply from the current period on. Past periods keep their history.',
      ),
    ).toBeInTheDocument();
    const limit = await screen.findByLabelText('Limit for each period');
    expect(limit).toHaveValue('5000.00');
    const allocation = screen.getByRole('group', { name: 'Allocation 1' });
    expect(within(allocation).getByLabelText('Category')).toHaveValue(CATEGORY_GROCERIES);
    await user.clear(limit);
    await user.type(limit, '6000');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    await findPageHeading('Food');
    expect(screen.getByText('Budget updated')).toBeInTheDocument();
    // Partial PATCH: unchanged fields (and the budget's time zone) are not sent.
    expect(body).toEqual({ version: 4, limit: '6000.00' });
  });

  it('clears what the user emptied and can turn threshold alerts off', async () => {
    testBackend.categories = starterCategories();
    let body: unknown;
    server.use(
      http.get(`${API}/budgets/:id`, () =>
        HttpResponse.json(
          envelope(
            makeBudget({
              version: 7,
              notes: 'Groceries only',
              ends_on: '2026-12-31',
              rollover_policy: 'carry_unused',
              rollover_cap: money('500.00'),
              alert_thresholds: [50, 75],
            }),
          ),
        ),
      ),
      http.patch(`${API}/budgets/:id`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(makeBudget({ version: 8 })));
      }),
      ...detailReads(),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit budget');
    expect(await screen.findByLabelText(/Most to carry over/)).toHaveValue('500.00');
    expect(screen.getByRole('checkbox', { name: '75%' })).toBeChecked();
    expect(screen.getByRole('checkbox', { name: '150%' })).not.toBeChecked();

    await user.clear(screen.getByLabelText(/^Ends on/));
    await user.selectOptions(screen.getByLabelText('At the end of a period'), 'none');
    await user.click(screen.getByRole('radio', { name: /^No spending level alerts/ }));
    expect(screen.queryByRole('checkbox', { name: '75%' })).not.toBeInTheDocument();
    await user.clear(screen.getByLabelText(/^Notes/));
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    await findPageHeading('Food');
    expect(body).toEqual({
      version: 7,
      ends_on: '',
      rollover_policy: 'none',
      rollover_cap: '',
      alert_thresholds: [],
      notes: '',
    });
  });

  it('does not send anything when nothing changed', async () => {
    testBackend.categories = starterCategories();
    let patched = false;
    server.use(
      http.get(`${API}/budgets/:id`, () => HttpResponse.json(envelope(makeBudget()))),
      http.patch(`${API}/budgets/:id`, () => {
        patched = true;
        return HttpResponse.json(envelope(makeBudget()));
      }),
      ...detailReads(),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit budget');
    await screen.findByLabelText('Limit for each period');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    await findPageHeading('Food');
    expect(screen.getByText('No changes to save')).toBeInTheDocument();
    expect(patched).toBe(false);
  });

  it('reloads after a version conflict and saves with the new version', async () => {
    testBackend.categories = starterCategories();
    let reads = 0;
    const versions: unknown[] = [];
    server.use(
      http.get(`${API}/budgets/:id`, () => {
        reads += 1;
        return HttpResponse.json(
          envelope(
            reads === 1
              ? makeBudget({ version: 4 })
              : makeBudget({ version: 5, name: 'Food and dining' }),
          ),
        );
      }),
      http.patch(`${API}/budgets/:id`, async ({ request }) => {
        const sent = (await request.json()) as { version: number };
        versions.push(sent.version);
        if (versions.length === 1) {
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeBudget({ version: 6, name: 'Food and dining' })));
      }),
      ...detailReads(),
    );
    const user = userEvent.setup();
    renderRoute(`/budgets/${BUDGET_ID}/edit`, { user: signedIn() });
    await findPageHeading('Edit budget');
    const limit = await screen.findByLabelText('Limit for each period');
    await user.clear(limit);
    await user.type(limit, '6000');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText(/This budget was changed somewhere else/)).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.getByLabelText('Name')).toHaveValue('Food and dining');
    });
    // The form shows the latest version; the change is made again on top of it.
    const reloaded = screen.getByLabelText('Limit for each period');
    expect(reloaded).toHaveValue('5000.00');
    await user.clear(reloaded);
    await user.type(reloaded, '6000');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    await findPageHeading('Food and dining');
    expect(versions).toEqual([4, 5]);
  });

  it('is read only for people the budget is shared with as viewers', async () => {
    server.use(
      http.get(`${API}/budgets/:id`, () => HttpResponse.json(envelope(makeSharedBudget()))),
    );
    renderRoute(`/budgets/${BUDGET_ID}/edit`, { user: signedIn() });
    expect(
      await screen.findByRole('heading', { name: 'You can view this budget' }),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Save changes' })).not.toBeInTheDocument();
  });

  it('says when the budget no longer exists', async () => {
    server.use(
      http.get(`${API}/budgets/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(`/budgets/${BUDGET_ID}/edit`, { user: signedIn() });
    expect(
      await screen.findByRole('heading', { name: 'This budget isn’t available' }),
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Back to budgets' })).toHaveAttribute(
      'href',
      '/budgets',
    );
  });
});
