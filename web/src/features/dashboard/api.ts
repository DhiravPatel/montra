import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { commaSeparatedArrays } from '@/shared/api/query';
import { apiData, apiEnvelope } from '@/shared/api/request';
import type { operations } from '@/shared/api/schema';
import { financeKeys } from '@/shared/finance/keys';
import type {
  DashboardPlanning,
  DashboardSummary,
  Widget,
  WidgetsPatch,
} from '@/shared/finance/types';

/** The planning cards' data and when the server produced it (`meta.timestamp`). */
export interface PlanningResult {
  planning: DashboardPlanning;
  generatedAt: string;
}

export type DashboardQuery = NonNullable<operations['dashboard-summary']['parameters']['query']>;

/** Dashboard endpoints (spec §4.2, §20B.3). Every figure is computed by the API. */
export const dashboardApi = {
  summary: (query: DashboardQuery, signal?: AbortSignal): Promise<DashboardSummary> =>
    apiData(
      api.GET('/dashboard/summary', {
        params: { query },
        querySerializer: commaSeparatedArrays,
        ...(signal ? { signal } : {}),
      }),
    ),
  widgets: (signal?: AbortSignal): Promise<Widget[]> =>
    apiData(api.GET('/dashboard/widgets', signal ? { signal } : {})),
  updateWidgets: (body: WidgetsPatch): Promise<Widget[]> =>
    apiData(api.PATCH('/dashboard/widgets', { body })),
  /**
   * Budgets (fullest first), upcoming items (overdue first), goals and group
   * balances with their counts: one request for all four planning cards.
   */
  planning: async (signal?: AbortSignal): Promise<PlanningResult> => {
    const envelope = await apiEnvelope(api.GET('/dashboard/planning', signal ? { signal } : {}));
    return { planning: envelope.data, generatedAt: envelope.meta.timestamp };
  },
};

export function useDashboardSummary(query: DashboardQuery, enabled: boolean) {
  return useQuery({
    queryKey: financeKeys.dashboard(query),
    queryFn: ({ signal }) => dashboardApi.summary(query, signal),
    enabled,
    placeholderData: keepPreviousData,
  });
}

export function useWidgetLayout() {
  return useQuery({
    queryKey: financeKeys.widgets(),
    queryFn: ({ signal }) => dashboardApi.widgets(signal),
    staleTime: 5 * 60_000,
  });
}

/** Shared by every planning card; fetched only while at least one of them is shown. */
export function useDashboardPlanning(enabled: boolean) {
  return useQuery({
    queryKey: financeKeys.dashboardPlanning(),
    queryFn: ({ signal }) => dashboardApi.planning(signal),
    enabled,
  });
}
