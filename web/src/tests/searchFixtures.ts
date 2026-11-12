import { http, HttpResponse } from 'msw';
import type {
  NamedHit,
  PostHit,
  RecentSearch,
  SearchResults,
  TransactionHit,
  UserHit,
} from '@/features/search/types';
import { ACCOUNT_CASH, ACCOUNT_USD, money } from './financeFixtures';
import { API, envelope } from './fixtures';

/** Search fixtures shaped like the contract (GET /search, GET /search/recent). */

export const HIT_TX_COFFEE = 'a0a0a0a0-0000-4000-8000-000000000001';
export const HIT_TX_MUSEUM = 'a0a0a0a0-0000-4000-8000-000000000002';
export const HIT_ACCOUNT = 'a0a0a0a0-0000-4000-8000-000000000003';
export const HIT_MERCHANT = 'a0a0a0a0-0000-4000-8000-000000000004';
export const HIT_GOAL = 'a0a0a0a0-0000-4000-8000-000000000005';
export const HIT_GROUP = 'a0a0a0a0-0000-4000-8000-000000000006';
export const HIT_POST = 'a0a0a0a0-0000-4000-8000-000000000007';
export const HIT_COMMUNITY = 'a0a0a0a0-0000-4000-8000-000000000008';
export const HIT_USER = 'a0a0a0a0-0000-4000-8000-000000000009';
export const HIT_CATEGORY = 'a0a0a0a0-0000-4000-8000-000000000010';
export const HIT_BUDGET = 'a0a0a0a0-0000-4000-8000-000000000011';
export const HIT_BILL = 'a0a0a0a0-0000-4000-8000-000000000012';
export const HIT_SUBSCRIPTION = 'a0a0a0a0-0000-4000-8000-000000000013';
export const HIT_RECURRING = 'a0a0a0a0-0000-4000-8000-000000000014';

export function emptyResults(
  query: string,
  scope = 'all',
  sort: SearchResults['sort'] = 'relevance',
): SearchResults {
  return {
    query,
    scope,
    sort,
    transactions: [],
    merchants: [],
    accounts: [],
    categories: [],
    budgets: [],
    bills: [],
    subscriptions: [],
    recurring_rules: [],
    groups: [],
    posts: [],
    users: [],
    goals: [],
  };
}

export function makeTransactionHit(overrides: Partial<TransactionHit> = {}): TransactionHit {
  return {
    id: HIT_TX_COFFEE,
    description: 'Holiday coffee',
    merchant: 'Blue Tokai',
    amount: money('250.00'),
    type: 'expense',
    local_date: '2026-11-03',
    account_id: ACCOUNT_CASH,
    shared: false,
    ...overrides,
  };
}

export function makeNamedHit(overrides: Partial<NamedHit> = {}): NamedHit {
  return { id: HIT_ACCOUNT, name: 'Holiday Savings', kind: 'savings', ...overrides };
}

export function makePostHit(overrides: Partial<PostHit> = {}): PostHit {
  return {
    id: HIT_POST,
    community_id: HIT_COMMUNITY,
    community_name: 'Budget travellers',
    title: 'Holiday packing on a budget',
    created_at: '2026-11-01T06:30:00Z',
    ...overrides,
  };
}

export function makeUserHit(overrides: Partial<UserHit> = {}): UserHit {
  return { user_id: HIT_USER, display_name: 'Holiday Fan', username: 'holidayfan', ...overrides };
}

/** One hit in every section (two transactions, in two currencies). */
export function makeResults(
  query = 'holiday',
  overrides: Partial<SearchResults> = {},
): SearchResults {
  return {
    ...emptyResults(query),
    transactions: [
      makeTransactionHit(),
      makeTransactionHit({
        id: HIT_TX_MUSEUM,
        description: 'Holiday museum tickets',
        merchant: undefined,
        amount: money('42.50', 'USD'),
        account_id: ACCOUNT_USD,
        shared: true,
      }),
    ],
    accounts: [makeNamedHit()],
    merchants: [{ id: HIT_MERCHANT, name: 'Holiday Inn Express' }],
    categories: [makeNamedHit({ id: HIT_CATEGORY, name: 'Holidays', kind: 'expense' })],
    budgets: [makeNamedHit({ id: HIT_BUDGET, name: 'Holiday spending', kind: 'category' })],
    bills: [makeNamedHit({ id: HIT_BILL, name: 'Holiday home insurance', kind: 'active' })],
    subscriptions: [
      makeNamedHit({ id: HIT_SUBSCRIPTION, name: 'Holiday planner app', kind: 'trial' }),
    ],
    recurring_rules: [
      makeNamedHit({ id: HIT_RECURRING, name: 'Holiday fund transfer', kind: 'transfer' }),
    ],
    goals: [makeNamedHit({ id: HIT_GOAL, name: 'Holiday 2027', kind: 'active' })],
    groups: [makeNamedHit({ id: HIT_GROUP, name: 'Holiday trip', kind: 'trip' })],
    posts: [makePostHit()],
    users: [makeUserHit()],
    ...overrides,
  };
}

export function makeRecent(overrides: Partial<RecentSearch> = {}): RecentSearch {
  return { query: 'blue tokai', scope: 'all', created_at: '2026-11-04T09:00:00Z', ...overrides };
}

/**
 * Requests every signed-in shell makes besides the default handlers (the
 * notification bell's unread count), so page tests only declare their own.
 */
export function shellHandlers() {
  return [
    http.get(`${API}/notifications/unread-count`, () => HttpResponse.json(envelope({ unread: 0 }))),
  ];
}
