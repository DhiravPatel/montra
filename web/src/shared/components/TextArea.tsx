import type { ComponentProps, ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';
import { FieldError, FieldHelp, FieldLabel } from './FieldParts';
import { useFieldIds } from './useFieldIds';

interface TextAreaProps extends Omit<ComponentProps<'textarea'>, 'children'> {
  label: string;
  help?: ReactNode;
  error?: string | undefined;
  optional?: boolean;
}

/** Labelled multi-line text input. */
export function TextArea({
  label,
  help,
  error,
  optional,
  id,
  className,
  rows = 3,
  ref,
  ...props
}: TextAreaProps) {
  const { inputId, helpId, errorId, describedBy } = useFieldIds(id, Boolean(help), Boolean(error));
  return (
    <div className={cx('space-y-1.5', className)}>
      <FieldLabel htmlFor={inputId} optional={optional}>
        {label}
      </FieldLabel>
      <textarea
        ref={ref}
        id={inputId}
        rows={rows}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        aria-required={optional ? undefined : true}
        className={cx(
          'block w-full rounded-md border border-line-strong bg-surface px-3 py-2 text-base text-fg',
          'placeholder:text-fg-muted aria-[invalid=true]:border-danger disabled:cursor-not-allowed disabled:opacity-60',
        )}
        {...props}
      />
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </div>
  );
}
