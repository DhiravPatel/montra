import type { Message } from '../../types';

/** English `paymentMethods` messages (source of truth for their keys). */
const messages = {
  // Payment methods
  'paymentMethods.title': 'Payment methods',
  'paymentMethods.description':
    'How you pay: cash, UPI, cards and more. Pick one when you record an expense.',
  'paymentMethods.add': 'Add payment method',
  'paymentMethods.list.title': 'Your payment methods',
  'paymentMethods.loading': 'Loading payment methods…',
  'paymentMethods.error': 'We couldn’t load your payment methods',
  'paymentMethods.empty.title': 'No payment methods yet',
  'paymentMethods.empty.body':
    'Add the ways you pay, like cash, UPI or a card, to see how you spend.',
  'paymentMethods.showArchived': 'Show archived',
  'paymentMethods.default': 'Default',
  'paymentMethods.archived': 'Archived',
  'paymentMethods.linkedTo': 'Linked to {account}',
  'paymentMethods.notFound': 'That payment method no longer exists.',
  'paymentMethods.create.title': 'Add a payment method',
  'paymentMethods.create.submit': 'Add payment method',
  'paymentMethods.create.done': 'Payment method added',
  'paymentMethods.edit.title': 'Edit payment method',
  'paymentMethods.edit.done': 'Payment method updated',
  'paymentMethods.form.safety':
    'Only store a name and, if you like, the last 4 digits. Never enter full card numbers, CVVs, PINs or OTPs.',
  'paymentMethods.form.kind': 'Type',
  'paymentMethods.form.kindPlaceholder': 'Choose a type',
  'paymentMethods.form.kindRequired': 'Choose a type.',
  'paymentMethods.form.label': 'Name',
  'paymentMethods.form.labelHelp': 'For example “HDFC debit card” or “GPay”.',
  'paymentMethods.form.labelRequired': 'Enter a name.',
  'paymentMethods.form.network': 'Card network',
  'paymentMethods.form.hint': 'Hint',
  'paymentMethods.form.hintHelp': 'For example “•••• 4821” or a masked UPI handle.',
  'paymentMethods.form.hintUnsafe': 'Use at most the last 4 digits. Never enter a full number.',
  'paymentMethods.form.account': 'Linked account',
  'paymentMethods.form.accountHelp': 'The account this method usually pays from.',
  'paymentMethods.form.default': 'Use as my default',
  'paymentMethods.form.defaultHelp': 'Suggested first when you add an expense.',
  'paymentMethods.remove.action': 'Remove',
  'paymentMethods.remove.title': 'Remove this payment method?',
  'paymentMethods.remove.body':
    '{label} will no longer be offered for new transactions. If past transactions use it, it is archived so their history stays intact.',
  'paymentMethods.remove.confirm': 'Remove',
  'paymentMethods.remove.done': 'Payment method deleted',
  'paymentMethods.remove.archived': 'Payment method archived because past transactions use it',
  'paymentMethods.restore.action': 'Restore',
  'paymentMethods.restore.done': 'Payment method restored',
  'paymentMethods.restore.failed': 'We couldn’t restore the payment method',
  'paymentMethods.conflict':
    'It was changed somewhere else. We’ve loaded the latest version; review it and save again.',
} as const satisfies Record<string, Message>;

export default messages;
