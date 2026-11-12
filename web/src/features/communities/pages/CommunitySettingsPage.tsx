import { useParams } from 'react-router';
import { PageHeader } from '@/shared/components/PageHeader';
import { PermissionDenied } from '@/shared/components/states';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { canModerate, isOwner } from '../access';
import { RoleBadge } from '../components/CommunityBadges';
import { BackToCommunity, CommunityGate } from '../components/CommunityGate';
import { CommunityNotices } from '../components/CommunityNotices';
import { CommunitySubNav } from '../components/CommunitySubNav';
import { DetailsSection } from '../components/settings/DetailsSection';
import { InvitationsSection } from '../components/settings/InvitationsSection';
import { JoinRequestsSection } from '../components/settings/JoinRequestsSection';
import { MembersSection } from '../components/settings/MembersSection';
import { OwnerSection } from '../components/settings/OwnerSection';

/**
 * Community settings for the owner and moderators: details, members and
 * roles, join requests, invitations, and (owner) ownership and archiving.
 * The API stays the authority; its permission answers are shown.
 */
export function CommunitySettingsPage() {
  const t = useT();
  const { communityRef = '' } = useParams();
  useDocumentTitle(t('communities.settings.title'));
  return (
    <CommunityGate communityRef={communityRef} title={t('communities.settings.title')}>
      {({ community, reload }) => {
        if (!canModerate(community)) {
          return (
            <>
              <BackToCommunity community={community} />
              <PageHeader title={t('communities.settings.title')} />
              <PermissionDenied titleAs="h2" description={t('communities.settings.forbidden')} />
            </>
          );
        }
        return (
          <>
            <BackToCommunity community={community} />
            <PageHeader
              title={t('communities.settings.title')}
              description={
                <span className="flex flex-wrap items-center gap-2">
                  <span className="break-words">{community.name}</span>
                  {community.my_status === 'active' && community.my_role !== 'none' ? (
                    <RoleBadge role={community.my_role} />
                  ) : null}
                </span>
              }
            />
            <CommunitySubNav communityRef={communityRef} />
            <CommunityNotices community={community} />
            <div className="space-y-6">
              <DetailsSection community={community} reload={reload} />
              <JoinRequestsSection community={community} />
              <MembersSection community={community} reload={reload} />
              <InvitationsSection community={community} />
              {isOwner(community) ? (
                <OwnerSection community={community} reload={reload} />
              ) : (
                <p className="text-sm text-fg-muted">{t('communities.settings.ownerOnlyNote')}</p>
              )}
            </div>
          </>
        );
      }}
    </CommunityGate>
  );
}
