import { http, HttpResponse } from 'msw';
import type {
  ModerationAction,
  ModerationAppeal,
  ModerationReport,
} from '@/features/moderation/types';
import { API, envelope, makeUser } from './fixtures';
import { server } from './msw/server';

/** Moderation actions, reports and appeals (tests only). */
export const ACTION_REMOVE = '7d5e0a8b-3c9f-4d6e-8b0a-9f0e1d2c3be7';
export const ACTION_RESTRICT = '8e6f1b9c-4d0a-4e7f-9c1b-0a1f2e3d4cf8';
export const ACTION_HIDE = '9f7a2c0d-5e1b-4f8a-8d2c-1b2a3f4e5d09';
export const ACTION_WARN = 'a08b3d1e-6f2c-4a9b-9e3d-2c3b4a5f6e1a';
export const REPORT_PROFILE = 'b19c4e2f-7a3d-4b0c-8f4e-3d4c5b6a7f2b';
export const REPORT_POST = 'c2ad5f3a-8b4e-4c1d-9a5f-4e5d6c7b8a3c';
export const REPORT_GROUP = 'd3be6a4b-9c5f-4d2e-8b6a-5f6e7d8c9b4d';
export const APPEAL_ID = 'e4cf7b5c-0d6a-4e3f-9c7b-6a7f8e9d0c5e';
export const MOD_COMMUNITY_ID = 'f5d08c6d-1e7b-4f4a-8d8c-7b8a9f0e1d6f';
export const MOD_POST_ID = '06e19d7e-2f8c-4a5b-9e9d-8c9b0a1f2e70';
export const REPORTED_USER_ID = '17f2ae8f-3a9d-4b6c-8f0e-9d0c1b2a3f81';

const DAY_MS = 24 * 60 * 60 * 1000;

/** An instant `days` before now (RFC 3339 UTC). */
export function daysAgo(days: number): string {
  return new Date(Date.now() - days * DAY_MS).toISOString();
}

/** An instant `days` after now (RFC 3339 UTC). */
export function daysAhead(days: number): string {
  return new Date(Date.now() + days * DAY_MS).toISOString();
}

export function makeStaff() {
  return makeUser({ onboarding_completed: true, platform_role: 'support' });
}

/** Your post removed by a community moderator two days ago (appealable). */
export function makeAction(overrides: Partial<ModerationAction> = {}): ModerationAction {
  const created = daysAgo(2);
  return {
    id: ACTION_REMOVE,
    action: 'remove',
    target_type: 'post',
    target_id: MOD_POST_ID,
    target_user_id: makeUser().id,
    community_id: MOD_COMMUNITY_ID,
    reason: 'Advertising is not allowed',
    appealable: true,
    // Like the API: 30 days after the action.
    appeal_until: new Date(Date.parse(overrides.created_at ?? created) + 30 * DAY_MS).toISOString(),
    created_at: created,
    ...overrides,
  };
}

/** A report you filed about a post. */
export function makeReport(overrides: Partial<ModerationReport> = {}): ModerationReport {
  return {
    id: REPORT_POST,
    target_type: 'post',
    target_id: MOD_POST_ID,
    community_id: MOD_COMMUNITY_ID,
    reason: 'spam',
    details: 'Same link everywhere',
    status: 'open',
    open_reports: 0,
    created_at: daysAgo(1),
    ...overrides,
  };
}

/** An open appeal against a community moderator's removal (with the action it embeds). */
export function makeAppeal(overrides: Partial<ModerationAppeal> = {}): ModerationAppeal {
  const action = makeAction();
  return {
    id: APPEAL_ID,
    action_id: ACTION_REMOVE,
    action: {
      id: action.id,
      action: action.action,
      target_type: action.target_type,
      target_id: action.target_id,
      target_user_id: action.target_user_id,
      reason: action.reason,
      created_at: action.created_at,
    },
    community_id: MOD_COMMUNITY_ID,
    statement: 'It was a free guide, not an advert.',
    status: 'open',
    created_at: daysAgo(1),
    ...overrides,
  };
}

/** GET /me/moderation, GET /me/moderation/appeals and GET /content-reports. */
export function serveMyModeration(
  actions: ModerationAction[] = [],
  reports: ModerationReport[] = [],
  appeals: ModerationAppeal[] = [],
) {
  const state = { actions, reports, appeals };
  server.use(
    http.get(`${API}/me/moderation`, () => HttpResponse.json(envelope(state.actions))),
    http.get(`${API}/me/moderation/appeals`, () => HttpResponse.json(envelope(state.appeals))),
    http.get(`${API}/content-reports`, () => HttpResponse.json(envelope(state.reports))),
  );
  return state;
}

/**
 * GET /moderation/actions in cursor pages of `pageSize` (like the API:
 * `meta.next_cursor` / `has_more`); filters are not applied, the queries
 * received are recorded instead.
 */
export function serveStaffActions(actions: ModerationAction[] = [], pageSize = 50) {
  const state = { actions, queries: [] as string[] };
  server.use(
    http.get(`${API}/moderation/actions`, ({ request }) => {
      const params = new URL(request.url).searchParams;
      state.queries.push(params.toString());
      const cursor = params.get('cursor');
      const offset = cursor ? Number(cursor.replace(/^after-/u, '')) : 0;
      const end = offset + pageSize;
      const page = envelope(state.actions.slice(offset, end));
      const more = end < state.actions.length;
      return HttpResponse.json({
        ...page,
        meta: { ...page.meta, has_more: more, ...(more ? { next_cursor: `after-${end}` } : {}) },
      });
    }),
  );
  return state;
}

/**
 * GET /moderation/reports (per status), GET /moderation/appeals and an
 * empty GET /moderation/actions; returns the statuses asked for.
 */
export function serveStaffQueues(
  reports: Partial<Record<string, ModerationReport[]>> = {},
  appeals: ModerationAppeal[] = [],
) {
  const asked: string[] = [];
  serveStaffActions();
  server.use(
    http.get(`${API}/moderation/reports`, ({ request }) => {
      const status = new URL(request.url).searchParams.get('status') ?? '';
      asked.push(status);
      return HttpResponse.json(envelope(reports[status] ?? []));
    }),
    http.get(`${API}/moderation/appeals`, () => HttpResponse.json(envelope(appeals))),
  );
  return asked;
}
