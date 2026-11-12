import { parseRangeChoice, type RangeChoice } from '@/shared/finance/dateRange';
import { isDateRangePreset } from '@/shared/finance/labels';
import type { DateRangePreset } from '@/shared/finance/types';
import { isLocalDate } from '@/shared/formatting/dates';
import type { DashboardQuery } from './api';

/** Dashboard filters kept in the URL: periods, IDs and a currency code only. */
export interface DashboardFilters {
  range: Exclude<RangeChoice, 'all'>;
  from: string;
  to: string;
  accountId: string;
  categoryId: string;
  currency: string;
  includePending: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function readDashboardFilters(
  params: URLSearchParams,
  fallback: DateRangePreset,
): DashboardFilters {
  const from = params.get('from') ?? '';
  const to = params.get('to') ?? '';
  let range = parseRangeChoice(params.get('range') ?? '', false);
  // Links such as `?from=…&to=…` (without a range) mean a custom period.
  if (range === 'all' || !range) range = isLocalDate(from) && isLocalDate(to) ? 'custom' : fallback;
  const account = params.get('account_id') ?? '';
  const category = params.get('category_id') ?? '';
  const currency = params.get('currency') ?? '';
  return {
    range,
    from: range === 'custom' && isLocalDate(from) ? from : '',
    to: range === 'custom' && isLocalDate(to) ? to : '',
    accountId: UUID.test(account) ? account : '',
    categoryId: UUID.test(category) ? category : '',
    currency: /^[A-Z]{3}$/.test(currency) ? currency : '',
    includePending: params.get('pending') === '1',
  };
}

export function writeDashboardFilters(filters: DashboardFilters): URLSearchParams {
  const params = new URLSearchParams();
  params.set('range', filters.range);
  if (filters.range === 'custom') {
    if (filters.from) params.set('from', filters.from);
    if (filters.to) params.set('to', filters.to);
  }
  if (filters.accountId) params.set('account_id', filters.accountId);
  if (filters.categoryId) params.set('category_id', filters.categoryId);
  if (filters.currency) params.set('currency', filters.currency);
  if (filters.includePending) params.set('pending', '1');
  return params;
}

export function toDashboardQuery(filters: DashboardFilters): DashboardQuery {
  const query: DashboardQuery = {};
  if (filters.range === 'custom') {
    query.from = filters.from;
    query.to = filters.to;
  } else {
    query.range = filters.range;
  }
  if (filters.accountId) query.account_id = [filters.accountId];
  if (filters.categoryId) query.category_id = [filters.categoryId];
  if (filters.currency) query.currency = filters.currency;
  if (filters.includePending) query.include_pending = true;
  return query;
}

/** A custom range is usable once both dates are valid and in order. */
export function customRangeComplete(filters: DashboardFilters): boolean {
  if (filters.range !== 'custom') return true;
  return isLocalDate(filters.from) && isLocalDate(filters.to) && filters.from <= filters.to;
}

export function preferredRange(value: string | undefined): DateRangePreset {
  return value && isDateRangePreset(value) ? value : 'this_month';
}
