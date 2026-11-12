import type { Insight, InsightFeedbackState, InsightMute, Money } from '@/features/insights/types';
import { CATEGORY_GROCERIES, TX_GROCERIES } from './financeFixtures';
import { meta } from './fixtures';

/** Rule-based insight fixtures shaped like the contract (GET /insights). */

export const INSIGHT_UNUSUAL = 'c1c1c1c1-0000-4000-8000-000000000001';
export const INSIGHT_OVERSPEND = 'c1c1c1c1-0000-4000-8000-000000000002';
export const INSIGHT_DUPLICATE = 'c1c1c1c1-0000-4000-8000-000000000003';
export const INSIGHT_FREQUENCY = 'c1c1c1c1-0000-4000-8000-000000000004';
export const INSIGHT_CASHFLOW_USD = 'c1c1c1c1-0000-4000-8000-000000000005';
export const INSIGHT_SUBSCRIPTION = 'c1c1c1c1-0000-4000-8000-000000000006';
export const BUDGET_DINING = 'c2c2c2c2-0000-4000-8000-000000000001';
export const MERCHANT_CHAI = 'c2c2c2c2-0000-4000-8000-000000000002';
export const ACCOUNT_BANK = 'c2c2c2c2-0000-4000-8000-000000000003';
export const TX_DUPLICATE_A = 'c2c2c2c2-0000-4000-8000-000000000004';
export const TX_DUPLICATE_B = 'c2c2c2c2-0000-4000-8000-000000000005';
export const SUBSCRIPTION_STREAM = 'c2c2c2c2-0000-4000-8000-000000000006';

/** A Money object as the API writes it into message_params and evidence.amounts. */
export function insightMoney(amount: string, currency = 'INR'): Money {
  const [whole = '0', fraction = ''] = amount.replace('-', '').split('.');
  const minor = Number(`${whole}${fraction.padEnd(2, '0').slice(0, 2)}`);
  return { amount, amount_minor: amount.startsWith('-') ? -minor : minor, currency };
}

/** An unusually large expense (anomaly), as the API's unusual_amount rule writes it. */
export function makeInsight(overrides: Partial<Insight> = {}): Insight {
  return {
    id: INSIGHT_UNUSUAL,
    kind: 'anomaly',
    subtype: 'unusual_amount',
    title: 'Unusually large Groceries expense',
    body:
      '5200.00 INR for FreshMart on 2026-11-03 is about 5.2× your usual Groceries transaction ' +
      '(median 1000.00 INR over 12 transactions in the previous 6 months). If it is expected, mark it so.',
    severity: 'notice',
    confidence: 0.6,
    evidence: {
      transaction_id: TX_GROCERIES,
      amount: '5200.00 INR',
      baseline_median: '1000.00 INR',
      baseline_p95: '2400.00 INR',
      amounts: {
        amount: insightMoney('5200.00'),
        baseline_median: insightMoney('1000.00'),
        baseline_p95: insightMoney('2400.00'),
      },
      history_count: 12,
      window_days: 180,
      rule: 'amount ≥ 3× median and above the 95th percentile',
      scope: CATEGORY_GROCERIES,
    },
    message_code: 'unusual_amount',
    message_params: {
      transaction_id: TX_GROCERIES,
      label: 'FreshMart',
      category_id: CATEGORY_GROCERIES,
      category_name: 'Groceries',
      local_date: '2026-11-03',
      amount: insightMoney('5200.00'),
      baseline_median: insightMoney('1000.00'),
      ratio: '5.2',
      history_count: 12,
      window_months: 6,
    },
    rule_code: 'amount_3x_median_above_p95',
    period_start: '2026-11-03',
    period_end: '2026-11-03',
    source: 'rules',
    status: 'active',
    created_at: '2026-11-04T03:30:00Z',
    ...overrides,
  };
}

