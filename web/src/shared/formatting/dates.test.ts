import { describe, expect, it } from 'vitest';
import {
  addDaysToLocalDate,
  formatBasisPoints,
  formatLocalDate,
  formatLocalDateRange,
  isLocalDate,
  todayInTimeZone,
} from './dates';

describe('calendar dates', () => {
  it('validates YYYY-MM-DD strictly', () => {
    expect(isLocalDate('2026-11-04')).toBe(true);
    expect(isLocalDate('2026-02-30')).toBe(false);
    expect(isLocalDate('04/11/2026')).toBe(false);
  });

  it('formats a calendar day without shifting it to a neighbouring day', () => {
    expect(formatLocalDate('2026-11-01', 'en-US', 'long')).toBe('November 1, 2026');
    expect(formatLocalDate('2026-11-30', 'en-IN', 'long')).toBe('30 November 2026');
    expect(formatLocalDate('not-a-date', 'en-US')).toBe('not-a-date');
  });

  it('formats ranges', () => {
    // ICU puts thin spaces around the dash.
    expect(formatLocalDateRange('2026-11-01', '2026-11-30', 'en-US')).toMatch(
      /^Nov 1\s–\s30, 2026$/,
    );
    expect(formatLocalDateRange('2026-11-04', '2026-11-04', 'en-US')).toBe('Nov 4, 2026');
  });

  it('finds today in a time zone and does calendar arithmetic', () => {
    const instant = new Date('2026-11-04T20:00:00Z'); // already the 5th in India
    expect(todayInTimeZone('Asia/Kolkata', instant)).toBe('2026-11-05');
    expect(todayInTimeZone('America/New_York', instant)).toBe('2026-11-04');
    expect(addDaysToLocalDate('2026-03-01', -1)).toBe('2026-02-28');
    expect(addDaysToLocalDate('2026-12-31', 1)).toBe('2027-01-01');
  });

  it('formats basis points as percentages', () => {
    expect(formatBasisPoints(9479, 'en-US')).toBe('94.8%');
    expect(formatBasisPoints(10000, 'en-US')).toBe('100%');
  });
});
