import { describe, expect, it } from 'vitest';
import type { Bill, BillInput, RecurringRule, RecurringRuleInput } from '@/shared/finance/types';
import { ACCOUNT_CARD, ACCOUNT_CASH, CATEGORY_GROCERIES, money } from '@/tests/financeFixtures';
import { makeBill, makeBillSchedule, makeRule } from '@/tests/planningFixtures';
import { billPatchFrom, isEmptyPatch, rulePatchFrom, scheduleChanges } from './patches';
import { type ScheduleInput, scheduleFromRule, toScheduleInput } from './schedule';

/** What the bill form sends for a bill nobody changed. */
function billAsInput(bill: Bill): BillInput {
  return {
    name: bill.name,
    ...toScheduleInput(scheduleFromRule(bill.schedule), bill.schedule.timezone),
    amount_is_variable: bill.amount_is_variable,
    currency: bill.currency,
    ...(bill.expected_amount ? { expected_amount: bill.expected_amount.amount } : {}),
    ...(bill.provider_name ? { provider_name: bill.provider_name } : {}),
    ...(bill.payment_account_id ? { payment_account_id: bill.payment_account_id } : {}),
    ...(bill.category_id ? { category_id: bill.category_id } : {}),
    ...(bill.notes ? { notes: bill.notes } : {}),
  };
}

/** What the rule form sends for a rule nobody changed (expense or income). */
function ruleAsInput(rule: RecurringRule): RecurringRuleInput {
  return {
    kind: 'expense',
    name: rule.name,
    ...toScheduleInput(scheduleFromRule(rule), rule.timezone),
    amount_is_variable: rule.amount_is_variable,
    auto_post: rule.auto_post,
    ...(rule.amount ? { amount: rule.amount.amount } : {}),
    ...(rule.account_id ? { account_id: rule.account_id } : {}),
    ...(rule.category_id ? { category_id: rule.category_id } : {}),
    ...(rule.merchant ? { merchant_name: rule.merchant.name } : {}),
    ...(rule.description ? { description: rule.description } : {}),
    ...(rule.notes ? { notes: rule.notes } : {}),
  };
}

/** A field is never both sent and cleared (the API answers 422). */
function expectNoSendAndClear(patch: Record<string, unknown> & { clear?: readonly string[] }) {
  for (const field of patch.clear ?? []) expect(patch).not.toHaveProperty(field);
}

describe('billPatchFrom', () => {
  it('sends only the version when nothing changed', () => {
    const bill = makeBill();
    const patch = billPatchFrom(bill, billAsInput(bill));
    expect(patch).toEqual({ version: 4 });
    expect(isEmptyPatch(patch)).toBe(true);
  });

  it('sends only the fields that changed', () => {
    const bill = makeBill();
    const patch = billPatchFrom(bill, { ...billAsInput(bill), name: 'Power', local_time: '18:00' });
    expect(patch).toEqual({ version: 4, name: 'Power', local_time: '18:00' });
    expect(isEmptyPatch(patch)).toBe(false);
  });

  it('clears emptied references and sends emptied text as ""', () => {
    const bill = makeBill({ category_id: CATEGORY_GROCERIES, notes: 'Pay by the 5th' });
    const desired = billAsInput(bill);
    delete desired.payment_account_id;
    delete desired.category_id;
    delete desired.provider_name;
    delete desired.notes;
    const patch = billPatchFrom(bill, desired);
    expect(patch).toEqual({
      version: 4,
      provider_name: '',
      notes: '',
      clear: ['payment_account_id', 'category_id'],
    });
    expectNoSendAndClear(patch);
  });

  it('makes the bill variable by removing the expected amount', () => {
    const bill = makeBill();
    const desired = { ...billAsInput(bill), amount_is_variable: true };
    delete desired.expected_amount;
    expect(billPatchFrom(bill, desired)).toEqual({
      version: 4,
      amount_is_variable: true,
      expected_amount: '',
    });
  });

  it('sends the currency with an account in another currency', () => {
    const bill = makeBill();
    const patch = billPatchFrom(bill, {
      ...billAsInput(bill),
      payment_account_id: ACCOUNT_CARD,
      currency: 'USD',
      expected_amount: '15.00',
    });
    expect(patch).toEqual({
      version: 4,
      payment_account_id: ACCOUNT_CARD,
      currency: 'USD',
      expected_amount: '15.00',
    });
  });

  it('keeps fields the form does not show (the document)', () => {
    const bill = makeBill({ document_file_id: 'f0000000-0000-4000-8000-000000000001' });
    expect(billPatchFrom(bill, billAsInput(bill))).toEqual({ version: 4 });
  });
});

