import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import type {
  Challenge,
  ChallengeMetric,
  ChallengeType,
  ChallengeVisibility,
  ParticipationStatus,
} from './types';

export const CHALLENGE_TYPES: readonly ChallengeType[] = [
  'no_spend',
  'savings_streak',
  'grocery_budget',
  'meal_planning',
  'travel_savings',
  'custom',
];

export const CHALLENGE_METRICS: readonly ChallengeMetric[] = [
  'days',
  'streak',
  'milestones',
  'percent',
];

export function isChallengeType(value: string): value is ChallengeType {
  return CHALLENGE_TYPES.some((type) => type === value);
}

export function isChallengeMetric(value: string): value is ChallengeMetric {
  return CHALLENGE_METRICS.some((metric) => metric === value);
}

const typeLabels: Readonly<Record<ChallengeType, MessageKey>> = {
  no_spend: 'challenges.type.no_spend',
  savings_streak: 'challenges.type.savings_streak',
  grocery_budget: 'challenges.type.grocery_budget',
  meal_planning: 'challenges.type.meal_planning',
  travel_savings: 'challenges.type.travel_savings',
  custom: 'challenges.type.custom',
};

const typeIcons: Readonly<Record<ChallengeType, IconName>> = {
  no_spend: 'wallet',
  savings_streak: 'repeat',
  grocery_budget: 'shopping-bag',
  meal_planning: 'calendar',
  travel_savings: 'globe',
  custom: 'target',
};

/** The challenge type's name; the API reports it as a plain string. */
export function challengeTypeLabel(type: string): MessageKey {
  return isChallengeType(type) ? typeLabels[type] : 'challenges.type.custom';
}

export function challengeTypeIcon(type: string): IconName {
  return isChallengeType(type) ? typeIcons[type] : 'flag';
}

export const metricLabel: Readonly<Record<ChallengeMetric, MessageKey>> = {
  days: 'challenges.metric.days',
  streak: 'challenges.metric.streak',
  milestones: 'challenges.metric.milestones',
  percent: 'challenges.metric.percent',
};

export const metricHelp: Readonly<Record<ChallengeMetric, MessageKey>> = {
  days: 'challenges.metric.daysHelp',
  streak: 'challenges.metric.streakHelp',
  milestones: 'challenges.metric.milestonesHelp',
  percent: 'challenges.metric.percentHelp',
};

/** The target's unit, e.g. "days in a row" (plural forms by `count`). */
export const targetUnit: Readonly<Record<ChallengeMetric, MessageKey>> = {
  days: 'challenges.target.days',
  streak: 'challenges.target.streak',
  milestones: 'challenges.target.milestones',
  percent: 'challenges.target.percent',
};

export const visibilityLabel: Readonly<Record<ChallengeVisibility, MessageKey>> = {
  private: 'challenges.visibility.private',
  group: 'challenges.visibility.group',
  community: 'challenges.visibility.community',
  public: 'challenges.visibility.public',
};

export const visibilityHelp: Readonly<Record<ChallengeVisibility, MessageKey>> = {
  private: 'challenges.visibility.privateHelp',
  group: 'challenges.visibility.groupHelp',
  community: 'challenges.visibility.communityHelp',
  public: 'challenges.visibility.publicHelp',
};

export const visibilityIcon: Readonly<Record<ChallengeVisibility, IconName>> = {
  private: 'lock',
  group: 'users',
  community: 'message-square',
  public: 'globe',
};

export interface StatusLook {
  tone: Tone;
  icon: IconName;
  key: MessageKey;
  /** A date for the label (e.g. "Starts 10 Nov"). */
  date?: string;
}

/**
 * Where the challenge stands for everyone, from the API's status, its
 * `ended` flag and the start date compared with the user's today.
 */
export function challengeStatusLook(challenge: Challenge, today: string): StatusLook {
  switch (challenge.status) {
    case 'cancelled':
      return { tone: 'neutral', icon: 'x-circle', key: 'challenges.status.cancelled' };
    case 'completed':
      return { tone: 'success', icon: 'check-circle', key: 'challenges.status.completed' };
    case 'draft':
      return { tone: 'neutral', icon: 'pencil', key: 'challenges.status.draft' };
    case 'active':
      if (challenge.ended) {
        return { tone: 'neutral', icon: 'clock', key: 'challenges.status.ended' };
      }
      if (challenge.starts_on > today) {
        return {
          tone: 'info',
          icon: 'calendar',
          key: 'challenges.status.upcoming',
          date: challenge.starts_on,
        };
      }
      return { tone: 'info', icon: 'play', key: 'challenges.status.active' };
  }
}

export const participationLook: Readonly<Record<ParticipationStatus, StatusLook>> = {
  active: { tone: 'info', icon: 'check', key: 'challenges.participation.active' },
  completed: { tone: 'success', icon: 'check-circle', key: 'challenges.participation.completed' },
  left: { tone: 'neutral', icon: 'log-out', key: 'challenges.participation.left' },
};
