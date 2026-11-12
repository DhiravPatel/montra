import { useId } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { visibilityHelp, visibilityLabel } from '../labels';
import type { Community } from '../types';
import { UserText } from './UserText';

/** What the community is about, its rules and who can join. */
export function AboutCard({ community }: { community: Community }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const created = parseTimestamp(community.created_at);
  const rulesId = useId();
  return (
    <Card title={t('communities.about.title')}>
      <div className="space-y-5">
        {community.description ? (
          <UserText text={community.description} />
        ) : (
          <p className="text-sm text-fg-muted">{t('communities.about.noDescription')}</p>
        )}
        <Facts>
          <Fact label={t('communities.about.whoCanJoin')}>
            <span className="block font-medium">{t(visibilityLabel[community.visibility])}</span>
            <span className="block text-sm text-fg-muted">
              {t(visibilityHelp[community.visibility])}
            </span>
          </Fact>
          <Fact label={t('communities.about.members')}>
            {t('communities.memberCount', { count: community.member_count })}
          </Fact>
          {community.topics.length > 0 ? (
            <Fact label={t('communities.about.topics')}>
              <ul className="flex flex-wrap gap-2">
                {community.topics.map((topic) => (
                  <li
                    key={topic}
                    className="rounded-full border border-line bg-surface-muted px-2.5 py-0.5 text-xs font-medium text-fg"
                  >
                    {topic}
                  </li>
                ))}
              </ul>
            </Fact>
          ) : null}
          {created ? (
            <Fact label={t('communities.about.created')}>
              {formatDate(created, formatLocale, user.timezone)}
            </Fact>
          ) : null}
        </Facts>
        {community.rules ? (
          <section aria-labelledby={rulesId} className="space-y-2">
            <h3 id={rulesId} className="text-base font-semibold text-fg">
              {t('communities.about.rules')}
            </h3>
            <UserText text={community.rules} className="text-sm" />
          </section>
        ) : null}
        <p className="text-sm text-fg-muted">{t('communities.about.privacy')}</p>
      </div>
    </Card>
  );
}
