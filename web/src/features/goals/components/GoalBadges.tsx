import { StatusBadge } from '@/shared/components/StatusBadge';
import type { Goal } from '@/shared/finance/types';
import { useT } from '@/shared/i18n/I18nContext';
import { goalStatusIcon, goalStatusLabel, goalStatusTone } from '../labels';
import { sharedWith } from '../people';

/** Status (when not active) and sharing, always as icon + text. */
export function GoalBadges({ goal }: { goal: Goal }) {
  const t = useT();
  // The owner is listed among the members; count only the people it is shared with.
  const memberCount = sharedWith(goal).length;
  return (
    <div className="flex flex-wrap gap-2">
      {goal.status !== 'active' ? (
        <StatusBadge tone={goalStatusTone[goal.status]} icon={goalStatusIcon[goal.status]}>
          {t(goalStatusLabel[goal.status])}
        </StatusBadge>
      ) : null}
      {goal.access === 'contributor' ? (
        <StatusBadge tone="info" icon="users">
          {t('goals.access.contributor')}
        </StatusBadge>
      ) : null}
      {goal.access === 'viewer' ? (
        <StatusBadge tone="info" icon="eye">
          {t('goals.access.viewer')}
        </StatusBadge>
      ) : null}
      {goal.access === 'owner' && memberCount > 0 ? (
        <StatusBadge tone="neutral" icon="share">
          {t('goals.access.shared', { count: memberCount })}
        </StatusBadge>
      ) : null}
    </div>
  );
}
