import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { ConsentsCard } from '../components/ConsentsCard';
import { DeactivateCard } from '../components/DeactivateCard';
import { DeletionCard } from '../components/DeletionCard';
import { ExportCard } from '../components/ExportCard';
import { useLimits } from '../hooks';
import { HelpGuideLink } from '@/shared/help/HelpGuideLink';

/**
 * Privacy & data: optional consents, a full data export, deactivation and
 * deletion. Export, deactivation and deletion ask for the password again
 * (the shell's re-authentication prompt) when the API requires it.
 */
export function PrivacySettingsPage() {
  const t = useT();
  useDocumentTitle(t('privacySettings.title'));
  // Download window and grace period; the page works without them.
  const limits = useLimits();

  return (
    <>
      <PageHeader
        help={<HelpGuideLink guide="privacy" />}
        title={t('privacySettings.title')}
        description={
          <>
            {t('privacySettings.description')}{' '}
            <TextLink to={paths.privacy}>{t('privacySettings.readNotice')}</TextLink>
          </>
        }
        actions={
          <ButtonLink to={paths.limits} variant="secondary">
            <Icon name="sliders" className="size-4" />
            {t('privacySettings.limitsLink')}
          </ButtonLink>
        }
      />
      <div className="space-y-6">
        <ConsentsCard />
        <ExportCard downloadDays={limits.data?.export_download_days ?? null} />
        <DeactivateCard />
        <DeletionCard graceDays={limits.data?.deletion_grace_days ?? null} />
      </div>
    </>
  );
}
