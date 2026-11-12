import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { TextLink } from '@/shared/components/TextLink';
import { communityPath, groupPath } from '@/shared/config/paths';
import { useGroups } from '@/shared/finance/sharing';
import { formatDate, formatLocalDateRange, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useMyCommunities } from '../hooks';
import { challengeTypeLabel, metricHelp, metricLabel, visibilityLabel } from '../labels';
import { targetText } from '../progress';
import type { Challenge } from '../types';

/**
 * The group or community a challenge belongs to, named by the challenge
 * itself when you may see it (`group` / `community`). Older challenges
 * carry only the ID: then the name comes from your own groups and
 * communities while you are still in them.
 */
function Audience({ challenge }: { challenge: Challenge }) {
  const { t } = useI18n();
  const groups = useGroups(Boolean(challenge.group_id) && !challenge.group);
  const communities = useMyCommunities(Boolean(challenge.community_id) && !challenge.community);
  if (challenge.group_id) {
    const name =
      challenge.group?.name ?? groups.data?.find((group) => group.id === challenge.group_id)?.name;
    return (
      <TextLink to={groupPath(challenge.group_id)}>
        {name ?? t('challenges.about.openGroup')}
      </TextLink>
    );
  }
  if (challenge.community_id) {
    const name =
      challenge.community?.name ??
      communities.data?.find((community) => community.id === challenge.community_id)?.name;
    return (
      <TextLink to={communityPath(challenge.community_id)}>
        {name ?? t('challenges.about.openCommunity')}
      </TextLink>
    );
  }
  return null;
}

export function AboutCard({ challenge }: { challenge: Challenge }) {
  const { t, formatLocale } = useI18n();
  const { timezone } = useCurrentUser();
  const created = parseTimestamp(challenge.created_at);
  return (
    <Card title={t('challenges.about.title')}>
      <Facts>
        {challenge.description ? (
          <Fact label={t('challenges.form.description')}>
            <span className="whitespace-pre-line">{challenge.description}</span>
          </Fact>
        ) : null}
        <Fact label={t('challenges.form.type')}>
          {t(challengeTypeLabel(challenge.challenge_type))}
        </Fact>
        <Fact label={t('challenges.about.counting')}>
          <span className="block">{t(metricLabel[challenge.metric])}</span>
          <span className="block text-sm text-fg-muted">{t(metricHelp[challenge.metric])}</span>
        </Fact>
        <Fact label={t('challenges.form.target')}>{targetText(challenge, t)}</Fact>
        <Fact label={t('challenges.about.dates')}>
          {formatLocalDateRange(challenge.starts_on, challenge.ends_on, formatLocale)}
        </Fact>
        <Fact label={t('challenges.form.visibility')}>
          <span className="block">{t(visibilityLabel[challenge.visibility])}</span>
          {challenge.group_id || challenge.community_id ? (
            <span className="block">
              <Audience challenge={challenge} />
            </span>
          ) : null}
        </Fact>
        <Fact label={t('challenges.about.leaderboard')}>
          {challenge.leaderboard_enabled
            ? t('challenges.about.leaderboardOn')
            : t('challenges.about.leaderboardOff')}
        </Fact>
        <Fact label={t('challenges.about.participants')}>
          {t('challenges.card.participants', { count: challenge.participant_count })}
        </Fact>
        {challenge.rules ? (
          <Fact label={t('challenges.form.rules')}>
            <span className="whitespace-pre-line">{challenge.rules}</span>
          </Fact>
        ) : null}
        {created ? (
          <Fact label={t('challenges.about.created')}>
            {challenge.mine
              ? t('challenges.about.createdByYou', {
                  date: formatDate(created, formatLocale, timezone),
                })
              : formatDate(created, formatLocale, timezone)}
          </Fact>
        ) : null}
      </Facts>
    </Card>
  );
}
