import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import type { ContactKind, RequestKind, RequestStatus, StaffStatus } from './types';

export const REQUEST_KINDS = [
  'support',
  'bug',
  'security',
  'privacy',
  'feedback',
] as const satisfies readonly RequestKind[];

/** The signed-out contact form has no feedback option (the API refuses it). */
export const CONTACT_KINDS = [
  'support',
  'bug',
  'security',
  'privacy',
] as const satisfies readonly ContactKind[];

export const REQUEST_STATUSES = [
  'open',
  'in_progress',
  'resolved',
  'closed',
] as const satisfies readonly RequestStatus[];

export function isRequestKind(value: unknown): value is RequestKind {
  return typeof value === 'string' && (REQUEST_KINDS as readonly string[]).includes(value);
}

export function isRequestStatus(value: unknown): value is RequestStatus {
  return typeof value === 'string' && (REQUEST_STATUSES as readonly string[]).includes(value);
}

export const kindLabel: Readonly<Record<RequestKind, MessageKey>> = {
  support: 'support.kind.support',
  bug: 'support.kind.bug',
  security: 'support.kind.security',
  privacy: 'support.kind.privacy',
  feedback: 'support.kind.feedback',
};

export const kindHelp: Readonly<Record<RequestKind, MessageKey>> = {
  support: 'support.kindHelp.support',
  bug: 'support.kindHelp.bug',
  security: 'support.kindHelp.security',
  privacy: 'support.kindHelp.privacy',
  feedback: 'support.kindHelp.feedback',
};

export const kindIcon: Readonly<Record<RequestKind, IconName>> = {
  support: 'info',
  bug: 'alert-circle',
  security: 'shield',
  privacy: 'lock',
  feedback: 'mail',
};

export const statusLabel: Readonly<Record<RequestStatus, MessageKey>> = {
  open: 'support.status.open',
  in_progress: 'support.status.in_progress',
  resolved: 'support.status.resolved',
  closed: 'support.status.closed',
};

/** What each status means for the person who sent the request. */
export const statusExplanation: Readonly<Record<RequestStatus, MessageKey>> = {
  open: 'support.statusHelp.open',
  in_progress: 'support.statusHelp.in_progress',
  resolved: 'support.statusHelp.resolved',
  closed: 'support.statusHelp.closed',
};

export const statusTone: Readonly<Record<RequestStatus, Tone>> = {
  open: 'info',
  in_progress: 'info',
  resolved: 'success',
  closed: 'neutral',
};

export const statusIcon: Readonly<Record<RequestStatus, IconName>> = {
  open: 'inbox',
  in_progress: 'clock',
  resolved: 'check-circle',
  closed: 'archive',
};

/** Staff actions, in the order they are offered. */
export const STAFF_ACTIONS = [
  'in_progress',
  'resolved',
  'closed',
] as const satisfies readonly StaffStatus[];

export const staffActionLabel: Readonly<Record<StaffStatus, MessageKey>> = {
  in_progress: 'support.queue.action.in_progress',
  resolved: 'support.queue.action.resolved',
  closed: 'support.queue.action.closed',
};
