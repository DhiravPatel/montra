import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatLocalDate, isLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { challengesApi } from '../api';
import { challengeErrorMessage } from '../errors';
import { NOTE_MAX, PERCENT_MAX, TARGET_MAX } from '../formValues';
import { challengeChanged } from '../hooks';
import { checkInWindow, percentText, progressText } from '../progress';
import type { Challenge, ChallengeParticipation, ChallengeProgressInput } from '../types';

interface CheckInValues {
  date: string;
  /** days and streak challenges: "1" done, "0" not done (corrects a day). */
  done: '1' | '0';
  /** milestones (a count for the day) and percent (your progress now). */
  amount: string;
  note: string;
}

function buildSchema(
  t: Translate,
  challenge: Challenge,
  first: string,
  last: string,
  locale: string,
) {
  const max = challenge.metric === 'percent' ? PERCENT_MAX : TARGET_MAX;
  return z
    .object({
      date: z.string(),
      done: z.enum(['1', '0']),
      amount: z.string(),
      note: z.string().max(NOTE_MAX, { error: t('validation.maxLength', { max: NOTE_MAX }) }),
    })
    .superRefine((values, ctx) => {
      if (!values.date) {
        ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateRequired') });
      } else if (!isLocalDate(values.date)) {
        ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateInvalid') });
      } else if (values.date < first || values.date > last) {
        ctx.addIssue({
          code: 'custom',
          path: ['date'],
          message: t('challenges.checkIn.dateOutside', {
            first: formatLocalDate(first, locale),
            last: formatLocalDate(last, locale),
          }),
        });
      }
      if (challenge.metric === 'milestones' || challenge.metric === 'percent') {
        const text = values.amount.trim();
        if (!/^\d{1,4}$/.test(text) || Number(text) > max) {
          ctx.addIssue({
            code: 'custom',
            path: ['amount'],
            message: t('challenges.checkIn.amountInvalid', { max }),
          });
        }
      }
    });
}

function toProgressInput(challenge: Challenge, values: CheckInValues): ChallengeProgressInput {
  const value =
    challenge.metric === 'milestones' || challenge.metric === 'percent'
      ? Number(values.amount.trim())
      : Number(values.done);
  const note = values.note.trim();
  return { date: values.date, value, ...(note ? { note } : {}) };
}

/**
 * Check in for a day (POST /challenges/{id}/progress). Sending a day again
 * corrects it; notes stay private to you.
 */
export function CheckInCard({
  challenge,
  me,
  today,
}: {
  challenge: Challenge;
  me: ChallengeParticipation;
  today: string;
}) {
  const { t, formatLocale } = useI18n();
  const days = checkInWindow(challenge, today);
  return (
    <Card title={t('challenges.checkIn.title')} description={t('challenges.checkIn.description')}>
      {days.open ? (
        <CheckInForm challenge={challenge} me={me} first={days.first} last={days.last} />
      ) : (
        <p className="text-sm text-fg-muted">
          {t('challenges.checkIn.notStarted', {
            date: formatLocalDate(challenge.starts_on, formatLocale),
          })}
        </p>
      )}
    </Card>
  );
}

function CheckInForm({
  challenge,
  me,
  first,
  last,
}: {
  challenge: Challenge;
  me: ChallengeParticipation;
  first: string;
  last: string;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () => buildSchema(t, challenge, first, last, formatLocale),
    [t, challenge, first, last, formatLocale],
  );
  const form = useForm<CheckInValues, unknown, CheckInValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      date: last,
      done: '1',
      amount: challenge.metric === 'percent' ? String(me.progress_value) : '1',
      note: '',
    },
  });
  const record = useMutation({
    mutationFn: (body: ChallengeProgressInput) => challengesApi.recordProgress(challenge.id, body),
  });

  const onValid = form.handleSubmit(async (values) => {
    if (record.isPending) return;
    setFormError(null);
    try {
      const updated = await record.mutateAsync(toProgressInput(challenge, values));
      void challengeChanged(queryClient, updated);
      const after = updated.me;
      const reached = me.status !== 'completed' && after?.status === 'completed';
      toast.show({
        tone: 'success',
        title: reached ? t('challenges.checkIn.reached') : t('challenges.checkIn.saved'),
        ...(after
          ? { description: `${progressText(updated, after, t)} (${percentText(after, t)})` }
          : {}),
      });
      form.reset({ ...values, note: '' });
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          date: 'date',
          value: 'amount',
          note: 'note',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(challengeErrorMessage(error, t));
      }
    }
  });

  const { errors } = form.formState;
  const counted = challenge.metric === 'milestones' || challenge.metric === 'percent';

  return (
    <form onSubmit={onValid} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <TextField
        label={t('challenges.checkIn.date')}
        type="date"
        min={first}
        max={last}
        className="sm:max-w-xs"
        help={t('challenges.checkIn.dateHelp')}
        error={errors.date?.message}
        {...form.register('date')}
      />
      {counted ? (
        <TextField
          label={
            challenge.metric === 'percent'
              ? t('challenges.checkIn.percent')
              : t('challenges.checkIn.count')
          }
          inputMode="numeric"
          autoComplete="off"
          maxLength={4}
          className="sm:max-w-xs"
          help={
            challenge.metric === 'percent'
              ? t('challenges.checkIn.percentHelp')
              : t('challenges.checkIn.countHelp')
          }
          error={errors.amount?.message}
          {...form.register('amount')}
        />
      ) : (
        <Controller
          control={form.control}
          name="done"
          render={({ field }) => (
            <RadioGroup
              legend={t('challenges.checkIn.how')}
              value={field.value}
              onChange={field.onChange}
              help={t('challenges.checkIn.howHelp')}
              options={[
                { value: '1', label: t('challenges.checkIn.done') },
                { value: '0', label: t('challenges.checkIn.notDone') },
              ]}
            />
          )}
        />
      )}
      <TextArea
        label={t('challenges.checkIn.note')}
        optional
        rows={2}
        maxLength={NOTE_MAX}
        help={t('challenges.checkIn.noteHelp')}
        error={errors.note?.message}
        {...form.register('note')}
      />
      <Button type="submit" loading={record.isPending}>
        {t('challenges.checkIn.submit')}
      </Button>
    </form>
  );
}
