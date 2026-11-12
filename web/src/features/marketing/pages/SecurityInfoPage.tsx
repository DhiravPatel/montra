import { appConfig } from '@/shared/config/env';
import { ExternalLink } from '@/shared/components/TextLink';
import { useT } from '@/shared/i18n/I18nContext';
import { InfoList, InfoPage, InfoSection } from '../components/InfoPage';

export function SecurityInfoPage() {
  const t = useT();
  return (
    <InfoPage title={t('securityInfo.title')} intro={t('securityInfo.intro')}>
      <InfoSection title={t('securityInfo.protect.title')}>
        <InfoList
          items={[
            t('securityInfo.protect.passwords'),
            t('securityInfo.protect.sessions'),
            t('securityInfo.protect.mfa'),
            t('securityInfo.protect.devices'),
            t('securityInfo.protect.abuse'),
          ]}
        />
      </InfoSection>
      <InfoSection title={t('securityInfo.tips.title')}>
        <InfoList
          items={[
            t('securityInfo.tips.unique'),
            t('securityInfo.tips.mfa'),
            t('securityInfo.tips.codes'),
            t('securityInfo.tips.review'),
          ]}
        />
      </InfoSection>
      <InfoSection title={t('securityInfo.report.title')}>
        <p>
          {t('securityInfo.report.body')}{' '}
          <ExternalLink href={`mailto:${appConfig.securityEmail}`}>
            {appConfig.securityEmail}
          </ExternalLink>
        </p>
      </InfoSection>
    </InfoPage>
  );
}
