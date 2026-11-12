import type {
  DetectionCandidate,
  SubscriptionDetail,
  SubscriptionDuplicateWarning,
  SubscriptionEvent,
  SubscriptionPaymentCandidate,
  SubscriptionSummary,
} from '@/shared/finance/types';
import { ACCOUNT_CASH, money } from './financeFixtures';

/** Subscription fixtures shaped like the contract (tests only). */

export const SUB_NETFLIX = 'a1a1a1a1-1111-4111-8111-000000000001';
export const SUB_NETFLIX_FAMILY = 'a1a1a1a1-1111-4111-8111-000000000002';
export const SUB_GYM = 'a1a1a1a1-1111-4111-8111-000000000003';
export const MERCHANT_NETFLIX = 'b2b2b2b2-2222-4222-8222-000000000001';
export const DETECTION_SPOTIFY = 'c3c3c3c3-3333-4333-8333-000000000001';
export const MERCHANT_SPOTIFY = 'b2b2b2b2-2222-4222-8222-000000000002';
export const TX_NETFLIX_CHARGE = 'd4d4d4d4-4444-4444-8444-000000000001';
export const TX_NETFLIX_OLD = 'd4d4d4d4-4444-4444-8444-000000000002';

export function makeSubscriptionEvent(
  overrides: Partial<SubscriptionEvent> = {},
): SubscriptionEvent {
  return {
    id: 'e5e5e5e5-5555-4555-8555-000000000001',
    kind: 'created',
    new_amount: money('649.00'),
    occurred_on: '2026-10-10',
    created_at: '2026-10-10T06:00:00Z',
    ...overrides,
  };
}

export function makeSubscription(overrides: Partial<SubscriptionDetail> = {}): SubscriptionDetail {
  return {
    id: SUB_NETFLIX,
    name: 'Netflix',
    plan_name: 'Standard',
    merchant: { id: MERCHANT_NETFLIX, name: 'Netflix' },
    amount: money('649.00'),
    billing_frequency: 'monthly',
    interval_count: 1,
    start_date: '2026-10-10',
    next_renewal_date: '2026-11-10',
    payment_account_id: ACCOUNT_CASH,
    status: 'active',
    source: 'manual',
    cancellation_url: 'https://www.netflix.com/cancelplan',
    cancellation_checklist: [{ item: 'Download invoices', done: false }],
    reminder_days_before: [3, 1],
    monthly_cost: money('649.00'),
    annual_cost: money('7788.00'),
    duplicate_warnings: [],
    payments: [],
    owned: true,
    version: 2,
    created_at: '2026-10-10T06:00:00Z',
    events: [makeSubscriptionEvent()],
    ...overrides,
  };
}

export function makeSubscriptionSummary(
  overrides: Partial<SubscriptionSummary> = {},
): SubscriptionSummary {
  return {
    totals: [
      {
        currency: 'INR',
        monthly: money('1448.00'),
        annual: money('17376.00'),
        count: 2,
      },
    ],
    upcoming_renewals: [makeSubscription()],
    trials_ending_soon: [],
    pending_detections: 1,
    ...overrides,
  };
}

export function makeDetection(overrides: Partial<DetectionCandidate> = {}): DetectionCandidate {
  return {
    id: DETECTION_SPOTIFY,
    merchant_id: MERCHANT_SPOTIFY,
    merchant_label: 'Spotify',
    amount: money('199.00'),
    amount_tolerance: money('9.95'),
    cadence: 'monthly',
    // Still required by the contract type; the screens read confidence_bp only.
    // eslint-disable-next-line @typescript-eslint/no-deprecated -- deprecated field the API still sends
    confidence: '0.966',
    confidence_bp: 9660,
    evidence_transaction_ids: ['f6f6f6f6-6666-4666-8666-000000000001'],
    evidence: {
      reasons: [
        '5 charges, typically every 30 days (monthly)',
        '4 of 4 intervals fit the cadence',
        '5 of 5 amounts are within 5% of the typical amount',
      ],
      reason_codes: ['charge_cadence', 'intervals_fit_cadence', 'amounts_within_tolerance'],
      intervals_days: [30, 31, 31, 30],
      intervals_in_cycle: 4,
      median_interval_days: 30,
      amounts_minor: [19900, 19900, 19900, 19900, 19900],
      amounts_within_tolerance: 5,
      amount_tolerance_bp: 500,
      last_charge_date: '2026-10-12',
      charge_count: 5,
    },
    next_expected_date: '2026-11-12',
    status: 'pending',
    created_at: '2026-11-05T06:00:00Z',
    ...overrides,
  };
}

export function makeDuplicateWarning(
  overrides: Partial<SubscriptionDuplicateWarning> = {},
): SubscriptionDuplicateWarning {
  return {
    subscription_id: SUB_NETFLIX_FAMILY,
    name: 'Netflix family',
    reason: 'Same name',
    reason_code: 'same_name',
    reason_params: { name: 'Netflix family' },
    ...overrides,
  };
}

export function makePaymentCandidate(
  overrides: Partial<SubscriptionPaymentCandidate> = {},
): SubscriptionPaymentCandidate {
  return {
    transaction_id: TX_NETFLIX_CHARGE,
    local_date: '2026-11-12',
    amount: money('649.00'),
    account_name: 'Wallet',
    merchant: 'Netflix',
    description: 'Netflix November',
    expected_date: '2026-11-10',
    days_from_renewal: 2,
    reasons: ['Same merchant', 'Same amount as the price', 'Within 10 days of the renewal date'],
    reason_codes: ['same_merchant', 'same_amount', 'near_renewal_date'],
    ...overrides,
  };
}
