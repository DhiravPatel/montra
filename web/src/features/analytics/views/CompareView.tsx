import { type ReactNode, useState } from 'react';
import { Link } from 'react-router';
import type { Money } from '@/shared/api/types';
import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { BarList } from '@/shared/components/charts/BarList';
import { ChartFrame, ChartLegend, ChartTable } from '@/shared/components/charts/ChartFrame';
import { Icon, type IconName } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { categoriesById } from '@/shared/finance/categories';
import { useCategories } from '@/shared/finance/reference';
import { formatBasisPoints, formatLocalDateRange } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useCashFlow, useComparison } from '../api';
import { CurrencySection, QueryError, RefreshFailed, Refreshing } from '../components/Blocks';
import { ShowAllToggle } from '../components/ShowAllToggle';
import { ViewOptions } from '../components/ViewOptions';
import { sliceName } from '../categoryNames';
import {
  changeDirection,
  comparisonNotes,
  countDirection,
  type Direction,
  directionLabel,
  formatChange,
  formatChangeBp,
} from '../compare';
import {
  type AnalyticsFilters,
  cashFlowQuery,
  COMPARE_MODES,
  compareQuery,
  comparisonWindow,
  type DateWindow,
  periodReady,
  previousWindow,
} from '../filters';
import { compareModeLabel } from '../labels';
import { SPENDING_TYPES, transactionsLink } from '../links';
import type {
  CashFlowTotals,
  CategoryDelta,
  Comparison,
  CurrencyComparison,
  TotalsChange,
} from '../types';
import { useAnnounceSettled } from '../useAnnounceSettled';
import type { ViewProps } from './CashFlowView';

const TOP = 10;

const directionIcon: Readonly<Record<Direction, IconName>> = {
  higher: 'arrow-up',
  lower: 'arrow-down',
  same: 'arrow-left-right',
};

/** Higher / lower / no change as an arrow plus words (never color alone, never a judgement). */
function DirectionText({ direction }: { direction: Direction }) {
  const { t } = useI18n();
  return (
    <span className="inline-flex items-center gap-1">
      <Icon name={directionIcon[direction]} className="size-4 text-fg-muted" />
      {t(directionLabel[direction])}
    </span>
  );
}

/**
 * Both periods' totals side by side with the change between them, exactly
 * as the API computed them (amount and basis points of the comparison).
 */
function TotalsTable({ item, data }: { item: CurrencyComparison; data: Comparison }) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const { current, comparison, change } = item;
  const signed = (money: Money) => format(money, { signDisplay: 'exceptZero' });
  const money = (
    key: string,
    label: string,
    pick: (totals: CashFlowTotals) => Money,
    metric: keyof Omit<TotalsChange, 'transaction_count'>,
    net = false,
  ) => ({
    key,
    cells: [
      label,
      <MoneyText key="current" money={pick(current)} signDisplay={net ? 'exceptZero' : 'auto'} />,
      <MoneyText
        key="comparison"
        money={pick(comparison)}
        signDisplay={net ? 'exceptZero' : 'auto'}
      />,
      formatChange(change[metric], signed, formatLocale),
      <DirectionText key="direction" direction={changeDirection(change[metric].change)} />,
    ],
  });
  const rate = (value: number | undefined) =>
    value === undefined ? '—' : formatBasisPoints(value, formatLocale);
  const period = (window: Comparison['window']) =>
    formatLocalDateRange(window.from, window.to, formatLocale);
  const countChange = new Intl.NumberFormat(formatLocale, { signDisplay: 'exceptZero' }).format(
    change.transaction_count,
  );
  return (
    <div className="overflow-x-auto">
      <ChartTable
        caption={t('analytics.compare.totalsLabel', { currency: item.currency })}
        columns={[
          t('analytics.compare.measure'),
          t('analytics.compare.thisPeriodDates', { period: period(data.window) }),
          t('analytics.compare.otherPeriodDates', { period: period(data.comparison_window) }),
          t('analytics.compare.change'),
          t('analytics.compare.direction'),
        ]}
        rows={[
          money('income', t('analytics.measure.income'), (totals) => totals.income, 'income'),
          money(
            'spending',
            t('analytics.measure.spending'),
            (totals) => totals.net_expense,
            'net_expense',
          ),
          money('refunds', t('analytics.measure.refunds'), (totals) => totals.refunds, 'refunds'),
          money(
            'net',
            t('analytics.measure.net'),
            (totals) => totals.net_cash_flow,
            'net_cash_flow',
            true,
          ),
          {
            key: 'rate',
            cells: [
              t('analytics.cashFlow.savingsRate'),
              rate(current.savings_rate_bp),
              rate(comparison.savings_rate_bp),
              '—',
              current.savings_rate_bp === undefined || comparison.savings_rate_bp === undefined ? (
                '—'
              ) : (
                <DirectionText
                  key="direction"
                  direction={countDirection(current.savings_rate_bp, comparison.savings_rate_bp)}
                />
              ),
            ],
          },
          {
            key: 'count',
            cells: [
              t('analytics.count'),
              current.transaction_count,
              comparison.transaction_count,
              countChange,
              <DirectionText
                key="direction"
                direction={countDirection(current.transaction_count, comparison.transaction_count)}
              />,
            ],
          },
        ]}
      />
    </div>
  );
}

