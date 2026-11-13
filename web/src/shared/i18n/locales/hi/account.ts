import type { NamespaceTranslation } from '../../types';
import type en from '../en/account';

/** Hindi `account` messages; missing keys fall back to English. */
const messages = {
  'account.profile.edit': 'प्रोफ़ाइल बदलें',
  'account.preferences.edit': 'प्राथमिकताएँ बदलें',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
