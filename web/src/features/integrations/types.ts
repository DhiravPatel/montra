import type { components } from '@/shared/api/schema';

type Schemas = components['schemas'];

/** GET /integrations: the provider registry (with honest status) and your connections. */
export type IntegrationsOverview = Schemas['Overview'];
export type Provider = Schemas['ProviderInfo'];
export type ProviderStatus = Provider['status'];
export type ProviderKind = Provider['kind'];
export type Connection = Schemas['ConnectionDTO'];
export type ConnectionState = Connection['status'];
export type ConnectionStatus = Schemas['ConnectionStatus'];
export type SyncRun = Schemas['SyncRunDTO'];
export type SyncRunState = SyncRun['status'];
export type SyncTrigger = SyncRun['trigger'];
export type ConnectResult = Schemas['ConnectResult'];
export type DisconnectResult = Schemas['DisconnectResult'];
