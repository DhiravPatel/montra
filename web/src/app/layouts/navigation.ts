import type { IconName } from '@/shared/components/Icon';
import { paths } from '@/shared/config/paths';
import type { MessageKey } from '@/shared/i18n/types';

export type PlatformRole = 'user' | 'support' | 'admin';

export interface NavItem {
  id: string;
  to: string;
  labelKey: MessageKey;
  icon: IconName;
  /** Shown only to these platform roles (staff tools); the server still enforces access. */
  roles?: readonly PlatformRole[];
}

export interface NavSection {
  id: string;
  labelKey: MessageKey;
  items: readonly NavItem[];
}

/**
 * Signed-in navigation (sidebar on desktop; bottom bar plus a "More" menu on
 * small screens). List only screens that exist and work end to end; do not
 * add placeholders. Sub-pages are reached from their section's page (e.g.
 * payment methods under Accounts, rules/tags/merchants under Categories,
 * bills and recurring rules under Bills & recurring).
 */
export const navigationSections: readonly NavSection[] = [
  {
    id: 'money',
    labelKey: 'nav.section.money',
    items: [
      { id: 'home', to: paths.dashboard, labelKey: 'nav.home', icon: 'home' },
      { id: 'transactions', to: paths.transactions, labelKey: 'nav.transactions', icon: 'list' },
      { id: 'accounts', to: paths.accounts, labelKey: 'nav.accounts', icon: 'wallet' },
      { id: 'receipts', to: paths.receipts, labelKey: 'nav.receipts', icon: 'receipt' },
      { id: 'imports', to: paths.imports, labelKey: 'nav.imports', icon: 'upload' },
    ],
  },
  {
    id: 'plan',
    labelKey: 'nav.section.plan',
    items: [
      { id: 'budgets', to: paths.budgets, labelKey: 'nav.budgets', icon: 'pie-chart' },
      { id: 'planning', to: paths.planning, labelKey: 'nav.planning', icon: 'calendar' },
      {
        id: 'subscriptions',
        to: paths.subscriptions,
        labelKey: 'nav.subscriptions',
        icon: 'repeat',
      },
      { id: 'goals', to: paths.goals, labelKey: 'nav.goals', icon: 'target' },
    ],
  },
  {
    id: 'together',
    labelKey: 'nav.section.together',
    items: [
      { id: 'groups', to: paths.groups, labelKey: 'nav.groups', icon: 'users' },
      { id: 'friends', to: paths.friends, labelKey: 'nav.friends', icon: 'user-plus' },
      {
        id: 'communities',
        to: paths.communities,
        labelKey: 'nav.communities',
        icon: 'message-square',
      },
      { id: 'challenges', to: paths.challenges, labelKey: 'nav.challenges', icon: 'flag' },
    ],
  },
  {
    id: 'insights',
    labelKey: 'nav.section.insights',
    items: [
      { id: 'insights', to: paths.insights, labelKey: 'nav.insights', icon: 'trending-up' },
      { id: 'analytics', to: paths.analytics, labelKey: 'nav.analytics', icon: 'bar-chart' },
      { id: 'reports', to: paths.reports, labelKey: 'nav.reports', icon: 'file-text' },
    ],
  },
  {
    id: 'organize',
    labelKey: 'nav.section.organize',
    items: [{ id: 'categories', to: paths.categories, labelKey: 'nav.categories', icon: 'folder' }],
  },
  {
    id: 'you',
    labelKey: 'nav.section.you',
    items: [
      { id: 'account', to: paths.account, labelKey: 'nav.account', icon: 'user' },
      { id: 'security', to: paths.securitySettings, labelKey: 'nav.security', icon: 'shield' },
      {
        id: 'exchange-rates',
        to: paths.exchangeRates,
        labelKey: 'nav.exchangeRates',
        icon: 'arrow-left-right',
      },
      {
        id: 'notification-settings',
        to: paths.notificationSettings,
        labelKey: 'nav.notificationSettings',
        icon: 'bell',
      },
      { id: 'privacy', to: paths.privacySettings, labelKey: 'nav.privacyData', icon: 'lock' },
      { id: 'integrations', to: paths.integrations, labelKey: 'nav.integrations', icon: 'link' },
      { id: 'help', to: paths.help, labelKey: 'nav.help', icon: 'info' },
    ],
  },
  {
    id: 'staff',
    labelKey: 'nav.section.staff',
    items: [
      {
        id: 'staff-support',
        to: paths.staffSupport,
        labelKey: 'nav.staffSupport',
        icon: 'inbox',
        roles: ['support', 'admin'],
      },
      {
        id: 'staff-moderation',
        to: paths.staffModeration,
        labelKey: 'nav.staffModeration',
        icon: 'shield-check',
        roles: ['support', 'admin'],
      },
      {
        id: 'staff-usage',
        to: paths.staffUsage,
        labelKey: 'nav.staffUsage',
        icon: 'bar-chart',
        roles: ['admin'],
      },
    ],
  },
];

/** Sections and items visible to a platform role (empty sections are dropped). */
export function navigationFor(role: string): readonly NavSection[] {
  return navigationSections
    .map((section) => ({
      ...section,
      items: section.items.filter(
        (item) => !item.roles || item.roles.some((allowed) => allowed === role),
      ),
    }))
    .filter((section) => section.items.length > 0);
}

/** Every destination a role sees, in sidebar order. */
export function primaryNavigationFor(role: string): readonly NavItem[] {
  return navigationFor(role).flatMap((section) => section.items);
}

/** Bottom-bar destinations on small screens; the others are in the "More" menu. */
const MOBILE_TAB_IDS: ReadonlySet<string> = new Set(['home', 'transactions', 'budgets', 'goals']);

export const mobileTabs: readonly NavItem[] = primaryNavigationFor('user').filter((item) =>
  MOBILE_TAB_IDS.has(item.id),
);

export function mobileMoreItemsFor(role: string): readonly NavItem[] {
  return primaryNavigationFor(role).filter((item) => !MOBILE_TAB_IDS.has(item.id));
}
