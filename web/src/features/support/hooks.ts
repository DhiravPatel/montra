import { useQuery } from '@tanstack/react-query';
import { supportApi } from './api';
import { supportKeys } from './keys';
import type { QueueFilters } from './types';

export function useMyRequests() {
  return useQuery({
    queryKey: supportKeys.mine(),
    queryFn: ({ signal }) => supportApi.list(signal),
  });
}

export function useSupportRequest(id: string) {
  return useQuery({
    queryKey: supportKeys.request(id),
    queryFn: ({ signal }) => supportApi.get(id, signal),
    enabled: id !== '',
  });
}

/** A request's message thread (only fetched while it is shown). */
export function useSupportMessages(id: string, enabled = true) {
  return useQuery({
    queryKey: supportKeys.messages(id),
    queryFn: ({ signal }) => supportApi.messages(id, signal),
    enabled: enabled && id !== '',
  });
}

export function useSupportQueue(filters: QueueFilters) {
  return useQuery({
    queryKey: supportKeys.queue(filters),
    queryFn: ({ signal }) => supportApi.queue(filters, signal),
  });
}
