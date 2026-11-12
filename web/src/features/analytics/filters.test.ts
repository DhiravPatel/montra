import { describe, expect, it } from 'vitest';
import {
  allowedGranularities,
  baseQuery,
  cashFlowQuery,
  comparisonWindow,
  customDays,
  effectiveGranularity,
  previousWindow,
  readAnalyticsFilters,
  shiftYears,
  writeAnalyticsFilters,
} from './filters';

const ACCOUNT = '11111111-1111-4111-8111-111111111111';

describe('analytics URL filters', () => {
  it('reads only dates, IDs, enum values and currency codes', () => {
    const filters = readAnalyticsFilters(
      new URLSearchParams(
        `view=compare&range=custom&from=2026-11-01&to=2026-11-30&account_id=${ACCOUNT}&category_id=not-an-id&pending=1&group=week&display=inr&cmp=custom&compare_from=2026-10-01&compare_to=bad`,
      ),
      'this_month',
    );
    expect(filters).toMatchObject({
      view: 'compare',
      range: 'custom',
      from: '2026-11-01',
      to: '2026-11-30',
      accountId: ACCOUNT,
      categoryId: '',
      includePending: true,
      group: 'week',
      display: '',
      compare: 'custom',
      compareFrom: '2026-10-01',
      compareTo: '',
    });
  });

  it('falls back to the preferred period and treats dates without a range as custom', () => {
    expect(readAnalyticsFilters(new URLSearchParams(''), 'last_30_days').range).toBe(
      'last_30_days',
    );
    expect(readAnalyticsFilters(new URLSearchParams('range=all'), 'this_month').range).toBe(
      'this_month',
    );
    expect(
      readAnalyticsFilters(new URLSearchParams('from=2026-11-01&to=2026-11-07'), 'this_month'),
    ).toMatchObject({ range: 'custom', from: '2026-11-01', to: '2026-11-07' });
  });

  it('writes back a stable, minimal address', () => {
    const filters = readAnalyticsFilters(
      new URLSearchParams(`range=last_month&account_id=${ACCOUNT}&display=USD`),
      'this_month',
    );
    expect(writeAnalyticsFilters(filters).toString()).toBe(
      `range=last_month&account_id=${ACCOUNT}&display=USD`,
    );
  });

  it('builds API queries without empty filters', () => {
    const filters = readAnalyticsFilters(
      new URLSearchParams(`range=this_year&account_id=${ACCOUNT}&group=month&display=EUR`),
      'this_month',
    );
    expect(baseQuery(filters)).toEqual({ range: 'this_year', account_id: [ACCOUNT] });
    expect(cashFlowQuery(filters)).toEqual({
      range: 'this_year',
      account_id: [ACCOUNT],
      granularity: 'month',
      display_currency: 'EUR',
    });
  });
});

describe('chart buckets', () => {
  it('offers only bucket sizes that keep a chart readable for the period', () => {
    expect(allowedGranularities({ range: 'this_month', from: '', to: '' })).toEqual([
      'day',
      'week',
      'month',
      'year',
    ]);
    expect(allowedGranularities({ range: 'this_year', from: '', to: '' })).toEqual([
      'week',
      'month',
      'year',
    ]);
    expect(allowedGranularities({ range: 'custom', from: '2020-01-01', to: '2026-12-31' })).toEqual(
      ['month', 'year'],
    );
  });

  it('lets the API choose when the stored bucket does not suit the period', () => {
    expect(effectiveGranularity({ range: 'this_year', from: '', to: '', group: 'day' })).toBe(
      undefined,
    );
    expect(effectiveGranularity({ range: 'this_year', from: '', to: '', group: 'week' })).toBe(
      'week',
    );
  });

  it('counts calendar days inclusively', () => {
    expect(customDays('2026-11-01', '2026-11-30')).toBe(30);
    expect(customDays('2026-03-28', '2026-03-30')).toBe(3);
    expect(customDays('2026-11-30', '2026-11-01')).toBeNull();
  });
});

describe('comparison periods', () => {
  it('uses the same-length period just before (as the API’s previous period)', () => {
    expect(previousWindow({ from: '2026-11-01', to: '2026-11-30' })).toEqual({
      from: '2026-10-02',
      to: '2026-10-31',
    });
    expect(previousWindow({ from: '2026-01-01', to: '2026-01-07' })).toEqual({
      from: '2025-12-25',
      to: '2025-12-31',
    });
  });

  it('moves dates by a year, keeping 29 February valid', () => {
    expect(shiftYears('2024-02-29', -1)).toBe('2023-02-28');
    expect(shiftYears('2026-11-30', -1)).toBe('2025-11-30');
  });

  it('needs complete, ordered custom dates', () => {
    const current = { from: '2026-11-01', to: '2026-11-30' };
    expect(
      comparisonWindow(current, { compare: 'last_year', compareFrom: '', compareTo: '' }),
    ).toEqual({ from: '2025-11-01', to: '2025-11-30' });
    expect(
      comparisonWindow(current, {
        compare: 'custom',
        compareFrom: '2026-09-30',
        compareTo: '2026-09-01',
      }),
    ).toBeNull();
    expect(
      comparisonWindow(current, {
        compare: 'custom',
        compareFrom: '2026-09-01',
        compareTo: '2026-09-30',
      }),
    ).toEqual({ from: '2026-09-01', to: '2026-09-30' });
  });
});
