import type {
  Category,
  CategoryRule,
  MergeAffected,
  Merchant,
  MerchantDetail,
  MerchantMergeAffected,
  Tag,
} from '@/shared/finance/types';
import {
  CATEGORY_GROCERIES,
  CATEGORY_SALARY,
  CATEGORY_TRAVEL,
  TAG_HOME,
  makeCategory,
  money,
  starterCategories,
} from './financeFixtures';

/** Fixtures for the organize screens: categories, rules, tags and merchants (tests only). */

export const CATEGORY_FRUIT = '44444444-4444-4444-8444-444444444411';
export const CATEGORY_FOOD = '44444444-4444-4444-8444-444444444412';
export const CATEGORY_OLD = '44444444-4444-4444-8444-444444444413';
export const RULE_SWIGGY = 'abababab-abab-4bab-8bab-abababab0001';
export const RULE_UBER = 'abababab-abab-4bab-8bab-abababab0002';
export const TAG_TRIP = '55555555-5555-4555-8555-555555555502';
export const MERCHANT_BIG_BAZAAR = '99999999-9999-4999-8999-999999999901';
export const MERCHANT_BB_ONLINE = '99999999-9999-4999-8999-999999999902';
export const MERCHANT_SWIGGY = '99999999-9999-4999-8999-999999999903';

/** Starter categories plus a subcategory ("Fruit" inside "Groceries") and "Food & dining". */
export function organizeCategories(): Category[] {
  return [
    ...starterCategories().map((category) =>
      category.id === CATEGORY_GROCERIES ? { ...category, transaction_count: 12 } : category,
    ),
    makeCategory({
      id: CATEGORY_FRUIT,
      name: 'Fruit',
      system_key: undefined,
      parent_id: CATEGORY_GROCERIES,
      sort_order: 0,
      color: '#16A34A',
    }),
    makeCategory({
      id: CATEGORY_FOOD,
      name: 'Food & dining',
      system_key: 'food_dining',
      sort_order: 5,
      transaction_count: 4,
    }),
  ];
}

export function archivedCategory(): Category {
  return makeCategory({
    id: CATEGORY_OLD,
    name: 'Old hobby',
    system_key: undefined,
    status: 'archived',
    sort_order: 300,
    transaction_count: 2,
  });
}

export { CATEGORY_GROCERIES, CATEGORY_SALARY, CATEGORY_TRAVEL, TAG_HOME };

export function makeRule(overrides: Partial<CategoryRule> = {}): CategoryRule {
  return {
    id: RULE_SWIGGY,
    name: 'Food delivery',
    priority: 10,
    enabled: true,
    match_field: 'any',
    match_type: 'contains',
    pattern: 'swiggy',
    set_category_id: CATEGORY_FOOD,
    apply_to: 'all',
    created_at: '2026-11-01T08:00:00Z',
    currency: null,
    version: 1,
    ...overrides,
  };
}

export function makeTagRecord(overrides: Partial<Tag> = {}): Tag {
  return { id: TAG_HOME, name: 'home', usage_count: 3, version: 1, ...overrides };
}

export function makeMerchant(overrides: Partial<Merchant> = {}): Merchant {
  return {
    id: MERCHANT_BIG_BAZAAR,
    name: 'Big Bazaar',
    status: 'active',
    aliases: [],
    transaction_count: 3,
    last_used_on: '2026-11-03',
    version: 1,
    ...overrides,
  };
}

export function makeMerchantDetail(overrides: Partial<MerchantDetail> = {}): MerchantDetail {
  return {
    ...makeMerchant(),
    aliases: ['BIGBAZAAR*1234'],
    default_category_id: CATEGORY_GROCERIES,
    website: 'https://bigbazaar.example',
    notes: 'Weekly shop',
    spending: [
      { month: '2026-09', total: money('1200.00'), count: 2 },
      { month: '2026-10', total: money('300.00'), count: 1 },
      { month: '2026-11', total: money('4200.00'), count: 3 },
    ],
    ...overrides,
  };
}

/** Counts a category merge (or a refused delete) reports; zero unless overridden. */
export function makeMergeAffected(overrides: Partial<MergeAffected> = {}): MergeAffected {
  return {
    transactions: 0,
    subcategories: 0,
    rules: 0,
    merchants: 0,
    recurring_rules: 0,
    bills: 0,
    subscriptions: 0,
    budget_allocations: 0,
    budget_filters: 0,
    ...overrides,
  };
}

/** Counts a merchant merge preview reports; zero unless overridden. */
export function makeMerchantMergeAffected(
  overrides: Partial<MerchantMergeAffected> = {},
): MerchantMergeAffected {
  return {
    transactions: 0,
    aliases: 0,
    rules: 0,
    recurring_rules: 0,
    subscriptions: 0,
    budget_allocations: 0,
    budget_filters: 0,
    ...overrides,
  };
}
