import type { NamespaceTranslation } from '../../types';
import type en from '../en/sharing';

/** Hindi `sharing` messages; missing keys fall back to English. */
const messages = {
  // Round 2 shared: sharing with people, linking transactions
  'sharing.source.friend': 'मित्र',
  'sharing.source.group': 'समूह सदस्य',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
