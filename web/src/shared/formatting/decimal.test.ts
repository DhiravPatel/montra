import { describe, expect, it } from 'vitest';
import {
  absDecimal,
  compareDecimal,
  decimalSeparators,
  decimalToInput,
  isZeroDecimal,
  minorToDecimal,
  negateDecimal,
  normalizeDecimalInput,
} from './decimal';

const inr = { exponent: 2 };

describe('normalizeDecimalInput', () => {
  it('pads to the currency exponent without any float conversion', () => {
    expect(normalizeDecimalInput('1234.5', 'en-IN', inr)).toEqual({ ok: true, value: '1234.50' });
    expect(normalizeDecimalInput('7', 'en-IN', inr)).toEqual({ ok: true, value: '7.00' });
    expect(normalizeDecimalInput('.5', 'en-IN', inr)).toEqual({ ok: true, value: '0.50' });
    expect(normalizeDecimalInput('007.10', 'en-IN', inr)).toEqual({ ok: true, value: '7.10' });
  });

  it('keeps every digit of amounts beyond Number precision', () => {
    expect(normalizeDecimalInput('9007199254740.93', 'en-US', inr)).toEqual({
      ok: true,
      value: '9007199254740.93',
    });
  });

  it('accepts western and Indian grouping only when it is unambiguous', () => {
    expect(normalizeDecimalInput('1,23,456.78', 'en-IN', inr)).toEqual({
      ok: true,
      value: '123456.78',
    });
    expect(normalizeDecimalInput('12,345', 'en-US', inr)).toEqual({ ok: true, value: '12345.00' });
    expect(normalizeDecimalInput('12,50', 'en-IN', inr)).toEqual({ ok: false, issue: 'format' });
    expect(normalizeDecimalInput('1234,5', 'en-US', inr)).toEqual({ ok: false, issue: 'format' });
  });

  it('reads comma-decimal locales', () => {
    expect(decimalSeparators('de-DE')).toEqual({ decimal: ',', group: '.' });
    expect(normalizeDecimalInput('1.234,5', 'de-DE', inr)).toEqual({ ok: true, value: '1234.50' });
    expect(normalizeDecimalInput('12,50', 'de-DE', inr)).toEqual({ ok: true, value: '12.50' });
    // A dot not followed by a 3-digit group is read as the decimal point.
    expect(normalizeDecimalInput('12.50', 'de-DE', inr)).toEqual({ ok: true, value: '12.50' });
    expect(normalizeDecimalInput('1 234,50', 'fr-FR', inr)).toEqual({ ok: true, value: '1234.50' });
  });

  it('accepts native digits', () => {
    expect(normalizeDecimalInput('١٢٣٫٤٥', 'ar-EG', inr)).toEqual({ ok: true, value: '123.45' });
  });

  it('rejects more decimal places than the currency has, unless they are zeros', () => {
    expect(normalizeDecimalInput('1.005', 'en-US', inr)).toEqual({ ok: false, issue: 'precision' });
    expect(normalizeDecimalInput('10.500', 'en-US', inr)).toEqual({ ok: true, value: '10.50' });
    expect(normalizeDecimalInput('1500', 'en-US', { exponent: 0 })).toEqual({
      ok: true,
      value: '1500',
    });
    expect(normalizeDecimalInput('1500.5', 'en-US', { exponent: 0 })).toEqual({
      ok: false,
      issue: 'precision',
    });
    expect(normalizeDecimalInput('12.345', 'en-US', { exponent: 3 })).toEqual({
      ok: true,
      value: '12.345',
    });
  });

  it('enforces sign and zero rules', () => {
    expect(normalizeDecimalInput('-25', 'en-US', inr)).toEqual({ ok: false, issue: 'negative' });
    expect(normalizeDecimalInput('-25', 'en-US', { ...inr, allowNegative: true })).toEqual({
      ok: true,
      value: '-25.00',
    });
    expect(normalizeDecimalInput('−25', 'en-US', { ...inr, allowNegative: true })).toEqual({
      ok: true,
      value: '-25.00',
    });
    expect(normalizeDecimalInput('0', 'en-US', inr)).toEqual({ ok: false, issue: 'zero' });
    expect(normalizeDecimalInput('-0.00', 'en-US', { ...inr, allowZero: true })).toEqual({
      ok: true,
      value: '0.00',
    });
  });

  it('rejects amounts above the API maximum (10^15 minor units)', () => {
    expect(normalizeDecimalInput('10000000000000', 'en-US', inr)).toEqual({
      ok: true,
      value: '10000000000000.00',
    });
    expect(normalizeDecimalInput('10000000000000.01', 'en-US', inr)).toEqual({
      ok: false,
      issue: 'tooLarge',
    });
  });

  it.each(['', '   '])('reports empty input %j', (raw) => {
    expect(normalizeDecimalInput(raw, 'en-US', inr)).toEqual({ ok: false, issue: 'empty' });
  });

  it.each(['1e5', 'NaN', 'Infinity', '1.2.3', '--1', 'abc', '-', '12a'])('rejects %j', (raw) => {
    expect(normalizeDecimalInput(raw, 'en-US', inr)).toEqual({ ok: false, issue: 'format' });
  });
});

describe('decimal string helpers', () => {
  it('flips and strips signs without arithmetic', () => {
    expect(negateDecimal('250.00')).toBe('-250.00');
    expect(negateDecimal('-250.00')).toBe('250.00');
    expect(negateDecimal('0.00')).toBe('0.00');
    expect(absDecimal('-2000.00')).toBe('2000.00');
    expect(isZeroDecimal('-0.00')).toBe(true);
    expect(isZeroDecimal('0.01')).toBe(false);
  });

  it('compares exact decimals', () => {
    expect(compareDecimal('100.00', '99.99')).toBe(1);
    expect(compareDecimal('-100.00', '-99.99')).toBe(-1);
    expect(compareDecimal('-1.00', '1.00')).toBe(-1);
    expect(compareDecimal('50000.00', '50000')).toBe(0);
    expect(compareDecimal('0.00', '-0.00')).toBe(0);
  });

  it('converts audit minor units and input text exactly', () => {
    expect(minorToDecimal(123450, 2)).toBe('1234.50');
    expect(minorToDecimal(-5, 2)).toBe('-0.05');
    expect(minorToDecimal(1500, 0)).toBe('1500');
    expect(decimalToInput('1234.50', 'de-DE')).toBe('1234,50');
    expect(decimalToInput('1234.50', 'en-IN')).toBe('1234.50');
  });
});
