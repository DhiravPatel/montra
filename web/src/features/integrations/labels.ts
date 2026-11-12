import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import type {
  ConnectionState,
  ProviderKind,
  ProviderStatus,
  SyncRunState,
  SyncTrigger,
} from './types';

interface StatusLook {
  label: MessageKey;
  tone: Tone;
  icon: IconName;
}

/** Provider availability, exactly as the server reports it (never upgraded by the client). */
export const providerStatusLook: Readonly<Record<ProviderStatus, StatusLook>> = {
  available: { label: 'integrations.provider.available', tone: 'success', icon: 'check-circle' },
  not_configured: {
    label: 'integrations.provider.not_configured',
    tone: 'neutral',
    icon: 'ban',
  },
  unavailable: { label: 'integrations.provider.unavailable', tone: 'warning', icon: 'ban' },
};

export const connectionStatusLook: Readonly<Record<ConnectionState, StatusLook>> = {
  pending: { label: 'integrations.connection.pending', tone: 'info', icon: 'clock' },
  connected: { label: 'integrations.connection.connected', tone: 'success', icon: 'check-circle' },
  syncing: { label: 'integrations.connection.syncing', tone: 'info', icon: 'refresh' },
  partial: { label: 'integrations.connection.partial', tone: 'warning', icon: 'alert-triangle' },
  failed: { label: 'integrations.connection.failed', tone: 'danger', icon: 'alert-circle' },
  consent_expired: {
    label: 'integrations.connection.consent_expired',
    tone: 'warning',
    icon: 'clock',
  },
  disconnected: { label: 'integrations.connection.disconnected', tone: 'neutral', icon: 'ban' },
  revoked: { label: 'integrations.connection.revoked', tone: 'neutral', icon: 'ban' },
};

export const syncRunLook: Readonly<Record<SyncRunState, StatusLook>> = {
  queued: { label: 'integrations.run.queued', tone: 'info', icon: 'clock' },
  running: { label: 'integrations.run.running', tone: 'info', icon: 'refresh' },
  succeeded: { label: 'integrations.run.succeeded', tone: 'success', icon: 'check-circle' },
  partial: { label: 'integrations.run.partial', tone: 'warning', icon: 'alert-triangle' },
  failed: { label: 'integrations.run.failed', tone: 'danger', icon: 'alert-circle' },
};

export const syncTriggerLabel: Readonly<Record<SyncTrigger, MessageKey>> = {
  manual: 'integrations.trigger.manual',
  scheduled: 'integrations.trigger.scheduled',
  webhook: 'integrations.trigger.webhook',
  backfill: 'integrations.trigger.backfill',
};

export const providerKindLabel: Readonly<Record<ProviderKind, MessageKey>> = {
  bank_data: 'integrations.kind.bank_data',
  account_aggregator: 'integrations.kind.account_aggregator',
  card: 'integrations.kind.card',
  payments: 'integrations.kind.payments',
};

/** What a provider can read (consent scope and capabilities share these words). */
const dataLabels: Readonly<Record<string, MessageKey>> = {
  transactions: 'integrations.data.transactions',
  balances: 'integrations.data.balances',
  webhooks: 'integrations.data.webhooks',
};

export function dataLabelKey(value: string): MessageKey | null {
  return dataLabels[value] ?? null;
}

/** Connections that can sync now (the server refuses the others with a reason). */
export const SYNCABLE: ReadonlySet<ConnectionState> = new Set(['connected', 'partial', 'failed']);

/** Connections that need a new consent to work again. */
export const NEEDS_RECONNECT: ReadonlySet<ConnectionState> = new Set([
  'consent_expired',
  'revoked',
  'disconnected',
]);

/** Sync and connection error codes (`last_error_code`, run `error_code`). */
const errorCodes: Readonly<Record<string, MessageKey>> = {
  token_exchange_failed: 'integrations.errorCode.token_exchange_failed',
  consent_expired: 'integrations.errorCode.consent_expired',
  provider_unavailable: 'integrations.errorCode.provider_unavailable',
  provider_error: 'integrations.errorCode.provider_error',
  token_unreadable: 'integrations.errorCode.token_unreadable',
  timed_out: 'integrations.errorCode.timed_out',
  sync_timed_out: 'integrations.errorCode.timed_out',
};

export function errorCodeKey(code: string | undefined): MessageKey | null {
  if (!code) return null;
  return errorCodes[code] ?? 'integrations.errorCode.other';
}
