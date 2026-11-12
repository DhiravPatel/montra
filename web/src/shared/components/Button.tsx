import type { ComponentProps, MouseEvent } from 'react';
import { Link, type LinkProps } from 'react-router';
import { type ButtonSize, type ButtonVariant, buttonClasses } from './buttonStyles';
import { Spinner } from './Spinner';

interface ButtonProps extends ComponentProps<'button'> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  /**
   * Shows a spinner and blocks activation while an action is running. Uses
   * aria-disabled (not disabled) so keyboard focus is not lost mid-action.
   */
  loading?: boolean;
}

export function Button({
  variant = 'primary',
  size = 'md',
  loading = false,
  type = 'button',
  className,
  children,
  onClick,
  ...rest
}: ButtonProps) {
  const handleClick = (event: MouseEvent<HTMLButtonElement>) => {
    if (loading) {
      event.preventDefault(); // also blocks form submission while pending
      return;
    }
    onClick?.(event);
  };
  return (
    <button
      type={type}
      className={buttonClasses(variant, size, className)}
      aria-disabled={loading || undefined}
      aria-busy={loading || undefined}
      onClick={handleClick}
      {...rest}
    >
      {loading ? <Spinner size="sm" /> : null}
      {children}
    </button>
  );
}

interface ButtonLinkProps extends LinkProps {
  variant?: ButtonVariant;
  size?: ButtonSize;
}

/** A router link styled as a button (navigation, not an action). */
export function ButtonLink({
  variant = 'primary',
  size = 'md',
  className,
  ...rest
}: ButtonLinkProps) {
  return (
    <Link
      className={buttonClasses(
        variant,
        size,
        typeof className === 'string' ? className : undefined,
      )}
      {...rest}
    />
  );
}