describe('scheduleChanges', () => {
  // Monthly on day 5, one reminder the day before.
  const schedule = makeBillSchedule();
  const same = (): ScheduleInput => toScheduleInput(scheduleFromRule(schedule), schedule.timezone);

  it('switches the day of the month to the nth weekday, clearing the day', () => {
    const changes = scheduleChanges(schedule, {
      ...same(),
      by_month_day: undefined,
      by_weekday: 2,
      by_week_of_month: 2,
    });
    expect(changes).toEqual({
      fields: { by_weekday: 2, by_week_of_month: 2 },
      clear: ['by_month_day'],
    });
  });

  it('sends the anchors of a new frequency and clears the ones it does not use', () => {
    const weekly: ScheduleInput = {
      ...same(),
      frequency: 'weekly',
      by_month_day: undefined,
      by_weekday: 1,
    };
    expect(scheduleChanges(schedule, weekly)).toEqual({
      fields: { frequency: 'weekly', by_weekday: 1 },
      clear: ['by_month_day'],
    });
    const custom: ScheduleInput = {
      ...same(),
      frequency: 'custom',
      interval_count: 2,
      interval_unit: 'month',
    };
    // The day stays the same but is sent again: the API resets anchors on a new frequency.
    expect(scheduleChanges(schedule, custom)).toEqual({
      fields: { frequency: 'custom', interval_count: 2, interval_unit: 'month', by_month_day: 5 },
      clear: [],
    });
  });

  it('sends the anchors again when only the interval changes', () => {
    const everyTwoWeeks = makeRule({
      frequency: 'custom',
      interval_count: 2,
      interval_unit: 'week',
      by_month_day: undefined,
      by_weekday: 1,
    });
    const desired = {
      ...toScheduleInput(scheduleFromRule(everyTwoWeeks), everyTwoWeeks.timezone),
      interval_count: 3,
    };
    expect(scheduleChanges(everyTwoWeeks, desired)).toEqual({
      fields: { interval_count: 3, by_weekday: 1 },
      clear: [],
    });
  });

  it('changes how the schedule ends', () => {
    const withEnd = makeBillSchedule({ end_date: '2027-03-31' });
    const endless = toScheduleInput(
      { ...scheduleFromRule(withEnd), endMode: 'never' },
      withEnd.timezone,
    );
    expect(scheduleChanges(withEnd, endless)).toEqual({ fields: { end_date: '' }, clear: [] });

    const counted = toScheduleInput(
      { ...scheduleFromRule(withEnd), endMode: 'count', maxOccurrences: '12' },
      withEnd.timezone,
    );
    expect(scheduleChanges(withEnd, counted)).toEqual({
      fields: { end_date: '', max_occurrences: 12 },
      clear: [],
    });

    const limited = makeBillSchedule({ max_occurrences: 12 });
    expect(scheduleChanges(limited, endless)).toEqual({
      fields: {},
      clear: ['max_occurrences'],
    });
  });

  it('replaces the reminder list ([] turns reminders off)', () => {
    expect(scheduleChanges(schedule, { ...same(), reminder_days_before: [] })).toEqual({
      fields: { reminder_days_before: [] },
      clear: [],
    });
    expect(scheduleChanges(schedule, { ...same(), reminder_days_before: [3, 0, 3] })).toEqual({
      fields: { reminder_days_before: [0, 3] },
      clear: [],
    });
  });
});

describe('rulePatchFrom', () => {
  const rule = makeRule({
    merchant: { id: '99999999-9999-4999-8999-999999999902', name: 'Landlord' },
    description: 'Flat 4B',
  });

  it('sends only the version when nothing changed', () => {
    expect(rulePatchFrom(rule, ruleAsInput(rule), 'INR')).toEqual({ version: 3 });
  });

  it('clears an emptied account and category, and empties text with ""', () => {
    const desired = ruleAsInput(rule);
    delete desired.account_id;
    delete desired.category_id;
    delete desired.merchant_name;
    delete desired.description;
    const patch = rulePatchFrom(rule, desired, 'INR');
    expect(patch).toEqual({
      version: 3,
      merchant_name: '',
      description: '',
      clear: ['account_id', 'category_id'],
    });
    expectNoSendAndClear(patch);
  });

  it('makes the amount variable and records automatically only when asked', () => {
    const desired = { ...ruleAsInput(rule), amount_is_variable: true };
    delete desired.amount;
    expect(rulePatchFrom(rule, desired, 'INR')).toEqual({
      version: 3,
      amount_is_variable: true,
      amount: '',
    });
    expect(
      rulePatchFrom(rule, { ...ruleAsInput(rule), auto_post: true, amount: '15500.00' }, 'INR'),
    ).toEqual({ version: 3, auto_post: true, amount: '15500.00' });
  });

  it('sends a new currency and a moved schedule', () => {
    const noAccount = makeRule({ account_id: undefined, currency: 'INR' });
    const desired = {
      ...ruleAsInput(noAccount),
      currency: 'USD',
      amount: '150.00',
      start_date: '2026-12-01',
    };
    expect(rulePatchFrom(noAccount, desired, 'USD')).toEqual({
      version: 3,
      currency: 'USD',
      amount: '150.00',
      start_date: '2026-12-01',
    });
  });

  it('treats the transfer destination like the other references', () => {
    const transfer = makeRule({
      kind: 'transfer',
      account_id: ACCOUNT_CASH,
      to_account_id: ACCOUNT_CARD,
      category_id: undefined,
      amount: money('5000.00'),
    });
    const desired: RecurringRuleInput = { ...ruleAsInput(transfer), kind: 'transfer' };
    expect(rulePatchFrom(transfer, { ...desired, to_account_id: ACCOUNT_CARD }, 'INR')).toEqual({
      version: 3,
    });
  });
});
