import type {
  Account,
  AccountsReport,
  Category,
  DashboardPlanning,
  DashboardSummary,
  PaymentMethod,
  Preferences,
  Tag,
  Transaction,
  Transfer,
  Widget,
} from '@/shared/finance/types';

/** Finance fixtures shaped like the contract (tests only). */

export function money(amount: string, currency = 'INR') {
  const negative = amount.startsWith('-');
  const digits = amount.replace('-', '').replace('.', '');
  const minor = Number(digits) * (negative ? -1 : 1);
  return { amount, amount_minor: minor, currency };
}

export const ACCOUNT_CASH = '11111111-1111-4111-8111-111111111111';
export const ACCOUNT_CARD = '22222222-2222-4222-8222-222222222222';
export const ACCOUNT_USD = '33333333-3333-4333-8333-333333333333';
export const CATEGORY_GROCERIES = '44444444-4444-4444-8444-444444444401';
export const CATEGORY_SALARY = '44444444-4444-4444-8444-444444444402';
export const CATEGORY_TRAVEL = '44444444-4444-4444-8444-444444444403';
export const TAG_HOME = '55555555-5555-4555-8555-555555555501';
export const METHOD_UPI = '66666666-6666-4666-8666-666666666601';
export const TX_GROCERIES = '77777777-7777-4777-8777-777777777701';
export const TX_SALARY = '77777777-7777-4777-8777-777777777702';
export const TRANSFER_ID = '88888888-8888-4888-8888-888888888801';

export function makeAccount(overrides: Partial<Account> = {}): Account {
  return {
    id: ACCOUNT_CASH,
    name: 'Wallet',
    account_type: 'cash',
    is_liability: false,
    currency: 'INR',
    include_in_overview: true,
    opening_date: '2026-11-01',
    balance: money('1500.50'),
    balance_source: 'calculated',
    status: 'active',
    display_order: 0,
    shared_with_group: false,
    owned: true,
    version: 1,
    created_at: '2026-11-01T08:00:00Z',
    updated_at: '2026-11-01T08:00:00Z',
    ...overrides,
  };
}

export function makeCard(overrides: Partial<Account> = {}): Account {
  return makeAccount({
    id: ACCOUNT_CARD,
    name: 'HDFC Credit',
    account_type: 'credit_card',
    is_liability: true,
    masked_number: '4821',
    balance: money('-2000.00'),
    credit_limit: money('50000.00'),
    available_credit: money('48000.00'),
    ...overrides,
  });
}

export function makeCategory(overrides: Partial<Category> = {}): Category {
  return {
    id: CATEGORY_GROCERIES,
    name: 'Groceries',
    kind: 'expense',
    system_key: 'groceries',
    include_in_budgets: true,
    sort_order: 10,
    status: 'active',
    transaction_count: 0,
    version: 1,
    updated_at: '2026-11-01T08:00:00Z',
    ...overrides,
  };
}

export function starterCategories(): Category[] {
  return [
    makeCategory(),
    makeCategory({ id: CATEGORY_TRAVEL, name: 'Travel', system_key: 'travel', sort_order: 100 }),
    makeCategory({
      id: CATEGORY_SALARY,
      name: 'Salary',
      kind: 'income',
      system_key: 'salary',
      sort_order: 170,
    }),
  ];
}

export function makeTag(overrides: Partial<Tag> = {}): Tag {
  return { id: TAG_HOME, name: 'home', usage_count: 1, version: 1, ...overrides };
}

export function makePaymentMethod(overrides: Partial<PaymentMethod> = {}): PaymentMethod {
  return {
    id: METHOD_UPI,
    kind: 'upi',
    label: 'GPay',
    is_default: false,
    version: 1,
    ...overrides,
  };
}

export function makeTransaction(overrides: Partial<Transaction> = {}): Transaction {
  return {
    id: TX_GROCERIES,
    account_id: ACCOUNT_CASH,
    account_name: 'Wallet',
    type: 'expense',
    direction: 'outflow',
    status: 'posted',
    amount: money('250.75'),
    occurred_at: '2026-11-04T06:30:00Z',
    local_date: '2026-11-04',
    timezone: 'Asia/Kolkata',
    category: { id: CATEGORY_GROCERIES, name: 'Groceries' },
    merchant: { id: '99999999-9999-4999-8999-999999999901', name: 'Big Bazaar' },
    description: 'Weekly groceries',
    tags: [{ id: TAG_HOME, name: 'home' }],
    refunded_total: money('0.00'),
    source: 'manual',
    reconciliation_state: 'unreconciled',
    is_correction: false,
    attachment_count: 0,
    owned: true,
    version: 3,
    created_at: '2026-11-04T06:30:00Z',
    updated_at: '2026-11-04T06:30:00Z',
    ...overrides,
  };
}

export function makeIncome(overrides: Partial<Transaction> = {}): Transaction {
  return makeTransaction({
    id: TX_SALARY,
    type: 'income',
    direction: 'inflow',
    amount: money('5000.00'),
    category: { id: CATEGORY_SALARY, name: 'Salary' },
    merchant: undefined,
    description: 'November salary',
    tags: [],
    version: 1,
    ...overrides,
  });
}

