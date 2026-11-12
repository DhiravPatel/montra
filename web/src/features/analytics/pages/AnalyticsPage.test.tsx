import type { QueryClient } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { AppProviders } from '@/app/providers/AppProviders';
import { routes } from '@/app/router/routes';
import { CSRF_COOKIE } from '@/shared/api/csrf';
import {
  BUDGET_FOOD,
  GOAL_TRIP,
  makeBudgetPerformance,
  makeCashFlowReport,
  makeCategoryReport,
  makeComparison,
  makeConverted,
  makeExpensesReport,
  makeGoalReport,
  makeIncomeReport,
  makeMerchantReport,
  makeRecurringReport,
  makeSubscriptionSummary,
  MERCHANT_BAZAAR,
  totals,
} from '@/tests/analyticsFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACCOUNT_CASH,
  CATEGORY_GROCERIES,
  CATEGORY_SALARY,
  CATEGORY_TRAVEL,
  makeAccount,
  makePreferences,
  money,
  starterCategories,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { createTestQueryClient, findPageHeading, renderRoute } from '@/tests/render';

const returning = () => makeUser({ onboarding_completed: true });

/** Answers GET `path` with `body` and records every request URL. */
function serve(path: string, body: unknown, record: URL[] = []) {
  return http.get(`${API}${path}`, ({ request }) => {
    record.push(new URL(request.url));
    return HttpResponse.json(envelope(body));
  });
}

function categoriesHandlers(record: { categories?: URL[]; expenses?: URL[]; income?: URL[] } = {}) {
  return [
    serve('/analytics/categories', makeCategoryReport(), record.categories),
    serve('/analytics/expenses', makeExpensesReport(), record.expenses),
    serve('/analytics/income', makeIncomeReport(), record.income),
  ];
}

