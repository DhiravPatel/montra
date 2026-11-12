import { useParams } from 'react-router';
import { PageHeader } from '@/shared/components/PageHeader';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useNow } from '@/shared/hooks/useNow';
import { useT } from '@/shared/i18n/I18nContext';
import { canModerate, canParticipate } from '../access';
import { AboutCard } from '../components/AboutCard';
import { CommunityStateBadges, VisibilityBadge } from '../components/CommunityBadges';
import { BackToCommunities, CommunityGate } from '../components/CommunityGate';
import { CommunityNotices } from '../components/CommunityNotices';
import { CommunitySubNav } from '../components/CommunitySubNav';
import { Feed } from '../components/Feed';
import { MembershipActions } from '../components/MembershipActions';
import { ModeratorsCard } from '../components/ModeratorsCard';
import { PostComposer } from '../components/PostComposer';
import type { Community } from '../types';

function CommunityOverview({
  community,
  communityRef,
  reload,
}: {
  community: Community;
  communityRef: string;
  reload: () => void;
}) {
  const t = useT();
  const now = useNow();
  const moderator = canModerate(community);
  const participate = canParticipate(community, now);
  return (
    <>
      <BackToCommunities />
      <PageHeader
        title={community.name}
        description={
          <div className="mt-2 flex flex-wrap items-center gap-2 text-sm">
            <VisibilityBadge visibility={community.visibility} />
            <span>{t('communities.memberCount', { count: community.member_count })}</span>
            <CommunityStateBadges community={community} />
          </div>
        }
        actions={<MembershipActions community={community} reload={reload} />}
      />
      {moderator ? <CommunitySubNav communityRef={communityRef} /> : null}
      <CommunityNotices community={community} />
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="min-w-0 space-y-6 lg:col-span-2">
          {participate ? <PostComposer community={community} moderator={moderator} /> : null}
          <Feed community={community} canParticipate={participate} />
        </div>
        <aside aria-label={t('communities.page.aside')} className="min-w-0 space-y-6">
          <AboutCard community={community} />
          <ModeratorsCard community={community} moderator={moderator} communityRef={communityRef} />
        </aside>
      </div>
    </>
  );
}

/**
 * A community: about, rules and moderators, joining or leaving, and the
 * post feed with a composer for members. The page title stays generic
 * (community names are not put in the browser title).
 */
export function CommunityPage() {
  const t = useT();
  const { communityRef = '' } = useParams();
  useDocumentTitle(t('communities.page.title'));
  return (
    <CommunityGate communityRef={communityRef} title={t('communities.page.title')}>
      {({ community, reload }) => (
        <CommunityOverview community={community} communityRef={communityRef} reload={reload} />
      )}
    </CommunityGate>
  );
}
