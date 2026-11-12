import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { InsightFeedback, InsightKind, InsightSeverity, InsightStatus } from './types';

/*
 * Localized labels for the insight enums. The maps are typed against the
 * generated unions, so a value added to the contract fails compilation
 * until it has a label. Insights are found by fixed rules: nothing here
 * calls them AI.
 */

export const INSIGHT_KINDS = [
  'anomaly',
  'savings',
  'summary',
  'forecast',
  'budget',
  'subscription',
  'recurring',
] as const satisfies readonly InsightKind[];

type MissingKinds = Exclude<InsightKind, (typeof INSIGHT_KINDS)[number]>;
/** Compile-time check: every contract kind is listed above. */
export const insightKindsAreListed: [MissingKinds] extends [never] ? true : MissingKinds = true;

export function isInsightKind(value: unknown): value is InsightKind {
  return typeof value === 'string' && (INSIGHT_KINDS as readonly string[]).includes(value);
}

export const kindLabel: Readonly<Record<InsightKind, MessageKey>> = {
  anomaly: 'insights.kind.anomaly',
  savings: 'insights.kind.savings',
  summary: 'insights.kind.summary',
  forecast: 'insights.kind.forecast',
  budget: 'insights.kind.budget',
  subscription: 'insights.kind.subscription',
  recurring: 'insights.kind.recurring',
};

export const kindIcon: Readonly<Record<InsightKind, IconName>> = {
  anomaly: 'eye',
  savings: 'banknote',
  summary: 'bar-chart',
  forecast: 'line-chart',
  budget: 'pie-chart',
  subscription: 'repeat',
  recurring: 'calendar',
};

/** Severity is shown with an icon and words; the tone is never the only signal. */
export const severityLabel: Readonly<Record<InsightSeverity, MessageKey>> = {
  info: 'insights.severity.info',
  notice: 'insights.severity.notice',
  warning: 'insights.severity.warning',
};

export const severityTone: Readonly<Record<InsightSeverity, Tone>> = {
  info: 'neutral',
  notice: 'info',
  warning: 'warning',
};

export const severityIcon: Readonly<Record<InsightSeverity, IconName>> = {
  info: 'info',
  notice: 'eye',
  warning: 'alert-triangle',
};

export const statusLabel: Readonly<Record<InsightStatus, MessageKey>> = {
  active: 'insights.status.active',
  dismissed: 'insights.status.dismissed',
  snoozed: 'insights.status.snoozed',
  expected: 'insights.status.expected',
  resolved: 'insights.status.resolved',
  muted: 'insights.status.muted',
};

export const statusIcon: Readonly<Record<InsightStatus, IconName>> = {
  active: 'circle',
  dismissed: 'x-circle',
  snoozed: 'clock',
  expected: 'check-circle',
  resolved: 'check',
  muted: 'bell-off',
};

/** "You said this was useful." for a recorded answer. */
export const feedbackGivenLabel: Readonly<Record<InsightFeedback, MessageKey>> = {
  helpful: 'insights.feedback.given.helpful',
  not_helpful: 'insights.feedback.given.not_helpful',
  incorrect: 'insights.feedback.given.incorrect',
  expected: 'insights.feedback.given.expected',
};

/** The rules the API runs today (subtype → what it looks for). */
const subtypeLabels: ReadonlyMap<string, MessageKey> = new Map<string, MessageKey>([
  ['unusual_amount', 'insights.subtype.unusual_amount'],
  ['category_spike', 'insights.subtype.category_spike'],
  ['new_merchant_large', 'insights.subtype.new_merchant_large'],
  ['possible_duplicate', 'insights.subtype.possible_duplicate'],
  ['subscription_price_increase', 'insights.subtype.subscription_price_increase'],
  ['missing_recurring_payment', 'insights.subtype.missing_recurring_payment'],
  ['cash_flow_change', 'insights.subtype.cash_flow_change'],
  ['subscription_costs', 'insights.subtype.subscription_costs'],
  ['unusual_frequency', 'insights.subtype.unusual_frequency'],
  ['recurring_amount_change', 'insights.subtype.recurring_amount_change'],
  ['repeated_budget_overspend', 'insights.subtype.repeated_budget_overspend'],
]);

/** A name for a rule; a rule this client does not know yet falls back to its kind. */
export function subtypeLabel(subtype: string, kind: InsightKind): MessageKey {
  return subtypeLabels.get(subtype) ?? kindLabel[kind];
}