/** The API's category changes (largest first): this period against the comparison period. */
function CategoryChanges({
  item,
  data,
  filters,
}: {
  item: CurrencyComparison;
  data: Comparison;
  filters: AnalyticsFilters;
}) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const categories = useCategories(true);
  const byId = categoriesById(categories.data);
  const [showAll, setShowAll] = useState(false);
  const deltas = item.categories;
  if (deltas.length === 0) {
    return <p className="text-sm text-fg-muted">{t('analytics.compare.noCategories')}</p>;
  }
  const visible = showAll ? deltas : deltas.slice(0, TOP);
  const change = (delta: CategoryDelta) =>
    delta.change_bp === undefined
      ? t('analytics.compare.changeNew', {
          amount: format(delta.change, { signDisplay: 'exceptZero' }),
        })
      : t('analytics.compare.changeValue', {
          amount: format(delta.change, { signDisplay: 'exceptZero' }),
          percent: formatChangeBp(delta.change_bp, formatLocale),
        });
  const name = (delta: CategoryDelta) => sliceName(delta, byId, t);
  const label = t('analytics.compare.categoriesLabel', { currency: item.currency });
  const first = deltas[0];
  const otherPeriod = formatLocalDateRange(
    data.comparison_window.from,
    data.comparison_window.to,
    formatLocale,
  );
  const summary: ReactNode = first ? (
    <p>
      {t('analytics.compare.categoriesSummary', { name: name(first), change: change(first) })}
      {visible.length < deltas.length
        ? ` ${t('analytics.showingTop', { shown: visible.length, total: deltas.length })}`
        : null}
    </p>
  ) : null;
  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="text-sm font-semibold text-fg">{t('analytics.compare.categoriesTitle')}</h3>
        {deltas.length > TOP ? (
          <ShowAllToggle
            expanded={showAll}
            onToggle={() => {
              setShowAll((value) => !value);
            }}
            showAllLabel={t('analytics.categories.showAll')}
            showFewerLabel={t('analytics.showFewer', { count: TOP })}
          />
        ) : null}
      </div>
      <ChartFrame
        label={label}
        summary={summary}
        legend={
          <ChartLegend
            items={[
              {
                key: 'current',
                label: t('analytics.compare.thisPeriod'),
                swatchClass: 'bg-chart-1',
              },
              {
                key: 'comparison',
                label: t('analytics.compare.otherPeriod'),
                swatchClass: 'bg-chart-context',
              },
            ]}
          />
        }
        table={
          <ChartTable
            caption={label}
            columns={[
              t('transactions.form.category'),
              t('analytics.compare.thisPeriod'),
              t('analytics.compare.otherPeriod'),
              t('analytics.compare.change'),
              t('analytics.compare.changePercent'),
            ]}
            rows={visible.map((delta) => ({
              key: delta.category_id ?? 'uncategorized',
              cells: [
                name(delta),
                <MoneyText key="current" money={delta.current} />,
                <MoneyText key="comparison" money={delta.comparison} />,
                <MoneyText key="change" money={delta.change} signDisplay="exceptZero" />,
                delta.change_bp === undefined
                  ? t('analytics.compare.new')
                  : formatChangeBp(delta.change_bp, formatLocale),
              ],
            }))}
          />
        }
      >
        <BarList
          rows={visible.map((delta) => ({
            key: delta.category_id ?? 'uncategorized',
            label: (
              <Link
                to={transactionsLink(data.window, filters, {
                  ...(delta.category_id
                    ? { category_id: delta.category_id }
                    : { uncategorized: 'true' }),
                  type: SPENDING_TYPES,
                })}
                className="font-medium underline-offset-4 hover:underline"
              >
                {name(delta)}
              </Link>
            ),
            valueText: (
              <>
                <MoneyText money={delta.current} />{' '}
                <span className="font-normal text-fg-muted">({change(delta)})</span>
              </>
            ),
            value: delta.current.amount_minor,
            barClass: 'bg-chart-1',
            comparison: {
              value: delta.comparison.amount_minor,
              label: otherPeriod,
              valueText: format(delta.comparison),
              barClass: 'bg-chart-context',
            },
          }))}
        />
      </ChartFrame>
    </div>
  );
}

