import type {
  Goal,
  GoalContribution,
  GoalForecast,
  GoalMember,
  GoalReport,
} from '@/shared/finance/types';
import { makeUser } from './fixtures';
import { money } from './financeFixtures';
import { FRIEND_ID } from './sharingFixtures';

/** Goal fixtures shaped like the contract (tests only). */

export const GOAL_TRIP = 'a0a0a0a0-1111-4111-8111-000000000001';
export const GOAL_FUND = 'a0a0a0a0-1111-4111-8111-000000000002';
export const CONTRIBUTION_MINE = 'b0b0b0b0-2222-4222-8222-000000000001';
export const CONTRIBUTION_FRIEND = 'b0b0b0b0-2222-4222-8222-000000000002';
export const CONTRIBUTION_PLANNED = 'b0b0b0b0-2222-4222-8222-000000000003';
export const CONTRIBUTION_WITHDRAWAL = 'b0b0b0b0-2222-4222-8222-000000000004';
export const CONTRIBUTION_HIDDEN = 'b0b0b0b0-2222-4222-8222-000000000005';
export const TX_TO_SAVINGS = '77777777-7777-4777-8777-777777777799';

/** The signed-in test user (makeUser) as a goal member. */
export const ME = makeUser().id;
/** Someone else who owns a goal shared with the signed-in user. */
export const OTHER_OWNER = 'c0c0c0c0-3333-4333-8333-000000000001';

/** The owner as the API lists them: the first member, with role `owner`. */
export function makeOwnerMember(overrides: Partial<GoalMember> = {}): GoalMember {
  return {
    user_id: ME,
    display_name: 'Asha Rao',
    role: 'owner',
    contribution_visibility: 'amounts',
    joined_at: '2026-11-01T08:00:00Z',
    ...overrides,
  };
}

export function makeGoal(overrides: Partial<Goal> = {}): Goal {
  return {
    id: GOAL_TRIP,
    name: 'Goa trip',
    goal_type: 'travel',
    target: money('60000.00'),
    starting: money('1000.00'),
    start_date: '2026-11-01',
    target_date: '2027-06-30',
    priority: 3,
    contribution_schedule: 'monthly',
    planned_contribution: money('5000.00'),
    visibility: 'private',
    reminders_enabled: false,
    status: 'active',
    access: 'owner',
    progress: {
      saved: money('6000.00'),
      remaining: money('54000.00'),
      percent_bp: 1000,
      verified: money('3000.00'),
      planned: money('2000.00'),
      contribution_count: 2,
    },
    milestones: [
      { percent: 10, label: 'First step', reached_at: '2026-11-04T06:30:00Z' },
      { percent: 50 },
      { percent: 100 },
    ],
    owner_user_id: ME,
    owner: { user_id: ME, display_name: 'Asha Rao' },
    members: [makeOwnerMember()],
    version: 4,
    created_at: '2026-11-01T08:00:00Z',
    ...overrides,
  };
}

/**
 * A goal someone else (Kiran) owns and shared with the signed-in user, who
 * is listed after the owner with `mine` (role and visibility).
 */
export function makeSharedGoal(
  access: 'contributor' | 'viewer',
  mine: Partial<GoalMember> = {},
  overrides: Partial<Goal> = {},
): Goal {
  return makeGoal({
    access,
    owner_user_id: OTHER_OWNER,
    owner: { user_id: OTHER_OWNER, display_name: 'Kiran Shah' },
    members: [
      makeOwnerMember({ user_id: OTHER_OWNER, display_name: 'Kiran Shah' }),
      makeGoalMember({ user_id: ME, display_name: 'Asha Rao', role: access, ...mine }),
    ],
    ...overrides,
  });
}

export function makeGoalMember(overrides: Partial<GoalMember> = {}): GoalMember {
  return {
    user_id: FRIEND_ID,
    display_name: 'Ravi Kumar',
    role: 'contributor',
    contribution_visibility: 'amounts',
    joined_at: '2026-11-02T10:00:00Z',
    ...overrides,
  };
}

export function makeContribution(overrides: Partial<GoalContribution> = {}): GoalContribution {
  return {
    id: CONTRIBUTION_MINE,
    user_id: ME,
    display_name: 'Asha Rao',
    kind: 'contribution',
    amount: money('5000.00'),
    status: 'recorded',
    contributed_on: '2026-11-04',
    voided: false,
    mine: true,
    created_at: '2026-11-04T06:30:00Z',
    ...overrides,
  };
}

export function makeForecast(overrides: Partial<GoalForecast> = {}): GoalForecast {
  return {
    saved: money('6000.00'),
    remaining: money('54000.00'),
    target: money('60000.00'),
    target_date: '2027-06-30',
    days_left: 237,
    required_per_month: money('7714.29'),
    required_per_week: money('1588.24'),
    recent_monthly_pace: money('1666.67'),
    projected_completion: '2029-08-05',
    planned_completion: '2027-10-05',
    on_track: false,
    achieved: false,
    assumption_codes: ['exact_amounts_no_growth', 'recent_pace_window', 'planned_not_counted'],
    assumption_params: { currency: 'INR', window_days: '90', months: '3' },
    assumptions: [
      'Amounts are exact in INR; no interest, returns or inflation are assumed.',
      'Recent pace is the net of recorded and verified contributions in the last 90 days divided by 3.',
      'Planned contributions are intentions, not money movements, and are not counted as saved.',
    ],
    ...overrides,
  };
}

export function makeGoalReport(overrides: Partial<GoalReport> = {}): GoalReport {
  return {
    goals: [makeGoal()],
    totals: [
      {
        currency: 'INR',
        target: money('60000.00'),
        saved: money('6000.00'),
        count: 1,
        achieved: 0,
      },
    ],
    ...overrides,
  };
}
