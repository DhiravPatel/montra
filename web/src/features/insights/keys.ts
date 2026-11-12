import type { InsightListQuery } from './types';

/**
 * Insight query keys. Insights are derived from finance records, so they
 * start with `finance`: invalidateFinance() refreshes them after any write.
 */
export const insightsKeys = {
  all: ['finance', 'insights'] as const,
  /** Every list (prefix of `list`). */
  lists: () => ['finance', 'insights', 'list'] as const,
  list: (query: InsightListQuery) => ['finance', 'insights', 'list', query] as const,
  /** The mute rules (GET /insights/mutes). */
  mutes: () => ['finance', 'insights', 'mutes'] as const,
};
