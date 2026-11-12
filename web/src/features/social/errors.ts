import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { detailCount, domainRuleCode, errorDetailCode } from '@/shared/finance/domainErrors';
import { describeError } from '@/shared/i18n/describeError';
import type { Translate } from '@/shared/i18n/types';

/**
 * Social errors in the interface language. Blocks are never disclosed: the
 * API answers 404 for a blocked person, the same as for someone who does
 * not exist or is not findable, so messages never mention blocking.
 */

/** The coded reason of a 409 on POST /friend-requests, if any. */
export function sendConflictCode(error: unknown): 'already_friends' | 'request_pending' | null {
  const code = errorDetailCode(error, ['CONFLICT']);
  return code === 'already_friends' || code === 'request_pending' ? code : null;
}

/** True when the failure describes where things already stand (not a problem to fix). */
export function isSendStateNotice(error: unknown): boolean {
  return sendConflictCode(error) !== null || domainRuleCode(error)?.code === 'requests_closed';
}

/** POST /friend-requests failed. */
export function sendRequestError(error: unknown, t: Translate, name: string): string {
  if (domainRuleCode(error)?.code === 'requests_closed') return t('social.send.closed', { name });
  if (hasErrorCode(error, 'NOT_FOUND')) return t('social.send.notFound', { name });
  const conflict = sendConflictCode(error);
  if (conflict === 'already_friends') return t('social.send.alreadyFriends', { name });
  if (conflict === 'request_pending') return t('social.send.pending', { name });
  // 409 without a reason code (an older server): either of the two.
  if (hasErrorCode(error, 'CONFLICT')) return t('social.send.conflict', { name });
  return describeError(error, t);
}

/** Accept, decline or cancel failed. */
export function requestActionError(error: unknown, t: Translate): string {
  if (hasErrorCode(error, 'NOT_FOUND')) return t('social.requests.gone');
  return describeError(error, t);
}

/** Removing, blocking or unblocking failed. */
export function personActionError(error: unknown, t: Translate): string {
  return describeError(error, t);
}

export type UsernameProblem = 'taken' | 'reserved' | 'invalid';

/**
 * Why PATCH /me refused a username: 409 `username_taken` (someone else has
 * it; an uncoded 409 means the same on older servers), 422
 * `username_reserved` (kept for Montra and staff) or `username_invalid`
 * (not 3-30 of a-z 0-9 _ .). Null for any other failure.
 */
export function usernameProblem(error: unknown): UsernameProblem | null {
  if (!isApiError(error)) return null;
  const code = error.details.find((item) => item.code?.startsWith('username_'))?.code;
  if (code === 'username_taken' || (error.code === 'CONFLICT' && !code)) return 'taken';
  if (code === 'username_reserved') return 'reserved';
  if (code === 'username_invalid') return 'invalid';
  return null;
}

/** True when a username change failed because someone else has it. */
export function isUsernameTaken(error: unknown): boolean {
  return usernameProblem(error) === 'taken';
}

/** A username refusal in the interface language (null when it was not about the username). */
export function usernameErrorMessage(error: unknown, t: Translate): string | null {
  switch (usernameProblem(error)) {
    case 'taken':
      return t('social.username.taken');
    case 'reserved':
      return t('social.username.reserved');
    case 'invalid':
      return t('social.username.invalid');
    case null:
      return null;
  }
}

/**
 * The shortest search GET /users/search accepts, when it refused the text
 * as too short (`query_too_short` {min} on query.q); null otherwise.
 */
export function queryTooShortMin(error: unknown): number | null {
  if (!isApiError(error) || error.code !== 'VALIDATION_ERROR') return null;
  const detail = error.details.find((item) => item.code === 'query_too_short');
  if (!detail) return null;
  return detailCount(detail.params, 'min') ?? 3;
}
