import type { DailyUsage, Usage } from '@/features/admin/types';

/** A daily series of `days` days ending on 2026-11-05 (dates as the API sends them). */
export function makeDaily(days: number): DailyUsage[] {
  const out: DailyUsage[] = [];
  const end = Date.UTC(2026, 10, 5);
  for (let index = days - 1; index >= 0; index -= 1) {
    const date = new Date(end - index * 86_400_000).toISOString().slice(0, 10);
    out.push({
      date,
      new_users: index % 3,
      transactions: 40 + index,
      emails_sent: 5 + (index % 4),
    });
  }
  return out;
}

/** GET /admin/usage: aggregate counts only, shaped like the API's answer. */
export function makeUsage(overrides: Partial<Usage> = {}): Usage {
  return {
    window_days: 30,
    users: { active: 1284, new: 37, pending_deletion: 2 },
    storage: { bytes: 157_286_400, files: 412 },
    storage_by_area: { uploads: 104_857_600, exports: 52_428_800 },
    notifications: { 'email:sent': 118, 'email:failed': 3, 'push:sent': 54 },
    jobs: { done: 2210, dead: 4, queued: 6 },
    dead_jobs_by_type: { 'support.notify_staff': 3, 'privacy.export': 1 },
    ai: { requests: 0, cost_micro_usd: 0 },
    imports: 21,
    reports: 9,
    transactions_created: 3640,
    support_open: 5,
    daily: makeDaily(7),
    ...overrides,
  };
}
