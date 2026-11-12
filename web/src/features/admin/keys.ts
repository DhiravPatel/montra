/** Query keys for the operator dashboard (aggregate counts, not finance data). */
export const adminKeys = {
  all: ['admin'] as const,
  usage: (days: number) => ['admin', 'usage', days] as const,
};
