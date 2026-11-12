import { useState } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { ChartFrame, ChartTable } from '@/shared/components/charts/ChartFrame';
import { LineChart } from '@/shared/components/charts/LineChart';
import { axisDateLabels, formatAxisMoney } from '@/shared/components/charts/scale';
import { MoneyText } from '@/shared/components/MoneyText';
import { Select } from '@/shared/components/Select';
import { Skeleton } from '@/shared/components/Skeleton';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import type { Account } from '@/shared/finance/types';
import { addDaysToLocalDate, formatLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { formatMoney } from '@/shared/formatting/money';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useBalanceHistory } from '../api';

const PERIODS = [30, 90, 365] as const;
type Period = (typeof PERIODS)[number];

function isPeriod(value: number): value is Period {
  return (PERIODS as readonly number[]).includes(value);
}

/** Daily tracked balance from the ledger (GET /accounts/{id}/balance?from=). */
export function BalanceHistoryCard({ account }: { account: Account }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const currencies = useCurrencies();
  const [days, setDays] = useState<Period>(30);
  const [today] = useState(() => todayInTimeZone(user.timezone));
  const from = addDaysToLocalDate(today, -(days - 1));
  const history = useBalanceHistory(account.id, from, today);
  const exponent = exponentFor(currencies.data, account.currency);
  const format = (amount: string) => {
    try {
      return formatMoney(amount, account.currency, formatLocale);
    } catch {
      return `${amount} ${account.currency}`;
    }
  };

  let content;
  if (history.isPending) {
    content = (
      <LoadingState label={t('accounts.history.loading')}>
        <Skeleton className="h-52 w-full" />
      </LoadingState>
    );
  } else if (history.isError) {
    content = (
      <ErrorState
        title={t('accounts.history.error')}
        error={history.error}
        retrying={history.isFetching}
        onRetry={() => {
          void history.refetch();
        }}
      />
    );
  } else {
    const points = history.data.history;
    const first = points[0];
    const last = points[points.length - 1];
    const summary =
      first && last ? (
        <p>
          {t('accounts.history.summary', {
            from: formatLocalDate(first.date, formatLocale, 'long'),
            start: format(first.balance.amount),
            to: formatLocalDate(last.date, formatLocale, 'long'),
            end: format(last.balance.amount),
          })}
          {account.is_liability ? ` ${t('accounts.history.liabilityNote')}` : null}
        </p>
      ) : (
        <p>{t('accounts.history.none')}</p>
      );
    content = (
      <ChartFrame
        label={t('accounts.history.chartLabel')}
        summary={summary}
        table={
          <div className="max-h-80 overflow-y-auto">
            <ChartTable
              caption={t('accounts.history.chartLabel')}
              columns={[t('charts.date'), t('accounts.history.balance')]}
              rows={[...points].reverse().map((point) => ({
                key: point.date,
                cells: [
                  formatLocalDate(point.date, formatLocale),
                  <MoneyText key="balance" money={point.balance} />,
                ],
              }))}
            />
          </div>
        }
      >
        <LineChart
          series={[
            {
              key: 'balance',
              label: t('accounts.history.balance'),
              strokeClass: 'stroke-chart-1',
              fillClass: 'fill-chart-1',
              points: points.map((point) => ({
                value: point.balance.amount_minor,
                valueText: format(point.balance.amount),
              })),
            },
          ]}
          xLabels={axisDateLabels(
            points.map((point) => point.date),
            formatLocale,
          )}
          formatTick={(value) => formatAxisMoney(value, account.currency, exponent, formatLocale)}
        />
      </ChartFrame>
    );
  }

  return (
    <Card
      title={t('accounts.history.title')}
      description={t('accounts.history.description')}
      actions={
        <Select
          label={t('accounts.history.period')}
          hideLabel
          value={String(days)}
          options={PERIODS.map((period) => ({
            value: String(period),
            label: t('accounts.history.days', { count: period }),
          }))}
          onChange={(event) => {
            const next = Number(event.target.value);
            if (isPeriod(next)) setDays(next);
          }}
        />
      }
    >
      {content}
    </Card>
  );
}
