import type { NamespaceTranslation } from '../../types';
import type en from '../en/settings';

/** Hindi `settings` messages; missing keys fall back to English. */
const messages = {} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
