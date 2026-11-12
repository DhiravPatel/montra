import { useMutation } from '@tanstack/react-query';
import { type SyntheticEvent, useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { BarList } from '@/shared/components/charts/BarList';
import { ChartFrame, ChartTable } from '@/shared/components/charts/ChartFrame';
import { ColumnChart } from '@/shared/components/charts/ColumnChart';
import { axisDateLabels, formatAxisMoney } from '@/shared/components/charts/scale';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import {
  formatLocalDate,
  isLocalDate,
  parseLocalDate,
  todayInTimeZone,
} from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { groupMoneyApi, useGroupReport } from '../api';
import { GroupMoneyPage } from '../components/GroupMoneyPage';
import { fallbackExportName, saveCsvFile } from '../download';
import { categoryKeyName } from '../labels';
import { type People, byCurrency, usePeople } from '../people';
import type { GroupDetail, GroupReport } from '../types';

export function GroupReportsPage() {
  const { t } = useI18n();
  const { groupId = '' } = useParams();
  useDocumentTitle(t('groupMoney.reports.title'));
  return (
    <GroupMoneyPage groupId={groupId} title={t('groupMoney.reports.title')}>
      {(group) => <Reports group={group} />}
    </GroupMoneyPage>
  );
}

function monthName(month: string, locale: string): string {
  const date = parseLocalDate(`${month}-01`);
  if (!date) return month;
  return new Intl.DateTimeFormat(locale, {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(date);
}

function Reports({ group }: { group: GroupDetail }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const people = usePeople(group);
  const [draft, setDraft] = useState({ from: '', to: '' });
  const [range, setRange] = useState({ from: '', to: '' });
  const [rangeError, setRangeError] = useState<string | null>(null);
  const report = useGroupReport(group.id, range.from, range.to);
  const exportCsv = useMutation({ mutationFn: () => groupMoneyApi.exportCsv(group.id) });

  const apply = (event: SyntheticEvent) => {
    event.preventDefault();
    if ((draft.from && !isLocalDate(draft.from)) || (draft.to && !isLocalDate(draft.to))) {
      setRangeError(t('validation.dateInvalid'));
      return;
    }
    if (draft.from && draft.to && draft.to < draft.from) {
      setRangeError(t('validation.dateOrder'));
      return;
    }
    setRangeError(null);
    setRange(draft);
  };

  const download = () => {
    if (exportCsv.isPending) return;
    exportCsv.mutate(undefined, {
      onSuccess: ({ csv, fileName }) => {
        saveCsvFile(fileName ?? fallbackExportName(todayInTimeZone(group.timezone)), csv);
        toast.show({ tone: 'success', title: t('groupMoney.reports.exportStarted') });
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('groupMoney.reports.exportFailed'),
          description: describeError(error, t),
        });
      },
    });
  };

  let content;
  if (report.isPending) {
    content = <LoadingState label={t('groupMoney.reports.loading')} />;
  } else if (report.isError) {
    content = hasErrorCode(report.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('groupMoney.reports.error')}
        error={report.error}
        retrying={report.isFetching}
        onRetry={() => {
          void report.refetch();
        }}
      />
    );
  } else if (report.data.expense_count === 0) {
    content = (
      <Card>
        <EmptyState
          icon="bar-chart"
          title={t('groupMoney.reports.empty.title')}
          description={
            range.from || range.to
              ? t('groupMoney.reports.empty.range')
              : t('groupMoney.reports.empty.body')
          }
        />
      </Card>
    );
  } else {
    content = <ReportBody report={report.data} people={people} />;
  }

  return (
    <div className="space-y-6">
      <Card
        title={t('groupMoney.reports.period')}
        description={
          range.from || range.to
            ? t('groupMoney.reports.periodRange', {
                from: range.from ? formatLocalDate(range.from, formatLocale) : '…',
                to: range.to ? formatLocalDate(range.to, formatLocale) : '…',
              })
            : t('groupMoney.reports.periodAll')
        }
        actions={
          <Button variant="secondary" size="sm" loading={exportCsv.isPending} onClick={download}>
            <Icon name="download" className="size-4" />
            {t('groupMoney.reports.export')}
          </Button>
        }
      >
        <form noValidate onSubmit={apply} className="flex flex-wrap items-end gap-4">
          <TextField
            label={t('finance.range.from')}
            type="date"
            value={draft.from}
            className="min-w-40"
            onChange={(event) => {
              setDraft((current) => ({ ...current, from: event.target.value }));
            }}
          />
          <TextField
            label={t('finance.range.to')}
            type="date"
            value={draft.to}
            className="min-w-40"
            error={rangeError ?? undefined}
            onChange={(event) => {
              setDraft((current) => ({ ...current, to: event.target.value }));
            }}
          />
          <Button type="submit" variant="secondary">
            {t('common.apply')}
          </Button>
          {range.from || range.to ? (
            <Button
              variant="ghost"
              onClick={() => {
                setDraft({ from: '', to: '' });
                setRange({ from: '', to: '' });
                setRangeError(null);
              }}
            >
              {t('groupMoney.reports.allTime')}
            </Button>
          ) : null}
        </form>
        <p className="mt-4 text-sm text-fg-muted">{t('groupMoney.reports.exportHelp')}</p>
      </Card>
      {content}
    </div>
  );
}

