import type {
  Category,
  CategoryKind,
  CategoryRule,
  CategoryRuleInput,
  MergeAffected,
  MerchantMergeAffected,
  MerchantStatusFilter,
} from '@/shared/finance/types';
import { categoryName } from '@/shared/finance/categories';
import { parseLocalDate } from '@/shared/formatting/dates';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/*
 * Labels and small helpers for the organize screens. Maps are typed against
 * the generated contract unions, so a new enum value fails compilation until
 * it has a label.
 */

export const CATEGORY_KINDS = [
  'expense',
  'income',
  'both',
] as const satisfies readonly CategoryKind[];

export const categoryKindLabel: Readonly<Record<CategoryKind, MessageKey>> = {
  expense: 'categories.kind.expense',
  income: 'categories.kind.income',
  both: 'categories.kind.both',
};

export function isCategoryKind(value: string): value is CategoryKind {
  return (CATEGORY_KINDS as readonly string[]).includes(value);
}

export type RuleField = CategoryRuleInput['match_field'];
export type RuleMatch = CategoryRuleInput['match_type'];
export type RuleApplyTo = NonNullable<CategoryRuleInput['apply_to']>;
export type RuleType = NonNullable<CategoryRuleInput['transaction_type']>;

export const RULE_FIELDS = [
  'any',
  'description',
  'merchant',
] as const satisfies readonly RuleField[];
export const RULE_MATCHES = [
  'contains',
  'equals',
  'starts_with',
  'regex',
] as const satisfies readonly RuleMatch[];
export const RULE_APPLY_TO = ['all', 'manual', 'imports'] as const satisfies readonly RuleApplyTo[];
export const RULE_TYPES = ['expense', 'income'] as const satisfies readonly RuleType[];

export const ruleFieldLabel: Readonly<Record<RuleField, MessageKey>> = {
  any: 'categoryRules.field.any',
  description: 'categoryRules.field.description',
  merchant: 'categoryRules.field.merchant',
};

export const ruleMatchLabel: Readonly<Record<RuleMatch, MessageKey>> = {
  contains: 'categoryRules.match.contains',
  equals: 'categoryRules.match.equals',
  starts_with: 'categoryRules.match.starts_with',
  regex: 'categoryRules.match.regex',
};

export const ruleSummaryKey: Readonly<Record<RuleMatch, MessageKey>> = {
  contains: 'categoryRules.summary.contains',
  equals: 'categoryRules.summary.equals',
  starts_with: 'categoryRules.summary.starts_with',
  regex: 'categoryRules.summary.regex',
};

export const ruleApplyToLabel: Readonly<Record<RuleApplyTo, MessageKey>> = {
  all: 'categoryRules.applyTo.all',
  manual: 'categoryRules.applyTo.manual',
  imports: 'categoryRules.applyTo.imports',
};

export const ruleTypeLabel: Readonly<Record<RuleType, MessageKey>> = {
  expense: 'categoryRules.only.expense',
  income: 'categoryRules.only.income',
};

function oneOf<T extends string>(values: readonly T[], value: string): value is T {
  return (values as readonly string[]).includes(value);
}

export const isRuleField = (value: string): value is RuleField => oneOf(RULE_FIELDS, value);
export const isRuleMatch = (value: string): value is RuleMatch => oneOf(RULE_MATCHES, value);
export const isRuleApplyTo = (value: string): value is RuleApplyTo => oneOf(RULE_APPLY_TO, value);
export const isRuleType = (value: string): value is RuleType => oneOf(RULE_TYPES, value);

/** What a category merge moves (and what keeps a category in use), in display order. */
export const CATEGORY_COUNTS = [
  'transactions',
  'subcategories',
  'rules',
  'merchants',
  'recurring_rules',
  'bills',
  'subscriptions',
  'budget_allocations',
  'budget_filters',
] as const satisfies readonly (keyof MergeAffected)[];

type MissingCategoryCounts = Exclude<keyof MergeAffected, (typeof CATEGORY_COUNTS)[number]>;
/** Compile-time check: every count of the contract's MergeAffected is shown. */
export const categoryCountsAreListed: [MissingCategoryCounts] extends [never]
  ? true
  : MissingCategoryCounts = true;

