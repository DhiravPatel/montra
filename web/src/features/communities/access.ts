import type { User } from '@/shared/api/types';
import { parseTimestamp } from '@/shared/formatting/dates';
import type { Community, CommunityMember } from './types';

/*
 * What the interface offers. The API stays the authority: it checks every
 * request, and its permission answers are shown and the community reloaded.
 */

/** Montra support staff moderate every community (the API treats them as moderators). */
export function isStaff(user: Pick<User, 'platform_role'>): boolean {
  return user.platform_role === 'admin' || user.platform_role === 'support';
}

export function isActiveMember(community: Community): boolean {
  return community.my_status === 'active';
}

export function isOwner(community: Community): boolean {
  return community.my_status === 'active' && community.my_role === 'owner';
}

/**
 * Settings, members, reports and actions: the owner, moderators and Montra
 * staff, as the API says (`can_moderate`; staff moderate everywhere while
 * their `my_role` stays `none`).
 */
export function canModerate(community: Community): boolean {
  return community.can_moderate;
}

/** The end of a moderator's posting restriction on the caller, while it lasts. */
export function restrictionEnd(restrictedUntil: string | undefined, now: number): Date | null {
  const until = parseTimestamp(restrictedUntil);
  return until && until.getTime() > now ? until : null;
}

/**
 * Whether the caller may post, comment, react and vote: an active member of
 * an active community without a posting restriction. (A platform-wide
 * sanction is only known when the API answers `account_restricted`.)
 */
export function canParticipate(community: Community, now: number): boolean {
  return (
    community.status === 'active' &&
    community.my_status === 'active' &&
    restrictionEnd(community.restricted_until, now) === null
  );
}

/** Whether a moderator may act on this member (only the owner and staff act on moderators). */
export function canActOnMember(
  community: Community,
  user: Pick<User, 'id' | 'platform_role'>,
  member: CommunityMember,
): boolean {
  if (member.user_id === user.id || member.role === 'owner') return false;
  if (member.role === 'moderator') return isOwner(community) || isStaff(user);
  return canModerate(community);
}
