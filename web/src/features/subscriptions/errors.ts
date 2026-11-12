import { hasErrorCode } from '@/shared/api/errors';
import { errorDetailCode, financeErrorMessage } from '@/shared/finance/domainErrors';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/**
 * Coded subscription errors (docs/API.md "Domain rule codes"): 422 rules,
 * 409 CONFLICT / DUPLICATE details and the coded validation detail of the
 * cancel action. Shared codes (invalid_status_transition,
 * record_limit_reached) are localized by the shared finance helpers.
 */
const codeMessages: Readonly<Record<string, MessageKey>> = {
  subscription_not_cancelled: 'subscriptions.errors.notCancelled',
  subscription_inactive: 'subscriptions.payments.inactive',
  detection_already_decided: 'subscriptions.review.alreadyHandled',
  detection_evidence_missing: 'subscriptions.review.evidenceMissing',
  payment_already_linked: 'subscriptions.payments.alreadyLinkedHere',
  payment_linked_elsewhere: 'subscriptions.payments.linkedElsewhere',
  transaction_already_counted: 'subscriptions.payments.duplicate',
  cancellation_confirmation_required: 'subscriptions.cancel.confirmRequired',
};

/** A localized sentence for a failed subscription read or write. */
export function subscriptionErrorMessage(error: unknown, t: Translate, locale: string): string {
  const code = errorDetailCode(error);
  const key = code ? codeMessages[code] : undefined;
  if (key) return t(key);
  if (hasErrorCode(error, 'DUPLICATE')) return t('subscriptions.payments.duplicate');
  return financeErrorMessage(error, t, locale);
}
