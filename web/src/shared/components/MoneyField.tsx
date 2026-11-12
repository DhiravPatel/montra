import type { ComponentProps, ReactNode } from 'react';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { FieldError, FieldHelp, FieldLabel } from './FieldParts';
import { inputClasses } from './fieldStyles';
import { useFieldIds } from './useFieldIds';

interface MoneyFieldProps extends Omit<ComponentProps<'input'>, 'children' | 'type'> {
  label: string;
  /** ISO 4217 code of the amount; shown beside the input and announced with it. */
  currency: string | null;
  help?: ReactNode;
  error?: string | undefined;
  optional?: boolean;
}

/**
 * Amount input. Text (not type=number) so exact decimals are kept as typed
 * and parsed with normalizeDecimalInput(); never converted to a float.
 */
export function MoneyField({
  label,
  currency,
  help,
  error,
  optional,
  id,
  className,
  ref,
  ...inputProps
}: MoneyFieldProps) {
  const t = useT();
  const { inputId, helpId, errorId, describedBy } = useFieldIds(id, Boolean(help), Boolean(error));
  const currencyId = `${inputId}-currency`;
  return (
    <div className={cx('space-y-1.5', className)}>
      <FieldLabel htmlFor={inputId} optional={optional}>
        {label}
      </FieldLabel>
      <div className="flex">
        <span
          id={currencyId}
          className="inline-flex min-w-14 items-center justify-center rounded-s-md border border-e-0 border-line-strong bg-surface-muted px-3 text-sm font-medium text-fg-muted"
        >
          <span className="sr-only">{t('common.currency')} </span>
          {currency ?? '—'}
        </span>
        <input
          ref={ref}
          id={inputId}
          type="text"
          inputMode="decimal"
          autoComplete="off"
          spellCheck={false}
          aria-invalid={error ? true : undefined}
          aria-describedby={[currencyId, describedBy].filter(Boolean).join(' ')}
          aria-required={optional ? undefined : true}
          className={cx(inputClasses, 'rounded-s-none tabular-nums')}
          {...inputProps}
        />
      </div>
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </div>
  );
}
