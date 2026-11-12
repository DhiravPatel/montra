import type { IconName } from '@/shared/components/Icon';
import type { SelectOption } from '@/shared/components/Select';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type {
  DisputeStatus,
  ExpenseStatus,
  FxRateSource,
  RecurringSplitMethod,
  SettlementMethod,
  SettlementStatus,
  SplitMethod,
} from './types';

/*
 * Localized labels, icons and tones for group money enums. The maps are
 * typed against the generated unions, so a value added to the contract
 * fails compilation until it has a label. Status is always icon + text.
 */

export interface StatusLook {
  label: MessageKey;
  icon: IconName;
  tone: Tone;
}

export const SPLIT_METHODS = [
  'equal',
  'exact',
  'percentage',
  'shares',
  'itemized',
] as const satisfies readonly SplitMethod[];

type MissingSplitMethods = Exclude<SplitMethod, (typeof SPLIT_METHODS)[number]>;
/** Compile-time check: every split method in the contract is offered. */
export const splitMethodsAreListed: [MissingSplitMethods] extends [never]
  ? true
  : MissingSplitMethods = true;

/** Recurring expenses cannot use an itemized split (items change every time). */
export const RECURRING_SPLIT_METHODS = [
  'equal',
  'exact',
  'percentage',
  'shares',
] as const satisfies readonly RecurringSplitMethod[];

export function isSplitMethod(value: string): value is SplitMethod {
  return (SPLIT_METHODS as readonly string[]).includes(value);
}

export function isRecurringSplitMethod(value: string): value is RecurringSplitMethod {
  return (RECURRING_SPLIT_METHODS as readonly string[]).includes(value);
}

export const splitMethodLabel: Readonly<Record<SplitMethod, MessageKey>> = {
  equal: 'groupMoney.split.equal',
  exact: 'groupMoney.split.exact',
  percentage: 'groupMoney.split.percentage',
  shares: 'groupMoney.split.shares',
  itemized: 'groupMoney.split.itemized',
};

export const splitMethodHelp: Readonly<Record<SplitMethod, MessageKey>> = {
  equal: 'groupMoney.split.equalHelp',
  exact: 'groupMoney.split.exactHelp',
  percentage: 'groupMoney.split.percentageHelp',
  shares: 'groupMoney.split.sharesHelp',
  itemized: 'groupMoney.split.itemizedHelp',
};

/** "Split method" for any server value (falls back to the raw value for unknown ones). */
export function splitMethodName(value: string, t: Translate): string {
  return isSplitMethod(value) ? t(splitMethodLabel[value]) : value;
}

/**
 * Where a saved expense's rate came from: typed by a member (or taken from
 * their saved rates), or Montra's rate for the expense date (ECB or the
 * rate provider).
 */
export const fxRateSourceLabel: Readonly<Record<FxRateSource, MessageKey>> = {
  manual: 'groupMoney.fxSource.manual',
  ecb: 'groupMoney.fxSource.ecb',
  provider: 'groupMoney.fxSource.provider',
};

export const expenseStatusLook: Readonly<Record<ExpenseStatus, StatusLook>> = {
  active: { label: 'groupMoney.expenseStatus.active', icon: 'check-circle', tone: 'success' },
  disputed: { label: 'groupMoney.expenseStatus.disputed', icon: 'alert-triangle', tone: 'warning' },
  deleted: { label: 'groupMoney.expenseStatus.deleted', icon: 'trash', tone: 'neutral' },
};

export const disputeStatusLook: Readonly<Record<DisputeStatus, StatusLook>> = {
  open: { label: 'groupMoney.disputeStatus.open', icon: 'alert-triangle', tone: 'warning' },
  resolved: { label: 'groupMoney.disputeStatus.resolved', icon: 'check-circle', tone: 'success' },
  withdrawn: { label: 'groupMoney.disputeStatus.withdrawn', icon: 'undo', tone: 'neutral' },
};

