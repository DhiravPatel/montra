import { describe, expect, it } from 'vitest';
import { money } from '@/tests/financeFixtures';
import { makeGoal } from '@/tests/goalsFixtures';
import { ACCOUNT_CASH } from '@/tests/financeFixtures';
import { GROUP_ID } from '@/tests/sharingFixtures';
import { type GoalAmounts, type GoalFormValues, goalToValues, toGoalPatch } from './formValues';

const LOCALE = 'en-IN';

/** The loaded goal's values and exact amounts, as the edit form starts. */
function start(goal = makeGoal()): { values: GoalFormValues; amounts: GoalAmounts } {
  return {
    values: goalToValues(goal, LOCALE),
    amounts: {
      target: goal.target.amount,
      starting: goal.starting.amount,
      planned: goal.planned_contribution?.amount ?? null,
    },
  };
}

describe('toGoalPatch', () => {
  it('sends only the version when nothing changed', () => {
    const goal = makeGoal({
      linked_account_id: ACCOUNT_CASH,
      group_id: GROUP_ID,
      visibility: 'members',
      description: 'Beach week',
      notes: 'Book early',
    });
    const { values, amounts } = start(goal);
    expect(toGoalPatch(values, amounts, goal)).toEqual({ version: 4 });
  });

  it('sends changed fields, clears emptied text with "" and keeps milestones when untouched', () => {
    const goal = makeGoal({ description: 'Beach week', notes: 'Book early' });
    const { values, amounts } = start(goal);
    const patch = toGoalPatch(
      {
        ...values,
        name: ' Goa trip 2027 ',
        goalType: 'event',
        description: '   ',
        notes: '',
        targetDate: '',
        priority: '1',
        reminders: true,
      },
      { ...amounts, target: '65000.00' },
      goal,
    );
    expect(patch).toEqual({
      version: 4,
      name: 'Goa trip 2027',
      goal_type: 'event',
      target_amount: '65000.00',
      target_date: '',
      priority: 1,
      reminders_enabled: true,
      description: '',
      notes: '',
    });
    expect(patch).not.toHaveProperty('milestones');
    expect(patch).not.toHaveProperty('starting_amount');
  });

  it('names a removed linked account and group in clear (never sent and cleared at once)', () => {
    const goal = makeGoal({
      linked_account_id: ACCOUNT_CASH,
      group_id: GROUP_ID,
      visibility: 'members',
    });
    const { values, amounts } = start(goal);
    const patch = toGoalPatch({ ...values, linkedAccountId: '', groupId: '' }, amounts, goal);
    expect(patch).toEqual({
      version: 4,
      // Without a group the goal is private again.
      visibility: 'private',
      clear: ['linked_account_id', 'group_id'],
    });
    expect(patch).not.toHaveProperty('linked_account_id');
    expect(patch).not.toHaveProperty('group_id');
  });

  it('sends a newly chosen link instead of clearing it', () => {
    const goal = makeGoal();
    const { values, amounts } = start(goal);
    expect(
      toGoalPatch(
        { ...values, linkedAccountId: ACCOUNT_CASH, groupId: GROUP_ID, visibility: 'members' },
        amounts,
        goal,
      ),
    ).toEqual({
      version: 4,
      linked_account_id: ACCOUNT_CASH,
      group_id: GROUP_ID,
      visibility: 'members',
    });
  });

  it('clears the planned amount when the schedule is turned off', () => {
    const goal = makeGoal();
    const { values, amounts } = start(goal);
    expect(toGoalPatch({ ...values, schedule: 'none' }, amounts, goal)).toEqual({
      version: 4,
      contribution_schedule: 'none',
      planned_contribution: '',
    });
  });

  it('compares amounts exactly and sets an emptied starting amount to zero', () => {
    const goal = makeGoal({ starting: money('1000.00') });
    const { values, amounts } = start(goal);
    // The same values in another spelling are not a change.
    expect(toGoalPatch(values, { ...amounts, target: '60000.0' }, goal)).toEqual({ version: 4 });
    expect(toGoalPatch({ ...values, starting: '' }, { ...amounts, starting: null }, goal)).toEqual({
      version: 4,
      starting_amount: '',
    });
    expect(toGoalPatch(values, { ...amounts, planned: '4500.00' }, goal)).toEqual({
      version: 4,
      planned_contribution: '4500.00',
    });
  });

  it('replaces the whole milestone list when it changed', () => {
    const goal = makeGoal();
    const { values, amounts } = start(goal);
    const milestones = [...values.milestones.slice(0, 2), { percent: '75', label: ' Almost ' }];
    expect(toGoalPatch({ ...values, milestones }, amounts, goal)).toEqual({
      version: 4,
      milestones: [
        { percent: 10, label: 'First step' },
        { percent: 50 },
        { percent: 75, label: 'Almost' },
      ],
    });
    expect(toGoalPatch({ ...values, milestones: [] }, amounts, goal)).toEqual({
      version: 4,
      milestones: [],
    });
  });
});