/** A repeated budget overspend suggestion (savings) with its periods. */
export function makeOverspendInsight(overrides: Partial<Insight> = {}): Insight {
  return makeInsight({
    id: INSIGHT_OVERSPEND,
    kind: 'savings',
    subtype: 'repeated_budget_overspend',
    title: 'Dining out budget exceeded in 2 of the last 3 periods',
    body:
      'Across the last 3 periods you spent 1100.00 INR on average against a limit of 1000.00 INR. ' +
      'Based on past periods only.',
    severity: 'info',
    confidence: 0.7,
    evidence: {
      budget_id: BUDGET_DINING,
      periods: [
        {
          period_start: '2026-10-01',
          period_end: '2026-10-31',
          limit: '1000.00 INR',
          spent: '1500.00 INR',
          amounts: { limit: insightMoney('1000.00'), spent: insightMoney('1500.00') },
        },
        {
          period_start: '2026-09-01',
          period_end: '2026-09-30',
          limit: '1000.00 INR',
          spent: '1300.00 INR',
          amounts: { limit: insightMoney('1000.00'), spent: insightMoney('1300.00') },
        },
        {
          period_start: '2026-08-01',
          period_end: '2026-08-31',
          limit: '1000.00 INR',
          spent: '500.00 INR',
          amounts: { limit: insightMoney('1000.00'), spent: insightMoney('500.00') },
        },
      ],
      over_count: 2,
      average_spent: '1100.00 INR',
      average_overspend: '400.00 INR',
      amounts: {
        average_spent: insightMoney('1100.00'),
        average_overspend: insightMoney('400.00'),
      },
      assumption: 'Past periods only; future spending may differ.',
      rule: 'spent above the limit in at least 2 of the last 3 closed periods',
      scope: BUDGET_DINING,
    },
    message_code: 'repeated_budget_overspend',
    message_params: {
      budget_id: BUDGET_DINING,
      budget_name: 'Dining out',
      periods: 3,
      over_count: 2,
      average_spent: insightMoney('1100.00'),
      limit: insightMoney('1000.00'),
      average_overspend: insightMoney('400.00'),
    },
    rule_code: 'over_limit_2_of_last_3_periods',
    period_start: '2026-08-01',
    period_end: '2026-10-31',
    ...overrides,
  });
}

/** Two look-alike transactions in one account. */
export function makeDuplicateInsight(overrides: Partial<Insight> = {}): Insight {
  return makeInsight({
    id: INSIGHT_DUPLICATE,
    subtype: 'possible_duplicate',
    title: 'Possible duplicate: Uber',
    body: 'Two transactions of 349.00 INR for Uber on 2026-11-02 and 2026-11-02 in the same account look alike.',
    confidence: 0.7,
    evidence: {
      transaction_ids: [TX_DUPLICATE_A, TX_DUPLICATE_B],
      amount: '349.00 INR',
      amounts: { amount: insightMoney('349.00') },
      rule: 'same account and amount within 2 days, same merchant or description',
      scope: ACCOUNT_BANK,
    },
    message_code: 'possible_duplicate',
    message_params: {
      label: 'Uber',
      amount: insightMoney('349.00'),
      first_date: '2026-11-02',
      second_date: '2026-11-02',
      transaction_ids: [TX_DUPLICATE_A, TX_DUPLICATE_B],
      account_id: ACCOUNT_BANK,
    },
    rule_code: 'same_account_amount_within_2_days',
    period_start: '2026-11-02',
    period_end: '2026-11-02',
    ...overrides,
  });
}

/** A burst of purchases at one merchant. */
export function makeFrequencyInsight(overrides: Partial<Insight> = {}): Insight {
  return makeInsight({
    id: INSIGHT_FREQUENCY,
    subtype: 'unusual_frequency',
    title: 'More purchases than usual at Chai Point',
    body: 'You made 4 purchases at Chai Point in the last 7 days, compared with about 0.5 a week.',
    confidence: 0.6,
    evidence: {
      merchant_id: MERCHANT_CHAI,
      recent_count: 4,
      baseline_count: 6,
      baseline_weekly_average: '0.5',
      window_days: 7,
      baseline_days: 84,
      transaction_ids: [TX_DUPLICATE_A],
      rule: '≥ 4 purchases in 7 days and ≥ 3× the weekly average of the previous 12 weeks',
      scope: MERCHANT_CHAI,
    },
    message_code: 'unusual_frequency',
    message_params: {
      merchant_id: MERCHANT_CHAI,
      merchant_name: 'Chai Point',
      recent_count: 4,
      baseline_weekly_average: '0.5',
      window_days: 7,
      baseline_weeks: 12,
    },
    rule_code: '4_in_7_days_and_3x_weekly_average',
    period_start: '2026-10-29',
    period_end: '2026-11-04',
    ...overrides,
  });
}

