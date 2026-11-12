import { Link } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { challengePath } from '@/shared/config/paths';
import { formatLocalDateRange } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { challengeTypeIcon, challengeTypeLabel } from '../labels';
import { targetText } from '../progress';
import type { Challenge } from '../types';
import { ChallengeBadges } from './ChallengeBadges';
import { ChallengeProgressSummary } from './ChallengeProgressSummary';

/** One challenge in a list: what it is, when, and your progress if you take part. */
export function ChallengeCard({ challenge, today }: { challenge: Challenge; today: string }) {
  const { t, formatLocale } = useI18n();
  const details = [
    t(challengeTypeLabel(challenge.challenge_type)),
    formatLocalDateRange(challenge.starts_on, challenge.ends_on, formatLocale),
    t('challenges.card.target', { target: targetText(challenge, t) }),
  ];
  const me = challenge.me && challenge.me.status !== 'left' ? challenge.me : null;
  return (
    <article className="flex h-full flex-col gap-4 rounded-xl border border-line bg-surface p-5 shadow-card">
      <div className="flex items-start gap-3">
        <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
          <Icon name={challengeTypeIcon(challenge.challenge_type)} />
        </span>
        <div className="min-w-0 flex-1 space-y-1">
          <h3 className="text-base font-semibold break-words text-fg">
            <Link
              to={challengePath(challenge.id)}
              className="underline-offset-4 hover:underline focus-visible:underline"
            >
              {challenge.title}
            </Link>
          </h3>
          <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
          <p className="text-sm text-fg-muted">
            {t('challenges.card.participants', { count: challenge.participant_count })}
          </p>
        </div>
      </div>
      <ChallengeBadges challenge={challenge} today={today} />
      {me ? (
        <div className="mt-auto">
          <ChallengeProgressSummary challenge={challenge} me={me} size="sm" />
        </div>
      ) : null}
    </article>
  );
}