describe('AnalyticsPage — cash flow', () => {
  it('shows each currency separately with the previous period, savings rate and coverage', async () => {
    const requests: URL[] = [];
    server.use(serve('/analytics/cash-flow', makeCashFlowReport(), requests));
    renderRoute('/analytics', { user: returning() });
    await findPageHeading('Analytics');

    const inr = await screen.findByRole('region', { name: 'In INR' });
    expect(within(inr).getByText('₹50,000.00')).toBeInTheDocument();
    expect(within(inr).getByText('₹2,149.50')).toBeInTheDocument();
    expect(within(inr).getByText('+₹47,850.50')).toBeInTheDocument();
    expect(within(inr).getByText('More came in than went out')).toBeInTheDocument();
    expect(within(inr).getByText('95.7%')).toBeInTheDocument();
    expect(within(inr).getByText('Previous period: ₹300.00')).toBeInTheDocument();
    expect(
      within(inr).getByText(
        'Spending before refunds ₹2,249.50; refunds ₹100.00; from 4 transactions.',
      ),
    ).toBeInTheDocument();

    const usd = screen.getByRole('region', { name: 'In USD' });
    expect(within(usd).getByText('$100.00')).toBeInTheDocument();
    expect(within(usd).getAllByText('No activity in the previous period').length).toBeGreaterThan(
      0,
    );

    // The window and the same-length previous period the API compared with.
    const cashFlow = screen.getByRole('region', { name: 'Cash flow' });
    expect(within(cashFlow).getByText(/Nov 1\s–\s30, 2026 \(Asia\/Kolkata\)/)).toBeInTheDocument();
    expect(within(cashFlow).getByText(/Previous period: Oct 2\s–\s31, 2026/)).toBeInTheDocument();

    const coverage = screen.getByRole('region', { name: 'About these figures' });
    expect(
      within(coverage).getByRole('link', { name: '2 transactions without a category' }),
    ).toHaveAttribute(
      'href',
      '/transactions?from=2026-11-01&to=2026-11-30&status=posted&uncategorized=true&type=expense%2Cincome',
    );
    expect(within(coverage).getByRole('link', { name: '1 pending transaction' })).toHaveAttribute(
      'href',
      '/transactions?status=pending',
    );

    // The default period comes from the user's preference; no conversion unless asked.
    expect(requests[0]?.searchParams.get('range')).toBe('this_month');
    expect(requests[0]?.searchParams.has('display_currency')).toBe(false);
  });

  it('never adds currencies together: each block holds only its own currency', async () => {
    server.use(serve('/analytics/cash-flow', makeCashFlowReport()));
    renderRoute('/analytics', { user: returning() });
    const inr = await screen.findByRole('region', { name: 'In INR' });
    const usd = screen.getByRole('region', { name: 'In USD' });
    expect(within(inr).queryByText(/\$/)).not.toBeInTheDocument();
    expect(within(usd).queryByText(/₹/)).not.toBeInTheDocument();
    // No combined figure is shown without a chosen display currency.
    expect(screen.queryByRole('region', { name: /Converted to/ })).not.toBeInTheDocument();
  });

  it('gives every chart a text summary and a data table', async () => {
    server.use(serve('/analytics/cash-flow', makeCashFlowReport()));
    const user = userEvent.setup();
    renderRoute('/analytics', { user: returning() });
    const chart = await screen.findByRole('figure', {
      name: 'Income and spending over time in INR',
    });
    expect(chart).toHaveAccessibleDescription(
      'Weekly amounts from the week of Oct 26, 2026 to the week of Nov 9, 2026. Highest income: ₹50,000.00 (Week of Oct 26, 2026). Highest spending: ₹1,250.50 (Week of Oct 26, 2026).',
    );
    await user.click(within(chart).getByRole('button', { name: 'Show as table' }));
    const table = within(chart).getByRole('table', {
      name: 'Income and spending over time in INR',
    });
    const row = within(table).getByRole('row', { name: /Week of Nov 2, 2026/ });
    expect(within(row).getByText('₹899.00')).toBeInTheDocument();
    expect(within(row).getByText('-₹899.00')).toBeInTheDocument();
  });

  it('adds a converted total only with the rates the API disclosed', async () => {
    const requests: URL[] = [];
    server.use(
      http.get(`${API}/analytics/cash-flow`, ({ request }) => {
        const url = new URL(request.url);
        requests.push(url);
        const converted = url.searchParams.get('display_currency')
          ? makeConverted({ unconverted: ['JPY'] })
          : undefined;
        const report = makeCashFlowReport({
          totals: [
            ...makeCashFlowReport().totals,
            totals('JPY', { income: '0', gross: '1500', net: '1500', flow: '-1500', count: 1 }),
          ],
          ...(converted ? { converted } : {}),
        });
        return HttpResponse.json(envelope(report));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/analytics', { user: returning() });
    await screen.findByRole('region', { name: 'In INR' });

    await user.selectOptions(screen.getByLabelText(/Converted total/), 'INR');
    const card = await screen.findByRole('region', { name: 'Converted to INR' });
    expect(requests.at(-1)?.searchParams.get('display_currency')).toBe('INR');
    expect(within(card).getByText('₹58,312.34')).toBeInTheDocument();
    expect(within(card).getByText('+₹52,663.34')).toBeInTheDocument();
    expect(within(card).getByText('1 USD = 83.1234 INR')).toBeInTheDocument();
    expect(within(card).getByText('Manual rate')).toBeInTheDocument();
    expect(within(card).getByText('As of November 1, 2026')).toBeInTheDocument();
    expect(within(card).getByText('Some currencies are not included')).toBeInTheDocument();
    expect(
      within(card).getByText(
        'No exchange rate is available for JPY, so they are left out of this total.',
      ),
    ).toBeInTheDocument();
    expect(within(card).getByRole('link', { name: 'Add an exchange rate' })).toHaveAttribute(
      'href',
      '/settings/exchange-rates',
    );
    expect(within(card).getByText(/Includes INR and USD\./)).toBeInTheDocument();
    // The choice is kept in the address as a currency code only.
    expect(router.state.location.search).toBe('?range=this_month&display=INR');
  });

  it('recomputes for a new period and keeps only dates and IDs in the address', async () => {
    testBackend.accounts = [makeAccount()];
    const requests: URL[] = [];
    server.use(serve('/analytics/cash-flow', makeCashFlowReport(), requests));
    const user = userEvent.setup();
    const { router } = renderRoute('/analytics', { user: returning() });
    await screen.findByRole('region', { name: 'In INR' });

    await user.selectOptions(screen.getByLabelText('Period'), 'last_month');
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('range')).toBe('last_month');
    });

    await user.selectOptions(screen.getByLabelText('Period'), 'custom');
    expect(await screen.findByText('Choose your dates')).toBeInTheDocument();
    const count = requests.length;
    await user.type(screen.getByLabelText('From'), '2026-11-20');
    await user.type(screen.getByLabelText('To'), '2026-11-10');
    expect(
      await screen.findByText('The start date must be on or before the end date.'),
    ).toBeInTheDocument();
    expect(requests).toHaveLength(count);

    await user.clear(screen.getByLabelText('To'));
    await user.type(screen.getByLabelText('To'), '2026-11-25');
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('from')).toBe('2026-11-20');
    });
    expect(requests.at(-1)?.searchParams.get('to')).toBe('2026-11-25');
    expect(requests.at(-1)?.searchParams.has('range')).toBe(false);

    await user.selectOptions(screen.getByLabelText('Account (optional)'), ACCOUNT_CASH);
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('account_id')).toBe(ACCOUNT_CASH);
    });
    expect(router.state.location.search).toBe(
      `?range=custom&from=2026-11-20&to=2026-11-25&account_id=${ACCOUNT_CASH}`,
    );
  });

  it('starts from the preferred default period and groups by the chosen bucket', async () => {
    testBackend.preferences = makePreferences({ default_date_range: 'last_90_days' });
    const requests: URL[] = [];
    server.use(serve('/analytics/cash-flow', makeCashFlowReport(), requests));
    const user = userEvent.setup();
    renderRoute('/analytics', { user: returning() });
    await screen.findByRole('region', { name: 'In INR' });
    expect(requests).toHaveLength(1);
    expect(requests[0]?.searchParams.get('range')).toBe('last_90_days');

    const groupBy = screen.getByLabelText('Group by');
    expect(
      within(groupBy)
        .getAllByRole('option')
        .map((option) => option.textContent),
    ).toEqual(['Automatic', 'Day', 'Week', 'Month', 'Year']);
    await user.selectOptions(groupBy, 'month');
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('granularity')).toBe('month');
    });
  });

  it('shows a calm empty state when nothing happened in the period', async () => {
    server.use(
      serve(
        '/analytics/cash-flow',
        makeCashFlowReport({ totals: [], previous_period: [], series: [] }),
      ),
    );
    renderRoute('/analytics', { user: returning() });
    expect(await screen.findByText('No income or spending in this period')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Add transaction' })).toHaveAttribute(
      'href',
      '/transactions/new',
    );
  });

  it('explains a failure and recovers with retry', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/analytics/cash-flow`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(envelope(makeCashFlowReport()));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/analytics', { user: returning() });
    expect(await screen.findByText('We couldn’t work out these figures')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('region', { name: 'In INR' })).toBeInTheDocument();
  });

  it('keeps the figures on screen when a later refresh fails', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/analytics/cash-flow`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(envelope(makeCashFlowReport()))
          : HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 });
      }),
    );
    const { queryClient } = renderRoute('/analytics', { user: returning() });
    await screen.findByRole('region', { name: 'In INR' });
    await queryClient.refetchQueries({ queryKey: ['finance', 'analytics'] });
    expect(
      await screen.findByText('These figures couldn’t be refreshed, so they may be out of date.'),
    ).toBeInTheDocument();
    expect(screen.getByRole('region', { name: 'In INR' })).toBeInTheDocument();
  });

  it('shows the permission state when access is refused', async () => {
    server.use(
      http.get(`${API}/analytics/cash-flow`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/analytics', { user: returning() });
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});

describe('AnalyticsPage — categories and merchants', () => {
  it('ranks spending by category with transaction links (IDs only) and a table', async () => {
    testBackend.categories = starterCategories();
    const record = { categories: [] as URL[], expenses: [] as URL[], income: [] as URL[] };
    server.use(...categoriesHandlers(record));
    const user = userEvent.setup();
    renderRoute('/analytics?view=categories', { user: returning() });
    await findPageHeading('Analytics');

    const card = await screen.findByRole('region', { name: 'Spending by category' });
    const inr = await within(card).findByRole('region', { name: 'In INR' });
    expect(within(inr).getByRole('link', { name: 'Groceries' })).toHaveAttribute(
      'href',
      `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_GROCERIES}&status=posted&type=expense%2Cgroup_expense%2Crefund%2Creimbursement`,
    );
    expect(within(inr).getByRole('link', { name: 'Weekend trips' })).toHaveAttribute(
      'href',
      `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_TRAVEL}&status=posted&type=expense%2Cgroup_expense%2Crefund%2Creimbursement`,
    );
    expect(within(inr).getByRole('link', { name: 'Uncategorized' })).toHaveAttribute(
      'href',
      '/transactions?from=2026-11-01&to=2026-11-30&status=posted&uncategorized=true&type=expense%2Cgroup_expense%2Crefund%2Creimbursement',
    );
    const figure = within(inr).getByRole('figure', { name: 'Spending by category in INR' });
    expect(figure).toHaveAccessibleDescription(
      'Your largest spending category was Groceries: ₹1,250.50, 58.2% of your spending.',
    );
    await user.click(within(figure).getByRole('button', { name: 'Show as table' }));
    const table = within(figure).getByRole('table', { name: 'Spending by category in INR' });
    expect(
      within(table).getByRole('row', { name: /Weekend trips ₹800\.00 37\.2% 1/ }),
    ).toBeInTheDocument();

    // USD spending stays in its own block.
    const usd = within(card).getByRole('region', { name: 'In USD' });
    expect(within(usd).getByText('$42.10')).toBeInTheDocument();

    // Spending and income over time come from their own endpoints with the same period.
    const spending = screen.getByRole('region', { name: 'Spending over time' });
    expect(within(spending).getByText('Previous period: ₹300.00')).toBeInTheDocument();
    expect(
      within(spending).getByRole('figure', { name: 'Spending over time in INR' }),
    ).toBeInTheDocument();
    expect(within(spending).getByRole('link', { name: 'View transactions' })).toHaveAttribute(
      'href',
      '/transactions?from=2026-11-01&to=2026-11-30&status=posted&type=expense%2Cgroup_expense%2Crefund%2Creimbursement',
    );
    const income = screen.getByRole('region', { name: 'Income over time' });
    expect(within(income).getByText('₹50,000.00')).toBeInTheDocument();
    expect(record.expenses[0]?.searchParams.get('range')).toBe('this_month');
    expect(record.income[0]?.searchParams.get('range')).toBe('this_month');

    await user.click(screen.getByLabelText('Show subcategories separately'));
    await waitFor(() => {
      expect(record.categories.at(-1)?.searchParams.get('subcategories')).toBe('true');
    });
  });

  it('breaks income down by category (kind=income) with the API’s amounts', async () => {
    testBackend.categories = starterCategories();
    const requests: URL[] = [];
    server.use(
      http.get(`${API}/analytics/categories`, ({ request }) => {
        const url = new URL(request.url);
        requests.push(url);
        if (url.searchParams.get('kind') !== 'income') {
          return HttpResponse.json(envelope(makeCategoryReport()));
        }
        return HttpResponse.json(
          envelope(
            makeCategoryReport({
              kind: 'income',
              categories: [
                {
                  category_id: CATEGORY_SALARY,
                  name: 'Salary',
                  system_key: 'salary',
                  currency: 'INR',
                  amount: money('50000.00'),
                  net_expense: money('0.00'),
                  count: 1,
                  share_bp: 10000,
                  subcategory: false,
                  drill_down_path: '/transactions?from=2026-11-01&to=2026-11-30&uncategorized=true',
                },
              ],
            }),
          ),
        );
      }),
      serve('/analytics/expenses', makeExpensesReport()),
      serve('/analytics/income', makeIncomeReport()),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/analytics?view=categories', { user: returning() });
    await screen.findByRole('region', { name: 'Spending by category' });
    await waitFor(() => {
      expect(requests[0]?.searchParams.has('kind')).toBe(false);
    });

    await user.click(screen.getByRole('radio', { name: 'Income' }));
    const card = await screen.findByRole('region', { name: 'Income by category' });
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('kind')).toBe('income');
    });
    const figure = await within(card).findByRole('figure', { name: 'Income by category in INR' });
    expect(figure).toHaveAccessibleDescription(
      'Your largest income category was Salary: ₹50,000.00, 100% of your income.',
    );
    expect(within(card).getByRole('link', { name: 'Salary' })).toHaveAttribute(
      'href',
      `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_SALARY}&status=posted&type=income`,
    );
    expect(router.state.location.search).toBe('?view=categories&range=this_month&kind=income');
  });

  it('shows category names in the interface language by their starter key', async () => {
    testBackend.user = returning();
    document.cookie = `${CSRF_COOKIE}=csrf-cookie-token; path=/`;
    server.use(...categoriesHandlers());
    const queryClient: QueryClient = createTestQueryClient();
    render(
      <AppProviders queryClient={queryClient} language="hi">
        <RouterProvider
          router={createMemoryRouter(routes, { initialEntries: ['/analytics?view=categories'] })}
        />
      </AppProviders>,
    );
    const card = await screen.findByRole('region', { name: 'श्रेणी के अनुसार खर्च' });
    expect((await within(card).findAllByRole('link', { name: 'किराना' })).length).toBeGreaterThan(
      0,
    );
    expect(within(card).getByRole('link', { name: 'बिना श्रेणी' })).toBeInTheDocument();
    // A name the user chose is kept as it is.
    expect(within(card).getByRole('link', { name: 'Weekend trips' })).toBeInTheDocument();
  });

  it('ranks merchants per currency and links to their transactions', async () => {
    const requests: URL[] = [];
    server.use(serve('/analytics/merchants', makeMerchantReport(), requests));
    renderRoute('/analytics?view=merchants&range=this_month', { user: returning() });
    const card = await screen.findByRole('region', { name: 'Top merchants' });
    const inr = within(card).getByRole('region', { name: 'In INR' });
    expect(within(inr).getByRole('link', { name: 'Big Bazaar' })).toHaveAttribute(
      'href',
      `/transactions?from=2026-11-01&to=2026-11-30&status=posted&merchant_id=${MERCHANT_BAZAAR}&type=expense%2Cgroup_expense%2Crefund%2Creimbursement`,
    );
    expect(
      within(inr).getByRole('figure', { name: 'Top merchants in INR' }),
    ).toHaveAccessibleDescription(
      'You spent the most at Big Bazaar: ₹1,250.50 across 2 transactions.',
    );
    expect(within(card).getByRole('region', { name: 'In USD' })).toHaveTextContent('Corner Cafe');
    expect(requests[0]?.searchParams.get('limit')).toBe('100');
  });

  it('says when there is no merchant spending', async () => {
    server.use(serve('/analytics/merchants', makeMerchantReport({ merchants: [] })));
    renderRoute('/analytics?view=merchants', { user: returning() });
    expect(await screen.findByText('No merchant spending in this period')).toBeInTheDocument();
  });
});

