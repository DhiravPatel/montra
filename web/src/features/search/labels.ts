import type { components } from '@/shared/api/schema';
import type { IconName } from '@/shared/components/Icon';
import { accountTypeLabel, isAccountType } from '@/shared/finance/labels';
import type { MessageKey } from '@/shared/i18n/types';
import type { NamedSection, SearchScope, SearchSection, SearchSort } from './types';

type GroupType = components['schemas']['GroupDTO']['group_type'];
type GoalStatus = components['schemas']['GoalDTO']['status'];
type CategoryKind = components['schemas']['CategoryDTO']['kind'];
type BillStatus = components['schemas']['BillDTO']['status'];
type SubscriptionStatus = components['schemas']['SubscriptionDTO']['status'];
type RecurringKind = components['schemas']['RecurringRuleDTO']['kind'];
type BudgetType = components['schemas']['BudgetDTO']['budget_type'];

export const scopeLabel: Readonly<Record<SearchScope, MessageKey>> = {
  all: 'search.scope.all',
  transactions: 'search.section.transactions',
  accounts: 'search.section.accounts',
  merchants: 'search.section.merchants',
  categories: 'search.section.categories',
  budgets: 'search.section.budgets',
  bills: 'search.section.bills',
  subscriptions: 'search.section.subscriptions',
  recurring_rules: 'search.section.recurring_rules',
  goals: 'search.section.goals',
  groups: 'search.section.groups',
  posts: 'search.section.posts',
  users: 'search.section.users',
};

export const sectionIcon: Readonly<Record<SearchSection, IconName>> = {
  transactions: 'list',
  accounts: 'wallet',
  merchants: 'shopping-bag',
  categories: 'tag',
  budgets: 'pie-chart',
  bills: 'calendar',
  subscriptions: 'repeat',
  recurring_rules: 'clock',
  goals: 'target',
  groups: 'users',
  posts: 'message-square',
  users: 'user',
};

export const sortLabel: Readonly<Record<SearchSort, MessageKey>> = {
  relevance: 'search.sort.relevance',
  name: 'search.sort.name',
  recent: 'search.sort.recent',
};

const groupTypeLabel: Readonly<Record<GroupType, MessageKey>> = {
  household: 'groups.type.household',
  roommates: 'groups.type.roommates',
  trip: 'groups.type.trip',
  event: 'groups.type.event',
  friends: 'groups.type.friends',
  custom: 'groups.type.custom',
};

const goalStatusLabel: Readonly<Record<GoalStatus, MessageKey>> = {
  active: 'goals.status.active',
  paused: 'goals.status.paused',
  achieved: 'goals.status.achieved',
  cancelled: 'goals.status.cancelled',
  archived: 'goals.status.archived',
};

const categoryKindLabel: Readonly<Record<CategoryKind, MessageKey>> = {
  expense: 'categories.kind.expense',
  income: 'categories.kind.income',
  both: 'categories.kind.both',
};

const billStatusLabel: Readonly<Record<BillStatus, MessageKey>> = {
  active: 'search.kind.bill.active',
  paused: 'search.kind.bill.paused',
  archived: 'search.kind.bill.archived',
};

const subscriptionStatusLabel: Readonly<Record<SubscriptionStatus, MessageKey>> = {
  trial: 'subscriptions.status.trial',
  active: 'subscriptions.status.active',
  paused: 'subscriptions.status.paused',
  cancellation_pending: 'subscriptions.status.cancellation_pending',
  cancelled: 'subscriptions.status.cancelled',
};

const recurringKindLabel: Readonly<Record<RecurringKind, MessageKey>> = {
  expense: 'recurring.kind.expense',
  income: 'recurring.kind.income',
  transfer: 'recurring.kind.transfer',
  bill: 'recurring.kind.bill',
  group_expense: 'recurring.kind.group_expense',
};

const budgetTypeLabel: Readonly<Record<BudgetType, MessageKey>> = {
  total: 'budgets.type.total',
  category: 'budgets.type.category',
  merchant: 'budgets.type.merchant',
  account: 'budgets.type.account',
  envelope: 'budgets.type.envelope',
  zero_based: 'budgets.type.zero_based',
};

function hasKey<K extends string>(map: Readonly<Record<K, MessageKey>>, key: string): key is K {
  return Object.prototype.hasOwnProperty.call(map, key);
}

/**
 * The label for a hit's `kind` (account type, group type, goal status,
 * category kind, bill or subscription status, recurring rule kind or
 * budget type). Values this client does not know are not shown rather
 * than shown raw.
 */
export function hitKindLabel(section: NamedSection, kind: string | undefined): MessageKey | null {
  if (!kind) return null;
  switch (section) {
    case 'accounts':
      return isAccountType(kind) ? accountTypeLabel[kind] : null;
    case 'groups':
      return hasKey(groupTypeLabel, kind) ? groupTypeLabel[kind] : null;
    case 'goals':
      return hasKey(goalStatusLabel, kind) ? goalStatusLabel[kind] : null;
    case 'categories':
      return hasKey(categoryKindLabel, kind) ? categoryKindLabel[kind] : null;
    case 'bills':
      return hasKey(billStatusLabel, kind) ? billStatusLabel[kind] : null;
    case 'subscriptions':
      return hasKey(subscriptionStatusLabel, kind) ? subscriptionStatusLabel[kind] : null;
    case 'recurring_rules':
      return hasKey(recurringKindLabel, kind) ? recurringKindLabel[kind] : null;
    case 'budgets':
      return hasKey(budgetTypeLabel, kind) ? budgetTypeLabel[kind] : null;
    case 'merchants':
      return null;
  }
}
