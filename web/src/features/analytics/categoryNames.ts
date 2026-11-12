import { categoryName } from '@/shared/finance/categories';
import type { Category } from '@/shared/finance/types';
import type { Translate } from '@/shared/i18n/types';

interface NamedSlice {
  category_id?: string;
  name: string;
  system_key?: string;
  parent_id?: string;
}

/**
 * A category row's name in the interface language: starter categories by
 * their `system_key` (unless the user renamed them), "Uncategorized" for
 * spending without a category, and "Parent › Child" for subcategories.
 */
export function sliceName(
  slice: NamedSlice,
  byId: ReadonlyMap<string, Category>,
  t: Translate,
): string {
  if (slice.system_key === 'uncategorized' || !slice.category_id) {
    return t('categories.uncategorized');
  }
  const known = byId.get(slice.category_id);
  const own = slice.system_key
    ? categoryName({ name: slice.name, system_key: slice.system_key }, t)
    : known
      ? categoryName(known, t)
      : slice.name;
  const parent = slice.parent_id ? byId.get(slice.parent_id) : undefined;
  return parent ? `${categoryName(parent, t)} › ${own}` : own;
}

/** Rows grouped by currency in the API's order (grouping only, never summed). */
export function groupByCurrency<T extends { currency: string }>(
  rows: readonly T[],
): [string, T[]][] {
  const groups = new Map<string, T[]>();
  for (const row of rows) {
    const list = groups.get(row.currency) ?? [];
    list.push(row);
    groups.set(row.currency, list);
  }
  return [...groups.entries()];
}
