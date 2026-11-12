import type { SearchRequest } from './types';

/**
 * Search query keys. Results start with `finance`, so any financial write
 * (invalidateFinance) refreshes them. Recent searches are not finance data.
 * Keys live in memory only and are dropped on sign-out.
 */
export const searchKeys = {
  results: (request: SearchRequest) => ['finance', 'search', request] as const,
  recent: () => ['search', 'recent'] as const,
};
