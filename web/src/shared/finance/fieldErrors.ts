import type { FieldValues, Path, UseFormSetError } from 'react-hook-form';
import type { ApiError } from '@/shared/api/errors';
import type { Translate } from '@/shared/i18n/types';
import { fieldIssueMessage } from './domainErrors';

/**
 * Like applyServerErrors(), but every detail is worded by its code
 * (`required`, `too_long`, `invalid_format`…) in the interface language;
 * the server's English message is the fallback. Keys of `fieldMap` are the
 * API field names without the `body.` prefix. Returns the messages that
 * could not be attached to a field, for the form's summary.
 */
export function applyCodedServerErrors<T extends FieldValues>(
  error: ApiError,
  setError: UseFormSetError<T>,
  fieldMap: Readonly<Partial<Record<string, Path<T>>>>,
  t: Translate,
): string[] {
  const unmatched: string[] = [];
  let focused = false;
  for (const detail of error.details) {
    const apiField = detail.field?.replace(/^body\./, '');
    const formField = apiField ? fieldMap[apiField] : undefined;
    const message = fieldIssueMessage(detail, t);
    if (formField) {
      setError(formField, { type: 'server', message }, { shouldFocus: !focused });
      focused = true;
    } else {
      unmatched.push(message);
    }
  }
  return unmatched;
}
