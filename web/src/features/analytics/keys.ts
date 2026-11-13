/**
 * Analytics query keys. They start with `finance`, so any financial write
 * (invalidateFinance) recomputes every figure on screen.
 */
export const analyticsKeys = {
  all: ['finance', 'analytics'] as const,
  cashFlow: (query: object) => ['finance', 'analytics', 'cash-flow', query] as const,
  expenses: (query: object) => ['finance', 'analytics', 'expenses', query] as const,
  income: (query: object) => ['finance', 'analytics', 'income', query] as const,
  categories: (query: object) => ['finance', 'analytics', 'categories', query] as const,
  merchants: (query: object) => ['finance', 'analytics', 'merchants', query] as const,
  paymentMethods: (query: object) => ['finance', 'analytics', 'payment-methods', query] as const,
  accounts: (overviewOnly: boolean) =>
    ['finance', 'analytics', 'accounts', { overviewOnly }] as const,
  compare: (query: object) => ['finance', 'analytics', 'compare', query] as const,
  budgets: () => ['finance', 'analytics', 'budgets'] as const,
  goals: () => ['finance', 'analytics', 'goals'] as const,
  subscriptions: () => ['finance', 'analytics', 'subscriptions'] as const,
  recurring: () => ['finance', 'analytics', 'recurring'] as const,
};
