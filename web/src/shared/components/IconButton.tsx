import type { ComponentProps } from 'react';
import { cx } from '@/shared/utils/cx';
import { Icon, type IconName } from './Icon';

interface IconButtonProps extends Omit<ComponentProps<'button'>, 'children'> {
  icon: IconName;
  /** Required accessible name (icon-only buttons have no visible text). */
  label: string;
  size?: 'md' | 'sm';
}

export function IconButton({
  icon,
  label,
  size = 'md',
  type = 'button',
  className,
  ...rest
}: IconButtonProps) {
  return (
    <button
      type={type}
      aria-label={label}
      className={cx(
        'inline-flex shrink-0 items-center justify-center rounded-md border border-transparent text-fg-muted',
        'hover:bg-surface-muted hover:text-fg disabled:cursor-not-allowed disabled:opacity-60',
        size === 'md' ? 'size-11' : 'size-9',
        className,
      )}
      {...rest}
    >
      <Icon name={icon} />
    </button>
  );
}
