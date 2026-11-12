import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, LoadingState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { formatBasisPoints, formatLocalDateRange } from '@/shared/formatting/dates';
import { amountSign } from '@/shared/formatting/money';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useCashFlow } from '../api';
import {
  CurrencySection,
  QueryError,
  RefreshFailed,
  Refreshing,
  StatTile,
  WindowText,
} from '../components/Blocks';
import { ConvertedTotalsCard } from '../components/ConvertedTotalsCard';
import { CoverageCard } from '../components/CoverageCard';
import { TrendChart } from '../components/TrendChart';
import { DisplayCurrencySelect, GroupBySelect, ViewOptions } from '../components/ViewOptions';
import { type AnalyticsFilters, cashFlowQuery } from '../filters';
import { CASH_FLOW_TYPES, transactionsLink } from '../links';
import { activeTotals, pointsByCurrency } from '../trend';
import type { CashFlowTotals } from '../types';
import { useAnnounceSettled } from '../useAnnounceSettled';

export interface ViewProps {
  filters: AnalyticsFilters;
  onChange: (next: AnalyticsFilters) => void;
  /** False until the default period is known (the user's preference). */
  enabled: boolean;
}

function CashFlowStats({
  total,
  previous,
}: {
  total: CashFlowTotals;
  previous: CashFlowTotals | undefined;
}) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const before = (pick: (item: CashFlowTotals) => { amount: string; currency: string }) =>
    previous
      ? t('analytics.cashFlow.previous', { amount: format(pick(previous)) })
      : t('analytics.cashFlow.previousNone');
  const sign = amountSign(total.net_cash_flow.amount);
  const netMeaning =
    sign === 1
      ? t('analytics.cashFlow.positive')
      : sign === -1
        ? t('analytics.cashFlow.negative')
        : t('analytics.cashFlow.even');
  return (
    <>
      <dl className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile label={t('analytics.measure.income')} note={before((item) => item.income)}>
          <MoneyText money={total.income} />
        </StatTile>
        <StatTile label={t('analytics.measure.spending')} note={before((item) => item.net_expense)}>
          <MoneyText money={total.net_expense} />
        </StatTile>
        <StatTile label={t('analytics.measure.net')} note={netMeaning}>
          <MoneyText money={total.net_cash_flow} signDisplay="exceptZero" />
        </StatTile>
        <StatTile
          label={t('analytics.cashFlow.savingsRate')}
          note={
            total.savings_rate_bp === undefined
              ? t('analytics.cashFlow.noIncome')
              : previous?.savings_rate_bp !== undefined
                ? t('analytics.cashFlow.previous', {
                    amount: formatBasisPoints(previous.savings_rate_bp, formatLocale),
                  })
                : null
          }
        >
          {total.savings_rate_bp === undefined
            ? '—'
            : formatBasisPoints(total.savings_rate_bp, formatLocale)}
        </StatTile>
      </dl>
      <p className="text-sm text-fg-muted">
        {t('analytics.cashFlow.detail', {
          gross: format(total.gross_expense),
          refunds: format(total.refunds),
          count: total.transaction_count,
        })}
      </p>
    </>
  );
}

/** Income, spending, net cash flow and savings rate per currency, over time (spec §4.11). */
export function CashFlowView({ filters, onChange, enabled }: ViewProps) {
  const { t, formatLocale } = useI18n();
  const query = cashFlowQuery(filters);
  const report = useCashFlow(query, enabled);
  const fresh = report.isSuccess && !report.isPlaceholderData ? report.data : null;
  useAnnounceSettled(
    fresh ? JSON.stringify(query) : null,
    fresh
      ? t('analytics.updated', {
          period: formatLocalDateRange(fresh.window.from, fresh.window.to, formatLocale),
        })
      : '',
  );

  let content;
  if (report.isPending) {
    content = (
      <LoadingState label={t('analytics.loading')}>
        <div className="grid gap-6" aria-hidden="true">
          <Skeleton className="h-40 w-full" />
          <Skeleton className="h-72 w-full" />
        </div>
      </LoadingState>
    );
  } else if (!report.data) {
    content = (
      <Card>
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
  } else {
    const data = report.data;
    const totals = activeTotals(data.totals);
    const previous = new Map(data.previous_period.map((total) => [total.currency, total]));
    const series = pointsByCurrency(data.series);
    // The dates of the previous-period figures, as the API resolved them.
    const before = data.previous_window;
    const body =
      totals.length === 0 ? (
        <Card
          title={t('analytics.cashFlow.title')}
          description={<WindowText window={data.window} />}
        >
          <EmptyState
            icon="line-chart"
            title={t('analytics.empty.title')}
            description={t('analytics.empty.body')}
            action={
              <ButtonLink to={paths.transactionNew} variant="secondary">
                <Icon name="plus" className="size-4" />
                {t('transactions.add')}
              </ButtonLink>
            }
          />
        </Card>
      ) : (
        <Refreshing
          fetching={report.isFetching}
          stale={report.isPlaceholderData}
          className="grid gap-6"
        >
          <Card
            title={t('analytics.cashFlow.title')}
            description={
              <>
                <WindowText window={data.window} />
                {' · '}
                {t('analytics.cashFlow.previousWindow', {
                  period: formatLocalDateRange(before.from, before.to, formatLocale),
                })}
              </>
            }
            actions={
              <ButtonLink
                to={transactionsLink(data.window, filters, { type: CASH_FLOW_TYPES })}
                variant="ghost"
                size="sm"
              >
                {t('analytics.viewTransactions')}
                <Icon name="arrow-right" className="size-4" />
              </ButtonLink>
            }
          >
            <div className="space-y-10">
              {totals.map((total) => (
                <CurrencySection
                  key={total.currency}
                  currency={total.currency}
                  showHeading={totals.length > 1}
                >
                  <CashFlowStats total={total} previous={previous.get(total.currency)} />
                  <TrendChart
                    label={t('analytics.cashFlow.chartLabel', { currency: total.currency })}
                    currency={total.currency}
                    points={series.get(total.currency) ?? []}
                    granularity={data.series_granularity}
                    measures={['income', 'spending']}
                  />
                </CurrencySection>
              ))}
            </div>
          </Card>
          {data.converted ? (
            <ConvertedTotalsCard converted={data.converted} totals={totals} window={data.window} />
          ) : null}
          <CoverageCard coverage={data.coverage} window={data.window} filters={filters} />
        </Refreshing>
      );
    content = (
      <>
        {report.isError ? (
          <RefreshFailed
            message={t('analytics.stale.figures')}
            retrying={report.isFetching}
            onRetry={() => {
              void report.refetch();
            }}
          />
        ) : null}
        {body}
      </>
    );
  }

  return (
    <>
      <ViewOptions label={t('analytics.options.label')}>
        <GroupBySelect filters={filters} onChange={onChange} />
        <DisplayCurrencySelect filters={filters} onChange={onChange} />
      </ViewOptions>
      {content}
    </>
  );
}
