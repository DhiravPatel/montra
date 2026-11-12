import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import { detailParam } from '@/shared/finance/domainErrors';
import type {
  DetectionCandidate,
  DetectionEvidence,
  Subscription,
  SubscriptionDuplicateWarning,
  SubscriptionEvent,
  SubscriptionFrequency,
  SubscriptionPaymentCandidate,
  SubscriptionStatus,
} from '@/shared/finance/types';
import { formatBasisPoints, formatLocalDate } from '@/shared/formatting/dates';
import { formatMoney } from '@/shared/formatting/money';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { DetectionStatus, SubscriptionListStatus } from './api';

/*
 * Localized labels for subscription enums. Maps typed against the generated
 * unions fail compilation when the contract adds a value.
 */

export const statusLabel: Readonly<Record<SubscriptionStatus, MessageKey>> = {
  trial: 'subscriptions.status.trial',
  active: 'subscriptions.status.active',
  paused: 'subscriptions.status.paused',
  cancellation_pending: 'subscriptions.status.cancellation_pending',
  cancelled: 'subscriptions.status.cancelled',
};

export const statusTone: Readonly<Record<SubscriptionStatus, Tone>> = {
  trial: 'info',
  active: 'success',
  paused: 'neutral',
  cancellation_pending: 'warning',
  cancelled: 'neutral',
};

export const statusIcon: Readonly<Record<SubscriptionStatus, IconName>> = {
  trial: 'clock',
  active: 'check-circle',
  paused: 'pause',
  cancellation_pending: 'alert-triangle',
  cancelled: 'x-circle',
};

export const LIST_FILTERS = [
  '',
  'trial',
  'active',
  'paused',
  'cancellation_pending',
  'cancelled',
  'all',
] as const satisfies readonly SubscriptionListStatus[];

export const listFilterLabel: Readonly<Record<SubscriptionListStatus, MessageKey>> = {
  '': 'subscriptions.filter.current',
  trial: 'subscriptions.filter.trial',
  active: 'subscriptions.filter.active',
  paused: 'subscriptions.filter.paused',
  cancellation_pending: 'subscriptions.filter.cancellation_pending',
  cancelled: 'subscriptions.filter.cancelled',
  all: 'subscriptions.filter.all',
};

export function isListFilter(value: string): value is SubscriptionListStatus {
  return (LIST_FILTERS as readonly string[]).includes(value);
}

export const FREQUENCIES = [
  'weekly',
  'monthly',
  'quarterly',
  'semiannual',
  'yearly',
  'custom',
] as const satisfies readonly SubscriptionFrequency[];

type MissingFrequencies = Exclude<SubscriptionFrequency, (typeof FREQUENCIES)[number]>;
/** Compile-time check: every contract billing frequency is listed above. */
export const frequenciesAreListed: [MissingFrequencies] extends [never]
  ? true
  : MissingFrequencies = true;

export function isFrequency(value: string): value is SubscriptionFrequency {
  return (FREQUENCIES as readonly string[]).includes(value);
}

export const frequencyLabel: Readonly<Record<SubscriptionFrequency, MessageKey>> = {
  weekly: 'subscriptions.frequency.weekly',
  monthly: 'subscriptions.frequency.monthly',
  quarterly: 'subscriptions.frequency.quarterly',
  semiannual: 'subscriptions.frequency.semiannual',
  yearly: 'subscriptions.frequency.yearly',
  custom: 'subscriptions.frequency.custom',
};

export type IntervalUnit = NonNullable<Subscription['interval_unit']>;
export const INTERVAL_UNITS = [
  'day',
  'week',
  'month',
  'year',
] as const satisfies readonly IntervalUnit[];

type MissingUnits = Exclude<IntervalUnit, (typeof INTERVAL_UNITS)[number]>;
/** Compile-time check: every contract interval unit is listed above. */
export const unitsAreListed: [MissingUnits] extends [never] ? true : MissingUnits = true;

export function isIntervalUnit(value: string): value is IntervalUnit {
  return (INTERVAL_UNITS as readonly string[]).includes(value);
}

export const intervalUnitLabel: Readonly<Record<IntervalUnit, MessageKey>> = {
  day: 'subscriptions.unit.day',
  week: 'subscriptions.unit.week',
  month: 'subscriptions.unit.month',
  year: 'subscriptions.unit.year',
};

const everyUnit: Readonly<Record<IntervalUnit, MessageKey>> = {
  day: 'subscriptions.every.day',
  week: 'subscriptions.every.week',
  month: 'subscriptions.every.month',
  year: 'subscriptions.every.year',
};

/** "Monthly", "Every 3 months"... (the billing cycle in words). */
export function cycleLabel(
  subscription: Pick<Subscription, 'billing_frequency' | 'interval_count' | 'interval_unit'>,
  t: Translate,
): string {
  const frequency = subscription.billing_frequency;
  if (frequency === 'custom') {
    const unit = subscription.interval_unit ?? '';
    if (isIntervalUnit(unit)) return t(everyUnit[unit], { count: subscription.interval_count });
    return t('subscriptions.frequency.custom');
  }
  return isFrequency(frequency) ? t(frequencyLabel[frequency]) : frequency;
}

