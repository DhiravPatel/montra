import type {
  BillDetail,
  BillPaymentCandidate,
  CalendarItem,
  Occurrence,
  RecurringReport,
  RecurringRule,
  RecurringRuleDetail,
} from '@/shared/finance/types';
import { ACCOUNT_CASH, CATEGORY_GROCERIES, money } from './financeFixtures';

/** Planning fixtures (bills, recurring items, calendar) shaped like the contract (tests only). */

export const BILL_ID = 'b1111111-1111-4111-8111-111111111111';
export const BILL_RULE_ID = 'b2222222-2222-4222-8222-222222222222';
export const RULE_ID = 'c1111111-1111-4111-8111-111111111111';
export const OCC_DUE = 'd1111111-1111-4111-8111-111111111111';
export const OCC_NEXT = 'd2222222-2222-4222-8222-222222222222';
export const OCC_PAID = 'd3333333-3333-4333-8333-333333333333';
export const OCC_RULE = 'd4444444-4444-4444-8444-444444444444';
export const OCC_RULE_SKIPPED = 'd5555555-5555-4555-8555-555555555555';
export const TX_BILL_PAYMENT = '77777777-7777-4777-8777-777777777799';
export const MERCHANT_BESCOM = '99999999-9999-4999-8999-999999999903';

export function makeOccurrence(overrides: Partial<Occurrence> = {}): Occurrence {
  return {
    id: OCC_DUE,
    rule_id: BILL_RULE_ID,
    rule_name: 'Electricity',
    kind: 'bill',
    occurrence_date: '2026-11-05',
    effective_date: '2026-11-05',
    due_at: '2026-11-05T03:30:00Z',
    status: 'scheduled',
    amount: money('1200.00'),
    bill_id: BILL_ID,
    ...overrides,
  };
}

export function makeRule(overrides: Partial<RecurringRule> = {}): RecurringRule {
  return {
    id: RULE_ID,
    kind: 'expense',
    name: 'Rent',
    frequency: 'monthly',
    interval_count: 1,
    by_month_day: -1,
    start_date: '2026-11-01',
    timezone: 'Asia/Kolkata',
    local_time: '09:00',
    amount: money('15000.00'),
    currency: 'INR',
    amount_is_variable: false,
    account_id: ACCOUNT_CASH,
    category_id: CATEGORY_GROCERIES,
    auto_post: false,
    reminder_days_before: [1],
    status: 'active',
    next_occurrence: '2026-11-30',
    completed_count: 2,
    owned: true,
    version: 3,
    created_at: '2026-11-01T08:00:00Z',
    ...overrides,
  };
}

export function makeRuleDetail(overrides: Partial<RecurringRuleDetail> = {}): RecurringRuleDetail {
  return {
    ...makeRule(),
    occurrences: [
      makeOccurrence({
        id: OCC_RULE,
        rule_id: RULE_ID,
        rule_name: 'Rent',
        kind: 'expense',
        occurrence_date: '2026-11-30',
        effective_date: '2026-11-30',
        due_at: '2026-11-30T03:30:00Z',
        amount: money('15000.00'),
        bill_id: undefined,
      }),
      makeOccurrence({
        id: OCC_RULE_SKIPPED,
        rule_id: RULE_ID,
        rule_name: 'Rent',
        kind: 'expense',
        occurrence_date: '2026-10-31',
        effective_date: '2026-10-31',
        due_at: '2026-10-31T03:30:00Z',
        status: 'skipped',
        amount: money('15000.00'),
        bill_id: undefined,
      }),
    ],
    ...overrides,
  };
}

export function makeBillSchedule(overrides: Partial<RecurringRule> = {}): RecurringRule {
  return makeRule({
    id: BILL_RULE_ID,
    kind: 'bill',
    name: 'Electricity',
    by_month_day: 5,
    start_date: '2026-10-01',
    amount: money('1200.00'),
    category_id: undefined,
    next_occurrence: '2026-11-05',
    completed_count: 1,
    version: 1,
    bill_id: BILL_ID,
    merchant: { id: MERCHANT_BESCOM, name: 'BESCOM' },
    ...overrides,
  });
}

export function makeBill(overrides: Partial<BillDetail> = {}): BillDetail {
  return {
    id: BILL_ID,
    name: 'Electricity',
    provider_name: 'BESCOM',
    expected_amount: money('1200.00'),
    amount_is_variable: false,
    currency: 'INR',
    payment_account_id: ACCOUNT_CASH,
    status: 'active',
    state: 'due_today',
    next_due: makeOccurrence(),
    last_paid: makeOccurrence({
      id: OCC_PAID,
      occurrence_date: '2026-10-05',
      effective_date: '2026-10-05',
      due_at: '2026-10-05T03:30:00Z',
      status: 'paid',
      transaction_id: TX_BILL_PAYMENT,
    }),
    schedule: makeBillSchedule(),
    owned: true,
    version: 4,
    created_at: '2026-10-01T08:00:00Z',
    occurrences: [
      makeOccurrence({
        id: OCC_NEXT,
        occurrence_date: '2026-12-05',
        effective_date: '2026-12-05',
        due_at: '2026-12-05T03:30:00Z',
      }),
      makeOccurrence(),
      makeOccurrence({
        id: OCC_PAID,
        occurrence_date: '2026-10-05',
        effective_date: '2026-10-05',
        due_at: '2026-10-05T03:30:00Z',
        status: 'paid',
        transaction_id: TX_BILL_PAYMENT,
      }),
    ],
    ...overrides,
  };
}

export function makeCandidate(overrides: Partial<BillPaymentCandidate> = {}): BillPaymentCandidate {
  return {
    transaction_id: TX_BILL_PAYMENT,
    local_date: '2026-11-04',
    amount: money('1200.00'),
    account_name: 'Wallet',
    merchant: 'BESCOM',
    description: 'Electricity bill',
    reason_codes: ['same_provider', 'same_amount', 'near_due_date'],
    reasons: ['Same provider', 'Same amount as expected', 'Within 10 days of the due date'],
    days_from_due: -1,
    ...overrides,
  };
}

export function makeCalendarItem(overrides: Partial<CalendarItem> = {}): CalendarItem {
  return {
    date: '2026-11-05',
    kind: 'bill',
    title: 'Electricity',
    amount: money('1200.00'),
    status: 'scheduled',
    entity_type: 'bill',
    entity_id: BILL_ID,
    occurrence_id: OCC_DUE,
    ...overrides,
  };
}

export function makeRecurringReport(overrides: Partial<RecurringReport> = {}): RecurringReport {
  return {
    commitments: [
      {
        kind: 'bill',
        currency: 'INR',
        monthly_equivalent: money('1200.00'),
        next_30_days: money('2400.00'),
        rule_count: 1,
        variable_count: 0,
      },
      {
        kind: 'income',
        currency: 'INR',
        monthly_equivalent: money('1083.33'),
        next_30_days: money('1000.00'),
        rule_count: 2,
        variable_count: 1,
      },
    ],
    note: 'Monthly equivalents use fixed rule amounts only; bills and income are expectations, not recorded money.',
    note_code: 'fixed_amounts_expectations',
    ...overrides,
  };
}
