import type { IconName } from '@/shared/components/Icon';
import type { MeterTone } from '@/shared/components/ProgressMeter';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import type { AnalyticsView, CompareMode } from './filters';
import type { BudgetPace, CategoryKind, Granularity, RecurringCommitment } from './types';

/*
 * Localized labels for analytics enums. The maps are typed against the
 * generated unions, so a value added to the contract fails compilation
 * until it has a label.
 */

export const viewLabel: Readonly<Record<AnalyticsView, MessageKey>> = {
  'cash-flow': 'analytics.view.cashFlow',
  categories: 'analytics.view.categories',
  merchants: 'analytics.view.merchants',
  'payment-methods': 'analytics.view.paymentMethods',
  compare: 'analytics.view.compare',
  accounts: 'analytics.view.accounts',
  plans: 'analytics.view.plans',
};

export const viewIcon: Readonly<Record<AnalyticsView, IconName>> = {
  'cash-flow': 'line-chart',
  categories: 'pie-chart',
  merchants: 'shopping-bag',
  'payment-methods': 'credit-card',
  compare: 'scale',
  accounts: 'wallet',
  plans: 'target',
};

export const granularityLabel: Readonly<Record<Granularity, MessageKey>> = {
  day: 'analytics.group.day',
  week: 'analytics.group.week',
  month: 'analytics.group.month',
  year: 'analytics.group.year',
};

export const categoryKindLabel: Readonly<Record<CategoryKind, MessageKey>> = {
  expense: 'analytics.measure.spending',
  income: 'analytics.measure.income',
};

export const compareModeLabel: Readonly<Record<CompareMode, MessageKey>> = {
  previous: 'analytics.compare.mode.previous',
  last_year: 'analytics.compare.mode.lastYear',
  custom: 'analytics.compare.mode.custom',
};

interface PaceDisplay {
  label: MessageKey;
  icon: IconName;
  tone: Tone;
  meter: MeterTone;
}

/** Budget pace is always shown as icon + words; the color only repeats it. */
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

export const PACES = [
  'under_pace',
  'on_track',
  'ahead_of_pace',
  'over_budget',
] as const satisfies readonly BudgetPace[];

export function isPace(value: string): value is BudgetPace {
  return (PACES as readonly string[]).includes(value);
}

export const recurringKindLabel: Readonly<Record<RecurringCommitment['kind'], MessageKey>> = {
  expense: 'recurring.kind.expense',
  income: 'recurring.kind.income',
  transfer: 'recurring.kind.transfer',
  bill: 'recurring.kind.bill',
  subscription: 'recurring.kind.subscription',
  group_expense: 'recurring.kind.group_expense',
};
