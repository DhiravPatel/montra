/**
 * Exchange-rate query keys. They start with `finance` so a rate change also
 * refreshes converted analytics totals (invalidateFinance).
 */
export const fxKeys = {
  all: ['finance', 'fx'] as const,
  rates: (query: object) => ['finance', 'fx', 'rates', query] as const,
};
