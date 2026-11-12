import { useState } from 'react';
import { RadioGroup } from '@/shared/components/RadioGroup';
import type { IncomeRange } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { StepActions } from './StepActions';
import type { StepProps } from './types';
import { usePreferencePatch } from './usePreferencePatch';

const ranges: readonly { value: IncomeRange; label: MessageKey }[] = [
  { value: 'prefer_not_to_say', label: 'onboarding.income.prefer_not_to_say' },
  { value: 'under_25k', label: 'onboarding.income.under_25k' },
  { value: '25k_50k', label: 'onboarding.income.25k_50k' },
  { value: '50k_1l', label: 'onboarding.income.50k_1l' },
  { value: '1l_2l', label: 'onboarding.income.1l_2l' },
  { value: '2l_5l', label: 'onboarding.income.2l_5l' },
  { value: 'above_5l', label: 'onboarding.income.above_5l' },
];

function isIncomeRange(value: string | undefined): value is IncomeRange {
  return ranges.some((range) => range.value === value);
}

/** An optional income range, asked only with a reason (spec §4.1 "optional income range"). */
export function IncomeStep({ preferences, onNext, onBack, advancing }: StepProps) {
  const t = useT();
  const initial = isIncomeRange(preferences.income_range)
    ? preferences.income_range
    : 'prefer_not_to_say';
  const [range, setRange] = useState<IncomeRange>(initial);
  const [error, setError] = useState<string | null>(null);
  const patch = usePreferencePatch();

  const save = () => {
    if (patch.isPending) return;
    if (range === preferences.income_range) {
      onNext('completed');
      return;
    }
    setError(null);
    patch.mutate(
      { income_range: range },
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
      <p className="text-fg">{t('onboarding.income.why')}</p>
      <RadioGroup<IncomeRange>
        legend={t('onboarding.income.legend')}
        value={range}
        onChange={setRange}
        variant="cards"
        options={ranges.map((item) => ({ value: item.value, label: t(item.label) }))}
      />
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
