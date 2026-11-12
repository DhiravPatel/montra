import { z } from 'zod';
import { checkAmount } from '@/shared/forms/decimalField';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate } from '@/shared/formatting/dates';
import { formatMoney } from '@/shared/formatting/money';
import type { Translate } from '@/shared/i18n/types';
import { normalizeRateInput } from '@/features/fx/rate';
import { fromMinor, sumMinor, toMinor } from './exact';
import { isSplitMethod } from './labels';
import {
  type ItemRowValues,
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
  paysAnything,
  trimDecimal,
} from './splitForm';
import type {
  Conversion,
  ExpenseItemInput,
  FxRateSource,
  GroupDetail,
  GroupExpenseDetail,
  GroupExpenseInput,
  GroupMember,
  SplitMethod,
} from './types';

/**
 * `montra`: Montra's rate for the expense date (the server looks it up and
 * works out the amount); `own`: the rate you paid (the server works out
 * the amount from it); `saved`: editing only, the rate saved with the
 * expense is kept.
 */
export type RateChoice = 'montra' | 'own' | 'saved';

export interface ExpenseFormValues extends SplitShape {
  description: string;
  /** In the group currency (when not paid in another currency). */
  amount: string;
  foreign: boolean;
  originalCurrency: string;
  originalAmount: string;
  rateChoice: RateChoice;
  /** Group-currency units per one unit of the original currency. */
  ownRate: string;
  expenseDate: string;
  categoryKey: string;
  notes: string;
  items: ItemRowValues[];
  /** Create only: record my payment in one of my accounts. */
  payerAccountId: string;
  /** Edit only: keep the saved attachment (a new file replaces it). */
  keepAttachment: boolean;
}

/** The fields that decide the amount in the group currency. */
export type AmountValues = Pick<
  ExpenseFormValues,
  | 'foreign'
  | 'amount'
  | 'originalCurrency'
  | 'originalAmount'
  | 'rateChoice'
  | 'ownRate'
  | 'expenseDate'
>;

/** A rate lookup: the original amount (exact), its currency, the group currency and the date. */
export interface ConversionLookup {
  amount: string;
  from: string;
  to: string;
  date: string;
}

/** The rate saved with an expense being edited (kept unless another choice is made). */
export interface SavedRate {
  /** Canonical decimal, as the server stored it. */
  rate: string;
  source: FxRateSource;
  originalAmount: string;
  originalCurrency: string;
  /** The amount the server worked out from the saved original amount and rate. */
  amount: string;
}

export interface ExpenseFormDeps {
  t: Translate;
  locale: string;
  groupCurrency: string;
  exponent: (currency: string) => number;
  /** Montra's answer for a rate lookup, once it has been fetched (null otherwise). */
  conversion: (lookup: ConversionLookup) => Conversion | null;
  /** True once Montra answered that it has no rate for this lookup. */
  rateMissing: (lookup: ConversionLookup) => boolean;
  /** Edit mode: the rate saved with the expense. */
  saved: SavedRate | null;
  meId: string;
}

export function emptyItem(): ItemRowValues {
  return { description: '', amount: '', quantity: '', sharedBy: [] };
}

export function defaultExpenseValues(
  group: GroupDetail,
  active: readonly GroupMember[],
  meId: string,
  today: string,
): ExpenseFormValues {
  const method = isSplitMethod(group.default_split_method) ? group.default_split_method : 'equal';
  return {
    description: '',
    amount: '',
    foreign: false,
    originalCurrency: '',
    originalAmount: '',
    rateChoice: 'montra',
    ownRate: '',
    expenseDate: today,
    categoryKey: '',
    notes: '',
    splitMethod: method,
    participants: emptyParticipants(active),
    payerMode: 'one',
    singlePayer: meId,
    payers: emptyPayers(active),
    items: method === 'itemized' ? [emptyItem()] : [],
    payerAccountId: '',
    keepAttachment: true,
  };
}

/** The rate saved with a foreign-currency expense, for the "keep the saved rate" choice. */
export function savedRateOf(expense: GroupExpenseDetail): SavedRate | null {
  if (!expense.original_amount || !expense.fx_rate || !expense.fx_rate_source) return null;
  return {
    rate: expense.fx_rate,
    source: expense.fx_rate_source,
    originalAmount: expense.original_amount.amount,
    originalCurrency: expense.original_amount.currency,
    amount: expense.amount.amount,
  };
}

