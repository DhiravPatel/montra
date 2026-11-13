import type { Message } from '../../types';

/** English `tags` messages (source of truth for their keys). */
const messages = {
  'tags.title': 'Tags',
  'tags.description':
    'Tags are labels you can add to any transaction, like “work trip” or “wedding”.',
  'tags.add': 'Add tag',
  'tags.list.title': 'Your tags',
  'tags.loading': 'Loading tags…',
  'tags.error': 'We couldn’t load your tags',
  'tags.empty.title': 'No tags yet',
  'tags.empty.body': 'Add a tag here, or type one when you add a transaction.',
  'tags.allArchived': 'All your tags are archived. Turn on “Show archived” to see them.',
  'tags.usage': { one: 'Used on {count} transaction', other: 'Used on {count} transactions' },
  'tags.unused': 'Not used yet',
  'tags.create.title': 'Add a tag',
  'tags.create.submit': 'Add tag',
  'tags.create.done': 'Tag added',
  'tags.edit.title': 'Edit tag',
  'tags.edit.done': 'Tag updated',
  'tags.form.name': 'Name',
  'tags.form.nameRequired': 'Enter a name.',
  'tags.form.duplicate': 'You already have a tag with this name.',
  'tags.archive.action': 'Archive',
  'tags.archive.done': 'Tag archived. It stays on past transactions.',
  'tags.unarchive.action': 'Unarchive',
  'tags.unarchive.done': 'Tag is active again',
  'tags.status.failed': 'We couldn’t update the tag',
  'tags.delete.action': 'Delete',
  'tags.delete.title': 'Delete this tag?',
  'tags.delete.body': {
    one: '“{name}” will be removed from {count} transaction. The transaction itself stays.',
    other: '“{name}” will be removed from {count} transactions. The transactions themselves stay.',
  },
  'tags.delete.bodyUnused': '“{name}” isn’t used on any transaction.',
  'tags.delete.confirm': 'Delete tag',
  'tags.delete.done': 'Tag deleted',
  'tags.notFound': 'That tag no longer exists.',
  'tags.status.reloaded':
    'This tag was changed somewhere else. We’ve loaded the latest version, so check it and try again.',
} as const satisfies Record<string, Message>;

export default messages;