/** "unusual_amount" → "Unusual amount": the fallback name of a rule this client does not know. */
export function humanizeSubtype(subtype: string): string {
  const words = subtype.replace(/_/g, ' ').trim();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

/** A name for a mute rule, whose insight (and so kind) may no longer be listed. */
export function muteLabel(subtype: string, t: Translate): string {
  const key = subtypeLabels.get(subtype);
  return key ? t(key) : humanizeSubtype(subtype);
}

/** What kind of record a rule's scope names (the API mutes the rule for the insight's scope). */
type ScopeKind = 'category' | 'account' | 'subscription' | 'recurring' | 'merchant' | 'budget';

const scopeKinds: ReadonlyMap<string, ScopeKind> = new Map<string, ScopeKind>([
  ['unusual_amount', 'category'],
  ['category_spike', 'category'],
  ['possible_duplicate', 'account'],
  ['subscription_price_increase', 'subscription'],
  ['missing_recurring_payment', 'recurring'],
  ['recurring_amount_change', 'recurring'],
  ['unusual_frequency', 'merchant'],
  ['repeated_budget_overspend', 'budget'],
]);

const muteBodies: Readonly<Record<ScopeKind | 'item', MessageKey>> = {
  category: 'insights.mute.body.category',
  account: 'insights.mute.body.account',
  subscription: 'insights.mute.body.subscription',
  recurring: 'insights.mute.body.recurring',
  merchant: 'insights.mute.body.merchant',
  budget: 'insights.mute.body.budget',
  item: 'insights.mute.body.item',
};

const muteScopes: Readonly<Record<ScopeKind | 'item' | 'everywhere', MessageKey>> = {
  category: 'insights.muted.scope.category',
  account: 'insights.muted.scope.account',
  subscription: 'insights.muted.scope.subscription',
  recurring: 'insights.muted.scope.recurring',
  merchant: 'insights.muted.scope.merchant',
  budget: 'insights.muted.scope.budget',
  item: 'insights.muted.scope.item',
  everywhere: 'insights.muted.scope.everywhere',
};

/** The sentence of the mute confirmation. */
export function muteBody(subtype: string, scope: string): MessageKey {
  if (scope === '*') return 'insights.mute.body.everywhere';
  return muteBodies[scopeKinds.get(subtype) ?? 'item'];
}

/** What a mute rule covers, for the muted list ("For one category", "Everywhere"). */
export function muteScopeLabel(subtype: string, scope: string): MessageKey {
  if (scope === '*') return muteScopes.everywhere;
  return muteScopes[scopeKinds.get(subtype) ?? 'item'];
}

/** The rule that fired (`rule_code`, docs/API.md), in the interface language. */
const ruleLabels: ReadonlyMap<string, MessageKey> = new Map<string, MessageKey>([
  ['amount_3x_median_above_p95', 'insights.rule.amount_3x_median_above_p95'],
  ['month_to_date_above_3_month_average', 'insights.rule.month_to_date_above_3_month_average'],
  ['first_at_merchant_2x_median_expense', 'insights.rule.first_at_merchant_2x_median_expense'],
  ['same_account_amount_within_2_days', 'insights.rule.same_account_amount_within_2_days'],
  ['recorded_price_change', 'insights.rule.recorded_price_change'],
  ['overdue_recurring_occurrence', 'insights.rule.overdue_recurring_occurrence'],
  [
    'spending_up_25_or_income_down_20_vs_3_months',
    'insights.rule.spending_up_25_or_income_down_20_vs_3_months',
  ],
  [
    'active_subscriptions_normalized_monthly',
    'insights.rule.active_subscriptions_normalized_monthly',
  ],
  ['4_in_7_days_and_3x_weekly_average', 'insights.rule.4_in_7_days_and_3x_weekly_average'],
  ['latest_differs_10_from_median_of_6', 'insights.rule.latest_differs_10_from_median_of_6'],
  ['over_limit_2_of_last_3_periods', 'insights.rule.over_limit_2_of_last_3_periods'],
]);

/** The localized rule, or null for a rule code this client does not know (show evidence.rule). */
export function ruleLabel(ruleCode: string | undefined): MessageKey | null {
  if (!ruleCode) return null;
  return ruleLabels.get(ruleCode) ?? null;
}
