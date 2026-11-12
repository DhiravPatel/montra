import { useState } from 'react';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, LoadingState } from '@/shared/components/states';
import { categoriesById } from '@/shared/finance/categories';
import { useCategories } from '@/shared/finance/reference';
import { formatBasisPoints, formatLocalDateRange } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type SeriesKind, useCategoryBreakdown, useSeriesReport } from '../api';
import {
  CurrencySection,
  QueryError,
  RefreshFailed,
  Refreshing,
  StatTile,
  WindowText,
} from '../components/Blocks';
import { RankedChart } from '../components/RankedChart';
import { ShowAllToggle } from '../components/ShowAllToggle';
import { TrendChart } from '../components/TrendChart';
import { GroupBySelect, ViewOptions } from '../components/ViewOptions';
import { groupByCurrency, sliceName } from '../categoryNames';
import { type AnalyticsFilters, baseQuery, CATEGORY_KINDS, seriesQuery } from '../filters';
import { categoryKindLabel } from '../labels';
import { SPENDING_TYPES, transactionsLink } from '../links';
import { activeTotals, pointsByCurrency } from '../trend';
import { useAnnounceSettled } from '../useAnnounceSettled';
import type { ViewProps } from './CashFlowView';

/** Rows per currency before "Show all". */
const TOP = 10;

function CardLoading({ label }: { label: string }) {
  return (
    <LoadingState label={label}>
      <Skeleton className="h-56 w-full" />
    </LoadingState>
  );
}

const kindText = {
  expense: {
    title: 'analytics.categories.title',
    description: 'analytics.categories.description',
    chartLabel: 'analytics.categories.chartLabel',
    summary: 'analytics.categories.summary',
    empty: 'analytics.categories.empty',
    amount: 'analytics.measure.spending',
  },
  income: {
    title: 'analytics.categories.incomeTitle',
    description: 'analytics.categories.incomeDescription',
    chartLabel: 'analytics.categories.incomeChartLabel',
    summary: 'analytics.categories.incomeSummary',
    empty: 'analytics.categories.incomeEmpty',
    amount: 'analytics.measure.income',
  },
} as const;

/**
 * Net spending (or income) per category, ranked per currency by the API
 * (`amount` is what the breakdown measures); each row opens its transactions.
 */
function CategoryBreakdownCard({
  filters,
  enabled,
}: {
  filters: AnalyticsFilters;
  enabled: boolean;
}) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const [showAll, setShowAll] = useState(false);
  const text = kindText[filters.kind];
  const query = {
    ...baseQuery(filters),
    ...(filters.subcategories ? { subcategories: true } : {}),
    ...(filters.kind === 'income' ? { kind: 'income' as const } : {}),
  };
  const report = useCategoryBreakdown(query, enabled);
  const categories = useCategories(true);
  const byId = categoriesById(categories.data);
  const fresh = report.isSuccess && !report.isPlaceholderData ? report.data : null;
  useAnnounceSettled(
    fresh ? JSON.stringify(query) : null,
    fresh
      ? t('analytics.updated', {
          period: formatLocalDateRange(fresh.window.from, fresh.window.to, formatLocale),
        })
      : '',
  );

  if (report.isPending) {
    return (
      <Card title={t(text.title)}>
        <CardLoading label={t('analytics.loading')} />
      </Card>
    );
  }
  if (!report.data) {
    return (
      <Card title={t(text.title)}>
        <QueryError
          error={report.error}
          title={t('analytics.error')}
          retrying={report.isFetching}
          onRetry={() => {
            void report.refetch();
          }}
        />
      </Card>
    );
  }
  const data = report.data;
  const staleNotice = report.isError ? (
    <RefreshFailed
      message={t('analytics.stale.figures')}
      retrying={report.isFetching}
      onRetry={() => {
        void report.refetch();
      }}
    />
  ) : null;
  const groups = groupByCurrency(data.categories);
  const longest = Math.max(0, ...groups.map(([, rows]) => rows.length));
  return (
    <Card
      title={t(text.title)}
      description={
        <>
          <WindowText window={data.window} /> · {t(text.description)}
        </>
      }
      actions={
        longest > TOP ? (
          <ShowAllToggle
            expanded={showAll}
            onToggle={() => {
              setShowAll((value) => !value);
            }}
            showAllLabel={t('analytics.categories.showAll')}
            showFewerLabel={t('analytics.showFewer', { count: TOP })}
          />
        ) : null
      }
    >
      {staleNotice}
      {groups.length === 0 ? (
        <EmptyState
          icon="pie-chart"
          title={t(text.empty)}
          description={t('analytics.empty.body')}
        />
      ) : (
        <Refreshing fetching={report.isFetching} stale={report.isPlaceholderData}>
          <div className="space-y-10">
            {groups.map(([currency, slices]) => {
              const visible = showAll ? slices : slices.slice(0, TOP);
              const top = slices[0];
              return (
                <CurrencySection key={currency} currency={currency} showHeading={groups.length > 1}>
                  <RankedChart
                    label={t(text.chartLabel, { currency })}
                    summary={
                      top ? (
                        <p>
                          {t(text.summary, {
                            name: sliceName(top, byId, t),
                            amount: format(top.amount),
                            share: formatBasisPoints(top.share_bp, formatLocale),
                          })}
                          {visible.length < slices.length
                            ? ` ${t('analytics.showingTop', { shown: visible.length, total: slices.length })}`
                            : null}
                        </p>
                      ) : null
                    }
                    nameColumn={t('transactions.form.category')}
                    amountColumn={t(text.amount)}
                    rows={visible.map((slice) => ({
                      key: slice.category_id ?? 'uncategorized',
                      name: sliceName(slice, byId, t),
                      // The same transactions the row counts: the kind's types only.
                      to: transactionsLink(data.window, filters, {
                        ...(slice.category_id
                          ? { category_id: slice.category_id }
                          : { uncategorized: 'true' }),
                        type: data.kind === 'income' ? 'income' : SPENDING_TYPES,
                      }),
                      amount: slice.amount,
                      shareBp: slice.share_bp,
                      count: slice.count,
                    }))}
                  />
                </CurrencySection>
              );
            })}
          </div>
        </Refreshing>
      )}
    </Card>
  );
}

