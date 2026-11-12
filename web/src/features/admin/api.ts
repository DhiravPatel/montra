import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { adminKeys } from './keys';
import type { Usage } from './types';

/** Platform admins only (the API answers 403 to everyone else). */
export const adminApi = {
  usage: (days: number, signal?: AbortSignal): Promise<Usage> =>
    apiData(
      api.GET('/admin/usage', { params: { query: { days } }, ...(signal ? { signal } : {}) }),
    ),
};

/** Usage for the last `days` days; keeps showing the previous window while the next one loads. */
export function useUsage(days: number) {
  return useQuery({
    queryKey: adminKeys.usage(days),
    queryFn: ({ signal }) => adminApi.usage(days, signal),
    placeholderData: keepPreviousData,
  });
}
