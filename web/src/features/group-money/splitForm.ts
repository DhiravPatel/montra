import type { RefinementCtx } from 'zod';
import { checkAmount } from '@/shared/forms/decimalField';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { formatMoney } from '@/shared/formatting/money';
import type { Translate } from '@/shared/i18n/types';
import {
  basisPointsToPercent,
  fromMinor,
  parseShareWeight,
  percentToBasisPoints,
  sumMinor,
  toMinor,
} from './exact';
import { isSplitMethod } from './labels';
import type {
  ExpenseParticipantInput,
  ExpensePayerInput,
  ExpenseShare,
  GroupMember,
  SplitMethod,
} from './types';

/*
 * The "who paid" and "how to split" parts shared by the expense form and
 * the recurring expense form. Everything is kept as typed text; the request
 * carries exact decimal strings and the server computes every share.
 */

export interface ParticipantRow {
  userId: string;
  included: boolean;
  /** exact: amount; percentage: percent such as 33.33; shares: whole-number weight. */
  value: string;
}

export interface PayerRow {
  userId: string;
  amount: string;
}

/** One line of an itemized split; `sharedBy` lists the people who share it (weight 1 each). */
export interface ItemRowValues {
  description: string;
  amount: string;
  quantity: string;
  sharedBy: string[];
}

/** `adder` (recurring only): whoever adds the expense pays it. */
export type PayerMode = 'one' | 'several' | 'adder';

export interface SplitShape {
  splitMethod: string;
  participants: ParticipantRow[];
  payerMode: PayerMode;
  singlePayer: string;
  payers: PayerRow[];
  /** Form-level messages for whole sections (set by validation, never sent). */
  checks?: { split?: string; payers?: string; items?: string; rate?: string };
}

export interface SplitContext {
  t: Translate;
  locale: string;
  currency: string;
  exponent: number;
}

/** Rows for every active member, everyone included by default. */
export function emptyParticipants(active: readonly GroupMember[]): ParticipantRow[] {
  return active.map((member) => ({ userId: member.user_id, included: true, value: '' }));
}

export function emptyPayers(active: readonly GroupMember[]): PayerRow[] {
  return active.map((member) => ({ userId: member.user_id, amount: '' }));
}

/** "2.000" → "2", "83.250000000000" → "83.25" (display and inputs only). */
export function trimDecimal(value: string): string {
  return value.includes('.') ? value.replace(/0+$/, '').replace(/\.$/, '') : value;
}

/** A stored participant value shown for editing in the locale's format. */
function storedValue(method: string, value: string | undefined, locale: string): string {
  if (!value) return '';
  if (method === 'exact') return decimalToInput(value, locale);
  if (method === 'percentage') return decimalToInput(trimDecimal(value), locale);
  return value;
}

/** Participant rows from saved shares (members who left are not offered again). */
export function participantsFromShares(
  active: readonly GroupMember[],
  method: string,
  shares: readonly Pick<ExpenseShare, 'user_id' | 'input_value'>[],
  locale: string,
): ParticipantRow[] {
  const byUser = new Map(shares.map((share) => [share.user_id, share]));
  return active.map((member) => {
    const share = byUser.get(member.user_id);
    return {
      userId: member.user_id,
      included: Boolean(share),
      value: storedValue(method, share?.input_value, locale),
    };
  });
}

/** Payer rows and mode from saved payers (amounts as typed text). */
export function payersFromSaved(
  active: readonly GroupMember[],
  saved: readonly { user_id: string; amount?: string }[],
  fallbackPayer: string,
  locale: string,
): Pick<SplitShape, 'payerMode' | 'singlePayer' | 'payers'> {
  const amounts = new Map(saved.map((payer) => [payer.user_id, payer.amount]));
  const payers = active.map((member) => {
    const amount = amounts.get(member.user_id);
    return { userId: member.user_id, amount: amount ? decimalToInput(amount, locale) : '' };
  });
  const only = saved.length === 1 ? saved[0] : undefined;
  if (only && active.some((member) => member.user_id === only.user_id)) {
    return { payerMode: 'one', singlePayer: only.user_id, payers };
  }
  return {
    payerMode: saved.length === 0 ? 'one' : 'several',
    singlePayer: fallbackPayer,
    payers,
  };
}

