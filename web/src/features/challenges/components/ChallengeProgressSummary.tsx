import { ProgressMeter } from '@/shared/components/ProgressMeter';
import { useT } from '@/shared/i18n/I18nContext';
import { percentText, progressText } from '../progress';
import type { Challenge, ChallengeParticipation } from '../types';

/**
 * Your progress in words first, with a meter for a quick glance. Values are
 * the API's (`progress_value`, `percent_complete`); nothing is computed here.
 */
export function ChallengeProgressSummary({
  challenge,
  me,
  size = 'md',
}: {
  challenge: Challenge;
  me: ChallengeParticipation;
  size?: 'sm' | 'md';
}) {
  const t = useT();
  const words = progressText(challenge, me, t);
  const percent = percentText(me, t);
  return (
    <div className="space-y-2">
      <ProgressMeter
        percentBp={me.percent_complete * 100}
        label={t('challenges.progress.meterLabel', { title: challenge.title })}
        valueText={`${words} (${percent})`}
        tone={me.status === 'completed' ? 'success' : 'accent'}
        size={size}
      />
      <p className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 text-sm">
        <span className="font-semibold text-fg">{words}</span>
        <span className="text-fg-muted">{percent}</span>
      </p>
    </div>
  );
}
