/**
 * Query-string helpers. The contract declares array parameters with
 * `explode: false`, so the API expects `type=expense,income`; repeating the
 * parameter would silently keep only one value.
 */
export const commaSeparatedArrays = { array: { style: 'form', explode: false } } as const;

type Compact<T> = { [K in keyof T]?: Exclude<T[K], null> };

/** Drops empty values (undefined, null, '', []) so they are not sent as filters. */
export function compactQuery<T extends object>(query: T): Compact<T> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null || value === '') continue;
    if (Array.isArray(value) && value.length === 0) continue;
    out[key] = value;
  }
  return out as Compact<T>;
}