/** Last month's cash flow in another currency (scope `*`). */
export function makeCashFlowInsight(overrides: Partial<Insight> = {}): Insight {
  return makeInsight({
    id: INSIGHT_CASHFLOW_USD,
    kind: 'summary',
    subtype: 'cash_flow_change',
    title: 'Last month’s cash flow changed',
    body: 'In October 2026, spending was 1250.00 USD against your usual 900.00 USD.',
    severity: 'info',
    confidence: 0.8,
    evidence: {
      spending: '1250.00 USD',
      usual_spending: '900.00 USD',
      income: '3000.00 USD',
      usual_income: '3000.00 USD',
      amounts: {
        spending: insightMoney('1250.00', 'USD'),
        usual_spending: insightMoney('900.00', 'USD'),
        income: insightMoney('3000.00', 'USD'),
        usual_income: insightMoney('3000.00', 'USD'),
      },
      rule: 'spending +25% or income -20% vs the previous 3-month average',
      scope: '*',
    },
    message_code: 'cash_flow_change_spending',
    message_params: {
      month: '2026-10',
      spending: insightMoney('1250.00', 'USD'),
      usual_spending: insightMoney('900.00', 'USD'),
      income: insightMoney('3000.00', 'USD'),
      usual_income: insightMoney('3000.00', 'USD'),
      months_compared: 3,
    },
    rule_code: 'spending_up_25_or_income_down_20_vs_3_months',
    period_start: '2026-10-01',
    period_end: '2026-10-31',
    ...overrides,
  });
}

/** A subscription price rise (one of the kinds whose scope is the subscription). */
export function makePriceInsight(overrides: Partial<Insight> = {}): Insight {
  return makeInsight({
    id: INSIGHT_SUBSCRIPTION,
    kind: 'subscription',
    subtype: 'subscription_price_increase',
    title: 'StreamBox costs more',
    body: 'StreamBox went from 499.00 INR to 649.00 INR per monthly billing (30.06% more) on 2026-11-01.',
    confidence: 1,
    evidence: {
      subscription_id: SUBSCRIPTION_STREAM,
      old: '499.00 INR',
      new: '649.00 INR',
      amounts: { old: insightMoney('499.00'), new: insightMoney('649.00') },
      rule: 'recorded price change',
      scope: SUBSCRIPTION_STREAM,
    },
    message_code: 'subscription_price_increase',
    message_params: {
      subscription_id: SUBSCRIPTION_STREAM,
      name: 'StreamBox',
      old: insightMoney('499.00'),
      new: insightMoney('649.00'),
      billing_frequency: 'monthly',
      percent: '30.06',
      percent_bp: 3006,
      local_date: '2026-11-01',
    },
    rule_code: 'recorded_price_change',
    period_start: '2026-11-01',
    period_end: '2026-11-01',
    ...overrides,
  });
}

/** An insight recorded before message codes existed: English text only. */
export function makeLegacyInsight(overrides: Partial<Insight> = {}): Insight {
  const insight = makeInsight({
    id: 'c1c1c1c1-0000-4000-8000-000000000099',
    title: 'Unusually large Fuel expense',
    body: 'An older insight with English text only.',
    ...overrides,
  });
  delete insight.message_code;
  delete insight.message_params;
  return insight;
}

export function makeFeedback(overrides: Partial<InsightFeedbackState> = {}): InsightFeedbackState {
  return { feedback: 'helpful', updated_at: '2026-11-04T08:00:00Z', ...overrides };
}

/** A mute rule as GET /insights/mutes lists it. */
export function makeInsightMute(overrides: Partial<InsightMute> = {}): InsightMute {
  return {
    subtype: 'unusual_amount',
    scope: CATEGORY_GROCERIES,
    created_at: '2026-11-03T09:00:00Z',
    ...overrides,
  };
}

/** A GET /insights page envelope with cursor metadata like the API's. */
export function insightPage(items: Insight[], nextCursor?: string) {
  return {
    data: items,
    meta: {
      ...meta(),
      has_more: Boolean(nextCursor),
      ...(nextCursor ? { next_cursor: nextCursor } : {}),
    },
  };
}