/** Price per cycle as "₹649.00 per month" (the amount is already formatted). */
const perCycle: Readonly<Record<Exclude<SubscriptionFrequency, 'custom'>, MessageKey>> = {
  weekly: 'subscriptions.price.weekly',
  monthly: 'subscriptions.price.monthly',
  quarterly: 'subscriptions.price.quarterly',
  semiannual: 'subscriptions.price.semiannual',
  yearly: 'subscriptions.price.yearly',
};

export function pricePerCycle(
  subscription: Pick<Subscription, 'billing_frequency' | 'interval_count' | 'interval_unit'>,
  amount: string,
  t: Translate,
): string {
  const frequency = subscription.billing_frequency;
  if (isFrequency(frequency) && frequency !== 'custom') return t(perCycle[frequency], { amount });
  return t('subscriptions.price.custom', { amount, cycle: cycleLabel(subscription, t) });
}

export const DETECTION_STATUSES = [
  'pending',
  'confirmed',
  'dismissed',
] as const satisfies readonly DetectionStatus[];

export const detectionStatusLabel: Readonly<Record<DetectionStatus, MessageKey>> = {
  pending: 'subscriptions.review.filter.pending',
  confirmed: 'subscriptions.review.filter.confirmed',
  dismissed: 'subscriptions.review.filter.dismissed',
};

export function isDetectionStatus(value: string): value is DetectionStatus {
  return (DETECTION_STATUSES as readonly string[]).includes(value);
}

export const cadenceLabel: Readonly<Record<DetectionCandidate['cadence'], MessageKey>> = {
  weekly: 'subscriptions.frequency.weekly',
  monthly: 'subscriptions.frequency.monthly',
  quarterly: 'subscriptions.frequency.quarterly',
  semiannual: 'subscriptions.frequency.semiannual',
  yearly: 'subscriptions.frequency.yearly',
};

type EventKind = SubscriptionEvent['kind'];

/*
 * Event kinds, duplicate reasons and detection evidence come with stable
 * codes (the English texts next to them are not shown). The maps are
 * checked against the contract enums; a value newer than this client falls
 * back to a neutral label instead of showing server text.
 */
const eventKinds = {
  created: 'subscriptions.event.created',
  edited: 'subscriptions.event.edited',
  price_changed: 'subscriptions.event.price_changed',
  verified: 'subscriptions.event.verified',
  paused: 'subscriptions.event.paused',
  resumed: 'subscriptions.event.resumed',
  cancellation_started: 'subscriptions.event.cancellation_started',
  cancelled: 'subscriptions.event.cancelled',
  reactivated: 'subscriptions.event.reactivated',
  payment_recorded: 'subscriptions.event.payment_recorded',
  payment_unlinked: 'subscriptions.event.payment_unlinked',
  renewed: 'subscriptions.event.renewed',
  trial_started: 'subscriptions.event.trial_started',
  trial_ending: 'subscriptions.event.trial_ending',
} as const satisfies Readonly<Record<EventKind, MessageKey>>;

const eventIcons = {
  created: 'plus',
  edited: 'pencil',
  price_changed: 'trending-up',
  verified: 'shield-check',
  paused: 'pause',
  resumed: 'play',
  cancellation_started: 'alert-triangle',
  cancelled: 'x-circle',
  reactivated: 'refresh',
  payment_recorded: 'receipt',
  payment_unlinked: 'undo',
  renewed: 'repeat',
  trial_started: 'clock',
  trial_ending: 'bell',
} as const satisfies Readonly<Record<EventKind, IconName>>;

function isEventKind(kind: string): kind is EventKind {
  return kind in eventKinds;
}

export function eventLabel(event: Pick<SubscriptionEvent, 'kind'>, t: Translate): string {
  return isEventKind(event.kind) ? t(eventKinds[event.kind]) : t('subscriptions.event.other');
}

export function eventIcon(event: Pick<SubscriptionEvent, 'kind'>): IconName {
  return isEventKind(event.kind) ? eventIcons[event.kind] : 'history';
}

const noteCodes = {
  matched_by_detection: 'subscriptions.event.matchedByDetection',
} as const satisfies Readonly<Record<NonNullable<SubscriptionEvent['note_code']>, MessageKey>>;

/**
 * The event's note: text Montra wrote is localized by `note_code`; the
 * user's own note is shown as written.
 */
export function eventNote(
  event: Pick<SubscriptionEvent, 'note' | 'note_code'>,
  t: Translate,
): string | null {
  if (event.note_code) {
    return event.note_code in noteCodes ? t(noteCodes[event.note_code]) : null;
  }
  return event.note ? event.note : null;
}

