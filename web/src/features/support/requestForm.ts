import type { FieldValues, Path, UseFormSetError } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { describeError } from '@/shared/i18n/describeError';
import type { Translate } from '@/shared/i18n/types';
import { dailyCapMessage } from './errors';
import { containsSecret } from './secrets';

/** Limits the API enforces (in characters, counted as code points like the API does). */
export const SUBJECT_MIN = 3;
export const SUBJECT_MAX = 160;
export const BODY_MAX = 5000;

const length = (value: string) => Array.from(value).length;

/** Subject and message rules shared by the signed-in and the signed-out forms. */
export function messageFields(t: Translate) {
  return {
    subject: z
      .string()
      .trim()
      .refine((value) => length(value) >= SUBJECT_MIN && length(value) <= SUBJECT_MAX, {
        error: t('support.form.subjectLength', { min: SUBJECT_MIN, max: SUBJECT_MAX }),
      })
      .refine((value) => !containsSecret(value), { error: t('support.form.secret') }),
    body: z
      .string()
      .trim()
      .min(1, { error: t('support.form.bodyRequired') })
      .refine((value) => length(value) <= BODY_MAX, {
        error: t('validation.maxLength', { max: BODY_MAX }),
      })
      .refine((value) => !containsSecret(value), { error: t('support.form.secret') }),
  };
}

interface MessageFieldNames<T extends FieldValues> {
  kind: Path<T>;
  subject: Path<T>;
  body: Path<T>;
  contactEmail?: Path<T>;
}

interface SupportErrorOptions {
  /** The signed-out contact form (its daily cap counts one email address). */
  contact?: boolean;
}

/**
 * Shows a refused request's field problems in the user's language (the API's
 * field messages are English only): `contains_secret` names the problem, other
 * field problems repeat the field's rule. A daily cap explains the limit and
 * when sending works again. Returns a form-level message, or null when every
 * problem was attached to a field.
 */
export function supportErrorMessage<T extends FieldValues>(
  error: unknown,
  t: Translate,
  setError: UseFormSetError<T>,
  fields: MessageFieldNames<T>,
  options: SupportErrorOptions = {},
): string | null {
  const capped = dailyCapMessage(error, t, options);
  if (capped) return capped;
  if (!hasErrorCode(error, 'VALIDATION_ERROR')) return describeError(error, t);
  const known: Partial<Record<string, { field: Path<T>; message: string }>> = {
    kind: { field: fields.kind, message: t('support.form.kindRequired') },
    subject: {
      field: fields.subject,
      message: t('support.form.subjectLength', { min: SUBJECT_MIN, max: SUBJECT_MAX }),
    },
    body: { field: fields.body, message: t('support.form.bodyRefused', { max: BODY_MAX }) },
    ...(fields.contactEmail
      ? { contact_email: { field: fields.contactEmail, message: t('validation.emailInvalid') } }
      : {}),
  };
  let attached = 0;
  for (const detail of error.details) {
    const target = known[detail.field?.replace(/^body\./, '') ?? ''];
    if (!target) continue;
    const message = detail.code === 'contains_secret' ? t('support.form.secret') : target.message;
    setError(target.field, { type: 'server', message }, { shouldFocus: attached === 0 });
    attached += 1;
  }
  return attached > 0 ? null : describeError(error, t);
}
