import { StatusBadge } from '@/shared/components/StatusBadge';
import { useT } from '@/shared/i18n/I18nContext';
import { roleIcon, roleLabel, visibilityIcon, visibilityLabel } from '../labels';
import type { Community, CommunityVisibility, MemberRole } from '../types';

export function VisibilityBadge({ visibility }: { visibility: CommunityVisibility }) {
  const t = useT();
  return (
    <StatusBadge tone="neutral" icon={visibilityIcon[visibility]}>
      {t(visibilityLabel[visibility])}
    </StatusBadge>
  );
}

export function RoleBadge({ role }: { role: MemberRole }) {
  const t = useT();
  return (
    <StatusBadge tone={role === 'member' ? 'neutral' : 'info'} icon={roleIcon[role]}>
      {t(roleLabel[role])}
    </StatusBadge>
  );
}

/** The caller's place in a community and the community's state, as icon + text badges. */
export function CommunityStateBadges({ community }: { community: Community }) {
  const t = useT();
  return (
    <>
      {community.my_status === 'active' && community.my_role !== 'none' ? (
        <RoleBadge role={community.my_role} />
      ) : null}
      {community.my_status === 'pending' ? (
        <StatusBadge tone="info" icon="clock">
          {t('communities.membership.pending')}
        </StatusBadge>
      ) : null}
      {community.my_status === 'banned' ? (
        <StatusBadge tone="danger" icon="ban">
          {t('communities.membership.banned')}
        </StatusBadge>
      ) : null}
      {community.status === 'archived' ? (
        <StatusBadge tone="neutral" icon="archive">
          {t('communities.status.archived')}
        </StatusBadge>
      ) : null}
      {community.status === 'suspended' ? (
        <StatusBadge tone="warning" icon="ban">
          {t('communities.status.suspended')}
        </StatusBadge>
      ) : null}
    </>
  );
}
