import { z } from 'zod';
import { formatLocalDate, isLocalDate, parseLocalDate } from '@/shared/formatting/dates';
import type { RecurringRule, RecurringRuleInput } from '@/shared/finance/types';
import type { Translate } from '@/shared/i18n/types';
import { isFrequency, isIntervalUnit, isWeekOfMonth, weekOfMonthInSentence } from './labels';

/*
 * Schedules shared by recurring rules and bills (same contract fields). The
 * form keeps everything as strings; toScheduleInput() builds the request.
 * Occurrence dates are computed by the API only.
 */

export type ScheduleInput = Pick<
  RecurringRuleInput,
  | 'frequency'
  | 'interval_count'
  | 'interval_unit'
  | 'by_month_day'
  | 'by_weekday'
  | 'by_week_of_month'
  | 'start_date'
  | 'end_date'
  | 'max_occurrences'
  | 'local_time'
  | 'reminder_days_before'
  | 'timezone'
>;

export type ScheduleLike = Pick<
  RecurringRule,
  | 'frequency'
  | 'interval_count'
  | 'interval_unit'
  | 'by_month_day'
  | 'by_weekday'
  | 'by_week_of_month'
  | 'start_date'
>;

export type EndMode = 'never' | 'date' | 'count';
export type MonthAnchor = 'day' | 'weekday';

export interface ScheduleValues {
  frequency: string;
  /** Custom frequency: every N units. */
  intervalCount: string;
  intervalUnit: string;
  /** Month-based schedules: a day of the month or "the nth weekday". */
  monthAnchor: MonthAnchor;
  /** '' = same day as the start date, '-1' = last day, '1'..'31'. */
  monthDay: string;
  /** '' = same weekday as the start date (week-based), '0' (Sunday)..'6'. */
  weekday: string;
  /** '1'..'5' or '-1' (last), with a weekday. */
  weekOfMonth: string;
  startDate: string;
  endMode: EndMode;
  endDate: string;
  maxOccurrences: string;
  /** HH:MM local due time. */
  localTime: string;
  /** Days before the due date, as strings (checkbox values). */
  reminders: string[];
}

export const REMINDER_PRESETS = [0, 1, 3, 7] as const;
const MAX_REMINDERS = 5;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const WHOLE = /^\d+$/;

export type ScheduleFamily = 'day' | 'week' | 'month' | 'year';

/** How a frequency repeats: by days, weeks, months or years. */
export function scheduleFamily(frequency: string, unit: string | undefined): ScheduleFamily {
  switch (frequency) {
    case 'daily':
      return 'day';
    case 'weekly':
    case 'biweekly':
      return 'week';
    case 'yearly':
      return 'year';
    case 'custom':
      return unit === 'day' || unit === 'week' || unit === 'year' ? unit : 'month';
    default:
      return 'month';
  }
}

export function emptySchedule(startDate: string): ScheduleValues {
  return {
    frequency: 'monthly',
    intervalCount: '1',
    intervalUnit: 'month',
    monthAnchor: 'day',
    monthDay: '',
    weekday: '',
    weekOfMonth: '1',
    startDate,
    endMode: 'never',
    endDate: '',
    maxOccurrences: '',
    localTime: '09:00',
    reminders: ['1'],
  };
}

/** Form values for an existing schedule (rule or bill). */
export function scheduleFromRule(rule: RecurringRule): ScheduleValues {
  const nthWeekday = rule.by_week_of_month !== undefined && rule.by_week_of_month !== 0;
  return {
    frequency: isFrequency(rule.frequency) ? rule.frequency : '',
    intervalCount: String(Math.max(rule.interval_count, 1)),
    intervalUnit:
      rule.interval_unit && isIntervalUnit(rule.interval_unit) ? rule.interval_unit : 'month',
    monthAnchor: nthWeekday ? 'weekday' : 'day',
    monthDay: rule.by_month_day ? String(rule.by_month_day) : '',
    weekday: rule.by_weekday !== undefined ? String(rule.by_weekday) : '',
    weekOfMonth: nthWeekday ? String(rule.by_week_of_month) : '1',
    startDate: rule.start_date,
    endMode: rule.end_date ? 'date' : rule.max_occurrences ? 'count' : 'never',
    endDate: rule.end_date ?? '',
    maxOccurrences: rule.max_occurrences ? String(rule.max_occurrences) : '',
    localTime: rule.local_time || '09:00',
    reminders: rule.reminder_days_before.map(String),
  };
}

function wholeNumber(value: string): number | null {
  return WHOLE.test(value.trim()) ? Number(value.trim()) : null;
}

