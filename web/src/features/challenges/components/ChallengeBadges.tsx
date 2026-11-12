import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { challengeStatusLook, participationLook, visibilityIcon, visibilityLabel } from '../labels';
import type { Challenge } from '../types';

/** Status, your participation and who can see it: each as icon plus text. */
export function ChallengeBadges({ challenge, today }: { challenge: Challenge; today: string }) {
  const { t, formatLocale } = useI18n();
  const status = challengeStatusLook(challenge, today);
  const mine = challenge.me ? participationLook[challenge.me.status] : null;
  return (
    <div className="flex flex-wrap gap-2">
      <StatusBadge tone={status.tone} icon={status.icon}>
        {t(status.key, status.date ? { date: formatLocalDate(status.date, formatLocale) } : {})}
      </StatusBadge>
      {mine ? (
        <StatusBadge tone={mine.tone} icon={mine.icon}>
          {t(mine.key)}
        </StatusBadge>
      ) : null}
      <StatusBadge tone="neutral" icon={visibilityIcon[challenge.visibility]}>
        {t(visibilityLabel[challenge.visibility])}
      </StatusBadge>
    </div>
  );
}
