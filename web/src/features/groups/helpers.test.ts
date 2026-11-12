import { describe, expect, it } from 'vitest';
import { ApiError } from '@/shared/api/errors';
import { createTranslator } from '@/shared/i18n/translate';
import {
  ADMIN_ID,
  EXPENSE_ID,
  GROUP_ID,
  GROUP_MEMBER_ID,
  ME,
  SETTLEMENT_ID,
  makeActivity,
  makeGroupDetailFull,
  makeMember,
  makeTripDetail,
} from '@/tests/groupsFixtures';
import { canChangeRole, canInvite, canRemoveMember } from './access';
import { describeActivity } from './activity';
import { groupConflictCode, groupErrorMessage, shouldReloadGroup } from './errors';
import { groupToValues, toCreateInput, toUpdateInput, validGroupValues } from './formValues';
import { tripPhase } from './labels';
import type { GroupActivity } from './types';

const t = createTranslator('en', 'en-US');

function rule(code: string) {
  return new ApiError({
    status: 422,
    code: 'DOMAIN_RULE_VIOLATION',
    message: 'English fallback',
    details: [{ message: 'English fallback', code }],
  });
}

function conflict(code?: string, params?: Record<string, string>) {
  return new ApiError({
    status: 409,
    code: 'CONFLICT',
    message: 'English fallback',
    details: code ? [{ message: 'English fallback', code, ...(params ? { params } : {}) }] : [],
  });
}

describe('describeActivity', () => {
  const context = {
    groupId: GROUP_ID,
    members: makeGroupDetailFull().members,
    myId: ME,
    t,
    locale: 'en-US',
  };

  it('links resolved disputes to what was disputed', () => {
    const dispute = (summary: GroupActivity['summary']) =>
      describeActivity(
        makeActivity({
          kind: 'dispute_resolved',
          entity_type: 'group_dispute',
          entity_id: GROUP_MEMBER_ID,
          summary,
        }),
        context,
      ).to;
    expect(dispute({ target: EXPENSE_ID, target_type: 'expense' })).toBe(
      `/groups/${GROUP_ID}/expenses/${EXPENSE_ID}`,
    );
    expect(dispute({ target: SETTLEMENT_ID, target_type: 'settlement' })).toBe(
      `/groups/${GROUP_ID}/settlements/${SETTLEMENT_ID}`,
    );
    // Older events carry no target_type; they were always expenses.
    expect(dispute({ target: EXPENSE_ID })).toBe(`/groups/${GROUP_ID}/expenses/${EXPENSE_ID}`);
    expect(dispute({})).toBeNull();
  });

  it('names people from the member list and links records', () => {
    expect(describeActivity(makeActivity(), context)).toEqual({
      text: 'Meera Rao added an expense: Groceries',
      icon: 'receipt',
      to: `/groups/${GROUP_ID}/expenses/${EXPENSE_ID}`,
    });
    expect(
      describeActivity(
        makeActivity({
          actor_id: ME,
          kind: 'ownership_transferred',
          entity_type: 'group_member',
          entity_id: GROUP_MEMBER_ID,
          summary: {},
        }),
        context,
      ).text,
    ).toBe('You made Meera Rao the owner');
    expect(
      describeActivity(
        makeActivity({
          actor_id: GROUP_MEMBER_ID,
          kind: 'member_role_changed',
          entity_type: 'group_member',
          entity_id: ME,
          summary: { role: 'admin' },
        }),
        context,
      ).text,
    ).toBe('Meera Rao made you an admin');
  });

  it('builds sentences from the typed summary, never from server text', () => {
    expect(
      describeActivity(
        makeActivity({
          actor_id: ME,
          kind: 'group_created',
          entity_type: 'group',
          entity_id: GROUP_ID,
          summary: { type: 'trip' },
        }),
        context,
      ),
    ).toEqual({ text: 'You created the group (Trip)', icon: 'plus', to: null });
    expect(
      describeActivity(
        makeActivity({
          kind: 'invitation_created',
          entity_type: 'group_invitation',
          summary: { kind: 'username' },
        }),
        context,
      ).text,
    ).toBe('Meera Rao invited someone by username');
    expect(
      describeActivity(
        makeActivity({
          summary: { description: 'Rent', recurring_rule_id: 'rule-1' },
        }),
        context,
      ),
    ).toEqual({
      text: 'Meera Rao added a recurring expense: Rent',
      icon: 'repeat',
      to: `/groups/${GROUP_ID}/expenses/${EXPENSE_ID}`,
    });
    expect(
      describeActivity(
        makeActivity({
          kind: 'recurring_expense_created',
          entity_type: 'group_recurring_expense',
          entity_id: 'rule-1',
          summary: { name: '  Electricity ' },
        }),
        context,
      ),
    ).toEqual({
      text: 'Meera Rao set up a recurring expense: Electricity',
      icon: 'repeat',
      to: `/groups/${GROUP_ID}/recurring`,
    });
  });

  it('uses only what the summary safely carries', () => {
    // A summary from the network may not match the contract: anything odd is ignored.
    expect(
      describeActivity(makeActivity({ summary: { description: 42 as unknown as string } }), context)
        .text,
    ).toBe('Meera Rao added an expense');
    expect(
      describeActivity(
        makeActivity({
          kind: 'recurring_expense_skipped',
          entity_type: 'group_recurring_expense',
          summary: { date: '2026-11-01' },
        }),
        context,
      ),
    ).toEqual({
      text: 'Meera Rao skipped the recurring expense due Nov 1, 2026',
      icon: 'skip-forward',
      to: `/groups/${GROUP_ID}/recurring`,
    });
    expect(
      describeActivity(
        makeActivity({
          actor_id: ADMIN_ID,
          kind: 'member_joined',
          entity_type: 'group_member',
          entity_id: GROUP_MEMBER_ID,
          summary: { via: 'join_request' },
        }),
        context,
      ).text,
    ).toBe('Someone let Meera Rao join the group');
    // A kind the API added after this client was built.
    expect(
      describeActivity(
        makeActivity({
          actor_id: undefined,
          kind: 'brand_new_kind' as GroupActivity['kind'],
          entity_type: 'group',
          summary: {},
        }),
        context,
      ),
    ).toEqual({ text: 'Someone made a change', icon: 'info', to: null });
  });
});

