import { hasErrorCode } from '@/shared/api/errors';
import { domainRuleCode, errorDetailCode } from '@/shared/finance/domainErrors';
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

/** True when a username change failed because someone else has it. */
export function isUsernameTaken(error: unknown): boolean {
  return hasErrorCode(error, 'CONFLICT');
}
