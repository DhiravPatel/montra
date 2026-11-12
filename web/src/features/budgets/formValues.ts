import type {
  Budget,
  BudgetAlertThreshold,
  BudgetAllocation,
  BudgetAllocationInput,
  BudgetInput,
  BudgetPatch,
  BudgetPeriod,
  BudgetType,
} from '@/shared/finance/types';
import { compareDecimal, decimalToInput } from '@/shared/formatting/decimal';
import { DEFAULT_ALERT_THRESHOLDS, type RolloverPolicy, isAlertThreshold } from './labels';

/** What an allocation (a sub-limit) applies to. */
export type AllocationTarget = 'category' | 'merchant' | 'account' | 'member' | 'label';

export interface AllocationValues {
  target: AllocationTarget;
  categoryId: string;
  merchantId: string;
  /** Display only; '' until looked up. */
  merchantName: string;
  accountId: string;
  memberUserId: string;
  label: string;
  limit: string;
}

export interface MerchantChoice {
  id: string;
  /** Display only; '' until looked up. */
  name: string;
}

/** Threshold alerts at the chosen levels, or none at all (`alert_thresholds: []`). */
export type AlertsMode = 'levels' | 'off';

export interface BudgetFormValues {
  name: string;
  budgetType: string;
  period: string;
  startsOn: string;
  endsOn: string;
  currency: string;
  limit: string;
  rolloverPolicy: string;
  rolloverCap: string;
  includedAccountIds: string[];
  excludedCategoryIds: string[];
  merchants: MerchantChoice[];
  allocations: AllocationValues[];
  alertsMode: AlertsMode;
  /** The levels while `alertsMode` is 'levels' (kept when switching alerts off and on). */
  alertThresholds: number[];
  alertForecast: boolean;
  includePending: boolean;
  refundsRestore: boolean;
  countGroupShares: boolean;
  groupId: string;
  visibility: 'private' | 'members';
  notes: string;
}

/** The exact amounts read from the form (canonical decimal strings). */
export interface BudgetAmounts {
  limit: string;
  rolloverCap: string | null;
  allocationLimits: readonly string[];
}

export function emptyAllocation(target: AllocationTarget): AllocationValues {
  return {
    target,
    categoryId: '',
    merchantId: '',
    merchantName: '',
    accountId: '',
    memberUserId: '',
    label: '',
    limit: '',
  };
}

/** The allocation target that fits a budget type best. */
export function defaultAllocationTarget(type: string, grouped: boolean): AllocationTarget {
  if (grouped) return 'member';
  if (type === 'merchant') return 'merchant';
  if (type === 'account') return 'account';
  return 'category';
}

/**
 * Allocation targets a budget accepts: group budgets are split between
 * current group members only; personal budgets never by member, by merchant
 * only in merchant budgets and by account only in account budgets.
 */
export function allowedAllocationTargets(type: string, grouped: boolean): AllocationTarget[] {
  if (grouped) return ['member'];
  return [
    'category',
    ...(type === 'merchant' ? (['merchant'] as const) : []),
    ...(type === 'account' ? (['account'] as const) : []),
    'label',
  ];
}

export function newBudgetValues(currency: string, today: string): BudgetFormValues {
  return {
    name: '',
    budgetType: 'total',
    period: 'monthly',
    startsOn: today,
    endsOn: '',
    currency,
    limit: '',
    rolloverPolicy: 'none',
    rolloverCap: '',
    includedAccountIds: [],
    excludedCategoryIds: [],
    merchants: [],
    allocations: [],
    alertsMode: 'levels',
    alertThresholds: [...DEFAULT_ALERT_THRESHOLDS],
    alertForecast: true,
    includePending: false,
    refundsRestore: true,
    countGroupShares: true,
    groupId: '',
    visibility: 'private',
    notes: '',
  };
}

function allocationTarget(allocation: BudgetAllocation): AllocationTarget {
  if (allocation.category_id) return 'category';
  if (allocation.merchant_id) return 'merchant';
  if (allocation.account_id) return 'account';
  if (allocation.member_user_id) return 'member';
  return 'label';
}

