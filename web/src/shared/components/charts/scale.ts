/**
 * Axis helpers for charts. Values are integer minor units used only for
 * geometry (bar lengths, line positions); every number a person reads comes
 * from the API's exact strings, formatted with formatMoney().
 */

function niceStep(range: number, count: number): number {
  const raw = range / count;
  const magnitude = 10 ** Math.floor(Math.log10(raw));
  const normalized = raw / magnitude;
  const step =
    normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 2.5 ? 2.5 : normalized <= 5 ? 5 : 10;
  return step * magnitude;
}

export interface LinearScale {
  min: number;
  max: number;
  ticks: number[];
}

/** A zero-anchored domain with about four round tick steps. */
export function linearScale(values: readonly number[], tickCount = 4): LinearScale {
  let min = Math.min(0, ...values);
  let max = Math.max(0, ...values);
  if (min === max) max = min + 1;
  const step = niceStep(max - min, tickCount);
  min = Math.floor(min / step) * step;
  max = Math.ceil(max / step) * step;
  const ticks: number[] = [];
  for (let value = min; value <= max + step / 2; value += step) ticks.push(Math.round(value));
  return { min, max, ticks };
}

/** Bar length as a CSS percentage of the largest value (never negative). */
export function barPercent(value: number, max: number): string {
  if (max <= 0 || value <= 0) return '0%';
  return `${Math.max(1, (value / max) * 100).toFixed(2)}%`;
}

/** Compact currency for axis ticks only ("₹2.5K"), from minor units. */
export function formatAxisMoney(minor: number, currency: string, exponent: number, locale: string) {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    notation: 'compact',
    maximumFractionDigits: 1,
  }).format(minor / 10 ** exponent);
}

/**
 * Short axis labels for calendar dates: "Nov 2" for days and weeks (with a
 * 2-digit year when years differ), "Nov 2026" for months, "2026" for years.
 */
export function axisDateLabels(
  dates: readonly string[],
  locale: string,
  granularity: 'day' | 'week' | 'month' | 'year' = 'day',
): string[] {
  const years = new Set(dates.map((date) => date.slice(0, 4)));
  const options: Intl.DateTimeFormatOptions =
    granularity === 'year'
      ? { year: 'numeric' }
      : granularity === 'month'
        ? { month: 'short', year: 'numeric' }
        : { month: 'short', day: 'numeric', ...(years.size > 1 ? { year: '2-digit' } : {}) };
  const format = new Intl.DateTimeFormat(locale, { ...options, timeZone: 'UTC' });
  return dates.map((date) => {
    const [year, month, day] = date.split('-').map(Number);
    if (!year || !month || !day) return date;
    return format.format(new Date(Date.UTC(year, month - 1, day)));
  });
}

/**
 * Which x positions get a visible label so labels never collide: always the
 * first and last, plus evenly spaced ones while there is room. Every value
 * stays readable in the table view and the hover titles.
 */
export function visibleLabelIndexes(labels: readonly string[], plotWidth: number): number[] {
  const count = labels.length;
  if (count === 0) return [];
  if (count === 1) return [0];
  // ~7px per character at 12px plus breathing room.
  const labelWidth = Math.max(...labels.map((label) => label.length)) * 7 + 16;
  const slots = Math.max(2, Math.floor(plotWidth / labelWidth));
  if (count <= slots) return [...Array(count).keys()];
  const step = Math.ceil((count - 1) / (slots - 1));
  const indexes: number[] = [];
  for (let index = 0; index < count - 1; index += step) indexes.push(index);
  // Keep the last label, dropping a neighbour that would touch it.
  const last = count - 1;
  if (indexes.length > 1 && last - (indexes[indexes.length - 1] ?? 0) < step / 2) indexes.pop();
  indexes.push(last);
  return indexes;
}
