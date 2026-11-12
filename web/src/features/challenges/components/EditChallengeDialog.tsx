import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { applyCodedServerErrors } from '@/features/communities/fieldCodes';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { addDaysToLocalDate, isLocalDate } from '@/shared/formatting/dates';
import { useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { challengesApi } from '../api';
import { challengeErrorMessage, challengeRuleCode } from '../errors';
import {
  type EditValues,
  MAX_SPAN_DAYS,
  TEXT_MAX,
  TITLE_MAX,
  textSchema,
  titleSchema,
  toChallengePatch,
} from '../formValues';
import { challengeChanged, challengeStale } from '../hooks';
import type { Challenge, ChallengePatch } from '../types';

function buildSchema(t: Translate, challenge: Challenge) {
  const latest = addDaysToLocalDate(challenge.starts_on, MAX_SPAN_DAYS);
  return z
    .object({
      title: titleSchema(t),
      description: textSchema(t),
      rules: textSchema(t),
      endsOn: z.string(),
      leaderboard: z.boolean(),
    })
    .superRefine((values, ctx) => {
      if (!values.endsOn) {
        ctx.addIssue({ code: 'custom', path: ['endsOn'], message: t('validation.dateRequired') });
      } else if (!isLocalDate(values.endsOn)) {
        ctx.addIssue({ code: 'custom', path: ['endsOn'], message: t('validation.dateInvalid') });
      } else if (values.endsOn < challenge.ends_on) {
        ctx.addIssue({
          code: 'custom',
          path: ['endsOn'],
          message: t('challenges.edit.endEarlier'),
        });
      } else if (values.endsOn > latest) {
        ctx.addIssue({
          code: 'custom',
          path: ['endsOn'],
          message: t('challenges.form.endTooLate'),
        });
      }
    });
}

/**
 * Edits a challenge you created: only the fields that changed are sent,
 * with the challenge's `version`. When someone else saved first (409), the
 * latest challenge is loaded and the form starts again from it. The end
 * date can only move later.
 */
export function EditChallengeDialog({
  challenge,
  open,
  onOpenChange,
}: {
  challenge: Challenge;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useT();
  const [pending, setPending] = useState(false);
  const [conflict, setConflict] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) setConflict(false);
        onOpenChange(next);
      }}
      title={t('challenges.edit.title')}
      description={t('challenges.edit.description')}
      busy={pending}
    >
      {open ? (
        <>
          {conflict ? (
            <Alert tone="warning" live="polite" title={t('finance.conflict.title')}>
              {t('challenges.edit.conflictBody')}
            </Alert>
          ) : null}
          <EditForm
            // Every saved change moves the version: the form restarts from the latest challenge.
            key={challenge.version}
            challenge={challenge}
            onPendingChange={setPending}
            onConflict={() => {
              setConflict(true);
            }}
            onDone={() => {
              setConflict(false);
              onOpenChange(false);
            }}
          />
        </>
      ) : null}
    </Dialog>
  );
}

function EditForm({
  challenge,
  onPendingChange,
  onConflict,
  onDone,
}: {
  challenge: Challenge;
  onPendingChange: (pending: boolean) => void;
  onConflict: () => void;
  onDone: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(() => buildSchema(t, challenge), [t, challenge]);
  const form = useForm<EditValues, unknown, EditValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      title: challenge.title,
      description: challenge.description ?? '',
      rules: challenge.rules ?? '',
      endsOn: challenge.ends_on,
      leaderboard: challenge.leaderboard_enabled,
    },
  });
  const update = useMutation({
    mutationFn: (body: ChallengePatch) => challengesApi.update(challenge.id, body),
  });
  const shared = challenge.visibility !== 'private';

  const onValid = form.handleSubmit(async (values) => {
    if (update.isPending) return;
    setFormError(null);
    const patch = toChallengePatch(challenge, values);
    if (Object.keys(patch).length === 1) {
      toast.show({ tone: 'info', title: t('challenges.edit.unchanged') });
      onDone();
      return;
    }
    onPendingChange(true);
    try {
      const updated = await update.mutateAsync(patch);
      void challengeChanged(queryClient, updated);
      onPendingChange(false);
      toast.show({ tone: 'success', title: t('challenges.edit.done') });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyCodedServerErrors(
          error,
          form.setError,
          {
            title: 'title',
            description: 'description',
            rules: 'rules',
            ends_on: 'endsOn',
            leaderboard_enabled: 'leaderboard',
          },
          t,
        );
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'VERSION_CONFLICT')) {
        // Someone else saved first: the dialog explains and restarts the form from the reload.
        onConflict();
        void challengeStale(queryClient, challenge.id);
      } else {
        // No longer active (cancelled elsewhere): show the latest state behind the dialog.
        if (challengeRuleCode(error) === 'challenge_inactive') {
          void challengeStale(queryClient, challenge.id);
        }
        setFormError(challengeErrorMessage(error, t));
      }
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onValid} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <TextField
        label={t('challenges.form.title')}
        maxLength={TITLE_MAX}
        autoComplete="off"
        error={errors.title?.message}
        {...form.register('title')}
      />
      <TextArea
        label={t('challenges.form.description')}
        optional
        maxLength={TEXT_MAX}
        error={errors.description?.message}
        {...form.register('description')}
      />
      <TextArea
        label={t('challenges.form.rules')}
        optional
        maxLength={TEXT_MAX}
        error={errors.rules?.message}
        {...form.register('rules')}
      />
      <TextField
        label={t('challenges.form.endsOn')}
        type="date"
        min={challenge.ends_on}
        max={addDaysToLocalDate(challenge.starts_on, MAX_SPAN_DAYS)}
        help={t('challenges.edit.endsOnHelp')}
        error={errors.endsOn?.message}
        {...form.register('endsOn')}
      />
      {shared ? (
        <Checkbox
          label={t('challenges.form.leaderboard')}
          description={t('challenges.form.leaderboardHelp')}
          error={errors.leaderboard?.message}
          {...form.register('leaderboard')}
        />
      ) : null}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={update.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={update.isPending}>
          {t('common.save')}
        </Button>
      </div>
    </form>
  );
}
