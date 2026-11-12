import { Card } from '@/shared/components/Card';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { communitySettingsPath } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { useCommunityMembers } from '../api';
import type { Community } from '../types';
import { RoleBadge } from './CommunityBadges';
import { PersonName } from './PersonName';

/**
 * The owner and moderators (GET /communities/{id}/members: members and
 * visitors see only them; moderators see everyone and manage members in
 * settings). Only names and usernames are shown, never anything else.
 */
export function ModeratorsCard({
  community,
  moderator,
  communityRef,
}: {
  community: Community;
  /** The caller moderates this community (links to member management). */
  moderator: boolean;
  communityRef: string;
}) {
  const t = useT();
  const members = useCommunityMembers(community.id, 'active');

  let content;
  if (members.isPending) {
    content = <LoadingState label={t('communities.moderators.loading')} />;
  } else if (members.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('communities.moderators.error')}
        error={members.error}
        retrying={members.isFetching}
        onRetry={() => {
          void members.refetch();
        }}
      />
    );
  } else {
    const leaders = members.data.filter((member) => member.role !== 'member');
    content =
      leaders.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('communities.moderators.hidden')}</p>
      ) : (
        <ul className="space-y-3">
          {leaders.map((member) => (
            <li key={member.user_id} className="flex flex-wrap items-center justify-between gap-2">
              <PersonName name={member.display_name} username={member.username} />
              <RoleBadge role={member.role} />
            </li>
          ))}
        </ul>
      );
  }

  return (
    <Card title={t('communities.moderators.title')}>
      <div className="space-y-4">
        {content}
        {moderator ? (
          <p className="text-sm">
            <TextLink to={communitySettingsPath(communityRef)}>
              {t('communities.moderators.manage')}
            </TextLink>
          </p>
        ) : null}
      </div>
    </Card>
  );
}
