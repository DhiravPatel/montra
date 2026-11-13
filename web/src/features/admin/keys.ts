/** Query keys for the operator dashboard (aggregate counts, not finance data). */
export const adminKeys = {
  all: ['admin'] as const,
  usage: (days: number) => ['admin', 'usage', days] as const,
  jobs: (filters: object) => ['admin', 'jobs', 'list', filters] as const,
  job: (id: string) => ['admin', 'jobs', 'detail', id] as const,
};