/** Form values for editing a saved expense (members who left are not offered again). */
export function expenseToValues(
  expense: GroupExpenseDetail,
  group: GroupDetail,
  active: readonly GroupMember[],
  meId: string,
  locale: string,
): ExpenseFormValues {
  const activeIds = new Set(active.map((member) => member.user_id));
  const method = isSplitMethod(expense.split_method)
    ? expense.split_method
    : isSplitMethod(group.default_split_method)
      ? group.default_split_method
      : 'equal';
  const payers = payersFromSaved(
    active,
    expense.payers.map((payer) => ({ user_id: payer.user_id, amount: payer.paid.amount })),
    activeIds.has(meId) ? meId : (active[0]?.user_id ?? ''),
    locale,
  );
  const saved = savedRateOf(expense);
  return {
    description: expense.description,
    amount: decimalToInput(expense.amount.amount, locale),
    foreign: Boolean(expense.original_amount),
    originalCurrency: expense.original_amount?.currency ?? '',
    originalAmount: expense.original_amount
      ? decimalToInput(expense.original_amount.amount, locale)
      : '',
    // The saved rate is kept unless another choice is made; it also seeds "the rate I paid".
    rateChoice: saved ? 'saved' : 'montra',
    ownRate: saved ? decimalToInput(trimDecimal(saved.rate), locale) : '',
    expenseDate: expense.expense_date,
    categoryKey: expense.category_key ?? '',
    notes: expense.notes ?? '',
    splitMethod: method,
    participants: participantsFromShares(active, expense.split_method, expense.shares, locale),
    ...payers,
    items: expense.items.map((item) => ({
      description: item.description,
      amount: decimalToInput(item.amount.amount, locale),
      quantity: item.quantity ? trimDecimal(item.quantity) : '',
      sharedBy: item.shares.map((share) => share.user_id).filter((id) => activeIds.has(id)),
    })),
    payerAccountId: '',
    keepAttachment: true,
  };
}

/** Whether a saved expense involves people who are no longer active members. */
export function involvesFormerMembers(
  expense: GroupExpenseDetail,
  active: readonly GroupMember[],
): boolean {
  const activeIds = new Set(active.map((member) => member.user_id));
  return [...expense.shares, ...expense.payers].some((entry) => !activeIds.has(entry.user_id));
}

function splitContext(deps: ExpenseFormDeps): SplitContext {
  return {
    t: deps.t,
    locale: deps.locale,
    currency: deps.groupCurrency,
    exponent: deps.exponent(deps.groupCurrency),
  };
}

const CURRENCY = /^[A-Z]{3}$/;

/** The original amount (canonical) when the foreign-currency fields are filled in correctly. */
export function originalAmountValue(values: AmountValues, deps: ExpenseFormDeps): string | null {
  if (!CURRENCY.test(values.originalCurrency) || values.originalCurrency === deps.groupCurrency) {
    return null;
  }
  const result = normalizeDecimalInput(values.originalAmount, deps.locale, {
    exponent: deps.exponent(values.originalCurrency),
  });
  return result.ok ? result.value : null;
}

/** The lookup for the form's original amount, currency and date (null while incomplete). */
export function lookupFor(values: AmountValues, deps: ExpenseFormDeps): ConversionLookup | null {
  const original = originalAmountValue(values, deps);
  if (!original) return null;
  return {
    amount: original,
    from: values.originalCurrency,
    to: deps.groupCurrency,
    date: values.expenseDate,
  };
}

/** The conversion when it belongs to the amount, currency and date now in the form. */
export function matchingConversion(values: AmountValues, deps: ExpenseFormDeps): Conversion | null {
  const lookup = lookupFor(values, deps);
  if (!lookup) return null;
  const conversion = deps.conversion(lookup);
  if (!conversion) return null;
  const matches =
    conversion.from.amount === lookup.amount &&
    conversion.from.currency === lookup.from &&
    conversion.to.currency === lookup.to;
  return matches ? conversion : null;
}

/** Whether the saved rate still applies as saved (same original amount and currency). */
function savedUnchanged(values: AmountValues, deps: ExpenseFormDeps): boolean {
  const original = originalAmountValue(values, deps);
  return (
    deps.saved !== null &&
    original === deps.saved.originalAmount &&
    values.originalCurrency === deps.saved.originalCurrency
  );
}

/**
 * The amount in the group currency as the server knows it: typed (no
 * foreign currency), Montra's conversion for a lookup, or the amount saved
 * with an unchanged expense. Null while it is not known: with your own
 * rate the server works the amount out when the expense is saved, so no
 * money is computed here.
 */
export function expenseTotal(values: AmountValues, deps: ExpenseFormDeps): string | null {
  const groupExponent = deps.exponent(deps.groupCurrency);
  if (!values.foreign) {
    const typed = normalizeDecimalInput(values.amount, deps.locale, { exponent: groupExponent });
    return typed.ok ? typed.value : null;
  }
  switch (values.rateChoice) {
    case 'montra':
      return matchingConversion(values, deps)?.to.amount ?? null;
    case 'saved':
      return savedUnchanged(values, deps) ? (deps.saved?.amount ?? null) : null;
    case 'own':
      return null;
  }
}

