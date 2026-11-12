import { Button } from '@/shared/components/Button';
import { Icon, type IconName } from '@/shared/components/Icon';
import { useT } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';

const points: readonly { icon: IconName; title: MessageKey; body: MessageKey }[] = [
  { icon: 'check-circle', title: 'onboarding.welcome.free', body: 'onboarding.welcome.freeBody' },
  { icon: 'lock', title: 'onboarding.welcome.private', body: 'onboarding.welcome.privateBody' },
  { icon: 'pencil', title: 'onboarding.welcome.manual', body: 'onboarding.welcome.manualBody' },
];

interface WelcomeStepProps {
  onStart: () => void;
  onSkipAll: () => void;
  skipping: boolean;
}

export function WelcomeStep({ onStart, onSkipAll, skipping }: WelcomeStepProps) {
  const t = useT();
  return (
    <div className="space-y-6">
      <p className="text-fg">{t('onboarding.welcome.body')}</p>
      <ul className="grid gap-4 sm:grid-cols-3">
        {points.map((point) => (
          <li key={point.title} className="rounded-lg border border-line p-4">
            <Icon name={point.icon} className="text-accent" />
            <p className="mt-2 font-semibold text-fg">{t(point.title)}</p>
            <p className="mt-1 text-sm text-fg-muted">{t(point.body)}</p>
          </li>
        ))}
      </ul>
      <p className="text-sm text-fg-muted">{t('onboarding.welcome.optional')}</p>
      <div className="flex flex-col-reverse gap-3 border-t border-line pt-5 sm:flex-row sm:justify-end">
        <Button variant="ghost" loading={skipping} onClick={onSkipAll}>
          {t('onboarding.skipAll')}
        </Button>
        <Button onClick={onStart} disabled={skipping}>
          {t('onboarding.welcome.start')}
        </Button>
      </div>
    </div>
  );
}
