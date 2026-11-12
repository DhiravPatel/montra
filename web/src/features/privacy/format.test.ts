import { describe, expect, it } from 'vitest';
import { formatBytes, storageShareBp } from './format';

describe('formatBytes', () => {
  it('uses the largest whole unit with at most one decimal', () => {
    expect(formatBytes(0, 'en-US')).toBe('0 bytes');
    expect(formatBytes(1, 'en-US')).toBe('1 byte');
    expect(formatBytes(1536, 'en-US')).toBe('1.5 kB');
    expect(formatBytes(20_971_520, 'en-US')).toBe('20 MB');
    expect(formatBytes(2_147_483_648, 'en-US')).toBe('2 GB');
    expect(formatBytes(157_286_400, 'en-US')).toBe('150 MB');
  });

  it('treats invalid sizes as zero', () => {
    expect(formatBytes(-5, 'en-US')).toBe('0 bytes');
    expect(formatBytes(Number.NaN, 'en-US')).toBe('0 bytes');
  });
});

describe('storageShareBp', () => {
  it('is the used share of the allowance in basis points', () => {
    expect(storageShareBp(536_870_912, 2_147_483_648)).toBe(2500);
    expect(storageShareBp(3000, 2000)).toBe(15_000);
  });

  it('is zero without a cap or without usage', () => {
    expect(storageShareBp(500, 0)).toBe(0);
    expect(storageShareBp(0, 2000)).toBe(0);
  });
});
