import type { Goal, GoalMember } from '@/shared/finance/types';
import type { Translate } from '@/shared/i18n/types';

/**
 * The people on the goal, owner first. The API lists the owner as the first
 * member (role `owner`); an older answer without that row gets one built
 * from `owner` so the list always starts with the owner.
 */
export function goalPeople(goal: Goal): GoalMember[] {
  if (goal.members.some((member) => member.role === 'owner')) return goal.members;
  const owner: GoalMember = {
    user_id: goal.owner.user_id,
    display_name: goal.owner.display_name ?? '',
    role: 'owner',
    contribution_visibility: 'amounts',
    joined_at: goal.created_at,
  };
  return [owner, ...goal.members];
}

/** A member's name; the API leaves it out when their profile is not visible to you. */
export function memberName(member: Pick<GoalMember, 'display_name'>, t: Translate): string {
  return member.display_name ?? t('goals.members.hiddenName');
}

/** People the goal is shared with (everyone but the owner). */
export function sharedWith(goal: Goal): GoalMember[] {
  return goal.members.filter((member) => member.role !== 'owner');
}
