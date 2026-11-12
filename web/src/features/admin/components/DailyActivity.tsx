import { ChartFrame, ChartTable } from '@/shared/components/charts/ChartFrame';
import { LineChart } from '@/shared/components/charts/LineChart';
import { axisDateLabels } from '@/shared/components/charts/scale';
import { EmptyState } from '@/shared/components/states';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import type { DailyUsage, Usage } from '../types';

type Measure = 'new_users' | 'transactions' | 'emails_sent';

const MEASURES: readonly { key: Measure; label: MessageKey }[] = [
  { key: 'new_users', label: 'adminUsage.daily.newUsers' },
  { key: 'transactions', label: 'adminUsage.daily.transactions' },
  { key: 'emails_sent', label: 'adminUsage.daily.emailsSent' },
];

/**
 * The daily series as small multiples: the three counts differ by orders of
 * magnitude, so each gets its own chart and axis (never a dual axis). One
 * series per chart, named by its heading, in the first chart color. The
 * table view lists every day and every count.
 */
export function DailyActivity({ usage }: { usage: Usage }) {
  const { t, formatLocale } = useI18n();
  const days: readonly DailyUsage[] = usage.daily;
  if (days.length === 0) {
    return (
      <EmptyState
        icon="line-chart"
        title={t('adminUsage.daily.empty.title')}
        description={t('adminUsage.daily.empty.body')}
      />
    );
  }
  const numbers = new Intl.NumberFormat(formatLocale);
  const compact = new Intl.NumberFormat(formatLocale, {
    notation: 'compact',
    maximumFractionDigits: 1,
  });
  const xLabels = axisDateLabels(
    days.map((day) => day.date),
    formatLocale,
    'day',
  );
  const first = days[0];
  const last = days[days.length - 1];
  return (
    <ChartFrame
      label={t('adminUsage.daily.title')}
      summary={
        <p>
          {t('adminUsage.daily.summary', {
            from: first ? formatLocalDate(first.date, formatLocale) : '',
            to: last ? formatLocalDate(last.date, formatLocale) : '',
          })}
        </p>
      }
      table={
        <ChartTable
          caption={t('adminUsage.daily.title')}
          columns={[t('charts.date'), ...MEASURES.map((measure) => t(measure.label))]}
          rows={days.map((day) => ({
            key: day.date,
            cells: [
              formatLocalDate(day.date, formatLocale),
              ...MEASURES.map((measure) => numbers.format(day[measure.key])),
            ],
          }))}
        />
      }
    >
      {/* Stacked full width, so the three time axes line up for comparison. */}
      <div className="grid gap-6">
        {MEASURES.map((measure) => (
          <div key={measure.key} className="min-w-0">
            <h3 className="mb-2 text-sm font-semibold text-fg">{t(measure.label)}</h3>
            <LineChart
              height={150}
              xLabels={xLabels}
              formatTick={(value) => compact.format(value)}
              series={[
                {
                  key: measure.key,
                  label: t(measure.label),
                  strokeClass: 'stroke-chart-1',
                  fillClass: 'fill-chart-1',
                  points: days.map((day) => ({
                    value: day[measure.key],
                    valueText: numbers.format(day[measure.key]),
                  })),
                },
              ]}
            />
          </div>
        ))}
      </div>
    </ChartFrame>
  );
}
