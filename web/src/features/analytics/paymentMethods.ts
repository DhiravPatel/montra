import type { Translate } from '@/shared/i18n/types';
import type { PaymentMethodSlice } from './types';

/** The bucket of spending recorded without a payment method (no ID; localized by key). */
export const UNSPECIFIED_KEY = 'unspecified';

/** A payment method's name: the bucket by its key, others by label, last digits and status. */
export function paymentMethodName(slice: PaymentMethodSlice, t: Translate): string {
  if (slice.key === UNSPECIFIED_KEY && !slice.payment_method_id) {
    return t('analytics.paymentMethods.unspecified');
  }
  const named = slice.masked_hint
    ? t('analytics.paymentMethods.withHint', { name: slice.label, hint: slice.masked_hint })
    : slice.label;
  return slice.archived ? t('analytics.paymentMethods.archived', { name: named }) : named;
}

/**
 * The transactions behind a row: the API's own drill-down path when it is an
 * app path to the transactions list (it knows the exact filter, including
 * `payment_method_id=none` for the bucket), otherwise the same link built here.
 */
export function drillDownLink(slice: PaymentMethodSlice, fallback: () => string): string {
  const path = slice.drill_down_path;
  return /^\/transactions(\?|$)/.test(path) ? path : fallback();
}
