import { formatLocalDate, parseLocalDate } from '@/shared/formatting/dates';
import type { Translate } from '@/shared/i18n/types';
import type { CashFlowTotals, Granularity, SeriesPoint } from './types';

/** What a trend chart shows: money in (income) or money out (spending, net of refunds). */
export type Measure = 'income' | 'spending';

export function measureMoney(point: SeriesPoint, measure: Measure) {
  return measure === 'income' ? point.income : point.net_expense;
}

/**
 * The API's series grouped by currency, oldest bucket first. Grouping only:
 * amounts in different currencies are never combined.
 */
export function pointsByCurrency(points: readonly SeriesPoint[]): Map<string, SeriesPoint[]> {
  const groups = new Map<string, SeriesPoint[]>();
  for (const point of points) {
    const list = groups.get(point.currency) ?? [];
    list.push(point);
    groups.set(point.currency, list);
  }
  for (const list of groups.values()) list.sort((a, b) => a.bucket.localeCompare(b.bucket));
  return groups;
}

/** Totals for currencies with counted activity, in the API's order. */
export function activeTotals(totals: readonly CashFlowTotals[]): CashFlowTotals[] {
  return totals.filter((total) => total.transaction_count > 0);
}

/**
 * The bucket with the largest value for a measure, chosen by comparing the
 * API's exact integer minor units (a display choice, no arithmetic).
 */
export function peakPoint(points: readonly SeriesPoint[], measure: Measure): SeriesPoint | null {
  let best: SeriesPoint | null = null;
  for (const point of points) {
    const value = measureMoney(point, measure).amount_minor;
    if (value <= 0) continue;
    if (!best || value > measureMoney(best, measure).amount_minor) best = point;
  }
  return best;
}

/** A bucket's start as words: a day, a week's first day, a month or a year. */
export function bucketDate(bucket: string, granularity: Granularity, locale: string): string {
  const date = parseLocalDate(bucket);
  if (!date) return bucket;
  if (granularity === 'month') {
    return new Intl.DateTimeFormat(locale, {
      month: 'long',
      year: 'numeric',
      timeZone: 'UTC',
    }).format(date);
  }
  if (granularity === 'year') {
    return new Intl.DateTimeFormat(locale, { year: 'numeric', timeZone: 'UTC' }).format(date);
  }
  return formatLocalDate(bucket, locale, 'medium');
}

/** The label of one bucket in tables and sentences ("Week of 26 Oct 2026"). */
export function bucketLabel(
  bucket: string,
  granularity: Granularity,
  locale: string,
  t: Translate,
): string {
  const text = bucketDate(bucket, granularity, locale);
  return granularity === 'week' ? t('analytics.trend.weekOf', { date: text }) : text;
}
