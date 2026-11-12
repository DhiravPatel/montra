import { parseTimestamp } from '@/shared/formatting/dates';
import type { Report, ReportList, ReportStatus } from './types';

/** A report the background job is still working on. */
export function isActiveStatus(status: ReportStatus): boolean {
  return status === 'queued' || status === 'running';
}

const MINUTE = 60_000;
/** After this long a report is shown as delayed and is no longer polled for. */
export const STALLED_AFTER_MS = 30 * MINUTE;

/** How long ago (by the server's clock) a report was requested, or null when unknown. */
export function waitingMs(report: Report, serverTime: string): number | null {
  const requested = parseTimestamp(report.requested_at);
  const now = parseTimestamp(serverTime);
  if (!requested || !now) return null;
  return Math.max(0, now.getTime() - requested.getTime());
}

/** Still queued or running long after it was requested (the job may have stopped). */
export function isStalled(report: Report, serverTime: string): boolean {
  if (!isActiveStatus(report.status)) return false;
  const waited = waitingMs(report, serverTime);
  return waited !== null && waited > STALLED_AFTER_MS;
}

/**
 * A completed report whose download window has passed (by the server's
 * clock). Its status turns to `expired` only when a cleanup job runs, but
 * the API already refuses the download.
 */
export function isPastExpiry(report: Report, serverTime: string): boolean {
  if (report.status !== 'completed') return false;
  const expires = parseTimestamp(report.expires_at);
  const now = parseTimestamp(serverTime);
  return expires !== null && now !== null && expires.getTime() <= now.getTime();
}

/** The state to show for a report (a completed one past its download window is expired). */
export function displayStatus(report: Report, serverTime: string): ReportStatus {
  return isPastExpiry(report, serverTime) ? 'expired' : report.status;
}

/**
 * Polling for the report list: every 2 s in the first minute after a
 * request, every 5 s up to 10 minutes, every 30 s up to 30 minutes, then
 * not at all (a delayed report can be generated again).
 */
export function pollInterval(list: ReportList | undefined): number | false {
  if (!list) return false;
  let shortest: number | null = null;
  for (const report of list.reports) {
    if (!isActiveStatus(report.status)) continue;
    const waited = waitingMs(report, list.serverTime) ?? 0;
    if (waited > STALLED_AFTER_MS) continue;
    const interval = waited < MINUTE ? 2_000 : waited < 10 * MINUTE ? 5_000 : 30_000;
    shortest = shortest === null ? interval : Math.min(shortest, interval);
  }
  return shortest ?? false;
}
