import { appConfig } from '@/shared/config/env';
import { ExternalLink } from '@/shared/components/TextLink';
import { useT } from '@/shared/i18n/I18nContext';
import { InfoList, InfoPage, InfoSection } from '../components/InfoPage';

export function PrivacyPage() {
  const t = useT();
  return (
    <InfoPage
      title={t('privacy.title')}
      intro={t('privacy.intro')}
      meta={t('legal.version', { version: appConfig.legal.privacyVersion })}
    >
      <InfoSection title={t('privacy.commitments.title')}>
        <InfoList
          items={[
            t('privacy.commitments.private'),
            t('privacy.commitments.noSelling'),
            t('privacy.commitments.noBank'),
            t('privacy.commitments.minimal'),
          ]}
        />
      </InfoSection>
      <InfoSection title={t('privacy.collect.title')}>
        <InfoList
          items={[
            t('privacy.collect.account'),
            t('privacy.collect.preferences'),
            t('privacy.collect.finance'),
            t('privacy.collect.sessions'),
            t('privacy.collect.consents'),
          ]}
        />
      </InfoSection>
      <InfoSection title={t('privacy.cookies.title')}>
        <p>{t('privacy.cookies.essential')}</p>
        <p>{t('privacy.cookies.storage')}</p>
      </InfoSection>
      <InfoSection title={t('privacy.choices.title')}>
        <p>{t('privacy.choices.body')}</p>
      </InfoSection>
      <InfoSection title={t('privacy.contact.title')}>
        <p>
          {t('privacy.contact.body')}{' '}
          <ExternalLink href={`mailto:${appConfig.supportEmail}`}>
            {appConfig.supportEmail}
          </ExternalLink>
        </p>
      </InfoSection>
    </InfoPage>
  );
}
