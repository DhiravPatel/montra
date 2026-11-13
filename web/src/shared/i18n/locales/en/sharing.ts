import type { Message } from '../../types';

/** English `sharing` messages (source of truth for their keys). */
const messages = {
  // Round 2 shared: sharing with people, linking transactions
  'sharing.source.friend': 'Friend',
  'sharing.source.group': 'Group member',
} as const satisfies Record<string, Message>;

export default messages;
