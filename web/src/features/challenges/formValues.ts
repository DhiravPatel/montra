import { addDaysToLocalDate, isLocalDate } from '@/shared/formatting/dates';
import type { Translate } from '@/shared/i18n/types';
import { z } from 'zod';
import { isChallengeMetric, isChallengeType } from './labels';
import type {
  Challenge,
  ChallengeInput,
  ChallengeMetric,
  ChallengePatch,
  ChallengeVisibility,
} from './types';

/** The API’s limits (ChallengeInput / ChallengePatch). */
export const TITLE_MIN = 3;
export const TITLE_MAX = 120;
export const TEXT_MAX = 2000;
export const NOTE_MAX = 300;
export const TARGET_MAX = 3650;
export const PERCENT_MAX = 100;
/** An end date at most this many days after the start. */
export const MAX_SPAN_DAYS = 366;

export interface CreateValues {
  title: string;
  challengeType: string;
  description: string;
  rules: string;
  metric: ChallengeMetric;
  target: string;
  startsOn: string;
  endsOn: string;
  visibility: ChallengeVisibility;
  groupId: string;
  communityId: string;
  leaderboard: boolean;
  /** Your own sharing, saved right after the challenge is created. */
  shareProgress: boolean;
  showOnLeaderboard: boolean;
}

export function emptyCreateValues(
  today: string,
  preset: { groupId?: string | null; communityId?: string | null } = {},
): CreateValues {
  const visibility: ChallengeVisibility = preset.groupId
    ? 'group'
    : preset.communityId
      ? 'community'
      : 'private';
  return {
    title: '',
    challengeType: '',
    description: '',
    rules: '',
    metric: 'days',
    target: '',
    startsOn: today,
    endsOn: '',
    visibility,
    groupId: preset.groupId ?? '',
    communityId: preset.groupId ? '' : (preset.communityId ?? ''),
    leaderboard: false,
    shareProgress: false,
    showOnLeaderboard: false,
  };
}

/** A whole-number target within the API's range for the metric, or null. */
export function parseTarget(value: string, metric: ChallengeMetric): number | null {
  const text = value.trim();
  if (!/^\d{1,4}$/.test(text)) return null;
  const target = Number(text);
  const max = metric === 'percent' ? PERCENT_MAX : TARGET_MAX;
  return target >= 1 && target <= max ? target : null;
}

export function titleSchema(t: Translate) {
  return z
    .string()
    .trim()
    .min(1, { error: t('challenges.form.titleRequired') })
    .min(TITLE_MIN, { error: t('challenges.form.titleShort', { min: TITLE_MIN }) })
    .max(TITLE_MAX, { error: t('validation.maxLength', { max: TITLE_MAX }) });
}

export function textSchema(t: Translate) {
  return z.string().max(TEXT_MAX, { error: t('validation.maxLength', { max: TEXT_MAX }) });
}

