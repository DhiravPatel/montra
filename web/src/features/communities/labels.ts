import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type {
  AppealDecision,
  CommunityStatus,
  CommunityVisibility,
  InvitationKind,
  InvitationStatus,
  MemberRole,
  ModerationActionKind,
  NewPostKind,
  PostKind,
  PostLabel,
  ReactionKind,
  ReportFilter,
  ReportReason,
  ReportStatus,
} from './types';

export const VISIBILITIES = [
  'public',
  'private',
  'invite_only',
] as const satisfies readonly CommunityVisibility[];

export const visibilityLabel: Readonly<Record<CommunityVisibility, MessageKey>> = {
  public: 'communities.visibility.public',
  private: 'communities.visibility.private',
  invite_only: 'communities.visibility.invite_only',
};

/** Who can find, read and join (the community's join policy). */
export const visibilityHelp: Readonly<Record<CommunityVisibility, MessageKey>> = {
  public: 'communities.visibility.publicHelp',
  private: 'communities.visibility.privateHelp',
  invite_only: 'communities.visibility.invite_onlyHelp',
};

export const visibilityIcon: Readonly<Record<CommunityVisibility, IconName>> = {
  public: 'globe',
  private: 'lock',
  invite_only: 'mail',
};

export const communityStatusLabel: Readonly<Record<CommunityStatus, MessageKey>> = {
  active: 'communities.status.active',
  archived: 'communities.status.archived',
  suspended: 'communities.status.suspended',
};

export const roleLabel: Readonly<Record<MemberRole, MessageKey>> = {
  owner: 'communities.role.owner',
  moderator: 'communities.role.moderator',
  member: 'communities.role.member',
};

export const roleIcon: Readonly<Record<MemberRole, IconName>> = {
  owner: 'key',
  moderator: 'shield',
  member: 'user',
};

export const REACTION_KINDS = [
  'like',
  'helpful',
  'insightful',
  'support',
] as const satisfies readonly ReactionKind[];

export const reactionLabel: Readonly<Record<ReactionKind, MessageKey>> = {
  like: 'communities.reaction.like',
  helpful: 'communities.reaction.helpful',
  insightful: 'communities.reaction.insightful',
  support: 'communities.reaction.support',
};

export function isReactionKind(value: string): value is ReactionKind {
  return (REACTION_KINDS as readonly string[]).includes(value);
}

export const NEW_POST_KINDS = [
  'discussion',
  'question',
  'resource',
  'poll',
] as const satisfies readonly NewPostKind[];

export const postKindLabel: Readonly<Record<PostKind, MessageKey>> = {
  discussion: 'communities.kind.discussion',
  question: 'communities.kind.question',
  resource: 'communities.kind.resource',
  poll: 'communities.kind.poll',
  challenge_update: 'communities.kind.challenge_update',
};

export const postKindHelp: Readonly<Record<NewPostKind, MessageKey>> = {
  discussion: 'communities.kind.discussionHelp',
  question: 'communities.kind.questionHelp',
  resource: 'communities.kind.resourceHelp',
  poll: 'communities.kind.pollHelp',
};

export const postKindIcon: Readonly<Record<PostKind, IconName>> = {
  discussion: 'message-square',
  question: 'info',
  resource: 'link',
  poll: 'bar-chart',
  challenge_update: 'target',
};

export const postLabelLabel: Readonly<Record<PostLabel, MessageKey>> = {
  personal_experience: 'communities.label.personal_experience',
  verified_guidance: 'communities.label.verified_guidance',
  question: 'communities.label.question',
  resource: 'communities.label.resource',
};

export const postLabelIcon: Readonly<Record<PostLabel, IconName>> = {
  personal_experience: 'user',
  verified_guidance: 'shield-check',
  question: 'info',
  resource: 'link',
};

export const postLabelTone: Readonly<Record<PostLabel, Tone>> = {
  personal_experience: 'neutral',
  verified_guidance: 'success',
  question: 'info',
  resource: 'info',
};

export const REPORT_REASONS = [
  'spam',
  'abuse',
  'harassment',
  'scam',
  'impersonation',
  'misinformation',
  'privacy',
  'other',
] as const satisfies readonly ReportReason[];

export const reportReasonLabel: Readonly<Record<ReportReason, MessageKey>> = {
  spam: 'communities.reason.spam',
  abuse: 'communities.reason.abuse',
  harassment: 'communities.reason.harassment',
  scam: 'communities.reason.scam',
  impersonation: 'communities.reason.impersonation',
  misinformation: 'communities.reason.misinformation',
  privacy: 'communities.reason.privacy',
  other: 'communities.reason.other',
};

/** A report's reason in words (the queue returns it as free text). */
export function reportReasonName(reason: string, t: Translate): string {
  const key = (reportReasonLabel as Readonly<Record<string, MessageKey>>)[reason];
  return key ? t(key) : t('communities.reason.other');
}

export const REPORT_FILTERS = [
  'open',
  'actioned',
  'dismissed',
  'escalated',
] as const satisfies readonly ReportFilter[];

export const reportFilterLabel: Readonly<Record<ReportFilter, MessageKey>> = {
  open: 'communities.mod.reports.filter.open',
  actioned: 'communities.mod.reports.filter.actioned',
  dismissed: 'communities.mod.reports.filter.dismissed',
  escalated: 'communities.mod.reports.filter.escalated',
};

export const reportStatusLabel: Readonly<Record<ReportStatus, MessageKey>> = {
  open: 'communities.mod.reportStatus.open',
  under_review: 'communities.mod.reportStatus.under_review',
  actioned: 'communities.mod.reportStatus.actioned',
  dismissed: 'communities.mod.reportStatus.dismissed',
  escalated: 'communities.mod.reportStatus.escalated',
};

