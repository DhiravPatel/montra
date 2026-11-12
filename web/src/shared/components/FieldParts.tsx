import type { ReactNode } from 'react';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { Icon } from './Icon';

export function FieldLabel({
  htmlFor,
  children,
  optional,
}: {
  htmlFor: string;
  children: ReactNode;
  optional?: boolean;
}) {
  const t = useT();
  return (
    <label htmlFor={htmlFor} className="block text-sm font-medium text-fg">
      {children}
      {optional ? (
        <span className="font-normal text-fg-muted"> ({t('common.optional')})</span>
      ) : null}
    </label>
  );
}

export function FieldHelp({
  id,
  children,
  className,
}: {
  id: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div id={id} className={cx('text-sm text-fg-muted', className)}>
      {children}
    </div>
  );
}

/** Field-associated error text: icon plus words, never color alone. */
export function FieldError({ id, children }: { id: string; children: ReactNode }) {
  const t = useT();
  return (
    <p id={id} className="flex items-start gap-1.5 text-sm font-medium text-danger">
      <Icon name="alert-circle" className="mt-0.5 size-4" />
      <span>
        <span className="sr-only">{t('common.errorPrefix')} </span>
        {children}
      </span>
    </p>
  );
}
