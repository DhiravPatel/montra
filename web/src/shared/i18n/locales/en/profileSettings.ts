import type { Message } from '../../types';

/** English `profileSettings` messages (source of truth for their keys). */
const messages = {
  // Settings: security
  'profileSettings.title': 'Profile and preferences',
  'profileSettings.description':
    'How you appear to friends and groups, how Montra shows dates and money, and how the app looks. Changes apply on all your devices.',
  'profileSettings.nothingChanged': 'Nothing to save: you haven’t changed anything',
  'profileSettings.avatar.title': 'Profile photo',
  'profileSettings.avatar.description':
    'Shown next to your name to the people who can see your profile (see “Who can see your profile” below).',
  'profileSettings.avatar.help': 'A JPG, PNG or WebP image up to 5 MB.',
  'profileSettings.avatar.upload': 'Upload a photo',
  'profileSettings.avatar.change': 'Change photo',
  'profileSettings.avatar.choose': 'Choose a profile photo',
  'profileSettings.avatar.remove': 'Remove photo',
  'profileSettings.avatar.uploading': 'Uploading your photo…',
  'profileSettings.avatar.saving': 'Saving your photo…',
  'profileSettings.avatar.saved': 'Profile photo updated',
  'profileSettings.avatar.removed': 'Profile photo removed',
  'profileSettings.avatar.loading': 'Loading your photo…',
  'profileSettings.avatar.alt': 'Your profile photo',
  'profileSettings.avatar.unavailable': 'Photo unavailable',
  'profileSettings.avatar.previewFailed':
    'Your photo couldn’t be shown right now. It is still saved.',
  'profileSettings.avatar.type': 'Choose a JPG, PNG or WebP image.',
  'profileSettings.avatar.invalid':
    'That image can’t be used as your photo. Upload it again and wait for the upload to finish.',
  'profileSettings.avatar.removeTitle': 'Remove your profile photo?',
  'profileSettings.avatar.removeBody':
    'Your initials are shown instead. The image stays in your files until you delete it.',
  'profileSettings.avatar.removeConfirm': 'Remove photo',
  'profileSettings.profile.title': 'Your profile',
  'profileSettings.profile.description':
    'Your name and username are what friends and groups see. The rest is optional.',
  'profileSettings.profile.loading': 'Loading your profile…',
  'profileSettings.profile.error': 'We couldn’t load your profile',
  'profileSettings.profile.displayName': 'Display name',
  'profileSettings.profile.displayNameHelp': 'Up to 80 characters.',
  'profileSettings.profile.displayNameRequired': 'Enter a display name.',
  'profileSettings.profile.displayNameTooLong': 'Use 80 characters or fewer.',
  'profileSettings.profile.usernameHelp':
    '3 to 30 characters: lowercase letters, numbers, dots and underscores. Leave it empty to remove it.',
  'profileSettings.profile.bio': 'Bio',
  'profileSettings.profile.bioHelp': 'A line or two about you, up to 280 characters.',
  'profileSettings.profile.bioTooLong': 'Use 280 characters or fewer.',
  'profileSettings.profile.interests': 'Interests',
  'profileSettings.profile.interestsHelp': {
    one: 'Separate them with commas. Up to {count} interest.',
    other: 'Separate them with commas. Up to {count} interests.',
  },
  'profileSettings.profile.interestsInvalid': {
    one: 'Use up to {count} interest, each up to {length} characters.',
    other: 'Use up to {count} interests, each up to {length} characters.',
  },
  'profileSettings.profile.location': 'Location',
  'profileSettings.profile.locationHelp': 'A city or region only, never your address.',
  'profileSettings.profile.locationTooLong': 'Use 80 characters or fewer.',
  'profileSettings.profile.save': 'Save profile',
  'profileSettings.profile.saved': 'Profile saved',
  'profileSettings.visibility.legend': 'Who can see your profile',
  'profileSettings.visibility.help':
    'Your profile is your photo, bio, interests and location. Your balances and transactions are never part of it. People you block, or who block you, never see it.',
  'profileSettings.visibility.private': 'Private',
  'profileSettings.visibility.privateHelp':
    'Only you, people in an active group with you, and people you have a pending friend request with.',
  'profileSettings.visibility.connections': 'Friends',
  'profileSettings.visibility.connectionsHelp':
    'Your friends, plus everyone a private profile is shown to: people in an active group with you and people you have a pending friend request with.',
  'profileSettings.visibility.public': 'Anyone on Montra',
  'profileSettings.visibility.publicHelp': 'Anyone who is signed in to Montra.',
  'profileSettings.discoverableHelp':
    'People who type your exact username can find you and send a friend request.',
  'profileSettings.region.title': 'Region, money and display',
  'profileSettings.region.description':
    'Your currencies, time zone, formats and defaults. Only what you change is saved.',
  'profileSettings.region.loading': 'Loading your preferences…',
  'profileSettings.region.error': 'We couldn’t load your preferences',
  'profileSettings.region.currenciesFailed':
    'The currency list couldn’t be loaded, so only your current currencies are offered.',
  'profileSettings.region.accountsFailed':
    'Your accounts couldn’t be loaded right now; you can still clear the default.',
  'profileSettings.region.money': 'Money',
  'profileSettings.region.baseCurrencyHelp':
    'Used for new budgets, goals, subscriptions and recurring items when you don’t pick a currency, and for amount filters. Each account keeps its own currency.',
  'profileSettings.region.baseChangeTitle': 'What changing your main currency does',
  'profileSettings.region.baseChangeBody':
    'New records will start in {to} instead of {from}. Amounts you’ve already recorded, your accounts and their balances keep their currency and are not converted, and totals in different currencies are still shown separately.',
  'profileSettings.region.displayCurrency': 'Display currency',
  'profileSettings.region.displayCurrencyNone': 'None',
  'profileSettings.region.displayCurrencyHelp':
    'Optional. Analytics and reports can add converted totals in this currency, with the rates used. Your records are never converted.',
  'profileSettings.region.place': 'Place and time',
  'profileSettings.region.countryNone': 'Not set',
  'profileSettings.region.formats': 'Formats',
  'profileSettings.region.formatsHelp':
    'Used in emails, exports and reports. The app itself follows your interface language.',
  'profileSettings.region.dateFormat': 'Date format',
  'profileSettings.region.dateFormat.locale': 'Same as the language and region',
  'profileSettings.region.dateFormat.dmy': 'Day, month, year (31/12/2026)',
  'profileSettings.region.dateFormat.mdy': 'Month, day, year (12/31/2026)',
  'profileSettings.region.dateFormat.ymd': 'Year, month, day (2026-12-31)',
  'profileSettings.region.numberFormat': 'Number format',
  'profileSettings.region.numberFormat.locale': 'Same as the language and region',
  'profileSettings.region.numberFormat.indian': 'Indian (1,00,000.00)',
  'profileSettings.region.numberFormat.international': 'International (100,000.00)',
  'profileSettings.region.periods': 'Weeks and months',
  'profileSettings.region.monthStartHelp': 'Monthly budgets and reports start on this day.',
  'profileSettings.region.defaultRange': 'Default period',
  'profileSettings.region.defaultRangeHelp': 'What Home shows when you open it.',
  'profileSettings.region.defaults': 'Defaults and theme',
  'profileSettings.region.defaultAccount': 'Default account',
  'profileSettings.region.defaultAccountNone': 'No default account',
  'profileSettings.region.defaultAccountUnavailable': 'An account that is no longer active',
  'profileSettings.region.defaultAccountHelp': 'Chosen first when you add a transaction.',
  'profileSettings.region.themeHelp': 'Applies on all your devices.',
  'profileSettings.region.save': 'Save preferences',
  'profileSettings.region.saved': 'Preferences saved',
  'profileSettings.accessibility.title': 'Accessibility',
  'profileSettings.accessibility.description':
    'These apply across Montra as soon as you save, on all your devices.',
  'profileSettings.accessibility.reducedMotion': 'Reduce motion',
  'profileSettings.accessibility.reducedMotionHelp':
    'Turns off animations and transitions. Montra also follows your device’s setting.',
  'profileSettings.accessibility.highContrast': 'High contrast',
  'profileSettings.accessibility.highContrastHelp':
    'Darker text, stronger borders and clearer status colors, in light and dark themes.',
  'profileSettings.accessibility.textScale': 'Text size',
  'profileSettings.accessibility.textScaleHelp': 'Makes all text and spacing larger or smaller.',
  'profileSettings.accessibility.textScaleDefault': '{size} (default)',
  'profileSettings.accessibility.save': 'Save accessibility settings',
  'profileSettings.accessibility.saved': 'Accessibility settings saved',
} as const satisfies Record<string, Message>;

export default messages;
