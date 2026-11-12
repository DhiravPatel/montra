import {
  billPath,
  budgetPath,
  challengePath,
  communityModerationPath,
  communityPath,
  communitySettingsPath,
  goalPath,
  groupBalancesPath,
  groupExpensePath,
  groupPath,
  groupRecurringPath,
  groupSettingsPath,
  importPath,
  insightPath,
  paths,
  postPath,
  receiptPath,
  recurringPath,
  settlementPath,
  subscriptionPath,
  supportRequestPath,
  transactionPath,
  withQuery,
} from '@/shared/config/paths';
import type { AppNotification } from './types';

/** Entity IDs are opaque UUIDs; anything else is ignored (links carry IDs only). */
const OPAQUE_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function opaqueId(value: string | undefined): string | null {
  return value && OPAQUE_ID.test(value) ? value : null;
}

/** Where a category's notifications lead when they name no specific record. */
const categoryHome: Readonly<Record<string, string>> = {
  budget: paths.budgets,
  bill: paths.bills,
  subscription: paths.subscriptions,
  recurring: paths.recurring,
  goal: paths.goals,
  import: paths.imports,
  receipt: paths.receipts,
  insight: paths.insights,
  group: paths.groups,
  settlement: paths.groups,
  trip: paths.groups,
  social: paths.friends,
  community: paths.communities,
  challenge: paths.challenges,
  security: paths.securitySettings,
  account: paths.account,
  export: paths.privacySettings,
};

/**
 * The in-app page for a notification, built from its entity type and IDs
 * with the route helpers (never from free text). The destination re-checks
 * access, so a link to something the user can no longer see is safe.
 * Returns null when there is nowhere specific to go.
 *
 * Server deep links (IDs only) this mirrors: /planning/bills/{id},
 * /planning/recurring/{id}, /groups, /groups/{id}, /groups/{id}/settings,
 * /groups/{id}/recurring, /groups/{id}/expenses/{id},
 * /groups/{id}/settlements/{id}, /groups/{id}/balances,
 * /communities/{id}, /communities/{id}/settings,
 * /communities/{id}/moderation, /posts/{id}, /challenges/{id},
 * /settings/moderation, /settings/privacy?export={id},
 * /help/requests/{id}, /reports, /insights/{id}, /settings/integrations.
 */
export function notificationLink(notification: AppNotification): string | null {
  const id = opaqueId(notification.entity_id);
  const groupId = opaqueId(notification.group_id);
  const inGroup = (path: (group: string) => string) => (groupId ? path(groupId) : paths.groups);
  switch (notification.entity_type) {
    case 'transaction':
      return id ? transactionPath(id) : paths.transactions;
    case 'receipt':
      return id ? receiptPath(id) : paths.receipts;
    case 'goal':
      return id ? goalPath(id) : paths.goals;
    case 'budget':
      return id ? budgetPath(id) : paths.budgets;
    case 'bill':
      return id ? billPath(id) : paths.bills;
    case 'recurring_rule':
      return id ? recurringPath(id) : paths.recurring;
    case 'subscription':
      return id ? subscriptionPath(id) : paths.subscriptions;
    case 'import_batch':
      return id ? importPath(id) : paths.imports;
    case 'report':
    case 'scheduled_report':
      return paths.reports;
    case 'insight':
      return id ? insightPath(id) : paths.insights;
    case 'data_export':
      // The privacy page opens the exports list at this export.
      return id ? withQuery(paths.privacySettings, { export: id }) : paths.privacySettings;
    case 'support_request':
      return id ? supportRequestPath(id) : paths.help;
    case 'integration_connection':
      return paths.integrations;
    case 'friend_request':
    case 'connection':
      return paths.friends;
    case 'group':
      if (!id) return paths.groups;
      return notification.event_type === 'trip_ended_unsettled'
        ? groupBalancesPath(id)
        : groupPath(id);
    case 'group_member':
      return inGroup(groupPath);
    case 'group_expense':
      return groupId && id ? groupExpensePath(groupId, id) : inGroup(groupPath);
    case 'settlement':
      return groupId && id ? settlementPath(groupId, id) : inGroup(groupPath);
    case 'group_invitation':
      return paths.groups;
    case 'group_join_request':
      return inGroup(groupSettingsPath);
    case 'group_recurring_expense':
      return inGroup(groupRecurringPath);
    case 'community':
      if (!id) return paths.communities;
      if (notification.event_type === 'community_report') return communityModerationPath(id);
      if (notification.event_type === 'community_join_request') return communitySettingsPath(id);
      return communityPath(id);
    case 'community_post':
      return id ? postPath(id) : paths.communities;
    case 'challenge':
      return id ? challengePath(id) : paths.challenges;
    case 'moderation_action':
    case 'moderation_appeal':
      return paths.myModeration;
    default:
      break;
  }
  if (notification.category === 'account' && notification.event_type === 'deletion_scheduled') {
    return paths.privacySettings;
  }
  return categoryHome[notification.category] ?? null;
}
