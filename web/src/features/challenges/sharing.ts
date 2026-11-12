import type { ChallengeSharing } from './types';

/** Your two opt-ins as the form holds them. */
export interface SharingChoice {
  share: boolean;
  leaderboard: boolean;
}

/** The API body: the leaderboard needs sharing, and both are opt-in. */
export function sharingBody(choice: SharingChoice, leaderboardEnabled: boolean): ChallengeSharing {
  return {
    share_progress: choice.share,
    show_on_leaderboard: leaderboardEnabled && choice.share && choice.leaderboard,
  };
}
