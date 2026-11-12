import type { QueueFilters } from './types';

/** Query keys for support requests (not finance data, so no `finance` prefix). */
export const supportKeys = {
  all: ['support'] as const,
  mine: () => ['support', 'requests'] as const,
  request: (id: string) => ['support', 'requests', id] as const,
  messages: (id: string) => ['support', 'requests', id, 'messages'] as const,
  queueAll: () => ['support', 'queue'] as const,
  queue: (filters: QueueFilters) =>
    ['support', 'queue', filters.status ?? 'all', filters.kind ?? 'all'] as const,
};
