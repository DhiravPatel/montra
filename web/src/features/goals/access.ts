import type { Goal, GoalContribution } from '@/shared/finance/types';

/** Owners and contributors can add money while the goal is active. */
export function canContribute(goal: Goal): boolean {
  return goal.status === 'active' && (goal.access === 'owner' || goal.access === 'contributor');
}

/**
 * Your own planned contribution can be recorded while the goal accepts money
 * (an achieved goal still accepts withdrawals), as the API decides.
 */
export function canRecordPlanned(goal: Goal, contribution: GoalContribution): boolean {
  if (!contribution.mine || contribution.voided || contribution.status !== 'planned') return false;
  if (goal.access === 'viewer') return false;
  return (
    goal.status === 'active' || (goal.status === 'achieved' && contribution.kind === 'withdrawal')
  );
}
