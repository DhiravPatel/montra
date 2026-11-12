/**
 * Query keys for integrations. Connections are not finance records, so
 * they have their own prefix; writes that change transactions (disconnect
 * with data deletion) also call invalidateFinance().
 */
export const integrationsKeys = {
  all: ['integrations'] as const,
  overview: () => ['integrations', 'overview'] as const,
  status: (connectionId: string) => ['integrations', 'status', connectionId] as const,
};
