import type { RefinementCtx } from 'zod';
import {
  type DecimalIssue,
  type DecimalRules,
  normalizeDecimalInput,
} from '@/shared/formatting/decimal';
import type { Translate } from '@/shared/i18n/types';

/** A localized message for an amount that could not be read exactly. */
export function decimalIssueMessage(
  issue: DecimalIssue,
  t: Translate,
  currency: string,
  exponent: number,
): string {
  switch (issue) {
    case 'empty':
      return t('validation.amountRequired');
    case 'format':
      return t('validation.amountFormat');
    case 'precision':
      return exponent === 0
        ? t('validation.amountWhole', { currency })
        : t('validation.amountPrecision', { currency, count: exponent });
    case 'negative':
      return t('validation.amountNegative');
    case 'zero':
      return t('validation.amountZero');
    case 'tooLarge':
      return t('validation.amountTooLarge');
  }
}

interface CheckAmountOptions extends DecimalRules {
  value: string;
  path: string;
  locale: string;
  currency: string;
  t: Translate;
  /** Empty input is acceptable (optional amounts). */
  optional?: boolean;
}

/** Validates a typed amount inside a zod superRefine; returns the canonical value. */
export function checkAmount(ctx: RefinementCtx, options: CheckAmountOptions): string | null {
  if (options.optional && options.value.trim() === '') return null;
  const result = normalizeDecimalInput(options.value, options.locale, options);
  if (result.ok) return result.value;
  ctx.addIssue({
    code: 'custom',
    path: [options.path],
    message: decimalIssueMessage(result.issue, options.t, options.currency, options.exponent),
  });
  return null;
}
