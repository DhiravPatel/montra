import type { components } from './schema';

type Schemas = components['schemas'];

export type User = Schemas['UserDTO'];
export type Session = Schemas['SessionDTO'];
export type AuthResult = Schemas['AuthResult'];
export type MfaSetup = Schemas['MFASetup'];
export type MfaActivation = Schemas['MFAActivation'];
export type ResponseMeta = Schemas['Meta'];
export type ErrorDetail = Schemas['Detail'];
export type ErrorBody = Schemas['ErrorResponse'];

/**
 * Money as the API returns it (ADR-006). Display `amount` with
 * formatMoney(); never do arithmetic on it in the client.
 */
export interface Money {
  amount_minor: number;
  /** Exact decimal string, e.g. "1234.50". */
  amount: string;
  /** ISO 4217 code. */
  currency: string;
}
