import { ChartFrame, ChartLegend, ChartTable } from '@/shared/components/charts/ChartFrame';
import { ColumnChart } from '@/shared/components/charts/ColumnChart';
import { axisDateLabels, formatAxisMoney } from '@/shared/components/charts/scale';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import type { SeriesPoint } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { CurrencyHeading, WidgetCard } from '../components/WidgetCard';
import type { WidgetProps } from './types';

function byCurrency(points: readonly SeriesPoint[]): Map<string, SeriesPoint[]> {
  const groups = new Map<string, SeriesPoint[]>();
  for (const point of points) {
    const list = groups.get(point.currency) ?? [];
    list.push(point);
    groups.set(point.currency, list);
  }
  for (const list of groups.values()) list.sort((a, b) => a.bucket.localeCompare(b.bucket));
  return groups;
}

/** Income and spending per period bucket, one chart per currency. */
export function CashFlowTrendWidget({ summary, title, drill }: WidgetProps) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const currencies = useCurrencies();
  const granularity = summary.trend_granularity;
  const groups = [...byCurrency(summary.trend).entries()].filter(([, points]) =>
    points.some((point) => point.income.amount_minor !== 0 || point.net_expense.amount_minor !== 0),
  );

  return (
    <WidgetCard
      title={title}
      window={summary.window}
      generatedAt={summary.generated_at}
      drillDown={{ to: drill(), label: t('dashboard.viewTransactions') }}
    >
      {groups.length === 0 ? (
        <EmptyState
          icon="trending-up"
          title={t('dashboard.noActivity')}
          description={t('dashboard.noActivityBody')}
        />
      ) : (
        <div className="space-y-8">
          {groups.map(([currency, points]) => {
            // The highest spending bucket is picked by comparing exact minor units (no arithmetic).
            const peak = points.reduce((best, point) =>
              point.net_expense.amount_minor > best.net_expense.amount_minor ? point : best,
            );
            const first = points[0];
            const last = points[points.length - 1];
            const label = (bucket: string) => formatLocalDate(bucket, formatLocale, 'medium');
            const exponent = exponentFor(currencies.data, currency);
            return (
              <section key={currency} aria-label={t('dashboard.inCurrency', { currency })}>
                {groups.length > 1 ? <CurrencyHeading currency={currency} /> : null}
                <ChartFrame
                  label={t('dashboard.trend.chartLabel', { currency })}
                  summary={
                    <p>
                      {t(`dashboard.trend.summary.${granularity}`, {
                        from: first ? label(first.bucket) : '',
                        to: last ? label(last.bucket) : '',
                      })}{' '}
                      {peak.net_expense.amount_minor > 0
                        ? t('dashboard.trend.peak', {
                            amount: format(peak.net_expense),
                            date: label(peak.bucket),
                          })
                        : null}
                    </p>
                  }
                  legend={
                    <ChartLegend
                      items={[
                        {
                          key: 'income',
                          label: t('dashboard.cashFlow.income'),
                          swatchClass: 'bg-chart-1',
                        },
                        {
                          key: 'spending',
                          label: t('dashboard.cashFlow.spending'),
                          swatchClass: 'bg-chart-2',
                        },
                      ]}
                    />
                  }
                  table={
                    <ChartTable
                      caption={t('dashboard.trend.chartLabel', { currency })}
                      columns={[
                        t('charts.period'),
                        t('dashboard.cashFlow.income'),
                        t('dashboard.cashFlow.spending'),
                        t('dashboard.cashFlow.net'),
                      ]}
                      rows={points.map((point) => ({
                        key: point.bucket,
                        cells: [
                          label(point.bucket),
                          <MoneyText key="income" money={point.income} />,
                          <MoneyText key="spending" money={point.net_expense} />,
                          <MoneyText key="net" money={point.net} signDisplay="exceptZero" />,
                        ],
                      }))}
                    />
                  }
                >
                  <ColumnChart
                    series={[
                      {
                        key: 'income',
                        label: t('dashboard.cashFlow.income'),
                        fillClass: 'fill-chart-1',
                        values: points.map((point) => point.income.amount_minor),
                        valueTexts: points.map((point) => format(point.income)),
                      },
                      {
                        key: 'spending',
                        label: t('dashboard.cashFlow.spending'),
                        fillClass: 'fill-chart-2',
                        values: points.map((point) => point.net_expense.amount_minor),
                        valueTexts: points.map((point) => format(point.net_expense)),
                      },
                    ]}
                    xLabels={axisDateLabels(
                      points.map((point) => point.bucket),
                      formatLocale,
                      granularity,
                    )}
                    formatTick={(value) => formatAxisMoney(value, currency, exponent, formatLocale)}
                  />
                </ChartFrame>
              </section>
            );
          })}
        </div>
      )}
    </WidgetCard>
  );
}
