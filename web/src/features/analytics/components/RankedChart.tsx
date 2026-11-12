import type { ReactNode } from 'react';
import { Link } from 'react-router';
import type { Money } from '@/shared/api/types';
import { BarList } from '@/shared/components/charts/BarList';
import { ChartFrame, ChartTable } from '@/shared/components/charts/ChartFrame';
import { MoneyText } from '@/shared/components/MoneyText';
import { formatBasisPoints } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';

export interface RankedRow {
  key: string;
  name: string;
  /** The transactions behind the row (IDs only in the link). */
  to: string;
  amount: Money;
  /** Share of the currency's total in basis points, when the API gives one. */
  shareBp?: number;
  count: number;
}

interface RankedChartProps {
  /** Figure name, e.g. "Spending by category in INR". */
  label: string;
  summary: ReactNode;
  nameColumn: string;
  amountColumn: string;
  rows: readonly RankedRow[];
}

/**
 * Ranked horizontal bars (one series, one color) with real links and text
 * values, plus the same rows as a table.
 */
export function RankedChart({ label, summary, nameColumn, amountColumn, rows }: RankedChartProps) {
  const { t, formatLocale } = useI18n();
  const withShare = rows.some((row) => row.shareBp !== undefined);
  return (
    <ChartFrame
      label={label}
      summary={summary}
      table={
        <ChartTable
          caption={label}
          columns={[
            nameColumn,
            amountColumn,
            ...(withShare ? [t('analytics.share')] : []),
            t('analytics.count'),
          ]}
          rows={rows.map((row) => ({
            key: row.key,
            cells: [
              row.name,
              <MoneyText key="amount" money={row.amount} />,
              ...(withShare
                ? [row.shareBp === undefined ? '—' : formatBasisPoints(row.shareBp, formatLocale)]
                : []),
              row.count,
            ],
          }))}
        />
      }
    >
      <BarList
        rows={rows.map((row) => ({
          key: row.key,
          label: (
            <Link to={row.to} className="font-medium underline-offset-4 hover:underline">
              {row.name}
            </Link>
          ),
          valueText: (
            <>
              <MoneyText money={row.amount} />
              {row.shareBp !== undefined ? (
                <span className="font-normal text-fg-muted">
                  {' '}
                  ({formatBasisPoints(row.shareBp, formatLocale)})
                </span>
              ) : null}
            </>
          ),
          value: row.amount.amount_minor,
          barClass: 'bg-chart-1',
        }))}
      />
    </ChartFrame>
  );
}
