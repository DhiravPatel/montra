import { parseRangeChoice } from '@/shared/finance/dateRange';
import { isDateRangePreset } from '@/shared/finance/labels';
import type { DateRangePreset } from '@/shared/finance/types';
import { addDaysToLocalDate, isLocalDate, parseLocalDate } from '@/shared/formatting/dates';
import type { AnalyticsQuery, CategoryKind, CompareQuery, Granularity } from './types';

/**
 * Analytics workspace state kept in the URL: the open section, the period
 * and filters. Only dates, IDs, enum values and currency codes are stored,
 * never amounts or names (spec §20B.23).
 */

export const ANALYTICS_VIEWS = [
  'cash-flow',
  'categories',
  'merchants',
  'payment-methods',
  'compare',
  'accounts',
  'plans',
] as const;

export type AnalyticsView = (typeof ANALYTICS_VIEWS)[number];

/** Sections whose figures depend on the selected period and filters. */
export const PERIOD_VIEWS: ReadonlySet<AnalyticsView> = new Set([
  'cash-flow',
  'categories',
  'merchants',
  'payment-methods',
  'compare',
]);

export const GRANULARITIES = [
  'day',
  'week',
  'month',
  'year',
] as const satisfies readonly Granularity[];

export const COMPARE_MODES = ['previous', 'last_year', 'custom'] as const;
export type CompareMode = (typeof COMPARE_MODES)[number];

/** What the category breakdown measures: net spending (default) or income. */
export const CATEGORY_KINDS = ['expense', 'income'] as const satisfies readonly CategoryKind[];

