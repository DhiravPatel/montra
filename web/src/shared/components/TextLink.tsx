import type { ComponentProps } from 'react';
import { Link, type LinkProps } from 'react-router';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { Icon } from './Icon';

const linkClasses =
  'font-medium text-accent underline underline-offset-4 decoration-1 hover:text-accent-hover hover:decoration-2';

/** In-app link; underlined so it is not distinguished by color alone. */
export function TextLink({ className, ...rest }: LinkProps) {
  return (
    <Link
      className={cx(linkClasses, typeof className === 'string' ? className : undefined)}
      {...rest}
    />
  );
}

interface ExternalLinkProps extends ComponentProps<'a'> {
  href: string;
  /** Open in a new tab (announced to screen readers). */
  newTab?: boolean;
}

export function ExternalLink({ newTab = false, className, children, ...rest }: ExternalLinkProps) {
  const t = useT();
  return (
    <a
      className={cx(linkClasses, 'inline-flex items-center gap-1', className)}
      {...(newTab ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
      {...rest}
    >
      {children}
      {newTab ? (
        <>
          <Icon name="external-link" className="size-3.5" />
          <span className="sr-only"> {t('common.opensInNewTab')}</span>
        </>
      ) : null}
    </a>
  );
}
