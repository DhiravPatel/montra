import type {
  GroupBalances,
  GroupDetail,
  GroupExpense,
  GroupExpenseDetail,
  GroupRecurring,
  GroupReport,
  GroupSuggestions,
  GroupTransfer,
  MemberBalance,
  Occurrence,
  Settlement,
} from '@/features/group-money/types';
import { money } from './financeFixtures';
import { envelope, makeUser } from './fixtures';
import { testBackend } from './msw/backend';
import { GROUP_ID, GROUP_MEMBER_ID, makeGroupDetail } from './sharingFixtures';

/** Group money test data (tests only). The signed-in person is Asha (makeUser()). */
export const MONEY_GROUP = GROUP_ID;
export const ME = makeUser().id;
export const MEERA = GROUP_MEMBER_ID;
export const RAVI = '3c4d5e6f-7081-4923-8b4c-5d6e7f809102';
export const EXPENSE_ID = 'e1e1e1e1-0000-4000-8000-000000000001';
export const EXPENSE_2 = 'e1e1e1e1-0000-4000-8000-000000000002';
export const SETTLEMENT_ID = '5e5e5e5e-0000-4000-8000-000000000001';
export const SETTLEMENT_2 = '5e5e5e5e-0000-4000-8000-000000000002';
export const RULE_ID = '7a7a7a7a-0000-4000-8000-000000000001';
export const OCCURRENCE_DUE = '0c0c0c0c-0000-4000-8000-000000000001';
export const OCCURRENCE_NEXT = '0c0c0c0c-0000-4000-8000-000000000002';
export const FILE_ID = 'f1f1f1f1-0000-4000-8000-000000000001';

/** A household with three active members; Asha (the signed-in person) owns it. */
export function makeMoneyGroup(overrides: Partial<GroupDetail> = {}): GroupDetail {
  const base = makeGroupDetail();
  return {
    ...base,
    name: 'Flat 4B',
    member_count: 3,
    members: [
      ...base.members,
      {
        user_id: RAVI,
        display_name: 'Ravi Kumar',
        username: 'ravi',
        role: 'member',
        status: 'active',
        notification_level: 'all',
        joined_at: '2026-10-03T08:30:00Z',
      },
    ],
    ...overrides,
  };
}

/** The household after an admin removed Ravi (his records and balance stay). */
export function makeGroupWithFormerMember(overrides: Partial<GroupDetail> = {}): GroupDetail {
  const group = makeMoneyGroup();
  return {
    ...group,
    member_count: 2,
    members: group.members.map((member) =>
      member.user_id === RAVI ? { ...member, status: 'removed' } : member,
    ),
    ...overrides,
  };
}

/** Serves the group from the default GET /groups/:id handler. */
export function serveMoneyGroup(group: GroupDetail = makeMoneyGroup()): GroupDetail {
  testBackend.groupDetails[group.id] = group;
  return group;
}

/** One cursor page of GET /groups/{id}/expenses, as the API answers it. */
export function expensesPage(items: GroupExpense[], nextCursor?: string) {
  const page = envelope(items);
  return {
    ...page,
    meta: {
      ...page.meta,
      has_more: nextCursor !== undefined,
      ...(nextCursor !== undefined ? { next_cursor: nextCursor } : {}),
    },
  };
}

export function makeGroupExpense(overrides: Partial<GroupExpense> = {}): GroupExpense {
  return {
    id: EXPENSE_ID,
    group_id: MONEY_GROUP,
    description: 'Groceries',
    category_key: 'groceries',
    amount: money('100.00'),
    expense_date: '2026-11-04',
    split_method: 'equal',
    payers: [{ user_id: ME, paid: money('100.00') }],
    shares: [
      { user_id: ME, share: money('33.34') },
      { user_id: MEERA, share: money('33.33') },
      { user_id: RAVI, share: money('33.33') },
    ],
    my_share: money('33.34'),
    my_paid: money('100.00'),
    status: 'active',
    created_by: ME,
    version: 1,
    created_at: '2026-11-04T10:00:00Z',
    ...overrides,
  };
}

export function makeExpenseDetail(overrides: Partial<GroupExpenseDetail> = {}): GroupExpenseDetail {
  return {
    ...makeGroupExpense(),
    items: [],
    comments: [],
    disputes: [],
    revisions: 1,
    ...overrides,
  };
}

function transfer(
  from: string,
  fromName: string,
  to: string,
  toName: string,
  amount: string,
): GroupTransfer {
  return {
    from_user_id: from,
    from_name: fromName,
    to_user_id: to,
    to_name: toName,
    amount: money(amount),
    involves_me: from === ME || to === ME,
  };
}

function memberBalance(
  userId: string,
  name: string,
  values: { paid: string; share: string; net: string },
): MemberBalance {
  return {
    user_id: userId,
    display_name: name,
    member_status: 'active',
    paid: money(values.paid),
    share: money(values.share),
    settlements_sent: money('0.00'),
    settlements_received: money('0.00'),
    net: money(values.net),
    pending_in: money('0.00'),
    pending_out: money('0.00'),
  };
}