export interface AnalyticsFilters {
  view: AnalyticsView;
  range: DateRangePreset | 'custom';
  /** Custom period only. */
  from: string;
  to: string;
  accountId: string;
  categoryId: string;
  includePending: boolean;
  /** Chart buckets; '' lets the API choose for the period. */
  group: Granularity | '';
  /** Currency for converted cash-flow totals (with disclosed rates); '' for none. */
  display: string;
  /** Category breakdown without rolling subcategories up to their parents. */
  subcategories: boolean;
  /** Category breakdown of spending or of income. */
  kind: CategoryKind;
  /** Account totals for accounts included in the overview only. */
  overviewOnly: boolean;
  compare: CompareMode;
  /** Custom comparison period only. */
  compareFrom: string;
  compareTo: string;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CURRENCY = /^[A-Z]{3}$/;

function oneOf<T extends string>(value: string | null, allowed: readonly T[]): T | null {
  return value !== null && (allowed as readonly string[]).includes(value) ? (value as T) : null;
}

/** The user's preferred default period for analytics (`this_month` otherwise). */
export function preferredRange(value: string | undefined): DateRangePreset {
  return value && isDateRangePreset(value) ? value : 'this_month';
}

export function readAnalyticsFilters(
  params: URLSearchParams,
  fallback: DateRangePreset,
): AnalyticsFilters {
  const from = params.get('from') ?? '';
  const to = params.get('to') ?? '';
  let range = parseRangeChoice(params.get('range') ?? '', false);
  // A link with dates but no range (`?from=…&to=…`) means a custom period.
  if (range === null || range === 'all') {
    range = isLocalDate(from) && isLocalDate(to) ? 'custom' : fallback;
  }
  const account = params.get('account_id') ?? '';
  const category = params.get('category_id') ?? '';
  const display = params.get('display') ?? '';
  const compare = oneOf(params.get('cmp'), COMPARE_MODES) ?? 'previous';
  const compareFrom = params.get('compare_from') ?? '';
  const compareTo = params.get('compare_to') ?? '';
  return {
    view: oneOf(params.get('view'), ANALYTICS_VIEWS) ?? 'cash-flow',
    range,
    from: range === 'custom' && isLocalDate(from) ? from : '',
    to: range === 'custom' && isLocalDate(to) ? to : '',
    accountId: UUID.test(account) ? account : '',
    categoryId: UUID.test(category) ? category : '',
    includePending: params.get('pending') === '1',
    group: oneOf(params.get('group'), GRANULARITIES) ?? '',
    display: CURRENCY.test(display) ? display : '',
    subcategories: params.get('sub') === '1',
    kind: oneOf(params.get('kind'), CATEGORY_KINDS) ?? 'expense',
    overviewOnly: params.get('overview') === '1',
    compare,
    compareFrom: compare === 'custom' && isLocalDate(compareFrom) ? compareFrom : '',
    compareTo: compare === 'custom' && isLocalDate(compareTo) ? compareTo : '',
  };
}

export function writeAnalyticsFilters(filters: AnalyticsFilters): URLSearchParams {
  const params = new URLSearchParams();
  if (filters.view !== 'cash-flow') params.set('view', filters.view);
  params.set('range', filters.range);
  if (filters.range === 'custom') {
    if (filters.from) params.set('from', filters.from);
    if (filters.to) params.set('to', filters.to);
  }
  if (filters.accountId) params.set('account_id', filters.accountId);
  if (filters.categoryId) params.set('category_id', filters.categoryId);
  if (filters.includePending) params.set('pending', '1');
  if (filters.group) params.set('group', filters.group);
  if (filters.display) params.set('display', filters.display);
  if (filters.subcategories) params.set('sub', '1');
  if (filters.kind !== 'expense') params.set('kind', filters.kind);
  if (filters.overviewOnly) params.set('overview', '1');
  if (filters.compare !== 'previous') params.set('cmp', filters.compare);
  if (filters.compare === 'custom') {
    if (filters.compareFrom) params.set('compare_from', filters.compareFrom);
    if (filters.compareTo) params.set('compare_to', filters.compareTo);
  }
  return params;
}

/** A custom period is usable once both dates are valid and in order. */
export function periodReady(filters: Pick<AnalyticsFilters, 'range' | 'from' | 'to'>): boolean {
  if (filters.range !== 'custom') return true;
  return isLocalDate(filters.from) && isLocalDate(filters.to) && filters.from <= filters.to;
}

export function periodOutOfOrder(filters: Pick<AnalyticsFilters, 'range' | 'from' | 'to'>) {
  return (
    filters.range === 'custom' && Boolean(filters.from && filters.to) && filters.from > filters.to
  );
}

export type AnalyticsBaseQuery = Omit<AnalyticsQuery, 'granularity' | 'display_currency'>;

/** The period and filters shared by every period-based endpoint. */
export function baseQuery(filters: AnalyticsFilters): AnalyticsBaseQuery {
  const query: AnalyticsBaseQuery = {};
  if (filters.range === 'custom') {
    query.from = filters.from;
    query.to = filters.to;
  } else {
    query.range = filters.range;
  }
  if (filters.accountId) query.account_id = [filters.accountId];
  if (filters.categoryId) query.category_id = [filters.categoryId];
  if (filters.includePending) query.include_pending = true;
  return query;
}

/** Longest window each named period can have (bucket counts stay readable). */
const RANGE_MAX_DAYS: Readonly<Record<DateRangePreset, number>> = {
  today: 1,
  yesterday: 1,
  this_week: 7,
  last_week: 7,
  this_month: 31,
  last_month: 31,
  this_year: 366,
  last_year: 366,
  last_7_days: 7,
  last_30_days: 30,
  last_90_days: 90,
};

const DAY_MS = 86_400_000;

/** Calendar days in a custom period (inclusive), or null while it is incomplete. */
export function customDays(from: string, to: string): number | null {
  const start = parseLocalDate(from);
  const end = parseLocalDate(to);
  if (!start || !end || end < start) return null;
  return Math.round((end.getTime() - start.getTime()) / DAY_MS) + 1;
}

function maxDays(filters: Pick<AnalyticsFilters, 'range' | 'from' | 'to'>): number | null {
  return filters.range === 'custom'
    ? customDays(filters.from, filters.to)
    : RANGE_MAX_DAYS[filters.range];
}

/**
 * Bucket sizes that keep a chart to about a hundred columns for the period:
 * days up to ~3 months, weeks up to 2 years, months up to 10 years.
 */
export function allowedGranularities(
  filters: Pick<AnalyticsFilters, 'range' | 'from' | 'to'>,
): Granularity[] {
  const days = maxDays(filters);
  if (days === null) return [...GRANULARITIES];
  return GRANULARITIES.filter((granularity) => {
    if (granularity === 'day') return days <= 92;
    if (granularity === 'week') return days <= 731;
    if (granularity === 'month') return days <= 3700;
    return true;
  });
}

/** The chosen bucket size when it suits the period; otherwise the API chooses. */
export function effectiveGranularity(
  filters: Pick<AnalyticsFilters, 'range' | 'from' | 'to' | 'group'>,
): Granularity | undefined {
  if (!filters.group) return undefined;
  return allowedGranularities(filters).includes(filters.group) ? filters.group : undefined;
}

/** GET /analytics/cash-flow (also used to learn the resolved window of a named period). */
export function cashFlowQuery(filters: AnalyticsFilters): AnalyticsQuery {
  const granularity = effectiveGranularity(filters);
  return {
    ...baseQuery(filters),
    ...(granularity ? { granularity } : {}),
    ...(filters.display ? { display_currency: filters.display } : {}),
  };
}

/** GET /analytics/expenses and /analytics/income (series only, no conversion). */
export function seriesQuery(filters: AnalyticsFilters): AnalyticsQuery {
  const granularity = effectiveGranularity(filters);
  return { ...baseQuery(filters), ...(granularity ? { granularity } : {}) };
}

export interface DateWindow {
  from: string;
  to: string;
}

/** The same-length period just before a window (as the API's previous-period figures). */
export function previousWindow(window: DateWindow): DateWindow | null {
  const days = customDays(window.from, window.to);
  if (days === null) return null;
  const to = addDaysToLocalDate(window.from, -1);
  return { from: addDaysToLocalDate(to, -(days - 1)), to };
}

/** A calendar date moved by whole years (29 February becomes 28 February). */
export function shiftYears(value: string, years: number): string {
  const date = parseLocalDate(value);
  if (!date) return value;
  const year = date.getUTCFullYear() + years;
  const month = date.getUTCMonth();
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const day = Math.min(date.getUTCDate(), lastDay);
  const shifted = new Date(Date.UTC(year, month, day));
  return shifted.toISOString().slice(0, 10);
}

/** The period to compare the selected one with, or null while it cannot be known yet. */
export function comparisonWindow(
  current: DateWindow,
  filters: Pick<AnalyticsFilters, 'compare' | 'compareFrom' | 'compareTo'>,
): DateWindow | null {
  if (filters.compare === 'previous') return previousWindow(current);
  if (filters.compare === 'last_year') {
    return { from: shiftYears(current.from, -1), to: shiftYears(current.to, -1) };
  }
  const { compareFrom: from, compareTo: to } = filters;
  return isLocalDate(from) && isLocalDate(to) && from <= to ? { from, to } : null;
}

/** GET /analytics/compare for two explicit windows with the shared filters. */
export function compareQuery(
  filters: AnalyticsFilters,
  current: DateWindow,
  other: DateWindow,
): CompareQuery {
  const query: CompareQuery = {
    from: current.from,
    to: current.to,
    compare_from: other.from,
    compare_to: other.to,
  };
  if (filters.accountId) query.account_id = [filters.accountId];
  if (filters.categoryId) query.category_id = [filters.categoryId];
  if (filters.includePending) query.include_pending = true;
  return query;
}
