import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { DashboardSummary } from '@/shared/finance/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CATEGORY_GROCERIES,
  defaultWidgets,
  makeAccount,
  makeCategory,
  makePreferences,
  makeSummary,
  money,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
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
    expect(await screen.findByText('Cash flow moved to position 1 of 8')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Dashboard layout saved')).toBeInTheDocument();
    expect(bodies[0]).toEqual({
      widgets: [
        { key: 'cash_flow', position: 0, visible: true, settings: {} },
        { key: 'balances', position: 1, visible: false, settings: {} },
        { key: 'income_vs_expense', position: 2, visible: true, settings: {} },
        { key: 'cash_flow_trend', position: 3, visible: true, settings: {} },
        { key: 'category_breakdown', position: 4, visible: true, settings: {} },
        { key: 'top_merchants', position: 5, visible: true, settings: {} },
        { key: 'recent_transactions', position: 6, visible: true, settings: {} },
        { key: 'data_coverage', position: 7, visible: true, settings: {} },
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
