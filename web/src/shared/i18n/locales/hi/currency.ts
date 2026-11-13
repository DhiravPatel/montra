import type { NamespaceTranslation } from '../../types';
import type en from '../en/currency';

/** Hindi `currency` messages; missing keys fall back to English. */
const messages = {
  'currency.loading': 'मुद्राएँ लोड हो रही हैं…',
  'currency.loadFailed': 'हम मुद्राओं की सूची लोड नहीं कर सके।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
