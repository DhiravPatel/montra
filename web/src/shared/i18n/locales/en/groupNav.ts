import type { Message } from '../../types';

/** English `groupNav` messages (source of truth for their keys). */
const messages = {
  // Group navigation (shared by groups and group-money)
  'groupNav.label': 'Group pages',
  'groupNav.overview': 'Overview',
  'groupNav.expenses': 'Expenses',
  'groupNav.balances': 'Balances',
  'groupNav.recurring': 'Recurring',
  'groupNav.reports': 'Reports',
  'groupNav.settings': 'Settings',
} as const satisfies Record<string, Message>;

export default messages;
