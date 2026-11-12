import type { ComponentProps, ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';
import { FieldError, FieldHelp } from './FieldParts';
import { useFieldIds } from './useFieldIds';

interface CheckboxProps extends Omit<ComponentProps<'input'>, 'type' | 'children'> {
  label: ReactNode;
  description?: ReactNode;
  error?: string | undefined;
}

export function Checkbox({
  label,
  description,
  error,
  id,
  className,
  ref,
  ...inputProps
}: CheckboxProps) {
  const { inputId, helpId, errorId, describedBy } = useFieldIds(
    id,
    Boolean(description),
    Boolean(error),
  );
  return (
    <div className={cx('space-y-1.5', className)}>
      <div className="flex items-start gap-3">
        <input
          ref={ref}
          id={inputId}
          type="checkbox"
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy}
          className="mt-0.5 size-5 shrink-0 cursor-pointer rounded border-line-strong accent-accent"
          {...inputProps}
        />
        <div className="space-y-1">
          <label htmlFor={inputId} className="block cursor-pointer text-sm text-fg">
            {label}
          </label>
          {description ? <FieldHelp id={helpId}>{description}</FieldHelp> : null}
        </div>
      </div>
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </div>
  );
}
