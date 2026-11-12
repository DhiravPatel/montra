import type { FileAccess, Limits, Report, ReportSchedule } from '@/features/reports/types';

/** Report fixtures shaped like the contract (tests only). The API clock in tests is 2026-11-04T10:00:00Z. */

export const REPORT_READY = 'f0f0f0f0-1111-4111-8111-000000000001';
export const REPORT_RUNNING = 'f0f0f0f0-1111-4111-8111-000000000002';
export const REPORT_FAILED = 'f0f0f0f0-1111-4111-8111-000000000003';
export const REPORT_EXPIRED = 'f0f0f0f0-1111-4111-8111-000000000004';
export const REPORT_STALLED = 'f0f0f0f0-1111-4111-8111-000000000005';
export const REPORT_FILE = 'f1f1f1f1-2222-4222-8222-000000000001';
export const SCHEDULE_MONTHLY = 'f2f2f2f2-3333-4333-8333-000000000001';

export function makeReport(overrides: Partial<Report> = {}): Report {
  return {
    id: REPORT_READY,
    report_type: 'monthly_summary',
    title: 'Monthly summary',
    format: 'csv',
    filters: { range: 'last_month' },
    window: { from: '2026-10-01', to: '2026-10-31', days: 31, timezone: 'Asia/Kolkata' },
    timezone: 'Asia/Kolkata',
    status: 'completed',
    row_count: 22,
    requested_at: '2026-11-04T09:55:00.123456Z',
    completed_at: '2026-11-04T09:55:01Z',
    expires_at: '2026-11-11T09:55:01Z',
    ...overrides,
  };
}

/** Requested ten seconds before the API's clock: being prepared now. */
export function makeRunningReport(overrides: Partial<Report> = {}): Report {
  const report = makeReport({
    id: REPORT_RUNNING,
    report_type: 'transactions',
    title: 'November USD',
    format: 'pdf',
    filters: { from: '2026-11-01', to: '2026-11-30', currency: 'USD', include_pending: true },
    window: { from: '2026-11-01', to: '2026-11-30', days: 30, timezone: 'Asia/Kolkata' },
    status: 'running',
    requested_at: '2026-11-04T09:59:50Z',
    ...overrides,
  });
  delete report.row_count;
  delete report.completed_at;
  delete report.expires_at;
  return report;
}

export function makeFailedReport(overrides: Partial<Report> = {}): Report {
  const report = makeReport({
    id: REPORT_FAILED,
    report_type: 'transactions',
    title: 'Everything',
    format: 'pdf',
    filters: { range: 'this_year', account_ids: ['11111111-1111-4111-8111-111111111111'] },
    window: { from: '2026-01-01', to: '2026-12-31', days: 365, timezone: 'Asia/Kolkata' },
    status: 'failed',
    error_code: 'pdf_too_large',
    ...overrides,
  });
  delete report.row_count;
  delete report.completed_at;
  delete report.expires_at;
  return report;
}

export function makeExpiredReport(overrides: Partial<Report> = {}): Report {
  const report = makeReport({
    id: REPORT_EXPIRED,
    report_type: 'account',
    title: 'Accounts',
    format: 'xlsx',
    filters: {},
    status: 'expired',
    requested_at: '2026-10-20T08:00:00Z',
    completed_at: '2026-10-20T08:00:02Z',
    expires_at: '2026-10-27T08:00:02Z',
    ...overrides,
  });
  if (!overrides.window) delete report.window;
  return report;
}

/** Queued two hours before the API's clock: the job seems to have stopped. */
export function makeStalledReport(overrides: Partial<Report> = {}): Report {
  return makeRunningReport({
    id: REPORT_STALLED,
    report_type: 'cash_flow',
    title: 'Cash flow',
    format: 'json',
    filters: { range: 'this_month', display_currency: 'INR' },
    status: 'queued',
    requested_at: '2026-11-04T08:00:00Z',
    ...overrides,
  });
}

export function makeSchedule(overrides: Partial<ReportSchedule> = {}): ReportSchedule {
  return {
    id: SCHEDULE_MONTHLY,
    report_type: 'monthly_summary',
    title: 'Monthly summary (monthly)',
    format: 'pdf',
    cadence: 'monthly',
    filters: {},
    next_run_at: '2026-12-01T00:30:00Z',
    enabled: true,
    version: 1,
    ...overrides,
  };
}

/** The signed link the API issues: a file ID, an expiry, a signature and the owner's ID. */
export function makeAccess(overrides: Partial<FileAccess> = {}): FileAccess {
  return {
    url: `http://localhost:8080/api/v1/files/${REPORT_FILE}/content?exp=1793869250&sig=vynsUVtiJfOLY_xT0qcoLpJW6ZH8sEsQyxtsZR8KMtw&sub=7c9e6679-7425-40de-944b-e07fc1f90ae7`,
    expires_at: '2026-11-04T10:05:00Z',
    content_type: 'text/csv',
    filename: 'monthly-summary-20261104.csv',
    ...overrides,
  };
}

export function makeLimits(overrides: Partial<Limits> = {}): Limits {
  return {
    storage_quota_bytes: 2147483648,
    storage_used_bytes: 0,
    max_upload_bytes: 20971520,
    import_max_rows: 20000,
    max_open_recurring_rules: 500,
    max_open_bills: 200,
    max_open_goals: 100,
    max_open_subscriptions: 300,
    support_requests_per_day: 10,
    rate_limits: [{ policy: 'default', per_minute: 600, burst: 60 }],
    deletion_grace_days: 7,
    export_download_days: 7,
    ai_requests_per_day: 0,
    note: 'Every feature is free for everyone.',
    note_code: 'fair_use_same_for_everyone',
    ...overrides,
  };
}
