import { Link } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { communityPath } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { visibilityIcon } from '../labels';
import type { Community } from '../types';
import { CommunityStateBadges, VisibilityBadge } from './CommunityBadges';
import { UserTextExcerpt } from './UserText';

/**
 * A community in a list: name (links by ID), visibility, members, your
 * place in it, a short description and its topics. Topic buttons filter
 * the discovery list when `onTopic` is given.
 */
export function CommunityRow({
  community,
  onTopic,
}: {
  community: Community;
  onTopic?: (topic: string) => void;
}) {
  const t = useT();
  return (
    <li className="flex gap-3 py-4 first:pt-0 last:pb-0">
      <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name={visibilityIcon[community.visibility]} />
      </span>
      <div className="min-w-0 flex-1 space-y-1.5">
        <Link
          to={communityPath(community.id)}
          className="font-medium break-words text-fg underline-offset-4 hover:underline"
        >
          {community.name}
        </Link>
        <p className="text-sm text-fg-muted">
          {t('communities.memberCount', { count: community.member_count })}
        </p>
        {community.description ? (
          <UserTextExcerpt text={community.description} maxChars={160} className="text-sm" />
        ) : null}
        <div className="flex flex-wrap gap-2">
          <VisibilityBadge visibility={community.visibility} />
          <CommunityStateBadges community={community} />
        </div>
        {community.topics.length > 0 ? (
          <ul aria-label={t('communities.about.topics')} className="flex flex-wrap gap-2 pt-1">
            {community.topics.map((topic) => (
              <li key={topic}>
                {onTopic ? (
                  <button
                    type="button"
                    aria-label={t('communities.discover.filterTopic', { topic })}
                    className="inline-flex min-h-8 items-center rounded-full border border-line bg-surface-muted px-2.5 text-xs font-medium text-fg hover:border-accent"
                    onClick={() => {
                      onTopic(topic);
                    }}
                  >
                    {topic}
                  </button>
                ) : (
                  <span className="inline-flex min-h-8 items-center rounded-full border border-line bg-surface-muted px-2.5 text-xs font-medium text-fg">
                    {topic}
                  </span>
                )}
              </li>
            ))}
          </ul>
        ) : null}
      </div>
    </li>
  );
}
