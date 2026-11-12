import { parseTimestamp } from '@/shared/formatting/dates';
import type { ModerationAction } from './types';

/** Appeals are accepted for 30 days after the action (POST /moderation/actions/{id}/appeals). */
export const APPEAL_WINDOW_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * The last moment an appeal is accepted: the API's `appeal_until`, or 30
 * days after the action for records that do not carry it.
 */
export function appealDeadline(
  action: Pick<ModerationAction, 'created_at' | 'appeal_until'>,
): Date | null {
  const until = parseTimestamp(action.appeal_until);
  if (until) return until;
  const created = parseTimestamp(action.created_at);
  return created ? new Date(created.getTime() + APPEAL_WINDOW_DAYS * DAY_MS) : null;
}

export type AppealWindow =
  | { state: 'open'; deadline: Date }
  | { state: 'closed'; deadline: Date }
  /** Reversed or never appealable (`appealable` from the API). */
  | { state: 'none' };

export function appealWindow(action: ModerationAction, now: number): AppealWindow {
  if (!action.appealable) return { state: 'none' };
  const deadline = appealDeadline(action);
  if (!deadline) return { state: 'none' };
  return deadline.getTime() > now ? { state: 'open', deadline } : { state: 'closed', deadline };
}

/** Whether a restriction or ban is still in force (not reversed, not expired). */
export function isInForce(action: ModerationAction, now: number): boolean {
  if (action.reversed_at) return false;
  const expires = parseTimestamp(action.expires_at);
  return expires === null || expires.getTime() > now;
}

export interface Standing {
  /** An account-wide sanction by Montra staff, the strongest first. */
  account: { action: 'ban' | 'restrict'; until: string | null } | null;
  /** Communities where you cannot post right now. */
  restrictedIn: number;
  /** Communities you are banned from right now. */
  bannedFrom: number;
}

function newest(a: ModerationAction, b: ModerationAction): ModerationAction {
  return (parseTimestamp(a.created_at)?.getTime() ?? 0) >=
    (parseTimestamp(b.created_at)?.getTime() ?? 0)
    ? a
    : b;
}

/**
 * Where you stand, from the actions the API lists for you: account-wide
 * restrictions or bans that are still in force (as the API enforces them),
 * and community restrictions and bans (a later "unban" lifts a ban).
 */
export function standingFrom(actions: readonly ModerationAction[], now: number): Standing {
  const accountWide = actions.filter(
    (action) =>
      !action.community_id &&
      (action.action === 'ban' || action.action === 'restrict') &&
      isInForce(action, now),
  );
  const ban = accountWide.filter((action) => action.action === 'ban');
  const strongest = ban.length > 0 ? ban : accountWide;
  let account: Standing['account'] = null;
  if (strongest.length > 0) {
    const first = strongest[0];
    const open = strongest.some((action) => !action.expires_at);
    const latest = strongest
      .map((action) => action.expires_at ?? '')
      .filter(Boolean)
      .sort((a, b) => (parseTimestamp(b)?.getTime() ?? 0) - (parseTimestamp(a)?.getTime() ?? 0))[0];
    account = {
      action: first?.action === 'ban' ? 'ban' : 'restrict',
      until: open ? null : (latest ?? null),
    };
  }

  const restricted = new Set<string>();
  const latestBanState = new Map<string, ModerationAction>();
  for (const action of actions) {
    const community = action.community_id;
    if (!community) continue;
    if (action.action === 'restrict' && isInForce(action, now)) restricted.add(community);
    if (action.action === 'ban' || action.action === 'unban') {
      const seen = latestBanState.get(community);
      latestBanState.set(community, seen ? newest(seen, action) : action);
    }
  }
  let bannedFrom = 0;
  for (const action of latestBanState.values()) {
    if (action.action === 'ban' && isInForce(action, now)) bannedFrom += 1;
  }
  return { account, restrictedIn: restricted.size, bannedFrom };
}
