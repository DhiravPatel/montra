import { useMemo } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import type { GroupDetail, GroupMember, GroupTransfer, Settlement } from './types';

/**
 * Names for the people in a group's records. Only what the API returns for
 * members is shown (display name, username); former members stay readable,
 * and anyone the group no longer lists is "Former member".
 */
export interface People {
  meId: string;
  isMe: (userId: string | undefined) => boolean;
  /** "You" for the signed-in person, the member's name, or `fallback` / "Former member". */
  name: (userId: string | undefined, fallback?: string) => string;
  /** Like `name`, for the middle of a sentence ("Paid by you"). */
  inSentence: (userId: string | undefined, fallback?: string) => string;
  /** Picker label: "You (Asha Rao)" or "Meera Rao (@meera)". */
  optionLabel: (member: GroupMember) => string;
  /** Active members, the signed-in person first (who can pay or share). */
  active: GroupMember[];
  /** Everyone the group lists, active first (settlements may involve former members). */
  everyone: GroupMember[];
  isActiveMember: (userId: string) => boolean;
}

export function usePeople(group: GroupDetail): People {
  const t = useT();
  const me = useCurrentUser();
  return useMemo(() => {
    const byId = new Map(group.members.map((member) => [member.user_id, member]));
    const mineFirst = (a: GroupMember, b: GroupMember) =>
      Number(b.user_id === me.id) - Number(a.user_id === me.id);
    const active = group.members.filter((member) => member.status === 'active').sort(mineFirst);
    const everyone = [...active, ...group.members.filter((member) => member.status !== 'active')];
    return {
      meId: me.id,
      isMe: (userId) => userId === me.id,
      name: (userId, fallback) => {
        if (userId && userId === me.id) return t('groupMoney.people.you');
        const member = userId ? byId.get(userId) : undefined;
        return member?.display_name ?? fallback ?? t('groupMoney.people.former');
      },
      inSentence: (userId, fallback) => {
        if (userId && userId === me.id) return t('groupMoney.people.youInSentence');
        const member = userId ? byId.get(userId) : undefined;
        return member?.display_name ?? fallback ?? t('groupMoney.people.formerInSentence');
      },
      optionLabel: (member) => {
        if (member.user_id === me.id) {
          return t('groupMoney.people.youNamed', { name: member.display_name });
        }
        const handle = member.username ? ` (@${member.username})` : '';
        const left =
          member.status === 'active'
            ? ''
            : ` · ${t(member.status === 'removed' ? 'groupMoney.people.removed' : 'groupMoney.people.leftGroup')}`;
        return `${member.display_name}${handle}${left}`;
      },
      active,
      everyone,
      isActiveMember: (userId) => byId.get(userId)?.status === 'active',
    };
  }, [group.members, me.id, t]);
}

/** Owners and admins manage any record; members manage their own. */
export function isGroupAdmin(group: GroupDetail): boolean {
  return group.my_role === 'owner' || group.my_role === 'admin';
}

/** Archived (or deleted) groups are read-only until the owner restores them. */
export function isReadOnlyGroup(group: GroupDetail): boolean {
  return group.status !== 'active';
}

/** "You owe Meera", "Meera owes you" or "Meera owes Ravi" (names as the group lists them). */
export function useTransferSentence(people: People) {
  const t = useT();
  return (transfer: GroupTransfer) => {
    const from = people.name(transfer.from_user_id, transfer.from_name);
    const to = people.name(transfer.to_user_id, transfer.to_name);
    if (people.isMe(transfer.from_user_id)) return t('groupMoney.transfer.youOwe', { name: to });
    if (people.isMe(transfer.to_user_id)) return t('groupMoney.transfer.owesYou', { name: from });
    return t('groupMoney.transfer.owes', { from, to });
  };
}

/** Groups items by currency in first-seen order; amounts in different currencies are never added. */
export function byCurrency<T>(
  items: readonly T[],
  currencyOf: (item: T) => string,
): [string, T[]][] {
  const groups = new Map<string, T[]>();
  for (const item of items) {
    const code = currencyOf(item);
    const list = groups.get(code);
    if (list) list.push(item);
    else groups.set(code, [item]);
  }
  return [...groups.entries()];
}

/** "Meera Rao paid you", "You paid Ravi Kumar", "You plan to pay Ravi Kumar". */
export function settlementTitle(settlement: Settlement, people: People, t: Translate): string {
  const payer = people.name(settlement.payer_user_id, settlement.payer_name);
  const payee = people.inSentence(settlement.payee_user_id, settlement.payee_name);
  if (settlement.status !== 'proposed') return t('groupMoney.settlement.paid', { payer, payee });
  return people.isMe(settlement.payer_user_id)
    ? t('groupMoney.settlement.youPlan', { payee })
    : t('groupMoney.settlement.planned', { payer, payee });
}
