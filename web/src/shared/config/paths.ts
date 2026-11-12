/**
 * Route paths. Features link to each other only through these constants.
 * Add new feature routes here when the feature (UI + API) actually exists.
 */
export const paths = Object.freeze({
  landing: '/',
  privacy: '/privacy',
  securityInfo: '/security',
  terms: '/terms',
  signIn: '/sign-in',
  signUp: '/sign-up',
  verifyEmail: '/verify-email',
  forgotPassword: '/forgot-password',
  resetPassword: '/reset-password',
  account: '/account',
  /** Profile and preferences (SET-001). */
  profileSettings: '/settings/profile',
  securitySettings: '/settings/security',
  onboarding: '/onboarding',
  dashboard: '/dashboard',
  accounts: '/accounts',
  accountNew: '/accounts/new',
  paymentMethods: '/accounts/payment-methods',
  transactions: '/transactions',
  transactionNew: '/transactions/new',
  transferNew: '/transfers/new',
  categories: '/categories',
  categoryRules: '/categories/rules',
  tags: '/categories/tags',
  merchants: '/categories/merchants',
  budgets: '/budgets',
  budgetNew: '/budgets/new',
  planning: '/planning',
  bills: '/planning/bills',
  billNew: '/planning/bills/new',
  recurring: '/planning/recurring',
  recurringNew: '/planning/recurring/new',
  subscriptions: '/subscriptions',
  subscriptionNew: '/subscriptions/new',
  subscriptionReview: '/subscriptions/review',
  goals: '/goals',
  goalNew: '/goals/new',
  receipts: '/receipts',
  imports: '/imports',
  importNew: '/imports/new',
  analytics: '/analytics',
  reports: '/reports',
  exchangeRates: '/settings/exchange-rates',
  friends: '/friends',
  groups: '/groups',
  groupNew: '/groups/new',
  groupJoin: '/groups/join',
  communities: '/communities',
  communityNew: '/communities/new',
  communityJoin: '/communities/join',
  challenges: '/challenges',
  challengeNew: '/challenges/new',
  myModeration: '/settings/moderation',
  staffModeration: '/staff/moderation',
  notifications: '/notifications',
  notificationSettings: '/settings/notifications',
  unsubscribe: '/unsubscribe',
  integrations: '/settings/integrations',
  search: '/search',
  insights: '/insights',
  help: '/help',
  contact: '/contact',
  staffSupport: '/staff/support',
  staffUsage: '/staff/usage',
  privacySettings: '/settings/privacy',
  limits: '/settings/limits',
});

/** Where a signed-in user lands by default. */
export const defaultSignedInPath = paths.dashboard;

/*
 * Record paths carry only opaque IDs: never amounts, names, merchants or
 * descriptions (spec §20B.23).
 */
export const accountPath = (id: string) => `${paths.accounts}/${encodeURIComponent(id)}`;
export const accountEditPath = (id: string) => `${accountPath(id)}/edit`;
export const transactionPath = (id: string) => `${paths.transactions}/${encodeURIComponent(id)}`;
export const transactionEditPath = (id: string) => `${transactionPath(id)}/edit`;
export const merchantPath = (id: string) => `${paths.merchants}/${encodeURIComponent(id)}`;
export const budgetPath = (id: string) => `${paths.budgets}/${encodeURIComponent(id)}`;
export const budgetEditPath = (id: string) => `${budgetPath(id)}/edit`;
export const billPath = (id: string) => `${paths.bills}/${encodeURIComponent(id)}`;
export const billEditPath = (id: string) => `${billPath(id)}/edit`;
export const recurringPath = (id: string) => `${paths.recurring}/${encodeURIComponent(id)}`;
export const recurringEditPath = (id: string) => `${recurringPath(id)}/edit`;
export const subscriptionPath = (id: string) => `${paths.subscriptions}/${encodeURIComponent(id)}`;
export const subscriptionEditPath = (id: string) => `${subscriptionPath(id)}/edit`;
export const goalPath = (id: string) => `${paths.goals}/${encodeURIComponent(id)}`;
export const goalEditPath = (id: string) => `${goalPath(id)}/edit`;
export const receiptPath = (id: string) => `${paths.receipts}/${encodeURIComponent(id)}`;
export const importPath = (id: string) => `${paths.imports}/${encodeURIComponent(id)}`;
export const accountReconcilePath = (id: string) => `${accountPath(id)}/reconcile`;
export const groupPath = (id: string) => `${paths.groups}/${encodeURIComponent(id)}`;
export const groupSettingsPath = (id: string) => `${groupPath(id)}/settings`;
export const groupExpensesPath = (id: string) => `${groupPath(id)}/expenses`;
export const groupExpenseNewPath = (id: string) => `${groupExpensesPath(id)}/new`;
export const groupExpensePath = (groupId: string, expenseId: string) =>
  `${groupExpensesPath(groupId)}/${encodeURIComponent(expenseId)}`;
export const groupExpenseEditPath = (groupId: string, expenseId: string) =>
  `${groupExpensePath(groupId, expenseId)}/edit`;
export const groupBalancesPath = (id: string) => `${groupPath(id)}/balances`;
export const settlementPath = (groupId: string, settlementId: string) =>
  `${groupPath(groupId)}/settlements/${encodeURIComponent(settlementId)}`;
export const groupRecurringPath = (id: string) => `${groupPath(id)}/recurring`;
export const groupReportsPath = (id: string) => `${groupPath(id)}/reports`;
export const communityPath = (ref: string) => `${paths.communities}/${encodeURIComponent(ref)}`;
export const communitySettingsPath = (ref: string) => `${communityPath(ref)}/settings`;
export const communityModerationPath = (ref: string) => `${communityPath(ref)}/moderation`;
export const postPath = (id: string) => `/posts/${encodeURIComponent(id)}`;
export const challengePath = (id: string) => `${paths.challenges}/${encodeURIComponent(id)}`;
/** One insight on the insights page (highlighted there). */
export const insightPath = (id: string) => `${paths.insights}/${encodeURIComponent(id)}`;
export const supportRequestPath = (id: string) =>
  `${paths.help}/requests/${encodeURIComponent(id)}`;
export const integrationCallbackPath = (provider: string) =>
  `${paths.integrations}/${encodeURIComponent(provider)}/callback`;
/** Shareable community invitation link (one-time token in the URL fragment). */
export const communityJoinLink = (origin: string, token: string) =>
  `${origin}${paths.communityJoin}#token=${encodeURIComponent(token)}`;

/**
 * Shareable group invitation link. The one-time token travels in the URL
 * fragment, which browsers never send to servers (no logs, no referrers).
 */
export const groupJoinLink = (origin: string, token: string) =>
  `${origin}${paths.groupJoin}#token=${encodeURIComponent(token)}`;

/** A path with non-sensitive query parameters (IDs, dates, enum values). */
export function withQuery(path: string, query: Readonly<Record<string, string | undefined>>) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value) params.set(key, value);
  }
  const search = params.toString();
  return search ? `${path}?${search}` : path;
}

/**
 * Accepts only in-app absolute paths, so a `from` value can never redirect
 * the user to another site (no `//host`, schemes, or backslash tricks).
 */
export function isSafeInternalPath(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.startsWith('/') &&
    !value.startsWith('//') &&
    !value.includes('\\') &&
    !value.includes(':')
  );
}