export const reportStatusTone: Readonly<Record<ReportStatus, Tone>> = {
  open: 'warning',
  under_review: 'info',
  actioned: 'success',
  dismissed: 'neutral',
  escalated: 'info',
};

export const reportStatusIcon: Readonly<Record<ReportStatus, IconName>> = {
  open: 'flag',
  under_review: 'eye',
  actioned: 'check-circle',
  dismissed: 'x-circle',
  escalated: 'arrow-up',
};

const targetLabels: Readonly<Record<string, MessageKey>> = {
  post: 'communities.target.post',
  comment: 'communities.target.comment',
  member: 'communities.target.member',
  profile: 'communities.target.profile',
  community: 'communities.target.community',
  group: 'communities.target.group',
};

/** "Post", "Comment", "Member"… (moderation targets arrive as free text). */
export function targetName(type: string, t: Translate): string {
  const key = targetLabels[type];
  return key ? t(key) : t('communities.target.other');
}

/** Actions a moderator can choose (imperative). */
export const actionChoiceLabel: Readonly<Record<ModerationActionKind, MessageKey>> = {
  hide: 'communities.action.hide',
  remove: 'communities.action.remove',
  restore: 'communities.action.restore',
  pin: 'communities.action.pin',
  unpin: 'communities.action.unpin',
  lock: 'communities.action.lock',
  unlock: 'communities.action.unlock',
  warn: 'communities.action.warn',
  restrict: 'communities.action.restrict',
  ban: 'communities.action.ban',
  unban: 'communities.action.unban',
  dismiss_report: 'communities.action.dismiss_report',
  escalate: 'communities.action.escalate',
};

/** What each action does, shown before choosing it. */
export const actionChoiceHelp: Readonly<Record<ModerationActionKind, MessageKey>> = {
  hide: 'communities.action.hideHelp',
  remove: 'communities.action.removeHelp',
  restore: 'communities.action.restoreHelp',
  pin: 'communities.action.pinHelp',
  unpin: 'communities.action.unpinHelp',
  lock: 'communities.action.lockHelp',
  unlock: 'communities.action.unlockHelp',
  warn: 'communities.action.warnHelp',
  restrict: 'communities.action.restrictHelp',
  ban: 'communities.action.banHelp',
  unban: 'communities.action.unbanHelp',
  dismiss_report: 'communities.action.dismiss_reportHelp',
  escalate: 'communities.action.escalateHelp',
};

/** Actions recorded in the log (past tense; the log also records join decisions). */
const actionDoneLabels: Readonly<Record<string, MessageKey>> = {
  hide: 'communities.done.hide',
  remove: 'communities.done.remove',
  restore: 'communities.done.restore',
  pin: 'communities.done.pin',
  unpin: 'communities.done.unpin',
  lock: 'communities.done.lock',
  unlock: 'communities.done.unlock',
  warn: 'communities.done.warn',
  restrict: 'communities.done.restrict',
  unrestrict: 'communities.done.unrestrict',
  ban: 'communities.done.ban',
  unban: 'communities.done.unban',
  dismiss_report: 'communities.done.dismiss_report',
  escalate: 'communities.done.escalate',
  approve_member: 'communities.done.approve_member',
  reject_member: 'communities.done.reject_member',
};

export function actionDoneName(action: string, t: Translate): string {
  const key = actionDoneLabels[action];
  return key ? t(key) : t('communities.done.other');
}

/** Actions that tell the affected person why: a reason is required. */
export const REASON_REQUIRED: ReadonlySet<string> = new Set([
  'hide',
  'remove',
  'warn',
  'restrict',
  'ban',
]);

/** Actions that can be undone from the log (the record stays, marked reversed). */
export const REVERSIBLE: ReadonlySet<string> = new Set([
  'hide',
  'remove',
  'pin',
  'lock',
  'warn',
  'restrict',
  'ban',
]);

/** Serious actions get a danger-styled confirmation. */
export const DANGEROUS_ACTIONS: ReadonlySet<string> = new Set([
  'hide',
  'remove',
  'restrict',
  'ban',
]);

export const invitationKindLabel: Readonly<Record<InvitationKind, MessageKey>> = {
  link: 'communities.invitationKind.link',
  username: 'communities.invitationKind.username',
};

export const invitationStatusLabel: Readonly<Record<InvitationStatus, MessageKey>> = {
  active: 'communities.invitationStatus.active',
  used: 'communities.invitationStatus.used',
  declined: 'communities.invitationStatus.declined',
  revoked: 'communities.invitationStatus.revoked',
  expired: 'communities.invitationStatus.expired',
};

export const invitationStatusTone: Readonly<Record<InvitationStatus, Tone>> = {
  active: 'info',
  used: 'success',
  declined: 'neutral',
  revoked: 'neutral',
  expired: 'neutral',
};

export const invitationStatusIcon: Readonly<Record<InvitationStatus, IconName>> = {
  active: 'mail',
  used: 'check-circle',
  declined: 'x-circle',
  revoked: 'ban',
  expired: 'clock',
};

export const appealStatusLabel: Readonly<Record<string, MessageKey>> = {
  open: 'communities.mod.appealStatus.open',
  upheld: 'communities.mod.appealStatus.upheld',
  overturned: 'communities.mod.appealStatus.overturned',
};

export const appealDecisionLabel: Readonly<Record<AppealDecision, MessageKey>> = {
  upheld: 'communities.mod.appeals.uphold',
  overturned: 'communities.mod.appeals.overturn',
};
