import {
  keepPreviousData,
  useInfiniteQuery,
  useMutation,
  useQuery,
  useQueryClient,
} from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { adminKeys } from './keys';
import type { Job, JobDetail, JobFilters, Usage } from './types';

/** Platform admins only (the API answers 403 to everyone else). */
export const adminApi = {
  usage: (days: number, signal?: AbortSignal): Promise<Usage> =>
    apiData(
      api.GET('/admin/usage', { params: { query: { days } }, ...(signal ? { signal } : {}) }),
    ),
  jobs: async (
    filters: JobFilters,
    cursor: string | undefined,
    signal?: AbortSignal,
  ): Promise<{ items: Job[]; nextCursor: string | null }> => {
    const envelope = await apiEnvelope(
      api.GET('/admin/jobs', {
        params: {
          query: {
            ...(filters.status ? { status: filters.status } : {}),
            ...(filters.type ? { type: filters.type } : {}),
            ...(filters.from ? { from: filters.from } : {}),
            ...(filters.to ? { to: filters.to } : {}),
            ...(cursor ? { cursor } : {}),
            limit: JOB_PAGE_SIZE,
          },
        },
        ...(signal ? { signal } : {}),
      }),
    );
    return { items: envelope.data, nextCursor: envelope.meta.next_cursor ?? null };
  },
  job: (id: string, signal?: AbortSignal): Promise<JobDetail> =>
    apiData(
      api.GET('/admin/jobs/{id}', { params: { path: { id } }, ...(signal ? { signal } : {}) }),
    ),
  /** Re-queues a failed or dead job (audited). The key makes a repeated click return the first result. */
  retry: (id: string, idempotencyKey: string): Promise<Job> =>
    apiData(
      api.POST('/admin/jobs/{id}/retry', {
        params: { path: { id }, header: { 'Idempotency-Key': idempotencyKey } },
      }),
    ),
};

export const JOB_PAGE_SIZE = 50;

/** Usage for the last `days` days; keeps showing the previous window while the next one loads. */
export function useUsage(days: number) {
  return useQuery({
    queryKey: adminKeys.usage(days),
    queryFn: ({ signal }) => adminApi.usage(days, signal),
    placeholderData: keepPreviousData,
  });
}

/** Jobs newest first, a page at a time (cursor paging). */
export function useJobs(filters: JobFilters, enabled: boolean) {
  return useInfiniteQuery({
    queryKey: adminKeys.jobs(filters),
    queryFn: ({ pageParam, signal }) => adminApi.jobs(filters, pageParam, signal),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    enabled,
  });
}

export function useJob(id: string, enabled: boolean) {
  return useQuery({
    queryKey: adminKeys.job(id),
    queryFn: ({ signal }) => adminApi.job(id, signal),
    enabled,
  });
}

export function useRetryJob(id: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (idempotencyKey: string) => adminApi.retry(id, idempotencyKey),
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['admin', 'jobs'] }),
  });
}
