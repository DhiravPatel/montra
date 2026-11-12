import type {
  Budget,
  BudgetAlert,
  BudgetAllocation,
  BudgetExplainItem,
  BudgetMember,
  BudgetProgress,
} from '@/shared/finance/types';
import { CATEGORY_GROCERIES, money } from './financeFixtures';
import { meta } from './fixtures';
import { FRIEND_ID } from './sharingFixtures';

/** Budget fixtures shaped like the contract (tests only). */

export const BUDGET_ID = 'b0b0b0b0-0000-4000-8000-000000000001';
export const SHARED_BUDGET_ID = 'b0b0b0b0-0000-4000-8000-000000000002';
export const ALLOCATION_ID = 'b1b1b1b1-0000-4000-8000-000000000001';
export const ALERT_ID = 'a1a1a1a1-0000-4000-8000-000000000001';
export const OTHER_ALERT_ID = 'a1a1a1a1-0000-4000-8000-000000000002';
/** makeUser()'s ID: the signed-in user. */
export const ME = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
export const OTHER_OWNER = 'c0c0c0c0-0000-4000-8000-000000000009';

/** The API's explanation lines for a period: codes with values plus the English text. */
export function explainPeriod(
  spent: string,
  limit: string,
  from: string,
  to: string,
  extra: BudgetExplainItem[] = [],
): Pick<BudgetProgress, 'explanation' | 'explanation_items'> {
  const items: BudgetExplainItem[] = [
    { code: 'spent_of_limit', params: { spent, limit, currency: 'INR', from, to } },
    { code: 'refunds_restore' },
    ...extra,
  ];
  return {
    // The API's English prose: shown only for codes this client does not know.
    explanation: items.map((item) => `English line for ${item.code}`),
    explanation_items: items,
  };
}

export function makeProgress(overrides: Partial<BudgetProgress> = {}): BudgetProgress {
  return {
    period_start: '2026-11-01',
    period_end: '2026-11-30',
    base_limit: money('5000.00'),
    rollover_in: money('0.00'),
    limit: money('5000.00'),
    spent: money('4200.00'),
    remaining: money('800.00'),
    overspent: money('0.00'),
    percent_bp: 8400,
    elapsed_days: 5,
    total_days: 30,
    expected_by_now: money('833.33'),
    projected: money('25200.00'),
    projected_over: money('20200.00'),
    daily_allowance: money('32.00'),
    pace: 'ahead_of_pace',
    transaction_count: 3,
    other_currency_count: 0,
    ...explainPeriod('4200.00', '5000.00', '2026-11-01', '2026-11-30', [
      { code: 'projection_estimate', params: { projected: '25200.00', currency: 'INR' } },
    ]),
    ...overrides,
  };
}

/** October: a finished period that went over the limit. */
export function previousProgress(overrides: Partial<BudgetProgress> = {}): BudgetProgress {
  return makeProgress({
    period_start: '2026-10-01',
    period_end: '2026-10-31',
    spent: money('7000.00'),
    remaining: money('0.00'),
    overspent: money('2000.00'),
    percent_bp: 14000,
    elapsed_days: 31,
    total_days: 31,
    expected_by_now: money('5000.00'),
    projected: money('7000.00'),
    projected_over: money('2000.00'),
    daily_allowance: money('0.00'),
    pace: 'over_budget',
    transaction_count: 9,
    ...explainPeriod('7000.00', '5000.00', '2026-10-01', '2026-10-31'),
    ...overrides,
  });
}

export function makeAllocation(overrides: Partial<BudgetAllocation> = {}): BudgetAllocation {
  return {
    id: ALLOCATION_ID,
    category_id: CATEGORY_GROCERIES,
    limit: money('3000.00'),
    spent: money('4200.00'),
    remaining: money('0.00'),
    overspent: money('1200.00'),
    percent_bp: 14000,
    ...overrides,
  };
}

export function makeBudgetMember(overrides: Partial<BudgetMember> = {}): BudgetMember {
  return {
    user_id: FRIEND_ID,
    display_name: 'Ravi Kumar',
    role: 'viewer',
    ...overrides,
  };
}

export function makeBudget(overrides: Partial<Budget> = {}): Budget {
  return {
    id: BUDGET_ID,
    owner_user_id: ME,
    owner_display_name: 'Asha Rao',
    name: 'Food',
    budget_type: 'category',
    period: 'monthly',
    timezone: 'Asia/Kolkata',
    currency: 'INR',
    limit: money('5000.00'),
    rollover_policy: 'none',
    include_pending: false,
    refunds_restore: true,
    count_group_shares: true,
    included_account_ids: [],
    excluded_category_ids: [],
    merchant_ids: [],
    alert_thresholds: [50, 75, 90, 100],
    alert_forecast: true,
    visibility: 'private',
    status: 'active',
    starts_on: '2026-11-01',
    access: 'owner',
    allocations: [makeAllocation()],
    members: [],
    progress: makeProgress(),
    version: 1,
    created_at: '2026-11-01T06:00:00Z',
    updated_at: '2026-11-01T06:00:00Z',
    ...overrides,
  };
}

/** A budget someone else shared with the signed-in user (read only). */
export function makeSharedBudget(overrides: Partial<Budget> = {}): Budget {
  return makeBudget({
    id: SHARED_BUDGET_ID,
    owner_user_id: OTHER_OWNER,
    owner_display_name: 'Kiran Shah',
    name: 'Household',
    budget_type: 'total',
    access: 'viewer',
    allocations: [],
    members: [{ user_id: ME, display_name: 'Asha Rao', role: 'viewer' }],
    progress: makeProgress({
      spent: money('2000.00'),
      remaining: money('3000.00'),
      percent_bp: 4000,
      pace: 'on_track',
      as_of: '2026-11-05T06:40:00Z',
      ...explainPeriod('2000.00', '5000.00', '2026-11-01', '2026-11-30', [
        { code: 'owner_totals_only' },
      ]),
    }),
    ...overrides,
  });
}

export function makeBudgetAlert(overrides: Partial<BudgetAlert> = {}): BudgetAlert {
  return {
    id: ALERT_ID,
    budget_id: BUDGET_ID,
    budget_name: 'Food',
    period_start: '2026-11-01',
    kind: 'threshold',
    threshold: 75,
    status: 'active',
    triggered_at: '2026-11-04T06:39:00Z',
    ...overrides,
  };
}

/** One cursor page `{data, meta}`; `next` becomes meta.next_cursor (more pages follow). */
export function pageEnvelope<T>(data: T[], next?: string) {
  return {
    data,
    meta: { ...meta(), ...(next ? { next_cursor: next, has_more: true } : { has_more: false }) },
  };
}