function ReportBody({ report, people }: { report: GroupReport; people: People }) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const currencies = useCurrencies();
  const exponent = (code: string) => exponentFor(currencies.data, code);

  return (
    <div className="space-y-6">
      <Card title={t('groupMoney.reports.summary')}>
        <Facts>
          <Fact label={t('groupMoney.reports.total')}>
            <MoneyText money={report.total_spent} className="font-semibold" />
          </Fact>
          <Fact label={t('groupMoney.reports.expenses')}>
            {t('groupMoney.reports.expenseCount', { count: report.expense_count })}
            {report.disputed_count > 0 ? (
              <span className="block text-sm text-fg-muted">
                {t('groupMoney.reports.disputedCount', { count: report.disputed_count })}
              </span>
            ) : null}
          </Fact>
          <Fact label={t('groupMoney.reports.perPerson')}>
            <MoneyText money={report.per_person_average} />
            <span className="block text-sm text-fg-muted">
              {t('groupMoney.reports.perPersonHelp', { count: report.participant_count })}
            </span>
          </Fact>
          <Fact label={t('groupMoney.reports.youPaid')}>
            <MoneyText money={report.my_paid} />
          </Fact>
          <Fact label={t('groupMoney.reports.yourShare')}>
            <MoneyText money={report.my_share} />
          </Fact>
          {report.trip ? (
            <Fact label={t('groupMoney.reports.trip')}>
              {t('groupMoney.reports.tripDays', { count: report.trip.days })} ·{' '}
              {t('groupMoney.reports.dailyAverage')} <MoneyText money={report.trip.daily_average} />
              {report.trip.start_date && report.trip.end_date ? (
                <span className="block text-sm text-fg-muted">
                  {formatLocalDate(report.trip.start_date, formatLocale)} –{' '}
                  {formatLocalDate(report.trip.end_date, formatLocale)}
                </span>
              ) : null}
            </Fact>
          ) : null}
        </Facts>
      </Card>

      <Card title={t('groupMoney.reports.byCategory')}>
        <div className="space-y-8">
          {byCurrency(report.by_category, (row) => row.total.currency).map(([currency, rows]) => {
            const top = rows[0];
            const caption = t('groupMoney.reports.byCategoryIn', { currency });
            return (
              <section key={currency} aria-label={caption}>
                <ChartFrame
                  label={caption}
                  summary={
                    top ? (
                      <p>
                        {t('groupMoney.reports.categorySummary', {
                          name: categoryKeyName(top.category_key, t),
                          amount: format(top.total),
                          count: top.count,
                        })}
                      </p>
                    ) : null
                  }
                  table={
                    <ChartTable
                      caption={caption}
                      columns={[
                        t('groupMoney.form.category'),
                        t('groupMoney.reports.total'),
                        t('groupMoney.reports.expenses'),
                      ]}
                      rows={rows.map((row) => ({
                        key: row.category_key,
                        cells: [
                          categoryKeyName(row.category_key, t),
                          <MoneyText key="total" money={row.total} />,
                          row.count,
                        ],
                      }))}
                    />
                  }
                >
                  <BarList
                    rows={rows.map((row) => ({
                      key: row.category_key,
                      label: categoryKeyName(row.category_key, t),
                      valueText: <MoneyText money={row.total} />,
                      value: Math.max(0, row.total.amount_minor),
                      barClass: 'bg-chart-1',
                    }))}
                  />
                </ChartFrame>
              </section>
            );
          })}
        </div>
      </Card>

      <Card
        title={t('groupMoney.reports.byPerson')}
        description={t('groupMoney.reports.byPersonBody')}
      >
        <div className="space-y-8">
          {byCurrency(report.by_member, (row) => row.share.currency).map(([currency, rows]) => {
            const caption = t('groupMoney.reports.byPersonIn', { currency });
            return (
              <section key={currency} aria-label={caption}>
                <ChartFrame
                  label={caption}
                  summary={<p>{t('groupMoney.reports.personSummary')}</p>}
                  table={
                    <ChartTable
                      caption={caption}
                      columns={[
                        t('groupMoney.breakdown.person'),
                        t('groupMoney.balances.paid'),
                        t('groupMoney.balances.share'),
                      ]}
                      rows={rows.map((row) => ({
                        key: row.user_id,
                        cells: [
                          people.name(row.user_id, row.display_name),
                          <MoneyText key="paid" money={row.paid} />,
                          <MoneyText key="share" money={row.share} />,
                        ],
                      }))}
                    />
                  }
                >
                  <BarList
                    rows={rows.map((row) => ({
                      key: row.user_id,
                      label: people.name(row.user_id, row.display_name),
                      valueText: (
                        <>
                          <MoneyText money={row.share} />{' '}
                          <span className="font-normal text-fg-muted">
                            {t('groupMoney.reports.paidInline', { amount: format(row.paid) })}
                          </span>
                        </>
                      ),
                      value: Math.max(0, row.share.amount_minor),
                      barClass: 'bg-chart-1',
                    }))}
                  />
                </ChartFrame>
              </section>
            );
          })}
        </div>
      </Card>

      <Card title={t('groupMoney.reports.byMonth')}>
        <div className="space-y-8">
          {byCurrency(report.by_month, (row) => row.total.currency).map(([currency, rows]) => {
            const caption = t('groupMoney.reports.byMonthIn', { currency });
            const table = (
              <ChartTable
                caption={caption}
                columns={[
                  t('charts.period'),
                  t('groupMoney.reports.total'),
                  t('groupMoney.reports.expenses'),
                ]}
                rows={rows.map((row) => ({
                  key: row.month,
                  cells: [
                    monthName(row.month, formatLocale),
                    <MoneyText key="total" money={row.total} />,
                    row.count,
                  ],
                }))}
              />
            );
            const first = rows[0];
            const last = rows[rows.length - 1];
            return (
              <section key={currency} aria-label={caption}>
                <ChartFrame
                  label={caption}
                  summary={
                    first && last ? (
                      <p>
                        {t('groupMoney.reports.monthSummary', {
                          from: monthName(first.month, formatLocale),
                          to: monthName(last.month, formatLocale),
                          count: rows.length,
                        })}
                      </p>
                    ) : null
                  }
                  table={table}
                >
                  <ColumnChart
                    series={[
                      {
                        key: 'spent',
                        label: t('groupMoney.reports.total'),
                        fillClass: 'fill-chart-1',
                        values: rows.map((row) => row.total.amount_minor),
                        valueTexts: rows.map((row) => format(row.total)),
                      },
                    ]}
                    xLabels={axisDateLabels(
                      rows.map((row) => `${row.month}-01`),
                      formatLocale,
                      'month',
                    )}
                    formatTick={(value) =>
                      formatAxisMoney(value, currency, exponent(currency), formatLocale)
                    }
                  />
                </ChartFrame>
              </section>
            );
          })}
        </div>
      </Card>

      {report.original_currencies.length > 0 ? (
        <Card
          title={t('groupMoney.reports.otherCurrencies')}
          description={t('groupMoney.reports.otherCurrenciesBody')}
        >
          <ChartTable
            caption={t('groupMoney.reports.otherCurrencies')}
            columns={[
              t('common.currency'),
              t('groupMoney.reports.paidInCurrency'),
              t('groupMoney.reports.inGroupCurrency', { currency: report.currency }),
              t('groupMoney.reports.expenses'),
            ]}
            rows={report.original_currencies.map((row) => ({
              key: row.currency,
              cells: [
                row.currency,
                <MoneyText key="original" money={row.original} />,
                <MoneyText key="converted" money={row.converted} />,
                row.count,
              ],
            }))}
          />
        </Card>
      ) : null}

      <Card
        title={t('groupMoney.reports.payments')}
        description={t('groupMoney.reports.paymentsBody')}
      >
        <Facts>
          <Fact label={t('groupMoney.reports.confirmed')}>
            <MoneyText money={report.settlements.confirmed} />
          </Fact>
          <Fact label={t('groupMoney.reports.pending')}>
            <MoneyText money={report.settlements.pending} />
          </Fact>
          <Fact label={t('groupMoney.reports.paymentCount')}>
            {t('groupMoney.reports.paymentsCount', { count: report.settlements.count })}
            {report.settlements.disputed > 0 ? (
              <span className="block text-sm text-fg-muted">
                {t('groupMoney.reports.paymentsDisputed', { count: report.settlements.disputed })}
              </span>
            ) : null}
          </Fact>
        </Facts>
      </Card>
    </div>
  );
}
