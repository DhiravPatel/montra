import { decimalToInput } from '@/shared/formatting/decimal';
import type { Account, Bill, RecurringRule } from '@/shared/finance/types';
import { type EditableKind, isEditableKind } from './labels';
import { type ScheduleValues, emptySchedule, scheduleFromRule } from './schedule';

/** Bill form state (strings as typed; amounts are parsed exactly on submit). */
export interface BillFormValues {
  name: string;
  providerName: string;
  amount: string;
  variable: boolean;
  accountId: string;
  /** Used only when no payment account is chosen (otherwise the account's currency). */
  currency: string;
  categoryId: string;
  notes: string;
  schedule: ScheduleValues;
}

export function emptyBillValues(currency: string, today: string): BillFormValues {
  return {
    name: '',
    providerName: '',
    amount: '',
    variable: false,
    accountId: '',
    currency,
    categoryId: '',
    notes: '',
    schedule: emptySchedule(today),
  };
}

export function billToValues(bill: Bill, locale: string): BillFormValues {
  return {
    name: bill.name,
    providerName: bill.provider_name ?? '',
    amount: bill.expected_amount ? decimalToInput(bill.expected_amount.amount, locale) : '',
    variable: bill.amount_is_variable,
    accountId: bill.payment_account_id ?? '',
    currency: bill.currency,
    categoryId: bill.category_id ?? '',
    notes: bill.notes ?? '',
    schedule: scheduleFromRule(bill.schedule),
  };
}

/** Recurring income, expense or transfer form state. */
export interface RuleFormValues {
  kind: EditableKind;
  name: string;
  amount: string;
  variable: boolean;
  accountId: string;
  toAccountId: string;
  currency: string;
  categoryId: string;
  merchantName: string;
  description: string;
  notes: string;
  autoPost: boolean;
  schedule: ScheduleValues;
}

export function emptyRuleValues(currency: string, today: string): RuleFormValues {
  return {
    kind: 'expense',
    name: '',
    amount: '',
    variable: false,
    accountId: '',
    toAccountId: '',
    currency,
    categoryId: '',
    merchantName: '',
    description: '',
    notes: '',
    autoPost: false,
    schedule: emptySchedule(today),
  };
}

/** Form values for an existing rule (the payee comes with the rule as `merchant`). */
export function ruleToValues(rule: RecurringRule, locale: string): RuleFormValues {
  return {
    kind: isEditableKind(rule.kind) ? rule.kind : 'expense',
    name: rule.name,
    amount: rule.amount ? decimalToInput(rule.amount.amount, locale) : '',
    variable: rule.amount_is_variable,
    accountId: rule.account_id ?? '',
    toAccountId: rule.to_account_id ?? '',
    currency: rule.currency ?? rule.amount?.currency ?? '',
    categoryId: rule.category_id ?? '',
    merchantName: rule.merchant?.name ?? '',
    description: rule.description ?? '',
    notes: rule.notes ?? '',
    autoPost: rule.auto_post,
    schedule: scheduleFromRule(rule),
  };
}

/**
 * Accounts that can be chosen: the user's active accounts plus the one the
 * record already uses (even if it was archived since), so it stays selected.
 */
export function accountChoices(
  accounts: readonly Account[] | undefined,
  keep: readonly (string | undefined)[],
): Account[] {
  const kept = new Set(keep.filter(Boolean));
  return (accounts ?? []).filter(
    (account) => (account.owned && account.status === 'active') || kept.has(account.id),
  );
}
