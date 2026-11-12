import { compareDecimal, decimalToInput } from '@/shared/formatting/decimal';
import type {
  CancellationChecklistItem,
  Subscription,
  SubscriptionClearable,
  SubscriptionDetail,
  SubscriptionInput,
  SubscriptionPatch,
} from '@/shared/finance/types';
import { isFrequency, isIntervalUnit } from './labels';

export interface ChecklistValue {
  item: string;
  done: boolean;
}

/** Form state (strings as typed; amounts stay exact decimals). */
export interface SubscriptionFormValues {
  name: string;
  planName: string;
  merchantName: string;
  amount: string;
  currency: string;
  billingFrequency: string;
  intervalCount: string;
  intervalUnit: string;
  startDate: string;
  nextRenewalDate: string;
  trialEndsOn: string;
  paymentAccountId: string;
  categoryId: string;
  /** Selected reminder offsets as strings (checkbox values). */
  reminders: string[];
  cancellationUrl: string;
  cancellationInstructions: string;
  checklist: ChecklistValue[];
  groupId: string;
  notes: string;
  /** Cancelled subscriptions only: the date the cancellation took effect. */
  cancelledOn: string;
}

export function emptySubscriptionValues(currency: string, today: string): SubscriptionFormValues {
  return {
    name: '',
    planName: '',
    merchantName: '',
    amount: '',
    currency,
    billingFrequency: 'monthly',
    intervalCount: '1',
    intervalUnit: 'month',
    startDate: today,
    nextRenewalDate: '',
    trialEndsOn: '',
    paymentAccountId: '',
    categoryId: '',
    reminders: ['3'],
    cancellationUrl: '',
    cancellationInstructions: '',
    checklist: [],
    groupId: '',
    notes: '',
    cancelledOn: '',
  };
}

export function subscriptionToValues(
  subscription: Subscription,
  locale: string,
): SubscriptionFormValues {
  return {
    name: subscription.name,
    planName: subscription.plan_name ?? '',
    merchantName: subscription.merchant?.name ?? '',
    amount: decimalToInput(subscription.amount.amount, locale),
    currency: subscription.amount.currency,
    billingFrequency: subscription.billing_frequency,
    intervalCount: String(subscription.interval_count),
    intervalUnit: subscription.interval_unit ?? 'month',
    startDate: subscription.start_date,
    nextRenewalDate: subscription.next_renewal_date ?? '',
    trialEndsOn: subscription.trial_ends_on ?? '',
    paymentAccountId: subscription.payment_account_id ?? '',
    categoryId: subscription.category_id ?? '',
    reminders: subscription.reminder_days_before.map(String),
    cancellationUrl: subscription.cancellation_url ?? '',
    cancellationInstructions: subscription.cancellation_instructions ?? '',
    checklist: subscription.cancellation_checklist.map((entry) => ({
      item: entry.item,
      done: entry.done,
    })),
    groupId: subscription.group_id ?? '',
    notes: subscription.notes ?? '',
    cancelledOn: subscription.cancelled_on ?? '',
  };
}

