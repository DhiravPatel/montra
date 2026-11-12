import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { financeKeys } from '@/shared/finance/keys';
import type {
  Goal,
  GoalContribution,
  GoalContributionInput,
  GoalContributionRecordInput,
  GoalForecast,
  GoalInput,
  GoalMemberInput,
  GoalMemberUpdate,
  GoalPatch,
  GoalReport,
  GoalStatus,
} from '@/shared/finance/types';
import { exportFileName } from './download';

export type GoalStatusFilter = GoalStatus | 'all';

/** Status changes with their own endpoint (archiving is DELETE /goals/{id}). */
export type GoalTransition = 'pause' | 'resume' | 'achieve' | 'cancel';

export interface ContributionPage {
  items: GoalContribution[];
  /** meta.next_cursor when more contributions follow; null on the last page. */
  nextCursor: string | null;
}

export interface CsvDownload {
  csv: string;
  /** The server's neutral file name (goal-contributions-YYYY-MM-DD.csv), when usable. */
  fileName: string | null;
}

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

function path(id: string) {
  return { params: { path: { id } } };
}

/**
 * The version the screen displayed, so a concurrent change answers 409
 * VERSION_CONFLICT instead of acting on a goal the user has not seen.
 */
function versioned(id: string, version: number) {
  return { params: { path: { id }, query: { version } } };
}

function idempotent(key: string) {
  return { 'Idempotency-Key': key };
}

/** Savings goals (spec §8): goals, contributions, forecast, sharing and export. */
export const goalsApi = {
  list: (status: GoalStatusFilter, signal?: AbortSignal): Promise<Goal[]> =>
    apiData(api.GET('/goals', { params: { query: { status } }, ...signalOption(signal) })),
  /** Per-currency totals (never converted or added across currencies). */
  report: (signal?: AbortSignal): Promise<GoalReport> =>
    apiData(api.GET('/analytics/goals', signalOption(signal))),
  get: (id: string, signal?: AbortSignal): Promise<Goal> =>
    apiData(api.GET('/goals/{id}', { ...path(id), ...signalOption(signal) })),
  /** A retry with the same key replays the first result instead of creating a second goal. */
  create: (body: GoalInput, key: string): Promise<Goal> =>
    apiData(api.POST('/goals', { params: { header: idempotent(key) }, body })),
  /** Only the fields sent change; contributions are never rewritten. */
  update: (id: string, body: GoalPatch): Promise<Goal> =>
    apiData(api.PATCH('/goals/{id}', { ...path(id), body })),
  /** Archives the goal; its history is kept. */
  archive: (id: string, version: number): Promise<Goal> =>
    apiData(api.DELETE('/goals/{id}', versioned(id, version))),
  transition: (id: string, action: GoalTransition, version: number): Promise<Goal> => {
    const options = versioned(id, version);
    switch (action) {
      case 'pause':
        return apiData(api.POST('/goals/{id}/pause', options));
      case 'resume':
        return apiData(api.POST('/goals/{id}/resume', options));
      case 'achieve':
        return apiData(api.POST('/goals/{id}/achieve', options));
      case 'cancel':
        return apiData(api.POST('/goals/{id}/cancel', options));
    }
  },
  forecast: (id: string, signal?: AbortSignal): Promise<GoalForecast> =>
    apiData(api.GET('/goals/{id}/forecast', { ...path(id), ...signalOption(signal) })),
  /** One page of the history, newest first (the cursor stays in memory). */
  contributions: async (
    id: string,
    cursor: string,
    signal?: AbortSignal,
  ): Promise<ContributionPage> => {
    const envelope = await apiEnvelope(
      api.GET('/goals/{id}/contributions', {
        params: { path: { id }, query: cursor ? { cursor } : {} },
        ...signalOption(signal),
      }),
    );
    const more = envelope.meta.has_more ?? Boolean(envelope.meta.next_cursor);
    return {
      items: envelope.data,
      nextCursor: more && envelope.meta.next_cursor ? envelope.meta.next_cursor : null,
    };
  },
  /** A financial write: retries with the same key replay the first result. */
  contribute: (id: string, body: GoalContributionInput, key: string): Promise<GoalContribution> =>
    apiData(
      api.POST('/goals/{id}/contributions', {
        params: { path: { id }, header: idempotent(key) },
        body,
      }),
    ),
  /** Turns one of your planned contributions into a recorded (or verified) one, counted once. */
  recordPlanned: (
    id: string,
    contributionId: string,
    body: GoalContributionRecordInput,
    key: string,
  ): Promise<GoalContribution> =>
    apiData(
      api.POST('/goals/{id}/contributions/{contributionId}/record', {
        params: { path: { id, contributionId }, header: idempotent(key) },
        body,
      }),
    ),
  voidContribution: (id: string, contributionId: string): Promise<Goal> =>
    apiData(
      api.POST('/goals/{id}/contributions/{contributionId}/void', {
        params: { path: { id, contributionId } },
      }),
    ),
  addMember: (id: string, body: GoalMemberInput, version: number): Promise<Goal> =>
    apiData(api.POST('/goals/{id}/members', { ...versioned(id, version), body })),
  /** A role (owner only), or your own contribution visibility (the owner's too). */
  updateMember: (
    id: string,
    userId: string,
    body: GoalMemberUpdate,
    version: number,
  ): Promise<Goal> =>
    apiData(
      api.PATCH('/goals/{id}/members/{userId}', {
        params: { path: { id, userId }, query: { version } },
        body,
      }),
    ),
  /** Removes a member, or leaves when `userId` is the signed-in user. */
  removeMember: (id: string, userId: string, version: number): Promise<{ ok: boolean }> =>
    apiData(
      api.DELETE('/goals/{id}/members/{userId}', {
        params: { path: { id, userId }, query: { version } },
      }),
    ),
  /** The full contribution history as CSV text (text/csv), with the server's file name. */
  exportCsv: async (id: string): Promise<CsvDownload> => {
    const headers: { disposition: string | null } = { disposition: null };
    const csv = await apiEnvelope(
      api.GET('/goals/{id}/export', { ...path(id), parseAs: 'text' }).then((result) => {
        headers.disposition = result.response.headers.get('Content-Disposition');
        return result;
      }),
    );
    return { csv, fileName: exportFileName(headers.disposition) };
  },
};

export const goalReportKey = [...financeKeys.goals('report'), 'totals'] as const;

export function useGoals(status: GoalStatusFilter) {
  return useQuery({
    queryKey: financeKeys.goals(status),
    queryFn: ({ signal }) => goalsApi.list(status, signal),
  });
}

export function useGoalReport() {
  return useQuery({
    queryKey: goalReportKey,
    queryFn: ({ signal }) => goalsApi.report(signal),
  });
}

export function useGoal(id: string) {
  return useQuery({
    queryKey: financeKeys.goal(id),
    queryFn: ({ signal }) => goalsApi.get(id, signal),
    enabled: Boolean(id),
  });
}

export function useGoalForecast(id: string) {
  return useQuery({
    queryKey: financeKeys.goalForecast(id),
    queryFn: ({ signal }) => goalsApi.forecast(id, signal),
  });
}

/** Cursor pages of the contribution history ("Load more"). */
export function useGoalContributions(id: string) {
  return useInfiniteQuery({
    queryKey: financeKeys.goalContributions(id),
    queryFn: ({ pageParam, signal }) => goalsApi.contributions(id, pageParam, signal),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
}
