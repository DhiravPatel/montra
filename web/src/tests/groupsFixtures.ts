import { http, HttpResponse } from 'msw';
import type {
  Group,
  GroupActivity,
  GroupActivityPage,
  GroupBalances,
  GroupDetail,
  GroupInvitation,
  GroupMember,
  GroupMemberBalance,
  GroupPerson,
  InvitationPreview,
  JoinRequest,
} from '@/features/groups/types';
import { API, envelope, makeUser } from './fixtures';
import { money } from './financeFixtures';
import { FRIEND_ID, GROUP_ID, GROUP_MEMBER_ID } from './sharingFixtures';

/** Group fixtures shaped like the contract (tests only). */

export { GROUP_ID, GROUP_MEMBER_ID, FRIEND_ID };
/** The signed-in test user (makeUser). */
export const ME = makeUser().id;
export const TRIP_ID = 'c1c1c1c1-3333-4333-8333-000000000001';
export const ADMIN_ID = 'd2d2d2d2-4444-4444-8444-000000000001';
export const FORMER_ID = 'd2d2d2d2-4444-4444-8444-000000000002';
export const INVITATION_ID = 'e3e3e3e3-5555-4555-8555-000000000001';
export const LINK_INVITATION_ID = 'e3e3e3e3-5555-4555-8555-000000000002';
export const REQUEST_ID = 'f4f4f4f4-6666-4666-8666-000000000001';
export const EXPENSE_ID = 'a5a5a5a5-7777-4777-8777-000000000001';
export const SETTLEMENT_ID = 'a5a5a5a5-7777-4777-8777-000000000002';
/** A link token as the API creates them (24 random bytes, base64url). */
export const LINK_TOKEN = 'Qm9uZFRva2VuLUZvclRlc3RzLTEyMzQ1Njc4';

export function makeMember(overrides: Partial<GroupMember> = {}): GroupMember {
  return {
    user_id: GROUP_MEMBER_ID,
    display_name: 'Meera Rao',
    username: 'meera',
    role: 'member',
    status: 'active',
    notification_level: 'all',
    joined_at: '2026-10-02T08:30:00Z',
    ...overrides,
  };
}

/** The signed-in user as a member (owner unless overridden). */
export function makeMe(overrides: Partial<GroupMember> = {}): GroupMember {
  return makeMember({
    user_id: ME,
    display_name: 'Asha Rao',
    username: 'asha',
    role: 'owner',
    joined_at: '2026-10-01T08:30:00Z',
    ...overrides,
  });
}

export function makeGroupDTO(overrides: Partial<Group> = {}): Group {
  return {
    id: GROUP_ID,
    name: 'Home',
    group_type: 'household',
    base_currency: 'INR',
    timezone: 'Asia/Kolkata',
    default_split_method: 'equal',
    simplify_debts: true,
    allow_member_invites: true,
    require_join_approval: true,
    status: 'active',
    my_role: 'owner',
    member_count: 2,
    my_net: money('0.00'),
    version: 3,
    created_at: '2026-10-01T08:30:00Z',
    ...overrides,
  };
}

/** The signed-in user as the API names people (invited_by / invitee). */
export function mePerson(): GroupPerson {
  return { user_id: ME, display_name: 'Asha Rao', username: 'asha' };
}

export function meeraPerson(): GroupPerson {
  return { user_id: GROUP_MEMBER_ID, display_name: 'Meera Rao', username: 'meera' };
}

/** A household with the user (owner by default) and one member. */
export function makeGroupDetailFull(
  overrides: Partial<GroupDetail> = {},
  me: Partial<GroupMember> = {},
): GroupDetail {
  const role = overrides.my_role ?? 'owner';
  return {
    ...makeGroupDTO(),
    members: [makeMe({ role: role === 'none' ? 'member' : role, ...me }), makeMember()],
    ...overrides,
  };
}

export function makeTripDetail(overrides: Partial<GroupDetail> = {}): GroupDetail {
  return makeGroupDetailFull({
    id: TRIP_ID,
    name: 'Goa trip',
    group_type: 'trip',
    start_date: '2026-12-20',
    end_date: '2026-12-24',
    destination: 'Goa',
    ...overrides,
  });
}

