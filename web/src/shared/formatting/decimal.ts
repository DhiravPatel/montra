/**
 * Exact handling of money typed by people (ADR-006).
 *
 * The API accepts amounts as plain decimal strings ("1234.50") in the
 * currency's minor-unit precision. These helpers turn what a person typed in
 * their locale ("1,234.50", "1.234,50", "१२३४.५") into that canonical string
 * using string operations only: no binary floating point is ever involved,
 * so no value can be silently rounded. Anything ambiguous is rejected rather
 * than guessed.
 */

export interface DecimalSeparators {
  decimal: string;
  group: string;
}

const separatorCache = new Map<string, DecimalSeparators>();

/** The decimal and grouping separators a locale uses, e.g. en-IN → "." and ",". */
export function decimalSeparators(locale: string): DecimalSeparators {
  let cached = separatorCache.get(locale);
  if (!cached) {
    const parts = new Intl.NumberFormat(locale, { useGrouping: true }).formatToParts(1234567.5);
    cached = {
      decimal: parts.find((part) => part.type === 'decimal')?.value ?? '.',
      group: parts.find((part) => part.type === 'group')?.value ?? ',',
    };
    separatorCache.set(locale, cached);
  }
  return cached;
}

const digitTableCache = new Map<string, readonly string[]>();

/** The ten native digits of the locale's default numbering system. */
function nativeDigits(locale: string): readonly string[] {
  let digits = digitTableCache.get(locale);
  if (!digits) {
    const format = new Intl.NumberFormat(locale, { useGrouping: false });
    digits = Array.from({ length: 10 }, (_, digit) => format.format(digit));
    digitTableCache.set(locale, digits);
  }
  return digits;
}

export type DecimalIssue = 'empty' | 'format' | 'precision' | 'negative' | 'zero' | 'tooLarge';

export type DecimalResult = { ok: true; value: string } | { ok: false; issue: DecimalIssue };

export interface DecimalRules {
  /** Minor-unit digits of the currency (`exponent` from GET /currencies). */
  exponent: number;
  /** Accept a leading minus sign (balances, adjustments). */
  allowNegative?: boolean;
  /** Accept zero (filters, fees, opening balances). */
  allowZero?: boolean;
}

/** Largest amount the API accepts, in minor units (backend money.MaxMinor = 10^15). */
const MAX_MINOR_DIGITS = '1000000000000000';

const SPACES = /[\s\u00a0\u202f\u2009]/g;
const SPACE_CHAR = /^[\s\u00a0\u202f\u2009]$/;
const ASCII_DIGITS = /^\d+$/;

/**
 * Grouping is accepted only when it is unambiguous: 1–3 leading digits, then
 * groups of 2 or 3 digits (western or Indian), the last one exactly 3. So
 * "1,23,456" and "12,345" pass while "12,50" or "1234,5" are rejected
 * instead of being misread.
 */
function stripGrouping(integer: string, group: string): string | null {
  if (!integer.includes(group)) return integer;
  const parts = integer.split(group);
  const [first, ...rest] = parts;
  const last = rest[rest.length - 1];
  if (first === undefined || last === undefined) return null;
  if (!/^\d{1,3}$/.test(first) || !/^\d{3}$/.test(last)) return null;
  if (!rest.every((part) => /^\d{2,3}$/.test(part))) return null;
  return parts.join('');
}

function toAsciiDigits(value: string, locale: string): string {
  const digits = nativeDigits(locale);
  if (digits[0] === '0') return value;
  let out = '';
  for (const char of value) {
    const index = digits.indexOf(char);
    out += index === -1 ? char : String(index);
  }
  return out;
}

/**
 * Converts typed text into the API's canonical decimal string, padded to the
 * currency's exponent ("1,234.5" → "1234.50" for INR).
 */
