import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { usePreferences } from '@/shared/finance/reference';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { useNotificationPreferences } from '../api';
import { EmailDigestForm } from '../components/EmailDigestForm';
import { PreferencesForm } from '../components/PreferencesForm';
import { QuietHoursForm } from '../components/QuietHoursForm';
import { WebPushCard } from '../components/WebPushCard';

function QueryProblem({
  error,
  title,
  retrying,
  onRetry,
}: {
  error: unknown;
  title: string;
  retrying: boolean;
  onRetry: () => void;
}) {
  if (hasErrorCode(error, 'FORBIDDEN')) return <PermissionDenied />;
  return <ErrorState title={title} error={error} retrying={retrying} onRetry={onRetry} />;
}

/**
 * Notification settings (spec §4.17): browser notifications for this
 * browser (explicit opt-in), the summary email, quiet hours, and which
 * categories arrive in Montra, by email, in browsers and on phones.
 */
export function NotificationSettingsPage() {
  const t = useT();
  useDocumentTitle(t('notifications.settings.title'));
  const notificationPrefs = useNotificationPreferences();
  const accountPrefs = usePreferences();

  let preferencesContent;
  if (notificationPrefs.isPending) {
    preferencesContent = <LoadingState label={t('notifications.prefs.loading')} />;
  } else if (notificationPrefs.isError) {
    preferencesContent = (
      <QueryProblem
        error={notificationPrefs.error}
        title={t('notifications.prefs.error')}
        retrying={notificationPrefs.isFetching}
        onRetry={() => {
          void notificationPrefs.refetch();
        }}
      />
    );
  } else {
    preferencesContent = (
      <PreferencesForm
        key={notificationPrefs.dataUpdatedAt}
        preferences={notificationPrefs.data}
        emailDigest={accountPrefs.data?.email_digest ?? null}
      />
    );
  }

  const accountProblem = accountPrefs.isError ? (
    <QueryProblem
      error={accountPrefs.error}
      title={t('notifications.settings.accountError')}
      retrying={accountPrefs.isFetching}
      onRetry={() => {
        void accountPrefs.refetch();
      }}
    />
  ) : null;

  return (
    <>
      <PageHeader
        title={t('notifications.settings.title')}
        description={t('notifications.settings.description')}
        actions={
          <ButtonLink to={paths.notifications} variant="secondary">
            <Icon name="bell" className="size-4" />
            {t('notifications.settings.center')}
          </ButtonLink>
        }
      />
      <div className="space-y-6">
        <WebPushCard />
        <Card
          title={t('notifications.digest.title')}
          description={t('notifications.digest.description')}
        >
          {accountPrefs.isPending ? (
            <LoadingState />
          ) : accountPrefs.isError ? (
            accountProblem
          ) : (
            <EmailDigestForm
              key={accountPrefs.data.email_digest}
              current={accountPrefs.data.email_digest}
            />
          )}
        </Card>
        <Card
          title={t('notifications.quiet.title')}
          description={t('notifications.quiet.description')}
        >
          {accountPrefs.isPending ? (
            <LoadingState />
          ) : accountPrefs.isError ? (
            accountProblem
          ) : (
            <QuietHoursForm
              key={[
                accountPrefs.data.quiet_hours_enabled,
                accountPrefs.data.quiet_hours_start,
                accountPrefs.data.quiet_hours_end,
              ].join('|')}
              preferences={accountPrefs.data}
            />
          )}
        </Card>
        <Card
          title={t('notifications.prefs.title')}
          description={t('notifications.prefs.description')}
        >
          {preferencesContent}
        </Card>
      </div>
    </>
  );
}
