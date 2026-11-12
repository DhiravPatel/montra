import type { components } from '@/shared/api/schema';

type Schemas = components['schemas'];

/** Contract types for groups, households, trips and events. */
export type Group = Schemas['GroupDTO'];
export type GroupDetail = Schemas['GroupDetail'];
export type GroupMember = Schemas['GroupMemberDTO'];
export type GroupInput = Schemas['GroupInput'];
/** PATCH /groups/{id}: only the fields sent change; `version` is required. */
export type GroupPatch = Schemas['GroupPatch'];
export type GroupType = Group['group_type'];
export type GroupStatus = Group['status'];
/** The caller's role (`none` only for groups the caller cannot see). */
export type MyGroupRole = Group['my_role'];
export type GroupRole = GroupMember['role'];
export type MemberStatus = GroupMember['status'];
export type SplitMethod = Group['default_split_method'];
export type NotificationLevel = GroupMember['notification_level'];
export type GroupMemberUpdate = Schemas['GroupMemberUpdate'];

export type GroupInvitation = Schemas['GroupInvitationDTO'];
export type GroupInvitationInput = Schemas['GroupInvitationInput'];
export type InvitationStatus = GroupInvitation['status'];
export type InvitationPreview = Schemas['GroupInvitationPreview'];
export type JoinRequest = Schemas['GroupJoinRequestDTO'];
/** The minimal profile of a person named on an invitation (as the caller may see it). */
export type GroupPerson = Schemas['GroupPerson'];
/** POST /groups/{id}/members: a friend by `user_id`, or someone findable by `username`. */
export type AddMemberInput = Schemas['AddMemberInput'];

/**
 * Accepting an invitation link: 200 joins the group, 202 creates a join
 * request when the group requires approval (the admins decide).
 */
export type AcceptLinkResult =
  { outcome: 'joined'; group: GroupDetail } | { outcome: 'pending'; request: JoinRequest };

export type GroupActivity = Schemas['GroupActivityDTO'];
export type GroupActivitySummary = Schemas['GroupActivitySummary'];
export type GroupActivityPage = Schemas['GroupActivityPage'];
export type GroupBalances = Schemas['GroupBalancesDTO'];
export type GroupMemberBalance = Schemas['GroupMemberBalance'];
