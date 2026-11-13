import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import type { DashboardPlanning, DashboardSummary } from '@/shared/finance/types';
import { BUDGET_ID, makeBudget, makeBudgetAlert, makeProgress } from '@/tests/budgetsFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CATEGORY_GROCERIES,
  defaultWidgets,
  emptyPlanning,
  makeAccount,
  makeCategory,
  makePreferences,
  makeSummary,
  money,
} from '@/tests/financeFixtures';
import { GOAL_FUND, GOAL_TRIP, makeGoal } from '@/tests/goalsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { BILL_ID, makeCalendarItem } from '@/tests/planningFixtures';
import { server } from '@/tests/msw/server';
import { SUB_GYM, SUB_NETFLIX } from '@/tests/subscriptionsFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';

const returning = () => makeUser({ onboarding_completed: true });

function summaryHandler(record: URL[] = [], summary = makeSummary()) {
  return http.get(`${API}/dashboard/summary`, ({ request }) => {
    record.push(new URL(request.url));
    return HttpResponse.json(envelope(summary));
  });
}

describe('DashboardPage', () => {
  it('shows server figures with their period, freshness and drill-down links', async () => {
    // Only the clock is fixed (timers stay real): the summary was computed 5 minutes earlier.
    vi.useFakeTimers({ toFake: ['Date'], now: new Date('2026-11-04T10:05:00Z') });
    testBackend.accounts = [makeAccount()];
    testBackend.categories = [makeCategory()];
    const requests: URL[] = [];
    server.use(summaryHandler(requests));
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');

    const balances = await screen.findByRole('region', { name: 'Balances' });
    expect(within(balances).getByText('₹4,239.75')).toBeInTheDocument();
    expect(
      within(balances).getByText('Tracked from your records, not verified by a bank.'),
    ).toBeInTheDocument();

    const cashFlow = screen.getByRole('region', { name: 'Cash flow' });
    expect(within(cashFlow).getByText('₹5,000.00')).toBeInTheDocument();
    expect(within(cashFlow).getByText('+₹4,739.25')).toBeInTheDocument();
    expect(within(cashFlow).getByText('More came in than went out')).toBeInTheDocument();
    expect(within(cashFlow).getByText('94.8%')).toBeInTheDocument();
    expect(within(cashFlow).getByText('Previous period: ₹4,500.00')).toBeInTheDocument();
    expect(within(cashFlow).getByText(/Nov 1\s–\s30, 2026 \(Asia\/Kolkata\)/)).toBeInTheDocument();
    // Freshness: when the API computed the figures (generated_at), as a machine-readable time.
    const updated = within(cashFlow).getByText('Updated 5 minutes ago');
    expect(updated.tagName).toBe('TIME');
    expect(updated).toHaveAttribute('dateTime', '2026-11-04T10:00:00Z');
    expect(within(balances).getByText('Updated 5 minutes ago')).toHaveAttribute(
      'dateTime',
      '2026-11-04T10:00:00Z',
    );
    expect(within(cashFlow).getByRole('link', { name: 'View transactions' })).toHaveAttribute(
      'href',
      '/transactions?from=2026-11-01&to=2026-11-30',
    );

    const categories = screen.getByRole('region', { name: 'Spending by category' });
    expect(within(categories).getByRole('link', { name: 'Groceries' })).toHaveAttribute(
      'href',
      `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_GROCERIES}`,
    );
    expect(within(categories).getByRole('link', { name: 'Uncategorized' })).toHaveAttribute(
      'href',
      '/transactions?from=2026-11-01&to=2026-11-30&uncategorized=true',
    );

    const recent = screen.getByRole('region', { name: 'Recent transactions' });
    expect(within(recent).getByRole('link', { name: 'November salary' })).toBeInTheDocument();

    expect(requests[0]?.searchParams.get('range')).toBe('this_month');
  });

  it('explains the counting rules from the API’s note codes, in the interface language', async () => {
    testBackend.accounts = [makeAccount()];
    server.use(
      summaryHandler(
        [],
        makeSummary({
          // The last code is newer than this client (the contract evolves additively).
          note_codes: [
            'excludes_transfers_adjustments',
            'currencies_separate',
            'new_rule' as string as DashboardSummary['note_codes'][number],
          ],
          notes: [
            'Transfers are excluded (English).',
            'Currencies are separate (English).',
            'A rule this client does not know yet.',
          ],
        }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    await user.click(await screen.findByRole('button', { name: 'Show the rules' }));
    expect(
      screen.getByText(
        'Transfers between your accounts, balance corrections and opening balances are not counted as income or spending.',
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        'Amounts in different currencies are shown separately and never added together.',
      ),
    ).toBeInTheDocument();
    // An unknown code falls back to the API's own text for that position.
    expect(screen.getByText('A rule this client does not know yet.')).toBeInTheDocument();
    expect(screen.queryByText('Transfers are excluded (English).')).not.toBeInTheDocument();
  });

  it('gives every chart a text summary and a data table', async () => {
    server.use(summaryHandler());
    const user = userEvent.setup();
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');

    const chart = await screen.findByRole('figure', { name: 'Income and spending in INR' });
    expect(chart).toHaveAccessibleDescription(
      'This period, income was ₹5,000.00 and spending was ₹260.75. In the previous period, income was ₹4,500.00 and spending was ₹1,200.00.',
    );
    await user.click(within(chart).getByRole('button', { name: 'Show as table' }));
    const table = within(chart).getByRole('table', { name: 'Income and spending in INR' });
    const income = within(table).getByRole('row', { name: /Income/ });
    expect(within(income).getByText('₹5,000.00')).toBeInTheDocument();
    expect(within(income).getByText('₹4,500.00')).toBeInTheDocument();
    expect(within(chart).getByRole('button', { name: 'Show as chart' })).toHaveAttribute(
      'aria-pressed',
      'true',
    );

    const trend = screen.getByRole('figure', { name: 'Income and spending over time in INR' });
    expect(trend).toHaveAccessibleDescription(/The highest spending was ₹250\.75/);
  });

  it('describes a monthly trend by month, as the API grouped it', async () => {
    const bucket = (date: string, income: string, spent: string) => ({
      bucket: date,
      currency: 'INR',
      income: money(income),
      net_expense: money(spent),
      net: money('0.00'),
    });
    server.use(
      summaryHandler(
        [],
        makeSummary({
          trend_granularity: 'month',
          trend: [
            bucket('2026-09-01', '0.00', '0.00'),
            bucket('2026-10-01', '4500.00', '1200.00'),
            bucket('2026-11-01', '5000.00', '260.75'),
          ],
        }),
      ),
    );
    renderRoute('/dashboard?range=this_year', { user: returning() });
    await findPageHeading('Home');
    const trend = await screen.findByRole('figure', {
      name: 'Income and spending over time in INR',
    });
    expect(trend).toHaveAccessibleDescription(/^Monthly income and spending from/);
  });

  it('follows the saved widget layout (order and visibility)', async () => {
    testBackend.accounts = [makeAccount()];
    testBackend.widgets = [
      { key: 'recent_transactions', position: 0, visible: true, settings: {} },
      { key: 'balances', position: 1, visible: false, settings: {} },
      { key: 'cash_flow', position: 2, visible: true, settings: {} },
    ];
    server.use(summaryHandler());
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    await screen.findByRole('region', { name: 'Recent transactions' });
    const titles = screen
      .getAllByRole('heading', { level: 2 })
      .map((heading) => heading.textContent)
      .filter((text) => text !== 'How these figures are calculated');
    expect(titles).toEqual(['Recent transactions', 'Cash flow']);
    expect(screen.queryByRole('region', { name: 'Balances' })).not.toBeInTheDocument();
  });

  it('hides, reorders and resets widgets without touching finance data', async () => {
    const bodies: unknown[] = [];
    server.use(
      summaryHandler(),
      http.patch(`${API}/dashboard/widgets`, async ({ request }) => {
        const body = (await request.json()) as { reset?: boolean };
        bodies.push(body);
        return HttpResponse.json(
          envelope(body.reset ? defaultWidgets() : defaultWidgets().slice(1)),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    await screen.findByRole('region', { name: 'Balances' });

    await user.click(screen.getByRole('button', { name: 'Customize' }));
    let dialog = await screen.findByRole('dialog', { name: 'Customize your dashboard' });
    await user.click(within(dialog).getByLabelText('Show Balances'));
    await user.click(within(dialog).getByRole('button', { name: 'Move Cash flow up' }));
    expect(await screen.findByText('Cash flow moved to position 1 of 15')).toBeInTheDocument();
    // The planning cards are part of the same layout: hide some and move another.
    await user.click(within(dialog).getByLabelText('Show Group balances'));
    await user.click(within(dialog).getByLabelText('Show Renewals and trials'));
    await user.click(within(dialog).getByRole('button', { name: 'Move Goals up' }));
    expect(await screen.findByText('Goals moved to position 11 of 15')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Move Budget alerts down' }));
    expect(await screen.findByText('Budget alerts moved to position 4 of 15')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Dashboard layout saved')).toBeInTheDocument();
    expect(bodies[0]).toEqual({
      widgets: [
        { key: 'cash_flow', position: 0, visible: true, settings: {} },
        { key: 'balances', position: 1, visible: false, settings: {} },
        { key: 'budgets', position: 2, visible: true, settings: {} },
        { key: 'alerts', position: 3, visible: true, settings: {} },
        { key: 'upcoming', position: 4, visible: true, settings: {} },
        { key: 'renewals', position: 5, visible: false, settings: {} },
        { key: 'income_vs_expense', position: 6, visible: true, settings: {} },
        { key: 'cash_flow_trend', position: 7, visible: true, settings: {} },
        { key: 'category_breakdown', position: 8, visible: true, settings: {} },
        { key: 'top_merchants', position: 9, visible: true, settings: {} },
        { key: 'goals', position: 10, visible: true, settings: {} },
        { key: 'recurring', position: 11, visible: true, settings: {} },
        { key: 'group_balances', position: 12, visible: false, settings: {} },
        { key: 'recent_transactions', position: 13, visible: true, settings: {} },
        { key: 'data_coverage', position: 14, visible: true, settings: {} },
      ],
    });

    await user.click(screen.getByRole('button', { name: 'Customize' }));
    dialog = await screen.findByRole('dialog', { name: 'Customize your dashboard' });
    await user.click(within(dialog).getByRole('button', { name: 'Reset to default' }));
    expect(await screen.findByText('Dashboard reset to the default layout')).toBeInTheDocument();
    expect(bodies[1]).toEqual({ reset: true });
  });

  it('uses the preferred default period and keeps filters in the URL', async () => {
    testBackend.preferences = makePreferences({ default_date_range: 'last_30_days' });
    const requests: URL[] = [];
    server.use(summaryHandler(requests));
    const user = userEvent.setup();
    const { router } = renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    await screen.findByRole('region', { name: 'Cash flow' });
    expect(requests[0]?.searchParams.get('range')).toBe('last_30_days');

    await user.click(screen.getByLabelText('Include pending'));
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('include_pending')).toBe('true');
    });
    expect(router.state.location.search).toBe('?range=last_30_days&pending=1');
  });

  it('waits for both custom dates before computing', async () => {
    const requests: URL[] = [];
    server.use(summaryHandler(requests));
    const user = userEvent.setup();
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    await screen.findByRole('region', { name: 'Cash flow' });
    await user.selectOptions(screen.getByLabelText('Period'), 'custom');
    expect(await screen.findByText('Choose your dates')).toBeInTheDocument();
    await user.type(screen.getByLabelText('From'), '2026-10-01');
    await user.type(screen.getByLabelText('To'), '2026-10-31');
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('from')).toBe('2026-10-01');
    });
    expect(requests.at(-1)?.searchParams.get('to')).toBe('2026-10-31');
    expect(requests.at(-1)?.searchParams.has('range')).toBe(false);
  });

  it('shows a loading state, then an error with retry', async () => {
    let fail = true;
    server.use(
      http.get(`${API}/dashboard/summary`, async () => {
        await delay(20);
        return fail
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(envelope(makeSummary()));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    expect(screen.getByText('Loading your dashboard…')).toBeInTheDocument();
    expect(await screen.findByText('We couldn’t load your dashboard')).toBeInTheDocument();
    fail = false;
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('region', { name: 'Balances' })).toBeInTheDocument();
  });

  it('guides a first-time user with no accounts and no activity', async () => {
    server.use(
      summaryHandler(
        [],
        makeSummary({
          balances: [],
          cash_flow: [],
          previous_cash_flow: [],
          trend: [],
          top_categories: [],
          top_merchants: [],
          recent_transactions: [],
          coverage: {
            transaction_count: 0,
            uncategorized_count: 0,
            pending_count: 0,
            provider_synced: false,
          },
        }),
      ),
    );
    renderRoute('/dashboard', { user: makeUser() });
    await findPageHeading('Home');
    expect(await screen.findByText('Finish setting up Montra')).toBeInTheDocument();
    expect(await screen.findByText('Start with an account')).toBeInTheDocument();
    expect(screen.getAllByText('No income or spending in this period').length).toBeGreaterThan(0);
  });
});

const GROUP_HOME = 'c1c1c1c1-3333-4333-8333-0000000000a1';
const GROUP_TRIP = 'c1c1c1c1-3333-4333-8333-0000000000a2';
const GROUP_FLAT = 'c1c1c1c1-3333-4333-8333-0000000000a3';
const BUDGET_TRAVEL = 'b0b0b0b0-0000-4000-8000-0000000000a2';
const ALERT_FORECAST = 'a1e7a1e7-0000-4000-8000-0000000000a2';
const RULE_GYM = 'c1111111-1111-4111-8111-1111111111a2';

/** GET /dashboard/planning as the API orders it: fullest budgets, overdue first, nearest goals. */
function makePlanning(overrides: Partial<DashboardPlanning> = {}): DashboardPlanning {
  return emptyPlanning({
    budgets: [
      makeBudget({
        id: BUDGET_TRAVEL,
        name: 'Travel',
        progress: makeProgress({
          spent: money('5500.00'),
          limit: money('5000.00'),
          remaining: money('0.00'),
          overspent: money('500.00'),
          percent_bp: 11000,
          pace: 'over_budget',
        }),
      }),
      makeBudget(),
    ],
    budget_count: 7,
    over_budget_count: 1,
    upcoming: [
      makeCalendarItem({ date: '2026-11-03', status: 'overdue', title: 'Electricity' }),
      makeCalendarItem({
        date: '2026-11-12',
        kind: 'group_expense',
        title: 'Flat rent',
        amount: money('9000.00'),
        status: 'scheduled',
        entity_type: 'group_recurring_expense',
        entity_id: RULE_GYM,
        group_id: GROUP_FLAT,
      }),
      makeCalendarItem({
        date: '2026-11-20',
        kind: 'subscription_renewal',
        title: 'Music',
        amount: money('9.99', 'USD'),
        status: 'expected',
        entity_type: 'subscription',
        entity_id: RULE_GYM,
        occurrence_id: undefined,
      }),
    ],
    upcoming_count: 11,
    overdue_count: 1,
    goals: [
      makeGoal(),
      makeGoal({ id: GOAL_FUND, name: 'Emergency fund', target_date: undefined }),
    ],
    goal_count: 2,
    group_balances: [
      {
        group_id: GROUP_HOME,
        name: 'Home',
        group_type: 'household',
        my_net: money('1250.00'),
      },
      { group_id: GROUP_TRIP, name: 'Goa trip', group_type: 'trip', my_net: money('-300.50') },
    ],
    group_count: 2,
    alerts: [
      makeBudgetAlert({ budget_id: BUDGET_TRAVEL, budget_name: 'Travel', threshold: 100 }),
      makeBudgetAlert({
        id: ALERT_FORECAST,
        kind: 'forecast_overspend',
        threshold: 0,
        triggered_at: '2026-11-04T09:00:00Z',
      }),
    ],
    alert_count: 4,
    renewals: [
      makeCalendarItem({
        date: '2026-11-12',
        kind: 'trial_end',
        title: 'Music',
        amount: undefined,
        status: 'expected',
        entity_type: 'subscription',
        entity_id: SUB_GYM,
        occurrence_id: undefined,
      }),
      makeCalendarItem({
        date: '2026-11-20',
        kind: 'subscription_renewal',
        title: 'Netflix',
        amount: money('649.00'),
        status: 'expected',
        entity_type: 'subscription',
        entity_id: SUB_NETFLIX,
        occurrence_id: undefined,
      }),
    ],
    renewal_count: 3,
    recurring: [
      {
        kind: 'expense',
        currency: 'USD',
        monthly_equivalent: money('9.99', 'USD'),
        next_30_days: money('9.99', 'USD'),
        rule_count: 1,
        variable_count: 0,
      },
      {
        kind: 'expense',
        currency: 'INR',
        monthly_equivalent: money('1299.99', 'INR'),
        next_30_days: money('1200.00', 'INR'),
        rule_count: 2,
        variable_count: 1,
      },
      {
        kind: 'income',
        currency: 'INR',
        monthly_equivalent: money('50000.00', 'INR'),
        next_30_days: money('50000.00', 'INR'),
        rule_count: 1,
        variable_count: 0,
      },
    ],
    ...overrides,
  });
}

/** Serves the planning cards and counts the requests (one for all four cards). */
function planningHandler(calls: { count: number }, planning = makePlanning()) {
  return http.get(`${API}/dashboard/planning`, () => {
    calls.count += 1;
    return HttpResponse.json(envelope(planning));
  });
}

describe('DashboardPage planning cards', () => {
  it('shows budgets, upcoming items, goals and group balances from one request', async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: new Date('2026-11-04T10:02:00Z') });
    const calls = { count: 0 };
    server.use(summaryHandler(), planningHandler(calls));
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');

    const budgets = await screen.findByRole('region', { name: 'Budgets' });
    const travel = within(budgets).getByRole('link', { name: 'Travel' });
    expect(travel).toHaveAttribute('href', `/budgets/${BUDGET_TRAVEL}`);
    // Exact server money and the pace in words, not only colour.
    expect(within(budgets).getByText('₹5,500.00 of ₹5,000.00 spent')).toBeInTheDocument();
    expect(within(budgets).getByText('Over by ₹500.00')).toBeInTheDocument();
    expect(within(budgets).getByText('Over the limit')).toBeInTheDocument();
    expect(within(budgets).getByText('₹4,200.00 of ₹5,000.00 spent')).toBeInTheDocument();
    expect(within(budgets).getByText('Spending faster than expected')).toBeInTheDocument();
    expect(within(budgets).getByRole('meter', { name: 'Travel: budget used' })).toBeInTheDocument();
    // The count comes from the API (7), not from the 2 items listed.
    expect(within(budgets).getByText('2 of 7 active budgets · 1 over budget')).toBeInTheDocument();
    expect(within(budgets).getByRole('link', { name: 'View all 7 budgets' })).toHaveAttribute(
      'href',
      '/budgets',
    );
    expect(within(budgets).getByText('Updated 2 minutes ago')).toHaveAttribute(
      'dateTime',
      '2026-11-04T10:00:00Z',
    );

    const upcoming = screen.getByRole('region', { name: 'Coming up' });
    expect(within(upcoming).getByText('Overdue, and due through Nov 26, 2026')).toBeInTheDocument();
    expect(
      within(upcoming).getByText(
        '1 item is past its due date. Mark it paid or skip it when you are ready.',
      ),
    ).toBeInTheDocument();
    const rows = within(upcoming).getAllByRole('listitem');
    expect(rows).toHaveLength(3);
    expect(within(rows[0]!).getByRole('link', { name: 'Electricity' })).toHaveAttribute(
      'href',
      `/planning/bills/${BILL_ID}`,
    );
    expect(within(rows[0]!).getByText('Overdue')).toBeInTheDocument();
    expect(within(rows[0]!).getByText('Was due Nov 3, 2026')).toBeInTheDocument();
    expect(within(rows[0]!).getByText('₹1,200.00')).toBeInTheDocument();
    // A shared recurring expense opens its group's recurring expenses.
    expect(within(rows[1]!).getByRole('link', { name: 'Flat rent' })).toHaveAttribute(
      'href',
      `/groups/${GROUP_FLAT}/recurring`,
    );
    expect(within(rows[1]!).getByText('Due today')).toBeInTheDocument();
    expect(within(rows[1]!).queryByText('Overdue')).not.toBeInTheDocument();
    expect(within(rows[2]!).getByText('Due Nov 20, 2026')).toBeInTheDocument();
    expect(within(rows[2]!).getByText('Expected')).toBeInTheDocument();
    expect(within(rows[2]!).getByText('$9.99')).toBeInTheDocument();
    expect(within(upcoming).getByText('3 of 11 items')).toBeInTheDocument();
    expect(
      within(upcoming).getByRole('link', { name: 'View all 11 in the calendar' }),
    ).toHaveAttribute('href', '/planning');

    const goals = screen.getByRole('region', { name: 'Goals' });
    expect(within(goals).getByRole('link', { name: 'Goa trip' })).toHaveAttribute(
      'href',
      `/goals/${GOAL_TRIP}`,
    );
    const [trip, fund] = within(goals).getAllByRole('listitem');
    expect(within(trip!).getByText('₹6,000.00 saved of ₹60,000.00')).toBeInTheDocument();
    expect(within(trip!).getByText('₹54,000.00 to go')).toBeInTheDocument();
    expect(within(trip!).getByText('Target Jun 30, 2027')).toBeInTheDocument();
    expect(within(fund!).getByRole('link', { name: 'Emergency fund' })).toHaveAttribute(
      'href',
      `/goals/${GOAL_FUND}`,
    );
    expect(within(fund!).getByText('No target date')).toBeInTheDocument();
    expect(within(goals).getByText('2 of 2 active goals')).toBeInTheDocument();
    expect(within(goals).getByRole('link', { name: 'View all 2 goals' })).toHaveAttribute(
      'href',
      '/goals',
    );

    const groups = screen.getByRole('region', { name: 'Group balances' });
    expect(within(groups).getByRole('link', { name: 'Home' })).toHaveAttribute(
      'href',
      `/groups/${GROUP_HOME}/balances`,
    );
    expect(within(groups).getByText('You are owed ₹1,250.00')).toBeInTheDocument();
    expect(within(groups).getByText('You owe ₹300.50')).toBeInTheDocument();
    expect(within(groups).getByRole('link', { name: 'View all 2 groups' })).toHaveAttribute(
      'href',
      '/groups',
    );

    expect(calls.count).toBe(1);
  });

  it('shows budget alerts, renewals and recurring commitments from the same request', async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: new Date('2026-11-04T10:02:00Z') });
    const calls = { count: 0 };
    server.use(summaryHandler(), planningHandler(calls));
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');

    const alerts = await screen.findByRole('region', { name: 'Budget alerts' });
    expect(within(alerts).getByText('Active alerts, newest first')).toBeInTheDocument();
    // The budget, what happened and the threshold, in words, linking to the budget.
    expect(
      within(alerts).getByRole('link', { name: 'Travel reached 100% of its limit' }),
    ).toHaveAttribute('href', `/budgets/${BUDGET_TRAVEL}`);
    expect(
      within(alerts).getByRole('link', {
        name: 'Food may go over its limit before the period ends (an estimate)',
      }),
    ).toHaveAttribute('href', `/budgets/${BUDGET_ID}`);
    expect(within(alerts).getByText('Raised 1 hour ago')).toHaveAttribute(
      'dateTime',
      '2026-11-04T09:00:00Z',
    );
    expect(
      within(alerts).getByRole('button', { name: 'Snooze: Travel reached 100% of its limit' }),
    ).toBeInTheDocument();
    expect(
      within(alerts).getByRole('button', { name: 'Dismiss: Travel reached 100% of its limit' }),
    ).toBeInTheDocument();
    // The count is the API's (4), not the 2 listed.
    expect(within(alerts).getByText('2 of 4 active alerts')).toBeInTheDocument();
    expect(within(alerts).getByRole('link', { name: 'View all 4 in Budgets' })).toHaveAttribute(
      'href',
      '/budgets',
    );

    const renewals = screen.getByRole('region', { name: 'Renewals and trials' });
    expect(
      within(renewals).getByText('Due through Dec 12, 2026, soonest first'),
    ).toBeInTheDocument();
    const [trial, netflix] = within(renewals).getAllByRole('listitem');
    expect(within(trial!).getByRole('link', { name: 'Music' })).toHaveAttribute(
      'href',
      `/subscriptions/${SUB_GYM}`,
    );
    expect(within(trial!).getByText('Free trial ends today')).toHaveAttribute(
      'dateTime',
      '2026-11-12',
    );
    expect(within(netflix!).getByRole('link', { name: 'Netflix' })).toHaveAttribute(
      'href',
      `/subscriptions/${SUB_NETFLIX}`,
    );
    expect(within(netflix!).getByText('Renews Nov 20, 2026')).toBeInTheDocument();
    // Exactly the amount the API sent.
    expect(within(netflix!).getByText('₹649.00')).toBeInTheDocument();
    expect(within(renewals).getByText('2 of 3 renewals and trial ends')).toBeInTheDocument();
    expect(
      within(renewals).getByRole('link', { name: 'View all 3 in Subscriptions' }),
    ).toHaveAttribute('href', '/subscriptions');

    const recurring = screen.getByRole('region', { name: 'Recurring per month' });
    expect(
      within(recurring).getByText('Monthly equivalents of your active schedules'),
    ).toBeInTheDocument();
    // Per kind and currency, income first; currencies are never added together.
    const rows = within(recurring).getAllByRole('listitem');
    expect(rows.map((row) => row.querySelector('p')?.textContent)).toEqual([
      'Recurring income (1 schedule)',
      'Recurring expenses (2 schedules)',
      'Recurring expenses (1 schedule)',
    ]);
    expect(within(rows[0]!).getAllByText('₹50,000.00')).toHaveLength(2);
    expect(within(rows[1]!).getByText('₹1,299.99')).toBeInTheDocument();
    expect(within(rows[1]!).getByText('₹1,200.00')).toBeInTheDocument();
    expect(
      within(rows[1]!).getByText('1 schedule has a changing amount and isn’t included.'),
    ).toBeInTheDocument();
    expect(within(rows[2]!).getAllByText('$9.99')).toHaveLength(2);
    // What the figures count, localized from recurring_note_code.
    expect(
      within(recurring).getByText(
        'Only fixed amounts are counted. Bills and income are what you expect, not money recorded yet.',
      ),
    ).toBeInTheDocument();
    expect(
      within(recurring).getByRole('link', { name: 'View recurring schedules' }),
    ).toHaveAttribute('href', '/planning/recurring');

    expect(calls.count).toBe(1);
  });

  it('dismisses and snoozes an alert with the budget alert endpoints, then refreshes the cards', async () => {
    const travel = makePlanning().alerts[0]!;
    // Every active alert is listed (2 of 2).
    let planning = makePlanning({ alert_count: 2 });
    const calls = { count: 0 };
    const bodies: { id: string; body: Record<string, unknown> }[] = [];
    server.use(
      summaryHandler(),
      http.get(`${API}/dashboard/planning`, () => {
        calls.count += 1;
        return HttpResponse.json(envelope(planning));
      }),
      http.patch(`${API}/budget-alerts/:id`, async ({ request, params }) => {
        const body = (await request.json()) as Record<string, unknown>;
        bodies.push({ id: String(params.id), body });
        // The server drops the alert from the active list.
        planning = makePlanning({
          alerts: planning.alerts.filter((alert) => alert.id !== params.id),
          alert_count: planning.alert_count - 1,
        });
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    const alerts = await screen.findByRole('region', { name: 'Budget alerts' });
    await within(alerts).findByText('2 of 2 active alerts');

    await user.click(
      within(alerts).getByRole('button', { name: 'Dismiss: Travel reached 100% of its limit' }),
    );
    expect(await screen.findByText('Alert dismissed')).toBeInTheDocument();
    expect(bodies[0]).toEqual({ id: travel.id, body: { status: 'dismissed' } });
    expect(await within(alerts).findByText('1 of 1 active alert')).toBeInTheDocument();
    expect(
      within(alerts).queryByRole('link', { name: 'Travel reached 100% of its limit' }),
    ).not.toBeInTheDocument();
    expect(calls.count).toBe(2);

    const forecast = 'Food may go over its limit before the period ends (an estimate)';
    await user.click(within(alerts).getByRole('button', { name: `Snooze: ${forecast}` }));
    await user.click(await screen.findByRole('menuitem', { name: 'For a week' }));
    expect(await screen.findByText(/Alert snoozed until/)).toBeInTheDocument();
    const snooze = bodies[1]!;
    expect(snooze.id).toBe(ALERT_FORECAST);
    expect(snooze.body.status).toBe('snoozed');
    expect(Date.parse(String(snooze.body.snoozed_until))).toBeGreaterThan(
      Date.now() + 6 * 24 * 3600 * 1000,
    );
    expect(await within(alerts).findByText('No budget alerts')).toBeInTheDocument();
    expect(calls.count).toBe(3);
  });

  it('keeps the alert and says so when a change is refused', async () => {
    server.use(
      summaryHandler(),
      planningHandler({ count: 0 }),
      http.patch(`${API}/budget-alerts/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    const alerts = await screen.findByRole('region', { name: 'Budget alerts' });
    await user.click(
      await within(alerts).findByRole('button', {
        name: 'Dismiss: Travel reached 100% of its limit',
      }),
    );
    expect(await screen.findByText('We couldn’t update the alert')).toBeInTheDocument();
    expect(
      within(alerts).getByRole('link', { name: 'Travel reached 100% of its limit' }),
    ).toBeInTheDocument();
  });

  it('shows a calm empty state on each card, without View all links', async () => {
    server.use(summaryHandler(), planningHandler({ count: 0 }, emptyPlanning()));
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    const budgets = await screen.findByRole('region', { name: 'Budgets' });
    expect(await within(budgets).findByText('No active budgets')).toBeInTheDocument();
    expect(within(budgets).getByRole('link', { name: 'Create a budget' })).toHaveAttribute(
      'href',
      '/budgets/new',
    );
    const upcoming = screen.getByRole('region', { name: 'Coming up' });
    expect(within(upcoming).getByText('Nothing due in the next two weeks')).toBeInTheDocument();
    const goals = screen.getByRole('region', { name: 'Goals' });
    expect(within(goals).getByText('No active goals')).toBeInTheDocument();
    const groups = screen.getByRole('region', { name: 'Group balances' });
    expect(within(groups).getByText('All settled up')).toBeInTheDocument();
    const alerts = screen.getByRole('region', { name: 'Budget alerts' });
    expect(within(alerts).getByText('No budget alerts')).toBeInTheDocument();
    expect(within(alerts).queryByRole('button')).not.toBeInTheDocument();
    const renewals = screen.getByRole('region', { name: 'Renewals and trials' });
    expect(within(renewals).getByText('No renewals in the next 30 days')).toBeInTheDocument();
    expect(
      within(renewals).getByText('Due through Dec 12, 2026, soonest first'),
    ).toBeInTheDocument();
    expect(within(renewals).getByRole('link', { name: 'Add a subscription' })).toHaveAttribute(
      'href',
      '/subscriptions/new',
    );
    const recurring = screen.getByRole('region', { name: 'Recurring per month' });
    expect(within(recurring).getByText('No recurring schedules yet')).toBeInTheDocument();
    expect(within(recurring).getByRole('link', { name: 'Add a recurring item' })).toHaveAttribute(
      'href',
      '/planning/recurring/new',
    );
    expect(screen.queryByRole('link', { name: /^View all \d/ })).not.toBeInTheDocument();
    expect(
      screen.queryByRole('link', { name: 'View recurring schedules' }),
    ).not.toBeInTheDocument();
  });

  it('shows loading, then an error with retry on each card; one retry refreshes them all', async () => {
    let fail = true;
    const calls = { count: 0 };
    server.use(
      summaryHandler(),
      http.get(`${API}/dashboard/planning`, async () => {
        calls.count += 1;
        await delay(30);
        return fail
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(envelope(makePlanning()));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    const budgets = await screen.findByRole('region', { name: 'Budgets' });
    expect(within(budgets).getByText('Loading your budgets…')).toBeInTheDocument();
    expect(
      within(screen.getByRole('region', { name: 'Budget alerts' })).getByText(
        'Loading your budget alerts…',
      ),
    ).toBeInTheDocument();
    expect(await within(budgets).findByText('We couldn’t load your budgets')).toBeInTheDocument();
    const upcoming = screen.getByRole('region', { name: 'Coming up' });
    expect(within(upcoming).getByText('We couldn’t load what’s coming up')).toBeInTheDocument();
    expect(
      within(screen.getByRole('region', { name: 'Goals' })).getByText(
        'We couldn’t load your goals',
      ),
    ).toBeInTheDocument();
    expect(
      within(screen.getByRole('region', { name: 'Group balances' })).getByText(
        'We couldn’t load your group balances',
      ),
    ).toBeInTheDocument();
    for (const [name, text] of [
      ['Budget alerts', 'We couldn’t load your budget alerts'],
      ['Renewals and trials', 'We couldn’t load your renewals'],
      ['Recurring per month', 'We couldn’t load your recurring commitments'],
    ] as const) {
      expect(within(screen.getByRole('region', { name })).getByText(text)).toBeInTheDocument();
    }
    // The summary widgets are unaffected.
    expect(screen.getByRole('region', { name: 'Cash flow' })).toBeInTheDocument();
    expect(calls.count).toBe(1);

    fail = false;
    await user.click(within(upcoming).getByRole('button', { name: 'Try again' }));
    expect(await within(budgets).findByRole('link', { name: 'Travel' })).toBeInTheDocument();
    expect(
      within(screen.getByRole('region', { name: 'Renewals and trials' })).getByRole('link', {
        name: 'Music',
      }),
    ).toBeInTheDocument();
    expect(
      within(screen.getByRole('region', { name: 'Goals' })).getByRole('link', {
        name: 'Goa trip',
      }),
    ).toBeInTheDocument();
    expect(calls.count).toBe(2);
  });

  it('shows permission denied on each card when the API refuses', async () => {
    server.use(
      summaryHandler(),
      http.get(`${API}/dashboard/planning`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    const budgets = await screen.findByRole('region', { name: 'Budgets' });
    expect(await within(budgets).findByText('You don’t have access to this')).toBeInTheDocument();
    for (const name of [
      'Coming up',
      'Goals',
      'Group balances',
      'Budget alerts',
      'Renewals and trials',
      'Recurring per month',
    ]) {
      expect(
        within(screen.getByRole('region', { name })).getByText('You don’t have access to this'),
      ).toBeInTheDocument();
    }
    expect(screen.queryByRole('button', { name: 'Try again' })).not.toBeInTheDocument();
  });

  it('does not request the planning cards while they are all hidden', async () => {
    const calls = { count: 0 };
    testBackend.widgets = defaultWidgets().map((widget) =>
      [
        'alerts',
        'budgets',
        'upcoming',
        'renewals',
        'recurring',
        'goals',
        'group_balances',
      ].includes(widget.key)
        ? { ...widget, visible: false }
        : widget,
    );
    server.use(summaryHandler(), planningHandler(calls));
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    await screen.findByRole('region', { name: 'Recent transactions' });
    expect(screen.queryByRole('region', { name: 'Budgets' })).not.toBeInTheDocument();
    expect(calls.count).toBe(0);
  });

  it('places the planning cards where the saved layout puts them', async () => {
    testBackend.accounts = [makeAccount()];
    testBackend.widgets = [
      { key: 'goals', position: 0, visible: true, settings: {} },
      { key: 'balances', position: 1, visible: true, settings: {} },
      { key: 'upcoming', position: 2, visible: true, settings: {} },
    ];
    server.use(summaryHandler(), planningHandler({ count: 0 }));
    renderRoute('/dashboard', { user: returning() });
    await findPageHeading('Home');
    await screen.findByRole('region', { name: 'Goals' });
    const titles = screen
      .getAllByRole('heading', { level: 2 })
      .map((heading) => heading.textContent)
      .filter((text) => text !== 'How these figures are calculated');
    expect(titles).toEqual(['Goals', 'Balances', 'Coming up']);
  });
});
