import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type {
  Goal,
  GoalContribution,
  GoalMember,
  GoalStatus,
  GoalType,
} from '@/shared/finance/types';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { GoalStatusFilter } from './api';

/*
 * Localized labels for goal enums. The maps are typed against the generated
 * unions, so a value added to the contract fails compilation until it has a
 * label.
 */

export const GOAL_TYPES = [
  'emergency_fund',
  'travel',
  'education',
  'device',
  'vehicle',
  'home',
  'event',
  'debt_payoff',
  'large_purchase',
  'custom',
] as const satisfies readonly GoalType[];

type MissingGoalTypes = Exclude<GoalType, (typeof GOAL_TYPES)[number]>;
/** Compile-time check: every contract goal type is listed above. */
export const goalTypesAreListed: [MissingGoalTypes] extends [never] ? true : MissingGoalTypes =
  true;

export const goalTypeLabel: Readonly<Record<GoalType, MessageKey>> = {
  emergency_fund: 'goals.type.emergency_fund',
  travel: 'goals.type.travel',
  education: 'goals.type.education',
  device: 'goals.type.device',
  vehicle: 'goals.type.vehicle',
  home: 'goals.type.home',
  event: 'goals.type.event',
  debt_payoff: 'goals.type.debt_payoff',
  large_purchase: 'goals.type.large_purchase',
  custom: 'goals.type.custom',
};

const goalTypeIcons: Readonly<Record<GoalType, IconName>> = {
  emergency_fund: 'shield',
  travel: 'globe',
  education: 'file-text',
  device: 'smartphone',
  vehicle: 'key',
  home: 'home',
  event: 'calendar',
  debt_payoff: 'credit-card',
  large_purchase: 'shopping-bag',
  custom: 'target',
};

export function isGoalType(value: string): value is GoalType {
  return (GOAL_TYPES as readonly string[]).includes(value);
}

export function goalTypeName(type: GoalType, t: Translate): string {
  return t(goalTypeLabel[type]);
}

export function goalTypeIcon(type: GoalType): IconName {
  return goalTypeIcons[type];
}

export const goalStatusLabel: Readonly<Record<GoalStatus, MessageKey>> = {
  active: 'goals.status.active',
  paused: 'goals.status.paused',
  achieved: 'goals.status.achieved',
  cancelled: 'goals.status.cancelled',
  archived: 'goals.status.archived',
};

export const goalStatusIcon: Readonly<Record<GoalStatus, IconName>> = {
  active: 'check-circle',
  paused: 'pause',
  achieved: 'flag',
  cancelled: 'x-circle',
  archived: 'archive',
};

export const goalStatusTone: Readonly<Record<GoalStatus, Tone>> = {
  active: 'info',
  paused: 'neutral',
  achieved: 'success',
  cancelled: 'neutral',
  archived: 'neutral',
};

export const GOAL_STATUS_FILTERS = [
  'active',
  'paused',
  'achieved',
  'cancelled',
  'archived',
  'all',
] as const satisfies readonly GoalStatusFilter[];

export const goalFilterLabel: Readonly<Record<GoalStatusFilter, MessageKey>> = {
  active: 'goals.filter.active',
  paused: 'goals.filter.paused',
  achieved: 'goals.filter.achieved',
  cancelled: 'goals.filter.cancelled',
  archived: 'goals.filter.archived',
  all: 'goals.filter.all',
};

export function isGoalStatusFilter(value: string | null): value is GoalStatusFilter {
  return value !== null && (GOAL_STATUS_FILTERS as readonly string[]).includes(value);
}

export type ContributionSchedule = Goal['contribution_schedule'];

export const CONTRIBUTION_SCHEDULES = [
  'none',
  'weekly',
  'biweekly',
  'monthly',
] as const satisfies readonly ContributionSchedule[];

export const scheduleLabel: Readonly<Record<ContributionSchedule, MessageKey>> = {
  none: 'goals.schedule.none',
  weekly: 'goals.schedule.weekly',
  biweekly: 'goals.schedule.biweekly',
  monthly: 'goals.schedule.monthly',
};

