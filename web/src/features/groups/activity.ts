import type { IconName } from '@/shared/components/Icon';
import { groupExpensePath, groupRecurringPath, settlementPath } from '@/shared/config/paths';
import { formatLocalDate, isLocalDate } from '@/shared/formatting/dates';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { groupTypeLabel, isGroupType } from './labels';
import type { GroupActivity, GroupActivitySummary, GroupMember } from './types';

export interface ActivityLine {
  text: string;
  icon: IconName;
  /** The record the event is about, when it has its own page. */
  to: string | null;
}

interface ActivityContext {
  groupId: string;
  /** Current and former members (the API keeps former members for history). */
  members: readonly GroupMember[];
  myId: string;
  t: Translate;
  locale: string;
}

/** Events whose sentence only needs `{actor}`. */
const simpleEvents: Readonly<
  Partial<Record<GroupActivity['kind'], { key: MessageKey; icon: IconName }>>
> = {
  group_updated: { key: 'groups.activity.group_updated', icon: 'sliders' },
  group_archived: { key: 'groups.activity.group_archived', icon: 'archive' },
  group_restored: { key: 'groups.activity.group_restored', icon: 'archive-restore' },
  group_deleted: { key: 'groups.activity.group_deleted', icon: 'trash' },
  invitation_revoked: { key: 'groups.activity.invitation_revoked', icon: 'ban' },
  join_requested: { key: 'groups.activity.join_requested', icon: 'mail' },
  expense_updated: { key: 'groups.activity.expense_updated', icon: 'pencil' },
  expense_deleted: { key: 'groups.activity.expense_deleted', icon: 'trash' },
  expense_commented: { key: 'groups.activity.expense_commented', icon: 'message-square' },
  expense_disputed: { key: 'groups.activity.expense_disputed', icon: 'flag' },
  dispute_resolved: { key: 'groups.activity.dispute_resolved', icon: 'check-circle' },
  dispute_withdrawn: { key: 'groups.activity.dispute_withdrawn', icon: 'undo' },
  recurring_expense_updated: { key: 'groups.activity.recurring_expense_updated', icon: 'repeat' },
  recurring_expense_paused: { key: 'groups.activity.recurring_expense_paused', icon: 'pause' },
  recurring_expense_resumed: { key: 'groups.activity.recurring_expense_resumed', icon: 'play' },
  recurring_expense_stopped: {
    key: 'groups.activity.recurring_expense_stopped',
    icon: 'x-circle',
  },
  settlement_proposed: { key: 'groups.activity.settlement_proposed', icon: 'handshake' },
  settlement_reported: { key: 'groups.activity.settlement_reported', icon: 'banknote' },
  settlement_confirmed: { key: 'groups.activity.settlement_confirmed', icon: 'check-circle' },
  settlement_disputed: { key: 'groups.activity.settlement_disputed', icon: 'flag' },
  settlement_voided: { key: 'groups.activity.settlement_voided', icon: 'x-circle' },
  settlement_corrected: { key: 'groups.activity.settlement_corrected', icon: 'pencil' },
};

/**
 * A text the members typed (an expense description or a recurring expense
 * name), trimmed. Summaries are typed by the contract but come from the
 * network, so anything that is not a string is ignored.
 */
function typedText(value: GroupActivitySummary[keyof GroupActivitySummary]): string {
  return typeof value === 'string' ? value.trim() : '';
}

function linkFor(event: GroupActivity, groupId: string): string | null {
  const id = event.entity_id;
  if (!id) return null;
  if (event.entity_type === 'group_dispute') {
    // Resolved/withdrawn disputes name what was disputed; older events
    // (no target_type) were always expenses.
    const target = event.summary.target;
    if (!target) return null;
    return event.summary.target_type === 'settlement'
      ? settlementPath(groupId, target)
      : groupExpensePath(groupId, target);
  }
  switch (event.entity_type) {
    case 'group_expense':
      return groupExpensePath(groupId, id);
    case 'settlement':
      return settlementPath(groupId, id);
    case 'group_recurring_expense':
      return groupRecurringPath(groupId);
    default:
      return null;
  }
}

