import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type {
  BillPaymentCandidate,
  BillState,
  CalendarItem,
  Occurrence,
  OccurrenceStatus,
  RecurringCommitment,
  RecurringFrequency,
  RecurringIntervalUnit,
  RecurringKind,
  RecurringReport,
  RecurringStatus,
} from '@/shared/finance/types';
import type { MessageKey, Translate } from '@/shared/i18n/types';

/*
 * Localized labels, icons and tones for planning enums. Maps are typed
 * against the generated unions, so a value added to the contract fails
 * compilation until it has a label. Status is always icon + text.
 */

export interface StatusLook {
  label: MessageKey;
  icon: IconName;
  tone: Tone;
}

export const FREQUENCIES = [
  'daily',
  'weekly',
  'biweekly',
  'monthly',
  'bimonthly',
  'quarterly',
  'semiannual',
  'yearly',
  'custom',
] as const satisfies readonly RecurringFrequency[];

type MissingFrequencies = Exclude<RecurringFrequency, (typeof FREQUENCIES)[number]>;
/** Compile-time check: every contract frequency is listed above. */
export const frequenciesAreListed: [MissingFrequencies] extends [never]
  ? true
  : MissingFrequencies = true;

export const frequencyLabel: Readonly<Record<RecurringFrequency, MessageKey>> = {
  daily: 'schedule.frequency.daily',
  weekly: 'schedule.frequency.weekly',
  biweekly: 'schedule.frequency.biweekly',
  monthly: 'schedule.frequency.monthly',
  bimonthly: 'schedule.frequency.bimonthly',
  quarterly: 'schedule.frequency.quarterly',
  semiannual: 'schedule.frequency.semiannual',
  yearly: 'schedule.frequency.yearly',
  custom: 'schedule.frequency.custom',
};

export function isFrequency(value: string): value is RecurringFrequency {
  return (FREQUENCIES as readonly string[]).includes(value);
}

export const INTERVAL_UNITS = [
  'day',
  'week',
  'month',
  'year',
] as const satisfies readonly RecurringIntervalUnit[];

export const intervalUnitLabel: Readonly<Record<RecurringIntervalUnit, MessageKey>> = {
  day: 'schedule.unit.day',
  week: 'schedule.unit.week',
  month: 'schedule.unit.month',
  year: 'schedule.unit.year',
};

export function isIntervalUnit(value: string): value is RecurringIntervalUnit {
  return (INTERVAL_UNITS as readonly string[]).includes(value);
}

/** nth weekday of a month: 1..5 and -1 (last). */
export const WEEK_OF_MONTH = ['1', '2', '3', '4', '5', '-1'] as const;

export const weekOfMonthLabel: Readonly<Record<(typeof WEEK_OF_MONTH)[number], MessageKey>> = {
  '1': 'schedule.nth.1',
  '2': 'schedule.nth.2',
  '3': 'schedule.nth.3',
  '4': 'schedule.nth.4',
  '5': 'schedule.nth.5',
  '-1': 'schedule.nth.last',
};

/** The same ordinals inside a sentence ("on the second Tuesday"). */
export const weekOfMonthInSentence: Readonly<Record<(typeof WEEK_OF_MONTH)[number], MessageKey>> = {
  '1': 'schedule.nthInSentence.1',
  '2': 'schedule.nthInSentence.2',
  '3': 'schedule.nthInSentence.3',
  '4': 'schedule.nthInSentence.4',
  '5': 'schedule.nthInSentence.5',
  '-1': 'schedule.nthInSentence.last',
};

export function isWeekOfMonth(value: string): value is (typeof WEEK_OF_MONTH)[number] {
  return (WEEK_OF_MONTH as readonly string[]).includes(value);
}

export const occurrenceStatusLook: Readonly<Record<OccurrenceStatus, StatusLook>> = {
  scheduled: { label: 'schedule.occurrence.scheduled', icon: 'calendar', tone: 'neutral' },
  overdue: { label: 'schedule.occurrence.overdue', icon: 'alert-circle', tone: 'danger' },
  paid: { label: 'schedule.occurrence.paid', icon: 'check-circle', tone: 'success' },
  posted: { label: 'schedule.occurrence.posted', icon: 'check-circle', tone: 'success' },
  skipped: { label: 'schedule.occurrence.skipped', icon: 'skip-forward', tone: 'neutral' },
};

/** Occurrences that can still be paid, recorded, skipped or postponed (as the API decides). */
export function isOpenOccurrence(status: OccurrenceStatus): boolean {
  return status === 'scheduled' || status === 'overdue';
}

/**
 * The date an occurrence row shows: the scheduled date when it was moved
 * (the row names the new date, `postponed_to`, next to it), otherwise the
 * date it is due.
 */
export function occurrenceRowDate(
  occurrence: Pick<Occurrence, 'postponed_to' | 'occurrence_date' | 'effective_date'>,
): string {
  return occurrence.postponed_to ? occurrence.occurrence_date : occurrence.effective_date;
}

export const billStateLook: Readonly<Record<BillState, StatusLook>> = {
  overdue: { label: 'bills.state.overdue', icon: 'alert-circle', tone: 'danger' },
  due_today: { label: 'bills.state.due_today', icon: 'alert-triangle', tone: 'warning' },
  due_soon: { label: 'bills.state.due_soon', icon: 'clock', tone: 'warning' },
  paid: { label: 'bills.state.paid', icon: 'check-circle', tone: 'success' },
  upcoming: { label: 'bills.state.upcoming', icon: 'calendar', tone: 'neutral' },
  paused: { label: 'bills.state.paused', icon: 'pause', tone: 'neutral' },
  archived: { label: 'bills.state.archived', icon: 'archive', tone: 'neutral' },
  ended: { label: 'bills.state.ended', icon: 'flag', tone: 'neutral' },
};

