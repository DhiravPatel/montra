import type { Group, GroupDetail, PublicProfile } from '@/shared/finance/types';
import { money } from './financeFixtures';

/** People and groups for sharing budgets and goals (tests only). */
export const FRIEND_ID = '5d2f9a3e-8b1c-4e7a-9f60-1a2b3c4d5e6f';
export const GROUP_ID = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';
export const GROUP_MEMBER_ID = '2b3c4d5e-6f70-4812-9a3b-4c5d6e7f8091';

export function makeFriend(overrides: Partial<PublicProfile> = {}): PublicProfile {
  return {
    user_id: FRIEND_ID,
    display_name: 'Ravi Kumar',
    username: 'ravi',
    connection: 'friend',
    blocked_by_me: false,
    muted: false,
    ...overrides,
  };
}

export function makeGroup(overrides: Partial<Group> = {}): Group {
  return {
    id: GROUP_ID,
    name: 'Home',
    group_type: 'household',
    base_currency: 'INR',
    timezone: 'Asia/Kolkata',
    default_split_method: 'equal',
    simplify_debts: true,
    allow_member_invites: true,
    require_join_approval: false,
    status: 'active',
    my_role: 'owner',
    member_count: 2,
    my_net: money('0.00'),
    version: 1,
    created_at: '2026-10-01T08:30:00Z',
    ...overrides,
  };
}

export function makeGroupDetail(overrides: Partial<GroupDetail> = {}): GroupDetail {
  return {
    ...makeGroup(),
    members: [
      {
        user_id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
        display_name: 'Asha Rao',
        role: 'owner',
        status: 'active',
        notification_level: 'all',
        joined_at: '2026-10-01T08:30:00Z',
      },
      {
        user_id: GROUP_MEMBER_ID,
        display_name: 'Meera Rao',
        username: 'meera',
        role: 'member',
        status: 'active',
        notification_level: 'all',
        joined_at: '2026-10-02T08:30:00Z',
      },
    ],
    ...overrides,
  };
}
