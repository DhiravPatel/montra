import { appConfig } from '@/shared/config/env';
import { paths } from '@/shared/config/paths';
import { ExternalLink, TextLink } from '@/shared/components/TextLink';
import { useT } from '@/shared/i18n/I18nContext';

export function SiteFooter() {
  const t = useT();
  return (
    <footer className="border-t border-line bg-surface">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-8 text-sm text-fg-muted sm:px-6 md:flex-row md:items-center md:justify-between">
        <nav aria-label={t('nav.footer')}>
          <ul className="flex flex-wrap gap-x-6 gap-y-2">
            <li>
              <TextLink to={paths.privacy}>{t('nav.privacy')}</TextLink>
            </li>
            <li>
              <TextLink to={paths.securityInfo}>{t('nav.securityInfo')}</TextLink>
            </li>
            <li>
              <TextLink to={paths.terms}>{t('nav.terms')}</TextLink>
            </li>
            <li>
              <ExternalLink href={`mailto:${appConfig.supportEmail}`}>
                {t('footer.support')}
              </ExternalLink>
            </li>
          </ul>
        </nav>
        <p>{t('footer.tagline', { version: appConfig.clientVersion })}</p>
      </div>
    </footer>
  );
}
