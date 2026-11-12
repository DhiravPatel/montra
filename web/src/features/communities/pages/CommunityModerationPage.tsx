import { useParams } from 'react-router';
import { Alert } from '@/shared/components/Alert';
import { PageHeader } from '@/shared/components/PageHeader';
import { PermissionDenied } from '@/shared/components/states';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { canModerate } from '../access';
import { BackToCommunity, CommunityGate } from '../components/CommunityGate';
import { CommunitySubNav } from '../components/CommunitySubNav';
import { ActionLogSection } from '../components/moderation/ActionLogSection';
import { AppealsSection } from '../components/moderation/AppealsSection';
import { MembersModerationSection } from '../components/moderation/MembersModerationSection';
import { ReportsSection } from '../components/moderation/ReportsSection';

/**
 * Community moderation for the owner, moderators and Montra staff: the
 * report queue, members to warn, restrict, ban or unban, open appeals and
 * the moderation log. Every action is confirmed and recorded; moderators
 * never see anyone's finances.
 */
export function CommunityModerationPage() {
  const t = useT();
  const { communityRef = '' } = useParams();
  useDocumentTitle(t('communities.mod.title'));
  return (
    <CommunityGate communityRef={communityRef} title={t('communities.mod.title')}>
      {({ community }) => {
        if (!canModerate(community)) {
          return (
            <>
              <BackToCommunity community={community} />
              <PageHeader title={t('communities.mod.title')} />
              <PermissionDenied titleAs="h2" description={t('communities.mod.forbidden')} />
            </>
          );
        }
        return (
          <>
            <BackToCommunity community={community} />
            <PageHeader
              title={t('communities.mod.title')}
              description={<span className="break-words">{community.name}</span>}
            />
            <CommunitySubNav communityRef={communityRef} />
            <Alert tone="info" title={t('communities.mod.audited.title')} className="mb-6">
              <p>{t('communities.mod.audited.body')}</p>
              <p>{t('communities.mod.audited.privacy')}</p>
            </Alert>
            <div className="space-y-6">
              <ReportsSection community={community} />
              <AppealsSection community={community} />
              <MembersModerationSection community={community} />
              <ActionLogSection community={community} />
            </div>
          </>
        );
      }}
    </CommunityGate>
  );
}
