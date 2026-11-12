import { cx } from '@/shared/utils/cx';

interface SpinnerProps {
  /** Announced to assistive tech; omit when the surrounding text already explains the wait. */
  label?: string;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

const sizes = { sm: 'size-4', md: 'size-6', lg: 'size-10' } as const;

export function Spinner({ label, size = 'md', className }: SpinnerProps) {
  const circle = (
    <svg
      viewBox="0 0 24 24"
      className={cx(sizes[size], 'animate-spin motion-reduce:animate-none', className)}
      aria-hidden="true"
      focusable="false"
    >
      <circle
        cx="12"
        cy="12"
        r="9"
        fill="none"
        stroke="currentColor"
        strokeOpacity="0.25"
        strokeWidth="3"
      />
      <path
        d="M21 12a9 9 0 0 0-9-9"
        fill="none"
        stroke="currentColor"
        strokeWidth="3"
        strokeLinecap="round"
      />
    </svg>
  );
  if (!label) return circle;
  return (
    <span role="status" className="inline-flex items-center gap-2">
      {circle}
      <span className="sr-only">{label}</span>
    </span>
  );
}
