import type { Message } from '../../types';

/** English `terms` messages (source of truth for their keys). */
const messages = {
  'terms.title': 'Terms of use',
  'terms.intro': 'A summary of the terms you accept when you create a Montra account.',
  'terms.summary.title': 'The essentials',
  'terms.summary.free':
    'Montra is free. Every feature is available to every user, with no paid tiers.',
  'terms.summary.age': 'You must be at least 18 years old to create an account.',
  'terms.summary.account':
    'Keep your sign-in details safe. Tell us right away if you think someone else has accessed your account.',
  'terms.summary.data':
    'Your data is yours. We use it only to provide Montra, as described in our <link>Privacy notice</link>.',
  'terms.summary.advice':
    'Montra helps you understand your money. It doesn’t give professional financial, tax, or legal advice.',
  'terms.summary.use':
    'Don’t misuse the service: no attempts to access other people’s data, disrupt Montra, or break the law.',
  'terms.summary.changes':
    'If these terms change, we’ll show you the new version before it applies to you.',
  'terms.contact.title': 'Questions',
  'terms.contact.body': 'For questions about these terms, contact us at',
} as const satisfies Record<string, Message>;

export default messages;
