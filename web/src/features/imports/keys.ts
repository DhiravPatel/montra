/**
 * Query keys for statement imports. They start with `finance`, so any
 * finance write (and invalidateFinance) refreshes them too.
 */
export const importKeys = {
  all: ['finance', 'imports'] as const,
  list: (accountId: string) => ['finance', 'imports', 'list', { accountId }] as const,
  /** One import; its rows live under this prefix so invalidating it refreshes them too. */
  batch: (id: string) => ['finance', 'imports', 'batch', id] as const,
  /**
   * Rows of one import. `stage` (version and status) changes whenever the
   * server re-derives rows (mapping, processing), so a new stage loads fresh rows.
   */
  rows: (id: string, filter: string, stage: string) =>
    ['finance', 'imports', 'batch', id, 'rows', { filter, stage }] as const,
  /** The first rows of the file, as read, for the column mapping. */
  sample: (id: string, stage: string) =>
    ['finance', 'imports', 'batch', id, 'sample', { stage }] as const,
};
