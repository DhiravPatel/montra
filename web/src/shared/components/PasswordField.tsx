import { type ComponentProps, type ReactNode, useState } from 'react';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { FieldError, FieldHelp, FieldLabel } from './FieldParts';
import { inputClasses } from './fieldStyles';
import { Icon } from './Icon';
import { useFieldIds } from './useFieldIds';

export interface PasswordFieldProps extends Omit<ComponentProps<'input'>, 'type' | 'children'> {
  label: string;
  help?: ReactNode;
  error?: string | undefined;
  autoComplete: 'current-password' | 'new-password';
}

/** Password input with an accessible show/hide toggle. */
export function PasswordField({
  label,
  help,
  error,
  id,
  className,
  ref,
  ...inputProps
}: PasswordFieldProps) {
  const t = useT();
  const [visible, setVisible] = useState(false);
  const { inputId, helpId, errorId, describedBy } = useFieldIds(id, Boolean(help), Boolean(error));
  return (
    <div className={cx('space-y-1.5', className)}>
      <FieldLabel htmlFor={inputId}>{label}</FieldLabel>
      <div className="relative">
        <input
          ref={ref}
          id={inputId}
          type={visible ? 'text' : 'password'}
          spellCheck={false}
          autoCapitalize="off"
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy}
          aria-required
          className={cx(inputClasses, 'pe-12')}
          {...inputProps}
        />
        <button
          type="button"
          className="absolute inset-y-0 end-0 flex w-11 items-center justify-center rounded-e-md text-fg-muted hover:text-fg"
          aria-pressed={visible}
          aria-controls={inputId}
          aria-label={visible ? t('common.hidePassword') : t('common.showPassword')}
          onClick={() => {
            setVisible((value) => !value);
          }}
        >
          <Icon name={visible ? 'eye-off' : 'eye'} />
        </button>
      </div>
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </div>
  );
}
