import { type ReactNode, useId } from 'react';
import { cx } from '@/shared/utils/cx';
import { FieldError, FieldHelp } from './FieldParts';

export interface RadioOption<T extends string> {
  value: T;
  label: string;
  description?: ReactNode;
  disabled?: boolean;
}

interface RadioGroupProps<T extends string> {
  legend: string;
  value: T;
  onChange: (value: T) => void;
  options: readonly RadioOption<T>[];
  /** `segmented` renders a compact row of choices; `cards` stacks them with descriptions. */
  variant?: 'segmented' | 'cards';
  help?: ReactNode;
  error?: string | undefined;
  hideLegend?: boolean;
  disabled?: boolean;
  className?: string;
}

/**
 * Native radio buttons in a fieldset: arrow keys move between choices and
 * the selected one is marked by a filled dot and a border, not color alone.
 */
export function RadioGroup<T extends string>({
  legend,
  value,
  onChange,
  options,
  variant = 'segmented',
  help,
  error,
  hideLegend = false,
  disabled = false,
  className,
}: RadioGroupProps<T>) {
  const name = useId();
  const helpId = `${name}-help`;
  const errorId = `${name}-error`;
  const describedBy = [help ? helpId : null, error ? errorId : null].filter(Boolean).join(' ');
  return (
    <fieldset
      className={cx('space-y-2', className)}
      aria-describedby={describedBy || undefined}
      disabled={disabled}
    >
      <legend className={cx('mb-1.5 text-sm font-medium text-fg', hideLegend && 'sr-only')}>
        {legend}
      </legend>
      <div
        className={cx(
          variant === 'segmented' ? 'flex flex-wrap gap-2' : 'grid gap-2 sm:grid-cols-2',
        )}
      >
        {options.map((option) => {
          const checked = option.value === value;
          return (
            <label
              key={option.value}
              className={cx(
                'flex min-h-11 cursor-pointer items-start gap-3 rounded-md border px-3 py-2.5 text-sm',
                'has-[:focus-visible]:outline-3 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-focus',
                checked
                  ? 'border-accent bg-accent-soft font-semibold text-fg'
                  : 'border-line-strong bg-surface text-fg hover:bg-surface-muted',
                (option.disabled ?? disabled) && 'cursor-not-allowed opacity-60',
              )}
            >
              <input
                type="radio"
                name={name}
                value={option.value}
                checked={checked}
                disabled={option.disabled}
                onChange={() => {
                  onChange(option.value);
                }}
                className="mt-0.5 size-4 shrink-0 cursor-pointer accent-accent focus-visible:outline-none"
              />
              <span className="min-w-0">
                <span className="block">{option.label}</span>
                {option.description ? (
                  <span className="mt-0.5 block font-normal text-fg-muted">
                    {option.description}
                  </span>
                ) : null}
              </span>
            </label>
          );
        })}
      </div>
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </fieldset>
  );
}
