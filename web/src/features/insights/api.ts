import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { insightsKeys } from './keys';
import type {
  Insight,
  InsightActionInput,
  InsightFeedbackInput,
  InsightListQuery,
  InsightMute,
  InsightPage,
  UnmuteResult,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

function path(id: string) {
  return { params: { path: { id } } };
}

/**
 * Rule-based insights (spec §4.13): unusual activity and savings ideas found
 * by deterministic rules over the user's own history, each with its
 * evidence. Actions only change the insight, never the user's records.
 * The AI endpoints (/ai/*) are never called from here.
 */
export const insightsApi = {
  /** One cursor page (warnings first, then newest first; the server's page size). */
  list: async (
    { all, kind }: InsightListQuery,
    cursor: string,
    signal?: AbortSignal,
  ): Promise<InsightPage> => {
    const envelope = await apiEnvelope(
      api.GET('/insights', {
        params: {
          query: {
            ...(all ? { all: true } : {}),
            ...(kind ? { kind } : {}),
            ...(cursor ? { cursor } : {}),
          },
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
  /** One of your insights in any status (for links from notifications). */
  get: (id: string, signal?: AbortSignal): Promise<Insight> =>
    apiData(api.GET('/insights/{id}', { ...path(id), ...signalOption(signal) })),
  /** Dismiss, snooze, mark expected or resolved, mute or reopen; returns the updated insight. */
  act: (id: string, body: InsightActionInput): Promise<Insight> =>
    apiData(api.POST('/insights/{id}/actions', { ...path(id), body })),
  /**
   * Feedback only tunes the rules; it is never shared. One answer per
   * person and insight: sending it again replaces the earlier answer. The
   * response is the insight with `my_feedback`.
   */
  feedback: (id: string, body: InsightFeedbackInput): Promise<Insight> =>
    apiData(api.POST('/insights/{id}/feedback', { ...path(id), body })),
  /** The mute rules in force (subtype and scope, `*` for everywhere). */
  mutes: (signal?: AbortSignal): Promise<InsightMute[]> =>
    apiData(api.GET('/insights/mutes', signalOption(signal))),
  /**
   * Removes one mute rule and reopens the muted insights of that subtype
   * that no remaining rule covers (returned in the result).
   */
  unmute: (subtype: string, scope: string): Promise<UnmuteResult> =>
    apiData(api.DELETE('/insights/mutes', { params: { query: { subtype, scope } } })),
};

/** Cursor pages of insights for one view and kind. */
export function useInsights(query: InsightListQuery) {
  return useInfiniteQuery({
    queryKey: insightsKeys.list(query),
    queryFn: ({ pageParam, signal }) => insightsApi.list(query, pageParam, signal),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
}

/** One insight by ID (any status); disabled without an ID. */
export function useInsight(id: string | undefined) {
  return useQuery({
    queryKey: insightsKeys.detail(id ?? ''),
    queryFn: ({ signal }) => insightsApi.get(id ?? '', signal),
    enabled: Boolean(id),
  });
}

export function useInsightMutes() {
  return useQuery({
    queryKey: insightsKeys.mutes(),
    queryFn: ({ signal }) => insightsApi.mutes(signal),
  });
}
