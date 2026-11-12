import { useId, useState } from 'react';
import { Controller, useFormContext, useWatch } from 'react-hook-form';
import { FieldError, FieldHelp } from '@/shared/components/FieldParts';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { useI18n } from '@/shared/i18n/I18nContext';
import {
  FREQUENCIES,
  INTERVAL_UNITS,
  WEEK_OF_MONTH,
  frequencyLabel,
  intervalUnitLabel,
  weekOfMonthLabel,
} from '../labels';
import {
  type EndMode,
  type MonthAnchor,
  REMINDER_PRESETS,
  type ScheduleValues,
  reminderLabel,
  scheduleFamily,
  weekdayName,
} from '../schedule';

interface ScheduleForm {
  schedule: ScheduleValues;
}

const DAYS = Array.from({ length: 31 }, (_, index) => String(index + 1));
const WEEKDAYS = [0, 1, 2, 3, 4, 5, 6] as const;

/**
 * Schedule fields shared by recurring items and bills: how often, which day,
 * when it starts and ends, the due time and reminders. Render inside a
 * react-hook-form <FormProvider> whose values have a `schedule` object.
 * The API computes the actual dates.
 */
export function RecurrenceFields() {
  const { t, formatLocale } = useI18n();
  const { register, control, getValues, formState } = useFormContext<ScheduleForm>();
  const errors = formState.errors.schedule;
  const [frequency, intervalUnit, monthAnchor, endMode] = useWatch({
    control,
    name: [
      'schedule.frequency',
      'schedule.intervalUnit',
      'schedule.monthAnchor',
      'schedule.endMode',
    ],
  });
  // Keep reminder offsets the record already has (e.g. 2 days) next to the presets.
  const [reminderOptions] = useState(() =>
    [...new Set([...REMINDER_PRESETS, ...getValues('schedule.reminders').map(Number)])]
      .filter((value) => Number.isInteger(value) && value >= 0 && value <= 30)
      .sort((a, b) => a - b),
  );
  const remindersHelpId = useId();
  const remindersErrorId = useId();

  const family = scheduleFamily(frequency, intervalUnit);
  const monthBased = family === 'month' || family === 'year';
  const weekdayOptions = WEEKDAYS.map((day) => ({
    value: String(day),
    label: weekdayName(day, formatLocale),
  }));

  return (
    <fieldset className="space-y-5">
      <legend className="mb-1 text-base font-semibold text-fg">
        {t('schedule.fields.legend')}
      </legend>
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('schedule.fields.frequency')}
          options={FREQUENCIES.map((value) => ({ value, label: t(frequencyLabel[value]) }))}
          error={errors?.frequency?.message}
          {...register('schedule.frequency')}
        />
        <TextField
          label={t('schedule.fields.startDate')}
          type="date"
          help={
            family === 'year'
              ? t('schedule.fields.startHelpYearly')
              : t('schedule.fields.startHelp')
          }
          error={errors?.startDate?.message}
          {...register('schedule.startDate')}
        />
      </div>

      {frequency === 'custom' ? (
        <div className="grid gap-5 sm:grid-cols-2">
          <TextField
            label={t('schedule.fields.interval')}
            inputMode="numeric"
            autoComplete="off"
            maxLength={3}
            error={errors?.intervalCount?.message}
            {...register('schedule.intervalCount')}
          />
          <Select
            label={t('schedule.fields.unit')}
            options={INTERVAL_UNITS.map((value) => ({
              value,
              label: t(intervalUnitLabel[value]),
            }))}
            error={errors?.intervalUnit?.message}
            {...register('schedule.intervalUnit')}
          />
        </div>
      ) : null}

      {family === 'week' ? (
        <Select
          label={t('schedule.fields.weekday')}
          placeholder={t('schedule.fields.weekdaySame')}
          optional
          options={weekdayOptions}
          error={errors?.weekday?.message}
          {...register('schedule.weekday')}
        />
      ) : null}

      {monthBased ? (
        <div className="space-y-5">
          <Controller
            control={control}
            name="schedule.monthAnchor"
            render={({ field }) => (
              <RadioGroup<MonthAnchor>
                legend={t('schedule.fields.monthAnchor')}
                value={field.value}
                onChange={field.onChange}
                options={[
                  { value: 'day', label: t('schedule.fields.anchorDay') },
                  { value: 'weekday', label: t('schedule.fields.anchorWeekday') },
                ]}
              />
            )}
          />
          {monthAnchor === 'weekday' ? (
            <div className="grid gap-5 sm:grid-cols-2">
              <Select
                label={t('schedule.fields.weekOfMonth')}
                options={WEEK_OF_MONTH.map((value) => ({
                  value,
                  label: t(weekOfMonthLabel[value]),
                }))}
                error={errors?.weekOfMonth?.message}
                {...register('schedule.weekOfMonth')}
              />
              <Select
                label={t('schedule.fields.weekday')}
                placeholder={t('schedule.fields.weekdayChoose')}
                options={weekdayOptions}
                error={errors?.weekday?.message}
                {...register('schedule.weekday')}
              />
            </div>
          ) : (
            <Select
              label={t('schedule.fields.monthDay')}
              placeholder={t('schedule.fields.monthDaySame')}
              optional
              options={[
                ...DAYS.map((value) => ({ value, label: value })),
                { value: '-1', label: t('schedule.fields.lastDay') },
              ]}
              help={t('schedule.fields.monthDayHelp')}
              error={errors?.monthDay?.message}
              {...register('schedule.monthDay')}
            />
          )}
        </div>
      ) : null}

      <div className="space-y-5">
        <Controller
          control={control}
          name="schedule.endMode"
          render={({ field }) => (
            <RadioGroup<EndMode>
              legend={t('schedule.fields.end')}
              value={field.value}
              onChange={field.onChange}
              options={[
                { value: 'never', label: t('schedule.fields.endNever') },
                { value: 'date', label: t('schedule.fields.endDate') },
                { value: 'count', label: t('schedule.fields.endCount') },
              ]}
            />
          )}
        />
        {endMode === 'date' ? (
          <TextField
            label={t('schedule.fields.endDateLabel')}
            type="date"
            error={errors?.endDate?.message}
            {...register('schedule.endDate')}
          />
        ) : null}
        {endMode === 'count' ? (
          <TextField
            label={t('schedule.fields.maxOccurrences')}
            inputMode="numeric"
            autoComplete="off"
            maxLength={5}
            help={t('schedule.fields.maxOccurrencesHelp')}
            error={errors?.maxOccurrences?.message}
            {...register('schedule.maxOccurrences')}
          />
        ) : null}
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <TextField
          label={t('schedule.fields.localTime')}
          type="time"
          help={t('schedule.fields.localTimeHelp')}
          error={errors?.localTime?.message}
          {...register('schedule.localTime')}
        />
      </div>

      <fieldset
        className="space-y-2"
        aria-describedby={[remindersHelpId, errors?.reminders ? remindersErrorId : null]
          .filter(Boolean)
          .join(' ')}
      >
        <legend className="mb-1.5 text-sm font-medium text-fg">
          {t('schedule.fields.reminders')}
        </legend>
        <div className="flex flex-wrap gap-x-6 gap-y-2">
          {reminderOptions.map((days) => (
            <label
              key={days}
              className="inline-flex min-h-11 cursor-pointer items-center gap-2 text-sm text-fg"
            >
              <input
                type="checkbox"
                value={String(days)}
                className="size-5 shrink-0 cursor-pointer rounded border-line-strong accent-accent"
                {...register('schedule.reminders')}
              />
              {reminderLabel(days, t)}
            </label>
          ))}
        </div>
        <FieldHelp id={remindersHelpId}>{t('schedule.fields.remindersHelp')}</FieldHelp>
        {errors?.reminders ? (
          <FieldError id={remindersErrorId}>{errors.reminders.message}</FieldError>
        ) : null}
      </fieldset>
    </fieldset>
  );
}