export function createSchema(t: Translate, today: string) {
  return z
    .object({
      title: titleSchema(t),
      challengeType: z.string(),
      description: textSchema(t),
      rules: textSchema(t),
      metric: z.enum(['days', 'streak', 'milestones', 'percent']),
      target: z.string(),
      startsOn: z.string(),
      endsOn: z.string(),
      visibility: z.enum(['private', 'group', 'community', 'public']),
      groupId: z.string(),
      communityId: z.string(),
      leaderboard: z.boolean(),
      shareProgress: z.boolean(),
      showOnLeaderboard: z.boolean(),
    })
    .superRefine((values, ctx) => {
      if (!isChallengeType(values.challengeType)) {
        ctx.addIssue({
          code: 'custom',
          path: ['challengeType'],
          message: t('challenges.form.typeRequired'),
        });
      }
      if (parseTarget(values.target, values.metric) === null) {
        ctx.addIssue({
          code: 'custom',
          path: ['target'],
          message: t('challenges.form.targetInvalid', {
            max: values.metric === 'percent' ? PERCENT_MAX : TARGET_MAX,
          }),
        });
      }
      const startValid = isLocalDate(values.startsOn);
      if (!values.startsOn) {
        ctx.addIssue({ code: 'custom', path: ['startsOn'], message: t('validation.dateRequired') });
      } else if (!startValid) {
        ctx.addIssue({ code: 'custom', path: ['startsOn'], message: t('validation.dateInvalid') });
      }
      if (!values.endsOn) {
        ctx.addIssue({ code: 'custom', path: ['endsOn'], message: t('validation.dateRequired') });
      } else if (!isLocalDate(values.endsOn)) {
        ctx.addIssue({ code: 'custom', path: ['endsOn'], message: t('validation.dateInvalid') });
      } else if (startValid && values.endsOn < values.startsOn) {
        ctx.addIssue({ code: 'custom', path: ['endsOn'], message: t('validation.dateOrder') });
      } else if (startValid && values.endsOn > addDaysToLocalDate(values.startsOn, MAX_SPAN_DAYS)) {
        ctx.addIssue({
          code: 'custom',
          path: ['endsOn'],
          message: t('challenges.form.endTooLate'),
        });
      } else if (values.endsOn < today) {
        ctx.addIssue({ code: 'custom', path: ['endsOn'], message: t('challenges.form.endPassed') });
      }
      if (values.visibility === 'group' && !values.groupId) {
        ctx.addIssue({
          code: 'custom',
          path: ['groupId'],
          message: t('challenges.form.groupRequired'),
        });
      }
      if (values.visibility === 'community' && !values.communityId) {
        ctx.addIssue({
          code: 'custom',
          path: ['communityId'],
          message: t('challenges.form.communityRequired'),
        });
      }
    });
}

/** The create body for valid form values (null when the type or target is invalid). */
export function toChallengeInput(values: CreateValues): ChallengeInput | null {
  const target = parseTarget(values.target, values.metric);
  if (!isChallengeType(values.challengeType) || !isChallengeMetric(values.metric) || !target) {
    return null;
  }
  const description = values.description.trim();
  const rules = values.rules.trim();
  const shared = values.visibility !== 'private';
  return {
    title: values.title.trim(),
    challenge_type: values.challengeType,
    metric: values.metric,
    target_value: target,
    starts_on: values.startsOn,
    ends_on: values.endsOn,
    visibility: values.visibility,
    leaderboard_enabled: shared && values.leaderboard,
    ...(description ? { description } : {}),
    ...(rules ? { rules } : {}),
    ...(values.visibility === 'group' ? { group_id: values.groupId } : {}),
    ...(values.visibility === 'community' ? { community_id: values.communityId } : {}),
  };
}

/** API field (without `body.`) -> create form field. */
export const createServerFields = {
  title: 'title',
  challenge_type: 'challengeType',
  description: 'description',
  rules: 'rules',
  metric: 'metric',
  target_value: 'target',
  starts_on: 'startsOn',
  ends_on: 'endsOn',
  visibility: 'visibility',
  group_id: 'groupId',
  community_id: 'communityId',
  leaderboard_enabled: 'leaderboard',
} as const;

/** The edit dialog's values. */
export interface EditValues {
  title: string;
  description: string;
  rules: string;
  endsOn: string;
  leaderboard: boolean;
}

/**
 * The PATCH body: only what changed since `challenge`, with its `version`
 * (an empty description or rules clears it). Only `version` when nothing
 * changed.
 */
export function toChallengePatch(challenge: Challenge, values: EditValues): ChallengePatch {
  const patch: ChallengePatch = { version: challenge.version };
  const title = values.title.trim();
  if (title !== challenge.title) patch.title = title;
  const description = values.description.trim();
  if (description !== (challenge.description ?? '')) patch.description = description;
  const rules = values.rules.trim();
  if (rules !== (challenge.rules ?? '')) patch.rules = rules;
  if (values.endsOn !== challenge.ends_on) patch.ends_on = values.endsOn;
  const leaderboard = challenge.visibility !== 'private' && values.leaderboard;
  if (leaderboard !== challenge.leaderboard_enabled) patch.leaderboard_enabled = leaderboard;
  return patch;
}
