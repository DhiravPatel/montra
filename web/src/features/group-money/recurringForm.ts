import { z } from 'zod';
import { checkAmount } from '@/shared/forms/decimalField';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import type { Translate } from '@/shared/i18n/types';
import {
  type ScheduleValues,
  emptySchedule,
  scheduleSchema,
  toScheduleInput,
} from '@/features/planning/schedule';
import { isRecurringSplitMethod } from './labels';
import {
  type SplitContext,
  type SplitShape,
  checkPayers,
  checkSplit,
  emptyParticipants,
  emptyPayers,
  participantsFromShares,
  participantsInput,
  payersFromSaved,
  payersInput,
} from './splitForm';
import type {
  GroupDetail,
  GroupMember,
  GroupRecurring,
  GroupRecurringInput,
  GroupRecurringUpdate,
  RecurringSplitMethod,
} from './types';

export interface RecurringFormValues extends SplitShape {
  name: string;
  /** Each expense's amount in the group currency. */
  amount: string;
  description: string;
  categoryKey: string;
  autoAdd: boolean;
  /** Create only: a schedule cannot change later (stop it and create a new one). */
  schedule: ScheduleValues;
}

function defaultMethod(group: GroupDetail): RecurringSplitMethod {
  // Itemized splits are not offered for recurring expenses (items change every time).
  return isRecurringSplitMethod(group.default_split_method) ? group.default_split_method : 'equal';
}

export function defaultRecurringValues(
  group: GroupDetail,
  active: readonly GroupMember[],
  meId: string,
  today: string,
): RecurringFormValues {
  return {
    name: '',
    amount: '',
    description: '',
    categoryKey: '',
    autoAdd: false,
    splitMethod: defaultMethod(group),
    participants: emptyParticipants(active),
    payerMode: 'adder',
    singlePayer: meId,
    payers: emptyPayers(active),
    schedule: emptySchedule(today),
  };
}

/** Form values for editing a recurring expense (its schedule is shown, not edited). */
export function recurringToValues(
  recurring: GroupRecurring,
  group: GroupDetail,
  active: readonly GroupMember[],
  meId: string,
  locale: string,
  today: string,
): RecurringFormValues {
  const template = recurring.template;
  const method =
    template.split_method && isRecurringSplitMethod(template.split_method)
      ? template.split_method
      : defaultMethod(group);
  const saved = template.payers ?? [];
  const payers = payersFromSaved(active, saved, meId, locale);
  return {
    name: recurring.rule.name,
    amount: recurring.rule.amount ? decimalToInput(recurring.rule.amount.amount, locale) : '',
    description: template.description ?? '',
    categoryKey: template.category_key ?? '',
    autoAdd: recurring.auto_add,
    splitMethod: method,
    participants: participantsFromShares(
      active,
      method,
      template.participants.map((participant) => ({
        user_id: participant.user_id,
        ...(participant.value ? { input_value: participant.value } : {}),
      })),
      locale,
    ),
    ...(saved.length === 0 ? { ...payers, payerMode: 'adder' as const } : payers),
    schedule: emptySchedule(today),
  };
}

export interface RecurringFormDeps {
  t: Translate;
  locale: string;
  currency: string;
  exponent: number;
  mode: 'create' | 'edit';
}

function splitContext(deps: RecurringFormDeps): SplitContext {
  return { t: deps.t, locale: deps.locale, currency: deps.currency, exponent: deps.exponent };
}

export function recurringTotal(amount: string, deps: RecurringFormDeps): string | null {
  const result = normalizeDecimalInput(amount, deps.locale, { exponent: deps.exponent });
  return result.ok ? result.value : null;
}

export function buildRecurringSchema(deps: RecurringFormDeps) {
  const { t } = deps;
  const schedule = scheduleSchema(t);
  return z.custom<RecurringFormValues>().superRefine((values, ctx) => {
    const issue = (path: (string | number)[], message: string) => {
      ctx.addIssue({ code: 'custom', path, message });
    };
    const name = values.name.trim();
    if (!name) issue(['name'], t('groupMoney.recurring.form.nameRequired'));
    else if (name.length > 120) issue(['name'], t('validation.maxLength', { max: 120 }));
    if (values.description.trim().length > 200) {
      issue(['description'], t('validation.maxLength', { max: 200 }));
    }
    const total = checkAmount(ctx, {
      value: values.amount,
      path: 'amount',
      locale: deps.locale,
      currency: deps.currency,
      exponent: deps.exponent,
      t,
    });
    const context = splitContext(deps);
    if (!isRecurringSplitMethod(values.splitMethod)) {
      issue(['splitMethod'], t('groupMoney.form.split.methodRequired'));
    } else {
      checkSplit(ctx, values, total, context);
    }
    checkPayers(ctx, values, total, context);
    if (deps.mode === 'create') {
      const result = schedule.safeParse(values.schedule);
      if (!result.success) {
        for (const problem of result.error.issues) {
          issue(
            [
              'schedule',
              ...problem.path.map((part) => (typeof part === 'symbol' ? String(part) : part)),
            ],
            problem.message,
          );
        }
      }
    }
  });
}

function templateFields(values: RecurringFormValues, deps: RecurringFormDeps) {
  const context = splitContext(deps);
  const total = recurringTotal(values.amount, deps) ?? values.amount.trim();
  const method: RecurringSplitMethod = isRecurringSplitMethod(values.splitMethod)
    ? values.splitMethod
    : 'equal';
  const participants = participantsInput(method, values.participants, context);
  const payers = payersInput(values, total, context);
  return {
    total,
    method,
    participants,
    payers,
    fields: {
      amount: total,
      split_method: method,
      participants: participants.participants,
      auto_add: values.autoAdd,
      ...(payers.payers ? { payers: payers.payers } : {}),
      ...(values.description.trim() ? { description: values.description.trim() } : {}),
      ...(values.categoryKey ? { category_key: values.categoryKey } : {}),
    },
  };
}

export function toRecurringInput(
  values: RecurringFormValues,
  deps: RecurringFormDeps,
): { body: GroupRecurringInput; rows: { participants: number[]; payers: number[] } } {
  const template = templateFields(values, deps);
  return {
    body: { name: values.name.trim(), ...template.fields, ...toScheduleInput(values.schedule) },
    rows: { participants: template.participants.rowIndexes, payers: template.payers.rowIndexes },
  };
}

/** The whole template is replaced, so every field is sent (with the version that was edited). */
export function toRecurringUpdate(
  values: RecurringFormValues,
  deps: RecurringFormDeps,
  version: number,
): { body: GroupRecurringUpdate; rows: { participants: number[]; payers: number[] } } {
  const template = templateFields(values, deps);
  return {
    body: { name: values.name.trim(), ...template.fields, version },
    rows: { participants: template.participants.rowIndexes, payers: template.payers.rowIndexes },
  };
}