export function makeTransfer(overrides: Partial<Transfer> = {}): Transfer {
  return {
    id: TRANSFER_ID,
    from_account_id: ACCOUNT_CASH,
    to_account_id: ACCOUNT_CARD,
    from_transaction_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
    to_transaction_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02',
    fee_transaction_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa03',
    from_amount: money('1000.00'),
    to_amount: money('1000.00'),
    fee: money('10.00'),
    status: 'posted',
    local_date: '2026-11-04',
    created_at: '2026-11-04T07:00:00Z',
    ...overrides,
  };
}

export function makePreferences(overrides: Partial<Preferences> = {}): Preferences {
  return {
    locale: 'en-IN',
    timezone: 'Asia/Kolkata',
    base_currency: 'INR',
    date_format: 'locale',
    number_format: 'locale',
    week_start: 1,
    month_start_day: 1,
    theme: 'system',
    reduced_motion: false,
    high_contrast: false,
    text_scale_percent: 100,
    default_date_range: 'this_month',
    quiet_hours_enabled: false,
    quiet_hours_start: '22:00',
    quiet_hours_end: '07:00',
    email_digest: 'off',
    ai_enabled: false,
    analytics_opt_in: false,
    onboarding_completed: false,
    updated_at: '2026-11-01T08:00:00Z',
    ...overrides,
  };
}

/** The API's widget registry, in its default order (backend analytics widgetRegistry). */
export const WIDGET_KEYS: Widget['key'][] = [
  'balances',
  'cash_flow',
  'alerts',
  'budgets',
  'upcoming',
  'renewals',
  'income_vs_expense',
  'cash_flow_trend',
  'category_breakdown',
  'top_merchants',
  'recurring',
  'goals',
  'group_balances',
  'recent_transactions',
  'data_coverage',
];

export function defaultWidgets(): Widget[] {
  return WIDGET_KEYS.map((key, position) => ({ key, position, visible: true, settings: {} }));
}

/** GET /dashboard/planning for someone with nothing planned yet. */
export function emptyPlanning(overrides: Partial<DashboardPlanning> = {}): DashboardPlanning {
  return {
    today: '2026-11-12',
    upcoming_through: '2026-11-26',
    budgets: [],
    budget_count: 0,
    over_budget_count: 0,
    upcoming: [],
    upcoming_count: 0,
    overdue_count: 0,
    goals: [],
    goal_count: 0,
    group_balances: [],
    group_count: 0,
    alerts: [],
    alert_count: 0,
    renewals_through: '2026-12-12',
    renewals: [],
    renewal_count: 0,
    recurring: [],
    recurring_note_code: 'fixed_amounts_expectations',
    ...overrides,
  };
}

export function makeAccountsReport(): AccountsReport {
  return {
    totals: [
      {
        currency: 'INR',
        assets: money('5239.75'),
        liabilities: money('1000.00'),
        net_worth: money('4239.75'),
        account_count: 2,
      },
    ],
  };
}

export function makeSummary(overrides: Partial<DashboardSummary> = {}): DashboardSummary {
  return {
    window: { from: '2026-11-01', to: '2026-11-30', days: 30, timezone: 'Asia/Kolkata' },
    balances: [
      {
        currency: 'INR',
        assets: money('5239.75'),
        liabilities: money('1000.00'),
        net_worth: money('4239.75'),
        account_count: 2,
      },
    ],
    cash_flow: [
      {
        currency: 'INR',
        income: money('5000.00'),
        gross_expense: money('260.75'),
        refunds: money('0.00'),
        net_expense: money('260.75'),
        net_cash_flow: money('4739.25'),
        savings_rate_bp: 9479,
        transaction_count: 3,
      },
    ],
    previous_cash_flow: [
      {
        currency: 'INR',
        income: money('4500.00'),
        gross_expense: money('1200.00'),
        refunds: money('0.00'),
        net_expense: money('1200.00'),
        net_cash_flow: money('3300.00'),
        savings_rate_bp: 7333,
        transaction_count: 5,
      },
    ],
    trend: [
      {
        bucket: '2026-11-03',
        currency: 'INR',
        income: money('0.00'),
        net_expense: money('10.00'),
        net: money('-10.00'),
      },
      {
        bucket: '2026-11-04',
        currency: 'INR',
        income: money('5000.00'),
        net_expense: money('250.75'),
        net: money('4749.25'),
      },
    ],
    top_categories: [
      {
        category_id: CATEGORY_GROCERIES,
        name: 'Groceries',
        currency: 'INR',
        amount: money('250.75'),
        net_expense: money('250.75'),
        count: 1,
        share_bp: 9616,
        subcategory: false,
        drill_down_path: `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_GROCERIES}`,
      },
      {
        name: 'Uncategorized',
        system_key: 'uncategorized',
        currency: 'INR',
        amount: money('10.00'),
        net_expense: money('10.00'),
        count: 1,
        share_bp: 384,
        subcategory: false,
        drill_down_path: '/transactions?from=2026-11-01&to=2026-11-30&uncategorized=true',
      },
    ],
    top_merchants: [
      {
        merchant_id: '99999999-9999-4999-8999-999999999901',
        name: 'Big Bazaar',
        currency: 'INR',
        net_expense: money('250.75'),
        count: 1,
      },
    ],
    recent_transactions: [makeIncome(), makeTransaction()],
    coverage: {
      transaction_count: 3,
      earliest_transaction: '2026-11-03',
      latest_transaction: '2026-11-04',
      uncategorized_count: 1,
      pending_count: 0,
      provider_synced: false,
    },
    generated_at: '2026-11-04T10:00:00Z',
    notes: [],
    note_codes: [],
    trend_granularity: 'day',
    ...overrides,
  };
}
