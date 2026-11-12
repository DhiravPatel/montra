import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { moderationApi } from './api';
import { moderationKeys } from './keys';
import type { PlatformActionFilters, QueueStatus } from './types';

export function useMyModeration() {
  return useQuery({
    queryKey: moderationKeys.mine(),
    queryFn: ({ signal }) => moderationApi.myActions(signal),
  });
}

export function useMyAppeals() {
  return useQuery({
    queryKey: moderationKeys.myAppeals(),
    queryFn: ({ signal }) => moderationApi.myAppeals(signal),
  });
}

export function useMyReports() {
  return useQuery({
    queryKey: moderationKeys.myReports(),
    queryFn: ({ signal }) => moderationApi.myReports(signal),
  });
}

export function useStaffReports(status: QueueStatus) {
  return useQuery({
    queryKey: moderationKeys.staffReports(status),
    queryFn: ({ signal }) => moderationApi.staffReports(status, signal),
  });
}

export function useStaffAppeals() {
  return useQuery({
    queryKey: moderationKeys.staffAppeals(),
    queryFn: ({ signal }) => moderationApi.staffAppeals(signal),
  });
}

/** Platform actions matching `filters`, newest first, a cursor page at a time. */
export function useStaffActions(filters: PlatformActionFilters) {
  return useInfiniteQuery({
    queryKey: moderationKeys.staffActions(filters),
    queryFn: ({ pageParam, signal }) => moderationApi.staffActions(filters, pageParam, signal),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    placeholderData: keepPreviousData,
  });
}
