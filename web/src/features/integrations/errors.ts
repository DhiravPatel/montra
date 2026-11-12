import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/** Coded rules from integration endpoints (docs/API.md "Domain rule codes"). */
const rules: Readonly<Record<string, MessageKey>> = {
  consent_expired: 'integrations.error.consentExpired',
  reconnect_required: 'integrations.error.reconnect',
  account_inactive: 'integrations.error.accountInactive',
};

export type IntegrationAction = 'connect' | 'sync' | 'disconnect' | 'callback' | 'load';

/** A localized sentence for a failed integration request. */
export function integrationErrorMessage(
  error: unknown,
  t: Translate,
  action: IntegrationAction,
): string {
  const rule = domainRuleCode(error);
  if (rule) {
    const key = rules[rule.code];
    if (key) return t(key);
  }
  if (hasErrorCode(error, 'FEATURE_NOT_CONFIGURED')) {
    return t(
      action === 'connect' || action === 'callback'
        ? 'integrations.error.notAvailable'
        : 'integrations.error.noLongerAvailable',
    );
  }
  if (hasErrorCode(error, 'PROVIDER_UNAVAILABLE')) return t('integrations.error.providerFailed');
  if (hasErrorCode(error, 'GONE')) return t('integrations.error.requestExpired');
  if (hasErrorCode(error, 'CONFLICT') && action === 'sync') {
    return t('integrations.error.syncRunning');
  }
  if (hasErrorCode(error, 'NOT_FOUND') && action !== 'connect') {
    return t('integrations.error.connectionGone');
  }
  if (isApiError(error) && error.code === 'VALIDATION_ERROR' && action === 'connect') {
    const field = error.details[0]?.field ?? '';
    if (field === 'body.account_id') return t('integrations.error.chooseAccount');
    if (field === 'body.consent_confirm') return t('integrations.error.consentNeeded');
  }
  return describeError(error, t);
}
