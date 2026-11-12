import type { ComponentProps, ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';
import { FieldError, FieldHelp, FieldLabel } from './FieldParts';
import { inputClasses } from './fieldStyles';
import { useFieldIds } from './useFieldIds';

export interface TextFieldProps extends Omit<ComponentProps<'input'>, 'children'> {
  label: string;
  help?: ReactNode;
  error?: string | undefined;
  optional?: boolean;
}

/** Labelled text input with help and error text wired to aria-describedby. */
export function TextField({
  label,
  help,
  error,
  optional,
  id,
  className,
  ref,
  ...inputProps
}: TextFieldProps) {
  const { inputId, helpId, errorId, describedBy } = useFieldIds(id, Boolean(help), Boolean(error));
  return (
    <div className={cx('space-y-1.5', className)}>
      <FieldLabel htmlFor={inputId} optional={optional}>
        {label}
      </FieldLabel>
      <input
        ref={ref}
        id={inputId}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        aria-required={optional ? undefined : true}
        className={inputClasses}
        {...inputProps}
      />
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </div>
  );
}
