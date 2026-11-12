import { describe, expect, it } from 'vitest';
import {
  countActiveFilters,
  emptyPrivateFilters,
  emptyUrlFilters,
  readUrlFilters,
  toListQuery,
  writeUrlFilters,
} from './filters';

const CATEGORY = '44444444-4444-4444-8444-444444444401';
const ACCOUNT = '11111111-1111-4111-8111-111111111111';

describe('transaction filters', () => {
  it('reads dashboard drill-down links as a custom period', () => {
    const url = readUrlFilters(
      new URLSearchParams(`from=2026-11-01&to=2026-11-30&category_id=${CATEGORY}`),
    );
    expect(url.range).toBe('custom');
    expect(url.from).toBe('2026-11-01');
    expect(url.categoryIds).toEqual([CATEGORY]);
  });

  it('drops invalid values instead of sending them to the API', () => {
    const url = readUrlFilters(
      new URLSearchParams(
        'type=expense,nonsense&account_id=not-an-id&status=weird&sort=x&range=forever',
      ),
    );
    expect(url.types).toEqual(['expense']);
    expect(url.accountIds).toEqual([]);
    expect(url.status).toBe('');
    expect(url.sort).toBe('date_desc');
    expect(url.range).toBe('all');
  });

  it('round-trips through the URL and keeps the custom choice while dates are empty', () => {
    const filters = {
      ...emptyUrlFilters,
      range: 'custom' as const,
      types: ['expense' as const],
      accountIds: [ACCOUNT],
    };
    const params = writeUrlFilters(filters);
    expect(params.toString()).toBe(`range=custom&type=expense&account_id=${ACCOUNT}`);
    expect(readUrlFilters(params).range).toBe('custom');
  });

  it('never puts search text or amounts in the URL, but sends them to the API', () => {
    const url = { ...emptyUrlFilters, range: 'this_month' as const };
    const priv = { q: 'pharmacy', minAmount: '100.00', maxAmount: '', currency: 'INR' };
    expect(writeUrlFilters(url).toString()).toBe('range=this_month');
    expect(toListQuery(url, priv)).toEqual({
      sort: 'date_desc',
      range: 'this_month',
      q: 'pharmacy',
      currency: 'INR',
      min_amount: '100.00',
    });
  });

  it('counts active filters', () => {
    expect(countActiveFilters(emptyUrlFilters, emptyPrivateFilters)).toBe(0);
    expect(
      countActiveFilters(
        { ...emptyUrlFilters, types: ['income'], direction: 'inflow' },
        { ...emptyPrivateFilters, maxAmount: '5.00' },
      ),
    ).toBe(3);
  });
});