export function budgetToValues(budget: Budget, locale: string): BudgetFormValues {
  const alertsOff = budget.alert_thresholds.length === 0;
  return {
    name: budget.name,
    budgetType: budget.budget_type,
    period: budget.period,
    startsOn: budget.starts_on,
    endsOn: budget.ends_on ?? '',
    currency: budget.currency,
    limit: decimalToInput(budget.limit.amount, locale),
    rolloverPolicy: budget.rollover_policy,
    rolloverCap: budget.rollover_cap ? decimalToInput(budget.rollover_cap.amount, locale) : '',
    includedAccountIds: [...budget.included_account_ids],
    excludedCategoryIds: [...budget.excluded_category_ids],
    merchants: budget.merchant_ids.map((id) => ({ id, name: '' })),
    allocations: budget.allocations.map((allocation) => ({
      target: allocationTarget(allocation),
      categoryId: allocation.category_id ?? '',
      merchantId: allocation.merchant_id ?? '',
      merchantName: '',
      accountId: allocation.account_id ?? '',
      memberUserId: allocation.member_user_id ?? '',
      label: allocation.label ?? '',
      limit: decimalToInput(allocation.limit.amount, locale),
    })),
    alertsMode: alertsOff ? 'off' : 'levels',
    alertThresholds: alertsOff ? [...DEFAULT_ALERT_THRESHOLDS] : [...budget.alert_thresholds],
    alertForecast: budget.alert_forecast,
    includePending: budget.include_pending,
    refundsRestore: budget.refunds_restore,
    countGroupShares: budget.count_group_shares,
    groupId: budget.group_id ?? '',
    visibility: budget.visibility,
    notes: budget.notes ?? '',
  };
}

function allocationInput(values: AllocationValues, limit: string): BudgetAllocationInput {
  const label = values.label.trim();
  const input: BudgetAllocationInput = { limit, ...(label ? { label } : {}) };
  switch (values.target) {
    case 'category':
      return { ...input, category_id: values.categoryId };
    case 'merchant':
      return { ...input, merchant_id: values.merchantId };
    case 'account':
      return { ...input, account_id: values.accountId };
    case 'member':
      return { ...input, member_user_id: values.memberUserId };
    case 'label':
      return input;
  }
}

/** `[]` turns threshold alerts off; otherwise the chosen levels in order. */
export function thresholdsFor(
  values: Pick<BudgetFormValues, 'alertsMode' | 'alertThresholds'>,
): BudgetAlertThreshold[] {
  if (values.alertsMode === 'off') return [];
  const levels = new Set(values.alertThresholds.filter(isAlertThreshold));
  return [...levels].sort((a, b) => a - b);
}

/**
 * The create body. Group budgets count all of the group's expenses, so the
 * personal filters (hidden for them) are never sent; edits use
 * toBudgetPatch().
 */
export function toBudgetInput(values: BudgetFormValues, amounts: BudgetAmounts): BudgetInput {
  const notes = values.notes.trim();
  const rollover = values.rolloverPolicy as RolloverPolicy;
  const grouped = Boolean(values.groupId);
  return {
    name: values.name.trim(),
    budget_type: values.budgetType as BudgetType,
    period: values.period as BudgetPeriod,
    currency: values.currency,
    limit: amounts.limit,
    ...(values.startsOn ? { starts_on: values.startsOn } : {}),
    ...(values.endsOn ? { ends_on: values.endsOn } : {}),
    rollover_policy: rollover,
    ...(rollover !== 'none' && amounts.rolloverCap ? { rollover_cap: amounts.rolloverCap } : {}),
    included_account_ids: grouped ? [] : [...values.includedAccountIds],
    excluded_category_ids: grouped ? [] : [...values.excludedCategoryIds],
    merchant_ids: grouped ? [] : values.merchants.map((merchant) => merchant.id),
    allocations: values.allocations.map((allocation, index) =>
      allocationInput(allocation, amounts.allocationLimits[index] ?? allocation.limit),
    ),
    alert_thresholds: thresholdsFor(values),
    alert_forecast: values.alertForecast,
    include_pending: values.includePending,
    refunds_restore: values.refundsRestore,
    count_group_shares: values.countGroupShares,
    ...(values.groupId ? { group_id: values.groupId } : {}),
    visibility: values.visibility,
    ...(notes ? { notes } : {}),
  };
}

function sameIds(a: readonly string[], b: readonly string[]): boolean {
  if (a.length !== b.length) return false;
  const left = [...a].sort();
  const right = [...b].sort();
  return left.every((value, index) => value === right[index]);
}

