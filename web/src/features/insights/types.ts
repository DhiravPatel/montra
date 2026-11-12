import type { components, operations } from '@/shared/api/schema';

/** Insight types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type Insight = Schemas['InsightDTO'];
export type InsightKind = Insight['kind'];
export type InsightStatus = Insight['status'];
export type InsightSeverity = Insight['severity'];
export type InsightActionInput = Schemas['ActionInput'];
export type InsightAction = InsightActionInput['action'];
export type InsightFeedbackInput = Schemas['FeedbackInput'];
export type InsightFeedback = InsightFeedbackInput['feedback'];
/** The caller's recorded answer on an insight (`my_feedback`). */
export type InsightFeedbackState = Schemas['FeedbackDTO'];
/** A mute rule: a subtype for one record (`scope`) or everywhere (`*`). */
export type InsightMute = Schemas['InsightMuteDTO'];
/** What DELETE /insights/mutes did: the rule removed and the insights it reopened. */
export type UnmuteResult = Schemas['UnmuteResult'];
export type Money = Schemas['Money'];

type ListParams = NonNullable<operations['insights-list']['parameters']['query']>;

/** `''` lists every kind. */
export type InsightKindFilter = NonNullable<ListParams['kind']>;

export interface InsightListQuery {
  /** Include dismissed, snoozed, expected, resolved and muted insights. */
  all: boolean;
  kind: InsightKindFilter;
}

/** One cursor page of GET /insights. */
export interface InsightPage {
  items: Insight[];
  /** Cursor for the next page; null on the last page. */
  nextCursor: string | null;
}