describe('AnalyticsPage — compare periods', () => {
  it('compares the resolved period with the period before, per currency', async () => {
    const compares: URL[] = [];
    server.use(
      serve('/analytics/cash-flow', makeCashFlowReport()),
      serve('/analytics/compare', makeComparison(), compares),
    );
    const user = userEvent.setup();
    renderRoute('/analytics?view=compare', { user: returning() });
    const card = await screen.findByRole('region', { name: 'Comparison' });

    const sent = compares[0]!.searchParams;
    expect(sent.get('from')).toBe('2026-11-01');
    expect(sent.get('to')).toBe('2026-11-30');
    expect(sent.get('compare_from')).toBe('2026-10-02');
    expect(sent.get('compare_to')).toBe('2026-10-31');

    const inr = within(card).getByRole('region', { name: 'In INR' });
    const totalsTable = within(inr).getByRole('table', { name: 'Totals for both periods in INR' });
    const income = within(totalsTable).getByRole('row', { name: /^Income/ });
    expect(within(income).getByText('₹50,000.00')).toBeInTheDocument();
    expect(within(income).getByText('₹0.00')).toBeInTheDocument();
    // The change is the API's (no percentage when the comparison was zero).
    expect(within(income).getByText('+₹50,000.00')).toBeInTheDocument();
    expect(within(income).getByText('Higher')).toBeInTheDocument();
    const spending = within(totalsTable).getByRole('row', { name: /^Spending/ });
    expect(within(spending).getByText('+₹1,849.50 (+616.5%)')).toBeInTheDocument();
    const count = within(totalsTable).getByRole('row', { name: /^Transactions/ });
    expect(within(count).getByText('+3')).toBeInTheDocument();

    // The API's category changes, largest first, with its own change and percentage.
    const figure = within(inr).getByRole('figure', {
      name: 'Spending by category in both periods in INR',
    });
    expect(figure).toHaveAccessibleDescription(
      'The largest change was in Groceries: +₹950.50, +316.8%.',
    );
    expect(within(figure).getByText('(+₹800.00, new this period)')).toBeInTheDocument();
    await user.click(within(figure).getByRole('button', { name: 'Show as table' }));
    const changes = within(figure).getByRole('table');
    expect(
      within(changes).getByRole('row', {
        name: /Groceries ₹1,250\.50 ₹300\.00 \+₹950\.50 \+316\.8%/,
      }),
    ).toBeInTheDocument();
    expect(within(changes).getByRole('row', { name: /Weekend trips .* New/ })).toBeInTheDocument();

    const usd = within(card).getByRole('region', { name: 'In USD' });
    expect(within(usd).getByText('(-$7.90, -15.8%)')).toBeInTheDocument();
    expect(within(usd).queryByText(/₹/)).not.toBeInTheDocument();

    // The notes by note_code, in the interface language.
    const notes = screen.getByRole('region', { name: 'How the periods are compared' });
    expect(
      within(notes).getByText(
        'Both periods use the same filters and rules: transfers are not counted and refunds reduce spending.',
      ),
    ).toBeInTheDocument();
    expect(
      within(notes).getByText(
        'Each currency is compared on its own; currencies are never added together.',
      ),
    ).toBeInTheDocument();
    expect(within(notes).queryByText('Currencies are never added together.')).toBeNull();
  });

  it('compares with the same dates last year or with custom dates', async () => {
    const compares: URL[] = [];
    server.use(serve('/analytics/compare', makeComparison(), compares));
    const user = userEvent.setup();
    renderRoute('/analytics?view=compare&range=custom&from=2026-11-01&to=2026-11-30', {
      user: returning(),
    });
    await screen.findByRole('region', { name: 'Comparison' });
    expect(compares[0]?.searchParams.get('compare_from')).toBe('2026-10-02');

    await user.click(screen.getByLabelText('Same dates last year'));
    await waitFor(() => {
      expect(compares.at(-1)?.searchParams.get('compare_from')).toBe('2025-11-01');
    });
    expect(compares.at(-1)?.searchParams.get('compare_to')).toBe('2025-11-30');

    await user.click(screen.getByLabelText('Other dates'));
    // Custom dates start from the period before, ready to adjust.
    expect(screen.getByLabelText('Compare from')).toHaveValue('2026-10-02');
    await user.clear(screen.getByLabelText('Compare from'));
    expect(await screen.findByText('Choose the dates to compare with')).toBeInTheDocument();
    await user.type(screen.getByLabelText('Compare from'), '2026-09-01');
    await user.clear(screen.getByLabelText('Compare to'));
    await user.type(screen.getByLabelText('Compare to'), '2026-09-30');
    await waitFor(() => {
      expect(compares.at(-1)?.searchParams.get('compare_from')).toBe('2026-09-01');
    });
    expect(compares.at(-1)?.searchParams.get('compare_to')).toBe('2026-09-30');
  });

  it('explains a comparison failure', async () => {
    server.use(
      serve('/analytics/cash-flow', makeCashFlowReport()),
      http.get(`${API}/analytics/compare`, () =>
        HttpResponse.json(errorBody({ code: 'VALIDATION_ERROR' }), { status: 422 }),
      ),
    );
    renderRoute('/analytics?view=compare', { user: returning() });
    expect(await screen.findByText('We couldn’t compare these periods')).toBeInTheDocument();
    expect(
      screen.getByText('These filters couldn’t be used. Check the dates and try again.'),
    ).toBeInTheDocument();
  });
});