export const settlementStatusLook: Readonly<Record<SettlementStatus, StatusLook>> = {
  proposed: { label: 'groupMoney.settlementStatus.proposed', icon: 'calendar', tone: 'neutral' },
  user_reported_paid: {
    label: 'groupMoney.settlementStatus.user_reported_paid',
    icon: 'clock',
    tone: 'info',
  },
  confirmed: {
    label: 'groupMoney.settlementStatus.confirmed',
    icon: 'check-circle',
    tone: 'success',
  },
  disputed: {
    label: 'groupMoney.settlementStatus.disputed',
    icon: 'alert-triangle',
    tone: 'warning',
  },
  voided: { label: 'groupMoney.settlementStatus.voided', icon: 'ban', tone: 'neutral' },
};

export const SETTLEMENT_METHODS = [
  'upi',
  'bank_transfer',
  'cash',
  'other',
] as const satisfies readonly SettlementMethod[];

type MissingSettlementMethods = Exclude<SettlementMethod, (typeof SETTLEMENT_METHODS)[number]>;
export const settlementMethodsAreListed: [MissingSettlementMethods] extends [never]
  ? true
  : MissingSettlementMethods = true;

export function isSettlementMethod(value: string): value is SettlementMethod {
  return (SETTLEMENT_METHODS as readonly string[]).includes(value);
}

export const settlementMethodLabel: Readonly<Record<SettlementMethod, MessageKey>> = {
  cash: 'finance.paymentKind.cash',
  upi: 'finance.paymentKind.upi',
  bank_transfer: 'finance.paymentKind.bank_transfer',
  other: 'finance.paymentKind.other',
};

/** Starter category keys that fit shared spending (income keys are left out). */
const categoryKeyLabels = {
  food_dining: 'categories.starter.food_dining',
  groceries: 'categories.starter.groceries',
  housing_rent: 'categories.starter.housing_rent',
  utilities: 'categories.starter.utilities',
  transport: 'categories.starter.transport',
  fuel: 'categories.starter.fuel',
  travel: 'categories.starter.travel',
  entertainment: 'categories.starter.entertainment',
  shopping: 'categories.starter.shopping',
  healthcare: 'categories.starter.healthcare',
  education: 'categories.starter.education',
  personal_care: 'categories.starter.personal_care',
  insurance: 'categories.starter.insurance',
  taxes_fees: 'categories.starter.taxes_fees',
  gifts_donations: 'categories.starter.gifts_donations',
  family: 'categories.starter.family',
  work_expenses: 'categories.starter.work_expenses',
  other: 'categories.starter.other',
} as const satisfies Record<string, MessageKey>;

type GroupCategoryKey = keyof typeof categoryKeyLabels;

function isGroupCategoryKey(value: string): value is GroupCategoryKey {
  return value in categoryKeyLabels;
}

/** Category choices for a shared expense, keeping `keep` (an existing record's key) available. */
export function categoryKeyOptions(t: Translate, keep?: string): SelectOption[] {
  const options: SelectOption[] = (Object.keys(categoryKeyLabels) as GroupCategoryKey[]).map(
    (key) => ({
      value: key,
      label: t(categoryKeyLabels[key]),
    }),
  );
  if (keep && !isGroupCategoryKey(keep)) {
    options.push({ value: keep, label: categoryKeyName(keep, t) });
  }
  return options;
}

/** Other starter keys the API accepts (shown by name when a record uses one). */
const otherStarterLabels = {
  salary: 'categories.starter.salary',
  freelance_income: 'categories.starter.freelance_income',
  interest: 'categories.starter.interest',
  refunds: 'categories.starter.refunds',
} as const satisfies Record<string, MessageKey>;

function isOtherStarterKey(value: string): value is keyof typeof otherStarterLabels {
  return value in otherStarterLabels;
}

/** A category key from the API in the interface language ("uncategorized" included). */
export function categoryKeyName(key: string | undefined, t: Translate): string {
  if (!key || key === 'uncategorized') return t('categories.uncategorized');
  if (isGroupCategoryKey(key)) return t(categoryKeyLabels[key]);
  if (isOtherStarterKey(key)) return t(otherStarterLabels[key]);
  return key;
}
