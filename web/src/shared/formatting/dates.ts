/** Locale-aware date formatting. Inputs are RFC 3339 strings from the API. */

/**
 * Parses an API timestamp; returns null for invalid values and for the
 * zero-time placeholder (year 0001) that older API builds sent.
 */
export function parseTimestamp(iso: string | null | undefined): Date | null {
  if (!iso) return null;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime()) || date.getUTCFullYear() < 1971) return null;
  return date;
}

export function formatDateTime(date: Date, locale: string, timeZone?: string): string {
  return new Intl.DateTimeFormat(locale, {
    dateStyle: 'medium',
    timeStyle: 'short',
    ...(timeZone ? { timeZone } : {}),
  }).format(date);
}

export function formatDate(date: Date, locale: string, timeZone?: string): string {
  return new Intl.DateTimeFormat(locale, {
    dateStyle: 'long',
    ...(timeZone ? { timeZone } : {}),
  }).format(date);
}

const RELATIVE_STEPS: readonly (readonly [Intl.RelativeTimeFormatUnit, number])[] = [
  ['second', 60],
  ['minute', 60],
  ['hour', 24],
  ['day', 7],
  ['week', 4.345],
  ['month', 12],
  ['year', Number.POSITIVE_INFINITY],
];

/** "5 minutes ago", "yesterday", "now" — localized with Intl.RelativeTimeFormat. */
export function formatRelativeTime(date: Date, locale: string, now: number = Date.now()): string {
  const formatter = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });
  let value = (date.getTime() - now) / 1000;
  if (Math.abs(value) < 45) return formatter.format(0, 'second');
  for (const [unit, size] of RELATIVE_STEPS) {
    if (Math.abs(value) < size) return formatter.format(Math.round(value), unit);
    value /= size;
  }
  return formatter.format(Math.round(value), 'year');
}

/*
 * Calendar dates ("YYYY-MM-DD") are days in the user's or the record's time
 * zone, not instants. They are formatted in UTC so no browser time zone can
 * shift them to the previous or next day.
 */

const LOCAL_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

/** Parses "YYYY-MM-DD" as that calendar day (UTC midnight); null when invalid. */
export function parseLocalDate(value: string | null | undefined): Date | null {
  if (!value) return null;
  const match = LOCAL_DATE.exec(value);
  if (!match) return null;
  const [, year, month, day] = match;
  const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
  if (
    date.getUTCFullYear() !== Number(year) ||
    date.getUTCMonth() !== Number(month) - 1 ||
    date.getUTCDate() !== Number(day)
  ) {
    return null;
  }
  return date;
}

export function isLocalDate(value: string): boolean {
  return parseLocalDate(value) !== null;
}

/** Formats a calendar date for display, e.g. "4 Nov 2026"; falls back to the raw value. */
export function formatLocalDate(
  value: string,
  locale: string,
  style: 'long' | 'medium' | 'short' = 'medium',
): string {
  const date = parseLocalDate(value);
  if (!date) return value;
  return new Intl.DateTimeFormat(locale, { dateStyle: style, timeZone: 'UTC' }).format(date);
}

/** A calendar-date range such as "1–30 Nov 2026". */
export function formatLocalDateRange(from: string, to: string, locale: string): string {
  const start = parseLocalDate(from);
  const end = parseLocalDate(to);
  if (!start || !end) return `${from} – ${to}`;
  const format = new Intl.DateTimeFormat(locale, { dateStyle: 'medium', timeZone: 'UTC' });
  return from === to ? format.format(start) : format.formatRange(start, end);
}

function toLocalDateString(date: Date): string {
  const year = String(date.getUTCFullYear()).padStart(4, '0');
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/** Today's calendar date in an IANA time zone, as "YYYY-MM-DD". */
export function todayInTimeZone(timeZone: string, now: Date = new Date()): string {
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat('en-US', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(now);
  } catch {
    return toLocalDateString(now); // unknown zone: fall back to UTC
  }
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((item) => item.type === type)?.value ?? '';
  return `${part('year')}-${part('month')}-${part('day')}`;
}

/** Calendar arithmetic on "YYYY-MM-DD" (no time zone involved). */
export function addDaysToLocalDate(value: string, days: number): string {
  const date = parseLocalDate(value);
  if (!date) return value;
  date.setUTCDate(date.getUTCDate() + days);
  return toLocalDateString(date);
}

/** Basis points (10000 = 100 %) as a localized percentage with at most one decimal. */
export function formatBasisPoints(basisPoints: number, locale: string): string {
  return new Intl.NumberFormat(locale, {
    style: 'percent',
    maximumFractionDigits: 1,
  }).format(basisPoints / 10_000);
}
