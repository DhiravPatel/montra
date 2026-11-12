import type { Money } from '@/shared/api/types';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import type { ReceiptExtraction, ReceiptLineItemInput, ReceiptReviewInput } from './types';

/** One receipt line as typed in the review form. */
export interface LineValues {
  description: string;
  quantity: string;
  unitPrice: string;
  amount: string;
  tax: string;
}

/** The review form: every value is typed (or confirmed) by the person. */
export interface ReviewValues {
  merchant: string;
  date: string;
  time: string;
  currency: string;
  total: string;
  subtotal: string;
  tax: string;
  tip: string;
  discount: string;
  paymentHint: string;
  receiptNumber: string;
  lines: LineValues[];
}

/** The API keeps up to 500 lines per receipt. */
export const MAX_LINE_ITEMS = 500;

export const TEXT_LIMITS = {
  merchant: 200,
  paymentHint: 60,
  receiptNumber: 80,
  lineDescription: 200,
} as const;

export function emptyLine(): LineValues {
  return { description: '', quantity: '', unitPrice: '', amount: '', tax: '' };
}

export function lineIsBlank(line: LineValues): boolean {
  return [line.description, line.quantity, line.unitPrice, line.amount, line.tax].every(
    (value) => value.trim() === '',
  );
}

/** "2.000" → "2", "0.750" → "0.75" (the API pads quantities to three decimals). */
export function trimQuantity(value: string): string {
  return value.includes('.') ? value.replace(/0+$/, '').replace(/\.$/, '') : value;
}

/** A quantity as the API expects it (up to 9 digits and 3 decimals), or null when unusable. */
export function normalizeQuantity(value: string, locale: string): string | null {
  const result = normalizeDecimalInput(value, locale, { exponent: 3, allowZero: true });
  if (!result.ok) return null;
  const quantity = trimQuantity(result.value);
  const integer = quantity.split('.')[0] ?? '';
  return integer.length <= 9 ? quantity : null;
}

/**
 * Card and account numbers are never stored: a hint keeps at most the last
 * four digits. Digits separated by spaces or dashes count as one number.
 */
export function paymentHintIsSafe(value: string): boolean {
  return !/\d{5,}/.test(value.replace(/[\s-]/g, ''));
}

/** "HH:MM", 24-hour. */
export function isReceiptTime(value: string): boolean {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
}

function amountInput(money: Pick<Money, 'amount'> | undefined, locale: string): string {
  return money ? decimalToInput(money.amount, locale) : '';
}

/**
 * Form values from the person's last review, or an empty form. Values read
 * automatically in the past are never used to fill the form.
 */
export function reviewDefaults(
  reviewed: ReceiptExtraction | null,
  baseCurrency: string,
  locale: string,
): ReviewValues {
  if (!reviewed) {
    return {
      merchant: '',
      date: '',
      time: '',
      currency: baseCurrency,
      total: '',
      subtotal: '',
      tax: '',
      tip: '',
      discount: '',
      paymentHint: '',
      receiptNumber: '',
      lines: [],
    };
  }
  return {
    merchant: reviewed.merchant_name ?? '',
    date: reviewed.receipt_date ?? '',
    time: reviewed.receipt_time ?? '',
    currency: reviewed.currency ?? reviewed.total?.currency ?? baseCurrency,
    total: amountInput(reviewed.total, locale),
    subtotal: amountInput(reviewed.subtotal, locale),
    tax: amountInput(reviewed.tax, locale),
    tip: amountInput(reviewed.tip, locale),
    discount: amountInput(reviewed.discount, locale),
    paymentHint: reviewed.payment_hint ?? '',
    receiptNumber: reviewed.receipt_number ?? '',
    lines: reviewed.line_items.map((line) => ({
      description: line.description ?? '',
      quantity: line.quantity ? trimQuantity(line.quantity) : '',
      unitPrice: amountInput(line.unit_price, locale),
      amount: amountInput(line.amount, locale),
      tax: amountInput(line.tax, locale),
    })),
  };
}

export interface ReviewRequest {
  body: ReceiptReviewInput;
  /** The form position of each line sent (blank lines are left out), to place server errors. */
  lineIndexes: number[];
}

/**
 * The PATCH /receipts/{id}/review body. Amounts are exact decimal strings in
 * the receipt currency's precision. Returns null when a value cannot be read
 * exactly (the form validates the same rules first).
 */
export function toReviewRequest(
  values: ReviewValues,
  version: number,
  locale: string,
  exponent: number,
): ReviewRequest | null {
  // '' for an empty field, null when the typed value cannot be read exactly.
  const amount = (value: string): string | null => {
    if (value.trim() === '') return '';
    const result = normalizeDecimalInput(value, locale, { exponent, allowZero: true });
    return result.ok ? result.value : null;
  };
  const text = (value: string) => value.trim();

  const lineItems: ReceiptLineItemInput[] = [];
  const lineIndexes: number[] = [];
  for (const [index, line] of values.lines.entries()) {
    if (lineIsBlank(line)) continue;
    const quantity = line.quantity.trim() === '' ? '' : normalizeQuantity(line.quantity, locale);
    const unitPrice = amount(line.unitPrice);
    const lineAmount = amount(line.amount);
    const lineTax = amount(line.tax);
    if (quantity === null || unitPrice === null || lineAmount === null || lineTax === null) {
      return null;
    }
    const description = text(line.description);
    lineItems.push({
      ...(description ? { description } : {}),
      ...(quantity ? { quantity } : {}),
      ...(unitPrice ? { unit_price: unitPrice } : {}),
      ...(lineAmount ? { amount: lineAmount } : {}),
      ...(lineTax ? { tax: lineTax } : {}),
    });
    lineIndexes.push(index);
  }

  const total = amount(values.total);
  const subtotal = amount(values.subtotal);
  const tax = amount(values.tax);
  const tip = amount(values.tip);
  const discount = amount(values.discount);
  if (!total || subtotal === null || tax === null || tip === null || discount === null) {
    return null;
  }
  const merchant = text(values.merchant);
  const time = text(values.time);
  const paymentHint = text(values.paymentHint);
  const receiptNumber = text(values.receiptNumber);
  const body: ReceiptReviewInput = {
    receipt_date: values.date,
    total,
    currency: values.currency,
    version,
    ...(merchant ? { merchant_name: merchant } : {}),
    ...(time ? { receipt_time: time } : {}),
    ...(subtotal ? { subtotal } : {}),
    ...(tax ? { tax } : {}),
    ...(tip ? { tip } : {}),
    ...(discount ? { discount } : {}),
    ...(paymentHint ? { payment_hint: paymentHint } : {}),
    ...(receiptNumber ? { receipt_number: receiptNumber } : {}),
    ...(lineItems.length > 0 ? { line_items: lineItems } : {}),
  };
  return { body, lineIndexes };
}
