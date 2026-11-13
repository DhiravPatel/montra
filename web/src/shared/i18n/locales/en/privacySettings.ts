import type { Message } from '../../types';

/** English `privacySettings` messages (source of truth for their keys). */
const messages = {
  // Privacy & data settings and fair-use limits (round 5; privacy.* belongs to the public notice)
  'privacySettings.title': 'Privacy & data',
  'privacySettings.description':
    'Choose what optional processing Montra may do, get a copy of your data, or close your account.',
  'privacySettings.readNotice': 'Read the privacy notice',
  'privacySettings.limitsLink': 'Fair-use limits',
  'privacySettings.consents.title': 'Your choices',
  'privacySettings.consents.description':
    'Optional processing stays off until you allow it, and you can withdraw consent at any time.',
  'privacySettings.consents.loading': 'Loading your choices…',
  'privacySettings.consents.error': 'We couldn’t load your choices',
  'privacySettings.consents.on': 'On',
  'privacySettings.consents.off': 'Off',
  'privacySettings.consents.give': 'Allow',
  'privacySettings.consents.withdraw': 'Withdraw',
  'privacySettings.consents.givenOn': 'Allowed {date} · wording version {version}',
  'privacySettings.consents.otherApp':
    'You allowed this in another Montra app. The web portal has no AI features, but you can withdraw it here.',
  'privacySettings.consents.given': '{name}: allowed',
  'privacySettings.consents.withdrawn': '{name}: consent withdrawn',
  'privacySettings.consents.alreadyOff': '{name} was already off',
  'privacySettings.consents.failed': '{name} didn’t change',
  'privacySettings.consents.versionChanged':
    'Montra just updated the wording of this consent. Try again to agree to the latest version.',
  'privacySettings.consents.requiredTitle': 'Needed to use Montra',
  'privacySettings.consents.accepted': 'Accepted {date} · version {version}',
  'privacySettings.consents.notRecorded': 'Not recorded',
  'privacySettings.consents.requiredBody':
    'You accepted these when you signed up. To withdraw them, delete your account below.',
  'privacySettings.consents.showHistory': 'Show consent history',
  'privacySettings.consents.hideHistory': 'Hide consent history',
  'privacySettings.consents.historyTitle': 'Consent history',
  'privacySettings.consents.historyLoading': 'Loading consent history…',
  'privacySettings.consents.historyError': 'We couldn’t load your consent history',
  'privacySettings.consents.historyConsent': 'Consent',
  'privacySettings.consents.historyGiven': 'Given',
  'privacySettings.consents.historyWithdrawn': 'Withdrawn',
  'privacySettings.consents.historyVersion': 'Version',
  'privacySettings.consents.stillOn': 'Still on',
  'privacySettings.consent.location.title': 'Location on transactions',
  'privacySettings.consent.location.body':
    'Lets you save a place name with a transaction, like the shop where you paid.',
  'privacySettings.consent.location.off':
    'When it’s off, you can’t add a location to transactions.',
  'privacySettings.consent.push_notifications.title': 'Push notifications',
  'privacySettings.consent.push_notifications.body':
    'Lets Montra send alerts to browsers and phones where you have also turned push notifications on.',
  'privacySettings.consent.push_notifications.off':
    'This records your choice. Alerts on a device stop when you turn push off for it in Notification settings.',
  'privacySettings.consent.push_notifications.link': 'Notification settings',
  'privacySettings.consent.marketing_email.title': 'Product news by email',
  'privacySettings.consent.marketing_email.body': 'Occasional emails about new Montra features.',
  'privacySettings.consent.marketing_email.off':
    'Montra doesn’t send product news today; this records your choice in case that changes. Account and security emails are always sent.',
  'privacySettings.consent.product_analytics.title': 'Product analytics',
  'privacySettings.consent.product_analytics.body':
    'Allows aggregate statistics about how Montra’s features are used.',
  'privacySettings.consent.product_analytics.off':
    'Montra collects no product analytics today; this records your choice in case that changes.',
  'privacySettings.consent.contacts_discovery.title': 'Be found by your contacts',
  'privacySettings.consent.contacts_discovery.body':
    'Lets people who already have your contact details find you on Montra.',
  'privacySettings.consent.contacts_discovery.off':
    'Montra has no contact matching today; this records your choice in case that changes. Being found by username is a separate setting.',
  'privacySettings.consent.contacts_discovery.link': 'Who can find you by username',
  'privacySettings.consent.ai_processing.title': 'AI features',
  'privacySettings.consent.ai_processing.body':
    'Lets Montra’s optional AI features use your data to answer you.',
  'privacySettings.consent.ai_processing.off':
    'Withdrawing turns AI features off in every Montra app.',
  'privacySettings.consent.ai_receipt_processing.title': 'AI reading of receipts',
  'privacySettings.consent.ai_receipt_processing.body':
    'Lets Montra’s optional AI read receipt images to fill in details.',
  'privacySettings.consent.ai_receipt_processing.off': 'Withdrawing means receipts stay manual.',
  'privacySettings.consent.terms.title': 'Terms of use',
  'privacySettings.consent.privacy_policy.title': 'Privacy notice',
  'privacySettings.consent.integration.title': 'Connected service',
  'privacySettings.consent.other.title': 'Other consent',
  'privacySettings.export.title': 'Download your data',
  'privacySettings.export.description': 'Get a copy of everything Montra stores about you.',
  'privacySettings.export.contents':
    'Your profile, settings, records, groups, notifications and more, as JSON files in one ZIP file.',
  'privacySettings.export.secrets':
    'Passwords, security codes and sign-in tokens are never included.',
  'privacySettings.export.window': {
    one: 'The download stays available for {count} day after it’s ready.',
    other: 'The download stays available for {count} days after it’s ready.',
  },
  'privacySettings.export.windowUnknown':
    'The download stays available for a limited time after it’s ready.',
  'privacySettings.export.reauth': 'For your security, Montra may ask for your password first.',
  'privacySettings.export.request': 'Request my data',
  'privacySettings.export.requested': 'Export requested',
  'privacySettings.export.checking': 'Checking your export…',
  'privacySettings.export.notFound': 'We couldn’t find that export. Request a new one below.',
  'privacySettings.export.checkFailed': 'We couldn’t check your export',
  'privacySettings.export.queued': 'Your export is waiting to start',
  'privacySettings.export.running': 'Preparing your export',
  'privacySettings.export.wait':
    'This usually takes a few minutes. You can leave this page: Montra will notify you when it’s ready.',
  'privacySettings.export.stalled':
    'This is taking longer than usual. Check again in a little while.',
  'privacySettings.export.checkAgain': 'Check again',
  'privacySettings.export.ready': 'Your export is ready',
  'privacySettings.export.availableUntil': 'You can download it until {date}.',
  'privacySettings.export.download': 'Download ZIP',
  'privacySettings.export.requestNew': 'Request a new export',
  'privacySettings.export.downloadStarted': 'Download started',
  'privacySettings.export.downloadFailed': 'The download didn’t start',
  'privacySettings.export.downloadGone':
    'This download is no longer available. Request a new export.',
  'privacySettings.export.failed': 'We couldn’t prepare your export',
  'privacySettings.export.failedBody':
    'Nothing was lost. Try again, and contact support if it keeps happening.',
  'privacySettings.export.tryAgain': 'Try again',
  'privacySettings.export.expired': 'This export has expired',
  'privacySettings.export.expiredBody':
    'Downloads are removed after a while to protect your data. Request a new export when you need one.',
  'privacySettings.deactivate.title': 'Take a break',
  'privacySettings.deactivate.description':
    'Deactivate your account if you want to stop using Montra for a while.',
  'privacySettings.deactivate.signOut': 'You’re signed out on every device, including this one.',
  'privacySettings.deactivate.kept': 'Nothing is deleted: your records stay as they are.',
  'privacySettings.deactivate.return': 'Sign in again any time to reactivate your account.',
  'privacySettings.deactivate.action': 'Deactivate account',
  'privacySettings.deactivate.confirm.title': 'Deactivate your account?',
  'privacySettings.deactivate.confirm.body':
    'You’ll be signed out on every device. Nothing is deleted, and signing in again reactivates your account.',
  'privacySettings.deactivate.confirm.action': 'Deactivate',
  'privacySettings.deactivate.done': 'Your account is deactivated',
  'privacySettings.deactivate.doneBody': 'Sign in any time to reactivate it.',
  'privacySettings.deletion.title': 'Delete your account',
  'privacySettings.deletion.description':
    'Your account and personal data are removed for good after a grace period. Until then you can cancel.',
  'privacySettings.deletion.loading': 'Checking deletion status…',
  'privacySettings.deletion.error': 'We couldn’t check your deletion status',
  'privacySettings.deletion.grace': {
    one: 'Your account is deleted {count} day after you confirm. You can cancel at any time before then, and everything stays as it is.',
    other:
      'Your account is deleted {count} days after you confirm. You can cancel at any time before then, and everything stays as it is.',
  },
  'privacySettings.deletion.graceUnknown':
    'Your account is deleted after a grace period. You can cancel at any time before then, and everything stays as it is.',
  'privacySettings.deletion.consequences': 'What happens',
  'privacySettings.deletion.groupImpact': 'Your groups',
  'privacySettings.deletion.retained': 'What is kept, and why',
  'privacySettings.deletion.englishOnly':
    'Some of these details come from Montra’s servers and are shown in English.',
  'privacySettings.deletion.start': 'Delete my account…',
  'privacySettings.deletion.dialogTitle': 'Delete your account?',
  'privacySettings.deletion.dialogBody':
    'This schedules your account for deletion. Montra may ask for your password to confirm it’s you.',
  'privacySettings.deletion.dialogGrace': {
    one: 'It will be deleted {count} day from now unless you cancel.',
    other: 'It will be deleted {count} days from now unless you cancel.',
  },
  'privacySettings.deletion.dialogGraceUnknown':
    'It will be deleted when the grace period ends unless you cancel.',
  'privacySettings.deletion.confirmLabel': 'Type {word} to confirm',
  'privacySettings.deletion.confirmHelp': 'This makes sure no account is deleted by accident.',
  'privacySettings.deletion.confirmMismatch': 'Type {word} exactly as shown.',
  'privacySettings.deletion.reason': 'Why are you leaving?',
  'privacySettings.deletion.reasonHelp': 'It’s removed when your account is deleted.',
  'privacySettings.deletion.keepAccount': 'Keep my account',
  'privacySettings.deletion.schedule': 'Schedule deletion',
  'privacySettings.deletion.alreadyScheduled':
    'A deletion is already scheduled. The page now shows it.',
  'privacySettings.deletion.scheduledToast': 'Account deletion scheduled',
  'privacySettings.deletion.scheduledFor':
    'Your account will be deleted on {date}. You can cancel until then.',
  'privacySettings.deletion.scheduledTitle': 'Your account is scheduled for deletion',
  'privacySettings.deletion.scheduledBody':
    'It will be deleted on {date}. Until then you can cancel, and everything stays as it is.',
  'privacySettings.deletion.scheduledBodyNoDate':
    'It will be deleted when the grace period ends. Until then you can cancel, and everything stays as it is.',
  'privacySettings.deletion.exportFirst':
    'If you want a copy of your data, download an export before then.',
  'privacySettings.deletion.cancel': 'Cancel deletion',
  'privacySettings.deletion.cancelled': 'Deletion cancelled',
  'privacySettings.deletion.cancelledBody': 'Your account stays as it is.',
  'privacySettings.deletion.nothingToCancel': 'There’s no scheduled deletion to cancel.',
  'privacySettings.deletion.processingTitle': 'Your account is being deleted',
  'privacySettings.deletion.processingBody':
    'The grace period has ended and deletion has started. It can’t be stopped now.',
  'privacySettings.deletion.failedTitle': 'An earlier deletion didn’t finish',
  'privacySettings.deletion.failedBody':
    'Something went wrong while deleting your account. Contact support so the team can help.',
  'privacySettings.deletion.contactSupport': 'Contact support',
  'privacySettings.limits.title': 'Fair-use limits',
  'privacySettings.limits.description':
    'The limits that keep Montra fast for everyone, and how much of your storage you use.',
  'privacySettings.limits.free.title': 'Everything is free, for everyone',
  'privacySettings.limits.free.body':
    'There are no paid plans or upgrades. These limits are the same for every account; they keep Montra fast and affordable to run.',
  'privacySettings.limits.loading': 'Loading the limits…',
  'privacySettings.limits.error': 'We couldn’t load the limits',
  'privacySettings.limits.storage.title': 'Your storage',
  'privacySettings.limits.storage.description':
    'Receipts, statements and attachments you upload count towards it.',
  'privacySettings.limits.storage.used': '{used} of {quota} used ({percent})',
  'privacySettings.limits.storage.noCap': 'You use {used}. There’s no storage cap right now.',
  'privacySettings.limits.storage.meter': 'Storage used',
  'privacySettings.limits.storage.full': 'Full',
  'privacySettings.limits.storage.nearlyFull': 'Almost full',
  'privacySettings.limits.storage.freeUp':
    'To make room, delete files you no longer need, such as old receipts or statement files.',
  'privacySettings.limits.records.title': 'Limits on files and records',
  'privacySettings.limits.records.description': 'Most people never come close to these.',
  'privacySettings.limits.maxUpload': 'Largest file',
  'privacySettings.limits.maxUploadHelp':
    'The biggest single file you can upload. Some kinds of files have a smaller limit.',
  'privacySettings.limits.importRows': 'Statement import',
  'privacySettings.limits.rows': { one: '{count} row', other: '{count} rows' },
  'privacySettings.limits.importRowsHelp':
    'The most rows one import can read. Split a bigger statement into smaller files.',
  'privacySettings.limits.openRecurring': 'Recurring rules',
  'privacySettings.limits.openRecurringHelp':
    'Recurring rules that haven’t ended. Bill schedules count too.',
  'privacySettings.limits.openBills': 'Bills',
  'privacySettings.limits.openBillsHelp': 'Bills that aren’t archived.',
  'privacySettings.limits.openSubscriptions': 'Subscriptions',
  'privacySettings.limits.openSubscriptionsHelp': 'Subscriptions that aren’t cancelled.',
  'privacySettings.limits.openGoals': 'Goals',
  'privacySettings.limits.openGoalsHelp': 'Goals that aren’t archived.',
  'privacySettings.limits.supportRequests': 'Support requests',
  'privacySettings.limits.perDay': { one: '{count} per day', other: '{count} per day' },
  'privacySettings.limits.supportRequestsHelp': 'Requests you can send to support in 24 hours.',
  'privacySettings.limits.downloadWindow': 'Download window',
  'privacySettings.limits.downloadWindowHelp':
    'How long data exports and report downloads stay available.',
  'privacySettings.limits.deletionGrace': 'Deletion grace period',
  'privacySettings.limits.deletionGraceHelp':
    'How long you can cancel an account deletion after asking for it.',
  'privacySettings.limits.days': { one: '{count} day', other: '{count} days' },
  'privacySettings.limits.ai': 'AI requests',
  'privacySettings.limits.aiOff': 'Off',
  'privacySettings.limits.aiHelp':
    'Requests to Montra’s optional AI features, used only if you turn them on.',
  'privacySettings.limits.aiOffHelp': 'Montra’s optional AI features aren’t turned on.',
  'privacySettings.limits.rates.title': 'Request rates',
  'privacySettings.limits.rates.description':
    'How many requests the apps can make for you each minute, by kind.',
  'privacySettings.limits.rates.kind': 'Kind of request',
  'privacySettings.limits.rates.perMinute': 'Per minute',
  'privacySettings.limits.rates.burst': 'Burst allowance',
  'privacySettings.limits.rates.none': 'No request rates are published right now.',
  'privacySettings.limits.rates.over':
    'If you go over a rate, Montra asks you to wait a moment. Nothing is lost.',
  'privacySettings.limits.policy.default': 'Everyday use',
  'privacySettings.limits.policyHelp.default': 'Opening pages and reading your data.',
  'privacySettings.limits.policy.write': 'Saving changes',
  'privacySettings.limits.policyHelp.write': 'Adding, editing or deleting records.',
  'privacySettings.limits.policy.upload': 'Uploads',
  'privacySettings.limits.policyHelp.upload': 'Receipts, statements and attachments.',
  'privacySettings.limits.policy.export': 'Exports and reports',
  'privacySettings.limits.policyHelp.export': 'Data exports and report files.',
  'privacySettings.limits.policy.social': 'Friends, groups and communities',
  'privacySettings.limits.policyHelp.social': 'Friend requests, invitations and posts.',
  'privacySettings.limits.policy.auth': 'Sign-in and security',
  'privacySettings.limits.policyHelp.auth':
    'Sign-in attempts, password resets and the contact form.',
  'privacySettings.limits.policy.ai': 'AI requests',
  'privacySettings.limits.policyHelp.ai': 'Optional AI features.',
  'privacySettings.limits.backToPrivacy': 'Back to Privacy & data',
  'privacySettings.consents.versionUnknown':
    'This consent can’t be given right now. Reload the page and try again later.',
  'privacySettings.export.status.queued': 'Waiting to start',
  'privacySettings.export.status.running': 'Being prepared',
  'privacySettings.export.status.completed': 'Ready to download',
  'privacySettings.export.status.failed': 'Didn’t finish',
  'privacySettings.export.status.expired': 'No longer available',
  'privacySettings.export.historyTitle': 'Earlier exports',
  'privacySettings.export.requestedOn': 'Requested {date}',
  'privacySettings.export.downloadFrom': 'Download the export requested {date}',
  'privacySettings.export.listError': 'We couldn’t load your exports',
  'privacySettings.deletion.code.signed_out_and_integrations_revoked':
    'You’ll be signed out on every device, and every connected service will be disconnected.',
  'privacySettings.deletion.code.personal_records_deleted':
    'Your accounts, transactions, budgets, goals, subscriptions, receipts, imports and reports will be deleted for good.',
  'privacySettings.deletion.code.documents_removed':
    'Files you uploaded will be removed from storage.',
  'privacySettings.deletion.code.profile_removed_posts_anonymized':
    'Your profile will be removed; your community posts and comments will no longer show your name.',
  'privacySettings.deletion.code.irreversible_after_date':
    'After the scheduled date, this can’t be undone.',
  'privacySettings.deletion.code.shared_group_records_anonymized':
    'Your shares of group expenses and settlements stay, so other members’ balances remain correct; your name is replaced with “Deleted member”.',
  'privacySettings.deletion.code.security_audit_records_retained':
    'Security and audit records are kept without your name for the documented retention period, to meet legal and fraud-prevention duties.',
  'privacySettings.deletion.code.ownership_transfer':
    'Ownership of “{name}” will pass to its longest-standing admin or member.',
  'privacySettings.deletion.code.group_deleted':
    '“{name}” has no other members, so it will be deleted.',
} as const satisfies Record<string, Message>;

export default messages;
