import { useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { financeKeys } from '@/shared/finance/keys';
import type {
  Bill,
  BillDetail,
  BillInput,
  BillMarkPaidInput,
  BillPatch,
  BillPaymentCandidate,
  CalendarItem,
  Occurrence,
  OccurrenceAction,
  RecurringDeleteResult,
  RecurringReport,
  RecurringRule,
  RecurringRuleDetail,
  RecurringRuleInput,
  RecurringRulePatch,
} from '@/shared/finance/types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

function idempotent(key: string) {
  return { 'Idempotency-Key': key };
}

/** `?version=` for lifecycle actions: the version on screen (409 VERSION_CONFLICT when stale). */
function versionQuery(version?: number) {
  return version === undefined ? {} : { version };
}

/** GET /bills?status: '' = active and paused (default), or one status, or all. */
export type BillStatusFilter = '' | 'active' | 'paused' | 'archived' | 'all';
export type RuleKindFilter = '' | 'expense' | 'income' | 'transfer';
export type RuleStatusFilter = '' | 'active' | 'paused' | 'ended';

export type RuleStatusAction = 'pause' | 'resume' | 'stop' | 'skip-next';

/** Bill lifecycle: pause (from active), resume (from paused), archive, restore (from archived). */
export type BillStatusAction = 'pause' | 'resume' | 'archive' | 'restore';

/** Planning endpoints: calendar, recurring rules and occurrences, bills (spec §4.7, §20B.8). */
export const planningApi = {
  calendar: (from: string, to: string, signal?: AbortSignal): Promise<CalendarItem[]> =>
    apiData(api.GET('/calendar', { params: { query: { from, to } }, ...signalOption(signal) })),
  recurringReport: (signal?: AbortSignal): Promise<RecurringReport> =>
    apiData(api.GET('/analytics/recurring', signalOption(signal))),

  listRules: (
    query: { kind: RuleKindFilter; status: RuleStatusFilter },
    signal?: AbortSignal,
  ): Promise<RecurringRule[]> =>
    apiData(
      api.GET('/recurring-rules', {
        params: {
          query: {
            ...(query.kind ? { kind: query.kind } : {}),
            ...(query.status ? { status: query.status } : {}),
          },
        },
        ...signalOption(signal),
      }),
    ),
  getRule: (id: string, signal?: AbortSignal): Promise<RecurringRuleDetail> =>
    apiData(
      api.GET('/recurring-rules/{id}', { params: { path: { id } }, ...signalOption(signal) }),
    ),
  /** Idempotent per key: a retry of the same draft replays the first result. */
  createRule: (body: RecurringRuleInput, key: string): Promise<RecurringRule> =>
    apiData(api.POST('/recurring-rules', { params: { header: idempotent(key) }, body })),
  /** Only the fields sent change (this and future occurrences); `clear` removes optional ones. */
  updateRule: (id: string, body: RecurringRulePatch): Promise<RecurringRule> =>
    apiData(api.PATCH('/recurring-rules/{id}', { params: { path: { id } }, body })),
  /** Removes a never-used rule, or ends one with history (`outcome`). */
  deleteRule: (id: string): Promise<RecurringDeleteResult> =>
    apiData(api.DELETE('/recurring-rules/{id}', { params: { path: { id } } })),
  ruleAction: (id: string, action: RuleStatusAction, version?: number): Promise<RecurringRule> => {
    const options = { params: { path: { id }, query: versionQuery(version) } };
    switch (action) {
      case 'pause':
        return apiData(api.POST('/recurring-rules/{id}/pause', options));
      case 'resume':
        return apiData(api.POST('/recurring-rules/{id}/resume', options));
      case 'stop':
        return apiData(api.POST('/recurring-rules/{id}/stop', options));
      case 'skip-next':
        return apiData(api.POST('/recurring-rules/{id}/skip-next', options));
    }
  },
  /** One occurrence: skip, reopen, postpone, set amount, confirm or link (idempotent per key). */
  occurrenceAction: (id: string, body: OccurrenceAction, key: string): Promise<Occurrence> =>
    apiData(
      api.POST('/recurring-occurrences/{id}/actions', {
        params: { path: { id }, header: idempotent(key) },
        body,
      }),
    ),

  listBills: (status: BillStatusFilter, signal?: AbortSignal): Promise<Bill[]> =>
    apiData(
      api.GET('/bills', {
        params: { query: status ? { status } : {} },
        ...signalOption(signal),
      }),
    ),
  getBill: (id: string, signal?: AbortSignal): Promise<BillDetail> =>
    apiData(api.GET('/bills/{id}', { params: { path: { id } }, ...signalOption(signal) })),
  /** Idempotent per key: a retry of the same draft replays the first result. */
  createBill: (body: BillInput, key: string): Promise<BillDetail> =>
    apiData(api.POST('/bills', { params: { header: idempotent(key) }, body })),
  /** Only the fields sent change (this and future occurrences); `clear` removes optional ones. */
  updateBill: (id: string, body: BillPatch): Promise<BillDetail> =>
    apiData(api.PATCH('/bills/{id}', { params: { path: { id } }, body })),
  billAction: (id: string, action: BillStatusAction, version?: number): Promise<BillDetail> => {
    const options = { params: { path: { id }, query: versionQuery(version) } };
    switch (action) {
      case 'pause':
        return apiData(api.POST('/bills/{id}/pause', options));
      case 'resume':
        return apiData(api.POST('/bills/{id}/resume', options));
      case 'archive':
        return apiData(api.POST('/bills/{id}/archive', options));
      case 'restore':
        return apiData(api.POST('/bills/{id}/restore', options));
    }
  },
  markPaid: (id: string, body: BillMarkPaidInput, key: string): Promise<BillDetail> =>
    apiData(
      api.POST('/bills/{id}/mark-paid', {
        params: { path: { id }, header: idempotent(key) },
        body,
      }),
    ),
  skipBill: (id: string, occurrenceId?: string): Promise<BillDetail> =>
    apiData(
      api.POST('/bills/{id}/skip', {
        params: { path: { id } },
        body: occurrenceId ? { occurrence_id: occurrenceId } : {},
      }),
    ),
  paymentCandidates: (
    id: string,
    occurrenceId: string,
    signal?: AbortSignal,
  ): Promise<BillPaymentCandidate[]> =>
    apiData(
      api.GET('/bills/{id}/payment-candidates', {
        params: { path: { id }, query: occurrenceId ? { occurrence_id: occurrenceId } : {} },
        ...signalOption(signal),
      }),
    ),
};

export function useCalendar(from: string, to: string) {
  return useQuery({
    queryKey: financeKeys.calendar(from, to),
    queryFn: ({ signal }) => planningApi.calendar(from, to, signal),
  });
}

export function useRecurringReport() {
  return useQuery({
    queryKey: [...financeKeys.recurringRules({}), 'report'] as const,
    queryFn: ({ signal }) => planningApi.recurringReport(signal),
  });
}

export function useRecurringRules(kind: RuleKindFilter, status: RuleStatusFilter) {
  return useQuery({
    queryKey: financeKeys.recurringRules({ kind, status }),
    queryFn: ({ signal }) => planningApi.listRules({ kind, status }, signal),
  });
}

export function useRecurringRule(id: string) {
  return useQuery({
    queryKey: financeKeys.recurringRule(id),
    queryFn: ({ signal }) => planningApi.getRule(id, signal),
    enabled: Boolean(id),
  });
}

export function useBills(status: BillStatusFilter) {
  return useQuery({
    queryKey: financeKeys.bills(status),
    queryFn: ({ signal }) => planningApi.listBills(status, signal),
  });
}

export function useBill(id: string) {
  return useQuery({
    queryKey: financeKeys.bill(id),
    queryFn: ({ signal }) => planningApi.getBill(id, signal),
    enabled: Boolean(id),
  });
}

export function usePaymentCandidates(billId: string, occurrenceId: string, enabled: boolean) {
  return useQuery({
    queryKey: financeKeys.billCandidates(billId, occurrenceId),
    queryFn: ({ signal }) => planningApi.paymentCandidates(billId, occurrenceId, signal),
    enabled,
    staleTime: 0,
  });
}
