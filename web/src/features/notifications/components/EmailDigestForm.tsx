import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useState } from 'react';
import { Button } from '@/shared/components/Button';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { useToast } from '@/shared/components/toast/ToastContext';
import { preferencesQueryKey } from '@/shared/finance/keys';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { notificationsApi } from '../api';
import type { EmailDigest } from '../types';

/**
 * The account-level summary email: optional emails as they happen, or
 * collected into one email each morning or each Monday. Security, account
 * and urgent emails are never held back.
 */
export function EmailDigestForm({ current }: { current: EmailDigest }) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [value, setValue] = useState<EmailDigest>(current);
  const [error, setError] = useState<string | null>(null);
  // Saving remounts the form (keyed by the saved value): toast from the mutation itself.
  const save = useMutation({
    mutationFn: notificationsApi.updateEmailDigest,
    onSuccess: (preferences) => {
      toast.show({ tone: 'success', title: t('notifications.digest.saved') });
      queryClient.setQueryData(preferencesQueryKey, preferences);
    },
  });

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (save.isPending || value === current) return;
    setError(null);
    save.mutate(value, {
      onError: (failure) => {
        setError(describeError(failure, t));
      },
    });
  };

  return (
    <form noValidate onSubmit={submit} className="space-y-4">
      <FormAlert message={error} />
      <RadioGroup<EmailDigest>
        legend={t('notifications.digest.legend')}
        value={value}
        onChange={setValue}
        variant="cards"
        disabled={save.isPending}
        options={[
          {
            value: 'off',
            label: t('notifications.digest.off'),
            description: t('notifications.digest.offHelp'),
          },
          {
            value: 'daily',
            label: t('notifications.digest.daily'),
            description: t('notifications.digest.dailyHelp'),
          },
          {
            value: 'weekly',
            label: t('notifications.digest.weekly'),
            description: t('notifications.digest.weeklyHelp'),
          },
        ]}
      />
      <p className="text-sm text-fg-muted">{t('notifications.digest.always')}</p>
      <Button
        type="submit"
        variant="secondary"
        loading={save.isPending}
        disabled={value === current && !save.isPending}
      >
        {t('notifications.digest.save')}
      </Button>
    </form>
  );
}
