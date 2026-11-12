import type {
  BudgetPerformance,
  BudgetSummaryItem,
  CashFlowReport,
  CashFlowTotals,
  CategoryReport,
  Comparison,
  ConvertedTotals,
  GoalReport,
  GoalSummaryItem,
  MerchantReport,
  RecurringReport,
  SeriesPoint,
  SubscriptionSummary,
} from '@/features/analytics/types';
import { CATEGORY_GROCERIES, CATEGORY_TRAVEL, money } from './financeFixtures';

/** Analytics fixtures shaped like the contract (tests only). Amounts are the API's exact strings. */

export const MERCHANT_BAZAAR = '99999999-9999-4999-8999-999999999901';
export const MERCHANT_CAFE = '99999999-9999-4999-8999-999999999902';
export const BUDGET_FOOD = 'cccccccc-1111-4111-8111-000000000001';
export const SUBSCRIPTION_MUSIC = 'dddddddd-1111-4111-8111-000000000001';

export const NOVEMBER = {
  from: '2026-11-01',
  to: '2026-11-30',
  days: 30,
  timezone: 'Asia/Kolkata',
};

/** The same-length period before November (what `previous_period` covers). */
export const OCTOBER_WINDOW = {
  from: '2026-10-02',
  to: '2026-10-31',
  days: 30,
  timezone: 'Asia/Kolkata',
};

export function totals(
  currency: string,
  values: {
    income: string;
    gross: string;
    refunds?: string;
    net: string;
    flow: string;
    rate?: number;
    count: number;
  },
): CashFlowTotals {
  return {
    currency,
    income: money(values.income, currency),
    gross_expense: money(values.gross, currency),
    refunds: money(values.refunds ?? (currency === 'JPY' ? '0' : '0.00'), currency),
    net_expense: money(values.net, currency),
    net_cash_flow: money(values.flow, currency),
    ...(values.rate === undefined ? {} : { savings_rate_bp: values.rate }),
    transaction_count: values.count,
  };
}

function point(bucket: string, currency: string, income: string, spent: string, net: string) {
  return {
    bucket,
    currency,
    income: money(income, currency),
    net_expense: money(spent, currency),
    net: money(net, currency),
  } satisfies SeriesPoint;
}

/** November in two currencies (INR and USD) with October as the previous period (INR only). */
export function makeCashFlowReport(overrides: Partial<CashFlowReport> = {}): CashFlowReport {
  return {
    window: NOVEMBER,
    totals: [
      totals('INR', {
        income: '50000.00',
        gross: '2249.50',
        refunds: '100.00',
        net: '2149.50',
        flow: '47850.50',
        rate: 9570,
        count: 4,
      }),
      totals('USD', {
        income: '100.00',
        gross: '42.10',
        net: '42.10',
        flow: '57.90',
        rate: 5790,
        count: 2,
      }),
    ],
    previous_period: [
      totals('INR', { income: '0.00', gross: '300.00', net: '300.00', flow: '-300.00', count: 1 }),
    ],
    previous_window: OCTOBER_WINDOW,
    series: [
      point('2026-10-26', 'INR', '50000.00', '1250.50', '48749.50'),
      point('2026-10-26', 'USD', '0.00', '42.10', '-42.10'),
      point('2026-11-02', 'INR', '0.00', '899.00', '-899.00'),
      point('2026-11-02', 'USD', '100.00', '0.00', '100.00'),
      point('2026-11-09', 'INR', '0.00', '0.00', '0.00'),
      point('2026-11-09', 'USD', '0.00', '0.00', '0.00'),
    ],
    series_granularity: 'week',
    coverage: {
      transaction_count: 6,
      earliest_transaction: '2026-11-01',
      latest_transaction: '2026-11-04',
      uncategorized_count: 2,
      pending_count: 1,
      provider_synced: false,
    },
    ...overrides,
  };
}

