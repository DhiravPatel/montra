import type { Message } from '../../types';

/** English `settings` messages (source of truth for their keys). */
const messages = {
  'settings.security.title': 'Security',
  'settings.security.description':
    'Manage how you sign in and which devices can access your account.',
  'settings.mfa.title': 'Two-step verification',
  'settings.mfa.description': 'Ask for a code from your authenticator app whenever you sign in.',
  'settings.mfa.statusOn': 'On',
  'settings.mfa.statusOff': 'Off',
  'settings.mfa.offBody':
    'Add an extra layer of protection: even if someone learns your password, they can’t sign in without your authenticator app.',
  'settings.mfa.onBody':
    'Signing in needs your password and a code from your authenticator app. Keep your recovery codes safe in case you lose your device.',
  'settings.mfa.setup.action': 'Set up two-step verification',
  'settings.mfa.enroll.step1': '1. Add Montra to your authenticator app',
  'settings.mfa.enroll.step1Body':
    'Scan this QR code with an authenticator app such as Google Authenticator, Microsoft Authenticator, or 1Password.',
  'settings.mfa.enroll.qrLabel': 'QR code for adding Montra to your authenticator app',
  'settings.mfa.enroll.manual': 'Can’t scan it? Enter this setup key in your app instead:',
  'settings.mfa.enroll.copyKey': 'Copy key',
  'settings.mfa.enroll.step2': '2. Enter the code from your app',
  'settings.mfa.enroll.codeLabel': 'Verification code',
  'settings.mfa.enroll.codeHelp': 'The 6-digit code your app shows for Montra.',
  'settings.mfa.enroll.activate': 'Turn on',
  'settings.mfa.activate.invalid':
    'That code didn’t work. Check that your device’s time is correct, then try the newest code.',
  'settings.mfa.activate.conflict': 'This setup has expired. Cancel and start again.',
  'settings.mfa.enabled.title': 'Two-step verification is on',
  'settings.mfa.enabled.body':
    'You’ll be asked for a code from your authenticator app when you sign in.',
  'settings.mfa.codes.title': 'Save your recovery codes now',
  'settings.mfa.codes.body':
    'If you lose access to your authenticator app, each code lets you sign in once. They won’t be shown again.',
  'settings.mfa.codes.copy': 'Copy codes',
  'settings.mfa.codes.download': 'Download',
  'settings.mfa.codes.confirmSaved': 'I’ve saved these codes somewhere safe',
  'settings.mfa.codes.done': 'Done',
  'settings.mfa.codes.missing': 'No recovery codes were returned. Generate new codes to get a set.',
  'settings.mfa.codes.fileHeading': 'Montra recovery codes',
  'settings.mfa.codes.fileGenerated': 'Generated {date}',
  'settings.mfa.codes.fileFooter': 'Each code can be used once. Keep this file private.',
  'settings.mfa.regenerate.action': 'Get new recovery codes',
  'settings.mfa.regenerate.title': 'Get new recovery codes?',
  'settings.mfa.regenerate.body': 'Your current recovery codes will stop working immediately.',
  'settings.mfa.regenerate.confirm': 'Get new codes',
  'settings.mfa.disable.action': 'Turn off',
  'settings.mfa.disable.title': 'Turn off two-step verification?',
  'settings.mfa.disable.body':
    'Signing in will only need your password. Enter a code to confirm. Each code works once, so if you just used one, wait for a new code.',
  'settings.mfa.disable.codeLabel': 'Authenticator code',
  'settings.mfa.disable.codeHelp': 'The newest 6-digit code from your authenticator app.',
  'settings.mfa.disable.confirm': 'Turn off',
  'settings.mfa.disable.invalid':
    'That code didn’t work or was already used. Wait for a new code and try again.',
  'settings.mfa.disable.done': 'Two-step verification is off',
  'settings.sessions.title': 'Signed-in devices',
  'settings.sessions.description':
    'These devices are signed in to your account. Sign out any you don’t recognize.',
  'settings.sessions.loading': 'Loading your devices…',
  'settings.sessions.error': 'We couldn’t load your devices',
  'settings.sessions.empty.title': 'No signed-in devices',
  'settings.sessions.empty.body': 'Devices appear here when they sign in to your account.',
  'settings.sessions.refresh': 'Refresh',
  'settings.sessions.thisDevice': 'This device',
  'settings.sessions.unknownDevice': 'Unknown device',
  'settings.sessions.client.web': 'Web browser',
  'settings.sessions.client.android': 'Android app',
  'settings.sessions.client.ios': 'iOS app',
  'settings.sessions.client.unknown': 'Other client',
  'settings.sessions.lastActive': 'last active <time>{when}</time>',
  'settings.sessions.signedIn': 'Signed in <time>{when}</time>',
  'settings.sessions.mfaVerified': 'Verified with two-step verification',
  'settings.sessions.signOutDevice': 'Sign out',
  'settings.sessions.confirm.title': 'Sign out this device?',
  'settings.sessions.confirm.body': '{device} will be signed out and will need to sign in again.',
  'settings.sessions.revoked': 'Signed out {device}',
  'settings.sessions.alreadyEnded': 'That device was already signed out',
  'settings.password.title': 'Password',
  'settings.password.description': 'Changing your password signs out your other devices.',
  'settings.password.current': 'Current password',
  'settings.password.submit': 'Change password',
  'settings.password.changed': 'Password changed',
  'settings.password.changedBody': 'Your other devices have been signed out.',
  'settings.signOutAll.title': 'Sign out everywhere',
  'settings.signOutAll.description': 'Sign out of Montra on every device, including this one.',
  'settings.signOutAll.action': 'Sign out everywhere',
  'settings.signOutAll.confirm.title': 'Sign out on all devices?',
  'settings.signOutAll.confirm.body':
    'Every device, including this one, will need to sign in again.',
} as const satisfies Record<string, Message>;

export default messages;
