import { Button } from '@/shared/components/Button';
import { useT } from '@/shared/i18n/I18nContext';

interface StepActionsProps {
  onBack?: () => void;
  onSkip?: () => void;
  primaryLabel: string;
  /** `submit` when the step is a form. */
  primaryType?: 'submit' | 'button';
  onPrimary?: () => void;
  pending?: boolean;
  primaryDisabled?: boolean;
}

/** Back / Skip / Continue, the same on every onboarding step. */
export function StepActions({
  onBack,
  onSkip,
  primaryLabel,
  primaryType = 'button',
  onPrimary,
  pending = false,
  primaryDisabled = false,
}: StepActionsProps) {
  const t = useT();
  return (
    <div className="flex flex-col-reverse gap-3 border-t border-line pt-5 sm:flex-row sm:items-center sm:justify-between">
      <div>
        {onBack ? (
          <Button variant="ghost" onClick={onBack} disabled={pending}>
            {t('common.back')}
          </Button>
        ) : null}
      </div>
      <div className="flex flex-col-reverse gap-3 sm:flex-row">
        {onSkip ? (
          <Button variant="secondary" onClick={onSkip} disabled={pending}>
            {t('onboarding.skipStep')}
          </Button>
        ) : null}
        <Button
          type={primaryType}
          loading={pending}
          disabled={primaryDisabled}
          onClick={primaryType === 'button' ? onPrimary : undefined}
        >
          {primaryLabel}
        </Button>
      </div>
    </div>
  );
}
