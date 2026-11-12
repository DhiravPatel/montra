import { Icon } from '@/shared/components/Icon';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { evaluatePassword } from '@/shared/validation/password';

interface PasswordRequirementsProps {
  password: string;
  /** Enables the "does not contain your email" rule. */
  email?: string;
}

/** Live checklist mirroring the API password policy (icon + text, not color alone). */
export function PasswordRequirements({ password, email }: PasswordRequirementsProps) {
  const t = useT();
  const rules = evaluatePassword(password, email).filter(
    (rule) => email !== undefined || rule.id !== 'notEmail',
  );
  return (
    <div>
      <p className="mb-1">{t('auth.password.requirements')}</p>
      <ul className="space-y-1">
        {rules.map((rule) => (
          <li key={rule.id} className="flex items-center gap-2">
            <Icon
              name={rule.met ? 'check-circle' : 'circle'}
              className={cx('size-4', rule.met ? 'text-success' : 'text-fg-muted')}
            />
            <span className={rule.met ? 'text-fg' : undefined}>
              {t(`auth.password.rule.${rule.id}`)}
            </span>
            <span className="sr-only">
              {rule.met ? t('auth.password.ruleMet') : t('auth.password.ruleNotMet')}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