/** "Same price (₹649.00) and billing cycle (Monthly)" and the other duplicate reasons. */
export function duplicateReason(
  warning: Pick<SubscriptionDuplicateWarning, 'reason_code' | 'reason_params'>,
  t: Translate,
  locale: string,
): string {
  switch (warning.reason_code) {
    case 'same_merchant':
      return t('subscriptions.duplicate.sameMerchant');
    case 'same_name':
      return t('subscriptions.duplicate.sameName');
    case 'same_price_and_cycle': {
      const amount = detailParam(warning.reason_params, 'amount');
      const currency = detailParam(warning.reason_params, 'currency');
      const frequency = detailParam(warning.reason_params, 'billing_frequency') ?? '';
      if (amount && currency && isFrequency(frequency) && frequency !== 'custom') {
        let price = `${amount} ${currency}`;
        try {
          price = formatMoney(amount, currency, locale);
        } catch {
          // keep the raw value
        }
        return t('subscriptions.duplicate.samePriceDetail', {
          price,
          cycle: t(frequencyLabel[frequency]),
        });
      }
      return t('subscriptions.duplicate.samePrice');
    }
    default:
      return t('subscriptions.duplicate.similar');
  }
}

/** Confidence in basis points (10000 = certain) as a whole percentage. */
export function formatConfidence(basisPoints: number, locale: string): string {
  const ratio = Math.min(Math.max(basisPoints, 0), 10_000) / 10_000;
  return new Intl.NumberFormat(locale, { style: 'percent', maximumFractionDigits: 0 }).format(
    ratio,
  );
}

type DetectionReason = DetectionEvidence['reason_codes'][number];

const detectionReasonText = {
  charge_cadence: (evidence, t) =>
    t('subscriptions.review.reason.charge_cadence', {
      count: evidence.charge_count,
      interval: t('subscriptions.review.reason.every', { count: evidence.median_interval_days }),
    }),
  intervals_fit_cadence: (evidence, t) =>
    t('subscriptions.review.reason.intervals_fit_cadence', {
      count: evidence.intervals_days.length,
      fit: evidence.intervals_in_cycle,
    }),
  amounts_within_tolerance: (evidence, t, locale) =>
    t('subscriptions.review.reason.amounts_within_tolerance', {
      count: evidence.charge_count,
      within: evidence.amounts_within_tolerance,
      percent: formatBasisPoints(evidence.amount_tolerance_bp, locale),
    }),
} as const satisfies Readonly<
  Record<DetectionReason, (evidence: DetectionEvidence, t: Translate, locale: string) => string>
>;

/**
 * Why a repeating charge looks like a subscription: one sentence per
 * `reason_codes` entry (in the API's order), built from the evidence numbers.
 */
export function detectionReasons(
  evidence: DetectionEvidence,
  t: Translate,
  locale: string,
): string[] {
  return evidence.reason_codes
    .filter((code) => code in detectionReasonText)
    .map((code) => detectionReasonText[code](evidence, t, locale));
}

type CandidateReason = SubscriptionPaymentCandidate['reason_codes'][number];

const candidateReasons = {
  same_merchant: 'subscriptions.payments.reason.same_merchant',
  matches_name: 'subscriptions.payments.reason.matches_name',
  same_amount: 'subscriptions.payments.reason.same_amount',
  amount_close: 'subscriptions.payments.reason.amount_close',
  on_renewal_date: 'subscriptions.payments.reason.on_renewal_date',
  near_renewal_date: 'subscriptions.payments.reason.near_renewal_date',
} as const satisfies Readonly<Record<CandidateReason, MessageKey>>;

/** Localized reasons a payment was suggested (unknown codes are left out). */
export function candidateReasonLabels(
  candidate: Pick<SubscriptionPaymentCandidate, 'reason_codes'>,
  t: Translate,
): string[] {
  return candidate.reason_codes
    .filter((code) => code in candidateReasons)
    .map((code) => t(candidateReasons[code]));
}

/** "2 days after the renewal expected on 10 Nov 2026" (null without an expected date). */
export function candidateTiming(
  candidate: Pick<SubscriptionPaymentCandidate, 'days_from_renewal' | 'expected_date'>,
  t: Translate,
  locale: string,
): string | null {
  const days = candidate.days_from_renewal;
  if (!candidate.expected_date || days === undefined) return null;
  const date = formatLocalDate(candidate.expected_date, locale, 'long');
  if (days === 0) return t('subscriptions.payments.timing.onDate', { date });
  return days > 0
    ? t('subscriptions.payments.timing.after', { count: days, date })
    : t('subscriptions.payments.timing.before', { count: -days, date });
}

/** Reminder choices (days before a renewal or a trial end); saved values are always kept. */
export const REMINDER_CHOICES = [0, 1, 3, 7, 14] as const;

export function reminderLabel(days: number, t: Translate): string {
  return days === 0
    ? t('subscriptions.reminders.sameDay')
    : t('subscriptions.reminders.daysBefore', { count: days });
}

/** "3 days before, 1 day before" (largest first), or "No reminders". */
export function remindersText(days: readonly number[], t: Translate): string {
  if (days.length === 0) return t('subscriptions.reminders.none');
  return [...new Set(days)]
    .sort((a, b) => b - a)
    .map((day) => reminderLabel(day, t))
    .join(', ');
}