describe('group errors', () => {
  it('localizes the group rule codes, with context-specific sentences', () => {
    expect(groupErrorMessage(rule('balance_open'), t)).toBe(
      'Settle your balance before leaving the group.',
    );
    expect(
      groupErrorMessage(rule('balance_open'), t, {
        rules: { balance_open: 'groups.members.remove.balanceOpen' },
      }),
    ).toBe('This member still has an open balance. Settle it before removing them.');
    expect(groupErrorMessage(rule('transfer_ownership_first'), t)).toBe(
      'Transfer ownership to another member before you leave.',
    );
    expect(groupErrorMessage(rule('balances_open'), t)).toBe(
      'Settle all balances before deleting the group.',
    );
    expect(groupErrorMessage(rule('something_else'), t)).toBe('This change isn’t allowed.');
  });

  it('localizes the coded 409 conflicts, with context-specific sentences', () => {
    expect(groupConflictCode(conflict('already_member'))).toBe('already_member');
    expect(groupConflictCode(conflict())).toBeNull();
    expect(groupConflictCode(rule('balance_open'))).toBeNull();
    expect(groupErrorMessage(conflict('already_member'), t)).toBe(
      'This person is already a member.',
    );
    expect(groupErrorMessage(conflict('join_request_pending'), t)).toBe(
      'A request to join is already waiting for the admins.',
    );
    expect(
      groupErrorMessage(conflict('join_request_pending'), t, {
        conflicts: { join_request_pending: 'groups.joinRequest.pending' },
      }),
    ).toBe('Your request to join is already waiting for the admins.');
    expect(groupErrorMessage(conflict('invitation_used', { status: 'accepted' }), t)).toBe(
      'This invitation was already used, declined, cancelled or expired.',
    );
    // group_archived is a 409 now (it was a 422 rule); both read the same.
    expect(groupErrorMessage(conflict('group_archived'), t)).toBe(
      'This group is archived. Restore it to make changes.',
    );
    expect(groupErrorMessage(rule('group_archived'), t)).toBe(
      'This group is archived. Restore it to make changes.',
    );
    expect(groupErrorMessage(conflict('group_not_archived'), t)).toBe(
      'The group is no longer archived.',
    );
    // A conflict code this client does not know falls back to the action's own sentence.
    expect(
      groupErrorMessage(conflict('brand_new_conflict'), t, {
        codes: { CONFLICT: 'groups.invite.alreadyMember' },
      }),
    ).toBe('This person is already a member.');
  });

  it('names uncoded conflicts per action and reloads after state changes', () => {
    expect(
      groupErrorMessage(conflict(), t, { codes: { CONFLICT: 'groups.invite.alreadyMember' } }),
    ).toBe('This person is already a member.');
    expect(shouldReloadGroup(conflict())).toBe(true);
    expect(shouldReloadGroup(conflict('group_archived'))).toBe(true);
    expect(shouldReloadGroup(rule('group_archived'))).toBe(true);
    expect(shouldReloadGroup(rule('balance_open'))).toBe(false);
    expect(
      shouldReloadGroup(new ApiError({ status: 0, code: 'NETWORK_ERROR', message: 'x' })),
    ).toBe(false);
  });
});

