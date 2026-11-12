import type { ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';

/**
 * A description list of label/value pairs. Labels sit beside values only when
 * the list itself is wide enough (container query), so narrow side cards stack.
 */
export function Facts({ children, className }: { children: ReactNode; className?: string }) {
  return <dl className={cx('@container divide-y divide-line', className)}>{children}</dl>;
}

export function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="grid gap-1 py-3 first:pt-0 last:pb-0 @md:grid-cols-3 @md:gap-4">
      <dt className="text-sm font-medium text-fg-muted">{label}</dt>
      <dd className="min-w-0 break-words text-fg @md:col-span-2">{children}</dd>
    </div>
  );
}