/** What a merchant merge moves, in display order. */
export const MERCHANT_COUNTS = [
  'transactions',
  'aliases',
  'rules',
  'recurring_rules',
  'subscriptions',
  'budget_allocations',
  'budget_filters',
] as const satisfies readonly (keyof MerchantMergeAffected)[];

type MissingMerchantCounts = Exclude<keyof MerchantMergeAffected, (typeof MERCHANT_COUNTS)[number]>;
/** Compile-time check: every count of the contract's MerchantMergeAffected is shown. */
export const merchantCountsAreListed: [MissingMerchantCounts] extends [never]
  ? true
  : MissingMerchantCounts = true;

/** Record counts as noun phrases ("12 transactions"); budget filters name the target. */
const categoryCountLabel: Readonly<Record<(typeof CATEGORY_COUNTS)[number], MessageKey>> = {
  transactions: 'organize.merge.affected.transactions',
  subcategories: 'organize.merge.affected.subcategories',
  rules: 'organize.merge.affected.rules',
  merchants: 'organize.merge.affected.merchants',
  recurring_rules: 'organize.merge.affected.recurring_rules',
  bills: 'organize.merge.affected.bills',
  subscriptions: 'organize.merge.affected.subscriptions',
  budget_allocations: 'organize.merge.affected.budget_allocations',
  budget_filters: 'organize.merge.affected.budget_filters',
};

const inUseCountLabel: Readonly<Record<(typeof CATEGORY_COUNTS)[number], MessageKey>> = {
  ...categoryCountLabel,
  budget_filters: 'organize.categories.inUse.budget_filters',
};

const merchantCountLabel: Readonly<Record<(typeof MERCHANT_COUNTS)[number], MessageKey>> = {
  transactions: 'organize.merge.affected.transactions',
  aliases: 'merchants.merge.affected.aliases',
  rules: 'organize.merge.affected.rules',
  recurring_rules: 'organize.merge.affected.recurring_rules',
  subscriptions: 'organize.merge.affected.subscriptions',
  budget_allocations: 'organize.merge.affected.budget_allocations',
  budget_filters: 'merchants.merge.affected.budget_filters',
};

export interface MergeImpact {
  key: string;
  text: string;
}

/**
 * Localized lines for non-zero counts, in display order. Counts the client
 * does not know yet (an additive contract change) are summed as "other
 * linked records". `count` reads a value (numbers, or decimal strings in
 * error params).
 */
function impactLines(
  counts: Readonly<Record<string, unknown>>,
  order: readonly string[],
  label: (key: string) => MessageKey,
  t: Translate,
  params: Readonly<Record<string, string>> = {},
): MergeImpact[] {
  const count = (value: unknown): number => {
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string' && /^\d+$/.test(value)) return Number(value);
    return 0;
  };
  const lines: MergeImpact[] = [];
  for (const key of order) {
    const n = count(counts[key]);
    if (n > 0) lines.push({ key, text: t(label(key), { ...params, count: n }) });
  }
  const known = new Set(order);
  let other = 0;
  for (const [key, value] of Object.entries(counts)) {
    if (!known.has(key)) other += count(value);
  }
  if (other > 0) {
    lines.push({ key: 'other', text: t('organize.merge.affected.other', { count: other }) });
  }
  return lines;
}

/** What a category merge moves into `target` (non-zero counts only). */
export function mergeImpact(affected: MergeAffected, target: string, t: Translate): MergeImpact[] {
  return impactLines(
    affected,
    CATEGORY_COUNTS,
    (key) => categoryCountLabel[key as (typeof CATEGORY_COUNTS)[number]],
    t,
    { target },
  );
}

/** What still uses a category (the params of a 409 category_in_use). */
export function inUseImpact(
  params: Readonly<Record<string, unknown>>,
  t: Translate,
): MergeImpact[] {
  return impactLines(
    params,
    CATEGORY_COUNTS,
    (key) => inUseCountLabel[key as (typeof CATEGORY_COUNTS)[number]],
    t,
  );
}

