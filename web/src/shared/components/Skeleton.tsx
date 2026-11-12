import { cx } from '@/shared/utils/cx';

/** Decorative placeholder shape; pair with a labelled loading region. */
export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      aria-hidden="true"
      className={cx(
        'animate-pulse rounded-md bg-surface-muted motion-reduce:animate-none',
        className,
      )}
    />
  );
}
