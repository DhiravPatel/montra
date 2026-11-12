import type {
  Bill,
  BillClearable,
  BillInput,
  BillPatch,
  RecurringRule,
  RecurringRuleClearable,
  RecurringRuleInput,
  RecurringRulePatch,
} from '@/shared/finance/types';
import type { ScheduleInput } from './schedule';

/*
 * Partial updates (PATCH /bills/{id}, PATCH /recurring-rules/{id}): only the
 * fields sent change. The form builds the full request it would create; the
 * builders below compare it with the record on screen and keep what
 * changed. A previously set reference or number the user emptied goes into
 * `clear`; emptied text is sent as "". Lists replace the whole list. A field
 * is never both sent and cleared.
 */

type ScheduleSource = Pick<
  RecurringRule,
  | 'frequency'
  | 'interval_count'
  | 'interval_unit'
  | 'by_month_day'
  | 'by_weekday'
  | 'by_week_of_month'
  | 'start_date'
  | 'end_date'
  | 'max_occurrences'
  | 'local_time'
  | 'reminder_days_before'
>;

const ANCHORS = ['by_month_day', 'by_weekday', 'by_week_of_month'] as const;
type AnchorField = (typeof ANCHORS)[number];

/** Schedule fields both patches can clear (pushing them into each `clear` list checks this). */
export type ScheduleClearable = 'max_occurrences' | AnchorField;

export interface ScheduleChanges {
  fields: Partial<ScheduleInput>;
  clear: ScheduleClearable[];
}

/** An anchor the record has; 0 means "not set" except for Sunday (weekday 0). */
function anchorOf(current: ScheduleSource, field: AnchorField): number | undefined {
  const value = current[field];
  if (value === undefined || (value === 0 && field !== 'by_weekday')) return undefined;
  return value;
}

function sortedUnique(values: readonly number[]): number[] {
  return [...new Set(values)].sort((a, b) => a - b);
}

