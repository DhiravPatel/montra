import { decimalSeparators } from '@/shared/formatting/decimal';

/**
 * Exchange rates are exact decimal strings ("83.1234": quote units per one
 * base unit). They are handled as text only, never as binary floating
 * point, so what a person types is exactly what the API stores and what the
 * API returns is exactly what is shown.
 */

/** The API's limits for a rate: up to 12 decimal places and 40 characters. */
export const RATE_MAX_DECIMALS = 12;
const RATE_MAX_LENGTH = 40;

/** `ambiguous`: a "." in a locale whose decimal mark is "," ("15.800" may mean 15800). */
export type RateIssue = 'empty' | 'format' | 'precision' | 'zero' | 'ambiguous';

export type RateResult = { ok: true; value: string } | { ok: false; issue: RateIssue };

const nativeDigitCache = new Map<string, readonly string[]>();

function nativeDigits(locale: string): readonly string[] {
  let digits = nativeDigitCache.get(locale);
  if (!digits) {
    const format = new Intl.NumberFormat(locale, { useGrouping: false });
    digits = Array.from({ length: 10 }, (_, digit) => format.format(digit));
    nativeDigitCache.set(locale, digits);
  }
  return digits;
}

function toAsciiDigits(value: string, locale: string): string {
  const digits = nativeDigits(locale);
  if (digits[0] === '0') return value;
  return Array.from(value, (char) => {
    const index = digits.indexOf(char);
    return index === -1 ? char : String(index);
  }).join('');
}

/**
 * Reads a typed rate ("83.1234", or "83,1234" where the comma is the decimal
 * mark) into the API's canonical form. Grouping marks, signs and exponents
 * are rejected rather than guessed; trailing zeros are dropped.
 */
export function normalizeRateInput(raw: string, locale: string): RateResult {
  let text = toAsciiDigits(raw.trim(), locale);
  if (text === '') return { ok: false, issue: 'empty' };
  if (decimalSeparators(locale).decimal === ',') {
    if (text.includes(',')) {
      // The comma is the decimal mark, so a dot can only be grouping: not accepted.
      if (text.includes('.')) return { ok: false, issue: 'ambiguous' };
      text = text.replace(',', '.');
    } else if (/^\d*\.\d{3}$/.test(text)) {
      // "15.800" is 15800 to some readers and 15.8 to others: ask for the comma.
      return { ok: false, issue: 'ambiguous' };
    }
  }
  if (!/^\d*(\.\d*)?$/.test(text) || !/\d/.test(text)) return { ok: false, issue: 'format' };
  const [integerRaw = '', fractionRaw = ''] = text.split('.');
  if (fractionRaw.length > RATE_MAX_DECIMALS) {
    // Extra digits are fine only when they are zeros.
    if (/[1-9]/.test(fractionRaw.slice(RATE_MAX_DECIMALS)))
      return { ok: false, issue: 'precision' };
  }
  const integer = integerRaw.replace(/^0+(?=\d)/, '') || '0';
  const fraction = fractionRaw.slice(0, RATE_MAX_DECIMALS).replace(/0+$/, '');
  if (!/[1-9]/.test(integer + fraction)) return { ok: false, issue: 'zero' };
  const value = fraction ? `${integer}.${fraction}` : integer;
  if (value.length > RATE_MAX_LENGTH) return { ok: false, issue: 'format' };
  return { ok: true, value };
}

/**
 * A rate for display: trailing zeros dropped ("83.123400000000" → "83.1234"),
 * the integer part grouped for the locale and the locale's decimal mark.
 * Exact at any size; returns the raw text when it is not a plain decimal.
 */
export function formatRate(rate: string, locale: string): string {
  const match = /^(\d+)(?:\.(\d+))?$/.exec(rate.trim());
  if (!match) return rate;
  const integer = BigInt(match[1] ?? '0');
  const fraction = (match[2] ?? '').replace(/0+$/, '');
  const grouped = new Intl.NumberFormat(locale, { useGrouping: true }).format(integer);
  if (!fraction) return grouped;
  const digits = nativeDigits(locale);
  const localized = Array.from(fraction, (char) => digits[Number(char)] ?? char).join('');
  return `${grouped}${decimalSeparators(locale).decimal}${localized}`;
}