const seriesText = {
  expenses: {
    title: 'analytics.spending.title',
    chartLabel: 'analytics.spending.chartLabel',
    empty: 'analytics.spending.empty',
    total: 'analytics.spending.total',
  },
  income: {
    title: 'analytics.income.title',
    chartLabel: 'analytics.income.chartLabel',
    empty: 'analytics.income.empty',
    total: 'analytics.income.total',
  },
} as const;

/** Spending-only or income-only totals and buckets per currency (GET /analytics/expenses|income). */
function SeriesCard({
  kind,
  filters,
  enabled,
}: {
  kind: SeriesKind;
  filters: AnalyticsFilters;
  enabled: boolean;
}) {
  const { t } = useI18n();
  const format = useFormatMoney();
  const report = useSeriesReport(kind, seriesQuery(filters), enabled);
  const text = seriesText[kind];

  if (report.isPending) {
    return (
      <Card title={t(text.title)}>
        <CardLoading label={t('analytics.loading')} />
      </Card>
    );
  }
  if (!report.data) {
    return (
      <Card title={t(text.title)}>
        <QueryError
          error={report.error}
          title={t('analytics.error')}
          retrying={report.isFetching}
          onRetry={() => {
            void report.refetch();
          }}
        />
      </Card>
    );
  }
  const data = report.data;
  const staleNotice = report.isError ? (
    <RefreshFailed
      message={t('analytics.stale.figures')}
      retrying={report.isFetching}
      onRetry={() => {
        void report.refetch();
      }}
    />
  ) : null;
  const totals = activeTotals(data.totals);
  const previous = new Map(data.previous_period.map((total) => [total.currency, total]));
  const series = pointsByCurrency(data.series);
  const measure = kind === 'expenses' ? 'spending' : 'income';
  const pick = (total: (typeof totals)[number]) =>
    kind === 'expenses' ? total.net_expense : total.income;
  return (
    <Card
      title={t(text.title)}
      description={<WindowText window={data.window} />}
      actions={
        <ButtonLink
          to={transactionsLink(data.window, filters, {
            type: kind === 'expenses' ? SPENDING_TYPES : 'income',
          })}
          variant="ghost"
          size="sm"
        >
          {t('analytics.viewTransactions')}
          <Icon name="arrow-right" className="size-4" />
        </ButtonLink>
      }
    >
      {staleNotice}
      {totals.length === 0 ? (
        <EmptyState
          icon={kind === 'expenses' ? 'trending-down' : 'trending-up'}
          title={t(text.empty)}
          description={t('analytics.empty.body')}
        />
      ) : (
        <Refreshing fetching={report.isFetching} stale={report.isPlaceholderData}>
          <div className="space-y-10">
            {totals.map((total) => {
              const before = previous.get(total.currency);
              return (
                <CurrencySection
                  key={total.currency}
                  currency={total.currency}
                  showHeading={totals.length > 1}
                >
                  <dl className="grid gap-3 sm:grid-cols-2">
                    <StatTile
                      label={t(text.total)}
                      note={
                        before
                          ? t('analytics.cashFlow.previous', { amount: format(pick(before)) })
                          : t('analytics.cashFlow.previousNone')
                      }
                    >
                      <MoneyText money={pick(total)} />
                    </StatTile>
                    <StatTile label={t('analytics.count')}>
                      <span>{total.transaction_count}</span>
                    </StatTile>
                  </dl>
                  {kind === 'expenses' ? (
                    <p className="text-sm text-fg-muted">
                      {t('analytics.spending.detail', {
                        gross: format(total.gross_expense),
                        refunds: format(total.refunds),
                      })}
                    </p>
                  ) : null}
                  <TrendChart
                    label={t(text.chartLabel, { currency: total.currency })}
                    currency={total.currency}
                    points={series.get(total.currency) ?? []}
                    granularity={data.series_granularity}
                    measures={[measure]}
                  />
                </CurrencySection>
              );
            })}
          </div>
        </Refreshing>
      )}
    </Card>
  );
}

/** Where money went by category, and how spending and income moved over the period. */
export function CategoriesView({ filters, onChange, enabled }: ViewProps) {
  const { t } = useI18n();
  return (
    <>
      <ViewOptions label={t('analytics.options.label')}>
        <RadioGroup
          legend={t('analytics.categories.kind')}
          value={filters.kind}
          options={CATEGORY_KINDS.map((kind) => ({
            value: kind,
            label: t(categoryKindLabel[kind]),
          }))}
          onChange={(kind) => {
            onChange({ ...filters, kind });
          }}
        />
        <GroupBySelect filters={filters} onChange={onChange} />
        <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 text-sm text-fg">
          <input
            type="checkbox"
            checked={filters.subcategories}
            onChange={(event) => {
              onChange({ ...filters, subcategories: event.target.checked });
            }}
            className="size-5 accent-accent"
          />
          {t('analytics.categories.subcategories')}
        </label>
      </ViewOptions>
      <div className="grid gap-6">
        <CategoryBreakdownCard filters={filters} enabled={enabled} />
        <SeriesCard kind="expenses" filters={filters} enabled={enabled} />
        <SeriesCard kind="income" filters={filters} enabled={enabled} />
      </div>
    </>
  );
}
