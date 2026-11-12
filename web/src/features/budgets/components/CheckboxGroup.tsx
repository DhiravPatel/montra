import { type ReactNode, useId } from 'react';
import { FieldError, FieldHelp } from '@/shared/components/FieldParts';
import { cx } from '@/shared/utils/cx';

export interface CheckboxChoice {
  value: string;
  label: string;
}

interface CheckboxGroupProps {
  legend: string;
  help?: ReactNode;
  error?: string | undefined;
  choices: readonly CheckboxChoice[];
  value: readonly string[];
  onChange: (value: string[]) => void;
  /** Long lists scroll inside a box instead of stretching the form. */
  scroll?: boolean;
  columns?: 1 | 2 | 3;
  disabled?: boolean;
}

/** A fieldset of checkboxes for a list of IDs (keeps the given order). */
export function CheckboxGroup({
  legend,
  help,
  error,
  choices,
  value,
  onChange,
  scroll = false,
  columns = 1,
  disabled = false,
}: CheckboxGroupProps) {
  const id = useId();
  const helpId = `${id}-help`;
  const errorId = `${id}-error`;
  const describedBy = [help ? helpId : null, error ? errorId : null].filter(Boolean).join(' ');
  const selected = new Set(value);
  return (
    <fieldset className="space-y-2" aria-describedby={describedBy || undefined} disabled={disabled}>
      <legend className="mb-1.5 text-sm font-medium text-fg">{legend}</legend>
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      <div
        className={cx(
          'grid gap-x-4 gap-y-1',
          columns === 2 && 'sm:grid-cols-2',
          columns === 3 && 'sm:grid-cols-3',
          scroll && 'max-h-64 overflow-y-auto rounded-md border border-line p-3',
        )}
      >
        {choices.map((choice) => (
          <label
            key={choice.value}
            className="flex min-h-10 cursor-pointer items-center gap-3 text-sm text-fg"
          >
            <input
              type="checkbox"
              value={choice.value}
              checked={selected.has(choice.value)}
              onChange={(event) => {
                onChange(
                  event.target.checked
                    ? [...value, choice.value]
                    : value.filter((item) => item !== choice.value),
                );
              }}
              className="size-5 shrink-0 cursor-pointer rounded border-line-strong accent-accent"
            />
            {choice.label}
          </label>
        ))}
      </div>
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </fieldset>
  );
}
