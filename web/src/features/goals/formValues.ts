import type {
  Goal,
  GoalClearable,
  GoalInput,
  GoalMilestoneInput,
  GoalPatch,
} from '@/shared/finance/types';
import { compareDecimal, decimalToInput, isZeroDecimal } from '@/shared/formatting/decimal';
import { type ContributionSchedule, isContributionSchedule, isGoalType } from './labels';

export interface MilestoneValue {
  /** Whole number 1–100 as typed. */
  percent: string;
  label: string;
}

export interface GoalFormValues {
  name: string;
  /** A GoalType once chosen ('' until then). */
  goalType: string;
  currency: string;
  target: string;
  starting: string;
  startDate: string;
  targetDate: string;
  schedule: string;
  planned: string;
  priority: string;
  milestones: MilestoneValue[];
  linkedAccountId: string;
  groupId: string;
  visibility: 'private' | 'members';
  reminders: boolean;
  description: string;
  notes: string;
}

/** Exact canonical amounts after validation (decimal strings for the API). */
export interface GoalAmounts {
  target: string;
  starting: string | null;
  planned: string | null;
}

/** The API's default milestones. */
export const DEFAULT_MILESTONES = [25, 50, 75, 100] as const;
export const MAX_MILESTONES = 10;

export function emptyGoalValues(currency: string, today: string): GoalFormValues {
  return {
    name: '',
    goalType: '',
    currency,
    target: '',
    starting: '',
    startDate: today,
    targetDate: '',
    schedule: 'none',
    planned: '',
    priority: '3',
    milestones: DEFAULT_MILESTONES.map((percent) => ({ percent: String(percent), label: '' })),
    linkedAccountId: '',
    groupId: '',
    visibility: 'private',
    reminders: false,
    description: '',
    notes: '',
  };
}

export function goalToValues(goal: Goal, locale: string): GoalFormValues {
  return {
    name: goal.name,
    goalType: goal.goal_type,
    currency: goal.target.currency,
    target: decimalToInput(goal.target.amount, locale),
    starting: isZeroDecimal(goal.starting.amount)
      ? ''
      : decimalToInput(goal.starting.amount, locale),
    startDate: goal.start_date,
    targetDate: goal.target_date ?? '',
    schedule: goal.contribution_schedule,
    planned: goal.planned_contribution
      ? decimalToInput(goal.planned_contribution.amount, locale)
      : '',
    priority: String(goal.priority),
    milestones: goal.milestones.map((milestone) => ({
      percent: String(milestone.percent),
      label: milestone.label ?? '',
    })),
    linkedAccountId: goal.linked_account_id ?? '',
    groupId: goal.group_id ?? '',
    visibility: goal.visibility,
    reminders: goal.reminders_enabled,
    description: goal.description ?? '',
    notes: goal.notes ?? '',
  };
}

function scheduleOf(values: GoalFormValues): ContributionSchedule {
  return isContributionSchedule(values.schedule) ? values.schedule : 'none';
}

function milestoneInputs(values: GoalFormValues): GoalMilestoneInput[] {
  return values.milestones.map((milestone) => {
    const label = milestone.label.trim();
    return { percent: Number(milestone.percent), ...(label ? { label } : {}) };
  });
}

/** Sharing a goal with a group's members needs the group; without one it is private. */
function visibilityOf(values: GoalFormValues): GoalFormValues['visibility'] {
  return values.groupId ? values.visibility : 'private';
}

