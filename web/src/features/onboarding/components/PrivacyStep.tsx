import { useState } from 'react';
import { Checkbox } from '@/shared/components/Checkbox';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { StepActions } from './StepActions';
import type { StepProps } from './types';
import { usePreferencePatch } from './usePreferencePatch';

const facts: readonly MessageKey[] = [
  'onboarding.privacy.factPrivate',
  'onboarding.privacy.factNoSelling',
  'onboarding.privacy.factNoBank',
  'onboarding.privacy.factAi',
  'onboarding.privacy.factControl',
];

/** What Montra does with your data, and the one optional choice it asks for here. */
export function PrivacyStep({ preferences, onNext, onBack, advancing }: StepProps) {
  const t = useT();
  const [analytics, setAnalytics] = useState(preferences.analytics_opt_in);
  const [error, setError] = useState<string | null>(null);
  const patch = usePreferencePatch();

  const save = () => {
    if (patch.isPending) return;
    if (analytics === preferences.analytics_opt_in) {
      onNext('completed');
      return;
    }
    setError(null);
    patch.mutate(
      { analytics_opt_in: analytics },
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
      <ul className="list-disc space-y-2 ps-5 text-fg">
        {facts.map((fact) => (
          <li key={fact}>{t(fact)}</li>
        ))}
      </ul>
      <div className="rounded-lg border border-line p-4">
        <Checkbox
          label={t('onboarding.privacy.analytics')}
          description={t('onboarding.privacy.analyticsHelp')}
          checked={analytics}
          onChange={(event) => {
            setAnalytics(event.target.checked);
          }}
        />
      </div>
      <StepActions
        onBack={onBack}
        onSkip={() => {
          onNext('skipped');
        }}
        primaryLabel={t('common.continue')}
        onPrimary={save}
        pending={patch.isPending || advancing}
      />
    </div>
  );
}
