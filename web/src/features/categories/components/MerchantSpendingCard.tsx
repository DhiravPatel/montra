import { Card } from '@/shared/components/Card';
import { ChartFrame, ChartTable } from '@/shared/components/charts/ChartFrame';
import { ColumnChart } from '@/shared/components/charts/ColumnChart';
import { axisDateLabels, formatAxisMoney } from '@/shared/components/charts/scale';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import type { MerchantSpend } from '@/shared/finance/types';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { formatMonth } from '../labels';

function byCurrency(spending: readonly MerchantSpend[]): [string, MerchantSpend[]][] {
  const groups = new Map<string, MerchantSpend[]>();
  for (const point of spending) {
    const list = groups.get(point.total.currency) ?? [];
    list.push(point);
    groups.set(point.total.currency, list);
  }
  for (const list of groups.values()) list.sort((a, b) => a.month.localeCompare(b.month));
  return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b));
}

/**
 * Monthly spending with a merchant (server totals, net of refunds), one
 * chart and table per currency: currencies are never added together.
 */
export function MerchantSpendingCard({ spending }: { spending: readonly MerchantSpend[] }) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const currencies = useCurrencies();
  const groups = byCurrency(spending);
  return (
    <Card title={t('merchants.spending.title')} description={t('merchants.spending.description')}>
      {groups.length === 0 ? (
        <EmptyState icon="bar-chart" title={t('merchants.spending.empty')} titleAs="p" />
      ) : (
        <div className="space-y-8">
          {groups.map(([currency, points]) => {
            const first = points[0];
            const last = points[points.length - 1];
            // The highest month is found by comparing exact minor units (no arithmetic).
            const peak = points.reduce((best, point) =>
              point.total.amount_minor > best.total.amount_minor ? point : best,
            );
            const exponent = exponentFor(currencies.data, currency);
            // Bars only for non-negative totals; a refund-heavy month stays in the table.
            const chartable = points.every((point) => point.total.amount_minor >= 0);
            const label = t('merchants.spending.chartLabel', { currency });
            const table = (
              <ChartTable
                caption={label}
                columns={[
                  t('merchants.spending.month'),
                  t('merchants.spending.amount'),
                  t('merchants.spending.count'),
                ]}
                rows={points.map((point) => ({
                  key: point.month,
                  cells: [
                    formatMonth(point.month, formatLocale),
                    <MoneyText key="total" money={point.total} />,
                    String(point.count),
                  ],
                }))}
              />
            );
            return (
              <section key={currency} aria-label={label} className="space-y-3">
                {groups.length > 1 ? (
                  <h3 className="text-sm font-semibold text-fg">{currency}</h3>
                ) : null}
                {chartable ? (
                  <ChartFrame
                    label={label}
                    summary={
                      <p>
                        {t('merchants.spending.summary', {
                          from: first ? formatMonth(first.month, formatLocale) : '',
                          to: last ? formatMonth(last.month, formatLocale) : '',
                        })}{' '}
                        {peak.total.amount_minor > 0
                          ? t('merchants.spending.peak', {
                              amount: format(peak.total),
                              month: formatMonth(peak.month, formatLocale),
                            })
                          : null}
                      </p>
                    }
                    table={table}
                  >
                    <ColumnChart
                      series={[
                        {
                          key: 'spending',
                          label: t('merchants.spending.amount'),
                          fillClass: 'fill-chart-1',
                          values: points.map((point) => point.total.amount_minor),
                          valueTexts: points.map((point) => format(point.total)),
                        },
                      ]}
                      xLabels={axisDateLabels(
                        points.map((point) => `${point.month}-01`),
                        formatLocale,
                        'month',
                      )}
                      formatTick={(value) =>
                        formatAxisMoney(value, currency, exponent, formatLocale)
                      }
                    />
                  </ChartFrame>
                ) : (
                  table
                )}
              </section>
            );
          })}
        </div>
      )}
    </Card>
  );
}
