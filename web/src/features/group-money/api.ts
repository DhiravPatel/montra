import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { compactQuery } from '@/shared/api/query';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { groupMoneyKeys } from './keys';
import type {
  Conversion,
  CsvDownload,
  ExpenseFilters,
  ExpensePage,
  ExpenseRecordInput,
  GroupBalances,
  GroupComment,
  GroupDetail,
  GroupDispute,
  GroupExpenseDetail,
  GroupExpenseInput,
  GroupRecurring,
  GroupRecurringInput,
  GroupRecurringUpdate,
  GroupReport,
  GroupSuggestions,
  RecurringStatusAction,
  ResolveDisputeInput,
  Settlement,
  SettlementAction,
  SettlementActionBody,
  SettlementInput,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

function idempotent(key: string) {
  return { 'Idempotency-Key': key };
}

/** Expenses per page (the API's default is 50, at most 200). */
export const EXPENSE_PAGE_SIZE = 50;

/**
 * The only file name accepted from the server: a lowercase slug ending in
 * `-expenses-YYYY-MM-DD.csv` (the date the export was made).
 */
const SERVER_FILE_NAME = /^[a-z0-9][a-z0-9-]{0,59}-expenses(?:-\d{4}-\d{2}-\d{2})?\.csv$/;

/**
 * The file name from a `Content-Disposition` header (`filename="…"` or the
 * RFC 5987 form), accepted only when it is the API's sanitized
 * `<group-slug>-expenses-YYYY-MM-DD.csv`; null otherwise (the caller uses a
 * neutral one).
 */
export function exportFileName(disposition: string | null): string | null {
  if (!disposition) return null;
  const extended = /filename\*\s*=\s*(?:UTF-8|utf-8)?''([^;]+)/.exec(disposition);
  const plain = /filename\s*=\s*"?([^";]+)"?/.exec(disposition);
  let raw = extended?.[1] ?? plain?.[1] ?? '';
  try {
    raw = decodeURIComponent(raw.trim());
  } catch {
    return null;
  }
  return SERVER_FILE_NAME.test(raw) ? raw : null;
}

