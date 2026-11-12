/**
 * Query keys for reconciliation. They start with `finance`, so any finance
 * write (and invalidateFinance) refreshes suggestions, matches, statement
 * lines and history.
 */
export const reconciliationKeys = {
  all: ['finance', 'reconciliation'] as const,
  history: (accountId: string) => ['finance', 'reconciliation', accountId, 'history'] as const,
  candidates: (accountId: string, batchId: string) =>
    ['finance', 'reconciliation', accountId, 'candidates', { batchId }] as const,
  matches: (accountId: string) => ['finance', 'reconciliation', accountId, 'matches'] as const,
  statementLines: (accountId: string, status: string, batchId: string) =>
    ['finance', 'reconciliation', accountId, 'statement-lines', { status, batchId }] as const,
};
