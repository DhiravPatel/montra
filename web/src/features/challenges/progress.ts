import type { MessageKey, Translate } from '@/shared/i18n/types';
import { targetUnit } from './labels';
import type { Challenge, ChallengeMetric, ChallengeParticipation } from './types';

const progressKeys: Readonly<Record<ChallengeMetric, MessageKey>> = {
  days: 'challenges.progress.days',
  streak: 'challenges.progress.streak',
  milestones: 'challenges.progress.milestones',
  percent: 'challenges.progress.percent',
};

/**
 * Progress in words, from the server's values only: "3 of 7 days", "Best
 * streak: 2 of 5 days in a row", "4 of 10 check-ins" or "40% of an 80% goal".
 */
export function progressText(
  challenge: Pick<Challenge, 'metric' | 'target_value'>,
  me: Pick<ChallengeParticipation, 'progress_value'>,
  t: Translate,
): string {
  return t(progressKeys[challenge.metric], {
    value: me.progress_value,
    count: challenge.target_value,
  });
}

/** "60% of the target", from the API's `percent_complete` (0–100). */
export function percentText(me: Pick<ChallengeParticipation, 'percent_complete'>, t: Translate) {
  return t('challenges.progress.percentComplete', { percent: me.percent_complete });
}

/** The target in words, e.g. "7 days" or "80%". */
export function targetText(
  challenge: Pick<Challenge, 'metric' | 'target_value'>,
  t: Translate,
): string {
  return t(targetUnit[challenge.metric], { count: challenge.target_value });
}

/** The days you can check in for: within the challenge, up to today. */
export function checkInWindow(
  challenge: Pick<Challenge, 'starts_on' | 'ends_on'>,
  today: string,
): { first: string; last: string; open: boolean } {
  const last = challenge.ends_on < today ? challenge.ends_on : today;
  return { first: challenge.starts_on, last, open: challenge.starts_on <= today };
}

/** The halfway and target milestones the API marks with a notification. */
export const HALFWAY_PERCENT = 50;
export const TARGET_PERCENT = 100;
