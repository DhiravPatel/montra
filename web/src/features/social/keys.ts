/**
 * Query keys of the Friends page. People are not finance data, so finance
 * writes do not refetch them; social writes refresh these and the sharing
 * pickers (sharingKeys) together (see invalidateSocial).
 */
export const socialKeys = {
  all: ['social'] as const,
  connections: () => ['social', 'connections'] as const,
  requests: () => ['social', 'requests'] as const,
  /** Every search answer (prefix of `search`). */
  searches: () => ['social', 'search'] as const,
  /** GET /users/search for one normalized username. */
  search: (username: string) => ['social', 'search', username] as const,
  /** The signed-in user's own profile and social privacy settings (GET /me). */
  profile: () => ['social', 'profile'] as const,
  /** People you blocked (GET /blocks), newest first, in pages. */
  blocks: () => ['social', 'blocks'] as const,
  /** People you muted (GET /mutes), newest first, in pages. */
  mutes: () => ['social', 'mutes'] as const,
};
