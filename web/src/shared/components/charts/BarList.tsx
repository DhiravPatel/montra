import type { ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';
import { barPercent } from './scale';

export interface BarRow {
  key: string;
  label: ReactNode;
  valueText: ReactNode;
  /** Value in integer minor units (bar length only), >= 0. */
  value: number;
  /** Tailwind background class for the bar, e.g. `bg-chart-1`. */
  barClass: string;
  /** Optional comparison (e.g. the previous period), drawn thinner in a neutral color. */
  comparison?: { value: number; label: string; valueText: ReactNode; barClass: string };
}

/**
 * Horizontal bars on one baseline (ranked lists, period comparisons). The
 * names and values are real text; only the bars are decorative.
 */
export function BarList({ rows }: { rows: readonly BarRow[] }) {
  const max = Math.max(
    0,
    ...rows.flatMap((row) => [row.value, row.comparison ? row.comparison.value : 0]),
  );
  return (
    <ul className="space-y-4">
      {rows.map((row) => (
        <li key={row.key}>
          <div className="mb-1.5 flex flex-wrap items-baseline justify-between gap-x-3 text-sm">
            <span className="min-w-0 text-fg">{row.label}</span>
            <span className="shrink-0 font-medium tabular-nums text-fg">{row.valueText}</span>
          </div>
          <div aria-hidden="true" className="space-y-1">
            <div
              className={cx('h-3 rounded-e', row.barClass)}
              style={{ width: barPercent(row.value, max) }}
            />
            {row.comparison ? (
              <div
                className={cx('h-1.5 rounded-e', row.comparison.barClass)}
                style={{ width: barPercent(row.comparison.value, max) }}
              />
            ) : null}
          </div>
          {row.comparison ? (
            <p className="mt-1 text-xs text-fg-muted">
              {row.comparison.label}:{' '}
              <span className="tabular-nums">{row.comparison.valueText}</span>
            </p>
          ) : null}
        </li>
      ))}
    </ul>
  );
}
