import { StatusBadge } from '@/shared/components/StatusBadge';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useT } from '@/shared/i18n/I18nContext';
import {
  groupTypeIcon,
  groupTypeLabel,
  hasTripDetails,
  roleIcon,
  roleLabel,
  tripPhase,
  tripPhaseIcon,
  tripPhaseLabel,
} from '../labels';
import type { Group, GroupRole } from '../types';

export function GroupTypeBadge({ type }: { type: Group['group_type'] }) {
  const t = useT();
  return (
    <StatusBadge tone="neutral" icon={groupTypeIcon[type]}>
      {t(groupTypeLabel[type])}
    </StatusBadge>
  );
}

export function RoleBadge({ role }: { role: GroupRole }) {
  const t = useT();
  return (
    <StatusBadge tone={role === 'member' ? 'neutral' : 'info'} icon={roleIcon[role]}>
      {t(roleLabel[role])}
    </StatusBadge>
  );
}

/** Archived status and, for trips and events, whether it is upcoming, on or over. */
export function GroupStateBadges({
  group,
}: {
  group: Pick<Group, 'status' | 'group_type' | 'start_date' | 'end_date' | 'timezone'>;
}) {
  const t = useT();
  const phase = hasTripDetails(group.group_type)
    ? tripPhase(group, todayInTimeZone(group.timezone))
    : null;
  return (
    <>
      {group.status === 'archived' ? (
        <StatusBadge tone="warning" icon="archive">
          {t('groups.status.archived')}
        </StatusBadge>
      ) : null}
      {phase && group.status === 'active' ? (
        <StatusBadge tone={phase === 'ongoing' ? 'success' : 'neutral'} icon={tripPhaseIcon[phase]}>
          {t(tripPhaseLabel[phase])}
        </StatusBadge>
      ) : null}
    </>
  );
}
