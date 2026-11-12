import type { CalendarItem } from '@/shared/finance/types';
import { billPath, goalPath, recurringPath, subscriptionPath } from '@/shared/config/paths';

/*
 * Month arithmetic for the planning calendar on "YYYY-MM" strings (calendar
 * months, no time zone involved). One month is always within the API's
 * 93-day limit.
 */

const MONTH = /^(\d{4})-(0[1-9]|1[0-2])$/;

export function parseMonth(value: string | null): string | null {
  return value && MONTH.test(value) ? value : null;
}

function parts(month: string): [number, number] {
  const [year = '1970', monthPart = '01'] = month.split('-');
  return [Number(year), Number(monthPart)];
}

function format(year: number, month: number): string {
  return `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}`;
}

export function shiftMonth(month: string, delta: number): string {
  const [year, monthNumber] = parts(month);
  const index = year * 12 + (monthNumber - 1) + delta;
  return format(Math.floor(index / 12), (index % 12) + 1);
}

/** First and last calendar day of a month, as "YYYY-MM-DD". */
export function monthRange(month: string): { from: string; to: string } {
  const [year, monthNumber] = parts(month);
  const lastDay = new Date(Date.UTC(year, monthNumber, 0)).getUTCDate();
  return { from: `${month}-01`, to: `${month}-${String(lastDay).padStart(2, '0')}` };
}

export function monthLabel(month: string, locale: string): string {
  const [year, monthNumber] = parts(month);
  return new Intl.DateTimeFormat(locale, {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(Date.UTC(year, monthNumber - 1, 1)));
}

/** "Thursday, 5 November" for a day heading. */
export function dayHeading(date: string, locale: string): string {
  const [year = '1970', month = '01', day = '01'] = date.split('-');
  return new Intl.DateTimeFormat(locale, {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    timeZone: 'UTC',
  }).format(new Date(Date.UTC(Number(year), Number(month) - 1, Number(day))));
}

export interface CalendarDay {
  date: string;
  items: CalendarItem[];
}

/** Items grouped by date in date order (the API's order is kept within a day). */
export function groupByDate(items: readonly CalendarItem[]): CalendarDay[] {
  const days = new Map<string, CalendarItem[]>();
  for (const item of items) {
    const list = days.get(item.date);
    if (list) list.push(item);
    else days.set(item.date, [item]);
  }
  return [...days.entries()]
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([date, list]) => ({ date, items: list }));
}

/** The page for a calendar entry, when the web portal has one. */
export function calendarItemPath(item: CalendarItem): string | null {
  switch (item.entity_type) {
    case 'bill':
      return billPath(item.entity_id);
    case 'recurring_rule':
      return recurringPath(item.entity_id);
    case 'subscription':
      return subscriptionPath(item.entity_id);
    case 'goal':
      return goalPath(item.entity_id);
    case 'group_recurring_expense':
      return null;
  }
}
