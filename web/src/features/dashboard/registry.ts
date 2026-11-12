import type { MessageKey } from '@/shared/i18n/types';

/**
 * Widgets this client can draw, by the API's widget key. Keys the API adds
 * later (budgets, goals, groups…) still appear in the layout settings under a
 * generic name and render once their screens ship.
 */
export const widgetLabels = {
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
} as const satisfies Record<string, { title: MessageKey; description: MessageKey }>;

export type KnownWidgetKey = keyof typeof widgetLabels;

export const DEFAULT_WIDGET_ORDER = Object.keys(widgetLabels) as KnownWidgetKey[];

export function isKnownWidget(key: string): key is KnownWidgetKey {
  return key in widgetLabels;
}
