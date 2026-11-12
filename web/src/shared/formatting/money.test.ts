import { describe, expect, it } from 'vitest';
import { amountSign, formatMoney } from './money';

/**
 * Oracle for small values only: Intl formatting of a Number is exact for
 * amounts with few significant digits, so it pins the expected locale
 * layout without hard-coding ICU spacing characters.
 */
function intl(
  value: number,
  currency: string,
  locale: string,
  options: Intl.NumberFormatOptions = {},
): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency, ...options }).format(value);
}

describe('formatMoney', () => {
  it('uses Indian lakh/crore grouping for en-IN', () => {
    expect(formatMoney('12345678.90', 'INR', 'en-IN')).toBe('₹1,23,45,678.90');
    expect(formatMoney('100000', 'INR', 'en-IN')).toBe('₹1,00,000.00');
  });

  it('formats two-decimal currencies and pads missing minor digits', () => {
    expect(formatMoney('1234.5', 'USD', 'en-US')).toBe('$1,234.50');
    expect(formatMoney('7', 'USD', 'en-US')).toBe('$7.00');
  });

  it('formats zero-decimal currencies without a fraction', () => {
    expect(formatMoney('1500', 'JPY', 'en-US')).toBe('¥1,500');
    expect(formatMoney('1500', 'JPY', 'en-US')).toBe(intl(1500, 'JPY', 'en-US'));
  });

  it('formats three-decimal currencies exactly', () => {
    expect(formatMoney('12.345', 'KWD', 'en-US')).toBe(intl(12.345, 'KWD', 'en-US'));
    expect(formatMoney('0.005', 'BHD', 'en-US')).toBe(intl(0.005, 'BHD', 'en-US'));
  });

  it('keeps every digit of amounts beyond Number precision', () => {
    // 2^53 + 1 would round as a float; the exact string must survive.
    expect(formatMoney('9007199254740993.01', 'USD', 'en-US')).toBe('$9,007,199,254,740,993.01');
    expect(formatMoney('90071992547409931.23', 'INR', 'en-IN')).toBe(
      '₹90,07,19,92,54,74,09,931.23',
    );
  });

  it('never rounds digits the API sent', () => {
    expect(formatMoney('1.005', 'USD', 'en-US')).toBe('$1.005');
    expect(formatMoney('0.10', 'EUR', 'en-US')).toBe('€0.10');
  });

  it('pads to the exponent from GET /currencies when given (CLDR and ISO can differ)', () => {
    // CLDR shows IQD with 0 digits; the API registry uses the ISO exponent 3.
    expect(formatMoney('1', 'IQD', 'en-US', { minorDigits: 3, currencyDisplay: 'code' })).toBe(
      intl(1, 'IQD', 'en-US', {
        currencyDisplay: 'code',
        minimumFractionDigits: 3,
        maximumFractionDigits: 3,
      }),
    );
    expect(formatMoney('1.500', 'IQD', 'en-US', { currencyDisplay: 'code' })).toContain('1.500');
  });

  it('places the sign the way the locale does', () => {
    expect(formatMoney('-1234.56', 'USD', 'en-US')).toBe(intl(-1234.56, 'USD', 'en-US'));
    expect(formatMoney('-1234.56', 'EUR', 'de-DE')).toBe(intl(-1234.56, 'EUR', 'de-DE'));
    expect(formatMoney('+5.00', 'USD', 'en-US')).toBe('$5.00');
  });

  it('supports accounting negatives and explicit sign display', () => {
    expect(formatMoney('-5.00', 'USD', 'en-US', { accounting: true })).toBe('($5.00)');
    expect(formatMoney('5.00', 'USD', 'en-US', { signDisplay: 'always' })).toBe('+$5.00');
    expect(formatMoney('0.00', 'USD', 'en-US', { signDisplay: 'exceptZero' })).toBe('$0.00');
  });

  it('never shows a negative zero', () => {
    expect(formatMoney('-0.00', 'USD', 'en-US')).toBe('$0.00');
    expect(formatMoney('-0', 'JPY', 'en-US')).toBe('¥0');
  });

  it('uses locale separators and native digits', () => {
    expect(formatMoney('1234.56', 'EUR', 'de-DE')).toBe(intl(1234.56, 'EUR', 'de-DE'));
    expect(formatMoney('1234567.89', 'INR', 'hi-IN')).toBe(intl(1234567.89, 'INR', 'hi-IN'));
    expect(formatMoney('1234.56', 'EGP', 'ar-EG')).toBe(intl(1234.56, 'EGP', 'ar-EG'));
  });

  it('supports other currency displays', () => {
    expect(formatMoney('10', 'INR', 'en-IN', { currencyDisplay: 'code' })).toBe(
      intl(10, 'INR', 'en-IN', { currencyDisplay: 'code' }),
    );
  });

  it.each(['', '1e5', 'NaN', 'Infinity', '1.2.3', ' 1', '1,000', '.5', '5.', '--1', '١٢'])(
    'rejects non-decimal amount %j',
    (amount) => {
      expect(() => formatMoney(amount, 'USD', 'en-US')).toThrow(RangeError);
    },
  );

  it('rejects malformed currency codes', () => {
    expect(() => formatMoney('1.00', 'usd', 'en-US')).toThrow(RangeError);
    expect(() => formatMoney('1.00', 'US', 'en-US')).toThrow(RangeError);
  });

  it('does not leak the amount in error messages', () => {
    expect(() => formatMoney('12345abc', 'USD', 'en-US')).toThrow(/^(?!.*12345).*$/);
  });
});

describe('amountSign', () => {
  it('reads the sign of exact decimals', () => {
    expect(amountSign('-0.01')).toBe(-1);
    expect(amountSign('-0.00')).toBe(0);
    expect(amountSign('0')).toBe(0);
    expect(amountSign('42.10')).toBe(1);
    expect(amountSign('abc')).toBeNull();
  });
});