/** The request body for a new goal (the API fills defaults for what is left out). */
export function toGoalInput(values: GoalFormValues, amounts: GoalAmounts): GoalInput {
  const schedule = scheduleOf(values);
  const description = values.description.trim();
  const notes = values.notes.trim();
  return {
    name: values.name.trim(),
    goal_type: isGoalType(values.goalType) ? values.goalType : 'custom',
    currency: values.currency,
    target_amount: amounts.target,
    ...(amounts.starting ? { starting_amount: amounts.starting } : {}),
    start_date: values.startDate,
    ...(values.targetDate ? { target_date: values.targetDate } : {}),
    contribution_schedule: schedule,
    ...(schedule !== 'none' && amounts.planned ? { planned_contribution: amounts.planned } : {}),
    priority: Number(values.priority) || 3,
    milestones: milestoneInputs(values),
    ...(values.linkedAccountId ? { linked_account_id: values.linkedAccountId } : {}),
    ...(values.groupId ? { group_id: values.groupId } : {}),
    visibility: visibilityOf(values),
    reminders_enabled: values.reminders,
    ...(description ? { description } : {}),
    ...(notes ? { notes } : {}),
  };
}

function sameAmount(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return !a && !b;
  return compareDecimal(a, b) === 0;
}

function sameMilestones(goal: Goal, next: readonly GoalMilestoneInput[]): boolean {
  if (goal.milestones.length !== next.length) return false;
  return goal.milestones.every((milestone, index) => {
    const other = next[index];
    return other?.percent === milestone.percent && (other.label ?? '') === (milestone.label ?? '');
  });
}

/**
 * A partial update (PATCH /goals/{id}): only the fields the user changed,
 * always with the version they edited. Emptied text is sent as "" (the API
 * clears it); an emptied target date or planned amount is sent as "", an
 * emptied starting amount as "" (zero); a removed linked account or group is
 * named in `clear` (never sent and cleared at once). Milestones are sent only
 * when they changed, and then replace the whole list.
 */
export function toGoalPatch(values: GoalFormValues, amounts: GoalAmounts, goal: Goal): GoalPatch {
  const patch: GoalPatch = { version: goal.version };
  const clear: GoalClearable[] = [];

  const name = values.name.trim();
  if (name !== goal.name) patch.name = name;
  if (isGoalType(values.goalType) && values.goalType !== goal.goal_type) {
    patch.goal_type = values.goalType;
  }
  if (!sameAmount(amounts.target, goal.target.amount)) patch.target_amount = amounts.target;
  // An emptied starting amount means zero ("" sets it to zero).
  const starting = amounts.starting && !isZeroDecimal(amounts.starting) ? amounts.starting : null;
  const savedStarting = isZeroDecimal(goal.starting.amount) ? null : goal.starting.amount;
  if (!sameAmount(starting, savedStarting)) patch.starting_amount = starting ?? '';
  if (values.startDate !== goal.start_date) patch.start_date = values.startDate;
  if (values.targetDate !== (goal.target_date ?? '')) patch.target_date = values.targetDate;

  const schedule = scheduleOf(values);
  if (schedule !== goal.contribution_schedule) patch.contribution_schedule = schedule;
  const planned = schedule === 'none' ? null : amounts.planned;
  if (!sameAmount(planned, goal.planned_contribution?.amount)) {
    patch.planned_contribution = planned ?? '';
  }

  const priority = Number(values.priority) || 3;
  if (priority !== goal.priority) patch.priority = priority;
  const milestones = milestoneInputs(values);
  if (!sameMilestones(goal, milestones)) patch.milestones = milestones;

  if (values.linkedAccountId !== (goal.linked_account_id ?? '')) {
    if (values.linkedAccountId) patch.linked_account_id = values.linkedAccountId;
    else clear.push('linked_account_id');
  }
  if (values.groupId !== (goal.group_id ?? '')) {
    if (values.groupId) patch.group_id = values.groupId;
    else clear.push('group_id');
  }
  const visibility = visibilityOf(values);
  if (visibility !== goal.visibility) patch.visibility = visibility;
  if (values.reminders !== goal.reminders_enabled) patch.reminders_enabled = values.reminders;

  const description = values.description.trim();
  if (description !== (goal.description ?? '')) patch.description = description;
  const notes = values.notes.trim();
  if (notes !== (goal.notes ?? '')) patch.notes = notes;

  if (clear.length > 0) patch.clear = clear;
  return patch;
}