/** Bills that need attention now (shown first). */
export function billNeedsAttention(state: BillState): boolean {
  return state === 'overdue' || state === 'due_today' || state === 'due_soon';
}

export const recurringKindLabel: Readonly<Record<RecurringKind, MessageKey>> = {
  expense: 'recurring.kind.expense',
  income: 'recurring.kind.income',
  transfer: 'recurring.kind.transfer',
  bill: 'recurring.kind.bill',
  group_expense: 'recurring.kind.group_expense',
};

export const recurringKindIcon: Readonly<Record<RecurringKind, IconName>> = {
  expense: 'trending-down',
  income: 'trending-up',
  transfer: 'arrow-left-right',
  bill: 'receipt',
  group_expense: 'users',
};

/** Kinds created and edited on the Recurring screens (bills have their own). */
export const EDITABLE_KINDS = ['expense', 'income', 'transfer'] as const;
export type EditableKind = (typeof EDITABLE_KINDS)[number];

export function isEditableKind(value: string): value is EditableKind {
  return (EDITABLE_KINDS as readonly string[]).includes(value);
}

export const recurringStatusLook: Readonly<Record<RecurringStatus, StatusLook>> = {
  active: { label: 'recurring.status.active', icon: 'check-circle', tone: 'success' },
  paused: { label: 'recurring.status.paused', icon: 'pause', tone: 'neutral' },
  ended: { label: 'recurring.status.ended', icon: 'flag', tone: 'neutral' },
};

type CalendarKind = CalendarItem['kind'];

export const calendarKindLook: Readonly<
  Record<CalendarKind, { label: MessageKey; icon: IconName }>
> = {
  recurring: { label: 'calendar.kind.recurring', icon: 'repeat' },
  bill: { label: 'calendar.kind.bill', icon: 'receipt' },
  group_expense: { label: 'calendar.kind.group_expense', icon: 'users' },
  subscription_renewal: { label: 'calendar.kind.subscription_renewal', icon: 'refresh' },
  trial_end: { label: 'calendar.kind.trial_end', icon: 'clock' },
  goal_target: { label: 'calendar.kind.goal_target', icon: 'target' },
};

type CalendarStatus = CalendarItem['status'];

/**
 * Calendar statuses: occurrence statuses plus `projected` (beyond the
 * generated schedule), `expected` (subscription renewals and trial ends) and
 * `target` (goal dates).
 */
const calendarStatusLooks: Readonly<Record<CalendarStatus, StatusLook>> = {
  ...occurrenceStatusLook,
  projected: { label: 'calendar.status.projected', icon: 'calendar', tone: 'neutral' },
  expected: { label: 'calendar.status.expected', icon: 'calendar', tone: 'neutral' },
  target: { label: 'calendar.status.target', icon: 'flag', tone: 'info' },
};

/** The look of a calendar status; null for a status newer than this client (shown as sent). */
export function calendarStatusLook(status: string): StatusLook | null {
  return Object.hasOwn(calendarStatusLooks, status)
    ? calendarStatusLooks[status as CalendarStatus]
    : null;
}

/** Commitments still report subscriptions (from /subscriptions) next to recurring kinds. */
export const commitmentKindLabel: Readonly<Record<RecurringCommitment['kind'], MessageKey>> = {
  expense: 'calendar.commitments.kind.expense',
  income: 'calendar.commitments.kind.income',
  transfer: 'calendar.commitments.kind.transfer',
  bill: 'calendar.commitments.kind.bill',
  subscription: 'calendar.commitments.kind.subscription',
  group_expense: 'calendar.commitments.kind.group_expense',
};

/** GET /analytics/recurring `note_code`: what the monthly equivalents count. */
export const recurringNoteLabel: Readonly<Record<RecurringReport['note_code'], MessageKey>> = {
  fixed_amounts_expectations: 'calendar.commitments.note.fixed_amounts_expectations',
};

type CandidateReason = BillPaymentCandidate['reason_codes'][number];

/** Why GET /bills/{id}/payment-candidates suggested a transaction (`reason_codes`). */
export const candidateReasonLabel: Readonly<Record<CandidateReason, MessageKey>> = {
  same_provider: 'bills.markPaid.reason.sameProvider',
  same_amount: 'bills.markPaid.reason.sameAmount',
  amount_close: 'bills.markPaid.reason.amountClose',
  on_due_date: 'bills.markPaid.reason.onDueDate',
  near_due_date: 'bills.markPaid.reason.nearDueDate',
};

/**
 * Localized reasons for a payment candidate. A code newer than this client
 * falls back to the API's English sentence at the same position.
 */
export function candidateReasons(
  candidate: Pick<BillPaymentCandidate, 'reason_codes' | 'reasons'>,
  t: Translate,
): string[] {
  return candidate.reason_codes.map((code, index) =>
    Object.hasOwn(candidateReasonLabel, code)
      ? t(candidateReasonLabel[code])
      : (candidate.reasons[index] ?? code),
  );
}

/**
 * "3 days after the due date" for a candidate's `days_from_due` (payment
 * date minus due date). Null when the payment is on the due date and the
 * on_due_date reason already says so.
 */
export function candidateTiming(
  candidate: Pick<BillPaymentCandidate, 'days_from_due' | 'reason_codes'>,
  t: Translate,
): string | null {
  const days = candidate.days_from_due;
  if (days === 0) {
    return candidate.reason_codes.includes('on_due_date')
      ? null
      : t('bills.markPaid.timing.onDueDate');
  }
  return days < 0
    ? t('bills.markPaid.timing.before', { count: -days })
    : t('bills.markPaid.timing.after', { count: days });
}
