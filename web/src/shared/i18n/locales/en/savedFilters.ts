import type { Message } from '../../types';

/** English `savedFilters` messages (source of truth for their keys). */
const messages = {
  // Saved filters (transactions and search)
  'savedFilters.open': {
    one: 'Saved filters ({count})',
    other: 'Saved filters ({count})',
  },
  'savedFilters.openEmpty': 'Saved filters',
  'savedFilters.title.transactions': 'Saved filters',
  'savedFilters.title.search': 'Saved searches',
  'savedFilters.description':
    'Saved with your account, so they also work in the Montra app. Search text and amounts are saved too, but never appear in links.',
  'savedFilters.save.title.transactions': 'Save the current filters',
  'savedFilters.save.title.search': 'Save this search',
  'savedFilters.save.name': 'Name',
  'savedFilters.save.nameHelp': 'Up to 80 characters, different from your other saved filters.',
  'savedFilters.save.submit': 'Save',
  'savedFilters.save.nothing.transactions':
    'Choose a filter, period, sort order or search first, then save it here.',
  'savedFilters.save.nothing.search': 'Type at least 2 characters to search, then save it here.',
  'savedFilters.save.done': 'Saved “{name}”',
  'savedFilters.errors.nameRequired': 'Enter a name.',
  'savedFilters.errors.nameTooLong': 'Use at most 80 characters.',
  'savedFilters.errors.duplicate':
    'You already have a saved filter called “{name}”. Choose another name.',
  'savedFilters.errors.nameInvalid': 'This name can’t be used. Try a different one.',
  'savedFilters.errors.filterRejected':
    'These filters couldn’t be saved. Remove some of them and try again.',
  'savedFilters.list.title.transactions': 'Your saved filters',
  'savedFilters.list.title.search': 'Your saved searches',
  'savedFilters.list.loading': 'Loading saved filters…',
  'savedFilters.list.error': 'Saved filters couldn’t be loaded',
  'savedFilters.list.empty': 'Nothing saved yet.',
  'savedFilters.list.unusable': 'Can’t be used in this version of Montra.',
  'savedFilters.list.savedOn': 'Saved {date}',
  'savedFilters.apply': 'Apply',
  'savedFilters.applyNamed': 'Apply {name}',
  'savedFilters.applied': 'Applied “{name}”',
  'savedFilters.appliedPartly': 'Some of its filters aren’t available here and were left out.',
  'savedFilters.delete': 'Delete',
  'savedFilters.deleteNamed': 'Delete {name}',
  'savedFilters.delete.title': 'Delete “{name}”?',
  'savedFilters.delete.body': 'Only the saved filter is deleted. Nothing else changes.',
  'savedFilters.delete.confirm': 'Delete saved filter',
  'savedFilters.deleted': 'Deleted “{name}”',
} as const satisfies Record<string, Message>;

export default messages;