export const groupMoneyApi = {
  group: (groupId: string, signal?: AbortSignal): Promise<GroupDetail> =>
    apiData(
      api.GET('/groups/{id}', { params: { path: { id: groupId } }, ...signalOption(signal) }),
    ),

  // Expenses.
  /**
   * One page of expenses, newest first (expense date, then creation), with
   * the server-side filters; `cursor` is the previous page's `next_cursor`.
   */
  expenses: async (
    groupId: string,
    filters: ExpenseFilters,
    cursor: string | null,
    signal?: AbortSignal,
  ): Promise<ExpensePage> => {
    const envelope = await apiEnvelope(
      api.GET('/groups/{id}/expenses', {
        params: {
          path: { id: groupId },
          query: compactQuery({
            status: filters.status,
            from: filters.from,
            to: filters.to,
            payer_user_id: filters.payerUserId,
            category_key: filters.categoryKey,
            // Ignored by the API when a status is chosen (deleted ones are then listed by status).
            include_deleted: filters.includeDeleted && !filters.status ? true : undefined,
            cursor,
            limit: EXPENSE_PAGE_SIZE,
          }),
        },
        ...signalOption(signal),
      }),
    );
    return {
      items: envelope.data,
      nextCursor: envelope.meta.has_more === false ? null : (envelope.meta.next_cursor ?? null),
    };
  },
  expense: (
    groupId: string,
    expenseId: string,
    signal?: AbortSignal,
  ): Promise<GroupExpenseDetail> =>
    apiData(
      api.GET('/groups/{id}/expenses/{expenseId}', {
        params: { path: { id: groupId, expenseId } },
        ...signalOption(signal),
      }),
    ),
  createExpense: (
    groupId: string,
    body: GroupExpenseInput,
    key: string,
  ): Promise<GroupExpenseDetail> =>
    apiData(
      api.POST('/groups/{id}/expenses', {
        params: { path: { id: groupId }, header: idempotent(key) },
        body,
      }),
    ),
  /** Replaces the whole expense (send every field) with the version that was edited. */
  updateExpense: (
    groupId: string,
    expenseId: string,
    body: GroupExpenseInput,
  ): Promise<GroupExpenseDetail> =>
    apiData(
      api.PATCH('/groups/{id}/expenses/{expenseId}', {
        params: { path: { id: groupId, expenseId } },
        body,
      }),
    ),
  deleteExpense: (groupId: string, expenseId: string) =>
    apiData(
      api.DELETE('/groups/{id}/expenses/{expenseId}', {
        params: { path: { id: groupId, expenseId } },
      }),
    ),
  comment: (groupId: string, expenseId: string, text: string): Promise<GroupComment> =>
    apiData(
      api.POST('/groups/{id}/expenses/{expenseId}/comments', {
        params: { path: { id: groupId, expenseId } },
        body: { body: text },
      }),
    ),
  dispute: (groupId: string, expenseId: string, reason: string): Promise<GroupDispute> =>
    apiData(
      api.POST('/groups/{id}/expenses/{expenseId}/disputes', {
        params: { path: { id: groupId, expenseId } },
        body: { reason },
      }),
    ),
  resolveDispute: (groupId: string, disputeId: string, body: ResolveDisputeInput) =>
    apiData(
      api.POST('/groups/{id}/disputes/{disputeId}/resolve', {
        params: { path: { id: groupId, disputeId } },
        body,
      }),
    ),
  myRecord: (
    groupId: string,
    expenseId: string,
    body: ExpenseRecordInput,
  ): Promise<GroupExpenseDetail> =>
    apiData(
      api.POST('/groups/{id}/expenses/{expenseId}/my-record', {
        params: { path: { id: groupId, expenseId } },
        body,
      }),
    ),

  // Balances and settlements.
  balances: (groupId: string, signal?: AbortSignal): Promise<GroupBalances> =>
    apiData(
      api.GET('/groups/{id}/balances', {
        params: { path: { id: groupId } },
        ...signalOption(signal),
      }),
    ),
  suggestions: (groupId: string, mine: boolean, signal?: AbortSignal): Promise<GroupSuggestions> =>
    apiData(
      api.GET('/groups/{id}/settlement-suggestions', {
        params: { path: { id: groupId }, query: mine ? { mine: true } : {} },
        ...signalOption(signal),
      }),
    ),
  settlements: (
    groupId: string,
    includeVoided: boolean,
    signal?: AbortSignal,
  ): Promise<Settlement[]> =>
    apiData(
      api.GET('/groups/{id}/settlements', {
        params: { path: { id: groupId }, query: includeVoided ? { include_voided: true } : {} },
        ...signalOption(signal),
      }),
    ),
  settlement: (groupId: string, settlementId: string, signal?: AbortSignal): Promise<Settlement> =>
    apiData(
      api.GET('/groups/{id}/settlements/{settlementId}', {
        params: { path: { id: groupId, settlementId } },
        ...signalOption(signal),
      }),
    ),
  createSettlement: (groupId: string, body: SettlementInput, key: string): Promise<Settlement> =>
    apiData(
      api.POST('/groups/{id}/settlements', {
        params: { path: { id: groupId }, header: idempotent(key) },
        body,
      }),
    ),
  /** Voids the original (kept for history) and records the corrected settlement. */
  correctSettlement: (
    groupId: string,
    settlementId: string,
    body: SettlementInput,
    key: string,
  ): Promise<Settlement> =>
    apiData(
      api.POST('/groups/{id}/settlements/{settlementId}/correct', {
        params: { path: { id: groupId, settlementId }, header: idempotent(key) },
        body,
      }),
    ),
  settlementAction: (
    groupId: string,
    settlementId: string,
    action: SettlementAction,
    body: SettlementActionBody,
  ): Promise<Settlement> => {
    const params = { params: { path: { id: groupId, settlementId } }, body };
    switch (action) {
      case 'confirm':
        return apiData(api.POST('/groups/{id}/settlements/{settlementId}/confirm', params));
      case 'dispute':
        return apiData(api.POST('/groups/{id}/settlements/{settlementId}/dispute', params));
      case 'mark-paid':
        return apiData(api.POST('/groups/{id}/settlements/{settlementId}/mark-paid', params));
      case 'record':
        return apiData(api.POST('/groups/{id}/settlements/{settlementId}/record', params));
      case 'unlink':
        return apiData(api.POST('/groups/{id}/settlements/{settlementId}/unlink', params));
      case 'void':
        return apiData(api.POST('/groups/{id}/settlements/{settlementId}/void', params));
    }
  },

  // Recurring shared expenses.
  recurring: (groupId: string, signal?: AbortSignal): Promise<GroupRecurring[]> =>
    apiData(
      api.GET('/groups/{id}/recurring-expenses', {
        params: { path: { id: groupId } },
        ...signalOption(signal),
      }),
    ),
  /** Idempotent: the same key replays the created rule instead of adding it twice. */
  createRecurring: (
    groupId: string,
    body: GroupRecurringInput,
    key: string,
  ): Promise<GroupRecurring> =>
    apiData(
      api.POST('/groups/{id}/recurring-expenses', {
        params: { path: { id: groupId }, header: idempotent(key) },
        body,
      }),
    ),
  /** Versioned (409 VERSION_CONFLICT when stale); the contract declares no Idempotency-Key here. */
  updateRecurring: (
    groupId: string,
    ruleId: string,
    body: GroupRecurringUpdate,
  ): Promise<GroupRecurring> =>
    apiData(
      api.PATCH('/groups/{id}/recurring-expenses/{ruleId}', {
        params: { path: { id: groupId, ruleId } },
        body,
      }),
    ),
  recurringStatus: (
    groupId: string,
    ruleId: string,
    action: RecurringStatusAction,
  ): Promise<GroupRecurring> => {
    const params = { params: { path: { id: groupId, ruleId } } };
    switch (action) {
      case 'pause':
        return apiData(api.POST('/groups/{id}/recurring-expenses/{ruleId}/pause', params));
      case 'resume':
        return apiData(api.POST('/groups/{id}/recurring-expenses/{ruleId}/resume', params));
      case 'stop':
        return apiData(api.POST('/groups/{id}/recurring-expenses/{ruleId}/stop', params));
    }
  },
  addOccurrence: (
    groupId: string,
    ruleId: string,
    occurrenceId: string,
    key: string,
  ): Promise<GroupExpenseDetail> =>
    apiData(
      api.POST('/groups/{id}/recurring-expenses/{ruleId}/occurrences/{occurrenceId}/add', {
        params: { path: { id: groupId, ruleId, occurrenceId }, header: idempotent(key) },
      }),
    ),
  skipOccurrence: (
    groupId: string,
    ruleId: string,
    occurrenceId: string,
  ): Promise<GroupRecurring> =>
    apiData(
      api.POST('/groups/{id}/recurring-expenses/{ruleId}/occurrences/{occurrenceId}/skip', {
        params: { path: { id: groupId, ruleId, occurrenceId } },
      }),
    ),

  // Reports and export.
  report: (groupId: string, from: string, to: string, signal?: AbortSignal): Promise<GroupReport> =>
    apiData(
      api.GET('/groups/{id}/reports', {
        params: {
          path: { id: groupId },
          query: { ...(from ? { from } : {}), ...(to ? { to } : {}) },
        },
        ...signalOption(signal),
      }),
    ),
  /** Expenses and settlements as CSV text, with the server's (sanitized) file name. */
  exportCsv: async (groupId: string): Promise<CsvDownload> => {
    const headers: { disposition: string | null } = { disposition: null };
    const csv = await apiEnvelope(
      api
        .GET('/groups/{id}/export', { params: { path: { id: groupId } }, parseAs: 'text' })
        .then((result) => {
          headers.disposition = result.response.headers.get('Content-Disposition');
          return result;
        }),
    );
    return { csv, fileName: exportFileName(headers.disposition) };
  },

  // Supporting reads.
  /** The rate Montra would use for a foreign-currency amount on a date (404 when it has none). */
  convert: (
    query: { amount: string; from: string; to: string; date: string },
    signal?: AbortSignal,
  ): Promise<Conversion> =>
    apiData(
      api.GET('/fx/convert', {
        params: {
          query: {
            amount: query.amount,
            from: query.from,
            to: query.to,
            policy: 'historical',
            date: query.date,
          },
        },
        ...signalOption(signal),
      }),
    ),
  /** A short-lived download link for an attachment (authorization is checked on every call). */
  fileAccess: (fileId: string) =>
    apiData(api.GET('/files/{fileId}/access', { params: { path: { fileId } } })),
};