export function normalizeDecimalInput(
  raw: string,
  locale: string,
  rules: DecimalRules,
): DecimalResult {
  const exponent = Math.max(0, Math.trunc(rules.exponent));
  let text = toAsciiDigits(raw.trim(), locale).replace(/\u2212/g, '-');
  if (text === '') return { ok: false, issue: 'empty' };

  let negative = false;
  if (text.startsWith('-') || text.startsWith('+')) {
    negative = text.startsWith('-');
    text = text.slice(1).trimStart();
  }
  text = text.replace(SPACES, '');
  if (text === '') return { ok: false, issue: 'format' };

  const separators = decimalSeparators(locale);
  let decimal = separators.decimal;
  let group = separators.decimal === ',' ? '.' : ',';
  // A comma-decimal locale where someone typed "12.50" (no comma, and the
  // dot is not followed by a 3-digit group): read the dot as the decimal point.
  if (decimal === ',' && !text.includes(',')) {
    const dots = text.split('.').length - 1;
    if (dots === 1 && !/\.\d{3}$/.test(text)) {
      decimal = '.';
      group = ',';
    }
  }
  if (
    separators.group !== decimal &&
    separators.group !== group &&
    !SPACE_CHAR.test(separators.group)
  ) {
    // Locales with another grouping mark (e.g. an apostrophe) may use it too.
    text = text.split(separators.group).join(group);
  }

  const pieces = text.split(decimal);
  if (pieces.length > 2) return { ok: false, issue: 'format' };
  const integerRaw = pieces[0] ?? '';
  const fractionRaw = pieces[1] ?? '';
  if (integerRaw === '' && fractionRaw === '') return { ok: false, issue: 'format' };

  const integer = integerRaw === '' ? '0' : stripGrouping(integerRaw, group);
  if (integer === null || !ASCII_DIGITS.test(integer)) return { ok: false, issue: 'format' };
  if (fractionRaw !== '' && !ASCII_DIGITS.test(fractionRaw)) return { ok: false, issue: 'format' };

  let fraction = fractionRaw;
  if (fraction.length > exponent) {
    // Extra digits are fine only when they are zeros ("10.500" for INR).
    if (/[1-9]/.test(fraction.slice(exponent))) return { ok: false, issue: 'precision' };
    fraction = fraction.slice(0, exponent);
  }
  fraction = fraction.padEnd(exponent, '0');

  const minorDigits = (integer + fraction).replace(/^0+/, '');
  if (
    minorDigits.length > MAX_MINOR_DIGITS.length ||
    (minorDigits.length === MAX_MINOR_DIGITS.length && minorDigits > MAX_MINOR_DIGITS)
  ) {
    return { ok: false, issue: 'tooLarge' };
  }

  const isZero = minorDigits === '';
  if (isZero && !rules.allowZero) return { ok: false, issue: 'zero' };
  if (negative && !isZero && !rules.allowNegative) return { ok: false, issue: 'negative' };

  const whole = integer.replace(/^0+(?=\d)/, '');
  const value = exponent > 0 ? `${whole}.${fraction}` : whole;
  return { ok: true, value: negative && !isZero ? `-${value}` : value };
}

/**
 * Shows an API decimal in an input for editing, using the locale's decimal
 * separator and no grouping ("1234.50" → "1234,50" in de-DE).
 */
export function decimalToInput(amount: string, locale: string): string {
  const { decimal } = decimalSeparators(locale);
  return decimal === '.' ? amount : amount.replace('.', decimal);
}

/** Flips the sign of a canonical decimal string (no arithmetic involved). */
export function negateDecimal(value: string): string {
  if (value.startsWith('-')) return value.slice(1);
  if (!/[1-9]/.test(value)) return value; // zero stays unsigned
  return `-${value}`;
}

/** The magnitude of a canonical decimal string ("-25.00" → "25.00"). */
export function absDecimal(value: string): string {
  return value.startsWith('-') || value.startsWith('+') ? value.slice(1) : value;
}

/** True for "0", "0.00", "-0.00". */
export function isZeroDecimal(value: string): boolean {
  return !/[1-9]/.test(value);
}

/**
 * Exact comparison of two canonical decimal strings with the same exponent:
 * -1, 0 or 1. Used for display decisions only, never for totals.
 */
export function compareDecimal(a: string, b: string): -1 | 0 | 1 {
  const sign = (value: string) => (isZeroDecimal(value) ? 0 : value.startsWith('-') ? -1 : 1);
  const sa = sign(a);
  const sb = sign(b);
  if (sa !== sb) return sa < sb ? -1 : 1;
  if (sa === 0) return 0;
  const magnitude = (value: string) => {
    const [int = '0', frac = ''] = absDecimal(value).split('.');
    return { int: int.replace(/^0+(?=\d)/, ''), frac };
  };
  const ma = magnitude(a);
  const mb = magnitude(b);
  const width = Math.max(ma.frac.length, mb.frac.length);
  const fa = ma.frac.padEnd(width, '0');
  const fb = mb.frac.padEnd(width, '0');
  let result: -1 | 0 | 1 = 0;
  if (ma.int.length !== mb.int.length) result = ma.int.length < mb.int.length ? -1 : 1;
  else if (ma.int !== mb.int) result = ma.int < mb.int ? -1 : 1;
  else if (fa !== fb) result = fa < fb ? -1 : 1;
  if (sa === -1) return result === 0 ? 0 : result === 1 ? -1 : 1;
  return result;
}

/**
 * Integer minor units (as found in audit records) to an exact decimal
 * string: 123450 with exponent 2 → "1234.50". Values stay below 2^53.
 */
export function minorToDecimal(minor: number, exponent: number): string {
  if (!Number.isSafeInteger(minor)) throw new RangeError('minorToDecimal: unsafe integer');
  const digits = String(Math.abs(minor)).padStart(exponent + 1, '0');
  const value = exponent > 0 ? `${digits.slice(0, -exponent)}.${digits.slice(-exponent)}` : digits;
  return minor < 0 ? `-${value}` : value;
}
