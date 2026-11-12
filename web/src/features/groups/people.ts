import type { GroupMember } from './types';

/**
 * Accessible name for an action on one record, starting with the visible
 * button text so speech input matches (e.g. "Remove: Meera Rao").
 */
export function actionFor(action: string, subject: string): string {
  return `${action}: ${subject}`;
}

/** "Asha Rao (@asha)": the minimal profile the API returns, nothing more. */
export function memberName(member: Pick<GroupMember, 'display_name' | 'username'>): string {
  return member.username ? `${member.display_name} (@${member.username})` : member.display_name;
}

/** The same for anyone the API names on an invitation (invited_by, invitee). */
export function personName(person: { display_name: string; username?: string }): string {
  return memberName(person);
}
