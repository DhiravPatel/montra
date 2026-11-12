import { dailyCapMessage } from '@/features/communities/fieldCodes';
import { hasErrorCode } from '@/shared/api/errors';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { describeError } from '@/shared/i18n/describeError';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/** Coded challenge rules (422 DOMAIN_RULE_VIOLATION, docs/API.md "Domain rule codes"). */
const ruleMessages: Readonly<Record<string, MessageKey>> = {
  challenge_inactive: 'challenges.errors.inactive',
  challenge_not_open: 'challenges.errors.notOpen',
  challenge_cancelled: 'challenges.errors.cancelled',
  join_challenge_first: 'challenges.errors.joinFirst',
  join_community_first: 'challenges.errors.joinCommunityFirst',
  no_leaderboard: 'challenges.errors.noLeaderboard',
  leaderboard_opt_in_required: 'challenges.errors.leaderboardOptIn',
};

/** Rules the leaderboard explains in place (an info note, not a failure). */
const LEADERBOARD_NOTES: readonly string[] = ['no_leaderboard', 'leaderboard_opt_in_required'];

/** Whether a leaderboard answer is one of the API's calm explanations rather than an error. */
export function isLeaderboardNote(error: unknown): boolean {
  const code = challengeRuleCode(error);
  return code !== null && LEADERBOARD_NOTES.includes(code);
}

/** The rule code of a failed challenge write, when it is one this feature explains. */
export function challengeRuleCode(error: unknown): string | null {
  const code = domainRuleCode(error)?.code;
  return code && code in ruleMessages ? code : null;
}

/**
 * Why a challenge action failed, in the interface language. Field problems
 * (VALIDATION_ERROR details) are shown on the form fields by the caller.
 */
export function challengeErrorMessage(error: unknown, t: Translate): string {
  const code = challengeRuleCode(error);
  const key = code ? ruleMessages[code] : undefined;
  if (key) return t(key);
  if (hasErrorCode(error, 'NOT_FOUND')) return t('challenges.errors.notFound');
  if (hasErrorCode(error, 'FORBIDDEN')) return t('challenges.errors.forbidden');
  if (hasErrorCode(error, 'VERSION_CONFLICT')) return t('challenges.edit.conflictBody');
  const cap = dailyCapMessage(error, t);
  if (cap) return cap;
  return describeError(error, t);
}

/** Joining failed: 409 means you are already taking part. */
export function joinErrorMessage(error: unknown, t: Translate): string {
  if (hasErrorCode(error, 'CONFLICT')) return t('challenges.errors.alreadyJoined');
  return challengeErrorMessage(error, t);
}

/**
 * Creating failed. The daily cap (10 a day) answers 429 `daily_cap` with
 * Retry-After, so the message says when to try again; a 429 without it is
 * the short-burst limiter.
 */
export function createErrorMessage(error: unknown, t: Translate): string {
  const cap = dailyCapMessage(error, t);
  if (cap) return cap;
  if (hasErrorCode(error, 'RATE_LIMITED') && error.retryAfterSeconds === null) {
    return t('challenges.errors.dailyLimit');
  }
  const code = challengeRuleCode(error);
  const key = code ? ruleMessages[code] : undefined;
  // Nothing exists yet, so "not found" and "not allowed" keep their general wording.
  return key ? t(key) : describeError(error, t);
}
