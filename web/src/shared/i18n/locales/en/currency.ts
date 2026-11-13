import type { Message } from '../../types';

/** English `currency` messages (source of truth for their keys). */
const messages = {
  'currency.loading': 'Loading currencies…',
  'currency.loadFailed': 'We couldn’t load the list of currencies.',
} as const satisfies Record<string, Message>;

export default messages;
