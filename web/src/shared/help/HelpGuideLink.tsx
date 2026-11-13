import { Link } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { ExternalLink } from '@/shared/components/TextLink';
import { appConfig } from '@/shared/config/env';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { type HelpGuideId, helpGuidePath } from './guides';

interface HelpGuideLinkProps {
  guide: HelpGuideId;
  /** Opens the guide at this section (its anchor ID). */
  section?: string;
  className?: string;
}

/**
 * A screen's "How this works" link to the guide about it. The visible text
 * is short; the accessible name says which guide it opens.
 */
export function HelpGuideLink({ guide, section, className }: HelpGuideLinkProps) {
  const t = useT();
  const title = t(`helpGuides.${guide}.title`);
  return (
    <Link
      to={helpGuidePath(guide, section)}
      aria-label={t('helpGuides.ui.affordanceFor', { guide: title })}
      className={cx(
        'inline-flex min-h-11 items-center gap-1.5 rounded-md px-1 text-sm font-medium text-accent underline underline-offset-4 decoration-1 hover:text-accent-hover hover:decoration-2',
        className,
      )}
    >
      <Icon name="help-circle" className="size-4 shrink-0" />
      {t('helpGuides.ui.affordance')}
    </Link>
  );
}

/** Link to the public service-status page; renders nothing unless one is configured. */
export function ServiceStatusLink({ className }: { className?: string }) {
  const t = useT();
  const url = appConfig.statusPageUrl;
  if (!url) return null;
  return (
    <p className={cx('text-sm text-fg-muted', className)}>
      <ExternalLink href={url} newTab>
        {t('helpGuides.ui.status')}
      </ExternalLink>{' '}
      {t('helpGuides.ui.statusHelp')}
    </p>
  );
}
