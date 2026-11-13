import { useState } from 'react';
import { Card } from '@/shared/components/Card';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, LoadingState } from '@/shared/components/states';
import { formatBasisPoints, formatLocalDateRange } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { usePaymentMethodBreakdown } from '../api';
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
import { drillDownLink, paymentMethodName } from '../paymentMethods';
import { useAnnounceSettled } from '../useAnnounceSettled';
import type { ViewProps } from './CashFlowView';

const TOP = 10;

/** How spending was paid (net of refunds), ranked per currency (ANL-002). */
export function PaymentMethodsView({ filters, enabled }: ViewProps) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const [showAll, setShowAll] = useState(false);
  const query = baseQuery(filters);
  const report = usePaymentMethodBreakdown(query, enabled);
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
  // Each currency is its own ranking; amounts are never added across currencies.
  const groups = groupByCurrency(data.payment_methods);
  const longest = Math.max(0, ...groups.map(([, rows]) => rows.length));
  const hasUnspecified = data.payment_methods.some((slice) => !slice.payment_method_id);
  return (
    <Card
      title={t('analytics.paymentMethods.title')}
      description={
        <>
          <WindowText window={data.window} /> · {t('analytics.paymentMethods.description')}
        </>
      }
      actions={
        longest > TOP ? (
          <ShowAllToggle
            expanded={showAll}
            onToggle={() => {
              setShowAll((value) => !value);
            }}
            showAllLabel={t('analytics.paymentMethods.showAll')}
            showFewerLabel={t('analytics.showFewer', { count: TOP })}
          />
        ) : null
      }
    >
      {staleNotice}
      {groups.length === 0 ? (
        <EmptyState
          icon="credit-card"
          title={t('analytics.paymentMethods.empty')}
          description={t('analytics.paymentMethods.emptyBody')}
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
                    label={t('analytics.paymentMethods.chartLabel', { currency })}
                    summary={
                      top ? (
                        <p>
                          {t('analytics.paymentMethods.summary', {
                            name: paymentMethodName(top, t),
                            amount: format(top.net_expense),
                            share: formatBasisPoints(top.share_bp, formatLocale),
                            count: top.count,
                          })}
                          {visible.length < slices.length
                            ? ` ${t('analytics.showingTop', { shown: visible.length, total: slices.length })}`
                            : null}
                        </p>
                      ) : null
                    }
                    nameColumn={t('analytics.paymentMethods.column')}
                    amountColumn={t('analytics.measure.spending')}
                    rows={visible.map((slice) => ({
                      key: `${slice.currency}-${slice.key}`,
                      name: paymentMethodName(slice, t),
                      to: drillDownLink(slice, () =>
                        transactionsLink(data.window, filters, {
                          payment_method_id: slice.payment_method_id ?? 'none',
                          type: SPENDING_TYPES,
                        }),
                      ),
                      amount: slice.net_expense,
                      shareBp: slice.share_bp,
                      count: slice.count,
                    }))}
                  />
                </CurrencySection>
              );
            })}
            {hasUnspecified ? (
              <p className="text-sm text-fg-muted">
                {t('analytics.paymentMethods.unspecifiedNote')}
              </p>
            ) : null}
          </div>
        </Refreshing>
      )}
    </Card>
  );
}
