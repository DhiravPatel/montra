import type { NamespaceTranslation } from '../../types';
import type en from '../en/terms';

/** Hindi `terms` messages; missing keys fall back to English. */
const messages = {} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