function money(amount: string, context: SplitContext): string {
  try {
    return formatMoney(amount, context.currency, context.locale);
  } catch {
    return `${amount} ${context.currency}`;
  }
}

function normalized(value: string, context: SplitContext): string | null {
  const result = normalizeDecimalInput(value, context.locale, {
    exponent: context.exponent,
    allowZero: true,
  });
  return result.ok ? result.value : null;
}

/** Live guidance for the split section (never blocks; the server has the final word). */
export interface Guidance {
  tone: 'neutral' | 'success' | 'warning';
  text: string;
}

export function remainderGuidance(
  entered: bigint,
  total: string | null,
  context: SplitContext,
): Guidance | null {
  if (total === null) return null;
  const totalMinor = toMinor(total, context.exponent);
  if (totalMinor === null) return null;
  const left = totalMinor - entered;
  if (left === 0n) {
    return { tone: 'success', text: context.t('groupMoney.guide.allAssigned') };
  }
  if (left > 0n) {
    return {
      tone: 'warning',
      text: context.t('groupMoney.guide.leftToAssign', {
        amount: money(fromMinor(left, context.exponent), context),
      }),
    };
  }
  return {
    tone: 'warning',
    text: context.t('groupMoney.guide.overAssigned', {
      amount: money(fromMinor(-left, context.exponent), context),
    }),
  };
}

/** What still needs assigning in the split (exact, percentage) or how it will be shared. */
export function splitGuidance(
  method: string,
  participants: readonly ParticipantRow[],
  total: string | null,
  context: SplitContext,
): Guidance | null {
  const included = participants.filter((row) => row.included);
  const { t } = context;
  if (included.length === 0) {
    return { tone: 'warning', text: t('groupMoney.guide.nobody') };
  }
  switch (method) {
    case 'equal':
      return {
        tone: 'neutral',
        text: t('groupMoney.guide.equal', { count: included.length }),
      };
    case 'exact': {
      const minors = included.map((row) => {
        const value = normalized(row.value, context);
        return value === null ? 0n : (toMinor(value, context.exponent) ?? 0n);
      });
      if (total === null) return { tone: 'neutral', text: t('groupMoney.guide.enterTotal') };
      return remainderGuidance(sumMinor(minors), total, context);
    }
    case 'percentage': {
      const points = included.map((row) => percentToBasisPoints(row.value) ?? 0n);
      const left = 10_000n - sumMinor(points);
      if (left === 0n) return { tone: 'success', text: t('groupMoney.guide.percentDone') };
      return left > 0n
        ? {
            tone: 'warning',
            text: t('groupMoney.guide.percentLeft', { percent: basisPointsToPercent(left) }),
          }
        : {
            tone: 'warning',
            text: t('groupMoney.guide.percentOver', { percent: basisPointsToPercent(-left) }),
          };
    }
    case 'shares': {
      const weights = included.map((row) => parseShareWeight(row.value) ?? 0n);
      const totalWeight = sumMinor(weights);
      return totalWeight === 0n
        ? { tone: 'warning', text: t('groupMoney.guide.sharesNone') }
        : {
            tone: 'neutral',
            text: t('groupMoney.guide.sharesTotal', { count: Number(totalWeight) }),
          };
    }
    default:
      return null;
  }
}

/** Payers' amounts against the total ("₹20.00 left to assign"). */
export function payersGuidance(
  rows: readonly PayerRow[],
  total: string | null,
  context: SplitContext,
): Guidance | null {
  if (total === null) return { tone: 'neutral', text: context.t('groupMoney.guide.enterTotal') };
  const minors = rows.map((row) => {
    const value = row.amount.trim() === '' ? null : normalized(row.amount, context);
    return value === null ? 0n : (toMinor(value, context.exponent) ?? 0n);
  });
  return remainderGuidance(sumMinor(minors), total, context);
}

type Issue = (path: string, message: string) => void;

function issueFor(ctx: RefinementCtx): Issue {
  return (path, message) => {
    ctx.addIssue({ code: 'custom', path: path.split('.'), message });
  };
}

/**
 * Validates participants and their values for a non-itemized split. Sums
 * are checked with exact decimal math when the total is known.
 */