/** Validation for ScheduleValues (nest it under `schedule` in a form schema). */
export function scheduleSchema(t: Translate) {
  return z
    .object({
      frequency: z.string(),
      intervalCount: z.string(),
      intervalUnit: z.string(),
      monthAnchor: z.enum(['day', 'weekday']),
      monthDay: z.string(),
      weekday: z.string(),
      weekOfMonth: z.string(),
      startDate: z.string(),
      endMode: z.enum(['never', 'date', 'count']),
      endDate: z.string(),
      maxOccurrences: z.string(),
      localTime: z.string(),
      reminders: z.array(z.string()),
    })
    .superRefine((values, ctx) => {
      const issue = (path: keyof ScheduleValues, message: string) => {
        ctx.addIssue({ code: 'custom', path: [path], message });
      };
      if (!isFrequency(values.frequency)) {
        issue('frequency', t('schedule.errors.frequencyRequired'));
        return;
      }
      if (values.frequency === 'custom') {
        const count = wholeNumber(values.intervalCount);
        if (count === null || count < 1 || count > 366) {
          issue('intervalCount', t('schedule.errors.intervalInvalid'));
        }
        if (!isIntervalUnit(values.intervalUnit)) {
          issue('intervalUnit', t('schedule.errors.unitRequired'));
        }
      }
      const family = scheduleFamily(values.frequency, values.intervalUnit);
      const monthBased = family === 'month' || family === 'year';
      if (monthBased && values.monthAnchor === 'weekday') {
        if (values.weekday === '') issue('weekday', t('schedule.errors.weekdayRequired'));
        if (!isWeekOfMonth(values.weekOfMonth)) {
          issue('weekOfMonth', t('schedule.errors.weekRequired'));
        }
      }
      if (!isLocalDate(values.startDate)) {
        issue('startDate', t('schedule.errors.startRequired'));
      }
      if (values.endMode === 'date') {
        if (!isLocalDate(values.endDate)) {
          issue('endDate', t('schedule.errors.endDateRequired'));
        } else if (isLocalDate(values.startDate) && values.endDate < values.startDate) {
          issue('endDate', t('schedule.errors.endBeforeStart'));
        }
      }
      if (values.endMode === 'count') {
        const count = wholeNumber(values.maxOccurrences);
        if (count === null || count < 1 || count > 10_000) {
          issue('maxOccurrences', t('schedule.errors.countInvalid'));
        }
      }
      if (values.localTime && !TIME.test(values.localTime)) {
        issue('localTime', t('schedule.errors.timeInvalid'));
      }
      if (values.reminders.length > MAX_REMINDERS) {
        issue('reminders', t('schedule.errors.tooManyReminders', { max: MAX_REMINDERS }));
      }
    });
}

/**
 * The request fields for a validated schedule. `timezone` keeps an existing
 * rule's zone when editing (new schedules use the profile time zone).
 */
export function toScheduleInput(values: ScheduleValues, timezone?: string): ScheduleInput {
  if (!isFrequency(values.frequency)) throw new Error('toScheduleInput: invalid frequency');
  const custom = values.frequency === 'custom';
  const unit = isIntervalUnit(values.intervalUnit) ? values.intervalUnit : 'month';
  const family = scheduleFamily(values.frequency, unit);
  const input: ScheduleInput = {
    frequency: values.frequency,
    start_date: values.startDate,
    local_time: values.localTime || '09:00',
    reminder_days_before: [...new Set(values.reminders.map(Number))].sort((a, b) => a - b),
  };
  if (custom) {
    input.interval_count = Number(values.intervalCount.trim());
    input.interval_unit = unit;
  }
  if (family === 'week' && values.weekday !== '') {
    input.by_weekday = Number(values.weekday);
  }
  if (family === 'month' || family === 'year') {
    if (values.monthAnchor === 'weekday') {
      input.by_weekday = Number(values.weekday);
      input.by_week_of_month = Number(values.weekOfMonth);
    } else if (values.monthDay !== '') {
      input.by_month_day = Number(values.monthDay);
    }
  }
  if (values.endMode === 'date') input.end_date = values.endDate;
  if (values.endMode === 'count') input.max_occurrences = Number(values.maxOccurrences.trim());
  if (timezone) input.timezone = timezone;
  return input;
}

// 1 November 2026 is a Sunday; the API counts weekdays from Sunday = 0.
const SUNDAY = Date.UTC(2026, 10, 1);
const DAY_MS = 86_400_000;

export function weekdayName(index: number, locale: string): string {
  return new Intl.DateTimeFormat(locale, { weekday: 'long', timeZone: 'UTC' }).format(
    new Date(SUNDAY + index * DAY_MS),
  );
}

