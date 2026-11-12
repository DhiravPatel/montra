import { describe, expect, it } from 'vitest';
import { type CreateValues, emptyCreateValues, parseTarget, toChallengeInput } from './formValues';
import { checkInWindow } from './progress';
import { sharingBody } from './sharing';

const GROUP = '5b3c8e6f-1a7d-4b4c-8f6e-7d8c9b0a1fc5';

function values(overrides: Partial<CreateValues> = {}): CreateValues {
  return {
    ...emptyCreateValues('2026-11-05'),
    title: '  Cook at home ',
    challengeType: 'meal_planning',
    target: '7',
    endsOn: '2026-11-30',
    ...overrides,
  };
}

describe('parseTarget', () => {
  it('accepts whole numbers within the API range for the metric', () => {
    expect(parseTarget('7', 'days')).toBe(7);
    expect(parseTarget('3650', 'milestones')).toBe(3650);
    expect(parseTarget('100', 'percent')).toBe(100);
    expect(parseTarget('101', 'percent')).toBeNull();
    expect(parseTarget('0', 'days')).toBeNull();
    expect(parseTarget('2.5', 'days')).toBeNull();
    expect(parseTarget('3651', 'streak')).toBeNull();
  });
});

describe('toChallengeInput', () => {
  it('sends a private challenge without a leaderboard or empty text', () => {
    expect(toChallengeInput(values({ leaderboard: true }))).toEqual({
      title: 'Cook at home',
      challenge_type: 'meal_planning',
      metric: 'days',
      target_value: 7,
      starts_on: '2026-11-05',
      ends_on: '2026-11-30',
      visibility: 'private',
      leaderboard_enabled: false,
    });
  });

  it('names only the chosen group or community', () => {
    const input = toChallengeInput(
      values({ visibility: 'group', groupId: GROUP, communityId: 'ignored', leaderboard: true }),
    );
    expect(input).toMatchObject({
      visibility: 'group',
      group_id: GROUP,
      leaderboard_enabled: true,
    });
    expect(input).not.toHaveProperty('community_id');
  });

  it('starts with the group or community from the link', () => {
    expect(emptyCreateValues('2026-11-05', { groupId: GROUP })).toMatchObject({
      visibility: 'group',
      groupId: GROUP,
      communityId: '',
    });
    expect(emptyCreateValues('2026-11-05', { communityId: GROUP })).toMatchObject({
      visibility: 'community',
      communityId: GROUP,
    });
  });
});

describe('sharingBody', () => {
  it('never asks for the leaderboard without sharing or when the challenge has none', () => {
    expect(sharingBody({ share: false, leaderboard: true }, true)).toEqual({
      share_progress: false,
      show_on_leaderboard: false,
    });
    expect(sharingBody({ share: true, leaderboard: true }, false)).toEqual({
      share_progress: true,
      show_on_leaderboard: false,
    });
    expect(sharingBody({ share: true, leaderboard: true }, true)).toEqual({
      share_progress: true,
      show_on_leaderboard: true,
    });
  });
});

describe('checkInWindow', () => {
  it('runs from the start to today, or to the end once it has passed', () => {
    expect(checkInWindow({ starts_on: '2026-11-01', ends_on: '2026-11-30' }, '2026-11-05')).toEqual(
      {
        first: '2026-11-01',
        last: '2026-11-05',
        open: true,
      },
    );
    expect(checkInWindow({ starts_on: '2026-10-01', ends_on: '2026-10-31' }, '2026-11-05')).toEqual(
      {
        first: '2026-10-01',
        last: '2026-10-31',
        open: true,
      },
    );
    expect(
      checkInWindow({ starts_on: '2026-11-10', ends_on: '2026-11-30' }, '2026-11-05').open,
    ).toBe(false);
  });
});
