import { describe, expect, it } from 'vitest';
import { ACCOUNT_CASH, CATEGORY_GROCERIES } from '@/tests/financeFixtures';
import { makeSubscription } from '@/tests/subscriptionsFixtures';
import { subscriptionToValues, toSubscriptionInput, toSubscriptionPatch } from './formValues';

const GROUP = 'abababab-0000-4000-8000-000000000001';

function saved() {
  return makeSubscription({
    category_id: CATEGORY_GROCERIES,
    group_id: GROUP,
    notes: 'Family plan',
    trial_ends_on: '2026-10-20',
    invoice_file_id: '0f0f0f0f-0000-4000-8000-000000000001',
  });
}

describe('toSubscriptionPatch', () => {
  it('sends only the version when nothing changed', () => {
    const subscription = saved();
    const values = subscriptionToValues(subscription, 'en-IN');
    expect(toSubscriptionPatch(values, '649.00', subscription)).toEqual({ version: 2 });
  });

  it('treats the same price written differently and reordered reminders as unchanged', () => {
    const subscription = saved();
    const values = { ...subscriptionToValues(subscription, 'en-IN'), reminders: ['1', '3'] };
    expect(toSubscriptionPatch(values, '649.0', subscription)).toEqual({ version: 2 });
  });

  it('clears emptied text with "" and removed links through clear, never both', () => {
    const subscription = saved();
    const values = {
      ...subscriptionToValues(subscription, 'en-IN'),
      planName: '',
      notes: '  ',
      merchantName: '',
      categoryId: '',
      groupId: '',
      paymentAccountId: '',
      trialEndsOn: '',
      cancellationUrl: '',
    };
    const patch = toSubscriptionPatch(values, '649.00', subscription);
    expect(patch).toEqual({
      version: 2,
      plan_name: '',
      merchant_name: '',
      notes: '',
      trial_ends_on: '',
      cancellation_url: '',
      clear: ['payment_account_id', 'category_id', 'group_id'],
    });
    for (const field of patch.clear ?? []) expect(patch).not.toHaveProperty(field);
    // The invoice is not edited here, so it is never sent (the API keeps it).
    expect(patch).not.toHaveProperty('invoice_file_id');
  });

  it('sends changed links as values', () => {
    const subscription = makeSubscription({ payment_account_id: undefined });
    const values = {
      ...subscriptionToValues(subscription, 'en-IN'),
      paymentAccountId: ACCOUNT_CASH,
      categoryId: CATEGORY_GROCERIES,
    };
    expect(toSubscriptionPatch(values, '649.00', subscription)).toEqual({
      version: 2,
      payment_account_id: ACCOUNT_CASH,
      category_id: CATEGORY_GROCERIES,
    });
  });

  it('sends the price with a new currency, and the interval when switching to custom', () => {
    const subscription = saved();
    const values = {
      ...subscriptionToValues(subscription, 'en-IN'),
      currency: 'USD',
      billingFrequency: 'custom',
      intervalCount: '3',
      intervalUnit: 'month',
    };
    expect(toSubscriptionPatch(values, '8.00', subscription)).toEqual({
      version: 2,
      currency: 'USD',
      amount: '8.00',
      billing_frequency: 'custom',
      interval_count: 3,
      interval_unit: 'month',
    });
  });

  it('sends only the changed part of a custom interval', () => {
    const subscription = makeSubscription({
      billing_frequency: 'custom',
      interval_count: 3,
      interval_unit: 'month',
    });
    const values = { ...subscriptionToValues(subscription, 'en-IN'), intervalCount: '4' };
    expect(toSubscriptionPatch(values, '649.00', subscription)).toEqual({
      version: 2,
      interval_count: 4,
    });
  });

  it('asks the API to recompute an emptied next renewal date', () => {
    const subscription = saved();
    const values = { ...subscriptionToValues(subscription, 'en-IN'), nextRenewalDate: '' };
    expect(toSubscriptionPatch(values, '649.00', subscription)).toEqual({
      version: 2,
      next_renewal_date: '',
    });
  });

  it('replaces the reminders and the checklist as whole lists', () => {
    const subscription = saved();
    const values = {
      ...subscriptionToValues(subscription, 'en-IN'),
      reminders: [],
      checklist: [
        { item: 'Download invoices', done: true },
        { item: '  ', done: false },
        { item: 'Remove the card', done: false },
      ],
    };
    expect(toSubscriptionPatch(values, '649.00', subscription)).toEqual({
      version: 2,
      reminder_days_before: [],
      cancellation_checklist: [
        { item: 'Download invoices', done: true },
        { item: 'Remove the card', done: false },
      ],
    });
  });

  it('corrects the cancellation date only for a cancelled subscription', () => {
    const cancelled = makeSubscription({ status: 'cancelled', cancelled_on: '2026-11-01' });
    const values = { ...subscriptionToValues(cancelled, 'en-IN'), cancelledOn: '2026-10-30' };
    expect(toSubscriptionPatch(values, '649.00', cancelled)).toEqual({
      version: 2,
      cancelled_on: '2026-10-30',
    });
    const active = makeSubscription();
    expect(
      toSubscriptionPatch(
        { ...subscriptionToValues(active, 'en-IN'), cancelledOn: '2026-10-30' },
        '649.00',
        active,
      ),
    ).toEqual({ version: 2 });
  });
});

describe('toSubscriptionInput', () => {
  it('builds a new subscription without a version or empty optional fields', () => {
    const values = {
      ...subscriptionToValues(makeSubscription(), 'en-IN'),
      planName: '',
      nextRenewalDate: '',
    };
    const input = toSubscriptionInput(values, '649.00');
    expect(input).not.toHaveProperty('version');
    expect(input).not.toHaveProperty('plan_name');
    expect(input).not.toHaveProperty('next_renewal_date');
    expect(input).toMatchObject({
      name: 'Netflix',
      amount: '649.00',
      reminder_days_before: [3, 1],
    });
  });
});