describe('access', () => {
  const owner = makeGroupDetailFull();
  const admin = makeGroupDetailFull({ my_role: 'admin' });
  const member = makeMember();
  const otherAdmin = makeMember({ role: 'admin' });
  const theOwner = makeMember({ role: 'owner' });

  it('mirrors who may manage whom', () => {
    expect(canChangeRole(owner, otherAdmin, ME)).toBe(true);
    expect(canChangeRole(admin, member, ME)).toBe(true);
    expect(canChangeRole(admin, otherAdmin, ME)).toBe(false);
    expect(canChangeRole(admin, theOwner, ME)).toBe(false);
    expect(canChangeRole(makeGroupDetailFull({ status: 'archived' }), member, ME)).toBe(false);
    // Removing works in archived groups too; never yourself (that is leaving).
    expect(canRemoveMember(makeGroupDetailFull({ status: 'archived' }), member, ME)).toBe(true);
    expect(canRemoveMember(owner, makeMember({ user_id: ME }), ME)).toBe(false);
  });

  it('lets members invite only when the group allows it', () => {
    expect(canInvite(makeGroupDetailFull({ my_role: 'member', allow_member_invites: true }))).toBe(
      true,
    );
    expect(canInvite(makeGroupDetailFull({ my_role: 'member', allow_member_invites: false }))).toBe(
      false,
    );
    expect(canInvite(makeGroupDetailFull({ status: 'archived' }))).toBe(false);
  });
});

describe('trip phase', () => {
  it('compares calendar dates in the group’s zone', () => {
    const trip = { start_date: '2026-12-20', end_date: '2026-12-24' };
    expect(tripPhase(trip, '2026-12-19')).toBe('upcoming');
    expect(tripPhase(trip, '2026-12-20')).toBe('ongoing');
    expect(tripPhase(trip, '2026-12-24')).toBe('ongoing');
    expect(tripPhase(trip, '2026-12-25')).toBe('ended');
    // Without an end date it is a one-day trip or event (as the API's reminders assume).
    expect(tripPhase({ start_date: '2026-12-20' }, '2026-12-20')).toBe('ongoing');
    expect(tripPhase({ start_date: '2026-12-20' }, '2026-12-21')).toBe('ended');
    expect(tripPhase({}, '2026-12-21')).toBeNull();
  });
});

describe('form bodies', () => {
  it('sends only the changed settings with the edited version', () => {
    const group = makeGroupDetailFull({ description: 'Our flat', version: 7 });
    const values = validGroupValues({
      ...groupToValues(group),
      name: ' Flat 4B ',
      simplifyDebts: false,
      requireJoinApproval: false,
    });
    expect(toUpdateInput(group, values!)).toEqual({
      name: 'Flat 4B',
      simplify_debts: false,
      require_join_approval: false,
      version: 7,
    });
  });

  it('clears text with an empty string and trip details when the type changes', () => {
    const trip = makeTripDetail({ description: 'Beach week', version: 7 });
    const values = validGroupValues({
      ...groupToValues(trip),
      groupType: 'friends',
      description: '  ',
    });
    expect(toUpdateInput(trip, values!)).toEqual({
      group_type: 'friends',
      description: '',
      start_date: '',
      end_date: '',
      destination: '',
      version: 7,
    });
  });

  it('sends nothing when nothing changed', () => {
    const group = makeGroupDetailFull({ rules: 'Split groceries' });
    const values = validGroupValues({ ...groupToValues(group), rules: ' Split groceries ' });
    expect(toUpdateInput(group, values!)).toBeNull();
  });

  it('sends only filled fields on create', () => {
    const values = validGroupValues({
      ...groupToValues(makeGroupDetailFull()),
      name: ' Flat ',
      description: '  ',
    });
    expect(toCreateInput(values!)).toEqual({
      name: 'Flat',
      group_type: 'household',
      base_currency: 'INR',
      timezone: 'Asia/Kolkata',
      default_split_method: 'equal',
      simplify_debts: true,
      allow_member_invites: true,
      require_join_approval: true,
    });
  });
});