/** Converted into INR with one disclosed manual rate; JPY had no rate. */
export function makeConverted(overrides: Partial<ConvertedTotals> = {}): ConvertedTotals {
  return {
    currency: 'INR',
    income: money('58312.34', 'INR'),
    gross_expense: money('5749.00', 'INR'),
    refunds: money('100.00', 'INR'),
    net_expense: money('5649.00', 'INR'),
    net_cash_flow: money('52663.34', 'INR'),
    rates: [
      {
        base: 'USD',
        quote: 'INR',
        rate: '83.1234',
        source: 'manual',
        as_of: '2026-11-01T12:00:00Z',
        inverted: false,
      },
    ],
    unconverted: [],
    rate_policy:
      'Latest rate on or before 2026-11-30 (your manual rates first, then provider rates)',
    rate_policy_code: 'latest_on_or_before',
    rate_policy_params: { date: '2026-11-30' },
    ...overrides,
  };
}

export function makeCategoryReport(overrides: Partial<CategoryReport> = {}): CategoryReport {
  return {
    window: NOVEMBER,
    kind: 'expense',
    categories: [
      {
        category_id: CATEGORY_GROCERIES,
        name: 'Groceries',
        system_key: 'groceries',
        currency: 'INR',
        amount: money('1250.50'),
        net_expense: money('1250.50'),
        count: 1,
        share_bp: 5818,
        subcategory: false,
        drill_down_path: `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_GROCERIES}`,
      },
      {
        category_id: CATEGORY_TRAVEL,
        // A starter category the user renamed: their name is kept.
        name: 'Weekend trips',
        system_key: 'travel',
        currency: 'INR',
        amount: money('800.00'),
        net_expense: money('800.00'),
        count: 1,
        share_bp: 3722,
        subcategory: false,
        drill_down_path: `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_TRAVEL}`,
      },
      {
        name: 'Uncategorized',
        system_key: 'uncategorized',
        currency: 'INR',
        amount: money('99.00'),
        net_expense: money('99.00'),
        count: 1,
        share_bp: 460,
        subcategory: false,
        drill_down_path: '/transactions?from=2026-11-01&to=2026-11-30&uncategorized=true',
      },
      {
        category_id: CATEGORY_GROCERIES,
        name: 'Groceries',
        system_key: 'groceries',
        currency: 'USD',
        amount: money('42.10', 'USD'),
        net_expense: money('42.10', 'USD'),
        count: 1,
        share_bp: 10000,
        subcategory: false,
        drill_down_path: `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_GROCERIES}`,
      },
    ],
    ...overrides,
  };
}

/** GET /analytics/expenses: spending only, same model as cash flow. */
export function makeExpensesReport(overrides: Partial<CashFlowReport> = {}): CashFlowReport {
  return makeCashFlowReport({
    totals: [
      totals('INR', {
        income: '0.00',
        gross: '2249.50',
        refunds: '100.00',
        net: '2149.50',
        flow: '-2149.50',
        count: 3,
      }),
    ],
    previous_period: [
      totals('INR', { income: '0.00', gross: '300.00', net: '300.00', flow: '-300.00', count: 1 }),
    ],
    series: [
      point('2026-10-26', 'INR', '0.00', '1250.50', '-1250.50'),
      point('2026-11-02', 'INR', '0.00', '899.00', '-899.00'),
    ],
    ...overrides,
  });
}

/** GET /analytics/income: income only, same model as cash flow. */
export function makeIncomeReport(overrides: Partial<CashFlowReport> = {}): CashFlowReport {
  return makeCashFlowReport({
    totals: [
      totals('INR', {
        income: '50000.00',
        gross: '0.00',
        net: '0.00',
        flow: '50000.00',
        rate: 10000,
        count: 1,
      }),
    ],
    previous_period: [],
    series: [
      point('2026-10-26', 'INR', '50000.00', '0.00', '50000.00'),
      point('2026-11-02', 'INR', '0.00', '0.00', '0.00'),
    ],
    ...overrides,
  });
}

