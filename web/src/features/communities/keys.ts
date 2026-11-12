import type { InfiniteData, QueryClient } from '@tanstack/react-query';
import type { Community, FeedPage, Post, PostDetail } from './types';

export interface CommunityListQuery {
  q: string;
  topic: string;
  mine: boolean;
}

export interface FeedQuery {
  sort: 'new' | 'top' | 'active';
  q: string;
}

/**
 * Query keys for communities. Community content is not finance data, so the
 * keys start with `communities` (finance writes never refetch them, and
 * nothing here is ever shown on finance screens). A community is cached
 * under the reference used in the address (its ID or URL name); invitation
 * tokens never appear in keys.
 */
export const communitiesKeys = {
  all: ['communities'] as const,
  lists: () => ['communities', 'list'] as const,
  list: (query: CommunityListQuery) => ['communities', 'list', query] as const,
  invitationsToMe: () => ['communities', 'invitations-to-me'] as const,
  communities: () => ['communities', 'community'] as const,
  community: (ref: string) => ['communities', 'community', ref] as const,
  membersOf: (id: string) => ['communities', 'members', id] as const,
  members: (id: string, status: string) => ['communities', 'members', id, { status }] as const,
  /** The invitations a community's moderators manage (both lists). */
  invitationsOf: (id: string) => ['communities', 'invitations', id] as const,
  invitations: (id: string, includeInactive: boolean) =>
    ['communities', 'invitations', id, { includeInactive }] as const,
  feedOf: (communityId: string) => ['communities', 'feed', communityId] as const,
  feed: (communityId: string, query: FeedQuery) =>
    ['communities', 'feed', communityId, query] as const,
  post: (id: string) => ['communities', 'post', id] as const,
  moderation: (communityId: string) => ['communities', 'moderation', communityId] as const,
  reports: (communityId: string, status: string) =>
    ['communities', 'moderation', communityId, 'reports', { status }] as const,
  actions: (communityId: string) => ['communities', 'moderation', communityId, 'actions'] as const,
  appeals: (communityId: string) => ['communities', 'moderation', communityId, 'appeals'] as const,
};

/** Stores a community returned by a write under every reference it is cached by. */
export function storeCommunity(queryClient: QueryClient, community: Community): void {
  queryClient.setQueriesData<Community>({ queryKey: communitiesKeys.communities() }, (old) =>
    old?.id === community.id ? community : old,
  );
  queryClient.setQueryData(communitiesKeys.community(community.id), community);
}

/**
 * After joining, leaving, accepting an invitation or a settings change:
 * refreshes the community, the lists and what membership unlocks (members,
 * posts). Inactive queries are only marked stale.
 */
export async function refreshCommunity(queryClient: QueryClient, communityId: string) {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: communitiesKeys.communities() }),
    queryClient.invalidateQueries({ queryKey: communitiesKeys.lists() }),
    queryClient.invalidateQueries({ queryKey: communitiesKeys.invitationsToMe() }),
    queryClient.invalidateQueries({ queryKey: communitiesKeys.membersOf(communityId) }),
    queryClient.invalidateQueries({ queryKey: communitiesKeys.invitationsOf(communityId) }),
    queryClient.invalidateQueries({ queryKey: communitiesKeys.feedOf(communityId) }),
    queryClient.invalidateQueries({ queryKey: communitiesKeys.moderation(communityId) }),
  ]);
}

/** After posting, editing or moderating content: the feed and the post refetch. */
export async function refreshContent(
  queryClient: QueryClient,
  communityId: string,
  postId?: string,
) {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: communitiesKeys.feedOf(communityId) }),
    postId ? queryClient.invalidateQueries({ queryKey: communitiesKeys.post(postId) }) : null,
  ]);
}

type PostPatch = (post: Post) => Post;

/**
 * Applies a change to a post wherever it is cached (every feed page and its
 * detail), e.g. new reaction counts or poll results, without refetching.
 */
export function patchPost(
  queryClient: QueryClient,
  communityId: string,
  postId: string,
  patch: PostPatch,
): void {
  queryClient.setQueriesData<InfiniteData<FeedPage>>(
    { queryKey: communitiesKeys.feedOf(communityId) },
    (old) =>
      old
        ? {
            ...old,
            pages: old.pages.map((page) => ({
              ...page,
              items: page.items.map((post) => (post.id === postId ? patch(post) : post)),
            })),
          }
        : old,
  );
  queryClient.setQueryData<PostDetail>(communitiesKeys.post(postId), (old) =>
    old ? { ...old, ...patch(old), comments: old.comments } : old,
  );
}

/** Applies a change to one comment of a cached post. */
export function patchComment(
  queryClient: QueryClient,
  postId: string,
  commentId: string,
  patch: (comment: PostDetail['comments'][number]) => PostDetail['comments'][number],
): void {
  queryClient.setQueryData<PostDetail>(communitiesKeys.post(postId), (old) =>
    old
      ? {
          ...old,
          comments: old.comments.map((comment) =>
            comment.id === commentId ? patch(comment) : comment,
          ),
        }
      : old,
  );
}