/** Two periods side by side, per currency, with the API's category changes (spec §4.11). */
export function CompareView({ filters, onChange, enabled }: ViewProps) {
  const { t, formatLocale } = useI18n();
  const named = filters.range !== 'custom';
  // A named period ("this month") is resolved to dates by the API, in the
  // user's time zone; the cash-flow answer carries that window.
  const resolver = useCashFlow(cashFlowQuery(filters), enabled && named);
  let current: DateWindow | null = null;
  if (!named) {
    current = periodReady(filters) ? { from: filters.from, to: filters.to } : null;
  } else if (resolver.data && !resolver.isPlaceholderData) {
    current = { from: resolver.data.window.from, to: resolver.data.window.to };
  }
  const other = current ? comparisonWindow(current, filters) : null;
  const query = current && other ? compareQuery(filters, current, other) : null;
  const comparison = useComparison(query ?? {}, enabled && query !== null);
  const fresh =
    query && comparison.isSuccess && !comparison.isPlaceholderData ? comparison.data : null;
  useAnnounceSettled(
    fresh ? JSON.stringify(query) : null,
    fresh
      ? t('analytics.compare.updated', {
          current: formatLocalDateRange(fresh.window.from, fresh.window.to, formatLocale),
          other: formatLocalDateRange(
            fresh.comparison_window.from,
            fresh.comparison_window.to,
            formatLocale,
          ),
        })
      : '',
  );

  const customOutOfOrder =
    filters.compare === 'custom' &&
    Boolean(filters.compareFrom && filters.compareTo) &&
    filters.compareFrom > filters.compareTo;

  const options = (
    <ViewOptions label={t('analytics.options.label')}>
      <RadioGroup
        legend={t('analytics.compare.with')}
        value={filters.compare}
        options={COMPARE_MODES.map((mode) => ({ value: mode, label: t(compareModeLabel[mode]) }))}
        onChange={(mode) => {
          if (mode === 'custom' && !filters.compareFrom && !filters.compareTo && current) {
            // Start from the period before, so only the dates that differ need changing.
            const before = previousWindow(current);
            onChange({
              ...filters,
              compare: mode,
              compareFrom: before?.from ?? '',
              compareTo: before?.to ?? '',
            });
            return;
          }
          onChange({ ...filters, compare: mode });
        }}
      />
      {filters.compare === 'custom' ? (
        <div className="flex flex-wrap items-end gap-3">
          <TextField
            label={t('analytics.compare.from')}
            type="date"
            value={filters.compareFrom}
            max={filters.compareTo || undefined}
            className="min-w-40"
            error={customOutOfOrder ? t('validation.dateOrder') : undefined}
            onChange={(event) => {
              onChange({ ...filters, compareFrom: event.target.value });
            }}
          />
          <TextField
            label={t('analytics.compare.to')}
            type="date"
            value={filters.compareTo}
            min={filters.compareFrom || undefined}
            className="min-w-40"
            onChange={(event) => {
              onChange({ ...filters, compareTo: event.target.value });
            }}
          />
        </div>
      ) : null}
    </ViewOptions>
  );

  let content;
  const data = comparison.data;
  if (named && resolver.isError && !resolver.data) {
    content = (
      <Card>
        <QueryError
          error={resolver.error}
          title={t('analytics.error')}
          retrying={resolver.isFetching}
          onRetry={() => {
            void resolver.refetch();
          }}
        />
      </Card>
    );
  } else if (current && !other) {
    content = (
      <Alert tone="info" title={t('analytics.compare.chooseDates')}>
        {t('analytics.compare.chooseDatesBody')}
      </Alert>
    );
  } else if (query && comparison.isError && !data) {
    content = (
      <Card>
        <QueryError
          error={comparison.error}
          title={t('analytics.compare.error')}
          retrying={comparison.isFetching}
          onRetry={() => {
            void comparison.refetch();
          }}
        />
      </Card>
    );
  } else if (!data) {
    content = (
      <LoadingState label={t('analytics.loading')}>
        <Skeleton className="h-72 w-full" />
      </LoadingState>
    );
  } else {
    const currencies = data.currencies.filter(
      (item) =>
        item.current.transaction_count > 0 ||
        item.comparison.transaction_count > 0 ||
        item.categories.length > 0,
    );
    const heading = t('analytics.compare.heading', {
      current: formatLocalDateRange(data.window.from, data.window.to, formatLocale),
      other: formatLocalDateRange(
        data.comparison_window.from,
        data.comparison_window.to,
        formatLocale,
      ),
      zone: data.window.timezone,
    });
    content = (
      <Refreshing
        fetching={comparison.isFetching || resolver.isFetching}
        stale={comparison.isPlaceholderData || query === null}
        className="grid gap-6"
      >
        {comparison.isError ? (
          <RefreshFailed
            message={t('analytics.stale.figures')}
            retrying={comparison.isFetching}
            onRetry={() => {
              void comparison.refetch();
            }}
          />
        ) : null}
        <Card title={t('analytics.compare.title')} description={heading}>
          {currencies.length === 0 ? (
            <EmptyState
              icon="scale"
              title={t('analytics.compare.empty')}
              description={t('analytics.compare.emptyBody')}
            />
          ) : (
            <div className="space-y-10">
              {currencies.map((item) => (
                <CurrencySection
                  key={item.currency}
                  currency={item.currency}
                  showHeading={currencies.length > 1}
                >
                  <TotalsTable item={item} data={data} />
                  <CategoryChanges item={item} data={data} filters={filters} />
                </CurrencySection>
              ))}
            </div>
          )}
        </Card>
        <Card title={t('analytics.compare.notesTitle')}>
          <ul className="list-disc space-y-1 ps-5 text-sm text-fg">
            {comparisonNotes(data, t).map((note) => (
              <li key={note}>{note}</li>
            ))}
          </ul>
        </Card>
      </Refreshing>
    );
  }

  return (
    <>
      {options}
      {content}
    </>
  );
}
