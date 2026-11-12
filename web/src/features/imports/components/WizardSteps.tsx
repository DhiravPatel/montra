import { Icon } from '@/shared/components/Icon';
import { useT } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { cx } from '@/shared/utils/cx';

export type WizardStep = 'account' | 'file' | 'columns' | 'review' | 'confirm' | 'done';

const STEPS: readonly { id: WizardStep; label: MessageKey }[] = [
  { id: 'account', label: 'imports.wizard.step.account' },
  { id: 'file', label: 'imports.wizard.step.file' },
  { id: 'columns', label: 'imports.wizard.step.columns' },
  { id: 'review', label: 'imports.wizard.step.review' },
  { id: 'confirm', label: 'imports.wizard.step.confirm' },
  { id: 'done', label: 'imports.wizard.step.done' },
];

/**
 * Where the user is in the import: completed steps show a check (and say
 * so to screen readers), the current one is marked with aria-current="step".
 */
export function WizardSteps({ current }: { current: WizardStep }) {
  const t = useT();
  const index = STEPS.findIndex((step) => step.id === current);
  return (
    <ol aria-label={t('imports.wizard.stepsLabel')} className="mb-6 flex flex-wrap gap-x-5 gap-y-3">
      {STEPS.map((step, position) => {
        const state = position < index ? 'done' : position === index ? 'current' : 'todo';
        return (
          <li
            key={step.id}
            aria-current={state === 'current' ? 'step' : undefined}
            className={cx(
              'flex items-center gap-2 text-sm',
              state === 'current' ? 'font-semibold text-fg' : 'text-fg-muted',
            )}
          >
            <span
              aria-hidden="true"
              className={cx(
                'inline-flex size-7 shrink-0 items-center justify-center rounded-full border text-xs',
                state === 'current' && 'border-accent bg-accent text-on-accent',
                state === 'done' && 'border-success bg-success-soft text-success',
                state === 'todo' && 'border-line-strong',
              )}
            >
              {state === 'done' ? <Icon name="check" className="size-4" /> : position + 1}
            </span>
            <span>
              {t(step.label)}
              {state === 'done' ? (
                <span className="sr-only"> {t('imports.wizard.stepDone')}</span>
              ) : null}
            </span>
          </li>
        );
      })}
    </ol>
  );
}
