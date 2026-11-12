import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Checkbox } from '@/shared/components/Checkbox';
import { Select } from '@/shared/components/Select';
import { useToast } from '@/shared/components/toast/ToastContext';
import type { Preferences } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useSavePreferences } from '../profileApi';
import {
  type AccessibilityValues,
  accessibilityPatch,
  accessibilityValues,
  TEXT_SCALES,
} from '../profileValues';

/**
 * Reduced motion, high contrast and text size: saved to the account and
 * applied across the app at once (see AccountDisplayPreferences).
 */
export function AccessibilityCard({ preferences }: { preferences: Preferences }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const save = useSavePreferences();
  const [formError, setFormError] = useState<string | null>(null);
  const form = useForm<AccessibilityValues>({ defaultValues: accessibilityValues(preferences) });
  const percent = new Intl.NumberFormat(formatLocale, { style: 'percent' });
  const scales = [...new Set<number>([...TEXT_SCALES, preferences.text_scale_percent])].sort(
    (a, b) => a - b,
  );

  const onSubmit = form.handleSubmit((values) => {
    if (save.isPending) return;
    setFormError(null);
    const patch = accessibilityPatch(values, preferences);
    if (Object.keys(patch).length === 0) {
      toast.show({ tone: 'info', title: t('profileSettings.nothingChanged') });
      return;
    }
    save.mutate(patch, {
      onSuccess: (updated) => {
        form.reset(accessibilityValues(updated));
        toast.show({ tone: 'success', title: t('profileSettings.accessibility.saved') });
      },
      onError: (error) => {
        setFormError(describeError(error, t));
      },
    });
  });

  return (
    <Card
      title={t('profileSettings.accessibility.title')}
      description={t('profileSettings.accessibility.description')}
    >
      <form noValidate onSubmit={onSubmit} className="space-y-5">
        <FormAlert message={formError} />
        <Checkbox
          label={t('profileSettings.accessibility.reducedMotion')}
          description={t('profileSettings.accessibility.reducedMotionHelp')}
          {...form.register('reducedMotion')}
        />
        <Checkbox
          label={t('profileSettings.accessibility.highContrast')}
          description={t('profileSettings.accessibility.highContrastHelp')}
          {...form.register('highContrast')}
        />
        <Select
          label={t('profileSettings.accessibility.textScale')}
          help={t('profileSettings.accessibility.textScaleHelp')}
          options={scales.map((scale) => ({
            value: String(scale),
            label:
              scale === 100
                ? t('profileSettings.accessibility.textScaleDefault', {
                    size: percent.format(scale / 100),
                  })
                : percent.format(scale / 100),
          }))}
          className="sm:max-w-xs"
          {...form.register('textScale')}
        />
        <Button type="submit" loading={save.isPending}>
          {t('profileSettings.accessibility.save')}
        </Button>
      </form>
    </Card>
  );
}
