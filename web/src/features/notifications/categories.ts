import type { IconName } from '@/shared/components/Icon';
import type { MessageKey } from '@/shared/i18n/types';
import type { NotificationChannel } from './types';

/**
 * Notification categories (the server's `notifications.category` values).
 * The server is the source of truth: a category it adds later is still
 * shown, with a generic label.
 */
export const NOTIFICATION_CATEGORIES = [
  'budget',
  'bill',
  'subscription',
  'recurring',
  'goal',
  'import',
  'receipt',
  'insight',
  'group',
  'settlement',
  'trip',
  'social',
  'community',
  'challenge',
  'security',
  'account',
  'export',
  'system',
] as const;

export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];

export function isNotificationCategory(value: string): value is NotificationCategory {
  return (NOTIFICATION_CATEGORIES as readonly string[]).includes(value);
}

/**
 * Security and account notifications stay on in the app and by email
 * (the server reports them `locked`, and refuses to turn them off).
 */
export const ALWAYS_ON_CATEGORIES: ReadonlySet<string> = new Set(['security', 'account']);

interface CategoryInfo {
  label: MessageKey;
  description: MessageKey;
  icon: IconName;
}

export const categoryInfo: Readonly<Record<NotificationCategory, CategoryInfo>> = {
  budget: {
    label: 'notifications.category.budget',
    description: 'notifications.categoryHelp.budget',
    icon: 'pie-chart',
  },
  bill: {
    label: 'notifications.category.bill',
    description: 'notifications.categoryHelp.bill',
    icon: 'calendar',
  },
  subscription: {
    label: 'notifications.category.subscription',
    description: 'notifications.categoryHelp.subscription',
    icon: 'repeat',
  },
  recurring: {
    label: 'notifications.category.recurring',
    description: 'notifications.categoryHelp.recurring',
    icon: 'clock',
  },
  goal: {
    label: 'notifications.category.goal',
    description: 'notifications.categoryHelp.goal',
    icon: 'target',
  },
  import: {
    label: 'notifications.category.import',
    description: 'notifications.categoryHelp.import',
    icon: 'upload',
  },
  receipt: {
    label: 'notifications.category.receipt',
    description: 'notifications.categoryHelp.receipt',
    icon: 'receipt',
  },
  insight: {
    label: 'notifications.category.insight',
    description: 'notifications.categoryHelp.insight',
    icon: 'trending-up',
  },
  group: {
    label: 'notifications.category.group',
    description: 'notifications.categoryHelp.group',
    icon: 'users',
  },
  settlement: {
    label: 'notifications.category.settlement',
    description: 'notifications.categoryHelp.settlement',
    icon: 'handshake',
  },
  trip: {
    label: 'notifications.category.trip',
    description: 'notifications.categoryHelp.trip',
    icon: 'globe',
  },
  social: {
    label: 'notifications.category.social',
    description: 'notifications.categoryHelp.social',
    icon: 'user-plus',
  },
  community: {
    label: 'notifications.category.community',
    description: 'notifications.categoryHelp.community',
    icon: 'message-square',
  },
  challenge: {
    label: 'notifications.category.challenge',
    description: 'notifications.categoryHelp.challenge',
    icon: 'flag',
  },
  security: {
    label: 'notifications.category.security',
    description: 'notifications.categoryHelp.security',
    icon: 'shield',
  },
  account: {
    label: 'notifications.category.account',
    description: 'notifications.categoryHelp.account',
    icon: 'user',
  },
  export: {
    label: 'notifications.category.export',
    description: 'notifications.categoryHelp.export',
    icon: 'download',
  },
  system: {
    label: 'notifications.category.system',
    description: 'notifications.categoryHelp.system',
    icon: 'info',
  },
};

/** The category's name in the interface language (generic for unknown categories). */
export function categoryLabelKey(category: string): MessageKey {
  return isNotificationCategory(category)
    ? categoryInfo[category].label
    : 'notifications.category.other';
}

export function categoryIcon(category: string): IconName {
  return isNotificationCategory(category) ? categoryInfo[category].icon : 'bell';
}

/** Settings sections (categories grouped the way people think about them). */
export const categorySections: readonly {
  id: string;
  label: MessageKey;
  categories: readonly NotificationCategory[];
}[] = [
  {
    id: 'money',
    label: 'notifications.section.money',
    categories: [
      'budget',
      'bill',
      'subscription',
      'recurring',
      'goal',
      'import',
      'receipt',
      'insight',
    ],
  },
  {
    id: 'people',
    label: 'notifications.section.people',
    categories: ['group', 'settlement', 'trip', 'social', 'community', 'challenge'],
  },
  {
    id: 'account',
    label: 'notifications.section.account',
    categories: ['security', 'account', 'export', 'system'],
  },
];

export const CHANNELS: readonly NotificationChannel[] = ['in_app', 'email', 'web_push', 'push'];

export const channelLabel: Readonly<Record<NotificationChannel, MessageKey>> = {
  in_app: 'notifications.channel.in_app',
  email: 'notifications.channel.email',
  web_push: 'notifications.channel.web_push',
  push: 'notifications.channel.push',
};
