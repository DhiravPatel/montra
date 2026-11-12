import { useId, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useT } from '@/shared/i18n/I18nContext';
import { useCommunityFeed } from '../api';
import type { FeedQuery } from '../keys';
import type { Community, FeedPage, Post } from '../types';
import { PostCard } from './PostCard';
import { ReportDialog } from './ReportDialog';

const SEARCH_MAX = 100;
const SORTS = ['new', 'top', 'active'] as const satisfies readonly FeedQuery['sort'][];

function isSort(value: string): value is FeedQuery['sort'] {
  return (SORTS as readonly string[]).includes(value);
}

/** Posts on every loaded page, once each (a post can move between pages while they load). */
function visiblePosts(pages: readonly FeedPage[]): Post[] {
  const seen = new Set<string>();
  const posts: Post[] = [];
  for (const page of pages) {
    for (const post of page.items) {
      if (seen.has(post.id)) continue;
      seen.add(post.id);
      posts.push(post);
    }
  }
  return posts;
}

function FeedSkeleton() {
  const t = useT();
  return (
    <LoadingState label={t('communities.feed.loading')}>
      <div className="space-y-4" aria-hidden="true">
        <Skeleton className="h-36 w-full" />
        <Skeleton className="h-36 w-full" />
        <Skeleton className="h-36 w-full" />
      </div>
    </LoadingState>
  );
}

/**
 * The community's posts (pinned first), sorted by new, top or active, with
 * search and "Show more" (the next cursor page while the API reports more).
 * Private communities show posts to members only.
 */
export function Feed({
  community,
  canParticipate,
}: {
  community: Community;
  canParticipate: boolean;
}) {
  const t = useT();
  const announce = useAnnounce();
  const headingId = useId();
  const [sort, setSort] = useState<FeedQuery['sort']>('new');
  const [search, setSearch] = useState('');
  const q = useDebouncedValue(search.trim(), 300);
  const feed = useCommunityFeed(community.id, { sort, q });
  const [reporting, setReporting] = useState<Post | null>(null);

  /** Why the posts are not shown (the API answers 403 to non-members of private communities). */
  const membersOnlyText = () => {
    if (community.my_status === 'pending') return t('communities.feed.membersOnlyPending');
    if (community.my_status === 'banned') return t('communities.feed.membersOnlyBanned');
    if (community.status !== 'active') return t('communities.feed.membersOnlyClosed');
    return t('communities.feed.membersOnlyBody');
  };

  let content;
  if (feed.isPending) {
    content = <FeedSkeleton />;
  } else if (feed.isError) {
    content = hasErrorCode(feed.error, 'FORBIDDEN') ? (
      <EmptyState
        titleAs="p"
        icon="lock"
        title={t('communities.feed.membersOnly')}
        description={membersOnlyText()}
      />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('communities.feed.error')}
        error={feed.error}
        retrying={feed.isFetching}
        onRetry={() => {
          void feed.refetch();
        }}
      />
    );
  } else {
    const posts = visiblePosts(feed.data.pages);
    if (posts.length === 0) {
      content = q ? (
        <EmptyState
          titleAs="p"
          icon="search"
          title={t('communities.feed.noMatches', { query: q })}
          description={t('communities.feed.noMatchesBody')}
        />
      ) : (
        <EmptyState
          titleAs="p"
          icon="message-square"
          title={t('communities.feed.empty')}
          description={
            canParticipate ? t('communities.feed.emptyBody') : t('communities.feed.emptyVisitor')
          }
        />
      );
    } else {
      content = (
        <>
          <ul className="space-y-4">
            {posts.map((post) => (
              <li key={post.id}>
                <PostCard post={post} canParticipate={canParticipate} onReport={setReporting} />
              </li>
            ))}
          </ul>
          {feed.hasNextPage ? (
            <div className="mt-6 flex justify-center">
              <Button
                variant="secondary"
                loading={feed.isFetchingNextPage}
                onClick={() => {
                  if (feed.isFetchingNextPage) return;
                  void feed.fetchNextPage().then((result) => {
                    if (!result.isError) announce(t('communities.feed.moreLoaded'));
                  });
                }}
              >
                <Icon name="arrow-down" className="size-4" />
                {t('communities.feed.more')}
              </Button>
            </div>
          ) : null}
        </>
      );
    }
  }

  return (
    <section aria-labelledby={headingId} className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <h2 id={headingId} className="text-lg font-semibold text-fg">
          {t('communities.feed.title')}
        </h2>
        <div className="flex flex-wrap items-end gap-3">
          <TextField
            type="search"
            className="w-full sm:w-64"
            label={t('communities.feed.search')}
            aria-required={false}
            maxLength={SEARCH_MAX}
            autoComplete="off"
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
            }}
          />
          <Select
            className="w-full sm:w-44"
            label={t('communities.feed.sort')}
            value={sort}
            options={[
              { value: 'new', label: t('communities.feed.sort.new') },
              { value: 'top', label: t('communities.feed.sort.top') },
              { value: 'active', label: t('communities.feed.sort.active') },
            ]}
            onChange={(event) => {
              if (isSort(event.target.value)) setSort(event.target.value);
            }}
          />
        </div>
      </div>
      {content}
      <ReportDialog
        target={reporting ? { type: 'post', id: reporting.id } : null}
        open={reporting !== null}
        onOpenChange={(open) => {
          if (!open) setReporting(null);
        }}
      />
    </section>
  );
}
