import type { CommunityReactions, ReactionCounts } from './types';

/** The counts and the caller's reactions, as the API answers a reaction write. */
export function splitReactions(answer: CommunityReactions): {
  counts: ReactionCounts;
  mine: string[];
} {
  const { my_reactions: mine, ...counts } = answer;
  return { counts, mine };
}
