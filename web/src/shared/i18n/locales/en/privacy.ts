import type { Message } from '../../types';

/** English `privacy` messages (source of truth for their keys). */
const messages = {
  'privacy.title': 'Privacy notice',
  'privacy.intro': 'A plain-language summary of how Montra handles your information.',
  'privacy.commitments.title': 'Our commitments',
  'privacy.commitments.private':
    'Your financial information is private by default and never shown publicly.',
  'privacy.commitments.noSelling':
    'We don’t sell your data, and we don’t use your finances for advertising.',
  'privacy.commitments.noBank': 'You never need to link a bank account to use Montra.',
  'privacy.commitments.minimal': 'We collect only what we need to run and secure your account.',
  'privacy.collect.title': 'What we collect today',
  'privacy.collect.account':
    'Account details: your email address and display name. Your password is stored only as a one-way hash that no one can read.',
  'privacy.collect.preferences':
    'Preferences: your language and region, time zone, and main currency.',
  'privacy.collect.sessions':
    'Sign-in and security records: the devices signed in to your account (the browser or app description they report), when they were last active, and security events such as sign-ins and password changes. We keep a scrambled (hashed) form of your IP address for security, not the address itself.',
  'privacy.collect.finance':
    'Money records you add: accounts (a name and, if you choose, the last 2–4 digits), payment methods, transactions, categories, tags and merchants, with the history of changes you make to them. Montra never asks for full card or account numbers, PINs or bank passwords.',
  'privacy.collect.consents':
    'Agreements: which versions of these documents you accepted, and when.',
  'privacy.cookies.title': 'Cookies and browser storage',
  'privacy.cookies.essential':
    'Montra uses only essential cookies: two sign-in cookies that page scripts can’t read, and a security token that protects your requests. There are no advertising or tracking cookies.',
  'privacy.cookies.storage':
    'Your theme and language choices are saved in this browser so they’re remembered next time. Nothing else is stored there.',
  'privacy.choices.title': 'Your choices',
  'privacy.choices.body':
    'You can review and sign out the devices on your account, sign out everywhere, change your password, and turn two-step verification on or off at any time from Security settings.',
  'privacy.contact.title': 'Questions',
  'privacy.contact.body': 'For questions about your information, contact us at',
} as const satisfies Record<string, Message>;

export default messages;