function sameNumbers(a: readonly number[], b: readonly number[]): boolean {
  const left = sortedUnique(a);
  const right = sortedUnique(b);
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

/**
 * What changed in a schedule. A new frequency (or interval) makes the API
 * reset the interval and day anchors to the ones sent with it, so then every
 * anchor the new schedule uses is sent again; anchors it no longer uses are
 * cleared.
 */
export function scheduleChanges(current: ScheduleSource, desired: ScheduleInput): ScheduleChanges {
  const fields: Partial<ScheduleInput> = {};
  const clear: ScheduleClearable[] = [];
  const newFrequency = desired.frequency !== current.frequency;
  let reset = newFrequency;
  if (newFrequency) fields.frequency = desired.frequency;
  if (desired.frequency === 'custom') {
    if (newFrequency || desired.interval_count !== current.interval_count) {
      fields.interval_count = desired.interval_count;
      reset = true;
    }
    if (newFrequency || desired.interval_unit !== current.interval_unit) {
      fields.interval_unit = desired.interval_unit;
      reset = true;
    }
  }
  for (const field of ANCHORS) {
    const want = desired[field];
    const have = anchorOf(current, field);
    if (want !== undefined) {
      if (reset || want !== have) fields[field] = want;
    } else if (have !== undefined) {
      clear.push(field);
    }
  }
  if (desired.start_date !== current.start_date) fields.start_date = desired.start_date;
  const end = desired.end_date ?? '';
  if (end !== (current.end_date ?? '')) fields.end_date = end; // "" removes the end date
  // 0 is "no limit" like an absent value.
  const maxHave = current.max_occurrences === 0 ? undefined : current.max_occurrences;
  if (desired.max_occurrences !== undefined) {
    if (desired.max_occurrences !== maxHave) fields.max_occurrences = desired.max_occurrences;
  } else if (maxHave !== undefined) {
    clear.push('max_occurrences');
  }
  if (desired.local_time !== undefined && desired.local_time !== current.local_time) {
    fields.local_time = desired.local_time;
  }
  const reminders = desired.reminder_days_before ?? [];
  if (!sameNumbers(reminders, current.reminder_days_before)) {
    fields.reminder_days_before = sortedUnique(reminders);
  }
  return { fields, clear };
}

/** Text the user may empty: "" clears it. */
function textChange(want: string | undefined, have: string | undefined): string | undefined {
  const next = want ?? '';
  return next === (have ?? '') ? undefined : next;
}

/** A reference the user may set, change or empty. */
function referenceChange(
  want: string | undefined,
  have: string | undefined,
): { send?: string; clear: boolean } {
  if (want) return want === have ? { clear: false } : { send: want, clear: false };
  return { clear: Boolean(have) };
}

/** PATCH /bills/{id} body: the changed fields of `desired` (the form's full request). */
export function billPatchFrom(bill: Bill, desired: BillInput): BillPatch {
  const patch: BillPatch = { version: bill.version };
  const clear: BillClearable[] = [];
  if (desired.name !== bill.name) patch.name = desired.name;
  const provider = textChange(desired.provider_name, bill.provider_name);
  if (provider !== undefined) patch.provider_name = provider;
  const variable = desired.amount_is_variable ?? false;
  if (variable !== bill.amount_is_variable) patch.amount_is_variable = variable;
  // "" removes the expected amount (a variable bill has none).
  const expected = textChange(desired.expected_amount, bill.expected_amount?.amount);
  if (expected !== undefined) patch.expected_amount = expected;
  if (desired.currency && desired.currency !== bill.currency) patch.currency = desired.currency;
  const account = referenceChange(desired.payment_account_id, bill.payment_account_id);
  if (account.send) patch.payment_account_id = account.send;
  if (account.clear) clear.push('payment_account_id');
  const category = referenceChange(desired.category_id, bill.category_id);
  if (category.send) patch.category_id = category.send;
  if (category.clear) clear.push('category_id');
  const notes = textChange(desired.notes, bill.notes);
  if (notes !== undefined) patch.notes = notes;
  const schedule = scheduleChanges(bill.schedule, desired);
  Object.assign(patch, schedule.fields);
  clear.push(...schedule.clear);
  if (clear.length > 0) patch.clear = clear;
  return patch;
}

/**
 * PATCH /recurring-rules/{id} body. `currency` is the one the form settled
 * on (the account's currency when an account is chosen); the kind never
 * changes and is not sent.
 */
export function rulePatchFrom(
  rule: RecurringRule,
  desired: RecurringRuleInput,
  currency: string,
): RecurringRulePatch {
  const patch: RecurringRulePatch = { version: rule.version };
  const clear: RecurringRuleClearable[] = [];
  if (desired.name !== rule.name) patch.name = desired.name;
  const variable = desired.amount_is_variable ?? false;
  if (variable !== rule.amount_is_variable) patch.amount_is_variable = variable;
  const autoPost = desired.auto_post ?? false;
  if (autoPost !== rule.auto_post) patch.auto_post = autoPost;
  // "" removes the amount (a variable rule has none).
  const amount = textChange(desired.amount, rule.amount?.amount);
  if (amount !== undefined) patch.amount = amount;
  if (currency && currency !== (rule.currency ?? rule.amount?.currency)) patch.currency = currency;
  for (const field of ['account_id', 'to_account_id', 'category_id'] as const) {
    const change = referenceChange(desired[field], rule[field]);
    if (change.send) patch[field] = change.send;
    if (change.clear) clear.push(field);
  }
  const merchant = textChange(desired.merchant_name, rule.merchant?.name);
  if (merchant !== undefined) patch.merchant_name = merchant;
  const description = textChange(desired.description, rule.description);
  if (description !== undefined) patch.description = description;
  const notes = textChange(desired.notes, rule.notes);
  if (notes !== undefined) patch.notes = notes;
  const schedule = scheduleChanges(rule, desired);
  Object.assign(patch, schedule.fields);
  clear.push(...schedule.clear);
  if (clear.length > 0) patch.clear = clear;
  return patch;
}

/** True when a patch changes nothing (it only carries the version). */
export function isEmptyPatch(patch: { version: number }): boolean {
  return Object.keys(patch).every((key) => key === 'version');
}