describe('AnalyticsPage — accounts and plans', () => {
  it('shows balances per currency as of now, optionally for overview accounts only', async () => {
    const requests: URL[] = [];
    server.use(
      serve(
        '/analytics/accounts',
        {
          totals: [
            {
              currency: 'INR',
              assets: money('57550.50'),
              liabilities: money('2000.00'),
              net_worth: money('55550.50'),
              account_count: 2,
            },
            {
              currency: 'USD',
              assets: money('557.90', 'USD'),
              liabilities: money('0.00', 'USD'),
              net_worth: money('557.90', 'USD'),
              account_count: 1,
            },
          ],
        },
        requests,
      ),
    );
    const user = userEvent.setup();
    renderRoute('/analytics?view=accounts', { user: returning() });
    const inr = await screen.findByRole('region', { name: 'In INR' });
    expect(within(inr).getByText('₹57,550.50')).toBeInTheDocument();
    expect(within(inr).getByText('+₹55,550.50')).toBeInTheDocument();
    expect(
      within(screen.getByRole('region', { name: 'In USD' })).getByText('$557.90'),
    ).toBeInTheDocument();
    // No period filter here: balances are point-in-time.
    expect(screen.queryByLabelText('Period')).not.toBeInTheDocument();

    await user.click(screen.getByLabelText('Only accounts shown in my overview'));
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('overview_only')).toBe('true');
    });
  });

  it('summarizes budgets, goals, subscriptions and recurring commitments', async () => {
    server.use(
      serve('/analytics/budgets', makeBudgetPerformance()),
      serve('/analytics/goals', makeGoalReport()),
      serve('/analytics/subscriptions', makeSubscriptionSummary()),
      serve('/analytics/recurring', makeRecurringReport()),
    );
    renderRoute('/analytics?view=plans', { user: returning() });

    const budgets = await screen.findByRole('region', { name: 'Budgets' });
    expect(await within(budgets).findByRole('link', { name: 'Food' })).toHaveAttribute(
      'href',
      `/budgets/${BUDGET_FOOD}`,
    );
    expect(within(budgets).getByText('Over the limit: 1')).toBeInTheDocument();
    expect(within(budgets).getByRole('meter', { name: 'Food budget' })).toHaveAttribute(
      'aria-valuetext',
      '₹11,250.00 of ₹10,000.00 spent',
    );

    const goals = screen.getByRole('region', { name: 'Goals' });
    expect(await within(goals).findByText('₹6,000.00')).toBeInTheDocument();
    expect(within(goals).getByText('1 goal, 0 achieved')).toBeInTheDocument();
    expect(within(goals).getByRole('link', { name: 'Goa trip' })).toHaveAttribute(
      'href',
      `/goals/${GOAL_TRIP}`,
    );

    const subscriptions = screen.getByRole('region', { name: 'Subscriptions' });
    expect(await within(subscriptions).findByText('₹199.00')).toBeInTheDocument();
    expect(within(subscriptions).getByText('$9.99')).toBeInTheDocument();
    expect(
      within(subscriptions).getByText('Montra noticed 2 payments that look like subscriptions'),
    ).toBeInTheDocument();

    const recurring = screen.getByRole('region', { name: 'Recurring commitments' });
    expect(await within(recurring).findByText('Bill')).toBeInTheDocument();
    expect(within(recurring).getByText('2 (1 without a fixed amount)')).toBeInTheDocument();
    expect(
      within(recurring).getByText(
        'Monthly amounts use fixed rule amounts only. Bills and income are expected amounts, not recorded money.',
      ),
    ).toBeInTheDocument();
  });

  it('keeps the other summaries when one fails, and shows empty states', async () => {
    server.use(
      http.get(`${API}/analytics/budgets`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
      serve('/analytics/goals', { totals: [], goals: [] }),
      serve('/analytics/subscriptions', {
        totals: [],
        upcoming_renewals: [],
        trials_ending_soon: [],
        pending_detections: 0,
      }),
      serve('/analytics/recurring', makeRecurringReport({ commitments: [] })),
    );
    renderRoute('/analytics?view=plans', { user: returning() });
    const budgets = await screen.findByRole('region', { name: 'Budgets' });
    expect(
      await within(budgets).findByText('We couldn’t work out these figures'),
    ).toBeInTheDocument();
    expect(await screen.findByText('No goals yet')).toBeInTheDocument();
    expect(screen.getByText('No subscriptions yet')).toBeInTheDocument();
    expect(screen.getByText('No active recurring rules')).toBeInTheDocument();
  });
});

describe('AnalyticsPage — sections', () => {
  it('switches sections with links that keep the period', async () => {
    server.use(serve('/analytics/cash-flow', makeCashFlowReport()), ...categoriesHandlers());
    const user = userEvent.setup();
    const { router } = renderRoute('/analytics?range=last_month', { user: returning() });
    await screen.findByRole('region', { name: 'In INR' });
    const nav = screen.getByRole('navigation', { name: 'Analytics sections' });
    expect(within(nav).getByRole('link', { name: 'Cash flow' })).toHaveAttribute(
      'aria-current',
      'page',
    );
    await user.click(within(nav).getByRole('link', { name: 'Categories' }));
    expect(await screen.findByRole('region', { name: 'Spending by category' })).toBeInTheDocument();
    expect(router.state.location.search).toBe('?view=categories&range=last_month');
    expect(within(nav).getByRole('link', { name: 'Categories' })).toHaveAttribute(
      'aria-current',
      'page',
    );
  });
});
