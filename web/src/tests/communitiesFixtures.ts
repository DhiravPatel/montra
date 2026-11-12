import { http, HttpResponse } from 'msw';
import type {
  Appeal,
  AppealedAction,
  Author,
  Community,
  CommunityInvitation,
  CommunityInvitationPreview,
  CommunityMember,
  CommunityPerson,
  CommunityReactions,
  ModerationAction,
  Poll,
  Post,
  PostComment,
  PostDetail,
  ReactionCounts,
  Report,
} from '@/features/communities/types';
import { API, envelope, errorBody, makeUser } from './fixtures';
import { server } from './msw/server';

/** Community fixtures shaped like the contract (tests only). */

/** The signed-in test user (makeUser). */
export const ME = makeUser().id;
export const COMMUNITY_ID = 'c0c0c0c0-1111-4111-8111-000000000001';
export const COMMUNITY_SLUG = 'frugal-living';
export const OTHER_COMMUNITY_ID = 'c0c0c0c0-1111-4111-8111-000000000002';
export const MEMBER_ID = 'd1d1d1d1-2222-4222-8222-000000000001';
export const MOD_ID = 'd1d1d1d1-2222-4222-8222-000000000002';
export const OWNER_ID = 'd1d1d1d1-2222-4222-8222-000000000003';
export const PENDING_ID = 'd1d1d1d1-2222-4222-8222-000000000004';
export const POST_ID = 'e2e2e2e2-3333-4333-8333-000000000001';
export const POLL_POST_ID = 'e2e2e2e2-3333-4333-8333-000000000002';
export const COMMENT_ID = 'f3f3f3f3-4444-4444-8444-000000000001';
export const REPLY_ID = 'f3f3f3f3-4444-4444-8444-000000000002';
export const POLL_ID = 'a4a4a4a4-5555-4555-8555-000000000001';
export const OPTION_A = 'a4a4a4a4-5555-4555-8555-00000000000a';
export const OPTION_B = 'a4a4a4a4-5555-4555-8555-00000000000b';
export const INVITATION_ID = 'b5b5b5b5-6666-4666-8666-000000000001';
export const REPORT_ID = 'b5b5b5b5-6666-4666-8666-000000000002';
export const ACTION_ID = 'b5b5b5b5-6666-4666-8666-000000000003';
export const APPEAL_ID = 'b5b5b5b5-6666-4666-8666-000000000004';
/** A link token as the API creates them (24 random bytes, base64url). */
export const COMMUNITY_LINK_TOKEN = 'Q29tbXVuaXR5LUxpbmstVG9rZW4tMTIz';

/** A community as the API returns it; `can_moderate` follows the role unless overridden. */
export function makeCommunity(overrides: Partial<Community> = {}): Community {
  const role = overrides.my_role ?? 'member';
  const status = overrides.my_status ?? 'active';
  return {
    id: COMMUNITY_ID,
    slug: COMMUNITY_SLUG,
    name: 'Frugal Living',
    description: 'Everyday saving tips. Read more at https://example.org/guide',
    rules: 'Be kind. No selling.',
    topics: ['saving', 'budgeting'],
    visibility: 'public',
    status: 'active',
    member_count: 12,
    my_role: 'member',
    my_status: 'active',
    can_moderate: status === 'active' && (role === 'owner' || role === 'moderator'),
    version: 1,
    created_at: '2026-10-01T08:30:00Z',
    ...overrides,
  };
}

export function makeCommunityMember(overrides: Partial<CommunityMember> = {}): CommunityMember {
  return {
    user_id: MEMBER_ID,
    display_name: 'Meera Rao',
    username: 'meera',
    role: 'member',
    status: 'active',
    joined_at: '2026-10-02T08:30:00Z',
    ...overrides,
  };
}

