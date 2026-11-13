import type { Message } from '../../types';

/** English `search` messages (source of truth for their keys). */
const messages = {
  // Global search (round 5)
  'search.header.label': 'Search Montra',
  'search.header.placeholder': 'Search Montra',
  'search.header.open': 'Open search',
  'search.title': 'Search',
  'search.description':
    'Find your transactions, accounts, merchants, categories, budgets, bills, subscriptions, recurring items, goals and groups, plus community posts and people you can connect with.',
  'search.form.label': 'Search Montra',
  'search.field.label': 'Search for',
  'search.field.placeholder': 'A merchant, description, account or goal',
  'search.field.help':
    'Type at least 2 characters. Results update as you type. Press Enter to keep a search in your recent searches.',
  'search.tooShort': 'Type at least 2 characters to search.',
  'search.scope.label': 'Look in',
  'search.scope.all': 'Everything',
  'search.sort.label': 'Order',
  'search.sort.relevance': 'Best match',
  'search.sort.name': 'By name',
  'search.sort.recent': 'Newest first',
  'search.submit': 'Search',
  'search.loading': 'Searching…',
  'search.updating': 'Updating results…',
  'search.error': 'We couldn’t search right now',
  'search.results.summary': {
    one: '{count} result for “{query}”',
    other: '{count} results for “{query}”',
  },
  'search.results.announce': { one: '{count} result found', other: '{count} results found' },
  'search.results.count': { one: '{count} result', other: '{count} results' },
  'search.results.sortedBy': 'Sorted: {order}',
  'search.empty.title': 'No results for “{query}”',
  'search.empty.body':
    'Check the spelling or try fewer words. Search looks at transaction descriptions, notes and merchants; names of accounts, merchants, categories, budgets, bills, subscriptions, recurring items, goals and groups; community posts you can read; and people who chose to be findable by their exact username.',
  'search.empty.announce': 'No results found',
  'search.empty.searchEverything': 'Search everything',
  'search.section.transactions': 'Transactions',
  'search.section.accounts': 'Accounts',
  'search.section.merchants': 'Merchants',
  'search.section.categories': 'Categories',
  'search.section.budgets': 'Budgets',
  'search.section.bills': 'Bills',
  'search.section.subscriptions': 'Subscriptions',
  'search.section.recurring_rules': 'Recurring items',
  'search.section.goals': 'Goals',
  'search.section.groups': 'Groups',
  'search.section.posts': 'Community posts',
  'search.section.users': 'People',
  'search.section.more': 'Show more in {section}',
  'search.section.limitReached': {
    one: 'Showing the first {count} match. Add words to narrow your search.',
    other: 'Showing the first {count} matches. Add words to narrow your search.',
  },
  'search.kind.bill.active': 'Active bill',
  'search.kind.bill.paused': 'Paused bill',
  'search.kind.bill.archived': 'Archived bill',
  'search.tx.untitled': 'Transaction',
  'search.tx.shared': 'Shared with you',
  'search.user.username': '@{username}',
  'search.users.connectHint':
    'To connect with someone, search for their exact username on the Friends page.',
  'search.users.findLink': 'Find people',
  'search.recent.title': 'Recent searches',
  'search.recent.description':
    'Searches you submit are kept on your account, newest first (up to 20). Only you can see them.',
  'search.recent.loading': 'Loading recent searches…',
  'search.recent.error': 'We couldn’t load your recent searches',
  'search.recent.empty': 'No recent searches yet.',
  'search.recent.inScope': 'In {section}',
  'search.recent.clear': 'Clear history',
  'search.recent.clearTitle': 'Clear your search history?',
  'search.recent.clearBody':
    'This removes all your recent searches from your account. Your records don’t change.',
  'search.recent.clearConfirm': 'Clear history',
  'search.recent.cleared': 'Search history cleared',
} as const satisfies Record<string, Message>;

export default messages;
