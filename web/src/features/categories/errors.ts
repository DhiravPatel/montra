import { hasErrorCode } from '@/shared/api/errors';
import {
  detailParam,
  errorDetail,
  errorDetailCode,
  financeErrorMessage,
} from '@/shared/finance/domainErrors';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { inUseImpact } from './labels';

/*
 * Coded errors of the organize endpoints (docs/API.md "Domain rule codes"):
 * 422 DOMAIN_RULE_VIOLATION and 409 CONFLICT carry a reason in
 * details[0].code. Anything else falls back to the shared finance messages.
 */
const organizeRules: Readonly<Record<string, MessageKey>> = {
  category_merged: 'organize.errors.category_merged',
  category_already_merged: 'organize.errors.category_already_merged',
  merge_target_inactive: 'organize.errors.merge_target_inactive',
  merge_target_must_be_top_level: 'organize.merge.topLevelOnly',
  parent_category_archived: 'organize.errors.parent_category_archived',
  category_depth: 'organize.categories.form.depth',
  rule_category_unavailable: 'categoryRules.errors.categoryUnavailable',
};

/** The 409 name_taken reason, with the name the API compared (may be absent). */
export function nameTaken(
  error: unknown,
): { name: string | null; merchantId: string | null } | null {
  const detail = errorDetail(error, ['CONFLICT']);
  if (detail?.code !== 'name_taken') return null;
  return {
    name: detailParam(detail.params, 'name'),
    merchantId: detailParam(detail.params, 'merchant_id'),
  };
}

/**
 * Why a category is still in use (409 category_in_use): "12 transactions
 * and 1 budget that excludes it". Null when the API sent no counts.
 */
export function inUseList(error: unknown, t: Translate, locale: string): string | null {
  const detail = errorDetail(error, ['CONFLICT']);
  if (detail?.code !== 'category_in_use') return null;
  const lines = inUseImpact(detail.params, t).map((line) => line.text);
  if (lines.length === 0) return null;
  return new Intl.ListFormat(locale, { type: 'conjunction' }).format(lines);
}

/** True for a 409 category_in_use (with or without counts). */
export function isCategoryInUse(error: unknown): boolean {
  return errorDetailCode(error, ['CONFLICT']) === 'category_in_use';
}

/**
 * A localized sentence for a failed organize write. Field-level validation
 * is handled by the forms; this covers the coded rules and conflicts.
 */
export function organizeErrorMessage(error: unknown, t: Translate, locale: string): string {
  const code = errorDetailCode(error, ['DOMAIN_RULE_VIOLATION', 'CONFLICT']);
  const key = code ? organizeRules[code] : undefined;
  if (key) return t(key);
  if (code === 'category_in_use') {
    const list = inUseList(error, t, locale);
    return list
      ? t('organize.categories.delete.inUseList', { list })
      : t('organize.categories.delete.inUse');
  }
  if (code === 'name_taken') {
    const name = nameTaken(error)?.name;
    return name
      ? t('organize.errors.name_taken', { name })
      : t('organize.errors.name_taken_generic');
  }
  if (hasErrorCode(error, 'VALIDATION_ERROR') && error.details.length > 0) {
    return error.details.map((detail) => detail.message).join(' ');
  }
  return financeErrorMessage(error, t, locale);
}