/** The group with its members (former members included, so history stays readable). */
export function useMoneyGroup(groupId: string) {
  return useQuery({
    queryKey: groupMoneyKeys.detail(groupId),
    queryFn: ({ signal }) => groupMoneyApi.group(groupId, signal),
    enabled: groupId !== '',
  });
}

/** Expense pages for one set of filters; `fetchNextPage` follows the server's cursor. */
export function useGroupExpenses(groupId: string, filters: ExpenseFilters) {
  return useInfiniteQuery({
    queryKey: groupMoneyKeys.expenses(groupId, filters),
    queryFn: ({ pageParam, signal }) => groupMoneyApi.expenses(groupId, filters, pageParam, signal),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.nextCursor,
  });
}

export function useGroupExpense(groupId: string, expenseId: string) {
  return useQuery({
    queryKey: groupMoneyKeys.expense(groupId, expenseId),
    queryFn: ({ signal }) => groupMoneyApi.expense(groupId, expenseId, signal),
  });
}

export function useGroupBalances(groupId: string) {
  return useQuery({
    queryKey: groupMoneyKeys.balances(groupId),
    queryFn: ({ signal }) => groupMoneyApi.balances(groupId, signal),
  });
}

export function useSettlementSuggestions(groupId: string, mine: boolean) {
  return useQuery({
    queryKey: groupMoneyKeys.suggestions(groupId, mine),
    queryFn: ({ signal }) => groupMoneyApi.suggestions(groupId, mine, signal),
  });
}

export function useSettlements(groupId: string, includeVoided: boolean) {
  return useQuery({
    queryKey: groupMoneyKeys.settlements(groupId, includeVoided),
    queryFn: ({ signal }) => groupMoneyApi.settlements(groupId, includeVoided, signal),
  });
}

export function useSettlement(groupId: string, settlementId: string) {
  return useQuery({
    queryKey: groupMoneyKeys.settlement(groupId, settlementId),
    queryFn: ({ signal }) => groupMoneyApi.settlement(groupId, settlementId, signal),
  });
}

export function useGroupRecurring(groupId: string) {
  return useQuery({
    queryKey: groupMoneyKeys.recurring(groupId),
    queryFn: ({ signal }) => groupMoneyApi.recurring(groupId, signal),
  });
}

export function useGroupReport(groupId: string, from: string, to: string) {
  return useQuery({
    queryKey: groupMoneyKeys.report(groupId, from, to),
    queryFn: ({ signal }) => groupMoneyApi.report(groupId, from, to, signal),
  });
}
