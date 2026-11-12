import type { Group, GroupMember, MyGroupRole } from './types';

/*
 * What the signed-in user's role allows (mirrors the API's checks so the
 * screen offers only what will work; the API stays the authority and its
 * FORBIDDEN answers are shown when they happen).
 */

export function isGroupAdmin(role: MyGroupRole): boolean {
  return role === 'owner' || role === 'admin';
}

export function isActive(group: Pick<Group, 'status'>): boolean {
  return group.status === 'active';
}

/** Owners and admins edit settings of active groups. */
export function canEditGroup(group: Pick<Group, 'my_role' | 'status'>): boolean {
  return isGroupAdmin(group.my_role) && isActive(group);
}

/** Owners and admins invite; members too when the group allows it. */
export function canInvite(
  group: Pick<Group, 'my_role' | 'status' | 'allow_member_invites'>,
): boolean {
  if (!isActive(group)) return false;
  return isGroupAdmin(group.my_role) || (group.my_role === 'member' && group.allow_member_invites);
}

/** The owner manages everyone else; admins manage members. Nobody manages the owner. */
function manages(myRole: MyGroupRole, target: GroupMember, myId: string): boolean {
  if (target.status !== 'active' || target.user_id === myId || target.role === 'owner') {
    return false;
  }
  return myRole === 'owner' || (myRole === 'admin' && target.role === 'member');
}

/** Role changes need an active group. */
export function canChangeRole(
  group: Pick<Group, 'my_role' | 'status'>,
  target: GroupMember,
  myId: string,
): boolean {
  return isActive(group) && manages(group.my_role, target, myId);
}

export function canRemoveMember(
  group: Pick<Group, 'my_role'>,
  target: GroupMember,
  myId: string,
): boolean {
  return manages(group.my_role, target, myId);
}