/** The rate that goes with the choice (Montra's, your own in canonical form, or the saved one). */
export function expenseRate(values: AmountValues, deps: ExpenseFormDeps): string | null {
  switch (values.rateChoice) {
    case 'montra':
      return matchingConversion(values, deps)?.rate.rate ?? null;
    case 'saved':
      return deps.saved?.rate ?? null;
    case 'own': {
      const rate = normalizeRateInput(values.ownRate, deps.locale);
      return rate.ok ? rate.value : null;
    }
  }
}

const QUANTITY = /^\d{1,9}(\.\d{1,3})?$/;

export function buildExpenseSchema(deps: ExpenseFormDeps) {
  const { t, locale } = deps;
  return z.custom<ExpenseFormValues>().superRefine((values, ctx) => {
    const issue = (path: string, message: string) => {
      ctx.addIssue({ code: 'custom', path: path.split('.'), message });
    };
    const description = values.description.trim();
    if (!description) issue('description', t('groupMoney.form.descriptionRequired'));
    else if (description.length > 200)
      issue('description', t('validation.maxLength', { max: 200 }));
    if (!values.expenseDate) issue('expenseDate', t('validation.dateRequired'));
    else if (!isLocalDate(values.expenseDate)) issue('expenseDate', t('validation.dateInvalid'));
    if (values.notes.length > 2000) issue('notes', t('validation.maxLength', { max: 2000 }));

    const context = splitContext(deps);
    let total: string | null = null;
    if (!values.foreign) {
      total = checkAmount(ctx, {
        value: values.amount,
        path: 'amount',
        locale,
        currency: deps.groupCurrency,
        exponent: context.exponent,
        t,
      });
    } else if (
      !CURRENCY.test(values.originalCurrency) ||
      values.originalCurrency === deps.groupCurrency
    ) {
      issue('originalCurrency', t('groupMoney.form.fx.currencyRequired'));
    } else {
      const original = checkAmount(ctx, {
        value: values.originalAmount,
        path: 'originalAmount',
        locale,
        currency: values.originalCurrency,
        exponent: deps.exponent(values.originalCurrency),
        t,
      });
      if (original !== null) {
        const pair = { from: values.originalCurrency, to: deps.groupCurrency };
        if (values.rateChoice === 'montra') {
          const lookup = lookupFor(values, deps);
          if (lookup && deps.rateMissing(lookup)) {
            issue('checks.rate', t('groupMoney.form.fx.noRate', pair));
          }
        } else if (values.rateChoice === 'own') {
          if (!normalizeRateInput(values.ownRate, locale).ok) {
            issue('ownRate', t('validation.rateFormat'));
          }
        } else if (!deps.saved) {
          issue('checks.rate', t('groupMoney.form.fx.rateMissing'));
        }
        total = expenseTotal(values, deps);
      }
    }

    if (values.splitMethod === 'itemized') {
      checkItems(ctx, values.items, total, context);
    } else {
      checkSplit(ctx, values, total, context);
    }
    // A chosen account is simply not sent when you no longer pay (the field is hidden then).
    checkPayers(ctx, values, total, context);
  });
}

function checkItems(
  ctx: z.RefinementCtx,
  items: readonly ItemRowValues[],
  total: string | null,
  context: SplitContext,
): void {
  const { t } = context;
  const issue = (path: string, message: string) => {
    ctx.addIssue({ code: 'custom', path: path.split('.'), message });
  };
  if (items.length === 0) {
    issue('checks.items', t('groupMoney.form.items.required'));
    return;
  }
  const minors: bigint[] = [];
  let complete = true;
  for (const [index, item] of items.entries()) {
    const description = item.description.trim();
    if (!description)
      issue(`items.${index}.description`, t('groupMoney.form.items.descriptionRequired'));
    else if (description.length > 200) {
      issue(`items.${index}.description`, t('validation.maxLength', { max: 200 }));
    }
    const amount = checkAmount(ctx, {
      value: item.amount,
      path: `items.${index}.amount`,
      locale: context.locale,
      currency: context.currency,
      exponent: context.exponent,
      allowZero: true,
      t,
    });
    const minor = amount === null ? null : toMinor(amount, context.exponent);
    if (minor === null) complete = false;
    else minors.push(minor);
    if (item.quantity.trim() && !QUANTITY.test(item.quantity.trim())) {
      issue(`items.${index}.quantity`, t('groupMoney.form.items.quantityFormat'));
    }
    if (item.sharedBy.length === 0) {
      issue(`items.${index}.sharedBy`, t('groupMoney.form.items.sharedByRequired'));
    }
  }
  if (!complete) return;
  const sum = sumMinor(minors);
  if (sum === 0n) {
    issue('checks.items', t('groupMoney.form.items.needAmount'));
    return;
  }
  const totalMinor = total === null ? null : toMinor(total, context.exponent);
  if (totalMinor !== null && total !== null && sum > totalMinor) {
    let sumText = fromMinor(sum, context.exponent);
    let totalText = total;
    try {
      sumText = formatMoney(sumText, context.currency, context.locale);
      totalText = formatMoney(total, context.currency, context.locale);
    } catch {
      // keep the plain values
    }
    issue('checks.items', t('groupMoney.form.items.exceed', { sum: sumText, total: totalText }));
  }
}

