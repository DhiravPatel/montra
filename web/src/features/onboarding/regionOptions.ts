import type { SelectOption } from '@/shared/components/Select';

function supportedTimeZones(): string[] {
  try {
    return Intl.supportedValuesOf('timeZone');
  } catch {
    return [];
  }
}

/** IANA time zones the browser knows, plus the current one and UTC, sorted. */
export function timeZones(current: string): string[] {
  return [...new Set([current, ...supportedTimeZones(), 'UTC'].filter(Boolean))].sort();
}

/** Monday..Sunday names in the interface language, keyed 0 = Sunday like the API. */
export function weekdayOptions(locale: string): SelectOption[] {
  const format = new Intl.DateTimeFormat(locale, { weekday: 'long', timeZone: 'UTC' });
  // 2026-11-01 was a Sunday.
  return Array.from({ length: 7 }, (_, day) => ({
    value: String(day),
    label: format.format(new Date(Date.UTC(2026, 10, 1 + day))),
  }));
}

/** Days 1-28 (the API's range for the day a month starts). */
export function monthStartOptions(): SelectOption[] {
  return Array.from({ length: 28 }, (_, index) => ({
    value: String(index + 1),
    label: String(index + 1),
  }));
}
