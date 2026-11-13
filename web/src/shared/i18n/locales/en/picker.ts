import type { Message } from '../../types';

/** English `picker` messages (source of truth for their keys). */
const messages = {
  'picker.legend': 'Choose a transaction',
  'picker.suggested': 'Suggested matches',
  'picker.suggestionsLoading': 'Looking for matching transactions…',
  'picker.searchHeading': 'Your transactions',
  'picker.search': 'Search description, notes or merchant',
  'picker.loading': 'Loading transactions…',
  'picker.error': 'We couldn’t load your transactions',
  'picker.noMatches': 'No transactions match your search.',
  'picker.empty': 'No transactions to show for this period.',
  'picker.resultCount': { one: '{count} transaction found', other: '{count} transactions found' },
} as const satisfies Record<string, Message>;

export default messages;
