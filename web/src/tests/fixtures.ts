import type { Session, User } from '@/shared/api/types';
import type { Currency } from '@/shared/currency/api';

/** Absolute API base used by tests (jsdom origin is http://localhost:5173). */
export const API = 'http://localhost:5173/api/v1';

let requestCounter = 0;

export function requestId(): string {
  requestCounter += 1;
  return `00000000-0000-4000-8000-${String(requestCounter).padStart(12, '0')}`;
}

export function meta() {
  return { request_id: requestId(), timestamp: '2026-11-04T10:00:00Z' };
}

/** Success envelope `{data, meta}`. */
export function envelope<T>(data: T) {
  return { data, meta: meta() };
}

interface ErrorInit {
  code: string;
  message?: string;
  details?: {
    field?: string;
    message: string;
    code?: string;
    params?: Readonly<Record<string, unknown>>;
  }[];
  request_id?: string;
}

/** Error envelope `{error: {code, message, details, request_id}}`. */
export function errorBody({
  code,
  message = 'Request failed.',
  details = [],
  request_id,
}: ErrorInit) {
  return { error: { code, message, details, request_id: request_id ?? requestId() } };
}

export function makeUser(overrides: Partial<User> = {}): User {
  return {
    id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
    email: 'asha@example.com',
    email_verified: true,
    display_name: 'Asha Rao',
    locale: 'en-IN',
    timezone: 'Asia/Kolkata',
    base_currency: 'INR',
    mfa_enabled: false,
    onboarding_completed: false,
    platform_role: 'user',
    created_at: '2026-10-01T08:30:00Z',
    ...overrides,
  };
}

export function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    id: '3f1c2d4e-5b6a-4c7d-8e9f-0a1b2c3d4e5f',
    client_kind: 'web',
    device_name: 'Firefox on Linux',
    created_at: '2026-11-01T09:00:00Z',
    last_seen_at: '2026-11-04T09:55:00Z',
    mfa_verified: false,
    current: false,
    ...overrides,
  };
}

/** A small slice of GET /currencies, including a retired currency. */
export const testCurrencies: Currency[] = [
  {
    code: 'BGN',
    name: 'Bulgarian Lev',
    exponent: 2,
    selectable: false,
    replaced_by: 'EUR',
    retired_on: '2026-01-01',
  },
  { code: 'EUR', name: 'Euro', exponent: 2, symbol: '€', selectable: true },
  { code: 'GBP', name: 'Pound Sterling', exponent: 2, symbol: '£', selectable: true },
  { code: 'INR', name: 'Indian Rupee', exponent: 2, symbol: '₹', selectable: true },
  { code: 'JPY', name: 'Yen', exponent: 0, symbol: '¥', selectable: true },
  { code: 'KWD', name: 'Kuwaiti Dinar', exponent: 3, selectable: true },
  { code: 'USD', name: 'US Dollar', exponent: 2, symbol: '$', selectable: true },
];
