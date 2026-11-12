import { BarList } from '@/shared/components/charts/BarList';
import { ChartFrame, ChartLegend, ChartTable } from '@/shared/components/charts/ChartFrame';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import type { CashFlowTotals } from '@/shared/finance/types';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useT } from '@/shared/i18n/I18nContext';
import { CurrencyHeading, WidgetCard } from '../components/WidgetCard';
import type { WidgetProps } from './types';

/** Income vs spending, this period against the previous one (emphasis on this period). */
export function IncomeVsExpenseWidget({ summary, title, drill }: WidgetProps) {
  const t = useT();
  const format = useFormatMoney();
  const totals = summary.cash_flow.filter((total) => total.transaction_count > 0);
  const previous = new Map(summary.previous_cash_flow.map((total) => [total.currency, total]));

  const chart = (total: CashFlowTotals) => {
    const before = previous.get(total.currency);
    const summaryText = before
      ? t('dashboard.incomeVsExpense.summaryWithPrevious', {
          income: format(total.income),
          spending: format(total.net_expense),
          previousIncome: format(before.income),
          previousSpending: format(before.net_expense),
        })
      : t('dashboard.incomeVsExpense.summary', {
          income: format(total.income),
          spending: format(total.net_expense),
        });
    const rows = [
      {
        key: 'income',
        label: t('dashboard.cashFlow.income'),
        value: total.income,
        previous: before?.income,
        barClass: 'bg-chart-1',
      },
      {
        key: 'spending',
        label: t('dashboard.cashFlow.spending'),
        value: total.net_expense,
        previous: before?.net_expense,
        barClass: 'bg-chart-2',
      },
    ];
    return (
      <ChartFrame
        label={t('dashboard.incomeVsExpense.chartLabel', { currency: total.currency })}
        summary={<p>{summaryText}</p>}
        legend={
          <ChartLegend
            items={[
              { key: 'income', label: t('dashboard.cashFlow.income'), swatchClass: 'bg-chart-1' },
              {
                key: 'spending',
                label: t('dashboard.cashFlow.spending'),
                swatchClass: 'bg-chart-2',
              },
              ...(before
                ? [
                    {
                      key: 'previous',
                      label: t('dashboard.previousPeriod'),
                      swatchClass: 'bg-chart-context',
                    },
                  ]
                : []),
            ]}
          />
        }
        table={
          <ChartTable
            caption={t('dashboard.incomeVsExpense.chartLabel', { currency: total.currency })}
            columns={[
              t('dashboard.measure'),
              t('dashboard.thisPeriod'),
              t('dashboard.previousPeriod'),
            ]}
            rows={[
              ...rows.map((row) => ({
                key: row.key,
                cells: [
                  row.label,
                  <MoneyText key="now" money={row.value} />,
                  row.previous ? <MoneyText key="before" money={row.previous} /> : '—',
                ],
              })),
              {
                key: 'refunds',
                cells: [
                  t('dashboard.cashFlow.refunds'),
                  <MoneyText key="now" money={total.refunds} />,
                  before ? <MoneyText key="before" money={before.refunds} /> : '—',
                ],
              },
              {
                key: 'net',
                cells: [
                  t('dashboard.cashFlow.net'),
                  <MoneyText key="now" money={total.net_cash_flow} signDisplay="exceptZero" />,
                  before ? (
                    <MoneyText key="before" money={before.net_cash_flow} signDisplay="exceptZero" />
                  ) : (
                    '—'
                  ),
                ],
              },
            ]}
          />
        }
      >
        <BarList
          rows={rows.map((row) => ({
            key: row.key,
            label: row.label,
            valueText: <MoneyText money={row.value} />,
            value: row.value.amount_minor,
            barClass: row.barClass,
            ...(row.previous
              ? {
                  comparison: {
                    value: row.previous.amount_minor,
                    label: t('dashboard.previousPeriod'),
                    valueText: format(row.previous),
                    barClass: 'bg-chart-context',
                  },
                }
              : {}),
          }))}
        />
      </ChartFrame>
    );
  };

  return (
    <WidgetCard
      title={title}
      window={summary.window}
      generatedAt={summary.generated_at}
      drillDown={{ to: drill(), label: t('dashboard.viewTransactions') }}
    >
      {totals.length === 0 ? (
        <EmptyState
          icon="bar-chart"
          title={t('dashboard.noActivity')}
          description={t('dashboard.noActivityBody')}
        />
      ) : (
        <div className="space-y-8">
          {totals.map((total) => (
            <section
              key={total.currency}
              aria-label={t('dashboard.widgetInCurrency', {
                widget: title,
                currency: total.currency,
              })}
            >
              {totals.length > 1 ? <CurrencyHeading currency={total.currency} /> : null}
              {chart(total)}
            </section>
          ))}
        </div>
      )}
    </WidgetCard>
  );
}
