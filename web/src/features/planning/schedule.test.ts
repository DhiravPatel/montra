import { describe, expect, it } from 'vitest';
import { createTranslator } from '@/shared/i18n/translate';
import { makeRule } from '@/tests/planningFixtures';
import { monthRange, shiftMonth } from './calendarMonth';
import {
  describeEnd,
  describeReminders,
  describeSchedule,
  emptySchedule,
  scheduleFromRule,
  toScheduleInput,
} from './schedule';

const en = createTranslator('en', 'en-IN');
const hi = createTranslator('hi', 'hi-IN');

describe('describeSchedule', () => {
  it('describes each kind of schedule in words', () => {
    expect(describeSchedule(makeRule({ by_month_day: 5 }), en, 'en-IN')).toBe(
      'Every month on day 5',
    );
    expect(describeSchedule(makeRule({ by_month_day: -1 }), en, 'en-IN')).toBe(
      'Every month on the last day',
    );
    // No day given: the start date's day.
    expect(
      describeSchedule(
        makeRule({ by_month_day: undefined, start_date: '2026-11-12' }),
        en,
        'en-IN',
      ),
    ).toBe('Every month on day 12');
    expect(
      describeSchedule(
        makeRule({
          frequency: 'quarterly',
          by_month_day: undefined,
          by_weekday: 2,
          by_week_of_month: 2,
        }),
        en,
        'en-IN',
      ),
    ).toBe('Every 3 months on the second Tuesday');
    expect(
      describeSchedule(
        makeRule({ frequency: 'weekly', by_month_day: undefined, start_date: '2026-11-02' }),
        en,
        'en-IN',
      ),
    ).toBe('Every week on Monday');
    expect(
      describeSchedule(
        makeRule({
          frequency: 'custom',
          interval_count: 2,
          interval_unit: 'week',
          by_month_day: undefined,
          by_weekday: 5,
        }),
        en,
        'en-IN',
      ),
    ).toBe('Every 2 weeks on Friday');
    expect(
      describeSchedule(
        makeRule({ frequency: 'yearly', by_month_day: undefined, start_date: '2026-03-05' }),
        en,
        'en-IN',
      ),
    ).toBe('Every year on 5 March');
    expect(
      describeSchedule(
        makeRule({ frequency: 'custom', interval_count: 10, interval_unit: 'day' }),
        en,
        'en-IN',
      ),
    ).toBe('Every 10 days');
  });

  it('describes schedules in Hindi', () => {
    expect(describeSchedule(makeRule({ by_month_day: 5 }), hi, 'hi-IN')).toBe(
      'हर महीने, 5 तारीख को',
    );
    expect(describeReminders([3, 1], hi, 'hi-IN')).toBe('1 दिन पहले और 3 दिन पहले');
  });

  it('describes reminders and ends', () => {
    expect(describeReminders([], en, 'en-IN')).toBe('No reminders');
    expect(describeReminders([0, 7], en, 'en-IN')).toBe('On the day and 7 days before');
    expect(describeEnd(makeRule(), en, 'en-IN')).toBe('No end date');
    expect(describeEnd(makeRule({ max_occurrences: 12 }), en, 'en-IN')).toBe('Ends after 12 times');
    expect(describeEnd(makeRule({ end_date: '2027-03-31' }), en, 'en-IN')).toBe(
      'Ends on 31 Mar 2027',
    );
  });
});

describe('schedule form values', () => {
  it('round-trips a saved schedule into the same request fields', () => {
    const rule = makeRule({
      frequency: 'monthly',
      by_month_day: undefined,
      by_weekday: 1,
      by_week_of_month: -1,
      end_date: '2027-12-31',
      reminder_days_before: [3, 0],
      local_time: '18:30',
    });
    expect(toScheduleInput(scheduleFromRule(rule), rule.timezone)).toEqual({
      frequency: 'monthly',
      by_weekday: 1,
      by_week_of_month: -1,
      start_date: '2026-11-01',
      end_date: '2027-12-31',
      local_time: '18:30',
      reminder_days_before: [0, 3],
      timezone: 'Asia/Kolkata',
    });
  });

  it('only sends the fields that fit the frequency', () => {
    const values = {
      ...emptySchedule('2026-11-05'),
      frequency: 'daily',
      monthDay: '5',
      weekday: '3',
      endMode: 'count' as const,
      maxOccurrences: '30',
      reminders: [],
    };
    expect(toScheduleInput(values)).toEqual({
      frequency: 'daily',
      start_date: '2026-11-05',
      local_time: '09:00',
      reminder_days_before: [],
      max_occurrences: 30,
    });
  });
});

describe('calendar months', () => {
  it('moves across years and knows month lengths', () => {
    expect(shiftMonth('2026-12', 1)).toBe('2027-01');
    expect(shiftMonth('2026-01', -1)).toBe('2025-12');
    expect(monthRange('2028-02')).toEqual({ from: '2028-02-01', to: '2028-02-29' });
    expect(monthRange('2026-11')).toEqual({ from: '2026-11-01', to: '2026-11-30' });
  });
});
