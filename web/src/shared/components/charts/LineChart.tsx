import { useT } from '@/shared/i18n/I18nContext';
import { linearScale, visibleLabelIndexes } from './scale';
import { useElementWidth } from './useElementWidth';

export interface LinePoint {
  /** Value in integer minor units (geometry only). */
  value: number;
  /** The exact, formatted value (for the hover title). */
  valueText: string;
}

export interface LineSeries {
  key: string;
  label: string;
  /** Tailwind stroke/fill classes for the series color, e.g. `stroke-chart-1`. */
  strokeClass: string;
  fillClass: string;
  points: readonly LinePoint[];
}

interface LineChartProps {
  series: readonly LineSeries[];
  /** One label per x position (formatted dates), shared by all series. */
  xLabels: readonly string[];
  formatTick: (value: number) => string;
  height?: number;
}

const MARGIN = { top: 12, right: 16, bottom: 28, left: 72 };
const FALLBACK_WIDTH = 640;

/**
 * Line chart for change over time: 2px lines, 8px markers with a surface
 * ring, hairline gridlines, one y axis. Decorative for assistive tech; the
 * surrounding ChartFrame provides the summary and the table view.
 */
export function LineChart({ series, xLabels, formatTick, height = 220 }: LineChartProps) {
  const t = useT();
  const [ref, measured] = useElementWidth();
  const width = measured > 0 ? measured : FALLBACK_WIDTH;
  const plotWidth = Math.max(1, width - MARGIN.left - MARGIN.right);
  const plotHeight = height - MARGIN.top - MARGIN.bottom;
  const count = xLabels.length;
  const scale = linearScale(series.flatMap((item) => item.points.map((point) => point.value)));
  const x = (index: number) =>
    MARGIN.left + (count <= 1 ? plotWidth / 2 : (index * plotWidth) / (count - 1));
  const y = (value: number) =>
    MARGIN.top + plotHeight * (1 - (value - scale.min) / (scale.max - scale.min));
  const labelIndexes = visibleLabelIndexes(xLabels, plotWidth);
  // Dense series show only the latest marker; every point keeps a hover target.
  const showMarkers = count <= 16;

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
        {labelIndexes.map((index) => (
          <text
            key={index}
            x={x(index)}
            y={height - 8}
            textAnchor={
              count <= 1 ? 'middle' : index === 0 ? 'start' : index === count - 1 ? 'end' : 'middle'
            }
            className="fill-fg-muted text-xs"
          >
            {xLabels[index]}
          </text>
        ))}
        {series.map((item) => {
          const path = item.points
            .map(
              (point, index) =>
                `${index === 0 ? 'M' : 'L'}${x(index).toFixed(1)},${y(point.value).toFixed(1)}`,
            )
            .join(' ');
          return (
            <g key={item.key}>
              {item.points.length > 1 ? (
                <path
                  d={path}
                  fill="none"
                  strokeWidth={2}
                  strokeLinejoin="round"
                  strokeLinecap="round"
                  className={item.strokeClass}
                />
              ) : null}
              {item.points.map((point, index) => (
                <g key={index}>
                  {showMarkers || index === item.points.length - 1 ? (
                    <circle
                      cx={x(index)}
                      cy={y(point.value)}
                      r={4}
                      strokeWidth={2}
                      className={`${item.fillClass} stroke-surface`}
                    />
                  ) : null}
                  {/* Larger transparent hit area carrying the hover title. */}
                  <circle cx={x(index)} cy={y(point.value)} r={12} fill="transparent">
                    <title>
                      {t('charts.pointTitle', {
                        series: item.label,
                        label: xLabels[index] ?? '',
                        value: point.valueText,
                      })}
                    </title>
                  </circle>
                </g>
              ))}
            </g>
          );
        })}
      </svg>
    </div>
  );
}
