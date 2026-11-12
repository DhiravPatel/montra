/**
 * Exact money formatting (ADR-006).
 *
 * The API sends money as `{ amount_minor, amount, currency }` where `amount`
 * is an exact decimal string. This formatter never converts the amount to a
 * binary floating-point number: the integer part is formatted as a BigInt
 * (exact at any magnitude, with locale grouping such as en-IN lakh/crore),
 * the fraction digits are copied verbatim, and the sign/currency layout is
 * taken from the locale's own pattern via Intl.NumberFormat#formatToParts.
 */

export interface FormatMoneyOptions {
  /**
   * Minor-unit digits of the currency (`exponent` from GET /currencies).
   * When omitted, Intl's currency data is used. Either way the digits the API
   * sent are never dropped: the API's exact string already carries them.
   */
  minorDigits?: number;
  currencyDisplay?: 'symbol' | 'narrowSymbol' | 'code' | 'name';
  signDisplay?: 'auto' | 'always' | 'exceptZero' | 'never';
  /** Use the locale's accounting format for negatives, e.g. ($5.00). */
  accounting?: boolean;
}

const DECIMAL = /^([+-])?(\d+)(?:\.(\d+))?$/;
const CURRENCY_CODE = /^[A-Z]{3}$/;
const NUMERIC_PARTS = new Set<string>(['integer', 'group', 'decimal', 'fraction']);
/** Intl.NumberFormat accepts at most 20 fraction digits in older engines. */
const MAX_FRACTION_DIGITS = 20;

const formatterCache = new Map<string, Intl.NumberFormat>();
const intlDigitsCache = new Map<string, number>();

/** Intl's default fraction digits for a currency (CLDR data), e.g. JPY 0, KWD 3. */
function intlMinorDigits(currency: string): number {
  let digits = intlDigitsCache.get(currency);
  if (digits === undefined) {
    digits =
      new Intl.NumberFormat('en', { style: 'currency', currency }).resolvedOptions()
        .maximumFractionDigits ?? 2;
    intlDigitsCache.set(currency, digits);
  }
  return digits;
}
const digitCache = new Map<string, readonly string[]>();

function currencyFormatter(
  locale: string,
  currency: string,
  digits: number,
  options: FormatMoneyOptions,
): Intl.NumberFormat {
  const display = options.currencyDisplay ?? 'symbol';
  const sign = options.signDisplay ?? 'auto';
  const accounting = options.accounting === true;
  const key = [locale, currency, digits, display, sign, accounting].join('|');
  let formatter = formatterCache.get(key);
  if (!formatter) {
    formatter = new Intl.NumberFormat(locale, {
      style: 'currency',
      currency,
      currencyDisplay: display,
      currencySign: accounting ? 'accounting' : 'standard',
      signDisplay: sign,
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
    });
    formatterCache.set(key, formatter);
  }
  return formatter;
}

/** The ten digits of the formatter's numbering system (e.g. Arabic-Indic). */
function localDigits(locale: string, numberingSystem: string): readonly string[] {
  const key = `${locale}|${numberingSystem}`;
  let digits = digitCache.get(key);
  if (!digits) {
    const single = new Intl.NumberFormat(locale, { numberingSystem, useGrouping: false });
    digits = Array.from({ length: 10 }, (_, digit) => single.format(digit));
    digitCache.set(key, digits);
  }
  return digits;
}

/**
 * Formats an exact decimal string as currency for a locale.
 *
 * @param amount exact decimal string from the API, e.g. "-1234.50"
 * @param currency ISO 4217 code, e.g. "INR"
 * @param locale BCP 47 locale, e.g. "en-IN"
 * @throws RangeError when the amount is not a plain decimal string or the
 *   currency code is malformed. The error never includes the amount.
 */
export function formatMoney(
  amount: string,
  currency: string,
  locale: string,
  options: FormatMoneyOptions = {},
): string {
  const match = DECIMAL.exec(amount);
  if (!match) throw new RangeError('formatMoney: amount must be a plain decimal string');
  if (!CURRENCY_CODE.test(currency))
    throw new RangeError('formatMoney: invalid ISO 4217 currency code');

  const sign = match[1];
  const integerDigits = match[2] ?? '0';
  const fractionDigits = match[3] ?? '';
  // Pad to the currency's minor units but never drop digits the API sent.
  const digits = Math.max(fractionDigits.length, options.minorDigits ?? intlMinorDigits(currency));
  if (digits > MAX_FRACTION_DIGITS) throw new RangeError('formatMoney: too many fraction digits');

  const formatter = currencyFormatter(locale, currency, digits, options);
  const magnitude = BigInt(integerDigits);
  const fraction = fractionDigits.padEnd(digits, '0');
  const isZero = magnitude === 0n && !/[1-9]/.test(fraction);
  const signum = isZero ? 0 : sign === '-' ? -1 : 1;

  const { numberingSystem } = formatter.resolvedOptions();
  const nativeDigits = localDigits(locale, numberingSystem);
  const localizedFraction = Array.from(fraction, (char) => nativeDigits[Number(char)] ?? char).join(
    '',
  );

  // Exact digits with locale grouping; only the numeric parts are kept.
  const numberRun = formatter
    .formatToParts(magnitude)
    .filter((part) => NUMERIC_PARTS.has(part.type))
    .map((part) => (part.type === 'fraction' ? localizedFraction : part.value));

  // Locale layout (sign, currency symbol, spacing, accounting parentheses)
  // for a number with the same sign; its numeric run is swapped for ours.
  const layout = formatter.formatToParts(signum);
  const first = layout.findIndex((part) => NUMERIC_PARTS.has(part.type));
  const last = layout.findLastIndex((part) => NUMERIC_PARTS.has(part.type));
  if (first === -1) return numberRun.join('');

  return [
    ...layout.slice(0, first).map((part) => part.value),
    ...numberRun,
    ...layout.slice(last + 1).map((part) => part.value),
  ].join('');
}

/** Sign of an exact decimal string: -1, 0 or 1 (null when not a decimal). */
export function amountSign(amount: string): -1 | 0 | 1 | null {
  const match = DECIMAL.exec(amount);
  if (!match) return null;
  if (!/[1-9]/.test((match[2] ?? '') + (match[3] ?? ''))) return 0;
  return match[1] === '-' ? -1 : 1;
}
