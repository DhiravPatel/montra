import type { MessageKey } from '@/shared/i18n/types';

interface WidgetLabel {
  title: MessageKey;
  description: MessageKey;
}

/**
 * Widgets drawn from GET /dashboard/summary (the chosen period and filters),
 * by the API's widget key.
 */
const summaryWidgetLabels = {
  balances: { title: 'dashboard.widget.balances', description: 'dashboard.widget.balancesHelp' },
  cash_flow: { title: 'dashboard.widget.cash_flow', description: 'dashboard.widget.cash_flowHelp' },
  income_vs_expense: {
    title: 'dashboard.widget.income_vs_expense',
    description: 'dashboard.widget.income_vs_expenseHelp',
  },
  cash_flow_trend: {
    title: 'dashboard.widget.cash_flow_trend',
    description: 'dashboard.widget.cash_flow_trendHelp',
  },
  category_breakdown: {
    title: 'dashboard.widget.category_breakdown',
    description: 'dashboard.widget.category_breakdownHelp',
  },
  top_merchants: {
    title: 'dashboard.widget.top_merchants',
    description: 'dashboard.widget.top_merchantsHelp',
  },
  recent_transactions: {
    title: 'dashboard.widget.recent_transactions',
    description: 'dashboard.widget.recent_transactionsHelp',
  },
  data_coverage: {
    title: 'dashboard.widget.data_coverage',
    description: 'dashboard.widget.data_coverageHelp',
  },
} as const satisfies Record<string, WidgetLabel>;

/**
 * Widgets drawn from GET /dashboard/planning (one request for all four,
 * independent of the period filter).
 */
const planningWidgetLabels = {
  budgets: { title: 'dashboard.widget.budgets', description: 'dashboard.widget.budgetsHelp' },
  upcoming: { title: 'dashboard.widget.upcoming', description: 'dashboard.widget.upcomingHelp' },
  goals: { title: 'dashboard.widget.goals', description: 'dashboard.widget.goalsHelp' },
  group_balances: {
    title: 'dashboard.widget.group_balances',
    description: 'dashboard.widget.group_balancesHelp',
  },
} as const satisfies Record<string, WidgetLabel>;

export type SummaryWidgetKey = keyof typeof summaryWidgetLabels;
export type PlanningWidgetKey = keyof typeof planningWidgetLabels;
export type KnownWidgetKey = SummaryWidgetKey | PlanningWidgetKey;

/**
 * Widgets this client can draw. Keys the API adds later still appear in the
 * layout settings under a generic name, so saving the layout keeps them.
 */
export const widgetLabels: Readonly<Record<KnownWidgetKey, WidgetLabel>> = {
  ...summaryWidgetLabels,
  ...planningWidgetLabels,
};

/**
 * The API's default order (backend widget registry), used when the saved
 * layout cannot be loaded.
 */
export const DEFAULT_WIDGET_ORDER = [
  'balances',
  'cash_flow',
  'budgets',
  'upcoming',
  'income_vs_expense',
  'cash_flow_trend',
  'category_breakdown',
  'top_merchants',
  'goals',
  'group_balances',
  'recent_transactions',
  'data_coverage',
] as const satisfies readonly KnownWidgetKey[];

type MissingFromOrder = Exclude<KnownWidgetKey, (typeof DEFAULT_WIDGET_ORDER)[number]>;
/** Compile-time check: every widget this client draws has a default position. */
export const widgetOrderIsComplete: [MissingFromOrder] extends [never] ? true : MissingFromOrder =
  true;

export function isKnownWidget(key: string): key is KnownWidgetKey {
  return Object.hasOwn(widgetLabels, key);
}

export function isSummaryWidget(key: string): key is SummaryWidgetKey {
  return Object.hasOwn(summaryWidgetLabels, key);
}

export function isPlanningWidget(key: string): key is PlanningWidgetKey {
  return Object.hasOwn(planningWidgetLabels, key);
}
