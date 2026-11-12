import type { components } from '@/shared/api/schema';

type Schemas = components['schemas'];

/** Contract types for communities, posts, comments, polls and community moderation. */
export type Community = Schemas['CommunityDTO'];
export type CommunityInput = Schemas['CommunityInput'];
/** PATCH /communities/{id}: only the fields sent change; `version` is required. */
export type CommunityPatch = Schemas['CommunityPatch'];
export type CommunityVisibility = Community['visibility'];
export type CommunityStatus = Community['status'];
/** The caller's role (`none` unless the caller is an active member). */
export type MyCommunityRole = Community['my_role'];
export type MyMembershipStatus = Community['my_status'];

export type CommunityMember = Schemas['CommunityMemberDTO'];
export type MemberRole = CommunityMember['role'];
export type MemberStatus = CommunityMember['status'];

/** A minimal profile on invitations (display name, username; never anything else). */
export type CommunityPerson = Schemas['CommunityPersonDTO'];
export type CommunityInvitation = Schemas['CommunityInvitationDTO'];
export type CommunityInvitationInput = Schemas['CommunityInvitationInput'];
export type InvitationKind = CommunityInvitation['kind'];
export type InvitationStatus = CommunityInvitation['status'];
/** What an invitation link is for, before joining (POST /community-invitations/preview). */
export type CommunityInvitationPreview = Schemas['CommunityInvitationPreview'];

export type Author = Schemas['CommunityAuthorDTO'];
export type Post = Schemas['CommunityPostDTO'];
export type PostDetail = Schemas['CommunityPostDetail'];
export type PostInput = Schemas['CommunityPostInput'];
export type PostKind = Post['kind'];
export type NewPostKind = NonNullable<PostInput['kind']>;
export type PostLabel = Post['label'];
/** Moderation state of a post or comment. */
export type ContentStatus = Post['status'];
export type PostComment = Schemas['CommunityCommentDTO'];
export type CommentInput = Schemas['CommunityCommentInput'];
export type Poll = Schemas['CommunityPollDTO'];
export type PollInput = Schemas['CommunityPollInput'];
export type ReactionCounts = Schemas['CommunityReactionCounts'];
/** The counts plus the caller's own reactions, as reaction writes answer. */
export type CommunityReactions = Schemas['CommunityReactionsDTO'];
export type ReactionKind = Schemas['CommunityReactionInput']['kind'];

/** One cursor page of a community's feed. */
export interface FeedPage {
  items: Post[];
  /** The next page's cursor; null on the last page. */
  nextCursor: string | null;
}

export type Report = Schemas['ModerationReportDTO'];
export type ReportInput = Schemas['ModerationReportInput'];
export type ReportReason = ReportInput['reason'];
export type ReportStatus = Report['status'];
export type ReportTargetType = Report['target_type'];
/** Report queue filter (`open` also lists reports under review). */
export type ReportFilter = 'open' | 'actioned' | 'dismissed' | 'escalated';

export type ModerationAction = Schemas['ModerationActionDTO'];
export type ModerationActionInput = Schemas['ModerationActionInput'];
export type ModerationActionKind = ModerationActionInput['action'];
export type ModerationTargetType = ModerationActionInput['target_type'];
/** The latest appeal against an action, as the action carries it. */
export type AppealState = Schemas['ModerationAppealState'];
export type Appeal = Schemas['ModerationAppealDTO'];
/** The action an appeal is against, embedded in the appeal. */
export type AppealedAction = Schemas['ModerationActionSummary'];
export type AppealDecision = Schemas['AppealDecisionInput']['decision'];

/** What reactions and reports point at. */
export type ContentTarget = 'post' | 'comment';
