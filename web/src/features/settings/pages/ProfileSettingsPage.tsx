import { hasErrorCode } from '@/shared/api/errors';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useCurrencies } from '@/shared/currency/api';
import { useAccounts, usePreferences } from '@/shared/finance/reference';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { useOwnProfile } from '@/features/social/hooks';
import { AccessibilityCard } from '../components/AccessibilityCard';
import { AvatarCard } from '../components/AvatarCard';
import { ProfileCard } from '../components/ProfileCard';
import { RegionPreferencesCard } from '../components/RegionPreferencesCard';

/** A card's loading, permission or error state, with retry. */
function CardState({
  title,
  loadingLabel,
  errorTitle,
  query,
}: {
  title: string;
  loadingLabel: string;
  errorTitle: string;
  query: { isPending: boolean; error: unknown; isFetching: boolean; refetch: () => unknown };
}) {
  return (
    <Card title={title}>
      {query.isPending ? (
        <LoadingState label={loadingLabel} />
      ) : hasErrorCode(query.error, 'FORBIDDEN') ? (
        <PermissionDenied titleAs="p" />
      ) : (
        <ErrorState
          titleAs="p"
          title={errorTitle}
          error={query.error}
          retrying={query.isFetching}
          onRetry={() => {
            void query.refetch();
          }}
        />
      )}
    </Card>
  );
}

/**
 * Profile and preferences (SET-001): your photo, name, username, bio,
 * interests, coarse location and who sees them; region, currencies,
 * formats, defaults and theme; and accessibility. Every save sends only
 * what changed.
 */
export function ProfileSettingsPage() {
  const t = useT();
  useDocumentTitle(t('profileSettings.title'));
  const profile = useOwnProfile();
  const preferences = usePreferences();
  // The pickers need their choices before the form takes its starting values.
  const currencies = useCurrencies();
  const accounts = useAccounts();
  const regionReady = !currencies.isPending && !accounts.isPending;

  return (
    <>
      <PageHeader
        title={t('profileSettings.title')}
        description={t('profileSettings.description')}
      />
      <div className="space-y-6">
        {profile.isSuccess ? (
          <>
            <AvatarCard profile={profile.data} />
            <ProfileCard profile={profile.data} />
          </>
        ) : (
          <CardState
            title={t('profileSettings.profile.title')}
            loadingLabel={t('profileSettings.profile.loading')}
            errorTitle={t('profileSettings.profile.error')}
            query={profile}
          />
        )}
        {preferences.isSuccess && regionReady ? (
          <>
            <RegionPreferencesCard preferences={preferences.data} />
            <AccessibilityCard preferences={preferences.data} />
          </>
        ) : (
          <CardState
            title={t('profileSettings.region.title')}
            loadingLabel={t('profileSettings.region.loading')}
            errorTitle={t('profileSettings.region.error')}
            query={
              preferences.isError
                ? preferences
                : { ...preferences, isPending: true, error: null, isFetching: true }
            }
          />
        )}
      </div>
    </>
  );
}
