import { Link } from 'react-router';
import { BarList } from '@/shared/components/charts/BarList';
import { ChartFrame, ChartTable } from '@/shared/components/charts/ChartFrame';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import { isSafeInternalPath } from '@/shared/config/paths';
import { categoriesById, categoryName } from '@/shared/finance/categories';
import { useCategories } from '@/shared/finance/reference';
import type { CategorySlice } from '@/shared/finance/types';
import { formatBasisPoints } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { CurrencyHeading, WidgetCard } from '../components/WidgetCard';
import type { WidgetProps } from './types';

/** Net spending by category, ranked, one hue; each row opens its transactions. */
export function CategoryBreakdownWidget({ summary, title, drill }: WidgetProps) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const categories = useCategories(true);
  const byId = categoriesById(categories.data);
  const slices = summary.top_categories;
  const currencies = [...new Set(slices.map((slice) => slice.currency))];

  const name = (slice: CategorySlice) => {
    if (slice.system_key === 'uncategorized' || !slice.category_id) {
      return t('categories.uncategorized');
    }
    if (slice.system_key)
      return categoryName({ name: slice.name, system_key: slice.system_key }, t);
    const category = byId.get(slice.category_id);
    return category ? categoryName(category, t) : slice.name;
  };
  const link = (slice: CategorySlice) =>
    isSafeInternalPath(slice.drill_down_path)
      ? slice.drill_down_path
      : drill(slice.category_id ? { category_id: slice.category_id } : { uncategorized: 'true' });

  return (
    <WidgetCard
      title={title}
      window={summary.window}
      generatedAt={summary.generated_at}
      drillDown={{ to: drill(), label: t('dashboard.viewTransactions') }}
    >
      {slices.length === 0 ? (
        <EmptyState
          icon="bar-chart"
          title={t('dashboard.categories.empty')}
          description={t('dashboard.noActivityBody')}
        />
      ) : (
        <div className="space-y-8">
          {currencies.map((currency) => {
            const rows = slices.filter((slice) => slice.currency === currency);
            const top = rows[0];
            return (
              <section key={currency} aria-label={t('dashboard.inCurrency', { currency })}>
                {currencies.length > 1 ? <CurrencyHeading currency={currency} /> : null}
                <ChartFrame
                  label={t('dashboard.categories.chartLabel', { currency })}
                  summary={
                    top ? (
                      <p>
                        {t('dashboard.categories.summary', {
                          name: name(top),
                          amount: format(top.amount),
                          share: formatBasisPoints(top.share_bp, formatLocale),
                        })}
                      </p>
                    ) : null
                  }
                  table={
                    <ChartTable
                      caption={t('dashboard.categories.chartLabel', { currency })}
                      columns={[
                        t('transactions.form.category'),
                        t('dashboard.cashFlow.spending'),
                        t('dashboard.share'),
                        t('dashboard.count'),
                      ]}
                      rows={rows.map((slice) => ({
                        key: slice.category_id ?? 'uncategorized',
                        cells: [
                          name(slice),
                          <MoneyText key="amount" money={slice.amount} />,
                          formatBasisPoints(slice.share_bp, formatLocale),
                          slice.count,
                        ],
                      }))}
                    />
                  }
                >
                  <BarList
                    rows={rows.map((slice) => ({
                      key: slice.category_id ?? 'uncategorized',
                      label: (
                        <Link
                          to={link(slice)}
                          className="font-medium underline-offset-4 hover:underline"
                        >
                          {name(slice)}
                        </Link>
                      ),
                      valueText: (
                        <>
                          <MoneyText money={slice.amount} />{' '}
                          <span className="font-normal text-fg-muted">
                            ({formatBasisPoints(slice.share_bp, formatLocale)})
                          </span>
                        </>
                      ),
                      value: slice.amount.amount_minor,
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
