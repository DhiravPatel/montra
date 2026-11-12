/**
 * Report query keys. They start with `finance` (reports are computed from
 * finance records), so invalidateFinance refreshes them too.
 */
export const reportsKeys = {
  all: ['finance', 'reports'] as const,
  list: () => ['finance', 'reports', 'list'] as const,
  schedules: () => ['finance', 'reports', 'schedules'] as const,
  limits: () => ['finance', 'reports', 'limits'] as const,
};
