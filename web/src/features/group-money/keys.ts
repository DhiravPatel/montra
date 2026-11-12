import type { QueryClient } from '@tanstack/react-query';
import { invalidateFinance, sharingKeys } from '@/shared/finance/keys';
import type { ExpenseFilters } from './types';

/**
 * Query keys for a group's money: expenses, balances, settlements,
 * recurring expenses and reports. They start with `finance`, so
 * invalidateFinance() refreshes them together with the personal records
 * that group expenses and settlements create (linked transactions).
 */
const base = ['finance', 'group-money'] as const;

export const groupMoneyKeys = {
  all: base,
  group: (groupId: string) => [...base, groupId] as const,
  detail: (groupId: string) => [...base, groupId, 'detail'] as const,
  /** Every expense page (prefix of `expenses`). */
  expenseLists: (groupId: string) => [...base, groupId, 'expenses'] as const,
  /** The cursor pages for one set of server-side filters (IDs and codes only). */
  expenses: (groupId: string, filters: ExpenseFilters) =>
    [...base, groupId, 'expenses', filters] as const,
  expense: (groupId: string, expenseId: string) =>
    [...base, groupId, 'expense', expenseId] as const,
  balances: (groupId: string) => [...base, groupId, 'balances'] as const,
  suggestions: (groupId: string, mine: boolean) =>
    [...base, groupId, 'suggestions', { mine }] as const,
  settlements: (groupId: string, includeVoided: boolean) =>
    [...base, groupId, 'settlements', { includeVoided }] as const,
  settlement: (groupId: string, settlementId: string) =>
    [...base, groupId, 'settlement', settlementId] as const,
  recurring: (groupId: string) => [...base, groupId, 'recurring'] as const,
  report: (groupId: string, from: string, to: string) =>
    [...base, groupId, 'report', { from, to }] as const,
  /** A rate lookup for a foreign-currency expense (no amounts of other people). */
  conversion: (query: { amount: string; from: string; to: string; date: string }) =>
    [...base, 'fx', query] as const,
};

/** The shared people and group pickers (budgets, goals and the groups pages read them). */
const sharingPrefix = [sharingKeys.groups()[0]] as const;

/**
 * Refreshes everything a group money write can change: the group's own
 * views, every personal finance view (linked records, balances, calendar)
 * and the shared group pickers.
 */
export async function refreshAfterGroupWrite(queryClient: QueryClient): Promise<void> {
  await Promise.all([
    invalidateFinance(queryClient),
    queryClient.invalidateQueries({ queryKey: sharingPrefix }),
  ]);
}

/**
 * After a state conflict (409 with a code such as `expense_deleted` or
 * `settlement_voided`): the record changed somewhere else, so every view of
 * the group is refetched and the screen shows the current state.
 */
export function reloadGroupAfterConflict(queryClient: QueryClient, groupId: string): Promise<void> {
  return queryClient.invalidateQueries({ queryKey: groupMoneyKeys.group(groupId) });
}
