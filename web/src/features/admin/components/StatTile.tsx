import type { ReactNode } from 'react';

interface StatTileProps {
  label: string;
  value: ReactNode;
  /** A short qualifier under the value (what it counts, or its window). */
  detail?: ReactNode;
}

/** One headline number. Proportional figures: a lone large number reads better without tabular digits. */
export function StatTile({ label, value, detail }: StatTileProps) {
  return (
    <div className="rounded-lg border border-line bg-surface p-4">
      <dt className="text-sm font-medium text-fg-muted">{label}</dt>
      <dd className="mt-1">
        <span className="block text-2xl font-semibold text-fg">{value}</span>
        {detail ? <span className="mt-1 block text-xs text-fg-muted">{detail}</span> : null}
      </dd>
    </div>
  );
}
