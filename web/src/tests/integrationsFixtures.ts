import { http, HttpResponse } from 'msw';
import type {
  Connection,
  ConnectionStatus,
  IntegrationsOverview,
  Provider,
  SyncRun,
} from '@/features/integrations/types';
import { API, envelope } from './fixtures';
import { server } from './msw/server';

export const SANDBOX_PROVIDER = 'sandbox_bank';
export const AGGREGATOR_PROVIDER = 'account_aggregator_in';
export const CONNECTION_ID = 'e5f6a7b8-5555-4e6f-9a71-000000000040';
export const RUN_ID = 'e5f6a7b8-5555-4e6f-9a71-000000000041';
/** A one-time OAuth state as the API makes them (base64url, 32 characters). */
export const OAUTH_STATE = 'q3Vt8w2dPn6Yk1Xa9LmZc4Rb7Hs0Jf5E';

/** The server's own note (English; the page shows its localized equivalent). */
const NOTE =
  'Montra works fully without connections: add transactions manually or import statements. Montra never asks for bank passwords, UPI PINs or OTPs.';

/** The provider the API lists today: unavailable, with the reason (as on the live dev API). */
export function aggregatorProvider(overrides: Partial<Provider> = {}): Provider {
  return {
    id: AGGREGATOR_PROVIDER,
    name: 'Account Aggregator (India)',
    kind: 'account_aggregator',
    countries: ['IN'],
    capabilities: ['transactions', 'balances'],
    status: 'unavailable',
    status_reason:
      'Needs an approved Account Aggregator partner, FIU registration and legal review before launch.',
    consent_purpose: 'Read your bank transactions and balances to keep Montra up to date',
    consent_scope: ['transactions', 'balances'],
    consent_days: 365,
    ...overrides,
  };
}

/** A registered (available) provider like the backend's test sandbox adapter. */
export function sandboxProvider(overrides: Partial<Provider> = {}): Provider {
  return {
    id: SANDBOX_PROVIDER,
    name: 'Sandbox Bank',
    kind: 'bank_data',
    countries: ['IN'],
    capabilities: ['transactions', 'webhooks'],
    status: 'available',
    consent_purpose: 'Keep your Montra account up to date',
    consent_scope: ['transactions'],
    consent_days: 90,
    ...overrides,
  };
}

export function makeConnection(overrides: Partial<Connection> = {}): Connection {
  return {
    id: CONNECTION_ID,
    provider: SANDBOX_PROVIDER,
    status: 'connected',
    consent_purpose: 'Keep your Montra account up to date',
    consent_scope: ['transactions'],
    consent_granted_at: '2026-11-01T09:00:00Z',
    consent_expires_at: '2027-01-30T09:00:00Z',
    last_sync_at: '2026-11-04T09:00:00Z',
    last_sync_status: 'succeeded',
    created_at: '2026-11-01T08:59:00Z',
    ...overrides,
  };
}

export function makeSyncRun(overrides: Partial<SyncRun> = {}): SyncRun {
  return {
    id: RUN_ID,
    status: 'succeeded',
    trigger: 'backfill',
    items_fetched: 5,
    items_created: 3,
    items_updated: 0,
    items_skipped: 2,
    started_at: '2026-11-04T09:00:00Z',
    finished_at: '2026-11-04T09:00:05Z',
    created_at: '2026-11-04T08:59:59Z',
    ...overrides,
  };
}

export function makeConnectionStatus(
  connection: Connection = makeConnection(),
  runs: SyncRun[] = [makeSyncRun()],
): ConnectionStatus {
  return { ...connection, runs };
}

export function makeOverview(
  providers: Provider[] = [aggregatorProvider()],
  connections: Connection[] = [],
): IntegrationsOverview {
  return { providers, connections, note: NOTE };
}

/** Serves GET /integrations from a mutable overview. */
export function serveOverview(overview: IntegrationsOverview = makeOverview()) {
  const state = { overview, calls: 0 };
  server.use(
    http.get(`${API}/integrations`, () => {
      state.calls += 1;
      return HttpResponse.json(envelope(state.overview));
    }),
  );
  return state;
}
