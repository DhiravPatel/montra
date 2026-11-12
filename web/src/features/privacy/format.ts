const UNITS = ['byte', 'kilobyte', 'megabyte', 'gigabyte', 'terabyte'] as const;

/**
 * A byte count for people: "512 bytes", "1.5 MB", "2 GB" (1024-based, the
 * way the API's allowances are configured). Sizes are not money, so working
 * them out here is fine.
 */
export function formatBytes(bytes: number, locale: string): string {
  let value = Number.isFinite(bytes) ? Math.max(0, bytes) : 0;
  let index = 0;
  while (value >= 1024 && index < UNITS.length - 1) {
    value /= 1024;
    index += 1;
  }
  return new Intl.NumberFormat(locale, {
    style: 'unit',
    unit: UNITS[index] ?? 'byte',
    unitDisplay: index === 0 ? 'long' : 'short',
    maximumFractionDigits: index === 0 || value >= 100 ? 0 : 1,
  }).format(value);
}

/**
 * The share of the storage allowance in use, in basis points (for the meter
 * only; the text always shows both sizes). 0 when there is no cap.
 */
export function storageShareBp(usedBytes: number, quotaBytes: number): number {
  if (!(quotaBytes > 0) || !(usedBytes > 0)) return 0;
  return Math.round((usedBytes / quotaBytes) * 10_000);
}
