import { cx } from '@/shared/utils/cx';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'md' | 'sm';

const base =
  'inline-flex items-center justify-center gap-2 rounded-md border font-medium whitespace-nowrap select-none ' +
  'transition-colors motion-reduce:transition-none ' +
  'disabled:cursor-not-allowed disabled:opacity-60 aria-disabled:cursor-not-allowed aria-disabled:opacity-70';

const sizes: Record<ButtonSize, string> = {
  md: 'min-h-11 px-4 py-2 text-sm',
  sm: 'min-h-9 px-3 py-1.5 text-sm',
};

// A transparent border keeps buttons visible in Windows forced-colors mode.
const variants: Record<ButtonVariant, string> = {
  primary: 'border-transparent bg-accent text-on-accent hover:bg-accent-hover',
  secondary: 'border-line-strong bg-surface text-fg hover:bg-surface-muted',
  ghost: 'border-transparent bg-transparent text-fg hover:bg-surface-muted',
  danger: 'border-transparent bg-danger text-on-danger hover:bg-danger-hover',
};

export function buttonClasses(
  variant: ButtonVariant = 'primary',
  size: ButtonSize = 'md',
  className?: string,
): string {
  return cx(base, sizes[size], variants[variant], className);
}
