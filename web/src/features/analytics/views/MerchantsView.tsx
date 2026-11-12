import { useState } from 'react';
import { Card } from '@/shared/components/Card';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, LoadingState } from '@/shared/components/states';
import { formatLocalDateRange } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { MERCHANT_LIMIT, useMerchants } from '../api';
import {
  CurrencySection,
  QueryError,
  RefreshFailed,
  Refreshing,
  WindowText,
} from '../components/Blocks';
import { RankedChart } from '../components/RankedChart';
import { ShowAllToggle } from '../components/ShowAllToggle';
import { groupByCurrency } from '../categoryNames';
import { baseQuery } from '../filters';
import { SPENDING_TYPES, transactionsLink } from '../links';
import { useAnnounceSettled } from '../useAnnounceSettled';
import type { ViewProps } from './CashFlowView';

const TOP = 10;

/** Where you spent the most (net of refunds), ranked per currency (spec §4.11). */
export function MerchantsView({ filters, enabled }: ViewProps) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const [showAll, setShowAll] = useState(false);
  // The API ranks across currencies before its limit, so ask for its maximum
  // and rank within each currency here (grouping only, nothing is added).
  const query = { ...baseQuery(filters), limit: MERCHANT_LIMIT };
  const report = useMerchants(query, enabled);
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
      <LoadingState label={t('analytics.loading')}>
        <Skeleton className="h-72 w-full" />
      </LoadingState>
    );
  }
  if (!report.data) {
    return (
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
  const groups = groupByCurrency(data.merchants);
  const longest = Math.max(0, ...groups.map(([, rows]) => rows.length));
  return (
    <Card
      title={t('analytics.merchants.title')}
      description={
        <>
          <WindowText window={data.window} /> · {t('analytics.merchants.description')}
        </>
      }
      actions={
        longest > TOP ? (
          <ShowAllToggle
            expanded={showAll}
            onToggle={() => {
              setShowAll((value) => !value);
            }}
            showAllLabel={t('analytics.merchants.showAll')}
            showFewerLabel={t('analytics.showFewer', { count: TOP })}
          />
        ) : null
      }
    >
      {staleNotice}
      {groups.length === 0 ? (
        <EmptyState
          icon="shopping-bag"
          title={t('analytics.merchants.empty')}
          description={t('analytics.merchants.emptyBody')}
        />
      ) : (
        <Refreshing fetching={report.isFetching} stale={report.isPlaceholderData}>
          <div className="space-y-10">
            {groups.map(([currency, merchants]) => {
              const visible = showAll ? merchants : merchants.slice(0, TOP);
              const top = merchants[0];
              return (
                <CurrencySection key={currency} currency={currency} showHeading={groups.length > 1}>
                  <RankedChart
                    label={t('analytics.merchants.chartLabel', { currency })}
                    summary={
                      top ? (
                        <p>
                          {t('analytics.merchants.summary', {
                            name: top.name,
                            amount: format(top.net_expense),
                            count: top.count,
                          })}
                          {visible.length < merchants.length
                            ? ` ${t('analytics.showingTop', { shown: visible.length, total: merchants.length })}`
                            : null}
                        </p>
                      ) : null
                    }
                    nameColumn={t('finance.merchant.label')}
                    amountColumn={t('analytics.measure.spending')}
                    rows={visible.map((merchant) => ({
                      key: merchant.merchant_id ?? merchant.name,
                      name: merchant.name,
                      to: transactionsLink(data.window, filters, {
                        merchant_id: merchant.merchant_id,
                        type: SPENDING_TYPES,
                      }),
                      amount: merchant.net_expense,
                      count: merchant.count,
                    }))}
                  />
                </CurrencySection>
              );
            })}
            {data.merchants.length >= MERCHANT_LIMIT ? (
              <p className="text-sm text-fg-muted">
                {t('analytics.merchants.limited', { count: MERCHANT_LIMIT })}
              </p>
            ) : null}
          </div>
        </Refreshing>
      )}
    </Card>
  );
}
