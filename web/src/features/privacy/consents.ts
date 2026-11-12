import type { MessageKey } from '@/shared/i18n/types';
import type { Consent, Legal, RevocableConsent } from './types';

export interface OptionalConsent {
  type: RevocableConsent;
  title: MessageKey;
  /** What the consent allows, in plain words. */
  body: MessageKey;
  /** What changes when it is off (honest about consents that are recorded only). */
  whenOff: MessageKey;
  /**
   * Offered for granting here. AI consents are withdraw-only on the web: the
   * web portal has no AI features, but a consent given in another Montra
   * app can always be withdrawn.
   */
  grantable: boolean;
}

export const OPTIONAL_CONSENTS: readonly OptionalConsent[] = [
  {
    type: 'location',
    title: 'privacySettings.consent.location.title',
    body: 'privacySettings.consent.location.body',
    whenOff: 'privacySettings.consent.location.off',
    grantable: true,
  },
  {
    type: 'push_notifications',
    title: 'privacySettings.consent.push_notifications.title',
    body: 'privacySettings.consent.push_notifications.body',
    whenOff: 'privacySettings.consent.push_notifications.off',
    grantable: true,
  },
  {
    type: 'marketing_email',
    title: 'privacySettings.consent.marketing_email.title',
    body: 'privacySettings.consent.marketing_email.body',
    whenOff: 'privacySettings.consent.marketing_email.off',
    grantable: true,
  },
  {
    type: 'product_analytics',
    title: 'privacySettings.consent.product_analytics.title',
    body: 'privacySettings.consent.product_analytics.body',
    whenOff: 'privacySettings.consent.product_analytics.off',
    grantable: true,
  },
  {
    type: 'contacts_discovery',
    title: 'privacySettings.consent.contacts_discovery.title',
    body: 'privacySettings.consent.contacts_discovery.body',
    whenOff: 'privacySettings.consent.contacts_discovery.off',
    grantable: true,
  },
  {
    type: 'ai_processing',
    title: 'privacySettings.consent.ai_processing.title',
    body: 'privacySettings.consent.ai_processing.body',
    whenOff: 'privacySettings.consent.ai_processing.off',
    grantable: false,
  },
  {
    type: 'ai_receipt_processing',
    title: 'privacySettings.consent.ai_receipt_processing.title',
    body: 'privacySettings.consent.ai_receipt_processing.body',
    whenOff: 'privacySettings.consent.ai_receipt_processing.off',
    grantable: false,
  },
];

/** Accepted at sign-up and needed to use Montra (withdrawing them means deleting the account). */
export const REQUIRED_CONSENTS = ['terms', 'privacy_policy'] as const;

const consentTitles: Readonly<Record<string, MessageKey>> = {
  ...Object.fromEntries(OPTIONAL_CONSENTS.map((consent) => [consent.type, consent.title])),
  terms: 'privacySettings.consent.terms.title',
  privacy_policy: 'privacySettings.consent.privacy_policy.title',
  integration: 'privacySettings.consent.integration.title',
};

/** A consent type's name; a type this app doesn't know yet falls back to a generic label. */
export function consentTitle(type: string): MessageKey {
  return consentTitles[type] ?? 'privacySettings.consent.other.title';
}

/** The active (not withdrawn) consent of a type, if any. Scoped consents belong to integrations. */
export function activeConsent(consents: readonly Consent[], type: string): Consent | undefined {
  return consents.find(
    (consent) => consent.consent_type === type && !consent.revoked_at && !consent.scope,
  );
}

/**
 * The wording version to send when granting `type` (GET /legal `consents`).
 * The API accepts only the current version; null when /legal does not list it.
 */
export function consentVersion(legal: Legal | undefined, type: string): string | null {
  return legal?.consents.find((consent) => consent.type === type)?.version ?? null;
}
