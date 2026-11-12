import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { financeKeys } from '@/shared/finance/keys';
import type {
  Budget,
  BudgetAlert,
  BudgetAlertUpdate,
  BudgetInput,
  BudgetMemberInput,
  BudgetMemberUpdate,
  BudgetPatch,
  BudgetProgress,
  Transaction,
} from '@/shared/finance/types';

export type AlertStatus = BudgetAlert['status'];

/** Lifecycle actions (archiving is DELETE /budgets/{id}). */
export type BudgetStatusAction = 'pause' | 'resume' | 'archive' | 'restore';

/** One cursor page; the cursor stays in memory, never in the URL. */
export interface Page<T> {
  items: T[];
  nextCursor: string | null;
}

/** The API's default page size for budget transactions and alerts (max 200). */
export const BUDGET_PAGE_SIZE = 50;

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/** `?version=` for lifecycle actions: a concurrent change answers 409 VERSION_CONFLICT. */
function versionQuery(version?: number) {
  return version === undefined ? {} : { version };
}

/** Budget endpoints (spec §4.6, §20B.7). Budgets are not money movements: no idempotency key. */
export const budgetsApi = {
  list: (includeArchived: boolean, signal?: AbortSignal): Promise<Budget[]> =>
    apiData(
      api.GET('/budgets', {
        params: { query: includeArchived ? { include_archived: true } : {} },
        ...signalOption(signal),
      }),
    ),
  get: (id: string, signal?: AbortSignal): Promise<Budget> =>
    apiData(api.GET('/budgets/{id}', { params: { path: { id } }, ...signalOption(signal) })),
  create: (body: BudgetInput): Promise<Budget> => apiData(api.POST('/budgets', { body })),
  /** Only the fields sent change (lists replace); applies from the current period on. */
  update: (id: string, body: BudgetPatch): Promise<Budget> =>
    apiData(api.PATCH('/budgets/{id}', { params: { path: { id } }, body })),
  /** Pause (from active), resume (from paused), archive (DELETE; history kept) or restore (from archived). */
  setStatus: (id: string, action: BudgetStatusAction, version?: number): Promise<Budget> => {
    const options = { params: { path: { id }, query: versionQuery(version) } };
    switch (action) {
      case 'pause':
        return apiData(api.POST('/budgets/{id}/pause', options));
      case 'resume':
        return apiData(api.POST('/budgets/{id}/resume', options));
      case 'restore':
        return apiData(api.POST('/budgets/{id}/restore', options));
      case 'archive':
        return apiData(api.DELETE('/budgets/{id}', options));
    }
  },
  /** The period containing `date` (default today) and the one before it. */
  progress: (id: string, date: string, signal?: AbortSignal): Promise<BudgetProgress[]> =>
    apiData(
      api.GET('/budgets/{id}/progress', {
        params: { path: { id }, query: date ? { date } : {} },
        ...signalOption(signal),
      }),
    ),
  /** Exactly the transactions counted in the period containing `date` (owner only), newest first. */
  transactions: async (
    id: string,
    date: string,
    cursor: string,
    signal?: AbortSignal,
  ): Promise<Page<Transaction>> => {
    const envelope = await apiEnvelope(
      api.GET('/budgets/{id}/transactions', {
        params: {
          path: { id },
          query: {
            limit: BUDGET_PAGE_SIZE,
            ...(date ? { date } : {}),
            ...(cursor ? { cursor } : {}),
          },
        },
        ...signalOption(signal),
      }),
    );
    return { items: envelope.data, nextCursor: envelope.meta.next_cursor ?? null };
  },
  addMember: (id: string, body: BudgetMemberInput): Promise<Budget> =>
    apiData(api.POST('/budgets/{id}/members', { params: { path: { id } }, body })),
  updateMember: (id: string, userId: string, body: BudgetMemberUpdate): Promise<Budget> =>
    apiData(
      api.PATCH('/budgets/{id}/members/{userId}', { params: { path: { id, userId } }, body }),
    ),
  /** Removes a member, or leaves the budget when `userId` is your own. */
  removeMember: (id: string, userId: string) =>
    apiData(api.DELETE('/budgets/{id}/members/{userId}', { params: { path: { id, userId } } })),
  /** Alerts with one status, optionally one budget's only (the server filters by `budget_id`). */
  alerts: async (
    status: AlertStatus,
    budgetId: string,
    cursor: string,
    signal?: AbortSignal,
  ): Promise<Page<BudgetAlert>> => {
    const envelope = await apiEnvelope(
      api.GET('/budget-alerts', {
        params: {
          query: {
            status,
            ...(budgetId ? { budget_id: budgetId } : {}),
            limit: BUDGET_PAGE_SIZE,
            ...(cursor ? { cursor } : {}),
          },
        },
        ...signalOption(signal),
      }),
    );
    return { items: envelope.data, nextCursor: envelope.meta.next_cursor ?? null };
  },
  updateAlert: (id: string, body: BudgetAlertUpdate) =>
    apiData(api.PATCH('/budget-alerts/{id}', { params: { path: { id } }, body })),
};

export function useBudgets(includeArchived: boolean) {
  return useQuery({
    queryKey: financeKeys.budgets(includeArchived),
    queryFn: ({ signal }) => budgetsApi.list(includeArchived, signal),
    placeholderData: keepPreviousData,
  });
}

export function useBudget(id: string) {
  return useQuery({
    queryKey: financeKeys.budget(id),
    queryFn: ({ signal }) => budgetsApi.get(id, signal),
    enabled: Boolean(id),
  });
}

/** `date` '' means the current period. */
export function useBudgetProgress(id: string, date: string) {
  return useQuery({
    queryKey: financeKeys.budgetProgress(id, date),
    queryFn: ({ signal }) => budgetsApi.progress(id, date, signal),
    placeholderData: keepPreviousData,
  });
}

/** Cursor pages of the transactions counted in a period ("Load more"). */
export function useBudgetTransactions(id: string, date: string, enabled: boolean) {
  return useInfiniteQuery({
    queryKey: financeKeys.budgetTransactions(id, date),
    queryFn: ({ pageParam, signal }) => budgetsApi.transactions(id, date, pageParam, signal),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    enabled,
    placeholderData: keepPreviousData,
  });
}

/** Cursor pages of budget alerts with one status ("Load more"), for every budget or one. */
export function useBudgetAlerts(status: AlertStatus, budgetId = '') {
  return useInfiniteQuery({
    queryKey: financeKeys.budgetAlerts(status, budgetId),
    queryFn: ({ pageParam, signal }) => budgetsApi.alerts(status, budgetId, pageParam, signal),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
}