/** Request index → form row, for server field errors. */
export interface RequestRows {
  participants: number[];
  payers: number[];
}

/**
 * The request for a validated form. PATCH replaces the whole expense, so
 * edits send every field (notes and the attachment included). A
 * foreign-currency expense sends the original amount and the rate choice
 * only: the server works out the amount in the group currency.
 */
export function toExpenseInput(
  values: ExpenseFormValues,
  deps: ExpenseFormDeps,
  extra: { receiptFileId?: string; version?: number; create: boolean },
): { body: GroupExpenseInput; rows: RequestRows } {
  const context = splitContext(deps);
  const total = expenseTotal(values, deps);
  const method: SplitMethod = isSplitMethod(values.splitMethod) ? values.splitMethod : 'equal';
  const itemized = method === 'itemized';
  const itemSharers = new Set(values.items.flatMap((item) => item.sharedBy));
  const rows = itemized
    ? values.participants.map((row) => ({ ...row, included: itemSharers.has(row.userId) }))
    : values.participants;
  const participants = participantsInput(method, rows, context);
  const body: GroupExpenseInput = {
    description: values.description.trim(),
    expense_date: values.expenseDate,
    split_method: method,
    participants: participants.participants,
  };
  // A single payer is sent without an amount: the server makes it the whole
  // (possibly converted) total, so the form never converts money itself.
  const payers = payersInput(values, undefined, context);
  if (payers.payers) body.payers = payers.payers;
  if (!values.foreign) body.amount = total ?? '';
  if (values.categoryKey) body.category_key = values.categoryKey;
  if (values.notes.trim()) body.notes = values.notes.trim();
  if (itemized) {
    body.items = values.items.map((item): ExpenseItemInput => {
      const amount = normalizeDecimalInput(item.amount, deps.locale, {
        exponent: context.exponent,
        allowZero: true,
      });
      const quantity = item.quantity.trim();
      return {
        description: item.description.trim(),
        amount: amount.ok ? amount.value : item.amount.trim(),
        ...(quantity ? { quantity } : {}),
        shared_by: item.sharedBy.map((userId) => ({ user_id: userId })),
      };
    });
  }
  if (values.foreign) {
    const original = originalAmountValue(values, deps);
    if (original) body.original_amount = original;
    body.original_currency = values.originalCurrency;
    if (values.rateChoice === 'montra') {
      body.fx_rate_source = 'lookup';
    } else if (values.rateChoice === 'saved' && deps.saved) {
      body.fx_rate = deps.saved.rate;
      body.fx_rate_source = deps.saved.source;
    } else {
      const rate = normalizeRateInput(values.ownRate, deps.locale);
      if (rate.ok) body.fx_rate = rate.value;
      body.fx_rate_source = 'manual';
    }
  }
  if (extra.receiptFileId) body.receipt_file_id = extra.receiptFileId;
  if (extra.create && values.payerAccountId && paysAnything(values, deps.meId, context)) {
    body.payer_account_id = values.payerAccountId;
  }
  if (extra.version !== undefined) body.version = extra.version;
  return { body, rows: { participants: participants.rowIndexes, payers: payers.rowIndexes } };
}

/** API body fields (without `body.`) → form fields, for server validation details. */
export function expenseFieldMap(values: ExpenseFormValues): Readonly<Record<string, string>> {
  return {
    description: 'description',
    amount: values.foreign ? 'originalAmount' : 'amount',
    expense_date: 'expenseDate',
    category_key: 'categoryKey',
    notes: 'notes',
    split_method: 'splitMethod',
    original_amount: 'originalAmount',
    original_currency: 'originalCurrency',
    fx_rate: values.rateChoice === 'own' ? 'ownRate' : 'checks.rate',
    fx_rate_source: 'checks.rate',
    payer_account_id: 'payerAccountId',
    account_id: 'payerAccountId',
  };
}
