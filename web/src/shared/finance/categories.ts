import { lookupMessage } from '@/shared/i18n/catalogs';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { Category, TransactionType } from './types';

/**
 * Starter categories are created by the API for every new user with a
 * `system_key` "for localization". Their names are shown in the interface
 * language until the user renames them; a renamed category keeps the name
 * the user chose.
 */
const starterKeys = {
  food_dining: 'categories.starter.food_dining',
  groceries: 'categories.starter.groceries',
  transport: 'categories.starter.transport',
  fuel: 'categories.starter.fuel',
  housing_rent: 'categories.starter.housing_rent',
  utilities: 'categories.starter.utilities',
  shopping: 'categories.starter.shopping',
  healthcare: 'categories.starter.healthcare',
  education: 'categories.starter.education',
  entertainment: 'categories.starter.entertainment',
  travel: 'categories.starter.travel',
  personal_care: 'categories.starter.personal_care',
  insurance: 'categories.starter.insurance',
  taxes_fees: 'categories.starter.taxes_fees',
  gifts_donations: 'categories.starter.gifts_donations',
  family: 'categories.starter.family',
  work_expenses: 'categories.starter.work_expenses',
  salary: 'categories.starter.salary',
  freelance_income: 'categories.starter.freelance_income',
  interest: 'categories.starter.interest',
  refunds: 'categories.starter.refunds',
  other: 'categories.starter.other',
} as const satisfies Record<string, MessageKey>;

type StarterKey = keyof typeof starterKeys;

function isStarterKey(value: string): value is StarterKey {
  return value in starterKeys;
}

/** The category's name in the interface language (user-chosen names are kept). */
export function categoryName(
  category: Pick<Category, 'name' | 'system_key'>,
  t: Translate,
): string {
  const key = category.system_key;
  if (key && isStarterKey(key)) {
    const messageKey = starterKeys[key];
    // The API seeds the English name; anything else is the user's own name.
    if (category.name === lookupMessage('en', messageKey)) return t(messageKey);
  }
  return category.name;
}

/** Name for a category reference on a transaction (localized by its system key). */
export function categoryRefName(
  ref: { id: string; name: string; system_key?: string },
  byId: ReadonlyMap<string, Category>,
  t: Translate,
): string {
  if (ref.system_key) return categoryName({ name: ref.name, system_key: ref.system_key }, t);
  const category = byId.get(ref.id);
  return category ? categoryName(category, t) : ref.name;
}

export function categoriesById(categories: readonly Category[] | undefined): Map<string, Category> {
  return new Map((categories ?? []).map((category) => [category.id, category]));
}

/** Whether a category can be used for a transaction type (mirrors the API's kind check). */
export function categoryFitsType(category: Pick<Category, 'kind'>, type: TransactionType): boolean {
  if (type === 'expense' || type === 'group_expense') return category.kind !== 'income';
  if (type === 'income') return category.kind !== 'expense';
  return true;
}

export interface CategoryNode {
  category: Category;
  children: Category[];
}

/** Active categories as a sorted tree: parents with their subcategories. */
export function categoryTree(
  categories: readonly Category[],
  t: Translate,
  locale: string,
  filter: (category: Category) => boolean = () => true,
): CategoryNode[] {
  const byName = (a: Category, b: Category) =>
    a.sort_order - b.sort_order || categoryName(a, t).localeCompare(categoryName(b, t), locale);
  const visible = categories.filter((category) => category.status === 'active' && filter(category));
  const ids = new Set(visible.map((category) => category.id));
  const parents = visible
    .filter((category) => !category.parent_id || !ids.has(category.parent_id))
    .sort(byName);
  return parents.map((category) => ({
    category,
    children: visible.filter((child) => child.parent_id === category.id).sort(byName),
  }));
}
