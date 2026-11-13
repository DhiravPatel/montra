import type { Message } from '../../types';

/** English `securityInfo` messages (source of truth for their keys). */
const messages = {
  'securityInfo.title': 'Security at Montra',
  'securityInfo.intro': 'How we protect your account, and how you can help keep it safe.',
  'securityInfo.protect.title': 'How we protect your account',
  'securityInfo.protect.passwords':
    'Passwords are protected with Argon2id, a slow one-way hash. They’re never stored or logged in readable form.',
  'securityInfo.protect.sessions':
    'Browser sessions use secure cookies that page scripts can’t read. Access expires after 15 minutes and renews automatically, and every request that changes your data must carry an anti-forgery token.',
  'securityInfo.protect.mfa':
    'Two-step verification uses codes from an authenticator app, with single-use recovery codes as a backup.',
  'securityInfo.protect.devices':
    'You can see every device signed in to your account and sign any of them out.',
  'securityInfo.protect.abuse':
    'Sign-in attempts are rate limited, and our messages never reveal whether an email address has an account.',
  'securityInfo.tips.title': 'Keep your account safe',
  'securityInfo.tips.unique': 'Use a password you don’t use anywhere else.',
  'securityInfo.tips.mfa': 'Turn on two-step verification.',
  'securityInfo.tips.codes': 'Store your recovery codes somewhere safe and offline.',
  'securityInfo.tips.review':
    'Review your signed-in devices from time to time and sign out any you don’t recognize.',
  'securityInfo.report.title': 'Report a security issue',
  'securityInfo.report.body':
    'If you believe you’ve found a vulnerability, please tell us privately and give us time to fix it before sharing details. Contact',
} as const satisfies Record<string, Message>;

export default messages;
