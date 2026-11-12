import { useT } from '@/shared/i18n/I18nContext';
import { linearScale, visibleLabelIndexes } from './scale';
import { useElementWidth } from './useElementWidth';

export interface ColumnSeries {
  key: string;
  label: string;
  /** Tailwind fill class for the series color, e.g. `fill-chart-1`. */
  fillClass: string;
  /** One value per bucket, in integer minor units (geometry only). */
  values: readonly number[];
  /** The exact formatted value per bucket (hover title). */
  valueTexts: readonly string[];
}

interface ColumnChartProps {
  series: readonly ColumnSeries[];
  /** One label per bucket (the API's buckets; empty periods are not invented). */
  xLabels: readonly string[];
  formatTick: (value: number) => string;
  height?: number;
}

const MARGIN = { top: 12, right: 8, bottom: 28, left: 64 };
const FALLBACK_WIDTH = 640;
const MAX_BAR = 24;
const GAP = 2;
const RADIUS = 4;

/** A column with a 4px rounded data end and a square end on the baseline. */
function columnPath(x: number, width: number, from: number, to: number): string {
  const top = Math.min(from, to);
  const bottom = Math.max(from, to);
  const height = bottom - top;
  if (height <= 0) return '';
  const r = Math.min(RADIUS, height, width / 2);
  if (to <= from) {
    // Upward column: rounded top.
    return `M${x},${bottom}V${top + r}Q${x},${top} ${x + r},${top}H${x + width - r}Q${x + width},${top} ${x + width},${top + r}V${bottom}Z`;
  }
  // Downward column (a negative value): rounded bottom.
  return `M${x},${top}V${bottom - r}Q${x},${bottom} ${x + r},${bottom}H${x + width - r}Q${x + width},${bottom} ${x + width},${bottom - r}V${top}Z`;
}

/**
 * Grouped columns per period bucket, one y axis, hairline grid. Decorative
 * for assistive tech: the surrounding ChartFrame carries the summary and the
 * table; each bucket's hover title lists every series.
 */
export function ColumnChart({ series, xLabels, formatTick, height = 220 }: ColumnChartProps) {
  const t = useT();
  const [ref, measured] = useElementWidth();
  const width = measured > 0 ? measured : FALLBACK_WIDTH;
  const plotWidth = Math.max(1, width - MARGIN.left - MARGIN.right);
  const plotHeight = height - MARGIN.top - MARGIN.bottom;
  const count = Math.max(1, xLabels.length);
  const scale = linearScale(series.flatMap((item) => item.values));
  const y = (value: number) =>
    MARGIN.top + plotHeight * (1 - (value - scale.min) / (scale.max - scale.min));
  const band = plotWidth / count;
  const barWidth = Math.max(
    2,
    Math.min(MAX_BAR, (band * 0.7 - GAP * (series.length - 1)) / Math.max(1, series.length)),
  );
  const groupWidth = barWidth * series.length + GAP * (series.length - 1);
  const labels = visibleLabelIndexes(xLabels, plotWidth);

  return (
    <div ref={ref} className="w-full">
      <svg
        width={width}
        height={height}
        aria-hidden="true"
        focusable="false"
        className="block max-w-full overflow-visible"
      >
        {scale.ticks.map((tick) => (
          <g key={tick}>
            <line
              x1={MARGIN.left}
              x2={width - MARGIN.right}
              y1={y(tick)}
              y2={y(tick)}
              strokeWidth={1}
              className={tick === 0 ? 'stroke-line-strong' : 'stroke-line'}
            />
            <text
              x={MARGIN.left - 8}
              y={y(tick)}
              dy="0.32em"
              textAnchor="end"
              className="fill-fg-muted text-xs tabular-nums"
            >
              {formatTick(tick)}
            </text>
          </g>
        ))}
        {xLabels.map((label, index) => {
          const start = MARGIN.left + index * band + (band - groupWidth) / 2;
          return (
            <g key={label + String(index)}>
              {series.map((item, position) => (
                <path
                  key={item.key}
                  d={columnPath(
                    start + position * (barWidth + GAP),
                    barWidth,
                    y(0),
                    y(item.values[index] ?? 0),
                  )}
                  className={item.fillClass}
                />
              ))}
              <rect
                x={MARGIN.left + index * band}
                y={MARGIN.top}
                width={band}
                height={plotHeight}
                fill="transparent"
              >
                <title>
                  {[
                    label,
                    ...series.map((item) =>
                      t('charts.seriesValue', {
                        series: item.label,
                        value: item.valueTexts[index] ?? '',
                      }),
                    ),
                  ].join('\n')}
                </title>
              </rect>
              {labels.includes(index) ? (
                <text
                  x={MARGIN.left + index * band + band / 2}
                  y={height - 8}
                  textAnchor="middle"
                  className="fill-fg-muted text-xs"
                >
                  {label}
                </text>
              ) : null}
            </g>
          );
        })}
      </svg>
    </div>
  );
}
