import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import type {
  ActionKind,
  ModerationAction,
  QueueStatus,
  ReportStatus,
  StaffTargetType,
} from './types';

const reasonLabels: Readonly<Record<string, MessageKey>> = {
  spam: 'moderation.reason.spam',
  abuse: 'moderation.reason.abuse',
  harassment: 'moderation.reason.harassment',
  scam: 'moderation.reason.scam',
  impersonation: 'moderation.reason.impersonation',
  misinformation: 'moderation.reason.misinformation',
  privacy: 'moderation.reason.privacy',
  other: 'moderation.reason.other',
};

/** A report reason (the API returns it as a string). */
export function reasonLabel(reason: string): MessageKey {
  return reasonLabels[reason] ?? 'moderation.reason.other';
}

const targetLabels: Readonly<Record<string, MessageKey>> = {
  post: 'moderation.target.post',
  comment: 'moderation.target.comment',
  profile: 'moderation.target.profile',
  member: 'moderation.target.member',
  group: 'moderation.target.group',
  community: 'moderation.target.community',
};

export function targetLabel(targetType: string): MessageKey {
  return targetLabels[targetType] ?? 'moderation.target.other';
}

export interface Look {
  tone: Tone;
  icon: IconName;
  key: MessageKey;
}

/** A report's status in plain words, for the person who filed it and for staff. */
export const reportStatusLook: Readonly<Record<ReportStatus, Look>> = {
  open: { tone: 'info', icon: 'clock', key: 'moderation.reportStatus.open' },
  under_review: { tone: 'info', icon: 'eye', key: 'moderation.reportStatus.under_review' },
  actioned: { tone: 'success', icon: 'check-circle', key: 'moderation.reportStatus.actioned' },
  dismissed: { tone: 'neutral', icon: 'check', key: 'moderation.reportStatus.dismissed' },
  escalated: { tone: 'warning', icon: 'arrow-up', key: 'moderation.reportStatus.escalated' },
};

export const QUEUE_STATUSES: readonly QueueStatus[] = [
  'open',
  'escalated',
  'actioned',
  'dismissed',
];

export const queueStatusLabel: Readonly<Record<QueueStatus, MessageKey>> = {
  open: 'moderation.staff.queue.open',
  escalated: 'moderation.staff.queue.escalated',
  actioned: 'moderation.staff.queue.actioned',
  dismissed: 'moderation.staff.queue.dismissed',
};

/** Reports that still need a decision. */
export function isOpenReport(status: ReportStatus): boolean {
  return status === 'open' || status === 'under_review' || status === 'escalated';
}

/**
 * What happened, told to the person it affected ("Your post was removed").
 * The moderator's identity is never part of it.
 */
export function affectedTitle(
  action: Pick<ModerationAction, 'action' | 'target_type'>,
): MessageKey {
  const content = action.target_type === 'comment' ? 'comment' : 'post';
  switch (action.action) {
    case 'hide':
      return content === 'comment'
        ? 'moderation.mine.what.hideComment'
        : 'moderation.mine.what.hidePost';
    case 'remove':
      return content === 'comment'
        ? 'moderation.mine.what.removeComment'
        : 'moderation.mine.what.removePost';
    case 'warn':
      return 'moderation.mine.what.warn';
    case 'restrict':
      return action.target_type === 'profile'
        ? 'moderation.mine.what.restrictAccount'
        : 'moderation.mine.what.restrictCommunity';
    case 'ban':
      return action.target_type === 'profile'
        ? 'moderation.mine.what.banAccount'
        : 'moderation.mine.what.banCommunity';
    case 'unban':
      return action.target_type === 'profile'
        ? 'moderation.mine.what.unbanAccount'
        : 'moderation.mine.what.unbanCommunity';
    default:
      return 'moderation.mine.what.other';
  }
}

/**
 * Actions Montra staff can take on each kind of target (dismissing needs a
 * report). A reported group can only have its report dismissed.
 */
export const STAFF_ACTIONS: Readonly<Record<StaffTargetType, readonly ActionKind[]>> = {
  post: ['hide', 'remove', 'restore', 'lock', 'unlock', 'warn'],
  comment: ['hide', 'remove', 'restore', 'warn'],
  profile: ['warn', 'restrict', 'ban', 'unban'],
  community: ['warn', 'ban', 'unban'],
  group: [],
};

/** Targets a new action can start from (groups are acted on from their report only). */
export const STAFF_TARGETS: readonly StaffTargetType[] = [
  'post',
  'comment',
  'profile',
  'community',
];

const ALL_STAFF_TARGETS: readonly StaffTargetType[] = [...STAFF_TARGETS, 'group'];

export function isStaffTarget(value: string): value is StaffTargetType {
  return ALL_STAFF_TARGETS.some((target) => target === value);
}

/** Every action kind, for the staff action list's filter. */
export const ACTION_KINDS: readonly ActionKind[] = [
  'hide',
  'remove',
  'restore',
  'pin',
  'unpin',
  'lock',
  'unlock',
  'warn',
  'restrict',
  'ban',
  'unban',
  'dismiss_report',
  'escalate',
];

const REASON_REQUIRED: readonly string[] = ['hide', 'remove', 'warn', 'restrict', 'ban'];
const SEVERE: readonly string[] = ['hide', 'remove', 'restrict', 'ban'];

/** The API requires a reason for these; the person affected sees it. */
export function needsReason(action: string): boolean {
  return REASON_REQUIRED.includes(action);
}

/** Actions that limit or remove something; confirmed with a danger button. */
export function isSevere(action: string): boolean {
  return SEVERE.includes(action);
}

/** The action as staff choose it ("Remove", "Suspend the community"). */
export function staffActionLabel(action: string, target: string): MessageKey {
  if (target === 'community' && action === 'ban') return 'moderation.staff.action.suspend';
  if (target === 'community' && action === 'unban') return 'moderation.staff.action.unsuspend';
  const keys: Readonly<Record<string, MessageKey>> = {
    hide: 'moderation.staff.action.hide',
    remove: 'moderation.staff.action.remove',
    restore: 'moderation.staff.action.restore',
    lock: 'moderation.staff.action.lock',
    unlock: 'moderation.staff.action.unlock',
    pin: 'moderation.staff.action.pin',
    unpin: 'moderation.staff.action.unpin',
    warn: 'moderation.staff.action.warn',
    restrict: 'moderation.staff.action.restrict',
    ban: 'moderation.staff.action.ban',
    unban: 'moderation.staff.action.unban',
    dismiss_report: 'moderation.staff.action.dismiss_report',
    escalate: 'moderation.staff.action.escalate',
  };
  return keys[action] ?? 'moderation.staff.action.other';
}

/** Restriction and ban lengths staff can choose (hours, as the API takes them). */
export const DURATION_CHOICES: readonly { hours: number; key: MessageKey }[] = [
  { hours: 24, key: 'moderation.staff.duration.day' },
  { hours: 72, key: 'moderation.staff.duration.days3' },
  { hours: 168, key: 'moderation.staff.duration.week' },
  { hours: 720, key: 'moderation.staff.duration.days30' },
  { hours: 2160, key: 'moderation.staff.duration.days90' },
  { hours: 8760, key: 'moderation.staff.duration.year' },
];
