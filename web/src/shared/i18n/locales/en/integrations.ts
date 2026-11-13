import type { Message } from '../../types';

/** English `integrations` messages (source of truth for their keys). */
const messages = {
  // Integrations: connected services, consent, sync and OAuth return
  'integrations.title': 'Integrations',
  'integrations.description':
    'Connect a bank or service so Montra can keep an account up to date. This is optional.',
  'integrations.loading': 'Loading integrations…',
  'integrations.error': 'We couldn’t load integrations',
  'integrations.manualFirst.title': 'Montra works fully without connections',
  'integrations.manualFirst.body':
    'Add transactions by hand or import a statement whenever you like. Connections are optional.',
  'integrations.manualFirst.never':
    'Montra never asks for your bank password, UPI PIN, OTP or card CVV. If you connect a service, you approve access on that service’s own site.',
  'integrations.importInstead': 'Import a statement',
  'integrations.connections.title': 'Your connections',
  'integrations.connections.empty': 'No connections',
  'integrations.connections.emptyBody':
    'You haven’t connected anything. Everything in Montra works without connections.',
  'integrations.connection.pending': 'Waiting for approval',
  'integrations.connection.connected': 'Connected',
  'integrations.connection.syncing': 'Syncing',
  'integrations.connection.partial': 'Partly synced',
  'integrations.connection.failed': 'Needs attention',
  'integrations.connection.consent_expired': 'Consent expired',
  'integrations.connection.disconnected': 'Disconnected',
  'integrations.connection.revoked': 'Disconnected',
  'integrations.connection.unknownProvider': 'A service that’s no longer listed',
  'integrations.connection.account': 'Account:',
  'integrations.connection.consentUntil': 'Consent until:',
  'integrations.connection.consentEnded': 'Consent ended:',
  'integrations.connection.lastSync': 'Last sync:',
  'integrations.connection.never': 'Not yet',
  'integrations.connection.expiredHelp':
    'Your consent ended, so syncing stopped. Reconnect to give consent again.',
  'integrations.connection.providerGone':
    'This service isn’t available any more, so it can’t sync.',
  'integrations.connection.reconnect': 'Reconnect',
  'integrations.connection.startAgain': 'Start again',
  'integrations.providers.title': 'Services',
  'integrations.providers.description':
    'Services you can connect. Each one shows what it would read.',
  'integrations.providers.noneAvailable':
    'None of these services can be connected yet. Each one says why.',
  'integrations.providers.empty': 'No services are listed',
  'integrations.provider.available': 'Available',
  'integrations.provider.not_configured': 'Not set up',
  'integrations.provider.unavailable': 'Not available',
  'integrations.provider.notConfiguredHelp':
    'This service isn’t set up on this Montra server, so it can’t be connected.',
  'integrations.provider.unavailableHelp': 'You can’t connect this service yet.',
  'integrations.provider.reads': 'Would read: {data}',
  'integrations.provider.connect': 'Connect',
  'integrations.kind.bank_data': 'Bank data',
  'integrations.kind.account_aggregator': 'Account Aggregator',
  'integrations.kind.card': 'Cards',
  'integrations.kind.payments': 'Payments',
  'integrations.data.transactions': 'transactions',
  'integrations.data.balances': 'account balances',
  'integrations.data.webhooks': 'instant update notices',
  'integrations.connect.title': 'Connect {provider}',
  'integrations.connect.description':
    'Read what you’re agreeing to. You’ll approve access on {provider}’s own site.',
  'integrations.connect.consentHeading': 'What you’re agreeing to',
  'integrations.connect.purpose': 'Why',
  'integrations.connect.shared': 'What Montra will read',
  'integrations.connect.duration': 'For how long',
  'integrations.connect.days': {
    one: '{count} day, unless you disconnect sooner',
    other: '{count} days, unless you disconnect sooner',
  },
  'integrations.connect.neverTitle': 'What Montra never does',
  'integrations.connect.neverCredentials':
    'Montra never asks for your bank password, UPI PIN, OTP or card CVV. You sign in on {provider}’s own site.',
  'integrations.connect.neverPayments':
    'Montra can only read. It can’t move money or make payments.',
  'integrations.connect.disconnectAnyTime':
    'You can disconnect at any time and choose whether to delete what was imported.',
  'integrations.connect.loadingAccounts': 'Loading your accounts…',
  'integrations.connect.noAccount.title': 'Add an account first',
  'integrations.connect.noAccount.body':
    'Montra needs an active account to put the imported transactions in.',
  'integrations.connect.noAccount.action': 'Add an account',
  'integrations.connect.account': 'Montra account to fill',
  'integrations.connect.accountHelp': 'Transactions from {provider} are added to this account.',
  'integrations.connect.accountPlaceholder': 'Choose an account',
  'integrations.connect.accountRequired': 'Choose the account to fill.',
  'integrations.connect.agree': {
    one: 'I agree that Montra may read my {data} from {provider} for {count} day, for the reason above.',
    other:
      'I agree that Montra may read my {data} from {provider} for {count} days, for the reason above.',
  },
  'integrations.connect.consentRequired': 'Agree to the consent to continue.',
  'integrations.connect.continue': 'Continue to {provider}',
  'integrations.connect.redirecting': 'Opening {provider}…',
  'integrations.connect.badRedirect':
    'The service’s approval page address looks wrong, so Montra didn’t open it. Try again later.',
  'integrations.sync.action': 'Sync now',
  'integrations.sync.started': 'Sync started',
  'integrations.sync.startedBody': 'New transactions appear when it finishes.',
  'integrations.sync.failed': 'Sync didn’t start',
  'integrations.history.title': 'Sync history',
  'integrations.history.show': 'Show sync history',
  'integrations.history.hide': 'Hide sync history',
  'integrations.history.label': 'Recent syncs',
  'integrations.history.loading': 'Loading sync history…',
  'integrations.history.error': 'We couldn’t load the sync history',
  'integrations.history.empty': 'No syncs yet.',
  'integrations.history.counts':
    'Read {fetched} · added {created} · updated {updated} · skipped {skipped}',
  'integrations.run.queued': 'Waiting',
  'integrations.run.running': 'Running',
  'integrations.run.succeeded': 'Finished',
  'integrations.run.partial': 'Partly finished',
  'integrations.run.failed': 'Failed',
  'integrations.trigger.manual': 'Started by you',
  'integrations.trigger.scheduled': 'Scheduled',
  'integrations.trigger.webhook': 'Update from the service',
  'integrations.trigger.backfill': 'First import',
  'integrations.errorCode.token_exchange_failed':
    'The service didn’t finish connecting. Try connecting again.',
  'integrations.errorCode.consent_expired': 'Your consent expired.',
  'integrations.errorCode.provider_unavailable':
    'The service wasn’t available. Montra will try again later.',
  'integrations.errorCode.provider_error':
    'The service sent an error. Montra will try again later.',
  'integrations.errorCode.token_unreadable':
    'Montra couldn’t use the stored access. Reconnect to fix this.',
  'integrations.errorCode.timed_out': 'The sync took too long and was stopped.',
  'integrations.errorCode.other': 'The last sync didn’t finish.',
  'integrations.disconnect.action': 'Disconnect',
  'integrations.disconnect.title': 'Disconnect {provider}?',
  'integrations.disconnect.body':
    'Montra stops syncing, deletes its stored access and asks {provider} to revoke it. Your consent ends now.',
  'integrations.disconnect.deleteData': 'Also delete the transactions this connection imported',
  'integrations.disconnect.deleteDataHelp':
    'They’re removed from your account and its balance. Transactions you added yourself stay.',
  'integrations.disconnect.confirm': 'Disconnect',
  'integrations.disconnect.done': 'Disconnected from {provider}',
  'integrations.disconnect.kept': 'Transactions already imported stay in your account.',
  'integrations.disconnect.deletedCount': {
    one: '{count} imported transaction was deleted.',
    other: '{count} imported transactions were deleted.',
  },
  'integrations.disconnect.dataAction': 'Delete imported transactions',
  'integrations.disconnect.dataTitle': 'Delete imported transactions?',
  'integrations.disconnect.dataBody':
    'This deletes the transactions this connection imported from {provider}.',
  'integrations.disconnect.dataConfirm': 'Delete transactions',
  'integrations.disconnect.dataDeleted': 'Imported transactions deleted',
  'integrations.error.consentExpired':
    'Your consent for this connection expired. Reconnect to renew it.',
  'integrations.error.reconnect': 'Connect again before syncing.',
  'integrations.error.accountInactive':
    'Choose an active account. Archived and closed accounts can’t be filled.',
  'integrations.error.notAvailable':
    'This service isn’t available. Add transactions by hand or import a statement instead.',
  'integrations.error.noLongerAvailable': 'This service isn’t available any more.',
  'integrations.error.providerFailed':
    'The service didn’t complete the connection, so nothing was saved. Try again from Integrations.',
  'integrations.error.requestExpired':
    'This connection request expired or was already used. Start again from Integrations.',
  'integrations.error.syncRunning': 'A sync is already running. Wait for it to finish.',
  'integrations.error.connectionGone': 'This connection no longer exists.',
  'integrations.error.chooseAccount': 'Choose one of your accounts.',
  'integrations.error.consentNeeded': 'Review and accept the consent to connect.',
  'integrations.callback.title': 'Finishing your connection',
  'integrations.callback.theProvider': 'the service',
  'integrations.callback.pending': 'Finishing the connection with {provider}…',
  'integrations.callback.back': 'Back to integrations',
  'integrations.callback.success.title': 'Connected to {provider}',
  'integrations.callback.success.body':
    'Montra is importing your transactions now. This can take a few minutes, and you can follow it in the sync history.',
  'integrations.callback.declined.title': 'You didn’t approve the connection',
  'integrations.callback.declined.body':
    'Nothing was shared with Montra from {provider}. You can try again from Integrations.',
  'integrations.callback.missing.title': 'This page is missing the service’s answer',
  'integrations.callback.missing.body': 'Start connecting again from Integrations.',
  'integrations.callback.expired.title': 'This connection request expired or was already used',
  'integrations.callback.expired.body':
    'A connection request works once, for 30 minutes. Start again from Integrations.',
  'integrations.callback.failed.title': 'The connection wasn’t completed',
} as const satisfies Record<string, Message>;

export default messages;