/** What a merchant merge moves into the merchant called `target`. */
export function merchantMergeImpact(
  affected: MerchantMergeAffected,
  target: string,
  t: Translate,
): MergeImpact[] {
  return impactLines(
    affected,
    MERCHANT_COUNTS,
    (key) => merchantCountLabel[key as (typeof MERCHANT_COUNTS)[number]],
    t,
    { name: target },
  );
}

/** Accessible palette for categories and tags (always shown with a name, never color alone). */
export const COLOR_PALETTE = [
  { value: '#0F766E', labelKey: 'organize.color.teal' },
  { value: '#2563EB', labelKey: 'organize.color.blue' },
  { value: '#4F46E5', labelKey: 'organize.color.indigo' },
  { value: '#7C3AED', labelKey: 'organize.color.purple' },
  { value: '#DB2777', labelKey: 'organize.color.pink' },
  { value: '#DC2626', labelKey: 'organize.color.red' },
  { value: '#EA580C', labelKey: 'organize.color.orange' },
  { value: '#CA8A04', labelKey: 'organize.color.yellow' },
  { value: '#16A34A', labelKey: 'organize.color.green' },
  { value: '#64748B', labelKey: 'organize.color.gray' },
] as const satisfies readonly { value: string; labelKey: MessageKey }[];

const HEX_COLOR = /^#[0-9A-Fa-f]{6}$/;

export function isHexColor(value: string | null | undefined): value is string {
  return typeof value === 'string' && HEX_COLOR.test(value);
}

export interface OrganizeNode {
  category: Category;
  children: Category[];
}

/**
 * Categories as parents with their subcategories, including archived ones
 * when the list has them (merged categories are left out). A subcategory
 * whose parent is not in the list is shown at the top level.
 */
export function organizeTree(
  categories: readonly Category[],
  t: Translate,
  locale: string,
): OrganizeNode[] {
  const byOrder = (a: Category, b: Category) =>
    a.sort_order - b.sort_order || categoryName(a, t).localeCompare(categoryName(b, t), locale);
  const visible = categories.filter((category) => category.status !== 'merged');
  const ids = new Set(visible.map((category) => category.id));
  return visible
    .filter((category) => !category.parent_id || !ids.has(category.parent_id))
    .sort(byOrder)
    .map((category) => ({
      category,
      children: visible.filter((child) => child.parent_id === category.id).sort(byOrder),
    }));
}

/** "November 2026" for a "YYYY-MM" month; the raw value when it cannot be read. */
export function formatMonth(month: string, locale: string, style: 'long' | 'short' = 'long') {
  const date = parseLocalDate(`${month}-01`);
  if (!date) return month;
  return new Intl.DateTimeFormat(locale, {
    month: style,
    year: 'numeric',
    timeZone: 'UTC',
  }).format(date);
}

/** Only http(s) URLs are shown as links (the API also requires them). */
export function isWebAddress(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}

/** Rules in the order the API runs them: lowest priority number first. */
export function sortRules(rules: readonly CategoryRule[]): CategoryRule[] {
  return [...rules].sort(
    (a, b) => a.priority - b.priority || a.created_at.localeCompare(b.created_at),
  );
}

/** GET /merchants?status: active (default), archived, merged or all. */
export const MERCHANT_STATUSES = [
  'active',
  'archived',
  'merged',
  'all',
] as const satisfies readonly MerchantStatusFilter[];

type MissingMerchantStatuses = Exclude<MerchantStatusFilter, (typeof MERCHANT_STATUSES)[number]>;
/** Compile-time check: every contract status filter is offered. */
export const merchantStatusesAreListed: [MissingMerchantStatuses] extends [never]
  ? true
  : MissingMerchantStatuses = true;

export const merchantStatusFilterLabel: Readonly<Record<MerchantStatusFilter, MessageKey>> = {
  active: 'merchants.filter.active',
  archived: 'merchants.filter.archived',
  merged: 'merchants.filter.merged',
  all: 'merchants.filter.all',
};

export function parseMerchantStatus(value: string | null): MerchantStatusFilter {
  return MERCHANT_STATUSES.find((status) => status === value) ?? 'active';
}
