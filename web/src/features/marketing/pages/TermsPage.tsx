import { appConfig } from '@/shared/config/env';
import { paths } from '@/shared/config/paths';
import { ExternalLink, TextLink } from '@/shared/components/TextLink';
import { useI18n } from '@/shared/i18n/I18nContext';
import { InfoList, InfoPage, InfoSection } from '../components/InfoPage';

export function TermsPage() {
  const { t, rich } = useI18n();
  return (
    <InfoPage
      title={t('terms.title')}
      intro={t('terms.intro')}
      meta={t('legal.version', { version: appConfig.legal.termsVersion })}
    >
      <InfoSection title={t('terms.summary.title')}>
        <InfoList
          items={[
            t('terms.summary.free'),
            t('terms.summary.age'),
            t('terms.summary.account'),
            rich('terms.summary.data', {
              link: (text) => <TextLink to={paths.privacy}>{text}</TextLink>,
            }),
            t('terms.summary.advice'),
            t('terms.summary.use'),
            t('terms.summary.changes'),
          ]}
        />
      </InfoSection>
      <InfoSection title={t('terms.contact.title')}>
        <p>
          {t('terms.contact.body')}{' '}
          <ExternalLink href={`mailto:${appConfig.supportEmail}`}>
            {appConfig.supportEmail}
          </ExternalLink>
        </p>
      </InfoSection>
    </InfoPage>
  );
}
