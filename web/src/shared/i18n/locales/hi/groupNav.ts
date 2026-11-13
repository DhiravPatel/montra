import type { NamespaceTranslation } from '../../types';
import type en from '../en/groupNav';

/** Hindi `groupNav` messages; missing keys fall back to English. */
const messages = {
  // Group navigation (shared by groups and group-money)
  'groupNav.label': 'समूह के पेज',
  'groupNav.overview': 'सारांश',
  'groupNav.expenses': 'खर्च',
  'groupNav.balances': 'बकाया',
  'groupNav.recurring': 'आवर्ती',
  'groupNav.reports': 'रिपोर्ट',
  'groupNav.settings': 'सेटिंग्स',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
