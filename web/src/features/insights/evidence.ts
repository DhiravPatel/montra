import {
  budgetPath,
  merchantPath,
  paths,
  recurringPath,
  subscriptionPath,
  transactionPath,
  withQuery,
} from '@/shared/config/paths';
import { isLocalDate } from '@/shared/formatting/dates';
import type { MessageKey } from '@/shared/i18n/types';
import type { Insight } from './types';

/*
 * An insight's `evidence` is a free-form object written by the rule that
 * found it. These helpers read it defensively and turn it into labelled
 * facts, the budget periods behind a suggestion, and links (IDs only) to
 * the records involved. Amounts are shown exactly as the server sent them:
 * `evidence.amounts` holds every amount as a Money object under its
 * evidence key (list entries such as `periods` carry their own `amounts`);
 * the top-level "1234.50 INR" strings are older and kept as a fallback.
 */

export interface MoneyValue {
  amount: string;
  currency: string;
}

const MONEY_TEXT = /^(-?\d+(?:\.\d+)?) ([A-Z]{3})$/;
const MONEY_AMOUNT = /^-?\d+(?:\.\d+)?$/;
const CURRENCY = /^[A-Z]{3}$/;

/** Evidence amounts arrive as "1234.50 INR" (exact decimal and ISO code); null otherwise. */
export function parseMoneyText(value: unknown): MoneyValue | null {
  if (typeof value !== 'string') return null;
  const match = MONEY_TEXT.exec(value.trim());
  if (!match) return null;
  const [, amount, currency] = match;
  return amount && currency ? { amount, currency } : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** A Money object `{amount, currency}` (exact decimal string, ISO code); null otherwise. */
export function readMoney(value: unknown): MoneyValue | null {
  if (!isRecord(value)) return null;
  const { amount, currency } = value;
  if (typeof amount !== 'string' || typeof currency !== 'string') return null;
  return MONEY_AMOUNT.test(amount) && CURRENCY.test(currency) ? { amount, currency } : null;
}

/** The Money object for `key` from an `amounts` map, else the old text form of `raw`. */
function moneyFor(amounts: unknown, key: string, raw: unknown): MoneyValue | null {
  return (isRecord(amounts) ? readMoney(amounts[key]) : null) ?? parseMoneyText(raw);
}

export type FactValue =
  | { type: 'money'; money: MoneyValue }
  | { type: 'text'; text: string }
  | { type: 'number'; value: number }
  | { type: 'days'; count: number }
  | { type: 'months'; count: number }
  | { type: 'percent'; value: string }
  | { type: 'perWeek'; value: string }
  | { type: 'date'; date: string };

type FactType = FactValue['type'];

export interface InsightFact {
  key: string;
  /** Localized label; null for a fact this client does not know yet. */
  labelKey: MessageKey | null;
  /** The key in words, for facts without a localized label. */
  fallbackLabel: string;
  value: FactValue;
}

/** Facts in display order: amounts first, then counts and windows, then the rule itself. */
const KNOWN_FACTS: readonly (readonly [key: string, label: MessageKey, type: FactType])[] = [
  ['amount', 'transactions.detail.amount', 'money'],
  ['usual_amount', 'insights.fact.usualAmount', 'money'],
  ['baseline_median', 'insights.fact.baselineMedian', 'money'],
  ['baseline_p95', 'insights.fact.baselineP95', 'money'],
  ['typical_expense', 'insights.fact.typicalExpense', 'money'],
  ['so_far', 'insights.fact.soFar', 'money'],
  ['monthly_average', 'insights.fact.monthlyAverage', 'money'],
  ['old', 'insights.fact.oldPrice', 'money'],
  ['new', 'insights.fact.newPrice', 'money'],
  ['spending', 'insights.fact.spending', 'money'],
  ['usual_spending', 'insights.fact.usualSpending', 'money'],
  ['income', 'insights.fact.income', 'money'],
  ['usual_income', 'insights.fact.usualIncome', 'money'],
  ['monthly', 'insights.fact.monthly', 'money'],
  ['yearly', 'insights.fact.yearly', 'money'],
  ['average_spent', 'insights.fact.averageSpent', 'money'],
  ['average_overspend', 'insights.fact.averageOverspend', 'money'],
  ['change_percent', 'insights.fact.changePercent', 'percent'],
  ['recent_count', 'insights.fact.recentCount', 'number'],
  ['baseline_count', 'insights.fact.baselineCount', 'number'],
  ['baseline_weekly_average', 'insights.fact.weeklyAverage', 'perWeek'],
  ['history_count', 'insights.fact.historyCount', 'number'],
  ['over_count', 'insights.fact.overCount', 'number'],
  ['count', 'insights.fact.count', 'number'],
  ['window_days', 'insights.fact.windowDays', 'days'],
  ['baseline_days', 'insights.fact.baselineDays', 'days'],
  ['months_compared', 'insights.fact.monthsCompared', 'months'],
  ['due', 'insights.fact.due', 'date'],
  ['assumption', 'insights.fact.assumptions', 'text'],
  ['assumptions', 'insights.fact.assumptions', 'text'],
  ['rule', 'insights.fact.rule', 'text'],
];

/** Keys that are not facts: the mute scope, the amounts map, the periods table and record references. */
function isHiddenKey(key: string): boolean {
  return (
    key === 'scope' ||
    key === 'amounts' ||
    key === 'periods' ||
    key.endsWith('_id') ||
    key.endsWith('_ids')
  );
}

const DECIMAL = /^[+-]?\d+(?:\.\d+)?$/;

function isCount(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0;
}

function toFactValue(type: FactType, raw: unknown, money: MoneyValue | null): FactValue | null {
  switch (type) {
    case 'money': {
      if (money) return { type: 'money', money };
      return typeof raw === 'string' && raw.trim() ? { type: 'text', text: raw } : null;
    }
    case 'text':
      return typeof raw === 'string' && raw.trim() ? { type: 'text', text: raw } : null;
    case 'number':
      return typeof raw === 'number' && Number.isFinite(raw)
        ? { type: 'number', value: raw }
        : null;
    case 'days':
      return isCount(raw) ? { type: 'days', count: raw } : null;
    case 'months':
      return isCount(raw) ? { type: 'months', count: raw } : null;
    case 'percent':
      return typeof raw === 'string' && DECIMAL.test(raw) ? { type: 'percent', value: raw } : null;
    case 'perWeek':
      if (typeof raw === 'number' && Number.isFinite(raw))
        return { type: 'perWeek', value: String(raw) };
      return typeof raw === 'string' && DECIMAL.test(raw) ? { type: 'perWeek', value: raw } : null;
    case 'date':
      return typeof raw === 'string' && isLocalDate(raw) ? { type: 'date', date: raw } : null;
  }
}

function humanize(key: string): string {
  const words = key.replace(/_/g, ' ').trim();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

/** The labelled facts behind an insight, known keys first, then any others the rule added. */
export function insightFacts(insight: Insight): InsightFact[] {
  const evidence = insight.evidence;
  const amounts = evidence.amounts;
  const facts: InsightFact[] = [];
  const known = new Set<string>();
  for (const [key, label, type] of KNOWN_FACTS) {
    known.add(key);
    if (!Object.hasOwn(evidence, key)) continue;
    const value = toFactValue(type, evidence[key], moneyFor(amounts, key, evidence[key]));
    if (!value) continue;
    const labelKey =
      key === 'count' && insight.subtype === 'subscription_costs'
        ? 'insights.fact.subscriptionCount'
        : label;
    facts.push({ key, labelKey, fallbackLabel: humanize(key), value });
  }
  for (const [key, raw] of Object.entries(evidence)) {
    if (known.has(key) || isHiddenKey(key)) continue;
    const value =
      typeof raw === 'number'
        ? toFactValue('number', raw, null)
        : toFactValue('money', raw, moneyFor(amounts, key, raw));
    if (value) facts.push({ key, labelKey: null, fallbackLabel: humanize(key), value });
  }
  return facts;
}

export interface PeriodRow {
  start: string;
  end: string;
  limit: MoneyValue | null;
  spent: MoneyValue | null;
}

/** Budget periods behind a repeated-overspend suggestion (oldest data as the rule listed it). */
export function insightPeriods(insight: Insight): PeriodRow[] {
  const raw = insight.evidence.periods;
  const list: unknown[] = Array.isArray(raw) ? raw : [];
  const rows: PeriodRow[] = [];
  for (const item of list) {
    if (typeof item !== 'object' || item === null) continue;
    const record = item as Record<string, unknown>;
    const start = record.period_start;
    const end = record.period_end;
    if (typeof start !== 'string' || typeof end !== 'string') continue;
    if (!isLocalDate(start) || !isLocalDate(end)) continue;
    rows.push({
      start,
      end,
      limit: moneyFor(record.amounts, 'limit', record.limit),
      spent: moneyFor(record.amounts, 'spent', record.spent),
    });
  }
  return rows;
}

export interface RelatedLink {
  key: string;
  to: string;
  labelKey: MessageKey;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function idOf(value: unknown): string | null {
  return typeof value === 'string' && UUID.test(value) ? value : null;
}

function idsOf(value: unknown): string[] {
  const list: unknown[] = Array.isArray(value) ? value : [];
  return list.filter((item): item is string => idOf(item) !== null);
}

/** Links to the records an insight is about (paths carry IDs and dates only). */
export function relatedLinks(insight: Insight): RelatedLink[] {
  const evidence = insight.evidence;
  const links: RelatedLink[] = [];
  const period =
    insight.period_start && insight.period_end
      ? { range: 'custom', from: insight.period_start, to: insight.period_end }
      : null;

  const transaction = idOf(evidence.transaction_id);
  if (transaction) {
    links.push({
      key: 'transaction',
      to: transactionPath(transaction),
      labelKey: 'insights.related.transaction',
    });
  }
  if (insight.subtype === 'possible_duplicate') {
    const [first, second] = idsOf(evidence.transaction_ids);
    if (first) {
      links.push({
        key: 'first',
        to: transactionPath(first),
        labelKey: 'insights.related.firstTransaction',
      });
    }
    if (second) {
      links.push({
        key: 'second',
        to: transactionPath(second),
        labelKey: 'insights.related.secondTransaction',
      });
    }
  }
  const merchant = idOf(evidence.merchant_id);
  if (merchant) {
    links.push({
      key: 'merchant',
      to: merchantPath(merchant),
      labelKey: 'insights.related.merchant',
    });
    if (period) {
      links.push({
        key: 'merchant-transactions',
        to: withQuery(paths.transactions, { merchant_id: merchant, ...period }),
        labelKey: 'insights.related.merchantTransactions',
      });
    }
  }
  const category = insight.subtype === 'category_spike' ? idOf(evidence.scope) : null;
  if (category && period) {
    links.push({
      key: 'category-transactions',
      to: withQuery(paths.transactions, { category_id: category, ...period }),
      labelKey: 'insights.related.categoryTransactions',
    });
  }
  const rule = idOf(evidence.recurring_rule_id);
  if (rule) {
    links.push({
      key: 'recurring',
      to: recurringPath(rule),
      labelKey: 'insights.related.recurring',
    });
  }
  const budget = idOf(evidence.budget_id);
  if (budget) {
    links.push({ key: 'budget', to: budgetPath(budget), labelKey: 'insights.related.budget' });
  }
  const subscription = idOf(evidence.subscription_id);
  if (subscription) {
    links.push({
      key: 'subscription',
      to: subscriptionPath(subscription),
      labelKey: 'insights.related.subscription',
    });
  }
  if (insight.subtype === 'subscription_costs') {
    links.push({
      key: 'subscriptions',
      to: paths.subscriptions,
      labelKey: 'insights.related.subscriptions',
    });
  }
  if (insight.subtype === 'cash_flow_change') {
    links.push({ key: 'analytics', to: paths.analytics, labelKey: 'insights.related.analytics' });
  }
  return links;
}

/** The mute scope the API stored on the insight (`*` covers every item). */
export function muteScopeOf(insight: Insight): string {
  const scope = insight.evidence.scope;
  return typeof scope === 'string' && scope ? scope : '*';
}

/** A mute rule's identity (subtype and scope), for keys and pending markers. */
export function muteKey({ subtype, scope }: { subtype: string; scope: string }): string {
  return JSON.stringify([subtype, scope]);
}
