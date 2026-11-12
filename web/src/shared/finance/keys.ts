import type { QueryClient } from '@tanstack/react-query';

/**
 * Query keys for everything derived from the user's finance records. All
 * of them start with `finance`, so any financial write invalidates balances,
 * lists, analytics and the dashboard together (cached data is per signed-in
 * user and dropped on sign-out by the auth layer).
 */
export const financeKeys = {
  all: ['finance'] as const,
  accounts: (includeArchived: boolean) => ['finance', 'accounts', { includeArchived }] as const,
  accountTotals: () => ['finance', 'accounts', 'totals'] as const,
  account: (id: string) => ['finance', 'account', id] as const,
  accountBalance: (id: string, from: string, to: string) =>
    ['finance', 'account', id, 'balance', { from, to }] as const,
  accountTransactions: (id: string) => ['finance', 'account', id, 'transactions'] as const,
  transactions: (query: object) => ['finance', 'transactions', query] as const,
  transaction: (id: string) => ['finance', 'transaction', id] as const,
  transactionAudit: (id: string) => ['finance', 'transaction', id, 'audit'] as const,
  transactionAttachments: (id: string) => ['finance', 'transaction', id, 'attachments'] as const,
  transfer: (id: string) => ['finance', 'transfer', id] as const,
  categories: (includeArchived: boolean) => ['finance', 'categories', { includeArchived }] as const,
  tags: () => ['finance', 'tags'] as const,
  merchants: (search: string) => ['finance', 'merchants', search] as const,
  paymentMethods: (includeArchived: boolean) =>
    ['finance', 'payment-methods', { includeArchived }] as const,
  dashboard: (query: object) => ['finance', 'dashboard', query] as const,
  widgets: () => ['finance', 'dashboard', 'widgets'] as const,

  // Round 2: organizing.
  categoryRules: () => ['finance', 'category-rules'] as const,
  category: (id: string) => ['finance', 'category', id] as const,
  merchant: (id: string) => ['finance', 'merchants', '', 'detail', id] as const,
  /** The merchants page: cursor pages for a search text and status (kept in memory only). */
  merchantList: (query: { q: string; status: string }) =>
    ['finance', 'merchants', 'list', query] as const,
  merchantMergePreview: (targetId: string, sourceIds: readonly string[]) =>
    ['finance', 'merchants', 'merge-preview', { targetId, sourceIds }] as const,
  categoryMergePreview: (targetId: string, sourceIds: readonly string[]) =>
    ['finance', 'categories', 'merge-preview', { targetId, sourceIds }] as const,
  // Round 2: budgets.
  budgets: (includeArchived: boolean) => ['finance', 'budgets', { includeArchived }] as const,
  budget: (id: string) => ['finance', 'budget', id] as const,
  budgetProgress: (id: string, date: string) =>
    ['finance', 'budget', id, 'progress', { date }] as const,
  budgetTransactions: (id: string, date: string) =>
    ['finance', 'budget', id, 'transactions', { date }] as const,
  budgetAlerts: (status: string, budgetId = '') =>
    ['finance', 'budget-alerts', { status, budgetId }] as const,
  // Round 2: recurring rules, bills and the calendar.
  recurringRules: (query: object) => ['finance', 'recurring-rules', query] as const,
  recurringRule: (id: string) => ['finance', 'recurring-rule', id] as const,
  bills: (status: string) => ['finance', 'bills', { status }] as const,
  bill: (id: string) => ['finance', 'bill', id] as const,
  billCandidates: (id: string, occurrenceId: string) =>
    ['finance', 'bill', id, 'candidates', { occurrenceId }] as const,
  calendar: (from: string, to: string) => ['finance', 'calendar', { from, to }] as const,
  // Round 2: subscriptions.
  subscriptions: (status: string) => ['finance', 'subscriptions', { status }] as const,
  subscriptionSummary: () => ['finance', 'subscriptions', 'summary'] as const,
  subscription: (id: string) => ['finance', 'subscription', id] as const,
  subscriptionPaymentCandidates: (id: string) =>
    ['finance', 'subscription', id, 'payment-candidates'] as const,
  detections: (status: string) => ['finance', 'subscription-detections', { status }] as const,
  // Round 2: goals.
  goals: (status: string) => ['finance', 'goals', { status }] as const,
  goal: (id: string) => ['finance', 'goal', id] as const,
  goalContributions: (id: string) => ['finance', 'goal', id, 'contributions'] as const,
  goalForecast: (id: string) => ['finance', 'goal', id, 'forecast'] as const,
};

/**
 * People and groups to share budgets and goals with. Not finance data, so
 * finance writes do not refetch them.
 */
export const sharingKeys = {
  connections: () => ['sharing', 'connections'] as const,
  groups: () => ['sharing', 'groups'] as const,
  group: (id: string) => ['sharing', 'group', id] as const,
};

export const preferencesQueryKey = ['me', 'preferences'] as const;

/** Marks every finance query stale and refetches the ones on screen. */
export function invalidateFinance(queryClient: QueryClient): Promise<void> {
  return queryClient.invalidateQueries({ queryKey: financeKeys.all });
}
