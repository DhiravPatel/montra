import type { Conversion, StoredRate } from '@/features/fx/types';
import { money } from './financeFixtures';

/** Exchange-rate fixtures shaped like the contract (tests only). */

export const RATE_MINE = 'eeeeeeee-1111-4111-8111-000000000001';
export const RATE_ECB = 'eeeeeeee-1111-4111-8111-000000000002';

/** Your manual USD→INR rate, as the API lists it (numeric text with its scale). */
export function makeManualRate(overrides: Partial<StoredRate> = {}): StoredRate {
  return {
    id: RATE_MINE,
    base: 'USD',
    quote: 'INR',
    rate: '83.1234',
    source: 'manual',
    as_of: '2026-11-01T12:00:00Z',
    mine: true,
    created_at: '2026-11-04T08:00:00Z',
    ...overrides,
  };
}

/** A provider (ECB) EUR→INR rate: not yours, so it cannot be deleted. */
export function makeProviderRate(overrides: Partial<StoredRate> = {}): StoredRate {
  return {
    id: RATE_ECB,
    base: 'EUR',
    quote: 'INR',
    rate: '89.500000000000',
    source: 'ecb',
    as_of: '2026-11-03T16:00:00Z',
    mine: false,
    created_at: '2026-11-03T16:05:00Z',
    ...overrides,
  };
}

export function makeConversion(overrides: Partial<Conversion> = {}): Conversion {
  return {
    from: money('10.50', 'USD'),
    to: money('872.80', 'INR'),
    rate: {
      base: 'USD',
      quote: 'INR',
      rate: '83.1234',
      source: 'manual',
      as_of: '2026-11-01T12:00:00Z',
      inverted: false,
    },
    policy: 'current',
    rounding_delta: '-0.43',
    ...overrides,
  };
}
