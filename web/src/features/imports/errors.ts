import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { domainRuleCode, domainRuleMessage } from '@/shared/finance/domainErrors';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/** DOMAIN_RULE_VIOLATION codes the import endpoints (and file uploads) can return. */
const ruleMessages: Readonly<Record<string, MessageKey>> = {
  no_rows: 'imports.errors.noRows',
  row_invalid: 'imports.errors.rowInvalid',
  storage_quota_exceeded: 'imports.errors.storageQuota',
};

/**
 * A localized message for a failed import write: coded rule violations
 * first, then the import's state conflicts (its status moved on, it was
 * already imported), then the shared finance rules and generic error text.
 */
export function importErrorMessage(error: unknown, t: Translate, locale: string): string {
  const rule = domainRuleCode(error);
  if (rule) {
    const key = ruleMessages[rule.code];
    if (key) return t(key);
  }
  // Upload refusals may carry the quota code on a validation error.
  if (
    isApiError(error) &&
    error.details.some((detail) => detail.code === 'storage_quota_exceeded')
  ) {
    return t('imports.errors.storageQuota');
  }
  if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
    return domainRuleMessage(error, t, locale) ?? describeError(error, t);
  }
  if (hasErrorCode(error, 'DUPLICATE')) return t('imports.errors.alreadyImported');
  if (hasErrorCode(error, 'VERSION_CONFLICT')) return t('finance.conflict.body');
  if (hasErrorCode(error, 'CONFLICT')) return t('imports.errors.stateChanged');
  if (
    hasErrorCode(error, 'IDEMPOTENCY_CONFLICT') ||
    hasErrorCode(error, 'IDEMPOTENCY_IN_PROGRESS')
  ) {
    return t('finance.errors.maybeSaved');
  }
  if (hasErrorCode(error, 'NOT_FOUND')) return t('imports.errors.notFound');
  return describeError(error, t);
}

/** True when the import changed on the server and should be reloaded before trying again. */
export function isStateConflict(error: unknown): boolean {
  return (
    hasErrorCode(error, 'CONFLICT') ||
    hasErrorCode(error, 'VERSION_CONFLICT') ||
    hasErrorCode(error, 'IDEMPOTENCY_CONFLICT') ||
    hasErrorCode(error, 'IDEMPOTENCY_IN_PROGRESS') ||
    hasErrorCode(error, 'DUPLICATE') ||
    hasErrorCode(error, 'NOT_FOUND')
  );
}