/** The community's owner, a moderator and a member (as moderators see the list). */
export function makeMemberList(): CommunityMember[] {
  return [
    makeCommunityMember({
      user_id: OWNER_ID,
      display_name: 'Owen Shah',
      username: 'owen',
      role: 'owner',
    }),
    makeCommunityMember({
      user_id: MOD_ID,
      display_name: 'Divya Iyer',
      username: 'divya',
      role: 'moderator',
    }),
    makeCommunityMember(),
  ];
}

export function makeAuthor(overrides: Partial<Author> = {}): Author {
  return { user_id: MEMBER_ID, display_name: 'Meera Rao', username: 'meera', ...overrides };
}

export function reactions(overrides: Partial<ReactionCounts> = {}): ReactionCounts {
  return { like: 0, helpful: 0, insightful: 0, support: 0, ...overrides };
}

/** A reaction write's answer: the counts plus the caller's own reactions. */
export function reactionsAnswer(
  counts: Partial<ReactionCounts> = {},
  mine: string[] = [],
): CommunityReactions {
  return { ...reactions(counts), my_reactions: mine };
}

export function makePost(overrides: Partial<Post> = {}): Post {
  return {
    id: POST_ID,
    community_id: COMMUNITY_ID,
    author: makeAuthor(),
    kind: 'discussion',
    label: 'personal_experience',
    title: 'How I paid off my bike loan',
    body: 'I paid a little extra each month.\n\nThanks @asha for the idea! Guide: https://example.org/payoff.',
    status: 'published',
    pinned: false,
    locked: false,
    comment_count: 2,
    reactions: reactions({ helpful: 3 }),
    my_reactions: [],
    mine: false,
    created_at: '2026-11-04T09:00:00Z',
    ...overrides,
  };
}

export function makePoll(overrides: Partial<Poll> = {}): Poll {
  return {
    id: POLL_ID,
    question: 'Avalanche or snowball?',
    allow_multiple: false,
    closed: false,
    options: [
      { id: OPTION_A, label: 'Avalanche', votes: 3 },
      { id: OPTION_B, label: 'Snowball', votes: 1 },
    ],
    total_votes: 4,
    my_votes: [],
    ...overrides,
  };
}

export function makePollPost(overrides: Partial<Post> = {}): Post {
  return makePost({
    id: POLL_POST_ID,
    kind: 'poll',
    title: 'Which payoff method?',
    body: '',
    comment_count: 0,
    reactions: reactions(),
    poll: makePoll(),
    ...overrides,
  });
}

export function makeComment(overrides: Partial<PostComment> = {}): PostComment {
  return {
    id: COMMENT_ID,
    post_id: POST_ID,
    author: makeAuthor({ user_id: MOD_ID, display_name: 'Divya Iyer', username: 'divya' }),
    body: 'Congratulations! See https://example.org/tips',
    status: 'published',
    reactions: reactions({ support: 1 }),
    my_reactions: [],
    mine: false,
    created_at: '2026-11-04T10:00:00Z',
    ...overrides,
  };
}

export function makePostDetail(
  overrides: Partial<PostDetail> = {},
  comments: PostComment[] = [
    makeComment(),
    makeComment({
      id: REPLY_ID,
      parent_comment_id: COMMENT_ID,
      author: makeAuthor(),
      body: 'Thank you!',
      reactions: reactions(),
      created_at: '2026-11-04T11:00:00Z',
    }),
  ],
): PostDetail {
  return { ...makePost(), comments, ...overrides };
}

/** The moderator who sends invitations (Divya Iyer, @divya). */
export function makeInviter(overrides: Partial<CommunityPerson> = {}): CommunityPerson {
  return { user_id: MOD_ID, display_name: 'Divya Iyer', username: 'divya', ...overrides };
}

/** A username invitation addressed to the signed-in user. */
export function makeCommunityInvitation(
  overrides: Partial<CommunityInvitation> = {},
): CommunityInvitation {
  return {
    id: INVITATION_ID,
    community_id: OTHER_COMMUNITY_ID,
    community_name: 'Founders Circle',
    kind: 'username',
    status: 'active',
    invitee_user_id: ME,
    invitee: { user_id: ME, display_name: 'Asha Rao', username: 'asha' },
    invited_by: makeInviter(),
    expires_at: '2026-11-12T09:00:00Z',
    created_at: '2026-11-05T09:00:00Z',
    ...overrides,
  };
}

