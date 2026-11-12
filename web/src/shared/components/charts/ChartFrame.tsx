import { type ReactNode, useId, useState } from 'react';
import { useT } from '@/shared/i18n/I18nContext';
import { Button } from '../Button';
import { Icon } from '../Icon';

interface ChartFrameProps {
  /** Accessible name of the figure (usually the widget title). */
  label: string;
  /** Plain-language description of what the chart shows, always visible. */
  summary: ReactNode;
  /** The same data as a table (the WCAG-clean equivalent). */
  table: ReactNode;
  legend?: ReactNode;
  /** The visual. Mark purely decorative parts aria-hidden inside it. */
  children: ReactNode;
}

/**
 * Wraps every chart: a visible text summary, an optional legend, and a
 * toggle between the chart and a data table, so no value depends on seeing
 * the chart, hovering, or telling colors apart.
 */
export function ChartFrame({ label, summary, table, legend, children }: ChartFrameProps) {
  const t = useT();
  const [showTable, setShowTable] = useState(false);
  const summaryId = useId();
  return (
    <figure aria-label={label} aria-describedby={summaryId} className="space-y-3">
      <div id={summaryId} className="text-sm text-fg-muted">
        {summary}
      </div>
      {legend && !showTable ? legend : null}
      {showTable ? <div className="overflow-x-auto">{table}</div> : children}
      <Button
        variant="ghost"
        size="sm"
        aria-pressed={showTable}
        onClick={() => {
          setShowTable((value) => !value);
        }}
      >
        <Icon name={showTable ? 'bar-chart' : 'table'} className="size-4" />
        {showTable ? t('charts.showChart') : t('charts.showTable')}
      </Button>
    </figure>
  );
}

export interface LegendItem {
  key: string;
  label: string;
  /** Tailwind background class for the swatch, e.g. `bg-chart-1`. */
  swatchClass: string;
  shape?: 'bar' | 'line';
}

/** Legend for two or more series: swatch shape plus text (text stays in text colors). */
export function ChartLegend({ items }: { items: readonly LegendItem[] }) {
  return (
    <ul className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-fg-muted" aria-hidden="true">
      {items.map((item) => (
        <li key={item.key} className="inline-flex items-center gap-2">
          <span
            className={
              item.shape === 'line'
                ? `inline-block h-0.5 w-4 rounded-full ${item.swatchClass}`
                : `inline-block size-3 rounded-sm ${item.swatchClass}`
            }
          />
          {item.label}
        </li>
      ))}
    </ul>
  );
}

/** A compact, accessible data table used as every chart's table view. */
export function ChartTable({
  caption,
  columns,
  rows,
}: {
  caption: string;
  columns: readonly string[];
  rows: readonly { key: string; cells: readonly ReactNode[] }[];
}) {
  return (
    <table className="w-full min-w-max border-collapse text-sm">
      <caption className="sr-only">{caption}</caption>
      <thead>
        <tr className="border-b border-line text-start">
          {columns.map((column, index) => (
            <th
              key={column}
              scope="col"
              className={`py-2 pe-4 font-medium text-fg-muted ${index === 0 ? 'text-start' : 'text-end'}`}
            >
              {column}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((row) => (
          <tr key={row.key} className="border-b border-line last:border-b-0">
            {row.cells.map((cell, index) =>
              index === 0 ? (
                <th key={index} scope="row" className="py-2 pe-4 text-start font-normal text-fg">
                  {cell}
                </th>
              ) : (
                <td key={index} className="py-2 pe-4 text-end tabular-nums text-fg">
                  {cell}
                </td>
              ),
            )}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
