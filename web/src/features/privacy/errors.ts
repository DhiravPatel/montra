import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { detailParam, errorDetailCode } from '@/shared/finance/domainErrors';

/*
 * Coded answers of POST and DELETE /me/deletion-request (docs/API.md):
 * 409 `deletion_already_scheduled`, 409 `no_deletion_scheduled` and 422
 * `confirm_word_mismatch` {word} on body.confirm. A 409 without a code
 * (an older server) means the same as the code for that call.
 */

/** Scheduling failed because a deletion is already scheduled. */
export function isDeletionAlreadyScheduled(error: unknown): boolean {
  const code = errorDetailCode(error, ['CONFLICT']);
  return (
    code === 'deletion_already_scheduled' || (code === null && hasErrorCode(error, 'CONFLICT'))
  );
}

/** Cancelling failed because nothing is scheduled any more. */
export function isNothingScheduled(error: unknown): boolean {
  const code = errorDetailCode(error, ['CONFLICT']);
  return code === 'no_deletion_scheduled' || (code === null && hasErrorCode(error, 'CONFLICT'));
}

/**
 * The word to type when the confirmation did not match (`confirm_word_mismatch`
 * names it in `params.word`), else null.
 */
export function confirmWordMismatch(error: unknown): string | null {
  if (!isApiError(error) || error.code !== 'VALIDATION_ERROR') return null;
  const detail = error.details.find((item) => item.code === 'confirm_word_mismatch');
  if (!detail) return null;
  return detailParam(detail.params, 'word') ?? '';
}
