import type { components, operations } from '@/shared/api/schema';

type Schemas = components['schemas'];

/** A recorded moderation action (the affected person never sees who acted). */
export type ModerationAction = Schemas['ModerationActionDTO'];
export type ModerationActionInput = Schemas['ModerationActionInput'];
export type ModerationAppeal = Schemas['ModerationAppealDTO'];
/** The latest appeal against an action, as the action carries it. */
export type AppealState = Schemas['ModerationAppealState'];
/** The action an appeal is against, embedded in the appeal. */
export type AppealedAction = Schemas['ModerationActionSummary'];
export type ModerationReport = Schemas['ModerationReportDTO'];
export type AppealDecisionInput = Schemas['AppealDecisionInput'];

export type ActionKind = ModerationActionInput['action'];
export type ActionTargetType = ModerationActionInput['target_type'];
export type ReportStatus = ModerationReport['status'];
export type ReportTargetType = ModerationReport['target_type'];
export type ReportReason = Schemas['ModerationReportInput']['reason'];
export type AppealDecision = AppealDecisionInput['decision'];

/** GET /moderation/reports `status` (open also lists under review and escalated). */
export type QueueStatus = 'open' | 'actioned' | 'dismissed' | 'escalated';

/** Targets Montra staff act on directly (member actions belong to a community). */
export type StaffTargetType = Exclude<ActionTargetType, 'member'>;

type PlatformActionQuery = NonNullable<
  operations['moderation-platform-actions']['parameters']['query']
>;

/** Filters of the staff action list (GET /moderation/actions); empty means "any". */
export interface PlatformActionFilters {
  status: NonNullable<PlatformActionQuery['status']>;
  action: NonNullable<PlatformActionQuery['action']>;
  targetType: NonNullable<PlatformActionQuery['target_type']>;
  targetId: string;
  targetUserId: string;
}

/** One cursor page of platform actions. */
export interface ActionPage {
  items: ModerationAction[];
  nextCursor: string | null;
}
