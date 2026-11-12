import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { commaSeparatedArrays } from '@/shared/api/query';
import { apiData } from '@/shared/api/request';
import type { operations } from '@/shared/api/schema';
import { financeKeys } from '@/shared/finance/keys';
import type { DashboardSummary, Widget, WidgetsPatch } from '@/shared/finance/types';

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
