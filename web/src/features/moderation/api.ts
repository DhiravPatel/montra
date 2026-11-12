import { api } from '@/shared/api/client';
import { compactQuery } from '@/shared/api/query';
import { apiData, apiEnvelope } from '@/shared/api/request';
import type {
  ActionPage,
  AppealDecisionInput,
  PlatformActionFilters,
  ModerationAction,
  ModerationActionInput,
  ModerationAppeal,
  ModerationReport,
  QueueStatus,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

const idPath = (id: string) => ({ params: { path: { id } } });

/** Platform actions per page (the API allows up to 200). */
export const ACTION_PAGE_SIZE = 50;

/**
 * Moderation (spec §4.16, §20B.17). People see the decisions that affected
 * them and the reports they filed, and can appeal within 30 days. Montra
 * staff work the platform queue; every action is audited, and moderators
 * never see anyone's finances.
 */
export const moderationApi = {
  /** Warnings, removals and sanctions that affected you (no moderator identities). */
  myActions: (signal?: AbortSignal): Promise<ModerationAction[]> =>
    apiData(api.GET('/me/moderation', signalOption(signal))),
  /** Appeals you made, newest first, each with the action it is against and its outcome. */
  myAppeals: (signal?: AbortSignal): Promise<ModerationAppeal[]> =>
    apiData(api.GET('/me/moderation/appeals', signalOption(signal))),
  /** Reports you filed and their outcome. */
  myReports: (signal?: AbortSignal): Promise<ModerationReport[]> =>
    apiData(api.GET('/content-reports', signalOption(signal))),
  /** Asks for a review of an action that affected you (one open appeal per action). */
  appeal: (actionId: string, statement: string): Promise<ModerationAppeal> =>
    apiData(
      api.POST('/moderation/actions/{id}/appeals', { ...idPath(actionId), body: { statement } }),
    ),

  /** Staff: profile, group and community reports plus escalations. */
  staffReports: (status: QueueStatus, signal?: AbortSignal): Promise<ModerationReport[]> =>
    apiData(
      api.GET('/moderation/reports', { params: { query: { status } }, ...signalOption(signal) }),
    ),
  /** Staff: every open appeal. */
  staffAppeals: (signal?: AbortSignal): Promise<ModerationAppeal[]> =>
    apiData(api.GET('/moderation/appeals', signalOption(signal))),
  /** Staff: platform actions, newest first, one cursor page at a time. */
  staffActions: async (
    filters: PlatformActionFilters,
    cursor: string | null,
    signal?: AbortSignal,
  ): Promise<ActionPage> => {
    const envelope = await apiEnvelope(
      api.GET('/moderation/actions', {
        params: {
          query: compactQuery({
            status: filters.status,
            action: filters.action,
            target_type: filters.targetType,
            target_id: filters.targetId.trim(),
            target_user_id: filters.targetUserId.trim(),
            limit: ACTION_PAGE_SIZE,
            cursor: cursor ?? undefined,
          }),
        },
        ...signalOption(signal),
      }),
    );
    const more = envelope.meta.has_more ?? Boolean(envelope.meta.next_cursor);
    return {
      items: envelope.data,
      nextCursor: more && envelope.meta.next_cursor ? envelope.meta.next_cursor : null,
    };
  },
  /** Staff: a platform action (audited). */
  act: (body: ModerationActionInput): Promise<ModerationAction> =>
    apiData(api.POST('/moderation/actions', { body })),
  /** Undoes an action; the record is kept with `reversed_at`. */
  reverse: (actionId: string, note: string): Promise<ModerationAction> =>
    apiData(
      api.POST('/moderation/actions/{id}/reverse', {
        ...idPath(actionId),
        body: note ? { note } : {},
      }),
    ),
  /** Upholds or overturns an appeal; overturning reverses the action. */
  decide: (appealId: string, body: AppealDecisionInput): Promise<ModerationAppeal> =>
    apiData(api.POST('/moderation/appeals/{id}/decide', { ...idPath(appealId), body })),
};
