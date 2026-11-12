import type { components } from '@/shared/api/schema';

type Schemas = components['schemas'];

/**
 * An opt-in challenge (spec §4.16): progress is self-reported in days,
 * streaks, check-ins or a percentage, never money, and stays private unless
 * the participant shares it.
 */
export type Challenge = Schemas['ChallengeDTO'];
/** The signed-in user's participation (`me`); absent when they never joined. */
export type ChallengeParticipation = Schemas['ChallengeParticipationDTO'];
export type ChallengeInput = Schemas['ChallengeInput'];
/** PATCH /challenges/{id}: only the fields sent change; `version` is required. */
export type ChallengePatch = Schemas['ChallengePatch'];
/** The group or community a challenge belongs to, named when the viewer may see it. */
export type ChallengeScopeRef = Schemas['ChallengeScopeRef'];
/** Sharing choices when joining, and later (PATCH /challenges/{id}/participation). */
export type ChallengeSharing = Schemas['ChallengeJoinInput'];
export type ChallengeProgressInput = Schemas['ChallengeProgressInput'];
/** One opted-in participant: a normalized percentage, never raw values. */
export type LeaderboardEntry = Schemas['ChallengeLeaderboardEntry'];

export type ChallengeType = ChallengeInput['challenge_type'];
export type ChallengeMetric = Challenge['metric'];
export type ChallengeVisibility = Challenge['visibility'];
export type ChallengeStatus = Challenge['status'];
export type ParticipationStatus = ChallengeParticipation['status'];

/** GET /challenges `scope`: ones you joined or created, or ones open to you. */
export type ChallengeScope = 'mine' | 'discover';

/** One cursor page of GET /challenges. */
export interface ChallengePage {
  items: Challenge[];
  /** The next page's cursor; null on the last page. */
  nextCursor: string | null;
}

/** A community the user belongs to (for community challenges). */
export type CommunityChoice = Schemas['CommunityDTO'];
