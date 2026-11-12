import { describe, expect, it } from 'vitest';
import { formatRate, normalizeRateInput } from './rate';

describe('normalizeRateInput', () => {
  it('keeps the typed digits exactly and drops trailing zeros', () => {
    expect(normalizeRateInput('83.1234', 'en-US')).toEqual({ ok: true, value: '83.1234' });
    expect(normalizeRateInput(' 83.12340 ', 'en-US')).toEqual({ ok: true, value: '83.1234' });
    expect(normalizeRateInput('0.000000000001', 'en-US')).toEqual({
      ok: true,
      value: '0.000000000001',
    });
    expect(normalizeRateInput('.5', 'en-US')).toEqual({ ok: true, value: '0.5' });
    expect(normalizeRateInput('15800', 'en-US')).toEqual({ ok: true, value: '15800' });
    expect(normalizeRateInput('007.10', 'en-US')).toEqual({ ok: true, value: '7.1' });
  });

  it('accepts the comma as the decimal mark where the locale uses it', () => {
    expect(normalizeRateInput('83,1234', 'de-DE')).toEqual({ ok: true, value: '83.1234' });
    expect(normalizeRateInput('83,1234', 'en-US')).toEqual({ ok: false, issue: 'format' });
  });

  it('never guesses a dot where the comma is the decimal mark', () => {
    // "15.800" is 15800 to a German reader: ask for the comma instead of saving 15.8.
    expect(normalizeRateInput('15.800', 'de-DE')).toEqual({ ok: false, issue: 'ambiguous' });
    expect(normalizeRateInput('1.234,5', 'de-DE')).toEqual({ ok: false, issue: 'ambiguous' });
    expect(normalizeRateInput('1.5', 'de-DE')).toEqual({ ok: true, value: '1.5' });
    expect(normalizeRateInput('15800', 'de-DE')).toEqual({ ok: true, value: '15800' });
    expect(normalizeRateInput('15.800', 'en-US')).toEqual({ ok: true, value: '15.8' });
  });

  it('rejects anything that is not a plain positive decimal', () => {
    expect(normalizeRateInput('', 'en-US')).toEqual({ ok: false, issue: 'empty' });
    for (const text of ['-1', '+1', '1e3', '1/3', '1.2.3', '1,000.5', 'abc', '.']) {
      expect(normalizeRateInput(text, 'en-US')).toEqual({ ok: false, issue: 'format' });
    }
    expect(normalizeRateInput('0', 'en-US')).toEqual({ ok: false, issue: 'zero' });
    expect(normalizeRateInput('0.000', 'en-US')).toEqual({ ok: false, issue: 'zero' });
  });

  it('allows at most 12 decimal places (zeros beyond are fine)', () => {
    expect(normalizeRateInput('1.1234567890123', 'en-US')).toEqual({
      ok: false,
      issue: 'precision',
    });
    expect(normalizeRateInput('1.1234567890120', 'en-US')).toEqual({
      ok: true,
      value: '1.123456789012',
    });
  });
});

describe('formatRate', () => {
  it('shows the API’s exact rate without its scale padding', () => {
    expect(formatRate('83.123400000000', 'en-US')).toBe('83.1234');
    expect(formatRate('15800.000000000000', 'en-US')).toBe('15,800');
    expect(formatRate('1234567.5', 'de-DE')).toBe('1.234.567,5');
    expect(formatRate('0.000000000001', 'en-US')).toBe('0.000000000001');
  });

  it('returns anything unexpected unchanged', () => {
    expect(formatRate('n/a', 'en-US')).toBe('n/a');
  });
});