function optional(value: string): string | undefined {
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

/** Reminder offsets as the API takes them: unique whole days 0–30, largest first. */
function reminderDays(values: readonly (string | number)[]): number[] {
  return [...new Set(values.map(Number))]
    .filter((day) => Number.isInteger(day) && day >= 0 && day <= 30)
    .sort((a, b) => b - a);
}

/** Checklist steps with text (empty rows are dropped). */
function checklistItems(values: readonly ChecklistValue[]): CancellationChecklistItem[] {
  return values
    .map((entry) => ({ item: entry.item.trim(), done: entry.done }))
    .filter((entry) => entry.item !== '');
}

/** The new subscription for POST /subscriptions (`amount` is the exact decimal). */
export function toSubscriptionInput(
  values: SubscriptionFormValues,
  amount: string,
): SubscriptionInput {
  const frequency = isFrequency(values.billingFrequency) ? values.billingFrequency : 'monthly';
  const unit = isIntervalUnit(values.intervalUnit) ? values.intervalUnit : undefined;
  const input: SubscriptionInput = {
    name: values.name.trim(),
    amount,
    currency: values.currency,
    billing_frequency: frequency,
    start_date: values.startDate,
    reminder_days_before: reminderDays(values.reminders),
    cancellation_checklist: checklistItems(values.checklist),
  };
  if (frequency === 'custom') {
    input.interval_count = Number(values.intervalCount);
    if (unit) input.interval_unit = unit;
  }
  const plan = optional(values.planName);
  if (plan) input.plan_name = plan;
  const merchant = optional(values.merchantName);
  if (merchant) input.merchant_name = merchant;
  if (values.nextRenewalDate) input.next_renewal_date = values.nextRenewalDate;
  if (values.trialEndsOn) input.trial_ends_on = values.trialEndsOn;
  if (values.paymentAccountId) input.payment_account_id = values.paymentAccountId;
  if (values.categoryId) input.category_id = values.categoryId;
  const url = optional(values.cancellationUrl);
  if (url) input.cancellation_url = url;
  const instructions = optional(values.cancellationInstructions);
  if (instructions) input.cancellation_instructions = instructions;
  if (values.groupId) input.group_id = values.groupId;
  const notes = optional(values.notes);
  if (notes) input.notes = notes;
  return input;
}

function sameList<T>(a: readonly T[], b: readonly T[], same: (x: T, y: T) => boolean): boolean {
  return a.length === b.length && a.every((value, index) => same(value, b[index] as T));
}

/**
 * A partial update for PATCH /subscriptions/{id}: only the fields the user
 * changed, always with the version on screen. Emptied text is sent as ""
 * (the API clears it; an emptied next renewal date is recomputed), and a
 * link the user removed (account, category, group) is named in `clear`.
 * A field is never both sent and cleared. Lists replace the saved ones.
 */
export function toSubscriptionPatch(
  values: SubscriptionFormValues,
  amount: string,
  existing: SubscriptionDetail,
): SubscriptionPatch {
  const patch: SubscriptionPatch = { version: existing.version };
  const clear: SubscriptionClearable[] = [];
  const changedText = (value: string, saved: string | undefined): string | null => {
    const next = value.trim();
    return next === (saved ?? '') ? null : next;
  };

  const name = values.name.trim();
  if (name !== existing.name) patch.name = name;
  const plan = changedText(values.planName, existing.plan_name);
  if (plan !== null) patch.plan_name = plan;
  const merchant = changedText(values.merchantName, existing.merchant?.name);
  if (merchant !== null) patch.merchant_name = merchant;

  // A different currency needs the price in that currency too.
  if (values.currency !== existing.amount.currency) {
    patch.currency = values.currency;
    patch.amount = amount;
  } else if (compareDecimal(amount, existing.amount.amount) !== 0) {
    patch.amount = amount;
  }

  const frequency = isFrequency(values.billingFrequency)
    ? values.billingFrequency
    : existing.billing_frequency;
  const frequencyChanged = frequency !== existing.billing_frequency;
  if (frequencyChanged) patch.billing_frequency = frequency;
  if (frequency === 'custom') {
    const count = Number(values.intervalCount);
    if (frequencyChanged || count !== existing.interval_count) patch.interval_count = count;
    if (isIntervalUnit(values.intervalUnit)) {
      if (frequencyChanged || values.intervalUnit !== existing.interval_unit) {
        patch.interval_unit = values.intervalUnit;
      }
    }
  }

  if (values.startDate !== existing.start_date) patch.start_date = values.startDate;
  // "" asks the API to work the next renewal out from the schedule again.
  if (values.nextRenewalDate !== (existing.next_renewal_date ?? '')) {
    patch.next_renewal_date = values.nextRenewalDate;
  }
  if (values.trialEndsOn !== (existing.trial_ends_on ?? '')) {
    patch.trial_ends_on = values.trialEndsOn;
  }

  if (values.paymentAccountId !== (existing.payment_account_id ?? '')) {
    if (values.paymentAccountId) patch.payment_account_id = values.paymentAccountId;
    else clear.push('payment_account_id');
  }
  if (values.categoryId !== (existing.category_id ?? '')) {
    if (values.categoryId) patch.category_id = values.categoryId;
    else clear.push('category_id');
  }
  if (values.groupId !== (existing.group_id ?? '')) {
    if (values.groupId) patch.group_id = values.groupId;
    else clear.push('group_id');
  }

  const reminders = reminderDays(values.reminders);
  if (!sameList(reminders, reminderDays(existing.reminder_days_before), Object.is)) {
    patch.reminder_days_before = reminders;
  }

  const url = changedText(values.cancellationUrl, existing.cancellation_url);
  if (url !== null) patch.cancellation_url = url;
  const instructions = changedText(
    values.cancellationInstructions,
    existing.cancellation_instructions,
  );
  if (instructions !== null) patch.cancellation_instructions = instructions;
  const checklist = checklistItems(values.checklist);
  const sameStep = (a: CancellationChecklistItem, b: CancellationChecklistItem) =>
    a.item === b.item && a.done === b.done;
  if (!sameList(checklist, existing.cancellation_checklist, sameStep)) {
    patch.cancellation_checklist = checklist;
  }
  const notes = changedText(values.notes, existing.notes);
  if (notes !== null) patch.notes = notes;

  // Only a cancelled subscription has a cancellation date to correct.
  if (
    existing.status === 'cancelled' &&
    values.cancelledOn &&
    values.cancelledOn !== (existing.cancelled_on ?? '')
  ) {
    patch.cancelled_on = values.cancelledOn;
  }

  if (clear.length > 0) patch.clear = clear;
  return patch;
}