export function isContributionSchedule(value: string): value is ContributionSchedule {
  return (CONTRIBUTION_SCHEDULES as readonly string[]).includes(value);
}

/** 1 = highest priority (contract), 3 = the default. */
export const PRIORITIES = [1, 2, 3, 4, 5] as const;

const priorityLabels: Readonly<Record<(typeof PRIORITIES)[number], MessageKey>> = {
  1: 'goals.priority.1',
  2: 'goals.priority.2',
  3: 'goals.priority.3',
  4: 'goals.priority.4',
  5: 'goals.priority.5',
};

function isPriority(value: number): value is (typeof PRIORITIES)[number] {
  return (PRIORITIES as readonly number[]).includes(value);
}

export function priorityLabel(priority: number): MessageKey {
  return isPriority(priority) ? priorityLabels[priority] : 'goals.priority.3';
}

type ContributionStatus = GoalContribution['status'];

export const contributionStatusLabel: Readonly<Record<ContributionStatus, MessageKey>> = {
  planned: 'goals.contributions.status.planned',
  recorded: 'goals.contributions.status.recorded',
  verified: 'goals.contributions.status.verified',
};

export const contributionStatusIcon: Readonly<Record<ContributionStatus, IconName>> = {
  planned: 'clock',
  recorded: 'check',
  verified: 'shield-check',
};

export const contributionStatusTone: Readonly<Record<ContributionStatus, Tone>> = {
  planned: 'neutral',
  recorded: 'info',
  verified: 'success',
};

export const contributionKindLabel: Readonly<Record<GoalContribution['kind'], MessageKey>> = {
  contribution: 'goals.contributions.kind.contribution',
  withdrawal: 'goals.contributions.kind.withdrawal',
};

export const contributionKindIcon: Readonly<Record<GoalContribution['kind'], IconName>> = {
  contribution: 'plus',
  withdrawal: 'minus',
};

/** Roles in the members list: the owner (listed first by the API), contributors and viewers. */
export type GoalRole = GoalMember['role'];
/** Roles the owner can give someone (the owner's own role is fixed). */
export type MemberRole = Exclude<GoalRole, 'owner'>;
export type ContributionVisibility = GoalMember['contribution_visibility'];

export const MEMBER_ROLES = ['contributor', 'viewer'] as const satisfies readonly MemberRole[];

export const memberRoleLabel: Readonly<Record<GoalRole, MessageKey>> = {
  owner: 'goals.members.role.owner',
  contributor: 'goals.members.role.contributor',
  viewer: 'goals.members.role.viewer',
};

export const memberRoleHelp: Readonly<Record<MemberRole, MessageKey>> = {
  contributor: 'goals.members.roleHelp.contributor',
  viewer: 'goals.members.roleHelp.viewer',
};

export function isMemberRole(value: string): value is MemberRole {
  return (MEMBER_ROLES as readonly string[]).includes(value);
}

export const CONTRIBUTION_VISIBILITIES = [
  'amounts',
  'percent_only',
  'hidden',
] as const satisfies readonly ContributionVisibility[];

/** How another member's choice is described in the members list. */
export const memberVisibilityLabel: Readonly<Record<ContributionVisibility, MessageKey>> = {
  amounts: 'goals.members.visibility.amounts',
  percent_only: 'goals.members.visibility.percent_only',
  hidden: 'goals.members.visibility.hidden',
};

/** The choices offered to a member for their own contributions. */
export const myVisibilityLabel: Readonly<Record<ContributionVisibility, MessageKey>> = {
  amounts: 'goals.members.myVisibilityOption.amounts',
  percent_only: 'goals.members.myVisibilityOption.percent_only',
  hidden: 'goals.members.myVisibilityOption.hidden',
};

export function isContributionVisibility(value: string): value is ContributionVisibility {
  return (CONTRIBUTION_VISIBILITIES as readonly string[]).includes(value);
}