function sameThresholds(
  a: readonly BudgetAlertThreshold[],
  b: readonly BudgetAlertThreshold[],
): boolean {
  if (a.length !== b.length) return false;
  const right = [...b].sort((x, y) => x - y);
  return [...a].sort((x, y) => x - y).every((value, index) => value === right[index]);
}

function sameAmount(a: string, b: string): boolean {
  try {
    return compareDecimal(a, b) === 0;
  } catch {
    return a === b;
  }
}

function sameAllocations(
  next: readonly BudgetAllocationInput[],
  saved: readonly BudgetAllocation[],
): boolean {
  if (next.length !== saved.length) return false;
  return next.every((item, index) => {
    const old = saved[index];
    if (!old) return false;
    return (
      (item.category_id ?? '') === (old.category_id ?? '') &&
      (item.merchant_id ?? '') === (old.merchant_id ?? '') &&
      (item.account_id ?? '') === (old.account_id ?? '') &&
      (item.member_user_id ?? '') === (old.member_user_id ?? '') &&
      (item.label ?? '') === (old.label ?? '') &&
      sameAmount(item.limit, old.limit.amount)
    );
  });
}

/**
 * A partial update (PATCH /budgets/{id}): only what changed against the
 * saved budget, always with its `version`. Lists are sent whole when they
 * changed (`[]` empties them); emptied text, end dates and rollover caps
 * are cleared with "". The budget keeps its own time zone and group.
 * Returns null when nothing changed.
 */
export function toBudgetPatch(
  values: BudgetFormValues,
  amounts: BudgetAmounts,
  budget: Budget,
): BudgetPatch | null {
  const next = toBudgetInput(values, amounts);
  const patch: BudgetPatch = { version: budget.version };
  const set = <K extends keyof BudgetPatch>(key: K, value: BudgetPatch[K]) => {
    patch[key] = value;
  };

  if (next.name !== budget.name) set('name', next.name);
  if (next.budget_type !== budget.budget_type) set('budget_type', next.budget_type);
  if (next.period !== budget.period) set('period', next.period);
  if (next.starts_on && next.starts_on !== budget.starts_on) set('starts_on', next.starts_on);
  if (values.endsOn !== (budget.ends_on ?? '')) set('ends_on', values.endsOn);
  if (next.currency !== budget.currency) set('currency', next.currency);
  if (!sameAmount(next.limit, budget.limit.amount)) set('limit', next.limit);
  if (next.rollover_policy !== budget.rollover_policy) {
    set('rollover_policy', next.rollover_policy);
  }
  const cap = next.rollover_cap ?? '';
  const savedCap = budget.rollover_cap?.amount ?? '';
  if (cap ? !savedCap || !sameAmount(cap, savedCap) : savedCap !== '') set('rollover_cap', cap);

  const accounts = next.included_account_ids ?? [];
  if (!sameIds(accounts, budget.included_account_ids)) set('included_account_ids', accounts);
  const excluded = next.excluded_category_ids ?? [];
  if (!sameIds(excluded, budget.excluded_category_ids)) set('excluded_category_ids', excluded);
  const merchants = next.merchant_ids ?? [];
  if (!sameIds(merchants, budget.merchant_ids)) set('merchant_ids', merchants);
  const allocations = next.allocations ?? [];
  if (!sameAllocations(allocations, budget.allocations)) set('allocations', allocations);

  const thresholds = next.alert_thresholds ?? [];
  if (!sameThresholds(thresholds, budget.alert_thresholds)) set('alert_thresholds', thresholds);
  if (values.alertForecast !== budget.alert_forecast) set('alert_forecast', values.alertForecast);
  if (values.includePending !== budget.include_pending) {
    set('include_pending', values.includePending);
  }
  if (values.refundsRestore !== budget.refunds_restore) {
    set('refunds_restore', values.refundsRestore);
  }
  if (values.countGroupShares !== budget.count_group_shares) {
    set('count_group_shares', values.countGroupShares);
  }
  if (values.visibility !== budget.visibility) set('visibility', values.visibility);
  const notes = values.notes.trim();
  if (notes !== (budget.notes ?? '')) set('notes', notes);

  // `version` alone means nothing changed.
  return Object.keys(patch).length > 1 ? patch : null;
}
