import type { FieldValues, Path, UseFormSetError } from 'react-hook-form';
import type { ApiError } from '@/shared/api/errors';

/**
 * Maps API validation details (`details[].field` such as `body.password`) to
 * form fields. Keys of `fieldMap` are the API field names without the
 * `body.` prefix. Returns messages that could not be attached to a field so
 * the form can show them in its summary.
 */
export function applyServerErrors<T extends FieldValues>(
  error: ApiError,
  setError: UseFormSetError<T>,
  fieldMap: Readonly<Partial<Record<string, Path<T>>>>,
): string[] {
  const unmatched: string[] = [];
  let focused = false;
  for (const detail of error.details) {
    const apiField = detail.field?.replace(/^body\./, '');
    const formField = apiField ? fieldMap[apiField] : undefined;
    if (formField) {
      setError(formField, { type: 'server', message: detail.message }, { shouldFocus: !focused });
      focused = true;
    } else {
      unmatched.push(detail.message);
    }
  }
  return unmatched;
}
