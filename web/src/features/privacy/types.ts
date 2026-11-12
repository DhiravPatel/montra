import type { components, operations } from '@/shared/api/schema';

/** Privacy and fair-use types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type Consent = Schemas['ConsentDTO'];
/** Consent types a user can withdraw (terms and privacy notice are required to use Montra). */
export type RevocableConsent =
  operations['me-consents-revoke']['parameters']['path']['consentType'];
export type ConsentGrant = Schemas['Me-consents-grantRequest'];

/** A data export request (POST /me/export, GET /me/export/{id}). */
export type ExportJob = Schemas['ExportDTO'];
export type ExportStatus = ExportJob['status'];
/** GET /legal: the current terms, privacy notice and consent wording versions (public). */
export type Legal = Schemas['LegalDTO'];
export type ConsentVersion = Schemas['ConsentVersionDTO'];
/** Groups you own and what deletion does to them (codes plus English text). */
export type GroupImpact = Schemas['GroupImpactDTO'];

/** A short-lived signed link to a stored file. */
export type FileAccess = Schemas['Access'];

/** Deletion status plus the API's disclosure (consequences, retained records, group impact). */
export type Deletion = Schemas['DeletionDTO'];
export type DeletionStatus = Deletion['status'];
export type DeletionRequest = Schemas['Me-deletion-requestRequest'];

/** Fair-use limits (the same for everyone) and the caller's usage. */
export type Limits = Schemas['Limits'];
export type RateLimit = Schemas['RateLimit'];
export type RatePolicy = RateLimit['policy'];