export function checkSplit(
  ctx: RefinementCtx,
  values: Pick<SplitShape, 'splitMethod' | 'participants'>,
  total: string | null,
  context: SplitContext,
): void {
  const issue = issueFor(ctx);
  const { t } = context;
  const method = values.splitMethod;
  if (!isSplitMethod(method)) {
    issue('splitMethod', t('groupMoney.form.split.methodRequired'));
    return;
  }
  const included = values.participants
    .map((row, index) => ({ row, index }))
    .filter(({ row }) => row.included);
  if (included.length === 0) {
    issue('checks.split', t('groupMoney.form.split.nobody'));
    return;
  }
  if (method === 'exact') {
    const minors: bigint[] = [];
    let complete = true;
    for (const { row, index } of included) {
      const value = checkAmount(ctx, {
        value: row.value,
        path: `participants.${index}.value`,
        locale: context.locale,
        currency: context.currency,
        exponent: context.exponent,
        allowZero: true,
        t,
      });
      const minor = value === null ? null : toMinor(value, context.exponent);
      if (minor === null) complete = false;
      else minors.push(minor);
    }
    const totalMinor = total === null ? null : toMinor(total, context.exponent);
    if (complete && totalMinor !== null && sumMinor(minors) !== totalMinor && total !== null) {
      issue(
        'checks.split',
        t('groupMoney.form.split.exactMismatch', {
          sum: money(fromMinor(sumMinor(minors), context.exponent), context),
          total: money(total, context),
        }),
      );
    }
  } else if (method === 'percentage') {
    const points: bigint[] = [];
    let complete = true;
    for (const { row, index } of included) {
      const value = percentToBasisPoints(row.value);
      if (value === null) {
        complete = false;
        issue(`participants.${index}.value`, t('groupMoney.form.split.percentFormat'));
      } else {
        points.push(value);
      }
    }
    const sum = sumMinor(points);
    if (complete && sum !== 10_000n) {
      issue(
        'checks.split',
        t('groupMoney.form.split.percentMismatch', { percent: basisPointsToPercent(sum) }),
      );
    }
  } else if (method === 'shares') {
    const weights: bigint[] = [];
    let complete = true;
    for (const { row, index } of included) {
      const value = parseShareWeight(row.value);
      if (value === null) {
        complete = false;
        issue(`participants.${index}.value`, t('groupMoney.form.split.sharesFormat'));
      } else {
        weights.push(value);
      }
    }
    if (complete && sumMinor(weights) === 0n) {
      issue('checks.split', t('groupMoney.form.split.sharesZero'));
    }
  }
}

/** Validates who paid: one chosen person, or amounts that add up to the total. */
export function checkPayers(
  ctx: RefinementCtx,
  values: Pick<SplitShape, 'payerMode' | 'singlePayer' | 'payers'>,
  total: string | null,
  context: SplitContext,
): void {
  const issue = issueFor(ctx);
  const { t } = context;
  if (values.payerMode === 'one') {
    if (!values.singlePayer) issue('singlePayer', t('groupMoney.form.payers.chooseOne'));
    return;
  }
  if (values.payerMode !== 'several') return;
  const minors: bigint[] = [];
  let complete = true;
  for (const [index, row] of values.payers.entries()) {
    if (row.amount.trim() === '') continue;
    const value = checkAmount(ctx, {
      value: row.amount,
      path: `payers.${index}.amount`,
      locale: context.locale,
      currency: context.currency,
      exponent: context.exponent,
      allowZero: true,
      t,
    });
    const minor = value === null ? null : toMinor(value, context.exponent);
    if (minor === null) complete = false;
    else minors.push(minor);
  }
  if (!complete) return;
  const paid = sumMinor(minors);
  if (paid === 0n) {
    issue('checks.payers', t('groupMoney.form.payers.none'));
    return;
  }
  const totalMinor = total === null ? null : toMinor(total, context.exponent);
  if (totalMinor !== null && total !== null && paid !== totalMinor) {
    issue(
      'checks.payers',
      t('groupMoney.form.payers.mismatch', {
        sum: money(fromMinor(paid, context.exponent), context),
        total: money(total, context),
      }),
    );
  }
}

