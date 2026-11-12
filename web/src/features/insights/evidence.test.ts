import { describe, expect, it } from 'vitest';
import { CATEGORY_GROCERIES, TX_GROCERIES } from '@/tests/financeFixtures';
import {
  ACCOUNT_BANK,
  BUDGET_DINING,
  makeCashFlowInsight,
  makeDuplicateInsight,
  makeFrequencyInsight,
  makeInsight,
  makeOverspendInsight,
  MERCHANT_CHAI,
  TX_DUPLICATE_A,
  TX_DUPLICATE_B,
} from '@/tests/insightsFixtures';
import {
  insightFacts,
  insightPeriods,
  muteKey,
  muteScopeOf,
  parseMoneyText,
  readMoney,
  relatedLinks,
} from './evidence';

describe('insight evidence', () => {
  it('reads money only in the exact "amount CODE" form the API writes', () => {
    expect(parseMoneyText('1100.00 INR')).toEqual({ amount: '1100.00', currency: 'INR' });
    expect(parseMoneyText('-5.5 USD')).toEqual({ amount: '-5.5', currency: 'USD' });
    expect(parseMoneyText('100 JPY')).toEqual({ amount: '100', currency: 'JPY' });
    expect(parseMoneyText('1,100.00 INR')).toBeNull();
    expect(parseMoneyText('INR 100')).toBeNull();
    expect(parseMoneyText(100)).toBeNull();
  });

  it('reads Money objects, and prefers them over the older text amounts', () => {
    expect(readMoney({ amount: '12.50', amount_minor: 1250, currency: 'INR' })).toEqual({
      amount: '12.50',
      currency: 'INR',
    });
    expect(readMoney({ amount: 12.5, currency: 'INR' })).toBeNull();
    expect(readMoney({ amount: '12.50', currency: 'rupees' })).toBeNull();
    expect(readMoney('12.50 INR')).toBeNull();
    const facts = insightFacts(
      makeInsight({
        evidence: {
          amount: '1.00 INR',
          amounts: { amount: { amount: '5200.00', amount_minor: 520000, currency: 'INR' } },
          unknown_total: '2.00 INR',
        },
      }),
    );
    expect(facts.map((fact) => [fact.key, fact.value])).toEqual([
      ['amount', { type: 'money', money: { amount: '5200.00', currency: 'INR' } }],
      ['unknown_total', { type: 'money', money: { amount: '2.00', currency: 'INR' } }],
    ]);
  });

  it('lists known facts in order with their types, hiding references, amounts and the scope', () => {
    const facts = insightFacts(
      makeInsight({
        evidence: { ...makeInsight().evidence, extra_note: 'Weekend', weird: { nested: true } },
      }),
    );
    expect(facts.map((fact) => [fact.key, fact.labelKey, fact.value.type])).toEqual([
      ['amount', 'transactions.detail.amount', 'money'],
      ['baseline_median', 'insights.fact.baselineMedian', 'money'],
      ['baseline_p95', 'insights.fact.baselineP95', 'money'],
      ['history_count', 'insights.fact.historyCount', 'number'],
      ['window_days', 'insights.fact.windowDays', 'days'],
      ['rule', 'insights.fact.rule', 'text'],
      // A fact this client does not know yet is still shown, in words.
      ['extra_note', null, 'text'],
    ]);
    expect(facts.at(-1)?.fallbackLabel).toBe('Extra note');
    expect(facts[0]?.value).toEqual({
      type: 'money',
      money: { amount: '5200.00', currency: 'INR' },
    });
  });

  it('reads percentages, weekly averages and the subscription count', () => {
    const frequency = insightFacts(makeFrequencyInsight());
    expect(frequency.find((fact) => fact.key === 'baseline_weekly_average')?.value).toEqual({
      type: 'perWeek',
      value: '0.5',
    });
    const drift = insightFacts(makeInsight({ evidence: { change_percent: '+30.1', count: 3 } }));
    expect(drift.map((fact) => fact.value)).toEqual([
      { type: 'percent', value: '+30.1' },
      { type: 'number', value: 3 },
    ]);
    const subscriptions = insightFacts(
      makeInsight({ subtype: 'subscription_costs', evidence: { count: 3 } }),
    );
    expect(subscriptions[0]?.labelKey).toBe('insights.fact.subscriptionCount');
  });

  it('reads the budget periods behind a suggestion', () => {
    expect(insightPeriods(makeOverspendInsight())).toEqual([
      {
        start: '2026-10-01',
        end: '2026-10-31',
        limit: { amount: '1000.00', currency: 'INR' },
        spent: { amount: '1500.00', currency: 'INR' },
      },
      {
        start: '2026-09-01',
        end: '2026-09-30',
        limit: { amount: '1000.00', currency: 'INR' },
        spent: { amount: '1300.00', currency: 'INR' },
      },
      {
        start: '2026-08-01',
        end: '2026-08-31',
        limit: { amount: '1000.00', currency: 'INR' },
        spent: { amount: '500.00', currency: 'INR' },
      },
    ]);
    expect(
      insightPeriods(makeInsight({ evidence: { periods: [{ period_start: 'x' }, 7] } })),
    ).toEqual([]);
  });

  it('links to the records involved by ID only', () => {
    expect(relatedLinks(makeInsight()).map((link) => link.to)).toEqual([
      `/transactions/${TX_GROCERIES}`,
    ]);
    expect(relatedLinks(makeDuplicateInsight()).map((link) => [link.to, link.labelKey])).toEqual([
      [`/transactions/${TX_DUPLICATE_A}`, 'insights.related.firstTransaction'],
      [`/transactions/${TX_DUPLICATE_B}`, 'insights.related.secondTransaction'],
    ]);
    expect(relatedLinks(makeFrequencyInsight()).map((link) => link.to)).toEqual([
      `/categories/merchants/${MERCHANT_CHAI}`,
      `/transactions?merchant_id=${MERCHANT_CHAI}&range=custom&from=2026-10-29&to=2026-11-04`,
    ]);
    expect(
      relatedLinks(
        makeInsight({
          subtype: 'category_spike',
          evidence: { scope: CATEGORY_GROCERIES },
          period_start: '2026-11-01',
          period_end: '2026-11-05',
        }),
      ).map((link) => link.to),
    ).toEqual([
      `/transactions?category_id=${CATEGORY_GROCERIES}&range=custom&from=2026-11-01&to=2026-11-05`,
    ]);
    expect(relatedLinks(makeOverspendInsight()).map((link) => link.to)).toEqual([
      `/budgets/${BUDGET_DINING}`,
    ]);
    expect(relatedLinks(makeCashFlowInsight()).map((link) => link.to)).toEqual(['/analytics']);
    // Anything that is not a UUID is ignored.
    expect(
      relatedLinks(makeInsight({ evidence: { transaction_id: '../settings', budget_id: 42 } })),
    ).toEqual([]);
  });

  it('names a mute rule by subtype and scope', () => {
    expect(muteScopeOf(makeInsight())).toBe(CATEGORY_GROCERIES);
    expect(muteScopeOf(makeInsight({ evidence: {} }))).toBe('*');
    expect(muteKey({ subtype: 'unusual_amount', scope: '*' })).not.toBe(
      muteKey({ subtype: 'unusual_amount', scope: ACCOUNT_BANK }),
    );
  });
});
