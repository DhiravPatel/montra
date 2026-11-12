import type { DashboardSummary } from '@/shared/finance/types';

export interface WidgetProps {
  summary: DashboardSummary;
  title: string;
  /** Path to the transactions behind this widget (same period and filters), plus extra filters. */
  drill: (extra?: Readonly<Record<string, string | undefined>>) => string;
}
