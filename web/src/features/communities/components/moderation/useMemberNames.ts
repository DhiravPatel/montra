import { useMemo } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { useT } from '@/shared/i18n/I18nContext';
import { useCommunityMembers } from '../../api';

/**
 * Names for user IDs in the moderation log and appeals, from the members
 * list moderators can read (every status). The caller is "you"; people no
 * longer listed are "someone".
 */
export function useMemberNames(communityId: string) {
  const t = useT();
  const me = useCurrentUser();
  const members = useCommunityMembers(communityId, '');
  const names = useMemo(() => {
    const map = new Map<string, string>();
    for (const member of members.data ?? []) {
      map.set(
        member.user_id,
        member.username ? `${member.display_name} (@${member.username})` : member.display_name,
      );
    }
    return map;
  }, [members.data]);
  return (userId: string | undefined): string => {
    if (!userId) return t('communities.mod.someone');
    if (userId === me.id) return t('communities.mod.you');
    return names.get(userId) ?? t('communities.mod.someone');
  };
}
