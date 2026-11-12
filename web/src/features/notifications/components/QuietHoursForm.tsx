import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { preferencesQueryKey } from '@/shared/finance/keys';
import type { Preferences } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { notificationsApi } from '../api';

const CLOCK = /^([01]\d|2[0-3]):[0-5]\d$/;

/** "22:00:00" or "22:00" → "22:00" (time inputs and the API use HH:MM). */
function hhmm(value: string): string {
  return value.slice(0, 5);
}

/**
 * Quiet hours: browser, phone and email notifications wait until the end
 * of the window (in the user's time zone). In-app notifications still
 * appear, and security alerts and urgent notices are never held.
 */
export function QuietHoursForm({ preferences }: { preferences: Preferences }) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const initial = {
    enabled: preferences.quiet_hours_enabled,
    start: hhmm(preferences.quiet_hours_start),
    end: hhmm(preferences.quiet_hours_end),
  };
  const [enabled, setEnabled] = useState(initial.enabled);
  const [start, setStart] = useState(initial.start);
  const [end, setEnd] = useState(initial.end);
  const [errors, setErrors] = useState<{ start?: string; end?: string }>({});
  const [error, setError] = useState<string | null>(null);
  // Saving remounts the form (keyed by the saved values): toast from the mutation itself.
  const save = useMutation({
    mutationFn: notificationsApi.updateQuietHours,
    onSuccess: (updated) => {
      toast.show({ tone: 'success', title: t('notifications.quiet.saved') });
      queryClient.setQueryData(preferencesQueryKey, updated);
    },
  });
  const dirty = enabled !== initial.enabled || start !== initial.start || end !== initial.end;

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (save.isPending || !dirty) return;
    const next: { start?: string; end?: string } = {};
    if (!CLOCK.test(start)) next.start = t('notifications.quiet.timeInvalid');
    if (!CLOCK.test(end)) next.end = t('notifications.quiet.timeInvalid');
    if (!next.start && !next.end && start === end && enabled) {
      next.end = t('notifications.quiet.sameTime');
    }
    setErrors(next);
    if (next.start || next.end) return;
    setError(null);
    save.mutate(
      { quiet_hours_enabled: enabled, quiet_hours_start: start, quiet_hours_end: end },
      {
        onError: (failure) => {
          setError(describeError(failure, t));
        },
      },
    );
  };

  return (
    <form noValidate onSubmit={submit} className="space-y-4">
      <FormAlert message={error} />
      <Checkbox
        label={t('notifications.quiet.enable')}
        description={t('notifications.quiet.enableHelp', { timeZone: preferences.timezone })}
        checked={enabled}
        disabled={save.isPending}
        onChange={(event) => {
          setEnabled(event.target.checked);
        }}
      />
      <div className="grid gap-4 sm:grid-cols-2">
        <TextField
          type="time"
          label={t('notifications.quiet.start')}
          value={start}
          error={errors.start}
          disabled={!enabled || save.isPending}
          onChange={(event) => {
            setStart(event.target.value);
          }}
        />
        <TextField
          type="time"
          label={t('notifications.quiet.end')}
          value={end}
          error={errors.end}
          disabled={!enabled || save.isPending}
          onChange={(event) => {
            setEnd(event.target.value);
          }}
        />
      </div>
      <Button
        type="submit"
        variant="secondary"
        loading={save.isPending}
        disabled={!dirty && !save.isPending}
      >
        {t('notifications.quiet.save')}
      </Button>
    </form>
  );
}