/** What a link is for, as POST /community-invitations/preview answers. */
export function makeInvitationPreview(
  overrides: Partial<CommunityInvitationPreview> = {},
): CommunityInvitationPreview {
  return {
    community_id: OTHER_COMMUNITY_ID,
    community_name: 'Founders Circle',
    slug: 'founders-circle',
    member_count: 7,
    invited_by: makeInviter(),
    status: 'active',
    expires_at: '2026-11-12T09:00:00Z',
    already_member: false,
    requires_approval: false,
    ...overrides,
  };
}

export function makeReport(overrides: Partial<Report> = {}): Report {
  return {
    id: REPORT_ID,
    target_type: 'post',
    target_id: POST_ID,
    target_user_id: MEMBER_ID,
    community_id: COMMUNITY_ID,
    reason: 'spam',
    details: 'Same link everywhere',
    status: 'open',
    preview: 'Buy my course — https://spam.example',
    open_reports: 2,
    created_at: '2026-11-04T12:00:00Z',
    ...overrides,
  };
}

export function makeModerationAction(overrides: Partial<ModerationAction> = {}): ModerationAction {
  return {
    id: ACTION_ID,
    community_id: COMMUNITY_ID,
    moderator_id: MOD_ID,
    target_type: 'post',
    target_id: POST_ID,
    target_user_id: MEMBER_ID,
    action: 'remove',
    reason: 'Advertising is not allowed',
    appealable: true,
    created_at: '2026-11-04T13:00:00Z',
    ...overrides,
  };
}

/** The action an appeal is against, as the appeal embeds it. */
export function makeAppealedAction(overrides: Partial<AppealedAction> = {}): AppealedAction {
  const action = makeModerationAction();
  return {
    id: action.id,
    action: action.action,
    target_type: action.target_type,
    target_id: action.target_id,
    target_user_id: action.target_user_id,
    reason: action.reason,
    created_at: action.created_at,
    ...overrides,
  };
}

export function makeAppeal(overrides: Partial<Appeal> = {}): Appeal {
  return {
    id: APPEAL_ID,
    action_id: ACTION_ID,
    action: makeAppealedAction(),
    community_id: COMMUNITY_ID,
    statement: 'It was a free guide, not an advert.',
    status: 'open',
    created_at: '2026-11-04T14:00:00Z',
    ...overrides,
  };
}

export function notFound(resource = 'community') {
  return HttpResponse.json(
    errorBody({ code: 'NOT_FOUND', message: `The ${resource} was not found.` }),
    { status: 404 },
  );
}

export function forbidden() {
  return HttpResponse.json(
    errorBody({ code: 'FORBIDDEN', message: 'You do not have permission to perform this action.' }),
    { status: 403 },
  );
}

export function ruleViolation(code: string, params?: Record<string, string>) {
  return HttpResponse.json(
    errorBody({
      code: 'DOMAIN_RULE_VIOLATION',
      message: 'Rule.',
      details: [{ message: 'Rule.', code, ...(params ? { params } : {}) }],
    }),
    { status: 422 },
  );
}

export function rateLimited(retryAfter?: number) {
  return HttpResponse.json(
    errorBody({ code: 'RATE_LIMITED', message: 'Too many requests. Please wait and try again.' }),
    { status: 429, headers: retryAfter ? { 'Retry-After': String(retryAfter) } : {} },
  );
}

/** A daily cap (429 `daily_cap` with Retry-After), as posts, comments, reports and creates answer it. */
export function dailyCapped(resource: string, limit: number, retryAfter: number) {
  return HttpResponse.json(
    errorBody({
      code: 'RATE_LIMITED',
      message: 'Too many requests. Please wait and try again.',
      details: [
        {
          message: 'Daily limit reached.',
          code: 'daily_cap',
          params: {
            resource,
            limit: String(limit),
            retry_at: new Date(Date.now() + retryAfter * 1000).toISOString(),
          },
        },
      ],
    }),
    { status: 429, headers: { 'Retry-After': String(retryAfter) } },
  );
}

