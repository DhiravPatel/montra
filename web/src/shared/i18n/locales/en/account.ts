import type { Message } from '../../types';

/** English `account` messages (source of truth for their keys). */
const messages = {
  // Account overview
  'account.title': 'Your account',
  'account.greeting': 'Hello, {name}. Here are your account details.',
  'account.profile.title': 'Profile',
  'account.profile.edit': 'Edit profile',
  'account.profile.name': 'Display name',
  'account.profile.email': 'Email',
  'account.profile.verified': 'Verified',
  'account.profile.unverified': 'Not verified',
  'account.profile.memberSince': 'Member since',
  'account.preferences.title': 'Preferences',
  'account.preferences.edit': 'Change preferences',
  'account.preferences.description': 'Your main currency, language and region, and time zone.',
  'account.preferences.currency': 'Main currency',
  'account.preferences.locale': 'Language and region',
  'account.preferences.timezone': 'Time zone',
  'account.preferences.currencyRetired': 'Retired',
  'account.preferences.currencyReplaced':
    '{currency} was replaced by {replacement} on {date}. Past records keep their original currency.',
  'account.security.title': 'Security',
  'account.security.manage': 'Manage security',
} as const satisfies Record<string, Message>;

export default messages;
