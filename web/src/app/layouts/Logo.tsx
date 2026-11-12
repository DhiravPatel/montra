import { Link } from 'react-router';
import { useT } from '@/shared/i18n/I18nContext';

export function Logo({ to }: { to: string }) {
  const t = useT();
  return (
    <Link
      to={to}
      className="inline-flex min-h-11 items-center gap-2 rounded-md text-lg font-semibold text-fg"
    >
      <svg viewBox="0 0 32 32" className="size-8" aria-hidden="true" focusable="false">
        <rect width="32" height="32" rx="8" className="fill-accent" />
        <path
          d="M8.5 22.5v-12l7.5 7.5 7.5-7.5v12"
          fill="none"
          className="stroke-on-accent"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      <span>{t('app.name')}</span>
      <span className="sr-only">{t('nav.homeLinkSuffix')}</span>
    </Link>
  );
}