export function makeMerchantReport(overrides: Partial<MerchantReport> = {}): MerchantReport {
  return {
    window: NOVEMBER,
    merchants: [
      {
        merchant_id: MERCHANT_BAZAAR,
        name: 'Big Bazaar',
        currency: 'INR',
        net_expense: money('1250.50'),
        count: 2,
      },
      {
        merchant_id: MERCHANT_CAFE,
        name: 'Corner Cafe',
        currency: 'USD',
        net_expense: money('42.10', 'USD'),
        count: 1,
      },
    ],
    ...overrides,
  };
}

/** November against October 2–31 (the same-length period before), INR and USD. */
export function makeComparison(overrides: Partial<Comparison> = {}): Comparison {
  return {
    window: NOVEMBER,
    comparison_window: { from: '2026-10-02', to: '2026-10-31', days: 30, timezone: 'Asia/Kolkata' },
    currencies: [
      {
        currency: 'INR',
        current: totals('INR', {
          income: '50000.00',
          gross: '2149.50',
          net: '2149.50',
          flow: '47850.50',
          rate: 9570,
          count: 4,
        }),
        comparison: totals('INR', {
          income: '0.00',
          gross: '300.00',
          net: '300.00',
          flow: '-300.00',
          count: 1,
        }),
        change: {
          income: { change: money('50000.00') },
          gross_expense: { change: money('1849.50'), change_bp: 61650 },
          refunds: { change: money('0.00') },
          net_expense: { change: money('1849.50'), change_bp: 61650 },
          net_cash_flow: { change: money('48150.50'), change_bp: 1605017 },
          transaction_count: 3,
        },
        categories: [
          {
            category_id: CATEGORY_GROCERIES,
            name: 'Groceries',
            system_key: 'groceries',
            current: money('1250.50'),
            comparison: money('300.00'),
            change: money('950.50'),
            change_bp: 31683,
          },
          {
            category_id: CATEGORY_TRAVEL,
            name: 'Weekend trips',
            system_key: 'travel',
            current: money('800.00'),
            comparison: money('0.00'),
            change: money('800.00'),
          },
        ],
      },
      {
        currency: 'USD',
        current: totals('USD', {
          income: '100.00',
          gross: '42.10',
          net: '42.10',
          flow: '57.90',
          rate: 5790,
          count: 2,
        }),
        comparison: totals('USD', {
          income: '100.00',
          gross: '50.00',
          net: '50.00',
          flow: '50.00',
          rate: 5000,
          count: 2,
        }),
        change: {
          income: { change: money('0.00', 'USD'), change_bp: 0 },
          gross_expense: { change: money('-7.90', 'USD'), change_bp: -1580 },
          refunds: { change: money('0.00', 'USD') },
          net_expense: { change: money('-7.90', 'USD'), change_bp: -1580 },
          net_cash_flow: { change: money('7.90', 'USD'), change_bp: 1580 },
          transaction_count: 0,
        },
        categories: [
          {
            category_id: CATEGORY_GROCERIES,
            name: 'Groceries',
            system_key: 'groceries',
            current: money('42.10', 'USD'),
            comparison: money('50.00', 'USD'),
            change: money('-7.90', 'USD'),
            change_bp: -1580,
          },
        ],
      },
    ],
    notes: [
      'Both periods use the same filters and rules: transfers excluded, refunds reduce spending.',
      'Currencies are never added together.',
    ],
    note_codes: ['same_filters_and_rules', 'currencies_separate'],
    ...overrides,
  };
}

