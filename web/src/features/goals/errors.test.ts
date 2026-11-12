import { describe, expect, it } from 'vitest';
import { ApiError } from '@/shared/api/errors';
import { createTranslator } from '@/shared/i18n/translate';
import { makeForecast } from '@/tests/goalsFixtures';
import { exportFileName } from './download';
import { contributionErrorMessage, goalErrorMessage, isContributionStale } from './errors';
import { forecastAssumptions } from './forecast';

const t = createTranslator('en', 'en-IN');
const hi = createTranslator('hi', 'hi-IN');

function coded(
  code: 'DOMAIN_RULE_VIOLATION' | 'CONFLICT' | 'DUPLICATE',
  detail: string,
  params: Record<string, string> = {},
) {
  const status = code === 'DOMAIN_RULE_VIOLATION' ? 422 : 409;
  return new ApiError({
    status,
    code,
    message: 'English fallback.',
    details: [{ message: 'English fallback.', code: detail, params }],
  });
}

describe('goal error messages', () => {
  it('localizes the owner rules', () => {
    expect(goalErrorMessage(coded('DOMAIN_RULE_VIOLATION', 'owner_role_fixed'), t, 'en-IN')).toBe(
      'The owner’s role can’t change.',
    );
    expect(goalErrorMessage(coded('DOMAIN_RULE_VIOLATION', 'owner_cannot_leave'), t, 'en-IN')).toBe(
      'The owner can’t leave or be removed. Archive the goal instead.',
    );
    expect(
      goalErrorMessage(coded('DOMAIN_RULE_VIOLATION', 'member_controls_visibility'), hi, 'hi-IN'),
    ).toBe('हर व्यक्ति खुद चुनता है कि दूसरे उसके योगदान में से क्या देखें।');
  });

  it('uses the shared status and limit messages', () => {
    expect(
      goalErrorMessage(
        coded('DOMAIN_RULE_VIOLATION', 'invalid_status_transition', {
          from: 'cancelled',
          to: 'paused',
        }),
        t,
        'en-IN',
      ),
    ).toMatch(/^This can’t change from cancelled to paused\./);
    expect(
      goalErrorMessage(
        coded('DOMAIN_RULE_VIOLATION', 'record_limit_reached', {
          resource: 'goals',
          limit: '200',
        }),
        t,
        'en-IN',
      ),
    ).toBe('You can keep up to 200 open goals. Archive goals you no longer need, then try again.');
  });

  it('explains contribution conflicts and marks them for a reload', () => {
    const voided = coded('CONFLICT', 'contribution_voided');
    expect(contributionErrorMessage(voided, t, 'en-IN')).toBe(
      'This contribution was voided, so it can’t be recorded.',
    );
    expect(isContributionStale(voided)).toBe(true);
    const verified = coded('CONFLICT', 'contribution_not_planned', { status: 'verified' });
    expect(contributionErrorMessage(verified, t, 'en-IN')).toBe(
      'This contribution is already recorded and verified. We’ve refreshed the list.',
    );
    const counted = coded('DUPLICATE', 'transaction_already_counted');
    expect(contributionErrorMessage(counted, t, 'en-IN')).toBe(
      'That transaction already counts toward a goal. Choose another one.',
    );
    expect(isContributionStale(counted)).toBe(false);
  });
});

describe('forecast assumptions', () => {
  it('are written from the codes and their values, not the English sentences', () => {
    const forecast = makeForecast({
      assumption_codes: ['recent_pace_window', 'exact_amounts_no_growth'],
      assumption_params: { currency: 'EUR', window_days: '60', months: '2' },
      assumptions: ['Some English text.', 'More English text.'],
    });
    expect(forecastAssumptions(forecast, t)).toEqual([
      {
        text: 'Recent pace is what was recorded or verified in the last 60 days, minus withdrawals, divided by 2.',
      },
      { text: 'Amounts are exact in EUR. No interest, returns or inflation are assumed.' },
    ]);
  });

  it('falls back to the sentences, marked as English, when there are no codes', () => {
    const forecast = makeForecast({ assumption_codes: [], assumptions: ['As sent.'] });
    expect(forecastAssumptions(forecast, t)).toEqual([{ text: 'As sent.', lang: 'en' }]);
  });
});

describe('export file name', () => {
  it('keeps only the neutral server name', () => {
    expect(exportFileName('attachment; filename="goal-contributions-2026-11-04.csv"')).toBe(
      'goal-contributions-2026-11-04.csv',
    );
    expect(exportFileName("attachment; filename*=UTF-8''goal-contributions-2026-11-04.csv")).toBe(
      'goal-contributions-2026-11-04.csv',
    );
    expect(exportFileName('attachment; filename="Goa trip.csv"')).toBeNull();
    expect(exportFileName(null)).toBeNull();
  });
});
