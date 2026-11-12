import type { ComponentProps, ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';
import { FieldError, FieldHelp, FieldLabel } from './FieldParts';
import { inputClasses } from './fieldStyles';
import { Icon } from './Icon';
import { useFieldIds } from './useFieldIds';

export interface SelectOption {
  value: string;
  label: string;
  disabled?: boolean;
}

export interface SelectGroup {
  label: string;
  options: readonly SelectOption[];
}

interface SelectProps extends Omit<ComponentProps<'select'>, 'children'> {
  label: string;
  options?: readonly SelectOption[];
  /** Options shown under <optgroup> headings (after any plain options). */
  groups?: readonly SelectGroup[];
  /** Optional first, empty choice (e.g. "Choose a currency"). */
  placeholder?: string;
  help?: ReactNode;
  error?: string | undefined;
  /** Marks the field as optional (label suffix, no aria-required). */
  optional?: boolean;
  /** Visually hides the label (it stays the accessible name). */
  hideLabel?: boolean;
}

function renderOption(option: SelectOption) {
  return (
    <option key={option.value} value={option.value} disabled={option.disabled}>
      {option.label}
    </option>
  );
}

/** Native select: the most robust keyboard and screen-reader experience. */
export function Select({
  label,
  options = [],
  groups,
  placeholder,
  help,
  error,
  optional,
  hideLabel,
  id,
  className,
  ref,
  ...selectProps
}: SelectProps) {
  const { inputId, helpId, errorId, describedBy } = useFieldIds(id, Boolean(help), Boolean(error));
  return (
    <div className={cx('space-y-1.5', className)}>
      <div className={hideLabel ? 'sr-only' : undefined}>
        <FieldLabel htmlFor={inputId} optional={optional}>
          {label}
        </FieldLabel>
      </div>
      <div className="relative">
        <select
          ref={ref}
          id={inputId}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy}
          aria-required={optional ? undefined : true}
          className={cx(inputClasses, 'cursor-pointer appearance-none pe-10')}
          {...selectProps}
        >
          {placeholder !== undefined ? <option value="">{placeholder}</option> : null}
          {options.map(renderOption)}
          {groups?.map((group) =>
            group.options.length > 0 ? (
              <optgroup key={group.label} label={group.label}>
                {group.options.map(renderOption)}
              </optgroup>
            ) : null,
          )}
        </select>
        <Icon
          name="chevron-down"
          className="pointer-events-none absolute end-3 top-1/2 -translate-y-1/2 text-fg-muted"
        />
      </div>
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </div>
  );
}
