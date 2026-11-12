import { Link } from 'react-router';
import { BarList } from '@/shared/components/charts/BarList';
import { ChartFrame, ChartTable } from '@/shared/components/charts/ChartFrame';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useT } from '@/shared/i18n/I18nContext';
import { CurrencyHeading, WidgetCard } from '../components/WidgetCard';
import type { WidgetProps } from './types';

/** Where you spent the most (net of refunds), ranked per currency. */
export function TopMerchantsWidget({ summary, title, drill }: WidgetProps) {
  const t = useT();
  const format = useFormatMoney();
  const merchants = summary.top_merchants;
  const currencies = [...new Set(merchants.map((merchant) => merchant.currency))];
  return (
    <WidgetCard
      title={title}
      window={summary.window}
      generatedAt={summary.generated_at}
      drillDown={{ to: drill(), label: t('dashboard.viewTransactions') }}
    >
      {merchants.length === 0 ? (
        <EmptyState
          icon="shopping-bag"
          title={t('dashboard.merchants.empty')}
          description={t('dashboard.merchants.emptyBody')}
        />
      ) : (
        <div className="space-y-8">
          {currencies.map((currency) => {
            const rows = merchants.filter((merchant) => merchant.currency === currency);
            const top = rows[0];
            return (
              <section key={currency} aria-label={t('dashboard.inCurrency', { currency })}>
                {currencies.length > 1 ? <CurrencyHeading currency={currency} /> : null}
                <ChartFrame
                  label={t('dashboard.merchants.chartLabel', { currency })}
                  summary={
                    top ? (
                      <p>
                        {t('dashboard.merchants.summary', {
                          name: top.name,
                          amount: format(top.net_expense),
                          count: top.count,
                        })}
                      </p>
                    ) : null
                  }
                  table={
                    <ChartTable
                      caption={t('dashboard.merchants.chartLabel', { currency })}
                      columns={[
                        t('finance.merchant.label'),
                        t('dashboard.cashFlow.spending'),
                        t('dashboard.count'),
                      ]}
                      rows={rows.map((merchant) => ({
                        key: merchant.merchant_id ?? merchant.name,
                        cells: [
                          merchant.name,
                          <MoneyText key="amount" money={merchant.net_expense} />,
                          merchant.count,
                        ],
                      }))}
                    />
                  }
                >
                  <BarList
                    rows={rows.map((merchant) => ({
                      key: merchant.merchant_id ?? merchant.name,
                      label: merchant.merchant_id ? (
                        <Link
                          to={drill({ merchant_id: merchant.merchant_id })}
                          className="font-medium underline-offset-4 hover:underline"
                        >
                          {merchant.name}
                        </Link>
                      ) : (
                        merchant.name
                      ),
                      valueText: <MoneyText money={merchant.net_expense} />,
                      value: merchant.net_expense.amount_minor,
                      barClass: 'bg-chart-1',
                    }))}
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
