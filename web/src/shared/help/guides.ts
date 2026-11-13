/**
 * In-app help guides (HELP-001): their IDs, topics and addresses. Screens
 * link to the guide about them through `helpGuidePath()` (or
 * <HelpGuideLink>); the guide pages live in features/support. Slugs match
 * the mobile app's routes (`/help/guides/<slug>`).
 */
export const helpGuideIds = [
  'gettingStarted',
  'noBank',
  'balances',
  'budgets',
  'recurring',
  'goals',
  'groupBalances',
  'imports',
  'reconciliation',
  'privacy',
  'twoStep',
  'fairUse',
  'troubleshooting',
] as const;

export type HelpGuideId = (typeof helpGuideIds)[number];

/** Topics in display order, each with its guides in order. */
export const helpTopics = [
  { id: 'start', guides: ['gettingStarted', 'noBank'] },
  { id: 'calculations', guides: ['balances', 'budgets', 'recurring', 'goals', 'groupBalances'] },
  { id: 'statements', guides: ['imports', 'reconciliation'] },
  { id: 'account', guides: ['privacy', 'twoStep', 'fairUse'] },
  { id: 'troubleshooting', guides: ['troubleshooting'] },
] as const satisfies readonly { id: string; guides: readonly HelpGuideId[] }[];

export type HelpTopicId = (typeof helpTopics)[number]['id'];

export const helpGuidesPath = '/help/guides';

/** `budgets` → `budgets`, `twoStep` → `two-step`. */
export function helpGuideSlug(id: HelpGuideId): string {
  return id.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
}

export function helpGuidePath(id: HelpGuideId, section?: string): string {
  return `${helpGuidesPath}/${helpGuideSlug(id)}${section ? `#${section}` : ''}`;
}

export function guideIdFromSlug(slug: string | undefined): HelpGuideId | null {
  return helpGuideIds.find((id) => helpGuideSlug(id) === slug) ?? null;
}