/** Meera invited the signed-in user by username. */
export function makeInvitation(overrides: Partial<GroupInvitation> = {}): GroupInvitation {
  return {
    id: INVITATION_ID,
    group_id: GROUP_ID,
    group_name: 'Home',
    kind: 'username',
    invitee_user_id: ME,
    invitee: mePerson(),
    invited_by: meeraPerson(),
    max_uses: 1,
    use_count: 0,
    status: 'active',
    expires_at: '2026-11-12T09:00:00Z',
    created_at: '2026-11-05T09:00:00Z',
    ...overrides,
  };
}

/** A link the signed-in user created. */
export function makeLinkInvitation(overrides: Partial<GroupInvitation> = {}): GroupInvitation {
  return makeInvitation({
    id: LINK_INVITATION_ID,
    kind: 'link',
    invitee_user_id: undefined,
    invitee: undefined,
    invited_by: mePerson(),
    max_uses: 5,
    use_count: 2,
    ...overrides,
  });
}

/** A link to the trip, created by Meera; the user is not a member yet. */
export function makePreview(overrides: Partial<InvitationPreview> = {}): InvitationPreview {
  return {
    group_id: TRIP_ID,
    group_name: 'Goa trip',
    group_type: 'trip',
    member_count: 4,
    invited_by: { display_name: 'Meera Rao', username: 'meera' },
    already_member: false,
    requires_approval: false,
    status: 'active',
    expires_at: '2026-11-12T09:00:00Z',
    ...overrides,
  };
}

export function makeJoinRequest(overrides: Partial<JoinRequest> = {}): JoinRequest {
  return {
    id: REQUEST_ID,
    group_id: GROUP_ID,
    user_id: FRIEND_ID,
    display_name: 'Ravi Kumar',
    message: 'Hi, it’s Ravi from the flat downstairs',
    status: 'pending',
    created_at: '2026-11-04T10:00:00Z',
    ...overrides,
  };
}

let activityId = 100;

export function makeActivity(overrides: Partial<GroupActivity> = {}): GroupActivity {
  activityId += 1;
  return {
    id: activityId,
    actor_id: GROUP_MEMBER_ID,
    kind: 'expense_added',
    entity_type: 'group_expense',
    entity_id: EXPENSE_ID,
    summary: { description: 'Groceries' },
    created_at: '2026-11-04T10:00:00Z',
    ...overrides,
  };
}

export function makeActivityPage(
  events: GroupActivity[] = [makeActivity()],
  nextBefore?: number,
): GroupActivityPage {
  return nextBefore === undefined ? { events } : { events, next_before: nextBefore };
}

function memberBalance(overrides: Partial<GroupMemberBalance> = {}): GroupMemberBalance {
  return {
    user_id: ME,
    display_name: 'Asha Rao',
    member_status: 'active',
    paid: money('0.00'),
    share: money('0.00'),
    settlements_sent: money('0.00'),
    settlements_received: money('0.00'),
    net: money('0.00'),
    pending_out: money('0.00'),
    pending_in: money('0.00'),
    ...overrides,
  };
}

/** Balances as the API derives them; `myNet` is the signed decimal for the user. */
export function makeBalances(
  myNet = '0.00',
  overrides: Partial<GroupBalances> = {},
  mine: Partial<GroupMemberBalance> = {},
): GroupBalances {
  return {
    group_id: GROUP_ID,
    currency: 'INR',
    balances: [
      memberBalance({ net: money(myNet), ...mine }),
      memberBalance({
        user_id: GROUP_MEMBER_ID,
        display_name: 'Meera Rao',
        net: money(
          myNet.startsWith('-') ? myNet.slice(1) : myNet === '0.00' ? '0.00' : `-${myNet}`,
        ),
      }),
    ],
    my_net: money(myNet),
    original_debts: [],
    simplified: [],
    simplify_enabled: true,
    disputed_expenses: 0,
    computed_at: '2026-11-05T09:00:00Z',
    ...overrides,
  };
}

/**
 * Read handlers for one group's pages: details, balances and activity.
 * `state.group` can be swapped by a test to change what later reads return.
 */
export function groupReadHandlers(
  initial: GroupDetail,
  {
    balances = makeBalances(),
    activity = makeActivityPage(),
  }: { balances?: GroupBalances; activity?: GroupActivityPage } = {},
) {
  const state = { group: initial };
  return {
    state,
    handlers: [
      http.get(`${API}/groups/:id`, () => HttpResponse.json(envelope(state.group))),
      http.get(`${API}/groups/:id/balances`, () => HttpResponse.json(envelope(balances))),
      http.get(`${API}/groups/:id/activity`, () => HttpResponse.json(envelope(activity))),
    ],
  };
}
