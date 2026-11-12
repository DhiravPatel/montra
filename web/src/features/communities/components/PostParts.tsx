import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatDateTime, formatRelativeTime, parseTimestamp } from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { useI18n } from '@/shared/i18n/I18nContext';
import {
  postKindIcon,
  postKindLabel,
  postLabelIcon,
  postLabelLabel,
  postLabelTone,
} from '../labels';
import type { Author, ContentStatus, Post } from '../types';
import { PersonName } from './PersonName';

/** "Asha Rao @asha · 5 minutes ago · edited" (the exact time is in the tooltip and for screen readers). */
export function AuthorLine({
  author,
  createdAt,
  editedAt,
  mine,
}: {
  author: Author;
  createdAt: string;
  editedAt?: string | undefined;
  mine: boolean;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const now = useNow();
  const created = parseTimestamp(createdAt);
  const edited = parseTimestamp(editedAt);
  return (
    <p className="flex flex-wrap items-baseline gap-x-2 gap-y-1 text-sm text-fg-muted">
      <PersonName name={author.display_name} username={author.username} />
      {mine ? <span>({t('communities.post.you')})</span> : null}
      {created ? (
        <time dateTime={createdAt} title={formatDateTime(created, formatLocale, user.timezone)}>
          {formatRelativeTime(created, formatLocale, now)}
        </time>
      ) : null}
      {edited ? (
        <span title={formatDateTime(edited, formatLocale, user.timezone)}>
          {t('communities.post.edited')}
        </span>
      ) : null}
    </p>
  );
}

/**
 * The post's label (personal experience or verified guidance from a
 * moderator, a question or a resource), its kind when that adds something,
 * and pinned / locked states. Always icon + text.
 */
export function PostBadges({ post }: { post: Post }) {
  const { t } = useI18n();
  const kindAddsInfo = post.kind !== 'discussion' && post.kind !== post.label;
  return (
    <div className="flex flex-wrap gap-2">
      {post.pinned ? (
        <StatusBadge tone="info" icon="arrow-up">
          {t('communities.post.pinned')}
        </StatusBadge>
      ) : null}
      <StatusBadge tone={postLabelTone[post.label]} icon={postLabelIcon[post.label]}>
        {t(postLabelLabel[post.label])}
      </StatusBadge>
      {kindAddsInfo ? (
        <StatusBadge tone="neutral" icon={postKindIcon[post.kind]}>
          {t(postKindLabel[post.kind])}
        </StatusBadge>
      ) : null}
      {post.locked ? (
        <StatusBadge tone="neutral" icon="lock">
          {t('communities.post.locked')}
        </StatusBadge>
      ) : null}
    </div>
  );
}

/**
 * Moderation state of a post or comment, as the API returns it: hidden
 * (while moderators review it), removed (with the reason when the API
 * shares it with the author and moderators) or deleted by its author.
 */
export function ContentNotice({
  status,
  reason,
  target,
  mine,
}: {
  status: ContentStatus;
  reason?: string | undefined;
  target: 'post' | 'comment';
  mine: boolean;
}) {
  const { t } = useI18n();
  if (status === 'published') return null;
  if (status === 'deleted') {
    return (
      <Alert
        tone="neutral"
        title={t(
          target === 'post'
            ? 'communities.notice.postDeleted'
            : 'communities.notice.commentDeleted',
        )}
      />
    );
  }
  const hidden = status === 'hidden';
  let body: string;
  if (hidden) {
    body = mine ? t('communities.notice.hiddenMine') : t('communities.notice.hiddenOthers');
  } else {
    body = mine ? t('communities.notice.removedMine') : t('communities.notice.removedOthers');
  }
  const title = hidden
    ? t(target === 'post' ? 'communities.notice.postHidden' : 'communities.notice.commentHidden')
    : t(target === 'post' ? 'communities.notice.postRemoved' : 'communities.notice.commentRemoved');
  return (
    <Alert tone="warning" title={title}>
      <p>{body}</p>
      {reason ? <p>{t('communities.notice.reason', { reason })}</p> : null}
    </Alert>
  );
}