/**
 * One activity event as a sentence in the interface language, built from
 * the typed summary (codes, IDs and the names members typed; the API sends
 * no sentences). Names come from the group's member list (only what
 * members already see); anyone else (a person asking to join) is "Someone".
 */
export function describeActivity(event: GroupActivity, context: ActivityContext): ActivityLine {
  const { t, myId, groupId } = context;
  const names = new Map(context.members.map((member) => [member.user_id, member.display_name]));
  const person = (id: string | undefined, self: MessageKey): string => {
    if (!id) return t('groups.activity.someone');
    if (id === myId) return t(self);
    return names.get(id) ?? t('groups.activity.someone');
  };
  const actor = person(event.actor_id, 'groups.activity.you');
  const member = person(event.entity_id, 'groups.activity.youObject');
  const to = linkFor(event, groupId);
  // Copied so a summary missing from the wire still reads as empty.
  const summary: GroupActivitySummary = { ...event.summary };

  const simple = simpleEvents[event.kind];
  if (simple) return { text: t(simple.key, { actor }), icon: simple.icon, to };

  switch (event.kind) {
    case 'group_created': {
      const type = summary.type;
      return {
        text:
          type && isGroupType(type)
            ? t('groups.activity.group_created_typed', { actor, type: t(groupTypeLabel[type]) })
            : t('groups.activity.group_created', { actor }),
        icon: 'plus',
        to,
      };
    }
    case 'invitation_created':
      return summary.kind === 'link'
        ? { text: t('groups.activity.invitation_link', { actor }), icon: 'link', to }
        : { text: t('groups.activity.invitation_username', { actor }), icon: 'user-plus', to };
    case 'member_joined': {
      if (summary.via === 'join_request') {
        return {
          text: t('groups.activity.member_approved', { actor, member }),
          icon: 'user-plus',
          to,
        };
      }
      const joined = event.entity_id === myId ? t('groups.activity.you') : member;
      return {
        text: t('groups.activity.member_joined', { member: joined }),
        icon: 'user-plus',
        to,
      };
    }
    case 'member_left': {
      const left = event.entity_id === myId ? t('groups.activity.you') : member;
      return { text: t('groups.activity.member_left', { member: left }), icon: 'log-out', to };
    }
    case 'member_removed':
      return { text: t('groups.activity.member_removed', { actor, member }), icon: 'x-circle', to };
    case 'member_role_changed': {
      if (summary.role === 'admin') {
        return { text: t('groups.activity.made_admin', { actor, member }), icon: 'shield', to };
      }
      if (summary.role === 'member') {
        return { text: t('groups.activity.made_member', { actor, member }), icon: 'user', to };
      }
      return { text: t('groups.activity.role_changed', { actor, member }), icon: 'user', to };
    }
    case 'ownership_transferred':
      return { text: t('groups.activity.made_owner', { actor, member }), icon: 'key', to };
    case 'expense_added': {
      const description = typedText(summary.description);
      const recurring = typedText(summary.recurring_rule_id) !== '';
      let text;
      if (recurring) {
        text = description
          ? t('groups.activity.expense_added_recurring_named', { actor, description })
          : t('groups.activity.expense_added_recurring', { actor });
      } else {
        text = description
          ? t('groups.activity.expense_added_named', { actor, description })
          : t('groups.activity.expense_added', { actor });
      }
      return { text, icon: recurring ? 'repeat' : 'receipt', to };
    }
    case 'recurring_expense_created': {
      const name = typedText(summary.name);
      return {
        text: name
          ? t('groups.activity.recurring_created_named', { actor, name })
          : t('groups.activity.recurring_created', { actor }),
        icon: 'repeat',
        to,
      };
    }
    case 'recurring_expense_skipped': {
      const date = typedText(summary.date);
      return {
        text: isLocalDate(date)
          ? t('groups.activity.recurring_skipped_dated', {
              actor,
              date: formatLocalDate(date, context.locale),
            })
          : t('groups.activity.recurring_skipped', { actor }),
        icon: 'skip-forward',
        to,
      };
    }
    default:
      // A kind added to the API after this client was built.
      return { text: t('groups.activity.other', { actor }), icon: 'info', to };
  }
}
