import { parseTimestamp } from '@/shared/formatting/dates';

/** The day a receipt was added, in the person's time zone (e.g. "Nov 4, 2026"). */
export function formatAddedOn(iso: string, locale: string, timeZone: string): string | null {
  const date = parseTimestamp(iso);
  if (!date) return null;
  try {
    return new Intl.DateTimeFormat(locale, { dateStyle: 'medium', timeZone }).format(date);
  } catch {
    // An unknown zone name: fall back to the browser's zone rather than hide the date.
    return new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(date);
  }
}
