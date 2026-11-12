import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import { formatLocalDate, formatLocalDateRange } from '@/shared/formatting/dates';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type {
  Group,
  GroupRole,
  GroupType,
  InvitationStatus,
  MemberStatus,
  NotificationLevel,
  SplitMethod,
} from './types';

export const GROUP_TYPES = [
  'household',
  'roommates',
  'trip',
  'event',
  'friends',
  'custom',
] as const satisfies readonly GroupType[];

export function isGroupType(value: string): value is GroupType {
  return (GROUP_TYPES as readonly string[]).includes(value);
}

export const groupTypeLabel: Readonly<Record<GroupType, MessageKey>> = {
  household: 'groups.type.household',
  roommates: 'groups.type.roommates',
  trip: 'groups.type.trip',
  event: 'groups.type.event',
  friends: 'groups.type.friends',
  custom: 'groups.type.custom',
};

export const groupTypeDescription: Readonly<Record<GroupType, MessageKey>> = {
  household: 'groups.type.household.description',
  roommates: 'groups.type.roommates.description',
  trip: 'groups.type.trip.description',
  event: 'groups.type.event.description',
  friends: 'groups.type.friends.description',
  custom: 'groups.type.custom.description',
};

export const groupTypeIcon: Readonly<Record<GroupType, IconName>> = {
  household: 'home',
  roommates: 'home',
  trip: 'globe',
  event: 'calendar',
  friends: 'users',
  custom: 'folder',
};

/** A preview's `group_type` is a plain string in the contract. */
export function groupTypeName(type: string, t: Translate): string {
  return isGroupType(type) ? t(groupTypeLabel[type]) : t('groups.type.custom');
}

/** Trips and events have dates and a destination (spec §4.15 "Trips/events"). */
export function hasTripDetails(type: string): boolean {
  return type === 'trip' || type === 'event';
}

/** Households and roommates share regular bills such as rent and utilities. */
export function isHome(type: string): boolean {
  return type === 'household' || type === 'roommates';
}

export const SPLIT_METHODS = [
  'equal',
  'exact',
  'percentage',
  'shares',
  'itemized',
] as const satisfies readonly SplitMethod[];

export function isSplitMethod(value: string): value is SplitMethod {
  return (SPLIT_METHODS as readonly string[]).includes(value);
}

export const splitMethodLabel: Readonly<Record<SplitMethod, MessageKey>> = {
  equal: 'groups.split.equal',
  exact: 'groups.split.exact',
  percentage: 'groups.split.percentage',
  shares: 'groups.split.shares',
  itemized: 'groups.split.itemized',
};

export const roleLabel: Readonly<Record<GroupRole, MessageKey>> = {
  owner: 'groups.role.owner',
  admin: 'groups.role.admin',
  member: 'groups.role.member',
};

export const roleIcon: Readonly<Record<GroupRole, IconName>> = {
  owner: 'key',
  admin: 'shield',
  member: 'user',
};

export const memberStatusLabel: Readonly<Record<MemberStatus, MessageKey>> = {
  active: 'groups.memberStatus.active',
  left: 'groups.memberStatus.left',
  removed: 'groups.memberStatus.removed',
};

export const NOTIFICATION_LEVELS = [
  'all',
  'important',
  'none',
] as const satisfies readonly NotificationLevel[];

export const notificationLevelLabel: Readonly<Record<NotificationLevel, MessageKey>> = {
  all: 'groups.notifications.all',
  important: 'groups.notifications.important',
  none: 'groups.notifications.none',
};

export const notificationLevelDescription: Readonly<Record<NotificationLevel, MessageKey>> = {
  all: 'groups.notifications.all.description',
  important: 'groups.notifications.important.description',
  none: 'groups.notifications.none.description',
};

export const invitationStatusLabel: Readonly<Record<InvitationStatus, MessageKey>> = {
  active: 'groups.invitationStatus.active',
  accepted: 'groups.invitationStatus.accepted',
  declined: 'groups.invitationStatus.declined',
  revoked: 'groups.invitationStatus.revoked',
  expired: 'groups.invitationStatus.expired',
};

export const invitationStatusTone: Readonly<Record<InvitationStatus, Tone>> = {
  active: 'success',
  accepted: 'neutral',
  declined: 'neutral',
  revoked: 'neutral',
  expired: 'warning',
};

export const invitationStatusIcon: Readonly<Record<InvitationStatus, IconName>> = {
  active: 'check-circle',
  accepted: 'check',
  declined: 'x-circle',
  revoked: 'ban',
  expired: 'clock',
};

export type TripPhase = 'upcoming' | 'ongoing' | 'ended';

/**
 * Where a trip or event stands today in the group's time zone (calendar
 * dates compare as strings). Without an end date it lasts one day, as the
 * API's trip reminders assume. Null without dates.
 */
export function tripPhase(
  group: Pick<Group, 'start_date' | 'end_date'>,
  today: string,
): TripPhase | null {
  const start = group.start_date;
  const end = group.end_date ?? group.start_date;
  if (!start && !end) return null;
  if (start && today < start) return 'upcoming';
  if (end && today > end) return 'ended';
  return 'ongoing';
}

export const tripPhaseLabel: Readonly<Record<TripPhase, MessageKey>> = {
  upcoming: 'groups.trip.upcoming',
  ongoing: 'groups.trip.ongoing',
  ended: 'groups.trip.ended',
};

export const tripPhaseIcon: Readonly<Record<TripPhase, IconName>> = {
  upcoming: 'calendar',
  ongoing: 'play',
  ended: 'check-circle',
};

/** "20–24 Dec 2026", "20 Dec 2026" (one day) or "Until 24 Dec 2026"; null without dates. */
export function tripDates(
  group: Pick<Group, 'start_date' | 'end_date'>,
  t: Translate,
  locale: string,
): string | null {
  const { start_date: start, end_date: end } = group;
  if (start && end) return formatLocalDateRange(start, end, locale);
  if (start) return formatLocalDate(start, locale);
  if (end) return t('groups.trip.until', { date: formatLocalDate(end, locale) });
  return null;
}
