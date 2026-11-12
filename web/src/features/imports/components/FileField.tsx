import type { ComponentProps, ReactNode } from 'react';
import { FieldError, FieldHelp, FieldLabel } from '@/shared/components/FieldParts';
import { useFieldIds } from '@/shared/components/useFieldIds';
import { cx } from '@/shared/utils/cx';

interface FileFieldProps extends Omit<ComponentProps<'input'>, 'type' | 'children'> {
  label: string;
  help?: ReactNode;
  error?: string | undefined;
}

/** Labelled native file picker (keyboard and screen-reader friendly) with help and error text. */
export function FileField({ label, help, error, id, className, ...inputProps }: FileFieldProps) {
  const { inputId, helpId, errorId, describedBy } = useFieldIds(id, Boolean(help), Boolean(error));
  return (
    <div className={cx('space-y-1.5', className)}>
      <FieldLabel htmlFor={inputId}>{label}</FieldLabel>
      <input
        id={inputId}
        type="file"
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        aria-required
        className={cx(
          'block w-full rounded-md border border-line-strong bg-surface p-2 text-sm text-fg',
          'file:me-3 file:min-h-9 file:cursor-pointer file:rounded-md file:border-0 file:bg-surface-muted file:px-3 file:font-medium file:text-fg',
          'aria-[invalid=true]:border-danger',
        )}
        {...inputProps}
      />
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </div>
  );
}
