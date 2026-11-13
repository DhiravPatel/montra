import type { Message } from '../../types';

/** English `reauth` messages (source of truth for their keys). */
const messages = {
  // Re-authentication
  'reauth.title': 'Confirm it’s you',
  'reauth.description': 'For your security, enter your password to continue.',
  'reauth.descriptionWithCode':
    'For your security, enter your password and a code from your authenticator app (or a recovery code) to continue.',
  'reauth.password': 'Password',
  'reauth.code': 'Authenticator code',
  'reauth.codeHelp': 'The 6-digit code from your authenticator app.',
  'reauth.confirm': 'Confirm',
  'reauth.wrongPassword': 'That password is incorrect.',
  'reauth.wrongCode': 'That code didn’t work. Wait for a new code and try again.',
  'reauth.recoveryHelp': 'Each recovery code works once, so using one here uses it up.',
  'reauth.wrongRecovery': 'That recovery code didn’t work or was already used.',
} as const satisfies Record<string, Message>;

export default messages;
