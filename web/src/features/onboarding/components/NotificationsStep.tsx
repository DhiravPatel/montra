import { useState } from 'react';
import { RadioGroup } from '@/shared/components/RadioGroup';
import type { EmailDigest } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { StepActions } from './StepActions';
import type { StepProps } from './types';
import { usePreferencePatch } from './usePreferencePatch';

/** How often to send an optional email summary; security emails are always sent. */
export function NotificationsStep({ preferences, onNext, onBack, advancing }: StepProps) {
  const t = useT();
  const [digest, setDigest] = useState<EmailDigest>(preferences.email_digest);
  const [error, setError] = useState<string | null>(null);
  const patch = usePreferencePatch();

  const save = () => {
    if (patch.isPending) return;
    if (digest === preferences.email_digest) {
      onNext('completed');
      return;
    }
    setError(null);
    patch.mutate(
      { email_digest: digest },
      {
        onSuccess: () => {
          onNext('completed');
        },
        onError: (failure) => {
          setError(describeError(failure, t));
        },
      },
    );
  };

  return (
    <div className="space-y-6">
      <FormAlert message={error} />
      <RadioGroup<EmailDigest>
        legend={t('onboarding.notifications.legend')}
        value={digest}
        onChange={setDigest}
        variant="cards"
        options={[
          {
            value: 'off',
            label: t('onboarding.notifications.off'),
            description: t('onboarding.notifications.offHelp'),
          },
          {
            value: 'daily',
            label: t('onboarding.notifications.daily'),
            description: t('onboarding.notifications.dailyHelp'),
          },
          {
            value: 'weekly',
            label: t('onboarding.notifications.weekly'),
            description: t('onboarding.notifications.weeklyHelp'),
          },
        ]}
      />
      <p className="text-sm text-fg-muted">{t('onboarding.notifications.security')}</p>
      <StepActions
        onBack={onBack}
        onSkip={() => {
          onNext('skipped');
        }}
        primaryLabel={t('onboarding.finish')}
        onPrimary={save}
        pending={patch.isPending || advancing}
      />
    </div>
  );
}
