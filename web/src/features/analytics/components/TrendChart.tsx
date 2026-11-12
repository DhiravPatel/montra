import { ChartFrame, ChartLegend, ChartTable } from '@/shared/components/charts/ChartFrame';
import { ColumnChart } from '@/shared/components/charts/ColumnChart';
import { axisDateLabels, formatAxisMoney } from '@/shared/components/charts/scale';
import { MoneyText } from '@/shared/components/MoneyText';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { bucketDate, bucketLabel, type Measure, measureMoney, peakPoint } from '../trend';
import type { Granularity, SeriesPoint } from '../types';

const measureLabel: Readonly<Record<Measure, MessageKey>> = {
  income: 'analytics.measure.income',
  spending: 'analytics.measure.spending',
};

/** Income keeps the first series color and spending the second, on every chart. */
const measureColor: Readonly<Record<Measure, { fill: string; swatch: string }>> = {
  income: { fill: 'fill-chart-1', swatch: 'bg-chart-1' },
  spending: { fill: 'fill-chart-2', swatch: 'bg-chart-2' },
};

const peakKey: Readonly<Record<Measure, MessageKey>> = {
  income: 'analytics.trend.peakIncome',
  spending: 'analytics.trend.peakSpending',
};

const rangeKey: Readonly<Record<Granularity, MessageKey>> = {
  day: 'analytics.trend.range.day',
  week: 'analytics.trend.range.week',
  month: 'analytics.trend.range.month',
  year: 'analytics.trend.range.year',
};

interface TrendChartProps {
  /** Accessible name of the figure, e.g. "Income and spending over time in INR". */
  label: string;
  currency: string;
  /** One currency's buckets, oldest first, exactly as the API returned them. */
  points: readonly SeriesPoint[];
  granularity: Granularity;
  measures: readonly Measure[];
}

/**
 * Income and/or spending per period bucket for one currency. The chart is
 * decorative for assistive tech: the summary sentence and the data table
 * carry every value (amounts formatted from the API's exact strings).
 */
export function TrendChart({ label, currency, points, granularity, measures }: TrendChartProps) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const currencies = useCurrencies();
  const exponent = exponentFor(currencies.data, currency);
  const first = points[0];
  const last = points[points.length - 1];
  const peaks = measures.flatMap((measure) => {
    const peak = peakPoint(points, measure);
    return peak
      ? [
          t(peakKey[measure], {
            amount: format(measureMoney(peak, measure)),
            period: bucketLabel(peak.bucket, granularity, formatLocale, t),
          }),
        ]
      : [];
  });
  const both = measures.length > 1;

  return (
    <ChartFrame
      label={label}
      summary={
        <p>
          {first && last
            ? t(rangeKey[granularity], {
                from: bucketDate(first.bucket, granularity, formatLocale),
                to: bucketDate(last.bucket, granularity, formatLocale),
              })
            : null}{' '}
          {peaks.join(' ')}
        </p>
      }
      legend={
        both ? (
          <ChartLegend
            items={measures.map((measure) => ({
              key: measure,
              label: t(measureLabel[measure]),
              swatchClass: measureColor[measure].swatch,
            }))}
          />
        ) : undefined
      }
      table={
        <ChartTable
          caption={label}
          columns={[
            t('charts.period'),
            ...measures.map((measure) => t(measureLabel[measure])),
            ...(both ? [t('analytics.measure.net')] : []),
          ]}
          rows={points.map((point) => ({
            key: point.bucket,
            cells: [
              bucketLabel(point.bucket, granularity, formatLocale, t),
              ...measures.map((measure) => (
                <MoneyText key={measure} money={measureMoney(point, measure)} />
              )),
              ...(both ? [<MoneyText key="net" money={point.net} signDisplay="exceptZero" />] : []),
            ],
          }))}
        />
      }
    >
      <ColumnChart
        series={measures.map((measure) => ({
          key: measure,
          label: t(measureLabel[measure]),
          fillClass: measureColor[measure].fill,
          values: points.map((point) => measureMoney(point, measure).amount_minor),
          valueTexts: points.map((point) => format(measureMoney(point, measure))),
        }))}
        xLabels={axisDateLabels(
          points.map((point) => point.bucket),
          formatLocale,
          granularity,
        )}
        formatTick={(value) => formatAxisMoney(value, currency, exponent, formatLocale)}
      />
    </ChartFrame>
  );
}
