import { paths, withQuery } from '@/shared/config/paths';
import type { AnalyticsFilters, DateWindow } from './filters';

/** Transaction types the API counts as spending (refunds reduce it). */
export const SPENDING_TYPES = 'expense,group_expense,refund,reimbursement';

/** Types counted in cash flow: income and spending (transfers and corrections are not). */
export const CASH_FLOW_TYPES = `income,${SPENDING_TYPES}`;

/** Types the API counts as "without a category" in its coverage figures. */
export const UNCATEGORIZED_TYPES = 'expense,income';

/**
 * The transactions behind a figure: the same window and filters, IDs only
 * in the link (never names or amounts). Without "include pending" the
 * figures count posted transactions only, so the list does too.
 */
export function transactionsLink(
  window: DateWindow,
  filters: Pick<AnalyticsFilters, 'accountId' | 'categoryId' | 'includePending'>,
  extra: Readonly<Record<string, string | undefined>> = {},
): string {
  const uncategorized = extra.uncategorized === 'true';
  return withQuery(paths.transactions, {
    from: window.from,
    to: window.to,
    account_id: filters.accountId || undefined,
    // The transactions list refuses `uncategorized` together with a category.
    category_id: uncategorized
      ? undefined
      : (extra.category_id ?? (filters.categoryId || undefined)),
    status: extra.status ?? (filters.includePending ? undefined : 'posted'),
    ...Object.fromEntries(
      Object.entries(extra).filter(([key]) => key !== 'category_id' && key !== 'status'),
    ),
  });
}
