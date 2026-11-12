import { z } from 'zod';
import type { Translate } from '@/shared/i18n/types';
import { firstUnmetPasswordRule, PASSWORD_MAX_LENGTH } from './password';

/** Reusable, localized field schemas. Build them with the current translator. */
export function emailSchema(t: Translate) {
  return z
    .string()
    .trim()
    .min(1, { error: t('validation.emailRequired') })
    .max(320, { error: t('validation.emailTooLong') })
    .pipe(z.email({ error: t('validation.emailInvalid') }));
}

/** Password entered to prove identity: only presence is checked client-side. */
export function currentPasswordSchema(t: Translate) {
  return z
    .string()
    .min(1, { error: t('validation.passwordRequired') })
    .max(PASSWORD_MAX_LENGTH, { error: t('validation.passwordTooLong') });
}

const passwordRuleMessage = {
  length: 'validation.passwordLength',
  notCommon: 'validation.passwordCommon',
  notEmail: 'validation.passwordContainsEmail',
  variety: 'validation.passwordVariety',
  tooLong: 'validation.passwordTooLong',
} as const;

/** A new password, checked against the same rules the API enforces. */
export function newPasswordSchema(t: Translate, email?: () => string | undefined) {
  return z.string().superRefine((value, ctx) => {
    if (value.length === 0) {
      ctx.addIssue({ code: 'custom', message: t('validation.passwordRequired') });
      return;
    }
    const failed = firstUnmetPasswordRule(value, email?.());
    if (failed) ctx.addIssue({ code: 'custom', message: t(passwordRuleMessage[failed]) });
  });
}

/** 6-digit authenticator code (spaces ignored). */
export function totpCodeSchema(t: Translate) {
  return z
    .string()
    .transform((value) => value.replace(/\s+/g, ''))
    .pipe(z.string().regex(/^\d{6}$/, { error: t('validation.totpCode') }));
}

/** Recovery code such as `abcde-fghij` (case and dash insensitive). */
export function recoveryCodeSchema(t: Translate) {
  return z
    .string()
    .trim()
    .min(1, { error: t('validation.recoveryCodeRequired') })
    .max(20, { error: t('validation.recoveryCodeInvalid') })
    .regex(/^[A-Za-z0-9-]+$/, { error: t('validation.recoveryCodeInvalid') });
}
