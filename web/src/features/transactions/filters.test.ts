import { describe, expect, it } from 'vitest';
import {
  countActiveFilters,
  emptyPrivateFilters,
  emptyUrlFilters,
  fromSavedFilter,
  readUrlFilters,
  toListQuery,
  toSavedFilter,
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

describe('saved filters', () => {
  const TAG = '22222222-2222-4222-8222-222222222222';

  it('saves exactly the GET /transactions query, search text and amounts included', () => {
    const url = readUrlFilters(
      new URLSearchParams(`range=this_month&type=expense,refund&account_id=${ACCOUNT}`),
    );
    expect(
      toSavedFilter(url, { q: ' rent ', minAmount: '10.00', maxAmount: '', currency: 'INR' }),
    ).toEqual({
      sort: 'date_desc',
      range: 'this_month',
      type: ['expense', 'refund'],
      account_id: [ACCOUNT],
      q: 'rent',
      currency: 'INR',
      min_amount: '10.00',
    });
  });

  it('has nothing to save for the unfiltered, default-sorted list', () => {
    expect(toSavedFilter(emptyUrlFilters, emptyPrivateFilters)).toBeNull();
    expect(toSavedFilter({ ...emptyUrlFilters, sort: 'amount_desc' }, emptyPrivateFilters)).toEqual(
      {
        sort: 'amount_desc',
      },
    );
  });

  it('round-trips a saved filter', () => {
    const url = readUrlFilters(
      new URLSearchParams(
        `from=2026-11-01&to=2026-11-30&tag_id=${TAG}&payment_method_id=none&sort=amount_asc`,
      ),
    );
    const priv = { q: 'tea', minAmount: '', maxAmount: '99.50', currency: 'USD' };
    const saved = toSavedFilter(url, priv)!;
    const parsed = fromSavedFilter(saved);
    expect(parsed?.partial).toBe(false);
    expect(parsed?.value.url).toEqual(url);
    expect(parsed?.value.priv).toEqual(priv);
  });

  it('applies what it can from a filter another client saved and reports the rest', () => {
    const parsed = fromSavedFilter({
      type: ['expense'],
      account_id: [ACCOUNT, 'not-an-id'],
      reconciliation_state: 'unreconciled',
      include_shared: true,
      some_future_key: 1,
      min_amount: '1e9',
    });
    expect(parsed?.partial).toBe(true);
    expect(parsed?.value.url.types).toEqual(['expense']);
    expect(parsed?.value.url.accountIds).toEqual([ACCOUNT]);
    expect(parsed?.value.priv.minAmount).toBe('');
  });

  it('accepts booleans and comma-separated strings as the web URL writes them', () => {
    const parsed = fromSavedFilter({ uncategorized: true, type: 'expense,income' });
    expect(parsed?.partial).toBe(false);
    expect(parsed?.value.url.uncategorized).toBe(true);
    expect(parsed?.value.url.types).toEqual(['expense', 'income']);
  });

  it('refuses a filter with nothing usable', () => {
    expect(fromSavedFilter({ reconciliation_state: 'matched', nonsense: [1, 2] })).toBeNull();
  });

  it('keeps the no-payment-method drill-down value', () => {
    const url = readUrlFilters(new URLSearchParams('payment_method_id=none'));
    expect(url.paymentMethodId).toBe('none');
    expect(toListQuery(url, emptyPrivateFilters).payment_method_id).toBe('none');
    expect(readUrlFilters(new URLSearchParams('payment_method_id=other')).paymentMethodId).toBe('');
  });
});
