import type { IconName } from '@/shared/components/Icon';
import type { MeterTone } from '@/shared/components/ProgressMeter';
import type { Tone } from '@/shared/components/tones';
import type {
  Budget,
  BudgetAccess,
  BudgetAlert,
  BudgetAlertThreshold,
  BudgetPace,
  BudgetPeriod,
  BudgetType,
} from '@/shared/finance/types';
import type { MessageKey } from '@/shared/i18n/types';

/*
 * Localized labels for budget enums. Maps are typed against the generated
 * unions, so a value added to the contract fails compilation until it has
 * a label.
 */

export const BUDGET_TYPES = [
  'total',
  'category',
  'merchant',
  'account',
  'envelope',
  'zero_based',
] as const satisfies readonly BudgetType[];

type MissingTypes = Exclude<BudgetType, (typeof BUDGET_TYPES)[number]>;
/** Compile-time check: every contract budget type is listed above. */
export const budgetTypesAreListed: [MissingTypes] extends [never] ? true : MissingTypes = true;

export const budgetTypeLabel: Readonly<Record<BudgetType, MessageKey>> = {
  total: 'budgets.type.total',
  category: 'budgets.type.category',
  merchant: 'budgets.type.merchant',
  account: 'budgets.type.account',
  envelope: 'budgets.type.envelope',
  zero_based: 'budgets.type.zero_based',
};

export const budgetTypeHelp: Readonly<Record<BudgetType, MessageKey>> = {
  total: 'budgets.type.total.help',
  category: 'budgets.type.category.help',
  merchant: 'budgets.type.merchant.help',
  account: 'budgets.type.account.help',
  envelope: 'budgets.type.envelope.help',
  zero_based: 'budgets.type.zero_based.help',
};

export function isBudgetType(value: string): value is BudgetType {
  return (BUDGET_TYPES as readonly string[]).includes(value);
}

/**
 * Group budgets count all of the group's expenses, so they can only be a
 * total budget or be split between members (envelopes, zero-based).
 */
export const GROUP_BUDGET_TYPES = [
  'total',
  'envelope',
  'zero_based',
] as const satisfies readonly BudgetType[];

export function isGroupBudgetType(value: string): boolean {
  return (GROUP_BUDGET_TYPES as readonly string[]).includes(value);
}

export const BUDGET_PERIODS = [
  'weekly',
  'monthly',
  'annual',
  'custom',
] as const satisfies readonly BudgetPeriod[];

type MissingPeriods = Exclude<BudgetPeriod, (typeof BUDGET_PERIODS)[number]>;
export const budgetPeriodsAreListed: [MissingPeriods] extends [never] ? true : MissingPeriods =
  true;

export const periodLabel: Readonly<Record<BudgetPeriod, MessageKey>> = {
  weekly: 'budgets.period.weekly',
  monthly: 'budgets.period.monthly',
  annual: 'budgets.period.annual',
  custom: 'budgets.period.custom',
};

export function isBudgetPeriod(value: string): value is BudgetPeriod {
  return (BUDGET_PERIODS as readonly string[]).includes(value);
}

export type RolloverPolicy = Budget['rollover_policy'];

export const ROLLOVER_POLICIES = [
  'none',
  'carry_unused',
  'carry_overspend',
  'carry_both',
] as const satisfies readonly RolloverPolicy[];

type MissingRollover = Exclude<RolloverPolicy, (typeof ROLLOVER_POLICIES)[number]>;
export const rolloverPoliciesAreListed: [MissingRollover] extends [never] ? true : MissingRollover =
  true;

export const rolloverLabel: Readonly<Record<RolloverPolicy, MessageKey>> = {
  none: 'budgets.rollover.none',
  carry_unused: 'budgets.rollover.carry_unused',
  carry_overspend: 'budgets.rollover.carry_overspend',
  carry_both: 'budgets.rollover.carry_both',
};

export function isRolloverPolicy(value: string): value is RolloverPolicy {
  return (ROLLOVER_POLICIES as readonly string[]).includes(value);
}

interface PaceDisplay {
  label: MessageKey;
  icon: IconName;
  tone: Tone;
  meter: MeterTone;
}

/** Pace is always shown as icon + words; the color only repeats it. */
export const paceDisplay: Readonly<Record<BudgetPace, PaceDisplay>> = {
  under_pace: {
    label: 'budgets.pace.under_pace',
    icon: 'trending-down',
    tone: 'success',
    meter: 'success',
  },
  on_track: {
    label: 'budgets.pace.on_track',
    icon: 'check-circle',
    tone: 'success',
    meter: 'accent',
  },
  ahead_of_pace: {
    label: 'budgets.pace.ahead_of_pace',
    icon: 'trending-up',
    tone: 'warning',
    meter: 'warning',
  },
  over_budget: {
    label: 'budgets.pace.over_budget',
    icon: 'alert-circle',
    tone: 'danger',
    meter: 'danger',
  },
};

export const accessLabel: Readonly<Record<BudgetAccess, MessageKey>> = {
  owner: 'budgets.access.owner',
  editor: 'budgets.access.editor',
  viewer: 'budgets.access.viewer',
};

export type MemberRole = 'editor' | 'viewer';

export const memberRoleLabel: Readonly<Record<MemberRole, MessageKey>> = {
  editor: 'budgets.members.role.editor',
  viewer: 'budgets.members.role.viewer',
};

export const memberRoleHelp: Readonly<Record<MemberRole, MessageKey>> = {
  editor: 'budgets.members.role.editor.help',
  viewer: 'budgets.members.role.viewer.help',
};

export const budgetStatusLabel: Readonly<Record<Budget['status'], MessageKey>> = {
  active: 'budgets.status.active',
  paused: 'budgets.status.paused',
  archived: 'budgets.status.archived',
};

export const alertStatusLabel: Readonly<Record<BudgetAlert['status'], MessageKey>> = {
  active: 'budgets.alerts.status.active',
  snoozed: 'budgets.alerts.status.snoozed',
  dismissed: 'budgets.alerts.status.dismissed',
};

/** Every alert threshold the API accepts (percent of the limit), in order. */
export const ALERT_THRESHOLDS = [
  1, 5, 10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 95, 100, 110, 125, 150,
] as const satisfies readonly BudgetAlertThreshold[];

type MissingThresholds = Exclude<BudgetAlertThreshold, (typeof ALERT_THRESHOLDS)[number]>;
/** Compile-time check: every contract threshold is offered above. */
export const alertThresholdsAreListed: [MissingThresholds] extends [never]
  ? true
  : MissingThresholds = true;

export function isAlertThreshold(value: number): value is BudgetAlertThreshold {
  return (ALERT_THRESHOLDS as readonly number[]).includes(value);
}

/** The API's defaults when a new budget does not choose (50/75/90/100 %). */
export const DEFAULT_ALERT_THRESHOLDS: readonly BudgetAlertThreshold[] = [50, 75, 90, 100];