export function makeBudgetItem(overrides: Partial<BudgetSummaryItem> = {}): BudgetSummaryItem {
  return {
    id: BUDGET_FOOD,
    name: 'Food',
    budget_type: 'category',
    period: 'monthly',
    currency: 'INR',
    limit: money('10000.00'),
    starts_on: '2026-11-01',
    timezone: 'Asia/Kolkata',
    status: 'active',
    access: 'owner',
    alert_forecast: false,
    alert_thresholds: [],
    allocations: [],
    count_group_shares: false,
    excluded_category_ids: [],
    include_pending: false,
    included_account_ids: [],
    merchant_ids: [],
    members: [],
    owner_display_name: 'Asha Rao',
    owner_user_id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
    refunds_restore: true,
    rollover_policy: 'none',
    visibility: 'private',
    version: 1,
    created_at: '2026-11-01T08:00:00Z',
    updated_at: '2026-11-01T08:00:00Z',
    progress: {
      base_limit: money('10000.00'),
      limit: money('10000.00'),
      spent: money('11250.00'),
      remaining: money('0.00'),
      overspent: money('1250.00'),
      expected_by_now: money('1333.33'),
      daily_allowance: money('0.00'),
      projected: money('84375.00'),
      projected_over: money('74375.00'),
      rollover_in: money('0.00'),
      percent_bp: 11250,
      pace: 'over_budget',
      period_start: '2026-11-01',
      period_end: '2026-11-30',
      elapsed_days: 4,
      total_days: 30,
      transaction_count: 6,
      other_currency_count: 0,
      explanation: [],
      explanation_items: [],
    },
    ...overrides,
  };
}

export function makeBudgetPerformance(
  overrides: Partial<BudgetPerformance> = {},
): BudgetPerformance {
  return {
    budgets: [makeBudgetItem()],
    by_pace: { over_budget: 1 },
    over_count: 1,
    ...overrides,
  };
}

export const GOAL_TRIP = 'a0a0a0a0-1111-4111-8111-000000000001';

export function makeGoalItem(overrides: Partial<GoalSummaryItem> = {}): GoalSummaryItem {
  return {
    id: GOAL_TRIP,
    name: 'Goa trip',
    goal_type: 'travel',
    target: money('60000.00'),
    starting: money('1000.00'),
    start_date: '2026-11-01',
    target_date: '2027-06-30',
    priority: 3,
    contribution_schedule: 'monthly',
    visibility: 'private',
    reminders_enabled: false,
    status: 'active',
    access: 'owner',
    owner: { user_id: '7c9e6679-7425-40de-944b-e07fc1f90ae7', display_name: 'Asha Rao' },
    owner_user_id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
    progress: {
      saved: money('6000.00'),
      remaining: money('54000.00'),
      percent_bp: 1000,
      verified: money('3000.00'),
      planned: money('2000.00'),
      contribution_count: 2,
    },
    milestones: [],
    members: [],
    version: 4,
    created_at: '2026-11-01T08:00:00Z',
    ...overrides,
  };
}

export function makeGoalReport(overrides: Partial<GoalReport> = {}): GoalReport {
  return {
    totals: [
      {
        currency: 'INR',
        target: money('60000.00'),
        saved: money('6000.00'),
        count: 1,
        achieved: 0,
      },
    ],
    goals: [makeGoalItem()],
    ...overrides,
  };
}

export function makeSubscriptionSummary(
  overrides: Partial<SubscriptionSummary> = {},
): SubscriptionSummary {
  return {
    totals: [
      { currency: 'INR', monthly: money('199.00'), annual: money('2388.00'), count: 1 },
      { currency: 'USD', monthly: money('9.99', 'USD'), annual: money('119.88', 'USD'), count: 1 },
    ],
    upcoming_renewals: [],
    trials_ending_soon: [],
    pending_detections: 2,
    ...overrides,
  };
}

export function makeRecurringReport(overrides: Partial<RecurringReport> = {}): RecurringReport {
  return {
    commitments: [
      {
        kind: 'bill',
        currency: 'INR',
        monthly_equivalent: money('15000.00'),
        next_30_days: money('15000.00'),
        rule_count: 2,
        variable_count: 1,
      },
      {
        kind: 'income',
        currency: 'INR',
        monthly_equivalent: money('50000.00'),
        next_30_days: money('50000.00'),
        rule_count: 1,
        variable_count: 0,
      },
    ],
    note: 'Monthly equivalents use fixed rule amounts only; bills and income are expectations, not recorded money.',
    note_code: 'fixed_amounts_expectations',
    ...overrides,
  };
}