/** Asha paid 1000.00 and is owed 500.00; Meera owes 300.00 and Ravi owes 200.00. */
export function makeBalances(overrides: Partial<GroupBalances> = {}): GroupBalances {
  return {
    group_id: MONEY_GROUP,
    currency: 'INR',
    balances: [
      memberBalance(ME, 'Asha Rao', { paid: '1000.00', share: '500.00', net: '500.00' }),
      memberBalance(MEERA, 'Meera Rao', { paid: '0.00', share: '300.00', net: '-300.00' }),
      memberBalance(RAVI, 'Ravi Kumar', { paid: '0.00', share: '200.00', net: '-200.00' }),
    ],
    my_net: money('500.00'),
    original_debts: [
      transfer(MEERA, 'Meera Rao', ME, 'Asha Rao', '300.00'),
      transfer(RAVI, 'Ravi Kumar', ME, 'Asha Rao', '150.00'),
      transfer(RAVI, 'Ravi Kumar', MEERA, 'Meera Rao', '50.00'),
    ],
    simplified: [
      transfer(MEERA, 'Meera Rao', ME, 'Asha Rao', '300.00'),
      transfer(RAVI, 'Ravi Kumar', ME, 'Asha Rao', '200.00'),
    ],
    simplify_enabled: true,
    disputed_expenses: 0,
    computed_at: '2026-11-05T10:00:00Z',
    ...overrides,
  };
}

export function makeSuggestions(overrides: Partial<GroupSuggestions> = {}): GroupSuggestions {
  return {
    mode: 'simplified',
    currency: 'INR',
    suggestions: makeBalances().simplified,
    note: 'Suggestions only. Montra does not move money; record a settlement after you pay off-app.',
    ...overrides,
  };
}

/** Meera reported paying Asha 300.00 by UPI; Asha has not confirmed yet. */
export function makeSettlement(overrides: Partial<Settlement> = {}): Settlement {
  return {
    id: SETTLEMENT_ID,
    group_id: MONEY_GROUP,
    payer_user_id: MEERA,
    payer_name: 'Meera Rao',
    payee_user_id: ME,
    payee_name: 'Asha Rao',
    amount: money('300.00'),
    method: 'upi',
    status: 'user_reported_paid',
    verification: 'user_reported',
    proposed_by: MEERA,
    settled_on: '2026-11-05',
    counted: false,
    version: 1,
    created_at: '2026-11-05T10:00:00Z',
    ...overrides,
  };
}

export function makeOccurrence(overrides: Partial<Occurrence> = {}): Occurrence {
  return {
    id: OCCURRENCE_DUE,
    rule_id: RULE_ID,
    rule_name: 'Rent',
    kind: 'group_expense',
    occurrence_date: '2026-11-05',
    effective_date: '2026-11-05',
    due_at: '2026-11-05T03:30:00Z',
    status: 'scheduled',
    amount: money('30000.00'),
    group_id: MONEY_GROUP,
    ...overrides,
  };
}

/** Monthly rent set up by Asha, split equally, added by a member when due. */
export function makeRecurring(overrides: Partial<GroupRecurring> = {}): GroupRecurring {
  return {
    rule: {
      id: RULE_ID,
      kind: 'group_expense',
      name: 'Rent',
      frequency: 'monthly',
      interval_count: 1,
      start_date: '2026-11-05',
      timezone: 'Asia/Kolkata',
      local_time: '09:00',
      amount: money('30000.00'),
      currency: 'INR',
      amount_is_variable: false,
      auto_post: false,
      reminder_days_before: [1],
      status: 'active',
      next_occurrence: '2026-11-05',
      completed_count: 0,
      group_id: MONEY_GROUP,
      owned: true,
      version: 1,
      created_at: '2026-11-01T09:00:00Z',
    },
    created_by: ME,
    auto_add: false,
    template: {
      category_key: 'housing_rent',
      split_method: 'equal',
      participants: [{ user_id: ME }, { user_id: MEERA }, { user_id: RAVI }],
    },
    occurrences: [
      makeOccurrence({
        id: OCCURRENCE_NEXT,
        occurrence_date: '2026-12-05',
        effective_date: '2026-12-05',
        due_at: '2026-12-05T03:30:00Z',
      }),
      makeOccurrence(),
    ],
    ...overrides,
  };
}

export function makeReport(overrides: Partial<GroupReport> = {}): GroupReport {
  return {
    group_id: MONEY_GROUP,
    group_type: 'household',
    currency: 'INR',
    total_spent: money('3019.99'),
    expense_count: 5,
    disputed_count: 1,
    participant_count: 3,
    per_person_average: money('1006.66'),
    my_paid: money('700.00'),
    my_share: money('1216.64'),
    by_category: [
      { category_key: 'utilities', total: money('1999.99'), count: 2 },
      { category_key: 'food_dining', total: money('880.00'), count: 1 },
      { category_key: 'uncategorized', total: money('140.00'), count: 2 },
    ],
    by_member: [
      { user_id: ME, display_name: 'Asha Rao', paid: money('700.00'), share: money('1216.64') },
      { user_id: MEERA, display_name: 'Meera Rao', paid: money('450.00'), share: money('976.63') },
      { user_id: RAVI, display_name: 'Ravi Kumar', paid: money('1879.99'), share: money('836.72') },
    ],
    by_month: [
      { month: '2026-10', total: money('999.99'), count: 1 },
      { month: '2026-11', total: money('2020.00'), count: 4 },
    ],
    original_currencies: [
      { currency: 'USD', original: money('100.00', 'USD'), converted: money('8325.00'), count: 1 },
    ],
    settlements: { confirmed: money('950.00'), pending: money('100.00'), disputed: 0, count: 3 },
    balances: makeBalances(),
    ...overrides,
  };
}
