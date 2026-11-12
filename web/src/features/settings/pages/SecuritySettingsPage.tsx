import { PageHeader } from '@/shared/components/PageHeader';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { ChangePasswordCard } from '../components/ChangePasswordCard';
import { SessionsCard } from '../components/SessionsCard';
import { SignOutEverywhereCard } from '../components/SignOutEverywhereCard';
import { TwoStepCard } from '../components/TwoStepCard';

export function SecuritySettingsPage() {
  const t = useT();
  useDocumentTitle(t('settings.security.title'));
  return (
    <>
      <PageHeader
        title={t('settings.security.title')}
        description={t('settings.security.description')}
      />
      <div className="space-y-6">
        <TwoStepCard />
        <SessionsCard />
        <ChangePasswordCard />
        <SignOutEverywhereCard />
      </div>
    </>
  );
}