function monthName(month: number, locale: string): string {
  return new Intl.DateTimeFormat(locale, { month: 'long', timeZone: 'UTC' }).format(
    new Date(Date.UTC(2024, month, 1)),
  );
}

function dayAndMonth(day: number, month: number, locale: string): string {
  // 2024 is a leap year, so 29 February can be named.
  return new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'long', timeZone: 'UTC' }).format(
    new Date(Date.UTC(2024, month, day)),
  );
}

function cadence(schedule: ScheduleLike, t: Translate): string {
  switch (schedule.frequency) {
    case 'daily':
      return t('schedule.every.day', { count: 1 });
    case 'weekly':
      return t('schedule.every.week', { count: 1 });
    case 'biweekly':
      return t('schedule.every.week', { count: 2 });
    case 'monthly':
      return t('schedule.every.month', { count: 1 });
    case 'bimonthly':
      return t('schedule.every.month', { count: 2 });
    case 'quarterly':
      return t('schedule.every.month', { count: 3 });
    case 'semiannual':
      return t('schedule.every.month', { count: 6 });
    case 'yearly':
      return t('schedule.every.year', { count: 1 });
  }
  const count = Math.max(schedule.interval_count, 1);
  switch (schedule.interval_unit) {
    case 'day':
      return t('schedule.every.day', { count });
    case 'week':
      return t('schedule.every.week', { count });
    case 'year':
      return t('schedule.every.year', { count });
    default:
      return t('schedule.every.month', { count });
  }
}

/** "Every month on day 5", "Every 2 weeks on Monday", "Every year on 5 March". */
export function describeSchedule(schedule: ScheduleLike, t: Translate, locale: string): string {
  const every = cadence(schedule, t);
  const start = parseLocalDate(schedule.start_date);
  const family = scheduleFamily(schedule.frequency, schedule.interval_unit);
  if (family === 'day' || !start) return every;
  if (family === 'week') {
    const weekday = weekdayName(schedule.by_weekday ?? start.getUTCDay(), locale);
    return t('schedule.describe.weekday', { cadence: every, weekday });
  }
  const nth = schedule.by_week_of_month ? String(schedule.by_week_of_month) : '';
  if (nth && isWeekOfMonth(nth) && schedule.by_weekday !== undefined) {
    const params = {
      cadence: every,
      nth: t(weekOfMonthInSentence[nth]),
      weekday: weekdayName(schedule.by_weekday, locale),
    };
    return family === 'year'
      ? t('schedule.describe.yearNthWeekday', {
          ...params,
          month: monthName(start.getUTCMonth(), locale),
        })
      : t('schedule.describe.nthWeekday', params);
  }
  if (schedule.by_month_day === -1) {
    return family === 'year'
      ? t('schedule.describe.yearLastDay', {
          cadence: every,
          month: monthName(start.getUTCMonth(), locale),
        })
      : t('schedule.describe.lastDay', { cadence: every });
  }
  // 0 or no value: the start date's day.
  const day =
    schedule.by_month_day !== undefined && schedule.by_month_day > 0
      ? schedule.by_month_day
      : start.getUTCDate();
  return family === 'year'
    ? t('schedule.describe.yearDate', {
        cadence: every,
        date: dayAndMonth(day, start.getUTCMonth(), locale),
      })
    : t('schedule.describe.monthDay', { cadence: every, day });
}

export function reminderLabel(days: number, t: Translate): string {
  return days === 0
    ? t('schedule.reminder.sameDay')
    : t('schedule.reminder.daysBefore', { count: days });
}

/** "1 day before and 3 days before", or "No reminders". */
export function describeReminders(days: readonly number[], t: Translate, locale: string): string {
  const sorted = [...new Set(days)].sort((a, b) => a - b);
  if (sorted.length === 0) return t('schedule.reminders.none');
  return new Intl.ListFormat(locale, { type: 'conjunction' }).format(
    sorted.map((value) => reminderLabel(value, t)),
  );
}

/** "Ends on 31 Mar 2027", "Ends after 12 times" or "No end date". */
export function describeEnd(
  schedule: Pick<RecurringRule, 'end_date' | 'max_occurrences'>,
  t: Translate,
  locale: string,
): string {
  if (schedule.end_date) {
    return t('schedule.ends.on', { date: formatLocalDate(schedule.end_date, locale) });
  }
  if (schedule.max_occurrences) {
    return t('schedule.ends.after', { count: schedule.max_occurrences });
  }
  return t('schedule.ends.never');
}
