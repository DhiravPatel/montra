import { useQueryClient } from '@tanstack/react-query';
import { useId } from 'react';
import { Link } from 'react-router';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { postPath } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { patchPost } from '../keys';
import type { Post } from '../types';
import { AuthorLine, ContentNotice, PostBadges } from './PostParts';
import { ReactionBar } from './ReactionBar';
import { ResourceLink, UserTextExcerpt } from './UserText';

/**
 * A post in the feed: badges, title (links to the post), author, a plain
 * text excerpt (links open from the post itself), the resource link, a
 * poll summary, reactions, the comment count and Report.
 */
export function PostCard({
  post,
  canParticipate,
  onReport,
}: {
  post: Post;
  canParticipate: boolean;
  onReport: (post: Post) => void;
}) {
  const t = useT();
  const queryClient = useQueryClient();
  const titleId = useId();
  const published = post.status === 'published';
  return (
    <article
      aria-labelledby={titleId}
      className="space-y-3 rounded-xl border border-line bg-surface p-5 shadow-card"
    >
      <PostBadges post={post} />
      <h3 id={titleId} className="text-lg font-semibold break-words text-fg">
        <Link to={postPath(post.id)} className="underline-offset-4 hover:underline">
          {post.title}
        </Link>
      </h3>
      <AuthorLine
        author={post.author}
        createdAt={post.created_at}
        editedAt={post.edited_at}
        mine={post.mine}
      />
      <ContentNotice
        status={post.status}
        reason={post.removed_reason}
        target="post"
        mine={post.mine}
      />
      {post.body ? <UserTextExcerpt text={post.body} /> : null}
      {post.kind === 'resource' ? <ResourceLink url={post.link_url} /> : null}
      {post.poll ? (
        <p className="flex items-start gap-2 text-sm text-fg">
          <Icon name="bar-chart" className="mt-0.5 size-4 text-fg-muted" />
          <span className="min-w-0 break-words">
            {t('communities.feed.pollSummary', {
              question: post.poll.question,
              count: post.poll.total_votes,
            })}
          </span>
        </p>
      ) : null}
      <div className="flex flex-wrap items-center justify-between gap-3 border-t border-line pt-3">
        {published ? (
          <ReactionBar
            target="post"
            id={post.id}
            reactions={post.reactions}
            mine={post.my_reactions}
            canAdd={canParticipate}
            onChange={(reactions, mine) => {
              patchPost(queryClient, post.community_id, post.id, (current) => ({
                ...current,
                reactions,
                my_reactions: mine,
              }));
            }}
          />
        ) : (
          <span />
        )}
        <div className="flex flex-wrap items-center gap-2">
          <Link
            to={postPath(post.id)}
            className="inline-flex min-h-9 items-center gap-1.5 rounded-md px-2 text-sm font-medium text-accent underline decoration-1 underline-offset-4 hover:text-accent-hover"
          >
            <Icon name="message-square" className="size-4" />
            {t('communities.feed.comments', { count: post.comment_count })}
            <span className="sr-only">: {post.title}</span>
          </Link>
          {!post.mine && published ? (
            <Button
              variant="ghost"
              size="sm"
              aria-label={t('communities.report.actionNamed', { title: post.title })}
              onClick={() => {
                onReport(post);
              }}
            >
              <Icon name="flag" className="size-4" />
              {t('communities.report.action')}
            </Button>
          ) : null}
        </div>
      </div>
    </article>
  );
}
