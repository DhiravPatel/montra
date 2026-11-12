import { describe, expect, it } from 'vitest';
import { ApiError } from '@/shared/api/errors';
import { createTranslator } from '@/shared/i18n/translate';
import { fieldIssueMessage } from './domainErrors';
import { applyCodedServerErrors } from './fieldErrors';
import { dailyCap, rateLimitMessage, retryAt } from './rateLimit';

const t = createTranslator('en', 'en-IN');
const hi = createTranslator('hi', 'hi-IN');

describe('fieldIssueMessage', () => {
  it('words generic field codes with their limits in the interface language', () => {
    expect(
      fieldIssueMessage({ message: 'too long', code: 'too_long', params: { max: '80' } }, t),
    ).toBe('Use 80 characters or fewer.');
    expect(
      fieldIssueMessage({ message: 'too short', code: 'too_short', params: { min: '1' } }, t),
    ).toBe('Use at least 1 character.');
    expect(fieldIssueMessage({ message: 'x', code: 'required' }, t)).toBe('This is required.');
    expect(
      fieldIssueMessage(
        { message: 'x', code: 'invalid_choice', params: { allowed: ['csv', 'pdf'] } },
        t,
      ),
    ).toBe('Choose one of: csv, pdf.');
    expect(
      fieldIssueMessage({ message: 'x', code: 'invalid_topic', params: { index: '0' } }, t),
    ).toBe('Topic 1 can’t be used.');
    expect(fieldIssueMessage({ message: 'x', code: 'contains_secret' }, hi)).not.toBe('x');
  });

  it('keeps the server’s message for unknown codes and missing values', () => {
    expect(fieldIssueMessage({ message: 'Server says no.', code: 'brand_new' }, t)).toBe(
      'Server says no.',
    );
    expect(fieldIssueMessage({ message: 'Server says no.' }, t)).toBe('Server says no.');
    expect(fieldIssueMessage({ message: 'Too long.', code: 'too_long' }, t)).toBe('Too long.');
  });

  it('attaches coded details to form fields and returns the rest', () => {
    const error = new ApiError({
      status: 422,
      code: 'VALIDATION_ERROR',
      message: 'Invalid.',
      details: [
        { field: 'body.title', message: 'too long', code: 'too_long', params: { max: '160' } },
        { field: 'body.other', message: 'x', code: 'required' },
      ],
    });
    const set: Record<string, string> = {};
    const rest = applyCodedServerErrors<{ title: string }>(
      error,
      (name, value) => {
        set[name] = value.message ?? '';
      },
      { title: 'title' },
      t,
    );
    expect(set).toEqual({ title: 'Use 160 characters or fewer.' });
    expect(rest).toEqual(['This is required.']);
  });
});

describe('daily caps (429 RATE_LIMITED)', () => {
  const now = Date.parse('2026-11-06T10:00:00Z');
  const capped = (params: Record<string, string>, retryAfterSeconds: number | null = 3600) =>
    new ApiError({
      status: 429,
      code: 'RATE_LIMITED',
      message: 'Daily limit reached.',
      details: [{ message: 'Daily limit reached.', code: 'daily_cap', params }],
      retryAfterSeconds,
    });

  it('reads the cap and the time of the next try', () => {
    const error = capped({
      resource: 'support_requests',
      limit: '10',
      retry_at: '2026-11-07T00:00:00Z',
    });
    expect(dailyCap(error, now)).toEqual({
      resource: 'support_requests',
      limit: 10,
      retryAt: new Date('2026-11-07T00:00:00Z'),
      windowHours: null,
    });
    expect(rateLimitMessage(error, t, 'en-IN', 'UTC', now)).toMatch(
      /^You’ve reached today’s limit of 10\. You can try again at .*7 Nov 2026/,
    );
  });

  it('falls back to Retry-After, and to the generic sentence without a cap', () => {
    const error = capped({ kind: 'post', limit: '20' });
    expect(retryAt(error, now)).toEqual(new Date(now + 3_600_000));
    const plain = new ApiError({
      status: 429,
      code: 'RATE_LIMITED',
      message: 'Slow down.',
      retryAfterSeconds: 30,
    });
    expect(rateLimitMessage(plain, t, 'en-IN', 'UTC', now)).toMatch(/You can try again at/);
    expect(
      rateLimitMessage(new ApiError({ status: 404, code: 'NOT_FOUND', message: 'x' }), t, 'en'),
    ).toBeNull();
  });
});