/** A coded 409 CONFLICT (e.g. already_member, invitation_used, invitation_inactive). */
export function conflict(code: string, message = 'Conflict.', params?: Record<string, string>) {
  return HttpResponse.json(
    errorBody({
      code: 'CONFLICT',
      message,
      details: [{ message, code, ...(params ? { params } : {}) }],
    }),
    { status: 409 },
  );
}

/** A coded field problem (422 VALIDATION_ERROR details). */
export function fieldError(
  field: string,
  code: string,
  message = 'Invalid.',
  params?: Record<string, string>,
) {
  return HttpResponse.json(
    errorBody({
      code: 'VALIDATION_ERROR',
      message: 'The request could not be processed.',
      details: [{ field, message, code, ...(params ? { params } : {}) }],
    }),
    { status: 422 },
  );
}

export interface CommunityState {
  community: Community;
  /** GET /communities/{id}/members, by status ('' = every status). */
  members: Record<string, CommunityMember[]>;
  posts: Post[];
  /** Requests the feed received (query strings). */
  feedQueries: string[];
  /** Answer for the feed instead of `posts` (e.g. 403 for private communities). */
  feedResponse?: () => Response;
}

/**
 * Serves a community by ID or URL name, its members (by status) and its
 * feed (cursor pages of `limit` posts, like the API: `meta.next_cursor`
 * and `has_more` while more follow). Tests change `state` to make later
 * reads return something else.
 */
export function serveCommunity(
  community: Community = makeCommunity(),
  {
    members = { active: makeMemberList(), '': makeMemberList() },
    posts = [makePost(), makePollPost()],
  }: { members?: Record<string, CommunityMember[]>; posts?: Post[] } = {},
): CommunityState {
  const state: CommunityState = { community, members, posts, feedQueries: [] };
  server.use(
    http.get(`${API}/communities/:ref`, ({ params }) => {
      const ref = String(params.ref);
      if (ref !== state.community.id && ref !== state.community.slug) return notFound();
      return HttpResponse.json(envelope(state.community));
    }),
    http.get(`${API}/communities/:id/members`, ({ request }) => {
      const status = new URL(request.url).searchParams.get('status') ?? '';
      return HttpResponse.json(envelope(state.members[status] ?? []));
    }),
    http.get(`${API}/communities/:id/posts`, ({ request }) => {
      const url = new URL(request.url);
      state.feedQueries.push(url.search);
      if (state.feedResponse) return state.feedResponse();
      const limit = Number(url.searchParams.get('limit') ?? '20');
      const cursor = url.searchParams.get('cursor');
      const offset = cursor ? Number(cursor.replace(/^after-/u, '')) : 0;
      const end = offset + limit;
      const page = envelope(state.posts.slice(offset, end));
      const more = end < state.posts.length;
      return HttpResponse.json({
        ...page,
        meta: { ...page.meta, has_more: more, ...(more ? { next_cursor: `after-${end}` } : {}) },
      });
    }),
  );
  return state;
}

/** Serves GET /posts/{id} (and the post's community) from `state`. */
export function servePost(
  post: PostDetail = makePostDetail(),
  community: Community = makeCommunity(),
) {
  const state = { post, community, reads: 0 };
  server.use(
    http.get(`${API}/posts/:id`, ({ params }) => {
      state.reads += 1;
      if (params.id !== state.post.id) return notFound('post');
      return HttpResponse.json(envelope(state.post));
    }),
    http.get(`${API}/communities/:ref`, ({ params }) => {
      if (params.ref !== state.community.id && params.ref !== state.community.slug) {
        return notFound();
      }
      return HttpResponse.json(envelope(state.community));
    }),
  );
  return state;
}