/** The canonical value a participant sends for a split method (validated input). */
function participantValue(method: SplitMethod, value: string, context: SplitContext): string {
  if (method === 'exact') return normalized(value, context) ?? value.trim();
  if (method === 'percentage') {
    const points = percentToBasisPoints(value);
    return points === null ? value.trim() : basisPointsToPercent(points);
  }
  const weight = parseShareWeight(value);
  return weight === null ? value.trim() : weight.toString();
}

/**
 * Participants for the request, plus each request index's form row (to put
 * server field errors such as `participants[1].value` on the right input).
 */
export function participantsInput(
  method: SplitMethod,
  rows: readonly ParticipantRow[],
  context: SplitContext,
): { participants: ExpenseParticipantInput[]; rowIndexes: number[] } {
  const participants: ExpenseParticipantInput[] = [];
  const rowIndexes: number[] = [];
  rows.forEach((row, index) => {
    if (!row.included) return;
    rowIndexes.push(index);
    participants.push(
      method === 'equal' || method === 'itemized'
        ? { user_id: row.userId }
        : { user_id: row.userId, value: participantValue(method, row.value, context) },
    );
  });
  return { participants, rowIndexes };
}

/** Payers for the request (`adder` sends none: whoever adds it pays). */
export function payersInput(
  values: Pick<SplitShape, 'payerMode' | 'singlePayer' | 'payers'>,
  total: string | undefined,
  context: SplitContext,
): { payers: ExpensePayerInput[] | undefined; rowIndexes: number[] } {
  if (values.payerMode === 'adder') return { payers: undefined, rowIndexes: [] };
  if (values.payerMode === 'one') {
    // A single payer may leave the amount out; the server then uses the total.
    const payer: ExpensePayerInput = { user_id: values.singlePayer };
    if (total) payer.amount = total;
    return { payers: [payer], rowIndexes: [] };
  }
  const payers: ExpensePayerInput[] = [];
  const rowIndexes: number[] = [];
  for (const [index, row] of values.payers.entries()) {
    if (row.amount.trim() === '') continue;
    const value = normalized(row.amount, context);
    if (value === null || !/[1-9]/.test(value)) continue;
    rowIndexes.push(index);
    payers.push({ user_id: row.userId, amount: value });
  }
  return { payers, rowIndexes };
}

/** Whether `userId` pays anything in the form's current payer choice. */
export function paysAnything(
  values: Pick<SplitShape, 'payerMode' | 'singlePayer' | 'payers'>,
  userId: string,
  context: SplitContext,
): boolean {
  if (values.payerMode === 'one') return values.singlePayer === userId;
  if (values.payerMode === 'adder') return false;
  const row = values.payers.find((payer) => payer.userId === userId);
  if (!row || row.amount.trim() === '') return false;
  const value = normalized(row.amount, context);
  return value !== null && /[1-9]/.test(value);
}

/**
 * Field paths for server validation details. `participants[2].value`
 * becomes the form row that was sent at index 2; unknown fields return null
 * (shown in the form summary instead).
 */
export function serverFieldPath(
  field: string,
  maps: { participants: number[]; payers: number[]; payerMode: PayerMode },
  plain: Readonly<Record<string, string>>,
): string | null {
  const name = field.replace(/^body\./, '');
  const indexed = /^(participants|payers|items)\[(\d+)\](?:\.([a-z_]+))?$/.exec(name);
  if (indexed) {
    const [, list, rawIndex = '0', property] = indexed;
    const index = Number(rawIndex);
    if (list === 'participants') {
      const row = maps.participants[index];
      if (row === undefined) return 'checks.split';
      return property === 'value' ? `participants.${row}.value` : 'checks.split';
    }
    if (list === 'payers') {
      if (maps.payerMode === 'one') return 'singlePayer';
      const row = maps.payers[index];
      if (row === undefined) return 'checks.payers';
      return property === 'amount' ? `payers.${row}.amount` : 'checks.payers';
    }
    const itemField: Readonly<Record<string, string>> = {
      description: 'description',
      amount: 'amount',
      quantity: 'quantity',
      shared_by: 'sharedBy',
    };
    const target = property ? itemField[property] : undefined;
    return target ? `items.${index}.${target}` : 'checks.items';
  }
  if (name === 'participants') return 'checks.split';
  if (name === 'payers') return 'checks.payers';
  if (name === 'items') return 'checks.items';
  return plain[name] ?? null;
}
